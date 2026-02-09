#!/usr/bin/env python3
"""
Darktable Storage Optimizer pour Google Drive

Optimise l'espace de stockage en:
- Conservant les fichiers RAW (.NEF) des photos avec des étoiles (lu depuis XMP)
- Convertissant les photos sans étoiles en JPEG haute qualité
- Déplaçant les fichiers NEF/XMP originaux vers une corbeille (sécurité)
"""

import os
import sys
import argparse
import subprocess
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from datetime import datetime


class DarktableStorageOptimizer:
    """Optimise l'espace de stockage des photos darktable"""

    def __init__(self, root_dir: str, dry_run: bool = True, jpeg_quality: int = 95,
                 trash_folder: str = None):
        """
        Initialise l'optimiseur

        Args:
            root_dir: Dossier racine à scanner
            dry_run: Si True, simule sans effectuer les modifications
            jpeg_quality: Qualité JPEG (1-100)
            trash_folder: Dossier corbeille (None = .corbeille dans root_dir)
        """
        self.root_dir = os.path.abspath(root_dir)
        self.dry_run = dry_run
        self.jpeg_quality = jpeg_quality

        if trash_folder:
            self.trash_folder = os.path.abspath(trash_folder)
        else:
            self.trash_folder = os.path.join(self.root_dir, '.corbeille')

        if not os.path.exists(self.root_dir):
            raise FileNotFoundError(f"Dossier non trouvé: {self.root_dir}")

    def read_rating_from_xmp(self, xmp_path: str) -> Optional[int]:
        """
        Lit le rating depuis un fichier XMP darktable

        Args:
            xmp_path: Chemin vers le fichier XMP

        Returns:
            Rating (0-5) ou None si non trouvé
        """
        if not os.path.exists(xmp_path):
            return None

        try:
            tree = ET.parse(xmp_path)
            root = tree.getroot()

            # Namespace XMP
            namespaces = {
                'x': 'adobe:ns:meta/',
                'rdf': 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
                'xmp': 'http://ns.adobe.com/xap/1.0/',
                'darktable': 'http://darktable.sf.net/'
            }

            # Cherche xmp:Rating (standard XMP)
            rating_elements = root.findall('.//xmp:Rating', namespaces)
            if rating_elements:
                try:
                    return int(rating_elements[0].text)
                except (ValueError, AttributeError):
                    pass

            # Cherche aussi dans les attributs RDF
            for desc in root.findall('.//{http://www.w3.org/1999/02/22-rdf-syntax-ns#}Description'):
                rating = desc.get('{http://ns.adobe.com/xap/1.0/}Rating')
                if rating:
                    try:
                        return int(rating)
                    except ValueError:
                        pass

            # Pas de rating trouvé = 0 étoiles
            return 0

        except ET.ParseError as e:
            print(f"  ⚠️  Erreur lecture XMP {xmp_path}: {e}")
            return None
        except Exception as e:
            print(f"  ⚠️  Erreur inattendue lecture XMP: {e}")
            return None

    def find_nef_files(self) -> List[Dict]:
        """
        Trouve tous les fichiers NEF avec leur rating

        Returns:
            Liste de dictionnaires contenant les infos des photos
        """
        photos = []
        nef_count = 0
        xmp_count = 0

        print(f"\nScan du dossier: {self.root_dir}")

        for root, dirs, files in os.walk(self.root_dir):
            # Ignore le dossier corbeille
            if '.corbeille' in root:
                continue

            for filename in files:
                if filename.upper().endswith('.NEF'):
                    nef_count += 1
                    nef_path = os.path.join(root, filename)
                    xmp_path = nef_path + '.xmp'

                    # Lit le rating depuis le XMP
                    rating = self.read_rating_from_xmp(xmp_path)

                    if rating is None:
                        # Pas de XMP = considère comme 0 étoiles
                        rating = 0
                        has_xmp = False
                    else:
                        has_xmp = True
                        xmp_count += 1

                    photos.append({
                        'filename': filename,
                        'folder': root,
                        'nef_path': nef_path,
                        'xmp_path': xmp_path if has_xmp else None,
                        'rating': rating,
                        'has_xmp': has_xmp,
                        'size': os.path.getsize(nef_path)
                    })

        print(f"  Trouvé {nef_count} fichier(s) NEF")
        print(f"  Trouvé {xmp_count} fichier(s) XMP associé(s)")

        return photos

    def filter_photos_without_stars(self, photos: List[Dict]) -> List[Dict]:
        """
        Filtre pour ne garder que les photos sans étoiles

        Args:
            photos: Liste de toutes les photos

        Returns:
            Liste des photos sans étoiles (rating = 0)
        """
        return [p for p in photos if p['rating'] == 0]

    def convert_to_jpeg(self, nef_path: str, jpeg_path: str, xmp_path: str = None) -> bool:
        """
        Convertit un fichier NEF en JPEG

        Args:
            nef_path: Chemin du fichier NEF source
            jpeg_path: Chemin du fichier JPEG destination
            xmp_path: Chemin du XMP (pour appliquer les retouches)

        Returns:
            True si la conversion a réussi
        """
        try:
            # Essaie d'abord avec darktable-cli (meilleure qualité)
            if xmp_path and os.path.exists(xmp_path):
                # darktable-cli utilise automatiquement le XMP s'il est à côté du NEF
                cmd = [
                    'darktable-cli',
                    nef_path,
                    jpeg_path,
                    '--core',
                    '--conf', f'plugins/imageio/format/jpeg/quality={self.jpeg_quality}'
                ]
            else:
                cmd = [
                    'darktable-cli',
                    nef_path,
                    jpeg_path,
                    '--core',
                    '--conf', f'plugins/imageio/format/jpeg/quality={self.jpeg_quality}'
                ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120
            )

            if result.returncode == 0 and os.path.exists(jpeg_path):
                return True
            else:
                # Si darktable-cli échoue, essaie alternative
                return self._convert_with_alternative(nef_path, jpeg_path)

        except FileNotFoundError:
            # darktable-cli pas installé, utilise alternative
            return self._convert_with_alternative(nef_path, jpeg_path)
        except subprocess.TimeoutExpired:
            print(f"    ⏱️  Timeout lors de la conversion")
            return False
        except Exception as e:
            print(f"    ❌ Erreur conversion: {e}")
            return False

    def _convert_with_alternative(self, nef_path: str, jpeg_path: str) -> bool:
        """
        Conversion alternative avec ImageMagick
        """
        try:
            cmd = [
                'convert',
                nef_path,
                '-quality', str(self.jpeg_quality),
                jpeg_path
            ]

            result = subprocess.run(cmd, capture_output=True, timeout=120)
            return result.returncode == 0 and os.path.exists(jpeg_path)

        except FileNotFoundError:
            print(f"    ❌ Ni darktable-cli ni ImageMagick disponible")
            return False
        except Exception as e:
            print(f"    ❌ Conversion alternative échouée: {e}")
            return False

    def move_to_trash(self, file_path: str) -> bool:
        """
        Déplace un fichier vers la corbeille en préservant la structure

        Args:
            file_path: Chemin du fichier à déplacer

        Returns:
            True si le déplacement a réussi
        """
        try:
            # Calcule le chemin relatif depuis root_dir
            rel_path = os.path.relpath(file_path, self.root_dir)

            # Crée le chemin de destination dans la corbeille
            trash_path = os.path.join(self.trash_folder, rel_path)
            trash_dir = os.path.dirname(trash_path)

            # Crée le dossier de destination si nécessaire
            os.makedirs(trash_dir, exist_ok=True)

            # Déplace le fichier
            shutil.move(file_path, trash_path)
            return True

        except Exception as e:
            print(f"    ❌ Erreur déplacement vers corbeille: {e}")
            return False

    def process_photos(self) -> Tuple[int, int, int]:
        """
        Traite toutes les photos sans étoiles

        Returns:
            Tuple (nombre traité, espace économisé en bytes, nombre d'erreurs)
        """
        all_photos = self.find_nef_files()
        photos_no_stars = self.filter_photos_without_stars(all_photos)

        with_stars = len(all_photos) - len(photos_no_stars)

        print(f"\n📊 Statistiques:")
        print(f"  Photos avec étoiles (⭐): {with_stars} (conservées en NEF)")
        print(f"  Photos sans étoiles: {len(photos_no_stars)} (à traiter)")

        if not photos_no_stars:
            print("\n✅ Aucune photo sans étoiles à traiter.")
            return 0, 0, 0

        print(f"\n{'='*70}")
        print(f"Mode: {'🔍 SIMULATION' if self.dry_run else '⚠️  RÉEL'}")
        print(f"{'='*70}\n")

        processed = 0
        space_saved = 0
        errors = 0

        for i, photo in enumerate(photos_no_stars, 1):
            rel_path = os.path.relpath(photo['folder'], self.root_dir)
            print(f"[{i}/{len(photos_no_stars)}] {rel_path}/{photo['filename']}")

            # Génère le nom du fichier JPEG
            jpeg_path = photo['nef_path'].rsplit('.', 1)[0] + '.jpg'

            # Étape 1: Conversion JPEG
            if os.path.exists(jpeg_path):
                print(f"  ✓ JPEG existe déjà")
                jpeg_size = os.path.getsize(jpeg_path)
            else:
                if self.dry_run:
                    print(f"  → Convertirait en JPEG (qualité {self.jpeg_quality})")
                    # Estime la taille JPEG (~ 10-15% du NEF)
                    jpeg_size = int(photo['size'] * 0.12)
                else:
                    print(f"  → Conversion en JPEG...")
                    if not self.convert_to_jpeg(photo['nef_path'], jpeg_path, photo['xmp_path']):
                        print(f"  ❌ ERREUR: Échec de conversion")
                        errors += 1
                        continue

                    # Vérifie que le JPEG a bien été créé
                    if not os.path.exists(jpeg_path):
                        print(f"  ❌ ERREUR: JPEG non créé")
                        errors += 1
                        continue

                    jpeg_size = os.path.getsize(jpeg_path)
                    print(f"  ✓ JPEG créé ({self._format_size(jpeg_size)})")

            # Étape 2: Déplacement vers corbeille
            files_to_trash = [photo['nef_path']]
            if photo['has_xmp']:
                files_to_trash.append(photo['xmp_path'])
                xmp_size = os.path.getsize(photo['xmp_path'])
            else:
                xmp_size = 0

            total_original_size = photo['size'] + xmp_size
            saved = total_original_size - jpeg_size

            if self.dry_run:
                print(f"  → Déplacerait {len(files_to_trash)} fichier(s) vers corbeille")
                print(f"  💾 Économie: {self._format_size(saved)}")
            else:
                success = True
                for file_path in files_to_trash:
                    if not self.move_to_trash(file_path):
                        success = False
                        errors += 1
                        break

                if success:
                    print(f"  ✓ {len(files_to_trash)} fichier(s) déplacé(s) vers corbeille")
                    print(f"  💾 Économie: {self._format_size(saved)}")
                else:
                    print(f"  ❌ ERREUR lors du déplacement")
                    continue

            space_saved += saved
            processed += 1

        return processed, space_saved, errors

    @staticmethod
    def _format_size(bytes: int) -> str:
        """Formate une taille en bytes de manière lisible"""
        for unit in ['o', 'Ko', 'Mo', 'Go']:
            if bytes < 1024.0:
                return f"{bytes:.2f} {unit}"
            bytes /= 1024.0
        return f"{bytes:.2f} To"

    def run(self):
        """Exécute l'optimisation"""
        print("=" * 70)
        print("📸 Darktable Storage Optimizer pour Google Drive")
        print("=" * 70)
        print(f"Dossier racine: {self.root_dir}")
        print(f"Dossier corbeille: {self.trash_folder}")
        print(f"Qualité JPEG: {self.jpeg_quality}")
        print(f"Mode: {'🔍 SIMULATION (dry-run)' if self.dry_run else '⚠️  RÉEL'}")
        print("=" * 70)

        processed, space_saved, errors = self.process_photos()

        print("\n" + "=" * 70)
        print("📊 RÉSUMÉ")
        print("=" * 70)
        print(f"Photos traitées: {processed}")
        print(f"Erreurs: {errors}")

        if self.dry_run:
            print(f"💾 Espace qui serait économisé: {self._format_size(space_saved)}")
            print("\n💡 Pour exécuter réellement, utilisez --execute")
        else:
            print(f"💾 Espace économisé: {self._format_size(space_saved)}")
            print(f"\n📁 Fichiers déplacés dans: {self.trash_folder}")
            print("💡 Vous pouvez récupérer les fichiers depuis la corbeille si nécessaire")

        print("=" * 70)


def main():
    parser = argparse.ArgumentParser(
        description="Optimise l'espace de stockage des photos darktable sur Google Drive",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:

  # Simulation (dry-run, aucun fichier modifié)
  %(prog)s /chemin/vers/photos

  # Exécution réelle
  %(prog)s /chemin/vers/photos --execute

  # Avec qualité JPEG personnalisée
  %(prog)s /chemin/vers/photos --execute --jpeg-quality 90

  # Avec dossier corbeille personnalisé
  %(prog)s /chemin/vers/photos --execute --trash-folder /autre/corbeille
        """
    )

    parser.add_argument(
        'directory',
        help="Dossier racine contenant les photos à traiter"
    )
    parser.add_argument(
        '--execute',
        action='store_true',
        help="Exécute réellement les conversions et déplacements (sinon mode simulation)"
    )
    parser.add_argument(
        '--jpeg-quality',
        type=int,
        default=95,
        choices=range(80, 101),
        metavar='80-100',
        help="Qualité JPEG (80-100, défaut: 95)"
    )
    parser.add_argument(
        '--trash-folder',
        help="Dossier corbeille personnalisé (défaut: .corbeille dans le dossier racine)"
    )

    args = parser.parse_args()

    # Confirmation pour mode réel
    if args.execute:
        print("\n⚠️  MODE RÉEL: Les fichiers NEF/XMP seront déplacés vers la corbeille!")
        print(f"📁 Dossier à traiter: {args.directory}")
        response = input("\nÊtes-vous sûr de vouloir continuer? (oui/non): ")
        if response.lower() not in ['oui', 'yes', 'o', 'y']:
            print("❌ Opération annulée.")
            return

    try:
        optimizer = DarktableStorageOptimizer(
            root_dir=args.directory,
            dry_run=not args.execute,
            jpeg_quality=args.jpeg_quality,
            trash_folder=args.trash_folder
        )
        optimizer.run()
    except KeyboardInterrupt:
        print("\n\n⚠️  Opération interrompue par l'utilisateur.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Erreur: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()

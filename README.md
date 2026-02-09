# Darktable Storage Optimizer pour Google Drive

Optimisez l'espace de stockage de vos photos darktable sur Google Drive en convertissant automatiquement les fichiers RAW (.NEF) sans étoiles en JPEG haute qualité.

## Fonctionnalités

- Lit les ratings (étoiles) directement depuis les fichiers XMP de darktable
- Conserve tous les fichiers .NEF des photos avec étoiles (⭐)
- Convertit les photos sans étoiles en JPEG haute qualité
- Applique automatiquement les retouches darktable lors de la conversion
- Déplace les fichiers NEF/XMP vers une corbeille (sécurité maximale)
- Mode simulation (dry-run) par défaut
- Statistiques détaillées sur l'espace économisé

## Prérequis

### Python 3
Le script nécessite Python 3.6 ou supérieur.

### Outils de conversion (au moins un)

**Option 1 : darktable-cli (recommandé)**
```bash
# Debian/Ubuntu
sudo apt install darktable

# Fedora
sudo dnf install darktable

# macOS
brew install darktable
```

**Option 2 : ImageMagick (alternative)**
```bash
# Debian/Ubuntu
sudo apt install imagemagick

# Fedora
sudo dnf install ImageMagick

# macOS
brew install imagemagick
```

## Installation

```bash
# Clonez ou téléchargez le script
git clone <url> darktable_storage_optimizer
cd darktable_storage_optimizer

# Rendez le script exécutable
chmod +x darktable_storage_optimizer.py
```

## Utilisation

### Simulation (recommandé pour le premier essai)

```bash
# Simule les opérations sans modifier les fichiers
python3 darktable_storage_optimizer.py /chemin/vers/vos/photos
```

Exemple de sortie:
```
======================================================================
📸 Darktable Storage Optimizer pour Google Drive
======================================================================
Dossier racine: /home/user/Google Drive/Photos
Dossier corbeille: /home/user/Google Drive/Photos/.corbeille
Qualité JPEG: 95
Mode: 🔍 SIMULATION (dry-run)
======================================================================

Scan du dossier: /home/user/Google Drive/Photos
  Trouvé 245 fichier(s) NEF
  Trouvé 187 fichier(s) XMP associé(s)

📊 Statistiques:
  Photos avec étoiles (⭐): 48 (conservées en NEF)
  Photos sans étoiles: 197 (à traiter)

...

💾 Espace qui serait économisé: 8.45 Go
```

### Exécution réelle

```bash
# Exécute les conversions et déplacements
python3 darktable_storage_optimizer.py /chemin/vers/vos/photos --execute
```

### Options avancées

```bash
# Qualité JPEG personnalisée (80-100)
python3 darktable_storage_optimizer.py /chemin/vers/photos --execute --jpeg-quality 90

# Dossier corbeille personnalisé
python3 darktable_storage_optimizer.py /chemin/vers/photos --execute --trash-folder /backup/corbeille

# Afficher l'aide
python3 darktable_storage_optimizer.py --help
```

## Workflow recommandé pour Google Drive

### 1. Première exécution (simulation)

```bash
# Test sur un sous-dossier d'abord
python3 darktable_storage_optimizer.py ~/GoogleDrive/Photos/2024
```

Vérifiez les statistiques affichées.

### 2. Exécution réelle

```bash
# Exécutez sur le dossier de test
python3 darktable_storage_optimizer.py ~/GoogleDrive/Photos/2024 --execute
```

### 3. Vérification

- Vérifiez que les JPEG sont corrects
- Les fichiers NEF/XMP sont dans `.corbeille`
- Google Drive synchronise les changements

### 4. Nettoyage de la corbeille

Une fois satisfait (après quelques jours) :

```bash
# Supprimez définitivement la corbeille
rm -rf ~/GoogleDrive/Photos/.corbeille
```

### 5. Exécution sur toute la bibliothèque

```bash
# Appliquez à tous vos dossiers
python3 darktable_storage_optimizer.py ~/GoogleDrive/Photos --execute
```

## Comment ça marche ?

1. **Scan** : Le script parcourt tous les fichiers .NEF du dossier
2. **Lecture XMP** : Pour chaque NEF, il lit le fichier XMP associé pour trouver le rating
3. **Filtrage** : Sépare les photos avec étoiles (conservées) et sans étoiles (à traiter)
4. **Conversion** : Pour les photos sans étoiles :
   - Convertit en JPEG avec darktable-cli (applique les retouches XMP)
   - Ou utilise ImageMagick si darktable-cli n'est pas disponible
5. **Sécurité** : Vérifie que le JPEG est créé avant de déplacer les originaux
6. **Corbeille** : Déplace NEF + XMP vers `.corbeille` en préservant la structure

## Structure de la corbeille

La corbeille préserve l'arborescence originale :

```
Photos/
├── 2024/
│   ├── Janvier/
│   │   ├── IMG_001.jpg      (nouveau JPEG)
│   │   └── IMG_002.NEF      (photo avec étoiles, conservée)
│   └── .corbeille/
│       └── Janvier/
│           ├── IMG_001.NEF  (déplacé)
│           └── IMG_001.NEF.xmp (déplacé)
```

## Sécurité

Le script est conçu avec la sécurité maximale :

- **Dry-run par défaut** : Aucune modification sans `--execute`
- **Corbeille** : Fichiers déplacés, pas supprimés
- **Vérifications** : Le JPEG doit être créé avant déplacement du NEF
- **Conservation structure** : Arborescence préservée dans la corbeille
- **Confirmation** : Demande de confirmation en mode réel

## Restauration

Pour restaurer un fichier depuis la corbeille :

```bash
# Retrouvez le fichier
find .corbeille -name "IMG_001.NEF"

# Déplacez-le vers son emplacement original
mv .corbeille/2024/Janvier/IMG_001.NEF 2024/Janvier/
mv .corbeille/2024/Janvier/IMG_001.NEF.xmp 2024/Janvier/
```

## FAQ

### Le script va-t-il modifier mes photos avec étoiles ?
Non, jamais. Les photos avec étoiles (rating > 0 dans XMP) sont complètement ignorées.

### Et si une photo n'a pas de fichier XMP ?
Elle sera considérée comme ayant 0 étoiles et donc traitée (convertie en JPEG).

### Quelle est la différence de taille ?
En moyenne, un JPEG haute qualité (95) représente 10-15% de la taille du NEF original.
Pour 100 Go de NEF, vous économiserez environ 85-90 Go.

### Puis-je annuler après avoir exécuté ?
Oui ! Tous les fichiers sont dans `.corbeille`. Vous pouvez les restaurer manuellement ou simplement ne pas supprimer la corbeille.

### Le script fonctionne-t-il avec d'autres formats RAW ?
Actuellement, seul .NEF est supporté. Pour CR2, ARW, etc., modifiez la ligne 123 :
```python
if filename.upper().endswith(('.NEF', '.CR2', '.ARW')):
```

### Que faire si darktable-cli et ImageMagick ne sont pas installés ?
Installez au moins un des deux (voir section Prérequis). darktable-cli est recommandé car il applique correctement les retouches XMP.

## Dépannage

### "Base de données darktable non trouvée"
Ce message n'apparaît plus avec cette version. Le script lit directement les XMP.

### "Erreur lecture XMP"
Le fichier XMP peut être corrompu. La photo sera traitée comme ayant 0 étoiles.

### "Timeout lors de la conversion"
La conversion d'un RAW peut prendre du temps. Le timeout est fixé à 120s par photo.

## Statistiques

Après exécution, le script affiche :
- Nombre de photos avec/sans étoiles
- Nombre de photos traitées
- Espace économisé
- Nombre d'erreurs éventuelles

## Licence

MIT License - Utilisez librement

## Contribuer

Améliorations bienvenues :
- Support d'autres formats RAW
- Interface graphique
- Intégration avec d'autres gestionnaires de photos

## Avertissement

Bien que le script soit conçu avec sécurité maximale (corbeille), faites toujours une sauvegarde avant de traiter une grande bibliothèque de photos !

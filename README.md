# Darktable Storage Optimizer

Optimise l'espace de stockage pour les photos darktable en convertissant automatiquement les photos sans étoiles en JPEG haute qualité, tout en conservant les photos importantes en RAW.

## Problème

Les photographes utilisant darktable accumulent des centaines de gigaoctets de fichiers RAW (.NEF), mais seulement une fraction de ces photos méritent d'être conservées en RAW. La synchronisation avec Google Drive devient coûteuse en stockage.

## Solution

Cet outil automatise le processus :
- ✅ Lit les ratings depuis la base de données darktable
- ⭐ **Conserve** les photos avec étoiles en RAW (haute qualité)
- 📸 **Convertit** les photos sans étoiles en JPEG 95% (économie d'espace)
- 🎨 Préserve tous les développements darktable (balance des blancs, exposition, etc.)
- 🗑️ Déplace les fichiers originaux dans `.corbeille` (sécurité)
- ⏱️ Métriques de performance détaillées

## Résultats réels

**Année 2024 :**
- 8,588 photos NEF analysées
- 1,002 photos avec étoiles conservées en RAW
- 7,586 photos converties en JPEG
- **353 Go économisés** 💾

**Année 2026 (tests) :**
- 91 photos converties
- 2.46 Go économisés
- 0 erreur
- Qualité JPEG préservée avec tous les développements

## Installation

### Prérequis

- Python 3.6+
- Darktable installé via Flatpak
- Fichiers XMP exportés depuis darktable (pour appliquer les développements)

### Installation des dépendances

```bash
# Darktable via Flatpak (recommandé)
flatpak install flathub org.darktable.Darktable

# Le script utilise uniquement des modules Python standard
```

## Utilisation

### Mode simulation (dry-run)

Analyse sans modifier les fichiers :

```bash
python3 darktable_storage_optimizer.py /chemin/vers/photos
```

### Mode réel

Convertit et déplace réellement les fichiers :

```bash
python3 darktable_storage_optimizer.py /chemin/vers/photos --execute
```

### Options avancées

```bash
# Qualité JPEG personnalisée (80-100)
python3 darktable_storage_optimizer.py /chemin/vers/photos --execute --jpeg-quality 90

# Mode automatique sans confirmation
python3 darktable_storage_optimizer.py /chemin/vers/photos --execute --yes

# Dossier corbeille personnalisé
python3 darktable_storage_optimizer.py /chemin/vers/photos --execute --trash-folder /backup/corbeille

# Forcer l'utilisation des XMP au lieu de la base darktable
python3 darktable_storage_optimizer.py /chemin/vers/photos --execute --force-xmp
```

### Traitement par lots

Le script `batch_optimize.sh` permet de traiter plusieurs dossiers interactivement :

```bash
# Simulation sur tous les dossiers de 2024
./batch_optimize.sh /home/user/Images/2024 --dry-run

# Traitement interactif
./batch_optimize.sh /home/user/Images/2024
```

## Exemple de sortie

```
======================================================================
📸 Darktable Storage Optimizer pour Google Drive
======================================================================
Dossier racine: /home/steph/Images/2026/02 -Février/07- Match Volley Puylaurens
Qualité JPEG: 95
Source ratings: 📁 Base darktable
Mode: ⚠️  RÉEL
======================================================================

Scan du dossier...
  Trouvé 143 fichier(s) NEF
  Trouvé 143 fichier(s) XMP associé(s)

📊 Statistiques:
  Photos avec étoiles (⭐): 76 (conservées en NEF)
  Photos sans étoiles: 67 (à traiter)

[1/67] ./_STE7417.NEF
  → Conversion en JPEG...
  ✓ JPEG créé (23.97 Mo)
  ✓ 2 fichier(s) déplacé(s) vers corbeille
  💾 Économie: 29.28 Mo

... [66 autres photos] ...

======================================================================
📊 RÉSUMÉ
======================================================================
Photos traitées: 67
Erreurs: 0
💾 Espace économisé: 2.10 Go

⏱️  Performance:
  Temps total: 5m 23s
  Temps de conversion: 4m 51s
  Temps opérations fichiers: 12.3s
  Moyenne par photo: 4.8s

📁 Fichiers déplacés dans: .corbeille
💡 Vous pouvez récupérer les fichiers depuis la corbeille si nécessaire
======================================================================
```

## Fonctionnement technique

### Lecture des ratings

L'outil lit les ratings de deux manières (par ordre de priorité) :

1. **Base de données darktable** (plus rapide) :
   - Lit directement depuis `library.db`
   - Cache tous les ratings en mémoire
   - Fonctionne avec darktable Flatpak

2. **Fichiers XMP** (fallback) :
   - Parse les fichiers `.xmp` individuellement
   - Lit le tag `xmp:Rating`

### Conversion JPEG

- Utilise `flatpak run --command=darktable-cli org.darktable.Darktable`
- Garantit la compatibilité avec darktable 5.0
- Applique automatiquement les développements depuis les XMP
- Qualité JPEG par défaut : 95%

### Sécurité

- Mode simulation par défaut
- Confirmation avant exécution réelle
- Fichiers déplacés vers `.corbeille` (pas supprimés)
- Structure de dossiers préservée dans la corbeille

## Récupération depuis la corbeille

Si vous voulez annuler une opération :

```bash
# Restaure tous les fichiers d'un dossier
cp -r /chemin/vers/photos/.corbeille/* /chemin/vers/photos/

# Supprime les JPEG créés
find /chemin/vers/photos -name "*.jpg" -delete
```

## Limitations

- **IMPORTANT** : Exporter les XMP depuis darktable AVANT de lancer l'outil
- Nécessite darktable installé (pour darktable-cli)
- Fonctionne uniquement avec les fichiers .NEF (Nikon)
- Les fichiers sans XMP ni rating dans la base sont considérés comme 0 étoile

## Export des XMP depuis darktable

Dans darktable :
1. Sélectionnez toutes les photos (Ctrl+A)
2. Menu : `Fichier` → `Exporter` → `Exporter les sidecars`
3. Ou : Table lumineuse → Bouton droit → `Écrire les fichiers sidecar`

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

## Licence

MIT License - Libre d'utilisation et de modification

## Auteur

Créé avec l'aide de Claude Code pour optimiser le stockage photo sur Google Drive.

---

**⚠️  Rappel** : Testez d'abord sur un petit dossier, vérifiez la qualité des JPEG, puis traitez l'ensemble de votre bibliothèque.

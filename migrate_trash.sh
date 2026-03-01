#!/bin/bash
#
# Migration des anciennes corbeilles locales vers la corbeille centralisée
# Préserve l'arborescence complète
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

IMAGES_ROOT="/home/steph/Images"
CENTRAL_TRASH="$IMAGES_ROOT/.corbeille"

echo "======================================================================"
echo "          Migration vers la corbeille centralisée"
echo "======================================================================"
echo ""
echo -e "${BLUE}Racine Images:${NC} $IMAGES_ROOT"
echo -e "${BLUE}Corbeille centralisée:${NC} $CENTRAL_TRASH"
echo ""

# Crée la corbeille centralisée si elle n'existe pas
mkdir -p "$CENTRAL_TRASH"

# Trouve toutes les corbeilles locales
local_trashes=$(find "$IMAGES_ROOT" -type d -name ".corbeille" ! -path "$CENTRAL_TRASH" 2>/dev/null)

if [[ -z "$local_trashes" ]]; then
    echo -e "${GREEN}✓ Aucune corbeille locale à migrer${NC}"
    exit 0
fi

echo "Corbeilles locales trouvées:"
echo ""

count=0
while IFS= read -r trash; do
    count=$((count + 1))
    rel_path="${trash#$IMAGES_ROOT/}"
    rel_path="${rel_path%/.corbeille}"
    
    file_count=$(find "$trash" -type f 2>/dev/null | wc -l)
    size=$(du -sh "$trash" 2>/dev/null | cut -f1)
    
    echo -e "  ${YELLOW}[$count]${NC} $rel_path"
    echo "      → $file_count fichiers, $size"
done <<< "$local_trashes"

echo ""
echo "======================================================================"
read -p "Migrer ces corbeilles vers la corbeille centralisée? (oui/non): " confirm

if [[ "$confirm" != "oui" ]]; then
    echo "Annulé."
    exit 0
fi

echo ""
echo "Migration en cours..."
echo ""

migrated=0
while IFS= read -r trash; do
    # Calcule le chemin relatif depuis Images
    rel_path="${trash#$IMAGES_ROOT/}"
    rel_path="${rel_path%/.corbeille}"
    
    # Destination dans la corbeille centralisée
    dest="$CENTRAL_TRASH/$rel_path"
    
    echo -e "${BLUE}→${NC} Migration de: $rel_path"
    
    # Crée le dossier de destination
    mkdir -p "$dest"
    
    # Déplace tous les fichiers
    if find "$trash" -mindepth 1 -maxdepth 1 -exec mv -t "$dest" {} + 2>/dev/null; then
        # Supprime le dossier .corbeille vide
        rmdir "$trash" 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} Migré"
        migrated=$((migrated + 1))
    else
        echo -e "  ${RED}✗${NC} Erreur"
    fi
done <<< "$local_trashes"

echo ""
echo "======================================================================"
echo -e "${GREEN}✓ Migration terminée${NC}"
echo -e "${GREEN}✓ $migrated corbeille(s) migré(es)${NC}"
echo ""
echo "Tous les fichiers sont maintenant dans:"
echo "  $CENTRAL_TRASH"
echo ""

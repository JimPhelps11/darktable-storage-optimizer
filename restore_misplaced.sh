#!/bin/bash
#
# Restaure les fichiers mal placés à la racine de .corbeille
# vers leur emplacement d'origine
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TRASH_ROOT="/home/steph/Images/.corbeille"
IMAGES_ROOT="/home/steph/Images"

echo "======================================================================"
echo "          Restauration des fichiers mal placés"
echo "======================================================================"
echo ""

# Compte les fichiers NEF à la racine de .corbeille
misplaced_files=$(find "$TRASH_ROOT" -maxdepth 1 -name "*.NEF" -o -maxdepth 1 -name "*.xmp" 2>/dev/null | wc -l)

if [[ $misplaced_files -eq 0 ]]; then
    echo -e "${GREEN}✓ Aucun fichier mal placé trouvé${NC}"
    exit 0
fi

echo -e "${YELLOW}Fichiers mal placés trouvés: $misplaced_files${NC}"
echo ""

# Liste les fichiers NEF mal placés
echo "Fichiers à restaurer:"
find "$TRASH_ROOT" -maxdepth 1 -name "*.NEF" 2>/dev/null | while read nef_file; do
    basename "$nef_file"
done | head -10
if [[ $misplaced_files -gt 10 ]]; then
    echo "... et $((misplaced_files - 10)) autres"
fi

echo ""
echo "======================================================================"
read -p "Restaurer ces fichiers vers leur emplacement d'origine? (oui/non): " confirm

if [[ "$confirm" != "oui" ]]; then
    echo "Annulé."
    exit 0
fi

echo ""
echo "Restauration en cours..."
echo ""

restored=0
failed=0

# Traite chaque fichier NEF
find "$TRASH_ROOT" -maxdepth 1 -name "*.NEF" 2>/dev/null | while read nef_file; do
    filename=$(basename "$nef_file")
    xmp_file="${nef_file}.xmp"
    
    # Cherche le fichier JPEG correspondant dans l'arborescence
    jpeg_name="${filename%.NEF}.jpg"
    jpeg_file=$(find "$IMAGES_ROOT" -name "$jpeg_name" 2>/dev/null | head -1)
    
    if [[ -n "$jpeg_file" ]]; then
        # Trouve le dossier d'origine (là où est le JPEG)
        original_dir=$(dirname "$jpeg_file")
        
        echo -e "${BLUE}→${NC} Restauration de $filename"
        echo "   vers: $original_dir"
        
        # Supprime le JPEG créé
        rm -f "$jpeg_file"
        
        # Restaure le NEF
        mv "$nef_file" "$original_dir/"
        
        # Restaure le XMP si présent
        if [[ -f "$xmp_file" ]]; then
            mv "$xmp_file" "$original_dir/"
        fi
        
        echo -e "   ${GREEN}✓${NC} Restauré"
        ((restored++))
    else
        echo -e "${RED}✗${NC} Impossible de trouver l'emplacement d'origine pour $filename"
        ((failed++))
    fi
done

echo ""
echo "======================================================================"
echo -e "${GREEN}✓ Restauration terminée${NC}"
echo -e "${GREEN}✓ $restored fichier(s) restauré(s)${NC}"
if [[ $failed -gt 0 ]]; then
    echo -e "${RED}⚠️  $failed fichier(s) non restauré(s)${NC}"
fi
echo ""

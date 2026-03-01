#!/bin/bash
#
# Script de nettoyage de la corbeille darktable
# Supprime les fichiers de la corbeille de manière interactive ou automatique
#
# Usage:
#   ./clean_trash.sh                    # Mode interactif
#   ./clean_trash.sh --auto             # Suppression automatique
#   ./clean_trash.sh --dry-run          # Simulation
#   ./clean_trash.sh --older-than 30    # Supprime les fichiers > 30 jours
#

set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration par défaut
TRASH_DIR=""
DRY_RUN=false
AUTO_MODE=false
OLDER_THAN_DAYS=0

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run|--simulate)
            DRY_RUN=true
            ;;
        --auto|-y|--yes)
            AUTO_MODE=true
            ;;
        --older-than=*)
            OLDER_THAN_DAYS="${arg#*=}"
            ;;
        *)
            # Si c'est un chemin, on l'utilise comme trash_dir
            if [[ -d "$arg" ]]; then
                TRASH_DIR="$arg"
            fi
            ;;
    esac
done

# Fonction pour trouver la corbeille
find_trash_dir() {
    # Si déjà spécifié, on l'utilise
    if [[ -n "$TRASH_DIR" ]]; then
        echo "$TRASH_DIR"
        return
    fi

    # Cherche dans les emplacements standards
    local possible_paths=(
        "/home/steph/Images/.corbeille"
        "$HOME/Images/.corbeille"
        "$(pwd)/.corbeille"
    )

    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return
        fi
    done

    # Pas trouvé
    echo ""
}

# Fonction pour formater la taille
format_size() {
    local size=$1
    if [[ $size -lt 1024 ]]; then
        echo "${size} o"
    elif [[ $size -lt $((1024*1024)) ]]; then
        echo "$(( size / 1024 )) Ko"
    elif [[ $size -lt $((1024*1024*1024)) ]]; then
        echo "$(( size / 1024 / 1024 )) Mo"
    else
        echo "$(( size / 1024 / 1024 / 1024 )) Go"
    fi
}

# Trouve la corbeille
TRASH_DIR=$(find_trash_dir)

if [[ -z "$TRASH_DIR" ]]; then
    echo -e "${RED}❌ Aucune corbeille trouvée${NC}"
    echo "Spécifiez le chemin avec: $0 /chemin/vers/.corbeille"
    exit 1
fi

if [[ ! -d "$TRASH_DIR" ]]; then
    echo -e "${RED}❌ Corbeille non trouvée: $TRASH_DIR${NC}"
    exit 1
fi

# Compte les fichiers
total_files=$(find "$TRASH_DIR" -type f 2>/dev/null | wc -l)
total_size=$(du -sb "$TRASH_DIR" 2>/dev/null | cut -f1)

echo "======================================================================"
echo "          Nettoyage de la corbeille darktable"
if [[ "$DRY_RUN" == true ]]; then
    echo "                    MODE SIMULATION"
fi
echo "======================================================================"
echo ""
echo -e "${BLUE}Corbeille:${NC} $TRASH_DIR"
echo -e "${BLUE}Fichiers:${NC} $total_files"
echo -e "${BLUE}Taille totale:${NC} $(format_size $total_size)"
echo ""

if [[ $total_files -eq 0 ]]; then
    echo -e "${GREEN}✓ La corbeille est déjà vide${NC}"
    exit 0
fi

# Affiche le détail par sous-dossier (années)
echo "Détail par année:"
echo ""

for year_dir in "$TRASH_DIR"/*; do
    if [[ -d "$year_dir" ]]; then
        year=$(basename "$year_dir")
        year_files=$(find "$year_dir" -type f 2>/dev/null | wc -l)
        year_size=$(du -sb "$year_dir" 2>/dev/null | cut -f1)

        if [[ $year_files -gt 0 ]]; then
            echo -e "  ${YELLOW}$year${NC}: $year_files fichiers, $(format_size $year_size)"
        fi
    fi
done

echo ""
echo "======================================================================"

# Filtre par date si demandé
if [[ $OLDER_THAN_DAYS -gt 0 ]]; then
    old_files=$(find "$TRASH_DIR" -type f -mtime +$OLDER_THAN_DAYS 2>/dev/null | wc -l)
    echo ""
    echo -e "${YELLOW}Mode: Suppression des fichiers de plus de $OLDER_THAN_DAYS jours${NC}"
    echo -e "${BLUE}Fichiers concernés:${NC} $old_files"

    if [[ $old_files -eq 0 ]]; then
        echo -e "${GREEN}✓ Aucun fichier à supprimer${NC}"
        exit 0
    fi

    total_files=$old_files
fi

# Confirmation
if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo -e "${GREEN}MODE SIMULATION: Aucun fichier ne sera supprimé${NC}"
    echo ""
    echo "Pour supprimer réellement:"
    echo "  $0"
    echo ""
    exit 0
fi

if [[ "$AUTO_MODE" == false ]]; then
    echo ""
    echo -e "${RED}⚠️  ATTENTION: Cette opération est IRRÉVERSIBLE${NC}"
    echo ""
    read -p "Voulez-vous vraiment supprimer ces $total_files fichiers? (oui/non): " confirm

    if [[ "$confirm" != "oui" ]]; then
        echo -e "${YELLOW}Annulé.${NC}"
        exit 0
    fi
fi

# Suppression
echo ""
echo "Suppression en cours..."

if [[ $OLDER_THAN_DAYS -gt 0 ]]; then
    # Supprime uniquement les fichiers anciens
    find "$TRASH_DIR" -type f -mtime +$OLDER_THAN_DAYS -delete 2>/dev/null
    # Supprime les dossiers vides
    find "$TRASH_DIR" -type d -empty -delete 2>/dev/null
else
    # Supprime tout le contenu
    rm -rf "${TRASH_DIR:?}"/*
fi

echo -e "${GREEN}✓ Corbeille nettoyée avec succès${NC}"
echo -e "${GREEN}✓ $(format_size $total_size) libérés${NC}"
echo ""

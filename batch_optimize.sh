#!/bin/bash
#
# Darktable Batch Storage Optimizer
# Script interactif pour traiter plusieurs dossiers d'un coup
#
# Usage:
#   ./batch_optimize.sh [BASE_DIR] [--dry-run|--simulate]
#   ./batch_optimize.sh --dry-run [BASE_DIR]
#

set -e

# Parse arguments
DRY_RUN=false
BASE_DIR="/home/steph/Images/2026"

for arg in "$@"; do
    if [[ "$arg" == "--dry-run" || "$arg" == "--simulate" ]]; then
        DRY_RUN=true
    elif [[ -d "$arg" ]]; then
        BASE_DIR="$arg"
    fi
done

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTIMIZER_SCRIPT="$SCRIPT_DIR/darktable_storage_optimizer.py"
TEMP_DIR="/tmp/darktable_batch_$$"

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Vérifications
if [ ! -f "$OPTIMIZER_SCRIPT" ]; then
    echo -e "${RED}Erreur: Script optimizer non trouvé: $OPTIMIZER_SCRIPT${NC}"
    exit 1
fi

if [ ! -d "$BASE_DIR" ]; then
    echo -e "${RED}Erreur: Dossier de base non trouvé: $BASE_DIR${NC}"
    exit 1
fi

mkdir -p "$TEMP_DIR"
trap "rm -rf '$TEMP_DIR'" EXIT

echo "======================================================================="
echo "          Darktable Batch Storage Optimizer"
if [ "$DRY_RUN" = true ]; then
    echo "                    MODE SIMULATION"
fi
echo "======================================================================="
echo ""
echo "Scan du dossier: $BASE_DIR"
echo ""

# Trouve tous les dossiers contenant des fichiers NEF
echo -e "${BLUE}Recherche des dossiers contenant des fichiers NEF...${NC}"
folders=()
while IFS= read -r -d '' folder; do
    nef_count=$(find "$folder" -maxdepth 1 -name "*.NEF" -o -name "*.nef" 2>/dev/null | wc -l)
    if [ "$nef_count" -gt 0 ]; then
        folders+=("$folder")
    fi
done < <(find "$BASE_DIR" -type d -print0 | sort -z)

if [ ${#folders[@]} -eq 0 ]; then
    echo -e "${YELLOW}Aucun dossier avec des fichiers NEF trouvé.${NC}"
    exit 0
fi

echo -e "${GREEN}Trouvé ${#folders[@]} dossier(s) avec des NEF${NC}"
echo ""

# Analyse chaque dossier en mode dry-run
echo -e "${BLUE}Analyse des dossiers (cela peut prendre un moment)...${NC}"
echo ""

declare -A folder_stats
folder_index=0

for folder in "${folders[@]}"; do
    folder_index=$((folder_index + 1))
    echo -ne "\rAnalyse du dossier $folder_index/${#folders[@]}..."

    # Lance l'optimizer en mode dry-run et capture la sortie
    output=$(python3 "$OPTIMIZER_SCRIPT" "$folder" 2>/dev/null || echo "ERROR")

    if [[ "$output" == "ERROR" ]]; then
        continue
    fi

    # Extrait les statistiques
    with_stars=$(echo "$output" | grep -oP 'Photos avec étoiles.*:\s*\K\d+' || echo "0")
    without_stars=$(echo "$output" | grep -oP 'Photos sans étoiles:\s*\K\d+' || echo "0")
    space_saved=$(echo "$output" | grep -oP 'Espace qui serait économisé:\s*\K[0-9.]+\s*[A-Za-z]+' || echo "0 o")

    # Ne garde que les dossiers avec des photos à traiter
    if [ "$without_stars" -gt 0 ]; then
        folder_stats["$folder"]="$with_stars|$without_stars|$space_saved"
    fi
done

echo -e "\r${GREEN}Analyse terminée!${NC}                                        "
echo ""

# Affiche les dossiers avec statistiques
if [ ${#folder_stats[@]} -eq 0 ]; then
    echo -e "${YELLOW}Aucun dossier à traiter (toutes les photos ont déjà des étoiles).${NC}"
    exit 0
fi

echo "======================================================================="
echo "Dossiers disponibles pour optimisation:"
echo "======================================================================="
echo ""

folder_list=()
folder_index=0

for folder in "${!folder_stats[@]}"; do
    IFS='|' read -r with_stars without_stars space_saved <<< "${folder_stats[$folder]}"
    folder_list+=("$folder")
    folder_index=$((folder_index + 1))

    # Affiche le chemin relatif pour plus de clarté
    rel_path="${folder#$BASE_DIR/}"

    printf "${BLUE}[%2d]${NC} %s\n" "$folder_index" "$rel_path"
    printf "     → ${GREEN}%d photos avec étoiles${NC} (conservées en RAW)\n" "$with_stars"
    printf "     → ${YELLOW}%d photos sans étoiles${NC} (à convertir en JPEG)\n" "$without_stars"
    printf "     → ${GREEN}Économie: %s${NC}\n" "$space_saved"
    echo ""
done

echo "======================================================================="
echo ""

# Si mode dry-run, affiche le résumé et quitte
if [ "$DRY_RUN" = true ]; then
    echo "RÉSUMÉ SIMULATION"
    echo "======================================================================="
    echo ""

    total_folders=${#folder_stats[@]}
    total_with_stars=0
    total_without_stars=0

    for folder in "${!folder_stats[@]}"; do
        IFS='|' read -r with_stars without_stars space_saved <<< "${folder_stats[$folder]}"
        total_with_stars=$((total_with_stars + with_stars))
        total_without_stars=$((total_without_stars + without_stars))
    done

    echo -e "${BLUE}Dossiers à optimiser:${NC} $total_folders"
    echo -e "${GREEN}Photos à conserver en RAW (avec étoiles):${NC} $total_with_stars"
    echo -e "${YELLOW}Photos à convertir en JPEG (sans étoiles):${NC} $total_without_stars"
    echo -e "${GREEN}Total photos:${NC} $((total_with_stars + total_without_stars))"
    echo ""
    echo "Pour lancer le traitement réel, exécutez le script sans --dry-run"
    echo ""
    echo "======================================================================="
    exit 0
fi

# Demande la sélection
echo -e "${YELLOW}Quels dossiers voulez-vous traiter ?${NC}"
echo ""
echo "  - Tapez les numéros séparés par des virgules (ex: 1,3,5)"
echo "  - Tapez un intervalle (ex: 1-5)"
echo "  - Tapez 'all' pour tous"
echo "  - Tapez 'q' pour quitter"
echo ""
read -p "Votre choix: " selection

if [[ "$selection" == "q" ]]; then
    echo "Annulé."
    exit 0
fi

# Parse la sélection
selected_folders=()

if [[ "$selection" == "all" ]]; then
    selected_folders=("${folder_list[@]}")
else
    # Parse les numéros et intervalles
    IFS=',' read -ra parts <<< "$selection"
    for part in "${parts[@]}"; do
        part=$(echo "$part" | xargs) # Trim whitespace

        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Intervalle
            start=${BASH_REMATCH[1]}
            end=${BASH_REMATCH[2]}
            for ((i=start; i<=end; i++)); do
                if [ $i -ge 1 ] && [ $i -le ${#folder_list[@]} ]; then
                    selected_folders+=("${folder_list[$((i-1))]}")
                fi
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            # Numéro simple
            index=$part
            if [ $index -ge 1 ] && [ $index -le ${#folder_list[@]} ]; then
                selected_folders+=("${folder_list[$((index-1))]}")
            fi
        fi
    done
fi

if [ ${#selected_folders[@]} -eq 0 ]; then
    echo -e "${RED}Aucun dossier sélectionné.${NC}"
    exit 0
fi

# Affiche le récapitulatif
echo ""
echo "======================================================================="
echo "RÉCAPITULATIF"
echo "======================================================================="
echo ""
echo -e "${YELLOW}${#selected_folders[@]} dossier(s) sélectionné(s):${NC}"
echo ""

total_with_stars=0
total_without_stars=0
total_space=0

for folder in "${selected_folders[@]}"; do
    IFS='|' read -r with_stars without_stars space_saved <<< "${folder_stats[$folder]}"
    rel_path="${folder#$BASE_DIR/}"

    echo "  - $rel_path"
    echo "    $without_stars photo(s) → JPEG, $with_stars photo(s) → RAW"

    total_with_stars=$((total_with_stars + with_stars))
    total_without_stars=$((total_without_stars + without_stars))
done

echo ""
echo -e "${GREEN}Total: $total_without_stars photos à convertir${NC}"
echo ""

# Confirmation finale
echo -e "${RED}⚠️  ATTENTION: Les fichiers NEF/XMP seront déplacés vers .corbeille${NC}"
echo ""
read -p "Voulez-vous continuer? (oui/non): " confirm

if [[ "$confirm" != "oui" ]]; then
    echo "Annulé."
    exit 0
fi

# Traitement
echo ""
echo "======================================================================="
echo "TRAITEMENT EN COURS"
echo "======================================================================="
echo ""

processed_folders=0
total_processed=0
total_errors=0
start_time=$(date +%s)

for folder in "${selected_folders[@]}"; do
    processed_folders=$((processed_folders + 1))
    rel_path="${folder#$BASE_DIR/}"

    echo ""
    echo "[$processed_folders/${#selected_folders[@]}] Traitement: $rel_path"
    echo "-------------------------------------------------------------------"

    # Lance le traitement réel
    if echo "oui" | python3 "$OPTIMIZER_SCRIPT" "$folder" --execute 2>&1 | tee "$TEMP_DIR/log_$processed_folders.txt"; then
        # Extrait les stats du traitement
        photos=$(grep -oP 'Photos traitées:\s*\K\d+' "$TEMP_DIR/log_$processed_folders.txt" || echo "0")
        errors=$(grep -oP 'Erreurs:\s*\K\d+' "$TEMP_DIR/log_$processed_folders.txt" || echo "0")

        total_processed=$((total_processed + photos))
        total_errors=$((total_errors + errors))

        if [ "$errors" -eq 0 ]; then
            echo -e "${GREEN}✓ Terminé avec succès${NC}"
        else
            echo -e "${YELLOW}⚠️  Terminé avec $errors erreur(s)${NC}"
        fi
    else
        echo -e "${RED}✗ Échec du traitement${NC}"
        total_errors=$((total_errors + 1))
    fi
done

end_time=$(date +%s)
duration=$((end_time - start_time))

# Rapport final
echo ""
echo "======================================================================="
echo "RAPPORT FINAL"
echo "======================================================================="
echo ""
echo "Dossiers traités: $processed_folders"
echo "Photos converties: $total_processed"
echo "Erreurs: $total_errors"
echo "Durée: ${duration}s"
echo ""

if [ $total_errors -eq 0 ]; then
    echo -e "${GREEN}✓ Tous les traitements ont réussi!${NC}"
else
    echo -e "${YELLOW}⚠️  Certains traitements ont échoué. Vérifiez les logs ci-dessus.${NC}"
fi

echo ""
echo "Les fichiers originaux sont dans les dossiers .corbeille de chaque dossier."
echo "Vous pouvez les supprimer une fois que vous avez vérifié les résultats."
echo ""
echo "======================================================================="

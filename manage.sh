#!/bin/bash
#
# Gestion des dossiers surveillés - folder-monitor
#
# Auteur: Xavier - XGR Solutions
# Version: 1.0
#
# Usage:
#   sudo ./manage.sh list            → Lister les dossiers surveillés
#   sudo ./manage.sh add /chemin     → Ajouter un dossier
#   sudo ./manage.sh remove /chemin  → Supprimer un dossier
#   sudo ./manage.sh status          → Voir le statut du service
#

set -e

SERVICE_FILE="/etc/systemd/system/folder-monitor.service"
SERVICE_NAME="folder-monitor"

# ─── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Vérifications préalables ──────────────────────────────────────────────────

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}⚠️  Ce script doit être exécuté en tant que root (sudo)${NC}"
        exit 1
    fi
}

check_installed() {
    if [[ ! -f "$SERVICE_FILE" ]]; then
        echo -e "${RED}❌ Le service folder-monitor n'est pas installé.${NC}"
        echo -e "   Exécutez d'abord ${CYAN}sudo ./install.sh${NC}"
        exit 1
    fi
}

# ─── Lecture / écriture de la config ──────────────────────────────────────────

get_current_folders() {
    grep '^Environment="WATCHED_FOLDERS=' "$SERVICE_FILE" \
        | sed 's/Environment="WATCHED_FOLDERS=//;s/"$//'
}

set_folders() {
    local new_value="$1"
    # Remplace la ligne WATCHED_FOLDERS dans le service file
    sed -i "s|^Environment=\"WATCHED_FOLDERS=.*\"|Environment=\"WATCHED_FOLDERS=$new_value\"|" "$SERVICE_FILE"
}

folders_to_array() {
    local folders_str="$1"
    IFS=',' read -ra arr <<< "$folders_str"
    echo "${arr[@]}"
}

# ─── Commandes ────────────────────────────────────────────────────────────────

cmd_list() {
    local folders_str
    folders_str=$(get_current_folders)

    echo
    echo -e "${BOLD}📂 Dossiers actuellement surveillés :${NC}"
    echo

    if [[ -z "$folders_str" ]]; then
        echo -e "  ${YELLOW}(aucun dossier configuré)${NC}"
    else
        local i=1
        IFS=',' read -ra folders <<< "$folders_str"
        for folder in "${folders[@]}"; do
            folder="${folder// /}"
            if [[ -d "$folder" ]]; then
                echo -e "  ${GREEN}$i. $folder${NC}"
            else
                echo -e "  ${YELLOW}$i. $folder ${RED}⚠ dossier introuvable${NC}"
            fi
            ((i++))
        done
    fi

    echo
    local status
    status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)
    if [[ "$status" == "active" ]]; then
        echo -e "  Service : ${GREEN}● actif${NC}"
    else
        echo -e "  Service : ${RED}● $status${NC}"
    fi
    echo
}

cmd_add() {
    local new_folder="$1"

    if [[ -z "$new_folder" ]]; then
        echo -e "${RED}❌ Usage : sudo ./manage.sh add /chemin/vers/dossier${NC}"
        exit 1
    fi

    # Normaliser (supprimer slash final)
    new_folder="${new_folder%/}"

    # Créer le dossier si inexistant
    if [[ ! -d "$new_folder" ]]; then
        echo -e "${YELLOW}⚠️  Le dossier $new_folder n'existe pas.${NC}"
        read -p "Voulez-vous le créer ? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$new_folder"
            echo -e "${GREEN}✓ Dossier créé${NC}"
        else
            echo -e "${RED}Abandon.${NC}"
            exit 0
        fi
    fi

    # Vérifier que le dossier n'est pas déjà surveillé
    local current
    current=$(get_current_folders)

    IFS=',' read -ra existing <<< "$current"
    for f in "${existing[@]}"; do
        f="${f// /}"
        if [[ "$f" == "$new_folder" ]]; then
            echo -e "${YELLOW}⚠️  Ce dossier est déjà surveillé.${NC}"
            exit 0
        fi
    done

    # Construire la nouvelle liste
    local updated
    if [[ -z "$current" ]]; then
        updated="$new_folder"
    else
        updated="$current,$new_folder"
    fi

    set_folders "$updated"

    systemctl daemon-reload
    systemctl restart "$SERVICE_NAME"

    echo
    echo -e "${GREEN}✅ Dossier ajouté et service redémarré :${NC}"
    echo -e "   ${CYAN}$new_folder${NC}"
    echo
    cmd_list
}

cmd_remove() {
    local target="$1"

    if [[ -z "$target" ]]; then
        echo -e "${RED}❌ Usage : sudo ./manage.sh remove /chemin/vers/dossier${NC}"
        exit 1
    fi

    target="${target%/}"

    local current
    current=$(get_current_folders)

    if [[ -z "$current" ]]; then
        echo -e "${YELLOW}⚠️  Aucun dossier surveillé.${NC}"
        exit 0
    fi

    # Reconstruire la liste sans le dossier cible
    local updated=""
    local found=0
    IFS=',' read -ra folders <<< "$current"
    for f in "${folders[@]}"; do
        f="${f// /}"
        if [[ "$f" == "$target" ]]; then
            found=1
        else
            if [[ -z "$updated" ]]; then
                updated="$f"
            else
                updated="$updated,$f"
            fi
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo -e "${RED}❌ Dossier introuvable dans la liste :${NC} $target"
        echo
        cmd_list
        exit 1
    fi

    if [[ -z "$updated" ]]; then
        echo -e "${YELLOW}⚠️  Attention : vous supprimez le dernier dossier surveillé.${NC}"
        read -p "Confirmer ? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Abandon."
            exit 0
        fi
    fi

    set_folders "$updated"

    systemctl daemon-reload
    systemctl restart "$SERVICE_NAME"

    echo
    echo -e "${GREEN}✅ Dossier retiré et service redémarré :${NC}"
    echo -e "   ${CYAN}$target${NC}"
    echo
    cmd_list
}

cmd_status() {
    echo
    systemctl status "$SERVICE_NAME" --no-pager || true
    echo
    cmd_list
}

cmd_uninstall() {
    echo
    echo -e "${BOLD}${RED}⚠️  Désinstallation de folder-monitor${NC}"
    echo
    echo -e "  Cela va supprimer :"
    echo -e "  • Le service systemd  (folder-monitor)"
    echo -e "  • Les fichiers        (/opt/folder-monitor)"
    echo
    read -p "Confirmer la désinstallation ? (y/n) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Abandon."
        exit 0
    fi

    echo
    echo -e "🛑 Arrêt du service..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true

    echo -e "🔌 Désactivation du service..."
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true

    echo -e "🗑️  Suppression du fichier service..."
    rm -f "$SERVICE_FILE"

    echo -e "🔄 Rechargement de systemd..."
    systemctl daemon-reload

    echo -e "🗑️  Suppression des fichiers installés..."
    rm -rf /opt/folder-monitor

    echo
    echo -e "${GREEN}✅ Désinstallation terminée.${NC}"
    echo
}

cmd_help() {
    echo
    echo -e "${BOLD}Usage : sudo ./manage.sh <commande> [argument]${NC}"
    echo
    echo -e "  ${CYAN}list${NC}              Lister les dossiers surveillés"
    echo -e "  ${CYAN}add /chemin${NC}       Ajouter un dossier à la surveillance"
    echo -e "  ${CYAN}remove /chemin${NC}    Retirer un dossier de la surveillance"
    echo -e "  ${CYAN}status${NC}            Voir le statut du service + liste des dossiers"
    echo -e "  ${CYAN}uninstall${NC}         Supprimer complètement le service et les fichiers"
    echo
    echo -e "Exemples :"
    echo -e "  sudo ./manage.sh add /var/www/uploads"
    echo -e "  sudo ./manage.sh remove /home/backup/old"
    echo -e "  sudo ./manage.sh list"
    echo -e "  sudo ./manage.sh uninstall"
    echo
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────

check_root

# uninstall n'a pas besoin que le service soit déjà installé
if [[ "${1:-}" != "uninstall" ]]; then
    check_installed
fi

case "${1:-}" in
    list)           cmd_list ;;
    add)            cmd_add "$2" ;;
    remove)         cmd_remove "$2" ;;
    status)         cmd_status ;;
    uninstall)      cmd_uninstall ;;
    help|--help|-h) cmd_help ;;
    *)
        echo -e "${RED}❌ Commande inconnue : ${1:-}${NC}"
        cmd_help
        exit 1
        ;;
esac

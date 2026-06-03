#!/bin/bash
#
# Installation - Surveillance multi-dossiers avec Telegram
#
# Auteur: Xavier - XGR Solutions
# Version: 3.0 - Multi-dossiers
#

set -e

echo "======================================================================"
echo "  INSTALLATION - SURVEILLANCE MULTI-DOSSIERS AVEC TELEGRAM"
echo "======================================================================"
echo

# Vérification des droits root
if [[ $EUID -ne 0 ]]; then
   echo "⚠️  Ce script doit être exécuté en tant que root (sudo)" 
   exit 1
fi

# Variables
INSTALL_DIR="/opt/folder-monitor"
SERVICE_NAME="folder-monitor"

# ============================================================================
# COLLECTE DES INFORMATIONS
# ============================================================================

echo "📝 Configuration Telegram"
echo
read -p "Token du bot Telegram: " BOT_TOKEN
read -p "Chat ID Telegram: " CHAT_ID

echo
echo "📂 Configuration des dossiers à surveiller"
echo
echo "Entrez les chemins des dossiers à surveiller (un par ligne)."
echo "Appuyez sur ENTRÉE avec une ligne vide pour terminer."
echo

FOLDERS=()
FOLDER_NUM=1

while true; do
    read -p "Dossier $FOLDER_NUM: " FOLDER_PATH
    
    # Si ligne vide et au moins un dossier, on arrête
    if [[ -z "$FOLDER_PATH" ]]; then
        if [[ ${#FOLDERS[@]} -gt 0 ]]; then
            break
        else
            echo "⚠️  Vous devez entrer au moins un dossier"
            continue
        fi
    fi
    
    # Vérifier si le dossier existe
    if [[ ! -d "$FOLDER_PATH" ]]; then
        echo "⚠️  Le dossier $FOLDER_PATH n'existe pas."
        read -p "Voulez-vous le créer ? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$FOLDER_PATH"
            echo "✓ Dossier créé"
        else
            continue
        fi
    fi
    
    FOLDERS+=("$FOLDER_PATH")
    echo "✓ Ajouté: $FOLDER_PATH"
    ((FOLDER_NUM++))
done

# Validation
if [[ -z "$BOT_TOKEN" ]] || [[ -z "$CHAT_ID" ]]; then
    echo "❌ Erreur: Token et Chat ID sont obligatoires"
    exit 1
fi

if [[ ${#FOLDERS[@]} -eq 0 ]]; then
    echo "❌ Erreur: Aucun dossier à surveiller"
    exit 1
fi

# Créer la liste des dossiers séparés par des virgules
WATCHED_FOLDERS=$(IFS=,; echo "${FOLDERS[*]}")

echo
echo "📊 Récapitulatif:"
echo "   • Bot Token: ${BOT_TOKEN:0:10}..."
echo "   • Chat ID: $CHAT_ID"
echo "   • Nombre de dossiers: ${#FOLDERS[@]}"
for i in "${!FOLDERS[@]}"; do
    echo "     $((i+1)). ${FOLDERS[$i]}"
done
echo

# ============================================================================
# INSTALLATION DES DÉPENDANCES
# ============================================================================

echo "📦 Installation des dépendances Python..."
apt-get update -qq
apt-get install -y python3 python3-pip python3-venv

# ============================================================================
# CRÉATION DU RÉPERTOIRE D'INSTALLATION
# ============================================================================

echo "📁 Création du répertoire d'installation..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ============================================================================
# CONFIGURATION DE L'ENVIRONNEMENT VIRTUEL
# ============================================================================

echo "🐍 Configuration de l'environnement virtuel..."
python3 -m venv venv
source venv/bin/activate

echo "📚 Installation des packages Python..."
pip install --quiet --upgrade pip
pip install --quiet watchdog requests

# ============================================================================
# INSTALLATION DU SCRIPT
# ============================================================================

echo "📄 Installation du script de surveillance multi-dossiers..."
cat > "$INSTALL_DIR/monitor.py" << 'EOFSCRIPT'
#!/usr/bin/env python3
import os
import time
import requests
from datetime import datetime
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')
WATCHED_FOLDERS = os.getenv('WATCHED_FOLDERS', '')
WATCHED_FOLDERS_LIST = [f.strip() for f in WATCHED_FOLDERS.split(',') if f.strip()]

class FolderMonitor(FileSystemEventHandler):
    def __init__(self, bot_token, chat_id, folder_name=None):
        self.bot_token = bot_token
        self.chat_id = chat_id
        self.folder_name = folder_name
        self.telegram_url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        self.last_notification_time = {}
    
    def send_telegram_notification(self, message):
        try:
            payload = {'chat_id': self.chat_id, 'text': message, 'parse_mode': 'HTML'}
            response = requests.post(self.telegram_url, data=payload, timeout=10)
            if response.status_code == 200:
                print(f"✓ Notification envoyée")
        except Exception as e:
            print(f"✗ Erreur: {e}")
    
    def should_notify(self, item_path, debounce=2):
        current_time = time.time()
        last_time = self.last_notification_time.get(item_path, 0)
        if current_time - last_time > debounce:
            self.last_notification_time[item_path] = current_time
            return True
        return False

    def _format_size(self, path):
        try:
            size_bytes = os.path.getsize(path)
            for unit in ['o', 'Ko', 'Mo', 'Go']:
                if size_bytes < 1024.0:
                    return f"{size_bytes:.2f} {unit}"
                size_bytes /= 1024.0
        except OSError:
            return "inconnu"

    def on_created(self, event):
        item_path = event.src_path
        if not self.should_notify(item_path):
            return
        time.sleep(0.5)
        if not os.path.exists(item_path):
            return
        
        item_name = os.path.basename(item_path)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        folder_label = self.folder_name if self.folder_name else os.path.dirname(item_path)
        
        if event.is_directory:
            message = f"📂 <b>Nouveau dossier</b>\n\n📁 <code>{item_name}</code>\n📍 Dans: <code>{folder_label}</code>\n🕒 {timestamp}"
            print(f"[{timestamp}] 📂 CRÉÉ: {item_name} (dans {folder_label})")
        else:
            size_str = self._format_size(item_path)
            message = f"📁 <b>Nouveau fichier</b>\n\n📄 <code>{item_name}</code>\n📍 Dans: <code>{folder_label}</code>\n💾 {size_str}\n🕒 {timestamp}"
            print(f"[{timestamp}] 📄 CRÉÉ: {item_name} (dans {folder_label})")
        
        self.send_telegram_notification(message)

    def on_modified(self, event):
        if event.is_directory:
            return
        item_path = event.src_path
        if not self.should_notify(item_path, debounce=5):
            return
        if not os.path.exists(item_path):
            return

        item_name = os.path.basename(item_path)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        folder_label = self.folder_name if self.folder_name else os.path.dirname(item_path)
        size_str = self._format_size(item_path)

        message = f"✏️ <b>Fichier modifié</b>\n\n📄 <code>{item_name}</code>\n📍 Dans: <code>{folder_label}</code>\n💾 {size_str}\n🕒 {timestamp}"
        print(f"[{timestamp}] ✏️  MODIFIÉ: {item_name} (dans {folder_label})")
        self.send_telegram_notification(message)

    def on_deleted(self, event):
        item_path = event.src_path
        if not self.should_notify(item_path):
            return

        item_name = os.path.basename(item_path)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        folder_label = self.folder_name if self.folder_name else os.path.dirname(item_path)

        if event.is_directory:
            message = f"🗑️ <b>Dossier supprimé</b>\n\n📁 <code>{item_name}</code>\n📍 Dans: <code>{folder_label}</code>\n🕒 {timestamp}"
            print(f"[{timestamp}] 🗑️  SUPPRIMÉ (dossier): {item_name} (dans {folder_label})")
        else:
            message = f"🗑️ <b>Fichier supprimé</b>\n\n📄 <code>{item_name}</code>\n📍 Dans: <code>{folder_label}</code>\n🕒 {timestamp}"
            print(f"[{timestamp}] 🗑️  SUPPRIMÉ: {item_name} (dans {folder_label})")

        self.send_telegram_notification(message)

def main():
    print(f"📂 Surveillance de {len(WATCHED_FOLDERS_LIST)} dossier(s)")
    
    observer = Observer()
    for folder in WATCHED_FOLDERS_LIST:
        folder_name = os.path.basename(folder) or folder
        event_handler = FolderMonitor(TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, folder_name)
        observer.schedule(event_handler, folder, recursive=False)
        print(f"✓ {folder}")
    
    observer.start()
    
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    try:
        requests.post(url, data={
            'chat_id': TELEGRAM_CHAT_ID,
            'text': f'🚀 <b>Surveillance active</b>\n\n📁 {len(WATCHED_FOLDERS_LIST)} dossier(s) surveillé(s)',
            'parse_mode': 'HTML'
        })
    except:
        pass
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

if __name__ == "__main__":
    main()
EOFSCRIPT

chmod +x "$INSTALL_DIR/monitor.py"

# ============================================================================
# CRÉATION DU SERVICE SYSTEMD
# ============================================================================

echo "⚙️  Configuration du service systemd..."
cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOFSERVICE
[Unit]
Description=Surveillance multi-dossiers avec Telegram
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
Environment="TELEGRAM_CHAT_ID=$CHAT_ID"
Environment="WATCHED_FOLDERS=$WATCHED_FOLDERS"
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/monitor.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

# ============================================================================
# ACTIVATION DU SERVICE
# ============================================================================

echo "🚀 Activation du service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

sleep 3
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo
    echo "======================================================================"
    echo "                   ✅ INSTALLATION RÉUSSIE !"
    echo "======================================================================"
    echo
    echo "📊 Informations:"
    echo "   • Service: $SERVICE_NAME"
    echo "   • Dossiers surveillés: ${#FOLDERS[@]}"
    for i in "${!FOLDERS[@]}"; do
        echo "     $((i+1)). ${FOLDERS[$i]}"
    done
    echo
    echo "📝 Commandes utiles:"
    echo "   • Statut:  systemctl status $SERVICE_NAME"
    echo "   • Logs:    journalctl -u $SERVICE_NAME -f"
    echo "   • Arrêt:   systemctl stop $SERVICE_NAME"
    echo
    echo "🧪 Tester:"
    echo "   touch ${FOLDERS[0]}/test.txt"
    echo "   mkdir ${FOLDERS[0]}/test_dir"
    echo
    echo "💬 Vérifiez Telegram pour la notification de démarrage !"
    echo "======================================================================"
else
    echo "❌ Erreur: Le service n'a pas démarré"
    journalctl -u $SERVICE_NAME -n 20
    exit 1
fi

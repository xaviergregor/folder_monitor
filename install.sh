#!/bin/bash
#
# Script d'installation automatique - Surveillance de dossier avec Telegram
# Détecte les fichiers ET les dossiers
#
# Auteur: Xavier - XGR Solutions
# Version: 2.0 FINALE
# Date: 2025-11-15
#

set -e

echo "======================================================================"
echo "    INSTALLATION - SURVEILLANCE DE DOSSIER AVEC TELEGRAM"
echo "                   Fichiers & Dossiers"
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

echo "📝 Configuration"
echo
read -p "Token du bot Telegram: " BOT_TOKEN
read -p "Chat ID Telegram: " CHAT_ID
read -p "Dossier à surveiller: " WATCHED_DIR

# Validation
if [[ -z "$BOT_TOKEN" ]] || [[ -z "$CHAT_ID" ]] || [[ -z "$WATCHED_DIR" ]]; then
    echo "❌ Erreur: Tous les champs sont obligatoires"
    exit 1
fi

if [[ ! -d "$WATCHED_DIR" ]]; then
    echo "⚠️  Le dossier $WATCHED_DIR n'existe pas."
    read -p "Voulez-vous le créer ? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$WATCHED_DIR"
        echo "✓ Dossier créé"
    else
        exit 1
    fi
fi

# ============================================================================
# INSTALLATION DES DÉPENDANCES
# ============================================================================

echo
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

# Installation des packages Python
echo "📚 Installation des packages Python..."
pip install --quiet --upgrade pip
pip install --quiet watchdog requests

# ============================================================================
# INSTALLATION DU SCRIPT
# ============================================================================

echo "📄 Installation du script de surveillance..."
cat > "$INSTALL_DIR/monitor.py" << 'EOFSCRIPT'
#!/usr/bin/env python3
"""
Script de surveillance de dossier avec notifications Telegram
VERSION FINALE - Détecte les fichiers ET les dossiers
"""

import os
import time
import requests
from datetime import datetime
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')
WATCHED_FOLDER = os.getenv('WATCHED_FOLDER')

class FolderMonitor(FileSystemEventHandler):
    def __init__(self, bot_token, chat_id):
        self.bot_token = bot_token
        self.chat_id = chat_id
        self.telegram_url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        self.last_notification_time = {}
    
    def send_telegram_notification(self, message):
        try:
            payload = {
                'chat_id': self.chat_id,
                'text': message,
                'parse_mode': 'HTML'
            }
            response = requests.post(self.telegram_url, data=payload, timeout=10)
            if response.status_code == 200:
                print(f"✓ Notification envoyée")
                return True
            else:
                print(f"✗ Erreur Telegram: {response.status_code}")
                return False
        except Exception as e:
            print(f"✗ Erreur: {e}")
            return False
    
    def should_notify(self, item_path):
        current_time = time.time()
        last_time = self.last_notification_time.get(item_path, 0)
        if current_time - last_time > 2:
            self.last_notification_time[item_path] = current_time
            return True
        return False
    
    def on_created(self, event):
        """Détecte les fichiers ET les dossiers"""
        item_path = event.src_path
        
        # Anti-doublon
        if not self.should_notify(item_path):
            return
        
        # Attendre que l'élément soit complètement créé
        time.sleep(0.5)
        
        # Vérifier l'existence
        if not os.path.exists(item_path):
            return
        
        item_name = os.path.basename(item_path)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        if event.is_directory:
            # ===== NOUVEAU DOSSIER =====
            message = (
                f"📂 <b>Nouveau dossier créé</b>\n\n"
                f"📁 Nom: <code>{item_name}</code>\n"
                f"📍 Chemin: <code>{os.path.dirname(item_path)}</code>\n"
                f"🕒 Date: {timestamp}"
            )
            print(f"[{timestamp}] 📂 DOSSIER: {item_name}")
            
        else:
            # ===== NOUVEAU FICHIER =====
            file_size = os.path.getsize(item_path)
            
            # Formatage de la taille
            size_bytes = file_size
            for unit in ['o', 'Ko', 'Mo', 'Go']:
                if size_bytes < 1024.0:
                    size_str = f"{size_bytes:.2f} {unit}"
                    break
                size_bytes /= 1024.0
            
            message = (
                f"📁 <b>Nouveau fichier détecté</b>\n\n"
                f"📄 Nom: <code>{item_name}</code>\n"
                f"💾 Taille: {size_str}\n"
                f"🕒 Date: {timestamp}"
            )
            print(f"[{timestamp}] 📄 FICHIER: {item_name}")
        
        # Envoi de la notification
        self.send_telegram_notification(message)

def main():
    print(f"📁 Surveillance: {WATCHED_FOLDER}")
    print(f"📂 Mode: FICHIERS ET DOSSIERS")
    print(f"=" * 60)
    
    event_handler = FolderMonitor(TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID)
    observer = Observer()
    observer.schedule(event_handler, WATCHED_FOLDER, recursive=False)
    observer.start()
    
    # Notification de démarrage
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    try:
        requests.post(url, data={
            'chat_id': TELEGRAM_CHAT_ID,
            'text': (
                f'🚀 <b>Surveillance active</b>\n\n'
                f'📁 {WATCHED_FOLDER}\n'
                f'✅ Détection fichiers ET dossiers'
            ),
            'parse_mode': 'HTML'
        }, timeout=5)
    except:
        pass
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        try:
            requests.post(url, data={
                'chat_id': TELEGRAM_CHAT_ID,
                'text': '🛑 <b>Surveillance arrêtée</b>',
                'parse_mode': 'HTML'
            }, timeout=5)
        except:
            pass
    
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
Description=Surveillance de dossier avec notifications Telegram (Fichiers & Dossiers)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
Environment="TELEGRAM_CHAT_ID=$CHAT_ID"
Environment="WATCHED_FOLDER=$WATCHED_DIR"
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

# ============================================================================
# VÉRIFICATION ET AFFICHAGE DU RÉSULTAT
# ============================================================================

sleep 3
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo
    echo "======================================================================"
    echo "                   ✅ INSTALLATION RÉUSSIE !"
    echo "======================================================================"
    echo
    echo "📊 Informations:"
    echo "   • Service: $SERVICE_NAME"
    echo "   • Dossier surveillé: $WATCHED_DIR"
    echo "   • Installation: $INSTALL_DIR"
    echo "   • Mode: Fichiers ET Dossiers ✅"
    echo
    echo "📝 Commandes utiles:"
    echo "   • Statut:      systemctl status $SERVICE_NAME"
    echo "   • Logs:        journalctl -u $SERVICE_NAME -f"
    echo "   • Arrêt:       systemctl stop $SERVICE_NAME"
    echo "   • Redémarrage: systemctl restart $SERVICE_NAME"
    echo
    echo "🧪 Test rapide:"
    echo "   # Créer un fichier test"
    echo "   touch $WATCHED_DIR/test_fichier.txt"
    echo
    echo "   # Créer un dossier test"
    echo "   mkdir $WATCHED_DIR/test_dossier"
    echo
    echo "💬 Vous devriez recevoir 2 notifications sur Telegram :"
    echo "   📁 Une pour le fichier"
    echo "   📂 Une pour le dossier"
    echo
    echo "📱 Vérifiez votre Telegram pour la notification de démarrage !"
    echo "======================================================================"
    echo
else
    echo
    echo "======================================================================"
    echo "                      ❌ ERREUR D'INSTALLATION"
    echo "======================================================================"
    echo
    echo "Le service n'a pas démarré correctement."
    echo
    echo "🔍 Vérifiez les logs:"
    echo "   journalctl -u $SERVICE_NAME -n 50"
    echo
    echo "======================================================================"
    exit 1
fi

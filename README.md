# 📁 Surveillance de Dossier avec Notifications Telegram

[![Python](https://img.shields.io/badge/Python-3.6+-blue.svg)](https://www.python.org/downloads/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-Bot-blue.svg)](https://core.telegram.org/bots)

Script Python de surveillance de dossier en temps réel avec notifications Telegram instantanées. Idéal pour monitorer des uploads, des backups, ou tout dossier nécessitant une surveillance active.

## ✨ Fonctionnalités

- 🔍 **Surveillance en temps réel** - Détection instantanée des nouveaux fichiers
- 📱 **Notifications Telegram** - Alertes immédiates avec détails du fichier
- 🚀 **Service systemd** - Démarrage automatique au boot
- 💾 **Anti-doublon** - Système de debouncing pour éviter les notifications multiples
- 🛡️ **Robuste** - Gestion des erreurs et reconnexion automatique
- ⚙️ **Simple** - Installation en une seule commande

## 📋 Prérequis

- Python 3.6 ou supérieur
- Accès root (pour l'installation en tant que service)
- Un bot Telegram (gratuit)
- Connexion internet

## 🚀 Installation rapide

### Installation automatique (recommandée)

```bash
# Télécharger le script d'installation
wget https://raw.githubusercontent.com/xaviergregor/folder_monitor/main/install.sh

# Rendre le script exécutable
chmod +x install.sh

# Lancer l'installation
sudo ./install.sh
```

Le script vous demandera :
- Le token de votre bot Telegram
- Votre Chat ID
- Le dossier à surveiller

Et configurera tout automatiquement !

## 🤖 Configuration du Bot Telegram

### Étape 1 : Créer un bot

1. Ouvrez Telegram et cherchez **[@BotFather](https://t.me/BotFather)**
2. Envoyez la commande `/newbot`
3. Suivez les instructions pour nommer votre bot
4. **Copiez le token** fourni (format : `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Étape 2 : Obtenir votre Chat ID

1. Cherchez **[@userinfobot](https://t.me/userinfobot)** sur Telegram
2. Démarrez une conversation avec `/start`
3. **Copiez votre ID** (un nombre comme `123456789`)

### Étape 3 : Activer le bot

1. Cherchez votre bot sur Telegram (le nom que vous lui avez donné)
2. Cliquez sur **Démarrer** ou envoyez `/start`

## 📱 Format des notifications

Les notifications Telegram affichent :

```
📁 Nouveau fichier

📄 document.pdf
💾 2.45 Mo
🕒 2025-11-15 14:30:25
```

## 🔧 Utilisation

### Gérer le service

```bash
# Démarrer la surveillance
sudo systemctl start folder-monitor

# Arrêter la surveillance
sudo systemctl stop folder-monitor

# Redémarrer
sudo systemctl restart folder-monitor

# Voir le statut
sudo systemctl status folder-monitor

# Activer au démarrage
sudo systemctl enable folder-monitor

# Désactiver au démarrage
sudo systemctl disable folder-monitor
```

### Consulter les logs

```bash
# Logs en temps réel
sudo journalctl -u folder-monitor -f

# Les 50 dernières lignes
sudo journalctl -u folder-monitor -n 50

# Logs d'aujourd'hui
sudo journalctl -u folder-monitor --since today
```

## ⚙️ Configuration avancée

### Surveiller les sous-dossiers

Modifiez le script et changez `recursive=False` en `recursive=True` :

```python
observer.schedule(event_handler, WATCHED_FOLDER, recursive=True)
```

### Variables d'environnement

Créez un fichier `.env` :

```bash
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=123456789
WATCHED_FOLDER=/var/www/uploads
```

### Filtrer par type de fichier

Ajoutez dans la méthode `on_created` :

```python
# Surveiller uniquement les images
if not file_path.lower().endswith(('.png', '.jpg', '.jpeg', '.gif')):
    return
```

## 🛠️ Dépannage

### Le service ne démarre pas

```bash
# Vérifier les logs d'erreur
sudo journalctl -u folder-monitor -n 50 --no-pager

# Tester le script manuellement
sudo -u root /opt/folder-monitor/venv/bin/python3 /opt/folder-monitor/monitor.py
```

### Erreur "Module not found"

```bash
# Réinstaller les dépendances
cd /opt/folder-monitor
source venv/bin/activate
pip install watchdog requests
```

### Le bot ne répond pas

- ✅ Vérifiez que le token est correct
- ✅ Assurez-vous d'avoir démarré une conversation avec votre bot (`/start`)
- ✅ Vérifiez votre connexion internet
- ✅ Testez avec `curl` :

```bash
curl -X POST "https://api.telegram.org/bot<VOTRE_TOKEN>/sendMessage" \
  -d "chat_id=<VOTRE_CHAT_ID>" \
  -d "text=Test"
```

### Permissions insuffisantes

```bash
# Vérifier les permissions du dossier surveillé
ls -la /chemin/vers/dossier

# Donner les permissions si nécessaire
sudo chown -R www-data:www-data /chemin/vers/dossier
```

## 🔐 Sécurité

⚠️ **Important** : 

- Ne partagez **JAMAIS** votre token de bot
- N'incluez **JAMAIS** vos tokens dans des dépôts publics
- Utilisez des variables d'environnement ou des fichiers `.env`
- Ajoutez `.env` à votre `.gitignore`

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

1. 🍴 Forker le projet
2. 🔧 Créer une branche (`git checkout -b feature/amelioration`)
3. 💾 Commiter vos changements (`git commit -am 'Ajout nouvelle fonctionnalité'`)
4. 📤 Pusher vers la branche (`git push origin feature/amelioration`)
5. 🎉 Ouvrir une Pull Request

## 📝 Cas d'usage

- 📸 Surveillance de dossier d'uploads (photos, documents)
- 💾 Monitoring de backups automatiques
- 📊 Alertes sur nouveaux rapports générés
- 🎬 Notification de nouveaux médias ajoutés
- 📦 Suivi de téléchargements terminés
- 🔄 Monitoring de dossiers de synchronisation

## 🌟 Exemples d'utilisation

### Surveillance d'uploads web

```bash
export WATCHED_FOLDER="/var/www/uploads"
python3 monitor_folder_env.py
```

### Monitoring de backups

```bash
export WATCHED_FOLDER="/home/backup/daily"
python3 monitor_folder_env.py
```

### Surveillance de téléchargements

```bash
export WATCHED_FOLDER="/home/user/Downloads"
python3 monitor_folder_env.py
```

## 📊 Performance

- **CPU** : < 1% en idle
- **RAM** : ~15-20 Mo
- **Latence** : Détection < 1 seconde
- **Fiabilité** : Redémarrage automatique en cas d'erreur

## 📜 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👤 Auteur

**Xavier Gregor** - [XGR Solutions](https://www.xgr.fr)

## 🙏 Remerciements

- [Watchdog](https://github.com/gorakhargosh/watchdog) - Bibliothèque de surveillance de fichiers
- [python-telegram-bot](https://github.com/python-telegram-bot/python-telegram-bot) - Pour l'inspiration
- La communauté Python 🐍

## 📞 Support

- 📧 Email : support@xgr-solutions.fr
- 🐛 Issues : [GitHub Issues](https://github.com/VOTRE_USERNAME/VOTRE_REPO/issues)
- 💬 Telegram : [@votre_username](https://t.me/votre_username)

---

⭐ Si ce projet vous est utile, n'hésitez pas à lui donner une étoile sur GitHub !



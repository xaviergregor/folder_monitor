# 📁 Surveillance de Dossiers avec Notifications Telegram

[![Python](https://img.shields.io/badge/Python-3.6+-blue.svg)](https://www.python.org/downloads/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-Bot-blue.svg)](https://core.telegram.org/bots)

Script Python de surveillance de dossiers en temps réel avec notifications Telegram instantanées. Idéal pour monitorer des uploads, des backups, ou tout dossier nécessitant une surveillance active.

## ✨ Fonctionnalités

- 🔍 **Surveillance en temps réel** — Détection instantanée des nouveaux fichiers, modifications et suppressions
- 📱 **Notifications Telegram** — Alertes immédiates avec détails du fichier
- 🚀 **Service systemd** — Démarrage automatique au boot
- 💾 **Anti-doublon** — Système de debouncing pour éviter les notifications multiples
- 🛡️ **Robuste** — Gestion des erreurs et reconnexion automatique
- 📂 **Multi-dossiers** — Surveillance simultanée de plusieurs répertoires
- 🖼️ **Aperçu image** — Envoi automatique de l'image en aperçu Telegram lors d'une création (jpg, jpeg, png, gif, webp, bmp). Fallback texte si > 10 Mo
- ⚙️ **Gestion dynamique** — Ajout/suppression de dossiers sans réinstallation

## 📋 Prérequis

- Python 3.6 ou supérieur
- Accès root (pour l'installation en tant que service)
- Un bot Telegram (gratuit)
- Connexion internet

## 🚀 Installation rapide

```bash
wget https://raw.githubusercontent.com/xaviergregor/folder_monitor/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

Le script vous demandera :
- Le token de votre bot Telegram
- Votre Chat ID
- Les dossiers à surveiller (autant que souhaité)

## 🤖 Configuration du Bot Telegram

### Étape 1 : Créer un bot

1. Ouvrez Telegram et cherchez **[@BotFather](https://t.me/BotFather)**
2. Envoyez `/newbot` et suivez les instructions
3. **Copiez le token** fourni (format : `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Étape 2 : Obtenir votre Chat ID

1. Cherchez **[@userinfobot](https://t.me/userinfobot)** sur Telegram
2. Envoyez `/start`
3. **Copiez votre ID** (un nombre comme `123456789`)

### Étape 3 : Activer le bot

Cherchez votre bot sur Telegram et cliquez sur **Démarrer**.

## ⚙️ Gestion des dossiers surveillés

Après installation, utilisez `manage.sh` pour modifier la liste des dossiers **sans réinstaller**.

```bash
wget https://raw.githubusercontent.com/xaviergregor/folder_monitor/main/manage.sh
chmod +x manage.sh
```

### Lister les dossiers surveillés

```bash
sudo ./manage.sh list
```

```
📂 Dossiers actuellement surveillés :

  1. /var/www/uploads
  2. /home/backup/daily

  Service : ● actif
```

### Ajouter un dossier

```bash
sudo ./manage.sh add /chemin/vers/dossier
```

Le dossier est créé automatiquement s'il n'existe pas (avec confirmation). Le service redémarre immédiatement.

### Supprimer un dossier

```bash
sudo ./manage.sh remove /chemin/vers/dossier
```

Le service redémarre immédiatement après la suppression.

### Voir le statut complet

```bash
sudo ./manage.sh status
```

### Désinstaller complètement

```bash
sudo ./manage.sh uninstall
```

Supprime le service systemd, son fichier de configuration et le répertoire `/opt/folder-monitor`. Une confirmation est demandée avant toute suppression.

### Activer / désactiver l'aperçu image

L'aperçu image est activé par défaut à l'installation. Pour le basculer sans réinstaller :

```bash
sudo ./manage.sh image-preview on    # Activer
sudo ./manage.sh image-preview off   # Désactiver
sudo ./manage.sh image-preview       # Voir l'état actuel
```

L'état est également visible dans `sudo ./manage.sh list`.

> **Note :** Toutes les commandes `manage.sh` nécessitent les droits root (`sudo`).

## 📱 Format des notifications

**Nouveau fichier**
```
📁 Nouveau fichier

📄 document.pdf
📍 Dans: uploads
💾 2.45 Mo
🕒 2025-11-15 14:30:25
```

**Fichier modifié**
```
✏️ Fichier modifié

📄 document.pdf
📍 Dans: uploads
💾 2.46 Mo
🕒 2025-11-15 14:35:10
```

**Fichier ou dossier supprimé**
```
🗑️ Fichier supprimé

📄 document.pdf
📍 Dans: uploads
🕒 2025-11-15 14:40:00
```

**Nouveau fichier image** *(aperçu envoyé directement dans Telegram)*
```
📁 Nouveau fichier

📄 photo.jpg
📍 Dans: uploads
💾 1.20 Mo
🕒 2025-11-15 14:32:00
[image affichée dans Telegram]
```

**Nouveau dossier**
```
📂 Nouveau dossier

📁 archives_2025
📍 Dans: backup
🕒 2025-11-15 14:31:02
```

## 🔧 Gestion du service

```bash
# Démarrer
sudo systemctl start folder-monitor

# Arrêter
sudo systemctl stop folder-monitor

# Redémarrer
sudo systemctl restart folder-monitor

# Statut
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

### Surveiller les sous-dossiers (récursif)

Modifiez `/opt/folder-monitor/monitor.py` et remplacez `recursive=False` par `recursive=True` :

```python
observer.schedule(event_handler, folder, recursive=True)
```

Puis redémarrez :

```bash
sudo systemctl restart folder-monitor
```

### Filtrer par type de fichier

Ajoutez dans la méthode `on_created` de `monitor.py` :

```python
# Surveiller uniquement les images
if not event.src_path.lower().endswith(('.png', '.jpg', '.jpeg', '.gif')):
    return
```

## 🛠️ Dépannage

### Le service ne démarre pas

```bash
sudo journalctl -u folder-monitor -n 50 --no-pager

# Tester manuellement
sudo /opt/folder-monitor/venv/bin/python3 /opt/folder-monitor/monitor.py
```

### Erreur "Module not found"

```bash
cd /opt/folder-monitor
source venv/bin/activate
pip install watchdog requests
```

### Le bot ne répond pas

- ✅ Vérifiez que le token est correct
- ✅ Assurez-vous d'avoir envoyé `/start` à votre bot
- ✅ Testez avec curl :

```bash
curl -X POST "https://api.telegram.org/bot<VOTRE_TOKEN>/sendMessage" \
  -d "chat_id=<VOTRE_CHAT_ID>" \
  -d "text=Test"
```

### Un dossier ajouté via manage.sh n'est pas surveillé

Vérifiez que le service a bien redémarré :

```bash
sudo systemctl status folder-monitor
sudo ./manage.sh list
```

## 🔐 Sécurité

⚠️ **Important** :

- Ne partagez **JAMAIS** votre token de bot
- N'incluez **JAMAIS** vos tokens dans des dépôts publics
- Le token est stocké dans `/etc/systemd/system/folder-monitor.service` — accès root requis

## 📊 Performance

- **CPU** : < 1% en idle
- **RAM** : ~15-20 Mo
- **Latence** : Détection < 1 seconde
- **Fiabilité** : Redémarrage automatique en cas d'erreur

## 📝 Cas d'usage

- 📸 Surveillance de dossiers d'uploads (photos, documents)
- 💾 Monitoring de backups automatiques
- 📊 Alertes sur nouveaux rapports générés
- 🎬 Notification de nouveaux médias ajoutés
- 📦 Suivi de téléchargements terminés
- 🔄 Monitoring de dossiers de synchronisation

## 📜 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👤 Auteur

**Xavier Gregor** - [XGR Solutions](https://www.xgr.fr)

## 🙏 Remerciements

- [Watchdog](https://github.com/gorakhargosh/watchdog) — Bibliothèque de surveillance de fichiers
- La communauté Python 🐍

## 📞 Support

- 🐛 Issues : [GitHub Issues](https://github.com/xaviergregor/folder_monitor/issues)

---

⭐ Si ce projet vous est utile, n'hésitez pas à lui donner une étoile sur GitHub !

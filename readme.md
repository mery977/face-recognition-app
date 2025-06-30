# 🔐 Login Biométrique par Reconnaissance Faciale

## 📋 Description

Système d'authentification biométrique moderne utilisant la reconnaissance faciale avec Flask, OpenCV, et MongoDB. Cette application permet aux utilisateurs de s'inscrire et se connecter en utilisant uniquement leur visage comme méthode d'authentification.

## ✨ Fonctionnalités

- **🎯 Reconnaissance faciale en temps réel** : Détection et analyse instantanée via webcam
- **🔒 Authentification sécurisée** : Encodage avancé des caractéristiques faciales
- **📊 Base de données NoSQL** : Stockage efficace avec MongoDB
- **📈 Dashboard administrateur** : Suivi des connexions et statistiques
- **📱 Interface responsive** : Compatible tous appareils
- **🐳 Containerisé** : Déploiement facile avec Docker

## 🏗️ Architecture

```
face-recognition-app/
├── app.py                  # Application Flask principale
├── requirements.txt        # Dépendances Python
├── Dockerfile             # Configuration Docker
├── docker-compose.yml     # Orchestration des services
├── templates/             # Templates HTML
│   ├── base.html
│   ├── index.html
│   ├── register.html
│   ├── login.html
│   └── dashboard.html
├── static/               # Ressources statiques
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── app.js
├── uploads/              # Photos des utilisateurs
└── README.md
```

## 🚀 Installation et Démarrage

### Prérequis

- Docker et Docker Compose installés
- Caméra web fonctionnelle
- Navigateur moderne (Chrome, Firefox, Safari)

### Installation rapide

1. **Cloner le projet**
```bash
git clone https://github.com/votre-username/face-recognition-login.git
cd face-recognition-login
```

2. **Démarrer avec Docker Compose**
```bash
docker-compose up --build
```

3. **Accéder à l'application**
- Application principale : http://localhost
- Dashboard MongoDB : http://localhost:8081
- API REST : http://localhost/api/

### Installation manuelle (développement)

1. **Installer les dépendances système**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install build-essential cmake libopencv-dev python3-opencv

# macOS (avec Homebrew)
brew install cmake opencv
```

2. **Installer les dépendances Python**
```bash
pip install -r requirements.txt
```

3. **Configurer MongoDB**
```bash
# Installer MongoDB localement ou utiliser MongoDB Atlas
mongodb://localhost:27017/face_recognition_db
```

4. **Lancer l'application**
```bash
python app.py
```

## 🔧 Configuration

### Variables d'environnement

```bash
# Base de données
MONGO_URI=mongodb://mongo:27017/face_recognition_db

# Flask
FLASK_ENV=development
SECRET_KEY=your-secret-key-here

# Upload
MAX_CONTENT_LENGTH=16777216  # 16MB
UPLOAD_FOLDER=uploads
```

### Configuration Docker

Le fichier `docker-compose.yml` configure :
- **Web service** : Application Flask sur le port 80
- **MongoDB** : Base de données sur le port 27017
- **Mongo Express** : Interface web MongoDB sur le port 8081

## 📡 API REST

### Endpoints disponibles

#### Inscription d'utilisateur


#### Connexion par reconnaissance faciale
```http
POST /api/login
Content-Type: application/json

{
  "image": "data:image/jpeg;base64,/9j/4AAQSkZJRgABA..."
}
```

#### Liste des utilisateurs
```http
GET /api/users
```

#### Historique des connexions
```http
GET /api/logs
```

## 🎨 Interface Utilisateur

### Pages principales

1. **Page d'accueil** (`/`) : Présentation du système
2. **Inscription** (`/register`) : Création de compte avec photo
3. **Connexion** (`/login`) : Authentification par caméra
4. **Dashboard** (`/dashboard`) : Statistiques et gestion

### Design moderne

- **Glassmorphism** : Effets de transparence et de flou
- **Gradients animés** : Arrière-plans dynamiques
- **Micro-interactions** : Animations fluides
- **Dark theme** : Interface sombre élégante

## 🔐 Sécurité

### Mesures implémentées

- **Encodage sécurisé** : Algorithmes face_recognition (dlib)
- **Validation des données** : Contrôles côté client et serveur
- **Limitation de taille** : Upload maximum 16MB
- **Logs d'audit** : Traçabilité des connexions
- **IP tracking** : Suivi des adresses IP

### Bonnes pratiques

- Photos stockées localement uniquement
- Encodages facials chiffrés en base
- Sessions sécurisées Flask
- Validation MIME des fichiers

## 📊 Monitoring et Logs

### Dashboard administrateur

Le dashboard fournit :
- **Statistiques en temps réel** : Nombre d'utilisateurs, connexions
- **Graphiques** : Visualisation des connexions par heure
- **Historique** : Logs des tentatives de connexion
- **Taux de réussite** : Métriques de performance

### Structure des logs

```json
{
  "_id": "ObjectId",
  "user_id": "ObjectId",
  "username": "john_doe",
  "login_time": "2025-06-30T10:30:00Z",
  "success": true,
  "ip_address": "192.168.1.100"
}
```

## 🧪 Tests

### Tests manuels

1. **Test d'inscription**
   - Uploader une photo claire
   - Vérifier la détection de visage
   - Contrôler l'enregistrement en base

2. **Test de connexion**
   - Activer la caméra
   - Positionner le visage
   - Vérifier la reconnaissance

3. **Tests d'erreur**
   - Photo sans visage
   - Visage non reconnu
   - Erreurs réseau

### Tests automatisés

```bash
# Tests unitaires (à implémenter)
python -m pytest tests/

# Tests de charge
ab -n 100 -c 10 http://localhost/api/users
```

## 🚀 Déploiement

### Déploiement en production

1. **Configuration sécurisée**
```bash
# Générer une clé secrète forte
export SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex())')

# Configuration MongoDB sécurisée
export MONGO_URI=mongodb://username:password@mongo-server:27017/prod_db
```

2. **Optimisations production**
```dockerfile
# Dockerfile optimisé
FROM python:3.9-slim
ENV FLASK_ENV=production
ENV PYTHONUNBUFFERED=1
```

3. **Monitoring**
```bash
# Logs de production
docker-compose logs -f web

# Monitoring ressources
docker stats
```







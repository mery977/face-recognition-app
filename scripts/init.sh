#!/bin/bash

# Script d'initialisation pour Face Recognition App
# Usage: ./scripts/init.sh [dev|prod]

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
ENVIRONMENT=${1:-dev}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPLOADS_DIR="$PROJECT_ROOT/uploads"
LOGS_DIR="$PROJECT_ROOT/logs"
BACKUPS_DIR="$PROJECT_ROOT/backups"
SSL_DIR="$PROJECT_ROOT/ssl"

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des prérequis
check_requirements() {
    log_info "Vérification des prérequis..."
    
    # Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    # Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    # Python (pour le développement local)
    if ! command -v python3 &> /dev/null; then
        log_warning "Python 3 n'est pas installé (requis pour le développement local)"
    fi
    
    log_success "Prérequis vérifiés"
}

# Création des dossiers nécessaires
create_directories() {
    log_info "Création des dossiers..."
    
    mkdir -p "$UPLOADS_DIR"
    mkdir -p "$LOGS_DIR"
    mkdir -p "$BACKUPS_DIR"
    mkdir -p "$PROJECT_ROOT/static/uploads"
    mkdir -p "$PROJECT_ROOT/templates"
    
    if [ "$ENVIRONMENT" = "prod" ]; then
        mkdir -p "$SSL_DIR"
        mkdir -p "$PROJECT_ROOT/monitoring/prometheus"
        mkdir -p "$PROJECT_ROOT/monitoring/grafana/dashboards"
        mkdir -p "$PROJECT_ROOT/monitoring/grafana/datasources"
    fi
    
    log_success "Dossiers créés"
}

# Configuration des permissions
setup_permissions() {
    log_info "Configuration des permissions..."
    
    # Permissions pour les dossiers de données
    chmod 755 "$UPLOADS_DIR"
    chmod 755 "$LOGS_DIR"
    chmod 755 "$BACKUPS_DIR"
    
    # Scripts exécutables
    find "$PROJECT_ROOT/scripts" -name "*.sh" -exec chmod +x {} \;
    
    log_success "Permissions configurées"
}

# Configuration de l'environnement
setup_environment() {
    log_info "Configuration de l'environnement..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        if [ -f "$PROJECT_ROOT/.env.example" ]; then
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            log_success "Fichier .env créé à partir de .env.example"
        else
            log_warning "Aucun fichier .env.example trouvé"
        fi
    else
        log_info "Fichier .env existe déjà"
    fi
    
    # Génération d'une clé secrète si nécessaire
    if [ -f "$PROJECT_ROOT/.env" ]; then
        if ! grep -q "SECRET_KEY=" "$PROJECT_ROOT/.env" || grep -q "your-secret-key-here" "$PROJECT_ROOT/.env"; then
            SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || openssl rand -hex 32)
            sed -i.bak "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" "$PROJECT_ROOT/.env"
            log_success "Clé secrète générée"
        fi
    fi
}

# Configuration SSL pour la production
setup_ssl() {
    if [ "$ENVIRONMENT" = "prod" ]; then
        log_info "Configuration SSL pour la production..."
        
        if [ ! -f "$SSL_DIR/cert.pem" ] || [ ! -f "$SSL_DIR/key.pem" ]; then
            log_warning "Certificats SSL non trouvés"
            log_info "Génération d'un certificat auto-signé pour les tests..."
            
            openssl req -x509 -newkey rsa:4096 -keyout "$SSL_DIR/key.pem" -out "$SSL_DIR/cert.pem" \
                -days 365 -nodes -subj "/C=FR/ST=IDF/L=Paris/O=FaceRecognition/CN=localhost"
            
            chmod 600 "$SSL_DIR/key.pem"
            chmod 644 "$SSL_DIR/cert.pem"
            
            log_success "Certificat auto-signé créé"
            log_warning "En production, utilisez un certificat valide (Let's Encrypt, etc.)"
        else
            log_success "Certificats SSL trouvés"
        fi
    fi
}

# Configuration des fichiers de monitoring
setup_monitoring() {
    if [ "$ENVIRONMENT" = "prod" ]; then
        log_info "Configuration du monitoring..."
        
        # Prometheus configuration
        cat > "$PROJECT_ROOT/monitoring/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'face-recognition-app'
    static_configs:
      - targets: ['web:80']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'mongodb'
    static_configs:
      - targets: ['mongo:27017']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
EOF

        # Grafana datasource
        mkdir -p "$PROJECT_ROOT/monitoring/grafana/datasources"
        cat > "$PROJECT_ROOT/monitoring/grafana/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

        # Grafana dashboard
        mkdir -p "$PROJECT_ROOT/monitoring/grafana/dashboards"
        cat > "$PROJECT_ROOT/monitoring/grafana/dashboards/dashboard.yml" << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

        log_success "Configuration monitoring créée"
    fi
}

# Installation des dépendances locales (développement)
install_dependencies() {
    if [ "$ENVIRONMENT" = "dev" ]; then
        log_info "Installation des dépendances de développement..."
        
        if command -v python3 &> /dev/null && command -v pip3 &> /dev/null; then
            pip3 install -r "$PROJECT_ROOT/requirements.txt"
            log_success "Dépendances Python installées"
        else
            log_warning "Python/pip non disponible, les dépendances seront installées dans Docker"
        fi
    fi
}

# Vérification de la configuration
verify_setup() {
    log_info "Vérification de la configuration..."
    
    # Vérification des fichiers essentiels
    local required_files=(
        "app.py"
        "requirements.txt"
        "Dockerfile"
        "docker-compose.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$PROJECT_ROOT/$file" ]; then
            log_error "Fichier manquant: $file"
            exit 1
        fi
    done
    
    # Vérification des dossiers
    local required_dirs=(
        "$UPLOADS_DIR"
        "$LOGS_DIR"
        "$BACKUPS_DIR"
        "$PROJECT_ROOT/templates"
        "$PROJECT_ROOT/static"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Dossier manquant: $dir"
            exit 1
        fi
    done
    
    log_success "Configuration vérifiée"
}

# Création des scripts utilitaires
create_helper_scripts() {
    log_info "Création des scripts utilitaires..."
    
    # Script de sauvegarde
    cat > "$PROJECT_ROOT/scripts/backup.sh" << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="face_recognition_backup_$TIMESTAMP"

echo "Création de la sauvegarde: $BACKUP_NAME"

# Créer le dossier de sauvegarde
mkdir -p "$BACKUP_DIR"

# Sauvegarder MongoDB
docker-compose exec -T mongo mongodump --db face_recognition_db --archive > "$BACKUP_DIR/$BACKUP_NAME.archive"

# Sauvegarder les uploads
tar -czf "$BACKUP_DIR/$BACKUP_NAME.uploads.tar.gz" uploads/

echo "Sauvegarde créée: $BACKUP_DIR/$BACKUP_NAME"
EOF

    # Script de restauration
    cat > "$PROJECT_ROOT/scripts/restore.sh" << 'EOF'
#!/bin/bash
set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_name>"
    echo "Backups disponibles:"
    ls -la backups/ | grep face_recognition_backup
    exit 1
fi

BACKUP_NAME=$1
BACKUP_DIR="./backups"

if [ ! -f "$BACKUP_DIR/$BACKUP_NAME.archive" ]; then
    echo "Erreur: Sauvegarde non trouvée: $BACKUP_DIR/$BACKUP_NAME.archive"
    exit 1
fi

echo "Restauration de la sauvegarde: $BACKUP_NAME"

# Restaurer MongoDB
docker-compose exec -T mongo mongorestore --db face_recognition_db --archive < "$BACKUP_DIR/$BACKUP_NAME.archive"

# Restaurer les uploads si disponible
if [ -f "$BACKUP_DIR/$BACKUP_NAME.uploads.tar.gz" ]; then
    tar -xzf "$BACKUP_DIR/$BACKUP_NAME.uploads.tar.gz"
    echo "Uploads restaurés"
fi

echo "Restauration terminée"
EOF

    # Script de monitoring
    cat > "$PROJECT_ROOT/scripts/monitor.sh" << 'EOF'
#!/bin/bash

echo "=== Face Recognition App - Status ==="
echo

echo "Services Docker:"
docker-compose ps
echo

echo "Utilisation disque:"
df -h | grep -E "(Filesystem|/dev/)"
echo

echo "Logs récents (10 dernières lignes):"
docker-compose logs --tail=10 web
echo

echo "Utilisateurs MongoDB:"
docker-compose exec mongo mongo face_recognition_db --eval "db.users.count()" --quiet
echo

echo "Connexions aujourd'hui:"
TODAY=$(date +%Y-%m-%d)
docker-compose exec mongo mongo face_recognition_db --eval "db.login_logs.count({login_time: {\$gte: new Date('$TODAY')}})" --quiet
EOF

    # Rendre les scripts exécutables
    chmod +x "$PROJECT_ROOT/scripts"/*.sh
    
    log_success "Scripts utilitaires créés"
}

# Affichage des informations finales
show_info() {
    log_success "Initialisation terminée!"
    echo
    echo -e "${BLUE}=== Informations utiles ===${NC}"
    echo
    echo "Environnement: $ENVIRONMENT"
    echo "Dossier du projet: $PROJECT_ROOT"
    echo
    echo -e "${YELLOW}Commandes utiles:${NC}"
    
    if [ "$ENVIRONMENT" = "dev" ]; then
        echo "  Démarrer en développement: make dev"
        echo "  ou: docker-compose up --build"
    else
        echo "  Démarrer en production: make prod"
        echo "  ou: docker-compose -f docker-compose.prod.yml up -d"
    fi
    
    echo "  Voir les logs: make logs"
    echo "  Arrêter: make down"
    echo "  Sauvegarder: ./scripts/backup.sh"
    echo "  Monitoring: ./scripts/monitor.sh"
    echo
    echo -e "${YELLOW}URLs d'accès:${NC}"
    echo "  Application: http://localhost"
    
    if [ "$ENVIRONMENT" = "dev" ]; then
        echo "  MongoDB Express: http://localhost:8081"
    else
        echo "  Grafana: http://localhost:3000"
        echo "  Prometheus: http://localhost:9090"
    fi
    
    echo
    echo -e "${YELLOW}Fichiers importants:${NC}"
    echo "  Configuration: .env"
    echo "  Logs: logs/"
    echo "  Uploads: uploads/"
    echo "  Sauvegardes: backups/"
    echo
    
    if [ -f "$PROJECT_ROOT/.env" ]; then
        log_warning "N'oubliez pas de modifier le fichier .env selon vos besoins!"
    fi
}

# Fonction principale
main() {
    cd "$PROJECT_ROOT"
    
    echo -e "${BLUE}=== Face Recognition App - Initialisation ===${NC}"
    echo "Environnement: $ENVIRONMENT"
    echo
    
    check_requirements
    create_directories
    setup_permissions
    setup_environment
    setup_ssl
    setup_monitoring
    install_dependencies
    create_helper_scripts
    verify_setup
    
    show_info
}

# Gestion des erreurs
trap 'log_error "Erreur lors de l\'initialisation"; exit 1' ERR

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
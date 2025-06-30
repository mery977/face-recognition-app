# Makefile pour Face Recognition App

.PHONY: help build up down restart logs clean test install dev prod backup

# Variables
PROJECT_NAME=face-recognition-app
DOCKER_COMPOSE=docker-compose
DOCKER_COMPOSE_PROD=docker-compose -f docker-compose.prod.yml
PYTHON=python3
PIP=pip3

# Couleurs pour les messages
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

help: ## Affiche l'aide
	@echo "$(BLUE)Face Recognition App - Commandes disponibles:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

install: ## Install les dépendances Python localement
	@echo "$(YELLOW)Installation des dépendances...$(NC)"
	$(PIP) install -r requirements.txt
	@echo "$(GREEN)✓ Dépendances installées$(NC)"

dev: ## Démarre l'environnement de développement
	@echo "$(YELLOW)Démarrage de l'environnement de développement...$(NC)"
	$(DOCKER_COMPOSE) up --build
	@echo "$(GREEN)✓ Environnement de développement démarré$(NC)"

build: ## Build les images Docker
	@echo "$(YELLOW)Construction des images Docker...$(NC)"
	$(DOCKER_COMPOSE) build
	@echo "$(GREEN)✓ Images construites$(NC)"

up: ## Démarre les services
	@echo "$(YELLOW)Démarrage des services...$(NC)"
	$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✓ Services démarrés$(NC)"
	@echo "$(BLUE)App disponible sur: http://localhost$(NC)"
	@echo "$(BLUE)MongoDB Express: http://localhost:8081$(NC)"

down: ## Arrête les services
	@echo "$(YELLOW)Arrêt des services...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ Services arrêtés$(NC)"

restart: down up ## Redémarre les services

logs: ## Affiche les logs
	@echo "$(YELLOW)Logs de l'application:$(NC)"
	$(DOCKER_COMPOSE) logs -f

logs-web: ## Affiche les logs du service web uniquement
	@echo "$(YELLOW)Logs du service web:$(NC)"
	$(DOCKER_COMPOSE) logs -f web

logs-mongo: ## Affiche les logs MongoDB
	@echo "$(YELLOW)Logs MongoDB:$(NC)"
	$(DOCKER_COMPOSE) logs -f mongo

status: ## Affiche le statut des services
	@echo "$(YELLOW)Statut des services:$(NC)"
	$(DOCKER_COMPOSE) ps

shell: ## Ouvre un shell dans le container web
	@echo "$(YELLOW)Ouverture du shell...$(NC)"
	$(DOCKER_COMPOSE) exec web /bin/bash

shell-mongo: ## Ouvre un shell MongoDB
	@echo "$(YELLOW)Ouverture du shell MongoDB...$(NC)"
	$(DOCKER_COMPOSE) exec mongo mongo

clean: ## Nettoie les données et images
	@echo "$(YELLOW)Nettoyage...$(NC)"
	$(DOCKER_COMPOSE) down -v --rmi all
	docker system prune -f
	@echo "$(GREEN)✓ Nettoyage effectué$(NC)"

clean-data: ## Supprime uniquement les données (volumes)
	@echo "$(RED)⚠️  Suppression des données...$(NC)"
	@read -p "Êtes-vous sûr ? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DOCKER_COMPOSE) down -v; \
		echo "$(GREEN)✓ Données supprimées$(NC)"; \
	else \
		echo "$(YELLOW)Annulé$(NC)"; \
	fi

backup: ## Sauvegarde la base de données
	@echo "$(YELLOW)Sauvegarde en cours...$(NC)"
	@mkdir -p ./backups
	$(DOCKER_COMPOSE) exec mongo mongodump --db face_recognition_db --out /tmp/backup
	$(DOCKER_COMPOSE) cp mongo:/tmp/backup ./backups/backup_$(shell date +%Y%m%d_%H%M%S)
	@echo "$(GREEN)✓ Sauvegarde créée dans ./backups/$(NC)"

restore: ## Restaure la base de données (usage: make restore BACKUP=backup_20231201_120000)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)Erreur: Spécifiez un backup avec BACKUP=nom_du_backup$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Restauration du backup $(BACKUP)...$(NC)"
	$(DOCKER_COMPOSE) cp ./backups/$(BACKUP) mongo:/tmp/restore
	$(DOCKER_COMPOSE) exec mongo mongorestore --db face_recognition_db --drop /tmp/restore/face_recognition_db
	@echo "$(GREEN)✓ Base de données restaurée$(NC)"

test: ## Lance les tests
	@echo "$(YELLOW)Lancement des tests...$(NC)"
	$(PYTHON) -m pytest tests/ -v
	@echo "$(GREEN)✓ Tests terminés$(NC)"

lint: ## Vérifie le code avec flake8
	@echo "$(YELLOW)Vérification du code...$(NC)"
	flake8 app.py --max-line-length=88 --ignore=E203,W503
	@echo "$(GREEN)✓ Code vérifié$(NC)"

format: ## Formate le code avec black
	@echo "$(YELLOW)Formatage du code...$(NC)"
	black app.py --line-length=88
	@echo "$(GREEN)✓ Code formaté$(NC)"

prod: ## Démarre l'environnement de production
	@echo "$(YELLOW)Démarrage de l'environnement de production...$(NC)"
	$(DOCKER_COMPOSE_PROD) up -d --build
	@echo "$(GREEN)✓ Production démarrée$(NC)"
	@echo "$(BLUE)App disponible sur: http://localhost$(NC)"
	@echo "$(BLUE)Monitoring: http://localhost:3000$(NC)"

prod-down: ## Arrête l'environnement de production
	@echo "$(YELLOW)Arrêt de la production...$(NC)"
	$(DOCKER_COMPOSE_PROD) down
	@echo "$(GREEN)✓ Production arrêtée$(NC)"

prod-logs: ## Affiche les logs de production
	@echo "$(YELLOW)Logs de production:$(NC)"
	$(DOCKER_COMPOSE_PROD) logs -f

monitor: ## Ouvre l'interface de monitoring
	@echo "$(BLUE)Ouverture du monitoring...$(NC)"
	@if command -v xdg-open > /dev/null; then \
		xdg-open http://localhost:3000; \
	elif command -v open > /dev/null; then \
		open http://localhost:3000; \
	else \
		echo "$(BLUE)Monitoring disponible sur: http://localhost:3000$(NC)"; \
	fi

setup: ## Configuration initiale du projet
	@echo "$(YELLOW)Configuration initiale...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)✓ Fichier .env créé$(NC)"; \
	fi
	@mkdir -p uploads logs backups static/uploads
	@echo "$(GREEN)✓ Dossiers créés$(NC)"
	@echo "$(BLUE)Pensez à modifier le fichier .env selon vos besoins$(NC)"

update: ## Met à jour les dépendances
	@echo "$(YELLOW)Mise à jour des dépendances...$(NC)"
	$(PIP) install --upgrade -r requirements.txt
	$(DOCKER_COMPOSE) build --no-cache
	@echo "$(GREEN)✓ Dépendances mises à jour$(NC)"

security-scan: ## Scan de sécurité des dépendances
	@echo "$(YELLOW)Scan de sécurité...$(NC)"
	$(PIP) install safety
	safety check -r requirements.txt
	@echo "$(GREEN)✓ Scan de sécurité terminé$(NC)"

deploy: ## Déploie en production avec vérifications
	@echo "$(YELLOW)Déploiement en production...$(NC)"
	@make lint
	@make test
	@make security-scan
	@echo "$(GREEN)✓ Vérifications passées$(NC)"
	@read -p "Déployer en production ? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		make prod; \
		echo "$(GREEN)✓ Déployé en production$(NC)"; \
	else \
		echo "$(YELLOW)Déploiement annulé$(NC)"; \
	fi

docs: ## Génère la documentation
	@echo "$(YELLOW)Génération de la documentation...$(NC)"
	@if command -v mkdocs > /dev/null; then \
		mkdocs serve; \
	else \
		echo "$(BLUE)Documentation disponible dans README.md$(NC)"; \
	fi

# Commandes de développement
dev-init: setup install ## Initialisation complète pour développement
	@echo "$(GREEN)✓ Environnement de développement initialisé$(NC)"
	@echo "$(BLUE)Utilisez 'make dev' pour démarrer$(NC)"

dev-reset: clean setup ## Reset complet de l'environnement de développement
	@echo "$(GREEN)✓ Environnement réinitialisé$(NC)"

# Outils de base de données
db-migrate: ## Exécute les migrations de base de données
	@echo "$(YELLOW)Exécution des migrations...$(NC)"
	$(DOCKER_COMPOSE) exec web python manage.py migrate
	@echo "$(GREEN)✓ Migrations exécutées$(NC)"

db-seed: ## Ajoute des données de test
	@echo "$(YELLOW)Ajout de données de test...$(NC)"
	$(DOCKER_COMPOSE) exec web python manage.py seed
	@echo "$(GREEN)✓ Données de test ajoutées$(NC)"

# Commandes utilitaires
ps: status ## Alias pour status

version: ## Affiche la version
	@echo "$(BLUE)Face Recognition App v1.0.0$(NC)"
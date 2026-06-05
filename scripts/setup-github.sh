#!/bin/bash
# ============================================================
# ACCENT — Script de Setup du Repository GitHub
# ============================================================
# Ce script initialise un dépôt git local, effectue le premier
# commit et pousse le projet vers un dépôt GitHub distant.
#
# Prérequis :
#   - Git installé et configuré (user.name, user.email)
#   - Dépôt GitHub créé (vide, sans README ni .gitignore)
#   - Accès en écriture au dépôt distant
#
# Usage :
#   1. Éditer GITHUB_USERNAME ci-dessous
#   2. Rendre le script exécutable : chmod +x setup-repo.sh
#   3. Exécuter depuis la racine du projet : ./setup-repo.sh
#
# Options :
#   --dry-run    Simule l'exécution sans pousser vers GitHub
#   --force      Force le push (écrase l'historique distant)
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------
GITHUB_USERNAME="21Yeet21"
REPO_NAME="accent-infrastructure"
BRANCH="main"
DRY_RUN=false
FORCE_PUSH=false

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ------------------------------------------------------------
# Fonctions utilitaires
# ------------------------------------------------------------
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

usage() {
    echo "Usage: $0 [--dry-run] [--force]"
    echo ""
    echo "Options :"
    echo "  --dry-run    Simule l'exécution sans pousser vers GitHub"
    echo "  --force      Force le push (écrase l'historique distant)"
    echo ""
    exit 1
}

# ------------------------------------------------------------
# Parsing des arguments
# ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            log_warn "Mode dry-run activé — aucun changement ne sera poussé"
            shift
            ;;
        --force)
            FORCE_PUSH=true
            log_warn "Mode force push activé"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Option inconnue : $1"
            usage
            ;;
    esac
done

# ------------------------------------------------------------
# Vérifications préalables
# ------------------------------------------------------------
log_info "Vérification des prérequis..."

# Vérifier que git est installé
if ! command -v git &> /dev/null; then
    log_error "Git n'est pas installé. Installez-le avec : sudo apt install git"
    exit 1
fi
log_success "Git installé : $(git --version)"

# Vérifier la configuration git
if ! git config user.name &> /dev/null; then
    log_error "Git user.name non configuré. Exécutez : git config --global user.name 'Votre Nom'"
    exit 1
fi

if ! git config user.email &> /dev/null; then
    log_error "Git user.email non configuré. Exécutez : git config --global user.email 'votre@email.com'"
    exit 1
fi
log_success "Git configuré pour : $(git config user.name) <$(git config user.email)>"

# Vérifier que nous sommes dans le bon dossier
if [ ! -f "README.md" ]; then
    log_error "README.md introuvable. Exécutez ce script depuis la racine du projet accent-infrastructure."
    exit 1
fi
log_success "Dossier projet valide détecté"

# Vérifier si le dossier est déjà un dépôt git
if [ -d ".git" ]; then
    log_warn "Un dépôt git existe déjà dans ce dossier"
    read -p "Voulez-vous réinitialiser le dépôt ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf .git
        log_info "Ancien dépôt git supprimé"
    else
        log_error "Opération annulée"
        exit 1
    fi
fi

# ------------------------------------------------------------
# Initialisation du dépôt
# ------------------------------------------------------------
log_info "Initialisation du dépôt git..."
git init -b "$BRANCH"
log_success "Dépôt initialisé sur la branche $BRANCH"

# ------------------------------------------------------------
# Création du .gitignore si absent
# ------------------------------------------------------------
if [ ! -f ".gitignore" ]; then
    log_warn "Aucun .gitignore trouvé — création d'un fichier minimal"
    cat > .gitignore << 'EOF'
# Secrets et credentials
.env
.env.local
*.pem
*.key
*.crt
*.p12
slack-webhook.txt
wazuh-passwords.txt

# OS et éditeurs
.DS_Store
Thumbs.db
.vscode/
.idea/
*.swp
*~

# Docker et données
*.log
data/
volumes/

# Binaires et archives
*.tar.gz
*.zip
*.iso
*.qcow2
*.vmdk
EOF
    log_success ".gitignore créé"
fi

# ------------------------------------------------------------
# Commit initial
# ------------------------------------------------------------
log_info "Ajout de tous les fichiers..."
git add .

# Vérifier qu'il y a bien des fichiers à committer
if git diff --cached --quiet; then
    log_error "Aucun fichier à committer. Vérifiez le contenu du dossier."
    exit 1
fi

FILE_COUNT=$(git diff --cached --name-only | wc -l)
log_success "$FILE_COUNT fichiers ajoutés à l'index"

log_info "Création du commit initial..."
git commit -m "Initial commit — ACCENT Infrastructure project

Infrastructure complète d'observabilité et de sécurité déployée en
environnement virtualisé (EVE-NG, Proxmox VE) avec stack Grafana,
Wazuh HIDS et haute disponibilité.

Contenu du commit :
- Configuration complète (pfSense, Prometheus, Grafana, Loki, Tempo, Wazuh)
- Documentation technique (9 sprints, architecture, webographie)
- Procédures opérationnelles (démarrage, arrêt, tests, dépannage)
- Scripts d'automatisation (installation, déploiement)
- Templates EVE-NG et configurations Cisco
- Dashboards Grafana et règles d'alerte

Projet réalisé par 21Yeet21 — PFE 2026
Encadré par M. Sofiane El Mahroug"

log_success "Commit initial créé"

# ------------------------------------------------------------
# Configuration du remote
# ------------------------------------------------------------
REMOTE_URL="https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
log_info "Configuration du remote : $REMOTE_URL"

if git remote get-url origin &> /dev/null; then
    log_warn "Remote 'origin' existe déjà — mise à jour de l'URL"
    git remote set-url origin "$REMOTE_URL"
else
    git remote add origin "$REMOTE_URL"
fi
log_success "Remote configuré"

# ------------------------------------------------------------
# Push vers GitHub
# ------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    log_warn "Mode dry-run — push simulé (non exécuté)"
    echo ""
    echo "Commande qui aurait été exécutée :"
    if [ "$FORCE_PUSH" = true ]; then
        echo "  git push -u origin $BRANCH --force"
    else
        echo "  git push -u origin $BRANCH"
    fi
else
    log_info "Push vers GitHub..."
    if [ "$FORCE_PUSH" = true ]; then
        git push -u origin "$BRANCH" --force
    else
        git push -u origin "$BRANCH"
    fi
    log_success "Push terminé avec succès"
fi

# ------------------------------------------------------------
# Résumé final
# ------------------------------------------------------------
echo ""
echo "============================================================"
echo -e "${GREEN}✅ Repository ACCENT initialisé avec succès !${NC}"
echo "============================================================"
echo ""
echo "  URL GitHub : https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo "  Branche    : $BRANCH"
echo "  Fichiers   : $FILE_COUNT"
echo ""
echo "Prochaines étapes :"
echo "  1. Vérifier le dépôt sur GitHub"
echo "  2. Ajouter votre collaborateur dans Settings → Collaborators"
echo "  3. Mettre à jour le README.md avec les informations du co-auteur"
echo ""
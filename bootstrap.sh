#!/usr/bin/env bash
# Richtet die VM ein und startet das Dev-Portal.
#
# Im Projektordner als normaler Benutzer mit sudo-Rechten ausführen:
#   ./bootstrap.sh
#
# Schritte: System aktualisieren, Docker installieren, git vorbereiten,
# docker/.env mit zufälligen Passwörtern anlegen, alles bauen und starten.
# Das Skript kann erneut ausgeführt werden; eine vorhandene docker/.env
# bleibt unverändert.
#
# Andere Ports oder ein anderer Projektname beim ersten Lauf:
#   PORTAL_PORT=9000 PROD_PORT=9080 COMPOSE_PROJECT_NAME=meinprojekt ./bootstrap.sh
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
PROJECT_DIR=$PWD
ENV_FILE=docker/.env

die()  { echo "Fehler: $*" >&2; exit 1; }
info() { echo; echo "==> $*"; }

# ask VARIABLE "Frage" "Standardwert"
ask() {
    local __var=$1 prompt=$2 default=${3:-} answer
    if [ -n "$default" ]; then
        read -r -p "$prompt [$default]: " answer
    else
        read -r -p "$prompt: " answer
    fi
    printf -v "$__var" '%s' "${answer:-$default}"
}

random_password() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true; }

[ "$(id -u)" -ne 0 ] || die "Bitte nicht als root, sondern als normaler Benutzer mit sudo-Rechten ausführen."
command -v sudo >/dev/null || die "sudo fehlt."
[ -f docker/compose.yaml ] || die "docker/compose.yaml nicht gefunden. Bitte im Projektordner ausführen."
. /etc/os-release
[ "${ID:-}" = debian ] || echo "Hinweis: getestet mit Debian 13, gefunden: ${PRETTY_NAME:-unbekannt}"

echo "Dev-Portal einrichten in $PROJECT_DIR"
sudo true  # fragt bei Bedarf einmal nach dem sudo-Passwort

# --- 1. Abfragen --------------------------------------------------------
NEW_ENV=0
if [ ! -f "$ENV_FILE" ]; then
    NEW_ENV=1
    info "Adressen hinter dem Reverse Proxy (ohne https://)"
    while :; do
        ask DEV_DOMAIN "Domain für das Dev-Portal, z. B. dev.meinedomain.de" ""
        [[ $DEV_DOMAIN =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] && break
        echo "Bitte eine Domain wie dev.meinedomain.de eingeben."
    done
    while :; do
        ask PROD_DOMAIN "Domain für die fertige Website, z. B. app.meinedomain.de" ""
        [[ $PROD_DOMAIN =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] && [ "$PROD_DOMAIN" != "$DEV_DOMAIN" ] && break
        echo "Bitte eine andere Domain als für das Dev-Portal eingeben."
    done
fi

CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)
[ "$CURRENT_TZ" = UTC ] && CURRENT_TZ=Europe/Berlin
ask TIMEZONE "Zeitzone" "$CURRENT_TZ"
[ -f "/usr/share/zoneinfo/$TIMEZONE" ] || die "Unbekannte Zeitzone: $TIMEZONE"

GIT_NAME=$(git config --global user.name 2>/dev/null || true)
GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    info "git (für Commits, leer lassen = später selbst einrichten)"
    ask GIT_NAME "Name für git-Commits" "$GIT_NAME"
    ask GIT_EMAIL "E-Mail für git-Commits" "$GIT_EMAIL"
fi

# --- 2. System und Docker ----------------------------------------------
info "System aktualisieren und Pakete installieren"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -q
sudo -E apt-get -y -q full-upgrade
sudo -E apt-get -y -q install ca-certificates curl git gnupg qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent 2>/dev/null || true
sudo timedatectl set-timezone "$TIMEZONE"

if ! command -v docker >/dev/null; then
    info "Docker Engine aus dem offiziellen Docker-Repository installieren"
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    printf 'Types: deb\nURIs: https://download.docker.com/linux/debian\nSuites: %s\nComponents: stable\nSigned-By: /etc/apt/keyrings/docker.asc\n' \
        "$VERSION_CODENAME" | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
    sudo apt-get update -q
    sudo -E apt-get -y -q install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo usermod -aG docker "$USER"

# Die neue Gruppe gilt erst nach erneutem Login, bis dahin Docker per sudo
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi

# --- 3. git -------------------------------------------------------------
# Konfiguration und Zugangsdaten liegen in ~/.config/git, dieser Ordner wird
# in code-server eingebunden (git pull/push auch im Terminal von VS Code).
info "git vorbereiten"
GIT_DIR=$HOME/.config/git
mkdir -p "$GIT_DIR" && chmod 700 "$GIT_DIR"
if [ -f ~/.gitconfig ] && [ ! -s "$GIT_DIR/config" ]; then
    mv ~/.gitconfig "$GIT_DIR/config" && echo "$HOME/.gitconfig nach $GIT_DIR/config verschoben"
fi
if [ -f ~/.git-credentials ] && [ ! -s "$GIT_DIR/credentials" ]; then
    mv ~/.git-credentials "$GIT_DIR/credentials" && echo "$HOME/.git-credentials nach $GIT_DIR/credentials verschoben"
fi
touch "$GIT_DIR/config"
[ -f ~/.gitconfig ] && echo "Hinweis: ~/.gitconfig existiert zusätzlich, code-server sieht nur $GIT_DIR/config."
[ -n "$GIT_NAME" ]  && git config --global user.name "$GIT_NAME"
[ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global credential.helper >/dev/null || git config --global credential.helper store

# --- 4. docker/.env -----------------------------------------------------
if [ "$NEW_ENV" = 1 ]; then
    info "docker/.env mit zufälligen Passwörtern anlegen"
    umask 077
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            COMPOSE_PROJECT_NAME=*) line="COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-${line#*=}}" ;;
            PORTAL_PORT=*)    line="PORTAL_PORT=${PORTAL_PORT:-${line#*=}}" ;;
            PROD_PORT=*)      line="PROD_PORT=${PROD_PORT:-${line#*=}}" ;;
            DEV_DOMAIN=*)     line="DEV_DOMAIN=$DEV_DOMAIN" ;;
            PROD_DOMAIN=*)    line="PROD_DOMAIN=$PROD_DOMAIN" ;;
            MAIL_FROM=*)      line="MAIL_FROM=noreply@$PROD_DOMAIN" ;;
            TZ=*)             line="TZ=$TIMEZONE" ;;
            DEV_UID=*)        line="DEV_UID=$(id -u)" ;;
            DEV_GID=*)        line="DEV_GID=$(id -g)" ;;
            GIT_CONFIG_DIR=*) line="GIT_CONFIG_DIR=$GIT_DIR" ;;
            *=__RANDOM__)     line="${line%=*}=$(random_password)" ;;
        esac
        printf '%s\n' "$line"
    done < docker/.env.example > "$ENV_FILE"
    umask 022
else
    info "docker/.env existiert bereits und bleibt unverändert"
fi

env_value() { { grep "^$1=" "$ENV_FILE" || true; } | cut -d= -f2- | tr -d "'\""; }
PORTAL_PORT=$(env_value PORTAL_PORT); PORTAL_PORT=${PORTAL_PORT:-8000}
PROD_PORT=$(env_value PROD_PORT); PROD_PORT=${PROD_PORT:-8080}

# --- 5. Bauen und starten -----------------------------------------------
info "Container bauen und starten (beim ersten Mal einige Minuten)"
(cd docker && "${DOCKER[@]}" compose up -d --build)

info "Warte, bis Dev-Portal und Datenbank bereit sind"
ok=0
for _ in $(seq 1 90); do
    if curl -fsS "http://localhost:$PORTAL_PORT/api/health" >/dev/null 2>&1 \
        && curl -fsS "http://localhost:$PROD_PORT/api/health" >/dev/null 2>&1; then
        ok=1; break
    fi
    sleep 5
done
[ "$ok" = 1 ] || die "Dienste antworten nicht. Logs ansehen: cd docker && ${DOCKER[*]} compose logs"

info "phpMyAdmin-Konfigurationsspeicher einrichten"
if [ "${DOCKER[0]}" = sudo ]; then sudo docker/setup-pma.sh; else docker/setup-pma.sh; fi

# --- 6. Zusammenfassung -------------------------------------------------
IP=$(hostname -I | awk '{print $1}')
cat <<DONE

Fertig! Alles läuft.

Im LAN:
  Dev-Portal:       http://$IP:$PORTAL_PORT
  Fertige Website:  http://$IP:$PROD_PORT

Reverse-Proxy-Einträge (HTTPS, siehe README):
  https://$(env_value DEV_DOMAIN)  ->  http://$IP:$PORTAL_PORT   (mit Login schützen, Websockets an)
  https://$(env_value PROD_DOMAIN)  ->  http://$IP:$PROD_PORT

Passwort für VS Code (code-server): $(env_value CODE_SERVER_PASSWORD)
Alle Passwörter stehen in $PROJECT_DIR/$ENV_FILE

Wichtig: Einmal ab- und wieder anmelden, damit "docker" ohne sudo funktioniert.
DONE

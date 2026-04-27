#!/usr/bin/env bash
# Instala Docker Engine + plugin compose en la distro detectada.
# Soporta: Debian/Ubuntu, Fedora/RHEL/CentOS, Arch/Manjaro.
# Para macOS sólo informa cómo bajar Docker Desktop.

set -euo pipefail

c_red()    { printf "\033[31m%s\033[0m\n" "$*"; }
c_green()  { printf "\033[32m%s\033[0m\n" "$*"; }
c_yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
c_dim()    { printf "\033[2m%s\033[0m\n" "$*"; }

require_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            c_red "Necesito sudo o ejecutar como root."
            exit 1
        fi
        SUDO="sudo"
    else
        SUDO=""
    fi
}

post_install_user() {
    local user="${SUDO_USER:-$USER}"
    if [ "$user" = "root" ]; then return; fi
    c_yellow "Agregando '$user' al grupo docker..."
    $SUDO groupadd -f docker
    $SUDO usermod -aG docker "$user"
    c_dim "Cerrá sesión y volvé a entrar (o corré 'newgrp docker') para que tome efecto."
}

enable_service() {
    if command -v systemctl >/dev/null 2>&1; then
        $SUDO systemctl enable --now docker
    fi
}

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
    c_yellow "macOS detectado."
    c_dim "Instalá Docker Desktop desde: https://www.docker.com/products/docker-desktop/"
    c_dim "Si tenés Homebrew:  brew install --cask docker"
    exit 0
fi

if [ "$OS" != "Linux" ]; then
    c_red "Sistema no soportado: $OS"
    c_dim "Para Windows usá: powershell -ExecutionPolicy Bypass -File scripts/install-docker.ps1"
    exit 1
fi

if [ ! -r /etc/os-release ]; then
    c_red "No puedo identificar la distro (falta /etc/os-release)."
    exit 1
fi
. /etc/os-release
DISTRO_ID="${ID:-}"
DISTRO_LIKE="${ID_LIKE:-}"

require_sudo
echo "==> Distro detectada: ${PRETTY_NAME:-$DISTRO_ID}"

case "$DISTRO_ID $DISTRO_LIKE" in
    *debian*|*ubuntu*)
        c_green "Instalando Docker en Debian/Ubuntu..."
        $SUDO apt-get update
        $SUDO apt-get install -y ca-certificates curl gnupg
        $SUDO install -m 0755 -d /etc/apt/keyrings
        if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
            curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" \
                | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
        fi
        CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-$UBUNTU_CODENAME}")"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${DISTRO_ID} ${CODENAME} stable" \
            | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
        $SUDO apt-get update
        $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        ;;

    *fedora*|*rhel*|*centos*|*rocky*|*almalinux*)
        c_green "Instalando Docker en Fedora/RHEL..."
        if command -v dnf >/dev/null 2>&1; then
            PKG=dnf
        else
            PKG=yum
        fi
        $SUDO $PKG -y install dnf-plugins-core || true
        $SUDO $PKG config-manager --add-repo \
            https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null \
            || $SUDO $PKG config-manager --add-repo \
                https://download.docker.com/linux/centos/docker-ce.repo
        $SUDO $PKG install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        ;;

    *arch*|*manjaro*)
        c_green "Instalando Docker en Arch/Manjaro..."
        $SUDO pacman -Sy --noconfirm --needed docker docker-compose docker-buildx
        ;;

    *)
        c_red "Distro no soportada automáticamente: $DISTRO_ID"
        c_dim "Seguí la guía oficial: https://docs.docker.com/engine/install/"
        exit 1
        ;;
esac

enable_service
post_install_user

echo
c_green "Docker instalado."
docker --version || true
docker compose version || true
c_dim "Verificá con:  ./scripts/check-docker.sh"

#!/usr/bin/env bash
# Verifica si Docker está instalado y el daemon responde.
# Uso:
#   ./check-docker.sh           -> sólo verifica
#   ./check-docker.sh --install -> intenta instalar si falta (delega en install-docker.sh)
#
# Códigos de salida:
#   0  Docker OK (cliente + daemon respondiendo + compose v2)
#   1  Docker instalado pero el daemon no responde
#   2  Docker no instalado
#   3  Falta `docker compose` (plugin v2)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

c_red()   { printf "\033[31m%s\033[0m\n" "$*"; }
c_green() { printf "\033[32m%s\033[0m\n" "$*"; }
c_yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
c_dim()   { printf "\033[2m%s\033[0m\n" "$*"; }

OS="$(uname -s)"
case "$OS" in
    Linux*)   PLATFORM="linux" ;;
    Darwin*)  PLATFORM="macos" ;;
    MINGW*|MSYS*|CYGWIN*)
        c_yellow "Detectado entorno tipo Windows (Git Bash / MSYS)."
        c_yellow "Para Windows usá: powershell -ExecutionPolicy Bypass -File scripts/check-docker.ps1"
        exit 2
        ;;
    *)
        c_red "Sistema operativo no reconocido: $OS"
        exit 2
        ;;
esac

echo "==> Plataforma: $PLATFORM"

if ! command -v docker >/dev/null 2>&1; then
    c_red "[X] Docker no está instalado."
    if [ "${1:-}" = "--install" ]; then
        c_yellow "Lanzando instalador..."
        exec "$SCRIPT_DIR/install-docker.sh"
    else
        c_dim "Sugerencia: ejecutá  '$0 --install'  para instalarlo,"
        c_dim "             o corré directamente  '$SCRIPT_DIR/install-docker.sh'."
    fi
    exit 2
fi

DOCKER_VERSION="$(docker --version 2>/dev/null || true)"
c_green "[OK] Docker CLI encontrado: $DOCKER_VERSION"

if ! docker compose version >/dev/null 2>&1; then
    c_red "[X] No se encuentra el plugin 'docker compose' (v2)."
    c_dim "    Instalá docker-compose-plugin (Linux) o actualizá Docker Desktop."
    exit 3
fi
c_green "[OK] $(docker compose version | head -n 1)"

if ! docker info >/dev/null 2>&1; then
    c_red "[X] El daemon de Docker no responde."
    if [ "$PLATFORM" = "linux" ]; then
        c_dim "    Probá:  sudo systemctl start docker"
        c_dim "    Si tu usuario no está en el grupo 'docker':"
        c_dim "        sudo usermod -aG docker \$USER  &&  newgrp docker"
    elif [ "$PLATFORM" = "macos" ]; then
        c_dim "    Iniciá Docker Desktop desde Aplicaciones."
    fi
    exit 1
fi

c_green "[OK] Daemon respondiendo."
echo
c_dim "Listo: podés correr  ./stack.sh start  desde node-red/"
exit 0

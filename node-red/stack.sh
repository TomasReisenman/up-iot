#!/bin/bash
# Script unificado para manejar el stack Docker
# Uso: ./stack.sh start|restart|stop|clean

PROJECT_NAME="iot-stack"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function ensure_docker() {
    if [ -x "$SCRIPT_DIR/scripts/check-docker.sh" ]; then
        if ! "$SCRIPT_DIR/scripts/check-docker.sh" >/dev/null 2>&1; then
            echo "Docker no está listo. Diagnóstico:"
            "$SCRIPT_DIR/scripts/check-docker.sh" || true
            echo
            echo "Para instalarlo: $SCRIPT_DIR/scripts/install-docker.sh"
            exit 1
        fi
    fi
}

function start_stack() {
    ensure_docker
    echo "Iniciando stack Docker..."
    docker compose -p $PROJECT_NAME up -d --build
    echo "Stack iniciado. Contenedores activos:"
    docker ps --filter "name=$PROJECT_NAME"
}

function restart_stack() {
    echo "Reiniciando stack Docker..."
    docker compose -p $PROJECT_NAME restart
    echo "Stack reiniciado. Contenedores activos:"
    docker ps --filter "name=$PROJECT_NAME"
}

function stop_stack() {
    echo "Deteniendo stack Docker..."
    docker compose -p $PROJECT_NAME down
    echo "Stack detenido."
}

function clean_stack() {
    echo "Eliminando stack Docker completamente..."
    docker compose -p $PROJECT_NAME down -v --remove-orphans
    echo "Stack eliminado completamente."
}

# Verificar argumento
case "$1" in
    start)
        start_stack
        ;;
    restart)
        restart_stack
        ;;
    stop)
        stop_stack
        ;;
    clean)
        clean_stack
        ;;
    *)
        echo "Uso: $0 {start|restart|stop|clean}"
        exit 1
        ;;
esac

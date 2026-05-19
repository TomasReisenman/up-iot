#!/usr/bin/env bash

BROKER="192.168.1.9"
PORT=1883
TOKEN="06e68bebe774b5b382ae5522de1ee267"
TOPIC="biometrico/caida"

pub() {
  mosquitto_pub -h "$BROKER" -p "$PORT" -t "$TOPIC" \
    -m "{\"t\":\"$TOKEN\",\"v\":$1}"
}

case "${1:-menu}" in
  caida)
    echo ">>> CAIDA"
    pub 1
    ;;
  ok)
    echo ">>> SIN CAIDA"
    pub 0
    ;;
  menu|*)
    echo ""
    echo "  1) Enviar CAIDA     (v=1)"
    echo "  2) Sin caida        (v=0)"
    echo "  3) Secuencia demo   (caida → ok)"
    echo "  q) Salir"
    echo ""
    while true; do
      read -rp "  > " opt
      case "$opt" in
        1) echo ">>> CAIDA"; pub 1 ;;
        2) echo ">>> SIN CAIDA"; pub 0 ;;
        3)
          echo ">>> CAIDA"
          pub 1
          sleep 3
          echo ">>> SIN CAIDA"
          pub 0
          ;;
        q|Q) break ;;
        *) echo "  Opcion invalida" ;;
      esac
    done
    ;;
esac

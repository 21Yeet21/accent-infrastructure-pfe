#!/bin/bash
# Script de préparation des volumes persistants pour la stack de monitoring
# Cible : MonSrv

set -e
STACK_DIR="${HOME}/monitoring-stack"

echo "[*] Création des répertoires de la stack..."
mkdir -p "${STACK_DIR}/prometheus-data"
mkdir -p "${STACK_DIR}/grafana-data"
mkdir -p "${STACK_DIR}/loki-data"
mkdir -p "${STACK_DIR}/tempo-data"

echo "[*] Attribution des permissions (UID/GID des conteneurs)..."
# Prometheus (nobody:nogroup = 65534:65534)
chown -R 65534:65534 "${STACK_DIR}/prometheus-data"
# Grafana (grafana = 472:472)
chown -R 472:472 "${STACK_DIR}/grafana-data"
# Loki (loki = 10001:10001)
chown -R 10001:10001 "${STACK_DIR}/loki-data"
# Tempo (tempo = 10001:10001)
chown -R 10001:10001 "${STACK_DIR}/tempo-data"

echo "[+] Volumes persistants configurés avec succès dans ${STACK_DIR}"
ls -ld "${STACK_DIR}"/*
#!/bin/bash
# Script d'installation de Prometheus Node Exporter
# Cible : pve1 (Proxmox VE)

set -e
VERSION="1.7.0"

echo "[*] Téléchargement de Node Exporter v${VERSION}..."
wget -q https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz

echo "[*] Extraction et installation..."
tar xzf node_exporter-${VERSION}.linux-amd64.tar.gz
cp node_exporter-${VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${VERSION}.linux-amd64*

echo "[*] Création de l'utilisateur système..."
useradd --no-create-home --shell /bin/false node_exporter || true

echo "[*] Création du service systemd..."
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Rechargement et démarrage du service..."
systemctl daemon-reload
systemctl enable --now node_exporter

echo "[+] Node Exporter installé et actif."
systemctl status node_exporter --no-pager
#!/bin/bash
# Script d'installation de l'agent Wazuh
# Cible : S1, S2, pve1 (Debian/Ubuntu/Proxmox)
# Version : 4.11.2

set -e

WAZUH_VERSION="4.11.2"
WAZUH_AGENT_DEB="wazuh-agent_${WAZUH_VERSION}-1_amd64.deb"
DOWNLOAD_URL="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/${WAZUH_AGENT_DEB}"

echo "[*] Téléchargement de l'agent Wazuh v${WAZUH_VERSION}..."
curl -so "${WAZUH_AGENT_DEB}" "${DOWNLOAD_URL}"

echo "[*] Installation du package..."
dpkg -i "${WAZUH_AGENT_DEB}"

echo "[*] Nettoyage du fichier téléchargé..."
rm -f "${WAZUH_AGENT_DEB}"

echo "[+] Agent Wazuh installé avec succès."
echo "[!] N'oubliez pas de configurer l'adresse du manager dans /var/ossec/etc/ossec.conf"
echo "[!] Puis exécutez : systemctl daemon-reload && systemctl enable --now wazuh-agent"
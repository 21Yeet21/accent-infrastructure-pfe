#!/bin/bash
# Script d'installation de Docker et Docker Compose
# Cible : MonSrv (Debian/Ubuntu)

set -e

echo "[*] Mise à jour des paquets..."
apt update && apt install -y ca-certificates curl gnupg lsb-release

echo "[*] Ajout de la clé GPG officielle de Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "[*] Ajout du dépôt Docker..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[*] Installation de Docker CE et Docker Compose..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[*] Démarrage et activation de Docker..."
systemctl enable --now docker

echo "[+] Installation de Docker terminée avec succès."
docker --version
docker compose version
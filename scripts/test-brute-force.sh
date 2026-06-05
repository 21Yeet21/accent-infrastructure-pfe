#!/bin/bash
# Script de simulation d'attaque par force brute SSH
# Cible : S2 (192.168.50.12) depuis S1
# Objectif : Déclencher l'alerte Wazuh "sshd: brute force" (Rule 5712/5720)

TARGET_IP="192.168.50.12"
USER="wronguser"
ATTEMPTS=15

echo "[*] Démarrage de la simulation d'attaque SSH vers ${TARGET_IP}..."
echo "[*] Nombre de tentatives : ${ATTEMPTS}"

for i in $(seq 1 ${ATTEMPTS}); do
    echo "[${i}/${ATTEMPTS}] Tentative de connexion avec utilisateur '${USER}'..."
    # -o BatchMode=yes empêche la demande interactive de mot de passe
    # -o ConnectTimeout=2 accélère l'échec
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o BatchMode=yes "${USER}@${TARGET_IP}" "exit" 2>/dev/null
    sleep 0.5
done

echo "[+] Simulation terminée."
echo "[!] Vérifiez les alertes Wazuh (Dashboard ou Slack) dans les 30 prochaines secondes."
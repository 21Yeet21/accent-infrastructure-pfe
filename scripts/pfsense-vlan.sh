#!/bin/bash
# Proxmox hook script for pfSense VM (VMID 104)
# Purpose: Configure VLAN tagging on the LAN interface after VM start
# Location on Proxmox host: /var/lib/vz/snippets/pfsense-vlan.sh
#
# Usage: qm set 104 --hookscript local:snippets/pfsense-vlan.sh

if [ "$2" = "post-start" ]; then
    TAP="tap${1}i1"
    
    # Wait for TAP interface to appear
    for i in $(seq 1 10); do
        ip link show "$TAP" >/dev/null 2>&1 && break
        sleep 1
    done
    
    if ! ip link show "$TAP" >/dev/null 2>&1; then
        echo "[ERROR] $TAP not found" >&2
        exit 1
    fi
    
    # Add TAP to bridge and configure VLANs
    ip link set "$TAP" master vmbr0 2>/dev/null || true
    bridge vlan del dev "$TAP" vid 1 2>/dev/null || true
    bridge vlan add dev "$TAP" vid 20 pvid untagged master
    bridge vlan add dev "$TAP" vid 10 tagged master
    bridge vlan add dev "$TAP" vid 50 tagged master
fi
# Sprint 5 — Déploiement de Prometheus & Exporters

> **Durée:** 2 semaines · **Story Points:** 8 · **User Stories:** US-5.1, US-5.2

---

## 🎯 Objectif

Déployer MonSrv et la stack de collecte de métriques avec Prometheus et exporters.

---

## 📦 Livrables

- ✅ VM 105 MonSrv (Debian 13, 192.168.50.10, VLAN50)
- ✅ Stack Docker Compose : Prometheus, Grafana, Loki, Tempo
- ✅ 5 targets Prometheus UP (scrape 15s, rétention 15j)
- ✅ Node Exporter sur S1, S2, pve1
- ✅ Redis Exporter sur S2
- ✅ Nginx reverse proxy sur S2

---

## 🛠️ Technologies

Prometheus · Node Exporter · Redis Exporter · Docker Compose

---

## 📐 Diagrammes

- [Diagramme d'Activité](../diagrams/activity/sprint-5-activity.puml)
- [Diagramme de Composants](../diagrams/components/sprint-5-component.mmd)

# Diagrammes UML — ACCENT

Diagrammes UML du projet, organisés par type et par sprint.

---

## 📂 Organisation

```
docs/diagrams/
├── activity/
│   └── sprint1-9.png          ← 1 diagramme d'activité couvrant tous les sprints
├── components/
│   └── sprint5-7.png          ← 1 diagramme de composants pour les sprints 5-7
└── deployment/
    ├── sprint1.png            ← Diagramme de déploiement Sprint 1
    ├── sprint2.png            ← Diagramme de déploiement Sprint 2
    ├── sprint3.png            ← Diagramme de déploiement Sprint 3
    ├── sprint4.png            ← Diagramme de déploiement Sprint 4
    ├── sprint8.png            ← Diagramme de déploiement Sprint 8
    └── sprint9.png            ← Diagramme de déploiement Sprint 9
```

---

## 🎨 Layout Final

| Sprint | Diagramme d'Activité | Second Diagramme |
|--------|---------------------|------------------|
| Sprint 1 | PlantUML | Deployment (PlantUML) |
| Sprint 2 | PlantUML | Deployment (PlantUML) |
| Sprint 3 | PlantUML | Deployment (PlantUML) |
| Sprint 4 | PlantUML | Deployment (PlantUML) |
| Sprint 5 | PlantUML | Component (Mermaid) |
| Sprint 6 | PlantUML | Component (Mermaid) |
| Sprint 7 | PlantUML | Component (Mermaid) |
| Sprint 8 | PlantUML | Deployment (Mermaid) |
| Sprint 9 | PlantUML | Deployment (Mermaid) |

---

## 🛠️ Outils de Rendu

### PlantUML
- Online : [plantuml.com/plantuml](https://www.plantuml.com/plantuml/uml)
- Local : Extension VS Code "PlantUML" + Java + Graphviz

### Mermaid
- Online : [mermaid.live](https://mermaid.live)
- Local : Extension VS Code "Markdown Preview Mermaid"

---

## 🎨 Palette de Couleurs (Consistante)

| Élément | Couleur | Usage |
|---------|---------|-------|
| Bleu clair `#dae8fc` | Containers/Packages | Subgraphs, nodes |
| Blanc `#ffffff` | Composants internes | Services |
| Vert `#d5e8d4` | Interfaces standard | Scrape, logs |
| Orange `#ffe6cc` | Interfaces spéciales | Traces, webhooks |
| Jaune `#fff2cc` | Stockage / Destinations | Volumes, Slack |

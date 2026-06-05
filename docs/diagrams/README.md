# Diagrammes UML — ACCENT

Diagrammes UML du projet, organisés par type et par sprint.

---

## 📂 Organisation

```
diagrams/
├── activity/        Diagrammes d'activité (.puml)
├── deployment/      Diagrammes de déploiement (.puml)
└── components/      Diagrammes de composants (.mmd)
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

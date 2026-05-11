# Journal de Prompts — TP : Élevage Pastoral
**Binôme :** Ndeye Khoudia Diop & Abdou Kader Zongo
**Cours :** Statistiques Agricoles — ENSAE 2026  
**Outil IA utilisé :** Gemini CLI

---

## Mode d'emploi

Ce fichier trace tous les échanges significatifs avec Claude Code.  
Pour chaque tâche, remplir les 4 colonnes :
- **Prompt envoyé** : le texte exact soumis à l'IA
- **Réponse (résumé)** : ce que l'IA a produit (ne pas tout copier, résumer)
- **Ce que vous avez modifié** : corrections, ajouts, refus — avec justification

> ⚠️ Un prompt sans colonne "Ce que vous avez modifié" est incomplet.

---

## Section 1 — Nettoyage des données

### Bloc 1 — Identifiants et géographie

| Tâche | Prompt envoyé | Réponse (résumé) | Ce que vous avez modifié |
|---|---|---|---|
| Lecture du bloc | "Commente chaque bloc du code contenu dans 1_cleaning.do. Pour chaque bloc, réponds à : 1. Que fait cette opération ? 2. Pourquoi est-elle nécessaire ? 3. Que se passerait-il si on ne l'appliquait pas ?" | L'IA a traduit les commentaires et structuré les explications en répondant aux trois points pour chaque section majeure du code. | Dans le cas où on utilisait pas describe, l'IA expliquait qu'on risquerait de travailler avec une base corrompue mais describe permet plutot d'avoir un aperçu global du dataset. |
| Double traitement pays/région | "Pourquoi extraire le pays depuis l'ID ET corriger manuellement via replace sur la Région ? Quels risques ?" | ... | ... |
| Suppression de variables | "La suppression de Ordredesaisie et PAYS est-elle justifiée ? Que risque-t-on à les supprimer ?" | ... | ... |

### Bloc 2 — Composition du ménage

| Tâche | Prompt envoyé | Réponse (résumé) | Ce que vous avez modifié |
|---|---|---|---|
| Recalcul Nombretotaldepersonnes | "Pourquoi recalculer cette variable plutôt qu'utiliser celle d'origine ?" | ... | ... |
| Coefficient 0,75 enfants (EA) | "Le coefficient 0,75 pour les enfants dans le calcul des Équivalents Adultes est-il standard ? Comment le justifies-tu ?" | ... | ... |

### Bloc 3 — Ventes de bétail

| Tâche | Prompt envoyé | Réponse (résumé) | Ce que vous avez modifié |
|---|---|---|---|
| Cas `sendré` | "Que signifie probablement 'sendré' dans ce contexte pastoral sahélien ? Pourquoi les valeurs ont-elles été imputées manuellement ?" | ... | ... |
| Reshape wide → long + duplicates drop | "Pourquoi utiliser duplicates drop ..., force après le reshape ? Quelles observations sont réellement supprimées ?" | ... | ... |
| Imputation prix hors [20 000 ; 450 000] | "Est-il raisonnable de remplacer les prix extrêmes par la moyenne conditionnelle ? Quelles alternatives proposes-tu ?" | ... | ... |
| Variable `soudure` (mois 5–8) | "Que représente la variable soudure construite sur les mois 5 à 8 dans le contexte sahélien ?" | ... | ... |

### Bloc 4 — Émigration

| Tâche | Prompt envoyé | Réponse (résumé) | Ce que vous avez modifié |
|---|---|---|---|
| Contenu probable de `emigration_cleaning.do` | "Propose ce que le fichier emigration_cleaning.do pourrait contenir, étant donné le contexte de l'enquête." | ... | ... |
| Comparaison avec le fichier réel | *(comparaison manuelle faite par le binôme)* | ... | ... |
| Condition ET vs OU | "Pourquoi supprimer les observations sans Liensdeparenté ET Années ET Activité ? Que se passerait-il avec un OU ?" | ... | ... |

---

## Section 2 — Subsistance du ménage

| Tâche | Prompt envoyé | Réponse (résumé) | Ce que vous avez modifié |
|---|---|---|---|
| % familles agriculture + élevage par pays | "..." | ... | ... |
| % par type de culture | "..." | ... | ... |
| Taille ménage en EA | "..." | ... | ... |
| Mois d'autosuffisance agricole | "..." | ... | ... |
| Taille cheptel en UBT | "..." | ... | ... |
| Indicateur viabilité UBT/EA | "..." | ... | ... |

---

## Section 3 — Ventes de bétail durant la transhumance

| Tâche | Prompt envoyé | Réponse (résumé) | Ce que vous avez modifié |
|---|---|---|---|
| Tableau statistique par pays | "..." | ... | ... |
| Graphique prix médian par sexe et pays | "..." | ... | ... |
| Justification du type de graphique | *(réflexion du binôme)* | ... | ... |
| Régression OLS prix_vente | "Écris une régression OLS de prix_vente sur sexe, age, origine, type_client, période, pays en [R/Stata/Python]." | ... | ... |
| Interprétation des coefficients | "..." | ... | ... |
| Variables supplémentaires pertinentes | "Quelles autres variables pourraient améliorer ce modèle dans un contexte pastoral sahélien ?" | ... | ... |

---

## Section 4 — Élevage et émigration

| Tâche | Prompt envoyé | Réponse (résumé) | Ce que vous avez modifié |
|---|---|---|---|
| Nombre d'émigrés par ménage | "..." | ... | ... |
| Taux d'émigration par pays | "..." | ... | ... |
| Destinations des fils d'éleveurs | "..." | ... | ... |
| Destinations générales des émigrés | "..." | ... | ... |
| Corrélation taux émigration × UBT/EA | "..." | ... | ... |
| Conclusion sur la corrélation | *(interprétation du binôme)* | ... | ... |

---

## Bilan critique de l'utilisation de l'IA

### Ce que l'IA a bien fait
*(à compléter — alimentera la slide 13)*

- ...
- ...
- ...

### Ce que l'IA a raté ou mal fait
*(obligatoire — alimentera la slide 14)*

| Erreur ou limite identifiée | Comment vous l'avez corrigée |
|---|---|
| ... | ... |
| ... | ... |
| ... | ... |

---

*Dernière mise à jour : [date]*

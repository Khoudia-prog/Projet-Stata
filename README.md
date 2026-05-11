# TP3 : Élevage Pastoral - Statistiques Agricoles 2026

## Description
Ce projet analyse la résilience des familles pastorales et agropastorales dans cinq pays du Sahel (Sénégal, Mali, Mauritanie, Burkina Faso, Niger). L'objectif est de comprendre les stratégies de mobilité, de subsistance et d'émigration.

## Configuration du projet
- **Données** : Les données brutes se trouvent dans le dossier `data/`.
- **Scripts** : Les do-files Stata se trouvent dans le dossier `do file/`.
- **Assistant IA** : Ce projet est réalisé avec l'assistance de Gemini CLI.

## Structure des fichiers
- `do file/1. cleaning.do` : Script principal de nettoyage (ID, composition ménage, ventes, émigration).
- `do file/emigration_cleaning.do` : Script secondaire pour l'harmonisation des lieux de destination.
- `PROMPTS.md` : Journal des interactions avec l'IA et réflexions critiques.
- `README.md` : Ce fichier.

## Comment lancer l'analyse
1. Ouvrir Stata.
2. Définir les macros de chemin (globals) :
   ```stata
   global data "C:/votre/chemin/data"
   global codes "C:/votre/chemin/do file"
   global inputfile "$data/famille_troupeau.dta"
   ```
3. Exécuter `do "$codes/1. cleaning.do"`.

## Difficultés rencontrées
- Harmonisation des données textuelles pour les prix (cas "sendré").
- Gestion des doublons après le `reshape` des ventes de bétail.

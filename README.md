# README — TP3 : Élevage Pastoral au Sahel

**Binôme :** Ndèye Khoudia Diop & Abdou Kader Zongo
**Date :** Mai 2026
**Outil IA utilisé :** Gemini CLI/Claude.ai — voir section Installation

---

## 1. Installation et configuration de l'outil IA

### Contexte
La consigne demandait d'utiliser **Claude Code**. Après tentative d'installation,
nous avons rencontré un blocage technique (voir section 4) qui nous a conduits à
utiliser **Gemini CLI** à la place, outil équivalent de Google permettant
d'interagir avec un LLM depuis le terminal.

### Étapes réalisées

**Étape 1 — Installation de Node.js**
Node.js est l'environnement d'exécution JavaScript nécessaire pour faire tourner
des outils en ligne de commande comme Claude Code ou Gemini CLI.
Sans Node.js, la commande `npm` (gestionnaire de paquets) n'existe pas.

```
https://nodejs.org → télécharger et installer la version LTS
```

**Étape 2 — Déblocage de la politique d'exécution PowerShell**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Par défaut, Windows bloque l'exécution de scripts `.ps1` non signés pour des
raisons de sécurité. Or `npm.ps1` (le script qui lance npm dans PowerShell)
est un script non signé. Cette commande autorise les scripts locaux non signés
à s'exécuter pour l'utilisateur courant uniquement, sans toucher aux paramètres
système globaux.

**Étape 3 — Installation de Gemini CLI**
```powershell
npm install -g @google/gemini-cli
```
Le flag `-g` installe l'outil globalement, le rendant accessible depuis n'importe
quel dossier du terminal. Cette commande télécharge Gemini CLI depuis le registre
npm et le rend disponible via la commande `gemini` dans le terminal.

**Étape 4 — Vérification de l'installation**
```powershell
gemini --version
```

---

## 2. Structure du projet

```
Projet stat agri\
│
├── data\                          ← Données (brutes et nettoyées)
│   ├── famille_troupeau.dta       ← Base brute (source)
│   ├── FT_cleanID.dta             ← Base nettoyée (après cleaning.do)
│   ├── vente_betail_cleaned.dta   ← Base ventes (après cleaning.do section 4)
│   ├── emigration_cleaned.dta     ← Base émigration (après cleaning.do section 5)
│   └── migr_count.dta             ← Comptage émigrés par ménage (après analyse.do)
│
├── do file\                       ← Scripts Stata
│   ├── 1__cleaning.do             ← Nettoyage complet des données
│   ├── 2__analyse.do              ← Analyse statistique
│   └── emigration_cleaning.do     ← Sous-script nettoyage émigration
│
├── .gitignore                     ← Fichiers exclus du suivi Git
├── Guide Famille troupeau 8juillet (1).pdf   ← Guide enquêteur
├── Quest Famille Troupeau 8juillet2015 (1).pdf ← Questionnaire original
├── PROMPTS.md                     ← Journal des interactions avec l'IA
└── README.md                      ← Ce fichier
```

---

## 3. Reproduire l'analyse de A à Z

### Prérequis
- Stata 16 ou supérieur installé
- La base brute `famille_troupeau.dta` placée dans le dossier `data\`
- Adapter les chemins globaux en tête de chaque script si nécessaire

### Étape 1 — Configurer les chemins

Ouvrir `1__cleaning.do` et vérifier le bloc de configuration en tête de fichier :

```stata
global root    "C:\Users\dkhou\OneDrive\Documents\Desktop\Projet stat agri"
global data    "${root}\data"
global codes   "${root}\do file"
global out     "${root}\output"
global inputfile "${data}\famille_troupeau"
```

Remplacer `C:\Users\dkhou\...` par le chemin correspondant à votre machine.

### Étape 2 — Exécuter le nettoyage

```stata
do "C:\...\do file\1__cleaning.do"
```

Ce script produit dans `data\` :
- `FT_cleanID.dta` — base ménages nettoyée (ID, géographie, composition, cheptel)
- `vente_betail_cleaned.dta` — base ventes de bétail au format long
- `emigration_cleaned.dta` — base émigration au format long

### Étape 3 — Exécuter l'analyse

```stata
do "C:\...\do file\2__analyse.do"
```

Ce script produit :
- Les tableaux descriptifs (subsistance, prix, émigration) dans la fenêtre Results
- Le graphique des prix médians par sexe et pays
- Les résultats de la régression OLS sur les prix de vente
- Les résultats de la corrélation intensité émigration / viabilité pastorale

### Ordre d'exécution obligatoire

```
1__cleaning.do  →  2__analyse.do
```

`2__analyse.do` dépend des fichiers produits par `1__cleaning.do`.
Ne pas exécuter l'analyse sans avoir d'abord lancé le nettoyage.

---

## 4. Difficultés techniques rencontrées et solutions adoptées

### Difficulté 1 — Blocage PowerShell (`npm.ps1` non autorisé)

**Symptôme :** après installation de Node.js, la commande `npm install` échoue
avec l'erreur :
```
npm.ps1 cannot be loaded because running scripts is disabled on this system
```

**Cause :** la politique d'exécution Windows (`ExecutionPolicy`) est réglée par
défaut sur `Restricted`, ce qui interdit tout script `.ps1` non signé numériquement.

**Solution :**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
`RemoteSigned` autorise les scripts locaux non signés mais exige une signature
pour les scripts téléchargés depuis Internet. Le paramètre `-Scope CurrentUser`
limite la modification à l'utilisateur courant sans toucher aux paramètres système.

---

### Difficulté 2 — Remplacement de Claude Code par Gemini CLI

**Symptôme :** Claude Code nécessite un abonnement Claude Pro ou un accès API
Anthropic payant pour être utilisé en ligne de commande.

**Solution :** utilisation de **Gemini CLI** (`@google/gemini-cli`), outil
équivalent développé par Google, accessible gratuitement avec un compte Google.
Les fonctionnalités utilisées dans ce TP (explication de code, identification
de failles, proposition d'alternatives) sont disponibles dans les deux outils.
Les prompts consignés dans `PROMPTS.md` ont été soumis via Gemini CLI.

---

### Difficulté 3 — Macro `${inputfile}` utilisée comme dossier

**Symptôme :** `save "${inputfile}/FT_cleanID.dta"` échouait car `${inputfile}`
pointait vers le fichier source et non vers un dossier.

**Solution :** séparation en deux macros distinctes :
```stata
global data      "${root}\data"         ← dossier
global inputfile "${data}\famille_troupeau"  ← fichier source
```
Tous les `save` utilisent désormais `${data}`.

---

### Difficulté 4 — `tempfile` perdu entre deux `use`

**Symptôme :** `merge 1:1 ID using \`migr_count'` échouait avec `r(198)`
car le tempfile avait été effacé lors du `use` suivant.

**Solution :** remplacement du `tempfile` par un fichier permanent :
```stata
save "${data}\migr_count.dta", replace
```

---

*Ce README a été rédigé à la fin du TP et reflète fidèlement les étapes
suivies ainsi que les problèmes rencontrés.*

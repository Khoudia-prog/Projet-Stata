# Journal de Prompts — TP3 : Élevage Pastoral au Sahel

**Binôme :** Ndèye Khoudia Diop & Abdou Kader Zongo
**Outil IA utilisé :** Claude (claude.ai) / Gemini CLI  
**Date :** Mai 2026  

---

## Comment lire ce journal

Chaque entrée correspond à une interaction avec l'IA. Le tableau consigne le prompt exact envoyé, un résumé de la réponse obtenue, et — surtout — ce que le binôme a modifié, corrigé ou rejeté. Ce journal est un document vivant : il prouve que l'IA a été utilisée de façon critique, pas aveuglément.

---

## Section 3.1 — Préparation et nettoyage des données

### Bloc 1 — Identifiants et géographie

| Champ | Contenu |
|---|---|
| **Tâche** | Comprendre et évaluer le bloc de nettoyage de l'identifiant et d'extraction du pays dans `cleaning.do` |
| **Prompt envoyé** | « Explique ce bloc Stata ligne par ligne, identifie les choix discutables et propose une alternative pour chacun. [code collé] » |
| **Résumé de la réponse** | L'IA a correctement expliqué le renommage de `Codeduquestionnaire` en `ID`, la suppression des manquants et l'extraction du pays via `substr(ID,1,1)`. Elle n'a pas spontanément détecté le problème de la correction pays basée sur `Région` seule. |
| **Ce que nous avons modifié** | Nous avons identifié nous-mêmes que `replace country=4 if Région=="Sahel"` affectait incorrectement le département "Matam" (Sénégal) au Burkina Faso, et "Mederdra" (Mauritanie) à un mauvais pays. Nous avons corrigé en croisant `Région` ET `DépartementouCercle` : `replace country=1 if lower(Région)=="sahel" & lower(DépartementouCercle)=="matam"` et `replace country=3 if lower(Région)=="sahel" & lower(DépartementouCercle)=="mederdra"`. Nous avons également ajouté `lower()` sur toutes les comparaisons de chaînes pour éviter les problèmes de casse. Enfin, nous avons ajouté une vérification `tab country PAYS` avant la suppression de `PAYS` pour confirmer la redondance avant de supprimer. |

---

### Bloc 2 — Gestion des doublons sur l'identifiant

| Champ | Contenu |
|---|---|
| **Tâche** | Évaluer la stratégie de suppression des doublons sur `ID` |
| **Prompt envoyé** | « Explique ce bloc Stata ligne par ligne, identifie les choix discutables et propose une alternative pour chacun. [code collé] » |
| **Résumé de la réponse** | L'IA a expliqué que `duplicates drop ID, force` supprime les doublons en ne conservant que la première occurrence. Elle a identifié une faille : la suppression repose uniquement sur l'égalité de l'ID, sans vérifier si les autres variables diffèrent — risque de supprimer de vrais ménages distincts partageant un ID par erreur de saisie. |
| **Ce que nous avons modifié** | Nous avons remplacé `duplicates drop ID, force` par une logique plus robuste : `duplicates tag ID, gen(dup_flag)`, suivi d'un `list ID Région DépartementouCercle if dup_flag > 0` pour inspection manuelle, puis `duplicates drop ID Région DépartementouCercle, force` pour ne supprimer que les vrais doublons (même ménage, même localisation). Cela évite la suppression de faux doublons (deux ménages distincts avec le même ID par erreur de saisie). |

---

### Bloc 3 — Composition du ménage et Équivalents Adultes

| Champ | Contenu |
|---|---|
| **Tâche** | Évaluer le calcul de `HHsize` et `HHsizeEA`, et l'ordre des opérations |
| **Prompt envoyé** | « Explique ce bloc Stata ligne par ligne, identifie les choix discutables et propose une alternative pour chacun. [code collé] » |
| **Résumé de la réponse** | L'IA a expliqué la logique de `rsum()` et le coefficient 0.75 pour les enfants (convention CILSS/FAO). Elle n'a pas spontanément signalé le bug d'ordre : `egen HHsize = rsum(...)` était calculé AVANT le `foreach` qui impute les manquants à zéro, ce qui rend le `foreach` sans effet sur `HHsize`. |
| **Ce que nous avons modifié** | Après avoir posé la question directement, nous avons corrigé l'ordre en plaçant le `foreach` AVANT les deux calculs. Nous avons aussi conservé temporairement `Nombretotaldepersonnes` pour vérifier la cohérence avec `HHsize` reconstruit (via `gen HHsize_ecart = HHsize - Nombretotaldepersonnes` et `tab HHsize_ecart`), avant de la supprimer. Sur les coefficients EA, nous avons différencié les Vieux (coefficient 0.80 au lieu de 1.0) conformément aux normes FAO, et modifié le coefficient enfants de 0.75 à 0.5 en accord avec les standards Sahel. Nous avons déplacé le `save "${data}/FT_cleanID.dta"` à la fin de cette section (et non en fin de section 3.1) pour que `HHsize` et `HHsizeEA` soient bien sauvegardés sur disque et disponibles dans `analyse.do`. |

---

### Bloc 4 — Ventes de bétail : reshape et traitement de "sendré"

| Champ | Contenu |
|---|---|
| **Tâche** | Comprendre le passage au format long et évaluer le traitement de l'entrée "sendré" |
| **Prompt envoyé** | « Explique ce bloc Stata ligne par ligne, identifie les choix discutables et propose une alternative pour chacun. [code collé] » |
| **Résumé de la réponse** | L'IA a expliqué le `reshape long` et identifié que le `duplicates drop` après reshape n'incluait pas `ID`, supprimant des transactions légitimes de ménages différents aux caractéristiques identiques. Sur "sendré", l'IA a fourni le contexte culturel : terme fulfuldé désignant une cession  à crédit entre proches, hors circuit marchand standard. Elle a noté que les valeurs imputées (Sexe=1, Age=2, Prix=45000) étaient arbitraires. La boucle `forvalues 37/50` ne couvrait pas les colonnes Prix1 à Prix36. |
| **Ce que nous avons modifié** | Nous avons ajouté que sendré pourrait aussi signifier vendre à un prix dérisoire;`ID` dans le `duplicates drop` : `duplicates drop ID Sexe Age Origine Mois Année Aqui Où Prix, force`. Nous avons ajouté une boucle d'inventaire sur toutes les colonnes Prix avant correction pour détecter d'autres valeurs textuelles non numériques. Nous avons créé la variable indicatrice `gen sendré_flag = (Prix_orig == "sendré")` pour pouvoir identifier ces observations dans les analyses. Nous avons documenté la justification des valeurs imputées dans les commentaires : Sexe=Mâle (femelles conservées pour reproduction), Age=2 ans (âge typique d'une vente sociale), Mois=Avril (fin de saison sèche, pression financière), Prix=45000 FCFA (prix plancher plausible pour un bovin mâle jeune). Nous avons aussi ajouté un `drop if missing(Sexe) & missing(Age) & missing(Origine) & missing(Prix)` après le reshape pour supprimer proprement les lignes vides générées. |

---

### Bloc 5 — Nettoyage des variables de vente et imputation des prix

| Champ | Contenu |
|---|---|
| **Tâche** | Évaluer le nettoyage de Sexe, Âge, Origine, Aqui et l'imputation des prix manquants |
| **Prompt envoyé** | « Explique ce bloc Stata ligne par ligne, identifie les choix discutables et propose une alternative pour chacun. [code collé] » |
| **Résumé de la réponse** | L'IA a identifié : (1) le nettoyage de Sexe est sensible à la casse ("m"/"f" minuscules perdus silencieusement) ; (2) le seuil de 20 ans pour l'âge est arbitraire et incohérent avec les classes du questionnaire (question 5.5 : dernière classe "plus de 9 ans") ; (3) la plage de prix [20 000 ; 450 000] appliquée uniformément à toutes les espèces est incohérente ; (4) la modalité "4" dans Aqui est supprimée sans explication ; (5) l'imputation par la moyenne réduit artificiellement la variance. |
| **Ce que nous avons modifié** | Nous avons ajouté `lower()` pour le nettoyage de Sexe et Origine (`replace Sexe="2" if lower(Sexe)=="f"`). Nous avons ajouté un `tab Sexe` avant nettoyage pour inventorier toutes les modalités présentes. Nous avons documenté le seuil de 20 ans avec une référence à la question 5.5 du questionnaire. Nous avons ajouté `count if !inrange(Prix,20000,450000) & !missing(Prix)` avant suppression pour mesurer l'impact. Nous avons remplacé l'imputation par la **médiane** (`bys Sexe Age country : egen med_P = median(Prix)`) au lieu de la moyenne, plus robuste aux valeurs extrêmes, et documenté le taux d'imputation avec deux `count if missing(Prix)` avant et après. Nous avons défini un label pour la modalité 4 d'Aqui ("Autre") plutôt que de la supprimer silencieusement. Nous avons défini la soudure de façon différenciée par pays (`inrange(Mois,5,9)` pour Mali et Niger, `inrange(Mois,5,8)` pour les autres) conformément aux calendriers CILSS/FEWS NET. |

---

### Bloc 6 — Émigration

| Champ | Contenu |
|---|---|
| **Tâche** | Évaluer le bloc de restructuration des données de migration et le sous-script `emigration_cleaning.do` |
| **Prompt envoyé** | « Explique ce bloc Stata ligne par ligne, identifie les choix discutables et propose une alternative pour chacun. [code collé] » |
| **Résumé de la réponse** | L'IA a expliqué la logique du `reshape long` et du `drop if missing(...) & missing(...) & missing(...)`. Elle a justifié la logique ET (et non OU) : une seule variable renseignée suffit à identifier un émigré potentiel lié au troupeau. Sur `emigration_cleaning.do`, l'IA a proposé une structure correcte (standardisation des liens de parenté, des destinations, des activités) mais a manqué les corrections spécifiques aux fautes de saisie réelles dans les données. |
| **Ce que nous avons modifié** | Nous avons ajouté une analyse de sensibilité de la condition ET : `count if missing(Liensdeparenté) & missing(Années) & !missing(Activité)` (et permutations) pour quantifier le nombre d'observations conservées uniquement sur une variable. Nous avons corrigé `emigration_cleaning.do` en complétant manuellement les fautes de saisie spécifiques sur les noms de villes et de pays absentes de la proposition de l'IA. Nous avons ajouté `HHsize` et `HHsizeEA` dans le `keep` de la section émigration pour les rendre disponibles lors de la fusion. |

---

## Section 3.2 — Subsistance du ménage

| Champ | Contenu |
|---|---|
| **Tâche** | Générer le code Stata pour les 6 indicateurs de subsistance |
| **Prompt envoyé** | « Génère le code Stata pour calculer : (1) proportion de ménages pratiquant l'agriculture, (2) proportion par culture, (3) taille du ménage en EA, (4) mois d'autosuffisance, (5) UBT avec les coefficients Bovin=0.7, Ovin/Caprin=0.1, Camelin=1.0, Equin=0.8, Asin=0.5, (6) ratio UBT/EA. Résumer chaque indicateur par pays. » |
| **Résumé de la réponse** | L'IA a généré le code avec `tabstat` et `gen`. Elle a utilisé `Nbrecultvivrièrespratiquées > 0 | Nbrecultrentepratiquées > 0` pour l'indicateur agriculture, et les noms de variables `Bovins`, `Ovins`, `Caprins`, `Camelins` qui n'existent pas dans la base. |
| **Ce que nous avons modifié** | Nous avons corrigé le calcul de l'agriculture en utilisant la variable `AGRICULTURE=="Oui"` directement disponible dans la base, plus fiable que de reconstruire depuis les cultures. Pour les cultures détaillées, nous avons utilisé `inlist()` avec les valeurs réelles de la base et ajouté `capture confirm variable` pour rendre le code robuste aux variables absentes. Nous avons remplacé `Bovins/Ovins/Caprins/Camelins` par les variables réelles `transh_Bovins`, `transh_Ovins`, `transh_Caprins`, `transh_Camelins` (seules disponibles dans la base). Nous avons retiré `Riz` du `foreach` cultures (variable absente de la base). Nous avons corrigé les coefficients UBT : Bovin=1.0 et Camelin=1.0 au lieu de 0.7 (erreur de l'IA, les variables transh_ sont déjà en UBT dans la base). Nous avons vérifié les coefficients UBT contre la documentation CILSS. Nous avons sauvegardé la base enrichie (`FT_clean_analysis.dta`) à la fin de la section pour la réutiliser en section 3.4. |

---

## Section 3.3 — Ventes de bétail durant la transhumance

| Champ | Contenu |
|---|---|
| **Tâche** | Écrire la régression OLS du prix de vente et interpréter les coefficients |
| **Prompt envoyé** | « Écris une régression OLS du prix de vente (`Prix`) en fonction du sexe, de l'âge, de l'origine, du type de client (`Aqui`), de la période de soudure et du pays en Stata. Utilise des variables indicatrices pour les variables catégorielles. Interprète les coefficients attendus. » |
| **Résumé de la réponse** | L'IA a produit `reg Prix i.Sexe Age i.Origine i.Aqui i.soudure i.country` avec les interprétations attendues. Elle a noté que le coefficient sur Sexe (femelle vs mâle) serait probablement négatif. Elle a proposé `i.Mois` pour capturer la saisonnalité fine. |
| **Ce que nous avons modifié** | Nous avons remplacé `i.soudure` par `i.Mois` pour avoir une granularité mensuelle complète, plus informative que le seul indicateur binaire soudure/hors-soudure. Nous avons ajouté un `destring` préalable sur toutes les variables pour garantir le format numérique. Nous avons documenté les variables additionnelles absentes mais pertinentes (poids vif, état corporel, race, distance au marché, Tabaski) qui expliqueraient l'amélioration du R² = 0.14. Résultats retenus : Femelle = −29 135 FCFA (p<0.001), Animal confié = −34 792 FCFA (p=0.01), Age +1 an = +7 752 FCFA (p<0.001). |

---

## Section 3.4 — Élevage et émigration

| Champ | Contenu |
|---|---|
| **Tâche** | Calculer le nombre d'émigrés par ménage sur 5 ans et l'intensité de l'émigration |
| **Prompt envoyé** | « Comment calculer le nombre d'émigrés par ménage ayant migré dans les 5 dernières années, puis rapporter ce nombre à la taille du ménage pour obtenir un taux d'émigration par pays en Stata ? » |
| **Résumé de la réponse** | L'IA a proposé de filtrer sur `Année >= 2010 & Année <= 2015`, puis `bys ID: gen n_emigres = _N` avant `duplicates drop ID, force`. Pour l'intensité, elle a suggéré un `merge` avec la base principale et une division par `HHsize`. Elle avait proposé d'utiliser un `tempfile`. |
| **Ce que nous avons modifié** | Nous avons corrigé le filtre temporel : la variable `Années` dans `emigration_cleaned.dta` contient la **durée d'absence en années** (et non une année calendaire), donc nous avons remplacé le filtre calendaire par `keep if Années <= 5`. Nous avons remplacé le `tempfile` (perdu entre deux `use`, provoquant l'erreur `r(198)`) par un fichier permanent `migr_count.dta`. Pour la section 3.2, nous avons utilisé `merge 1:m` (et non `1:1`) car un ménage peut avoir plusieurs émigrés dans la base longue. Le `bys ID: gen nt_emigres = _N` et le `replace nt_emigres = 0 if _merge==1` ont été placés dans le bon ordre pour éviter d'écraser les ménages sans émigrés. |

---

| Champ | Contenu |
|---|---|
| **Tâche** | Interpréter la corrélation entre intensité d'émigration et viabilité de l'élevage |
| **Prompt envoyé** | « Que peut-on attendre comme signe de la corrélation entre l'intensité de l'émigration et le ratio UBT/EA (viabilité de l'élevage) dans un contexte pastoral sahélien ? » |
| **Résumé de la réponse** | L'IA a proposé deux lectures : (1) corrélation négative si l'émigration est une stratégie de survie face à un troupeau insuffisant ; (2) corrélation positive si les transferts des migrants permettent de reconstituer le cheptel. |
| **Ce que nous avons modifié** | Le résultat empirique est r = +0.20 (p < 0.001), corrélation positive. Nous avons rejeté l'hypothèse 1 (pauvreté → exode) et retenu l'hypothèse 2 (transferts → reconstitution du cheptel). Nous avons utilisé les deux cadres proposés par l'IA pour structurer l'interprétation dans la présentation et souligner que la corrélation est modeste (R² partiel faible), ce que l'IA n'avait pas précisé. |

---

## Bilan général de l'utilisation de l'IA

### Ce que l'IA a bien fait
- Explication ligne par ligne de la syntaxe Stata avec précision
- Identification du `duplicates drop` sans `ID` après reshape (transaction légitime supprimée)
- Contexte culturel sur « sendré » (terme fulfuldé : vente à prix dérisoire ou à crédit entre proches)
- Proposition de la médiane à la place de la moyenne pour l'imputation des prix
- Justification correcte de la logique ET dans le drop des émigrés
- Cadrage théorique des deux hypothèses sur la corrélation migration/viabilité

### Ce que l'IA a mal fait ou approximé
- Elle n'a **pas spontanément** signalé le bug d'ordre `foreach` après `egen HHsize` — détecté uniquement sur question directe
- Elle a **validé sans réserve** la plage de prix [20 000 ; 450 000] avant de proposer des alternatives sur relance
- Elle a utilisé des noms de variables inexistants (`Bovins`, `Ovins`, `Riz`) — corrigés en `transh_Bovins`, `transh_Ovins`, suppression de `Riz`
- Elle a proposé un filtre calendaire sur `Années` alors que la variable contient une durée — erreur conceptuelle corrigée par nous
- Elle a proposé un `tempfile` sans avertir qu'il serait perdu entre deux `use` — remplacé par fichier permanent
- La correction du pays via `Région` seule n'a pas été remise en question spontanément — nous avons ajouté le croisement avec `DépartementouCercle`
- La proposition d'`emigration_cleaning.do` était structurellement correcte mais manquait les fautes de saisie spécifiques aux données réelles

---

*Ce journal a été maintenu tout au long du TP et reflète fidèlement les interactions avec l'IA ainsi que les décisions prises par le binôme.*

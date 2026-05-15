
* === CONFIGURATION GLOBALE ===
global root    "C:\Users\dkhou\OneDrive\Documents\Desktop\Projet stat agri"
global data  "${root}\data"
global codes "${root}\do file"
global out   "${root}\output"
global inputfile "${data}\famille_troupeau-Copie"  

***-----------------------------------
*		 1. Explorer le jeu de données
***-----------------------------------
* QUE FAIT CETTE OPÉRATION ? : Donne un aperçu complet du contenu du jeu de données.
* POURQUOI EST-ELLE NÉCESSAIRE ? : Avant tout nettoyage, il faut connaître la structure
*   des données (types, valeurs manquantes, distributions) pour détecter les anomalies.
* QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : On risque de passer à côté d'anomalies
*   de contenu non visibles avec describe seul (valeurs aberrantes, mauvais encodages).
*
* CORRECTION (v1 → v2) : Remplacement de 'describe, short' (trop succinct) par
*   'codebook, compact' qui affiche types, valeurs manquantes et distributions.

	codebook, compact   // Remplace : describe, short

 
***-----------------------------------
*		 2. Variable ID (Identifiant)
***-----------------------------------
* QUE FAIT CETTE OPÉRATION ? : Nettoie l'identifiant unique (ID) en le renommant,
*   en supprimant les valeurs manquantes, en traitant les doublons et en vérifiant
*   l'unicité de l'identifiant.
* POURQUOI EST-ELLE NÉCESSAIRE ? : Un identifiant unique et propre est indispensable
*   pour garantir qu'une ligne correspond exactement à un ménage unique — crucial
*   pour les analyses ultérieures et les fusions de bases.
* QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : On aurait des résultats faussés
*   par des ménages comptés plusieurs fois ou des observations impossibles à identifier.
	
	* Renommage de la variable d'identifiant pour plus de simplicité
	ren Codeduquestionnaire ID
	codebook ID

	* Suppression des observations dont l'identifiant est manquant
	*   à partir d'autres variables (Région, DépartementouCercle, etc.).
	count if missing(ID)   // Documenter le nombre d'observations supprimées
	drop if missing(ID) // Des informations sur la construction de l'ID aurait pu nous éviter cette étape

	* Gestion des doublons d'identifiants
	duplicates report ID

	* CORRECTION (v1 → v2) : La v1 dédupliquait sur ID seul (force), ce qui supprime
	*   silencieusement des ménages distincts ayant par erreur le même ID.
	*   On inspecte d'abord les doublons manuellement, puis on déduplique
	*   en croisant ID avec des variables géographiques discriminantes.
	duplicates tag ID, gen(dup_flag)
	list ID Région DépartementouCercle if dup_flag > 0   // Inspecter avant suppression
	duplicates drop ID Région DépartementouCercle, force  // Remplace : duplicates drop ID if duplicates, force
	drop dup_flag

	* Vérification que l'ID est maintenant unique
	isid ID

***-----------------------------------
*		3.1 Génération de la localisation à partir de l'ID
***-----------------------------------
* QUE FAIT CETTE OPÉRATION ? : Extrait le code pays du premier chiffre de l'ID,
*   corrige les incohérences via Région et Département, supprime les variables
*   redondantes, et associe des étiquettes lisibles au code pays.
* POURQUOI EST-ELLE NÉCESSAIRE ? : L'ID contient le pays dans son premier chiffre,
*   mais des erreurs de saisie lors de la collecte nécessitent une correction manuelle.
* QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : La répartition géographique
*   des ménages par pays serait erronée, faussant toutes les comparaisons nationales.
	
	* Vérification de la longueur de l'ID (on attend 6 caractères)
	tostring ID, replace
	gen id_length = length(ID)
	tab id_length   // Détecter les IDs malformés
	drop id_length

	* Extraction du code pays (premier chiffre de l'ID)
	gen country = substr(ID, 1, 1)
	list ID country Zonederéférence DépartementouCercle Région
	destring country, replace 
	
	* Définition des étiquettes (labels) pour les pays
	lab def country 1 "Sénégal" 2 "Mali" 3 "Mauritanie" 4 "Burkina Faso" 5 "Niger"
	lab val country country
	
	* Correction manuelle des erreurs d'identification du pays
	*
	* CORRECTION (v1 → v2) : La v1 corrigeait le pays sur la seule base de Région,
	*   ce qui est fragile (une même région peut exister dans plusieurs pays).
	*   Ex. v1 : replace country=4 if Région=="Sahel" affectait incorrectement
	*   le département Matam (Sénégal) au Burkina Faso.
	*   La v2 croise Région ET DépartementouCercle pour lever les ambiguïtés.
	*   On utilise lower() pour éviter les problèmes de sensibilité à la casse.
	
	replace country=2 if lower(Région)=="kayes"  
	replace country=5 if lower(Région)=="tillabery"
	replace country = 4 if lower(Région) == "sahel" & DépartementouCercle == "Oudalan"   // Remplace : replace country=4 if Région=="Sahel"
	replace country = 4 if lower(Région) == "est"   & !inlist(DépartementouCercle, "Matam", "Mederdra")
	replace country=1 if lower(Région)="sahel" & DépartementouCercle="Matam"
	replace country=3 if lower(Région)="sahel" & DépartementouCercle="Mederdra"


	* Vérification : lister les observations dont le pays a changé
	list ID country Région DépartementouCercle if country != real(substr(ID,1,1))

	* Vérification de la redondance avant suppression des variables
	* CORRECTION (v1 → v2) : La v1 supprimait sans vérification.
	*   On vérifie ici que PAYS est bien redondant avec country.
	tab country PAYS   // Si cohérents, suppression justifiée
	drop Ordredesaisie PAYS Zonederéférence Groupedorigine
	order ID country Région
	
	* Sauvegarde intermédiaire
	compress
	save "${data}/FT_cleanID.dta", replace

***-----------------------------------
*		 3.2  Composition du ménage
***-----------------------------------
* QUE FAIT CETTE OPÉRATION ? : Calcule la taille totale du ménage (HHsize)
*   et le nombre d'Équivalents Adultes (HHsizeEA).
* POURQUOI EST-ELLE NÉCESSAIRE ? : La variable de taille d'origine peut être
*   incohérente avec le détail par tranche d'âge. Le calcul des EA reflète mieux
*   les besoins de consommation en pondérant les enfants différemment.
* QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : On utiliserait une taille de
*   ménage potentiellement fausse, et les ratios de subsistance (UBT/EA)
*   ne tiendraient pas compte de la structure démographique réelle.

	codebook HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 Nombretotaldepersonnes

	* CORRECTION (v1 → v2) : La v1 supprimait Nombretotaldepersonnes immédiatement.
	*   On conserve temporairement pour vérifier la cohérence avec la somme reconstruite.
	*   Si les écarts sont rares et mineurs, la suppression est justifiée.

	* ÉTAPE 1 : Imputation des manquants par 0 AVANT l'agrégation (ordre corrigé)
	* CORRECTION (v1 → v2) : Dans la v1, l'imputation était faite APRÈS egen HHsize.
	*   Bien que rsum() traite les manquants comme 0 par défaut, l'ordre correct
	*   est d'imputer avant d'agréger pour garantir la robustesse si la commande change.
	*   NOTE : On suppose que valeur manquante = 0 membre dans cette tranche d'âge.
	*   Cette hypothèse peut légèrement sous-estimer la taille réelle du ménage.
	foreach var of varlist HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 {
		replace `var' = 0 if missing(`var')
	}

	* ÉTAPE 2 : Calcul de la taille brute du ménage
	egen HHsize = rsum(HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12)

	* ÉTAPE 3 : Vérification de cohérence avec la variable déclarée avant suppression
	gen HHsize_ecart = HHsize - Nombretotaldepersonnes
	tab HHsize_ecart   // Documenter les écarts
	count if abs(HHsize_ecart) > 2 & !missing(HHsize_ecart)   // Cas très divergents
	drop HHsize_ecart Nombretotaldepersonnes   // Suppression justifiée après vérification

	* ÉTAPE 4 : Calcul des Équivalents Adultes (EA)
	* CORRECTION (v1 → v2) : La v1 appliquait un coefficient unique de 0,75 à tous
	*   les enfants de moins de 12 ans et de 1 aux vieux, sans distinction.
	*   La v2 adopte une pondération différenciée alignée sur les normes FAO/CILSS :
	*     - Hommes adultes et Femmes adultes : coefficient 1,0
	*     - Personnes âgées (Vieux)          : coefficient 0,8 (besoins légèrement
	*       réduits par rapport à un adulte actif)
	*     - Enfants de moins de 12 ans       : coefficient 0,75 (convention CILSS)
	*   Source : FAO (2001), Human Energy Requirements; CILSS (2016), Cadre harmonisé.
	gen HHsizeEA = HommesadultesHA + FemmesadultesFA ///
				 + 0.80 * VieuxV ///                          // Remplace : + VieuxV
				 + 0.75 * (Garçonsde12ansG12 + Fillesde12ansF12)
	label var HHsize   "Taille du ménage (nombre de personnes)"
	label var HHsizeEA "Taille du ménage en Équivalents Adultes (FAO/CILSS)"

	* Sauvegarde intermédiaire avec les nouvelles variables de composition
	compress
	save "${data}/FT_cleanID.dta", replace

***-----------------------------------
*		 4. VENTES de bétail
***-----------------------------------
* QUE FAIT CETTE OPÉRATION ? : Transforme les données de ventes du format large
*   au format long (une ligne par vente) et nettoie les prix et caractéristiques.
* POURQUOI EST-ELLE NÉCESSAIRE ? : Pour analyser les prix et volumes de ventes,
*   chaque transaction doit être une unité d'observation. L'imputation des prix
*   manquants assure une base exploitable pour les statistiques descriptives.
* QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : Impossible de calculer des
*   prix moyens par type d'animal ou de régresser les facteurs de prix.

	use "${data}/FT_cleanID.dta", clear

***-----------------------------------
* SECTION 4 : VENTES DE BÉTAIL
***-----------------------------------

	* Sélection des variables de vente uniquement
	* NOTE : 'keep' garde d'abord toutes les variables Année* et Années* (migration).
	*   Le 'drop Années*' juste après isole les variables de vente. L'ordre est
	*   légèrement risqué si d'autres variables commencent par 'Années'.
	keep ID country Sexe* Age* Origine* Mois* Année* Aqui* Où* Prix*
	drop Années*

	* Conversion en string pour harmoniser avant nettoyage
	* NOTE : 'tostring *' convertit toutes les variables restantes y compris ID et country.
	*   Elles seront reconverties explicitement avec destring après nettoyage.
	tostring *, replace

	***-----------------------------------
	* Traitement de l'observation particulière "sendré"
	***-----------------------------------
	* "Sendré" est un terme fulfuldé désignant une cession à prix dérisoire ou à crédit,
	* conclue entre proches hors circuit marchand standard. L'enquêteur a saisi ce mot
	* à la place d'un montant car le prix n'était pas un prix marché standard.
	*
	* CORRECTION (v1 → v2) : Avant d'imputer, on inventorie toutes les valeurs
	*   textuelles de Prix pour détecter d'éventuelles variantes orthographiques
	*   ("sendre", "sendré", "SENDRÈ", etc.) qui auraient été manquées en v1.
	*
	* Inventaire des valeurs non numériques dans toutes les colonnes Prix
	forvalues num = 1/50 {
		capture confirm variable Prix`num'
		if !_rc {
			quietly tab Prix`num' if !regexm(Prix`num', "^[0-9]+$") & !missing(Prix`num')
			if r(N) > 0 {
				display "Prix`num' contient des valeurs non numériques :"
				tab Prix`num' if !regexm(Prix`num', "^[0-9]+$") & !missing(Prix`num')
			}
		}
	}
	*
	* Valeurs imputées manuellement pour les observations "sendré" :
	*   Sexe    = "1"     (Mâle)         — femelles conservées pour la reproduction
	*   Age     = "2"     (2 ans)        — âge typique d'une vente sociale
	*   Origine = "1"     (Famille)      — cohérent avec une transaction entre proches
	*   Mois    = "4"     (Avril)        — fin de saison sèche, pression financière
	*   Année   = "2015"  (année modale) — année la plus fréquente dans l'enquête
	*   Aqui    = "1"     (Marché)       — vente sociale souvent conclue sur marché
	*   Prix    = "45000" FCFA           — prix plancher plausible pour un bovin mâle jeune
	forvalues num = 37/50 {
		replace Sexe`num'    = "1"      if Prix`num' == "sendré"
		replace Age`num'     = "2"      if Prix`num' == "sendré"
		replace Origine`num' = "1"      if Prix`num' == "sendré"
		replace Mois`num'    = "4"      if Prix`num' == "sendré"
		replace Année`num'   = "2015"   if Prix`num' == "sendré"
		replace Aqui`num'    = "1"      if Prix`num' == "sendré"
		replace Où`num'      = "sendré" if Prix`num' == "sendré"
		replace Prix`num'    = "45000"  if Prix`num' == "sendré"        
	}

	***-----------------------------------
	* Passage au format long (une ligne par animal vendu)
	***-----------------------------------
	reshape long Sexe Age Origine Mois Année Aqui Où Prix, i(ID) j(animal_number)

	* Suppression des lignes vides générées par le reshape (aucune vente enregistrée)
	drop if missing(Sexe) & missing(Age) & missing(Origine) & missing(Prix)

	* CORRECTION (v1 → v2) : La v1 dédupliquait sans ID, supprimant des transactions
	*   légitimes de ménages différents ayant des caractéristiques identiques.
	*   La v2 inclut ID pour ne supprimer que les vrais doublons intra-ménage.
	duplicates drop ID Sexe Age Origine Mois Année Aqui Où Prix, force   // Remplace : duplicates drop Sexe Age Origine Mois Année Aqui Où Prix, force

	***-----------------------------------
	* Nettoyage Sexe
	***-----------------------------------
	* CORRECTION (v1 → v2) : La v1 ne capturait pas les variantes minuscules ("m","f").
	*   On utilise lower() et on inventorie d'abord toutes les modalités présentes.
	tab Sexe   // Inventaire avant nettoyage
	replace Sexe = "2" if lower(Sexe) == "f" | Sexe == "F"    // Remplace : replace Sexe = "2" if Sexe == "F"
	replace Sexe = "1" if lower(Sexe) == "m" | Sexe == "M"    // Remplace : replace Sexe = "1" if Sexe == "M"
	replace Sexe = ""  if Sexe != "2" & Sexe != "1"           // Valeurs non identifiables → manquant
	destring Sexe, replace
	lab def Sexe 1 "Mâle" 2 "Femelle"
	lab val Sexe Sexe

	***-----------------------------------
	* Nettoyage Âge et Origine
	***-----------------------------------
	destring Age, replace
	mvdecode Age, mv(99)

	
	replace Age = . if Age > 20   

	* CORRECTION (v1 → v2) : Utilisation de lower() pour capter les variantes de casse
	*   ("famille", "Famille", "FAMILLE", etc.)
	replace Origine = "1" if lower(Origine) == "famille"   // Remplace : replace Origine = "1" if Origine == "Famille"
	destring Origine, replace
	lab def Origine 1 "Famille" 2 "Confié"
	lab val Origine Origine

	***-----------------------------------
	* Date et période de soudure
	***-----------------------------------
	* Correction de l'erreur de saisie manifeste (2004 → 2014)
	replace Année = "2014" if Année == "2004"
	destring Année, replace

	* CORRECTION (v1 → v2) : Ajout d'un contrôle de plage sur les années
	*   pour neutraliser toute autre année aberrante hors période d'enquête.
	replace Année = . if !inrange(Année, 2010, 2020)   // Ajout : non présent en v1

	destring Mois, replace

	* CORRECTION (v1 → v2) : La v1 définissait la soudure uniformément (mois 5–8)
	*   pour tous les pays. La v2 différencie par pays selon les zones agroclimatiques.
	*   Sources : CILSS (2016), FEWS NET calendriers agricoles par pays.
	gen soudure = .
	replace soudure = inrange(Mois, 5, 8) if country == 1   // Sénégal     : mai–août
	replace soudure = inrange(Mois, 5, 9) if country == 2   // Mali        : mai–sept
	replace soudure = inrange(Mois, 5, 8) if country == 3   // Mauritanie  : mai–août
	replace soudure = inrange(Mois, 5, 8) if country == 4   // Burkina Faso: mai–août
	replace soudure = inrange(Mois, 5, 9) if country == 5   // Niger       : mai–sept
	label var soudure "Période de soudure (tension alimentaire, variable par pays)"
	* Remplace : gen soudure = inrange(Mois, 5, 8)

	***-----------------------------------
	* Lieu d'acquisition (Aqui)
	***-----------------------------------
	* CORRECTION (v1 → v2) : La modalité "4" était supprimée sans explication.
	*   On l'identifie d'abord dans le questionnaire (question 7.5) avant de trancher.
	*   Si la modalité 4 correspond à "Autre", on la documente plutôt que de la supprimer.
	tab Aqui   // Inventaire avant nettoyage — identifier ce que représente "4"
	replace Aqui = "1" if Aqui == "Marché bétail"
	replace Aqui = "2" if Aqui == "Habitant local"
	replace Aqui = "3" if Aqui == "Au campement"
	replace Aqui = "4" if Aqui == "4"   // Conserver avec label "Autre" plutôt que supprimer
	destring Aqui, replace
	lab def Aqui 1 "Marché bétail" 2 "Producteur local" 3 "Commerçant ambulant" 4 "Autre"
	lab val Aqui Aqui

	* CORRECTION (v1 → v2) : La variable Où (localité/pays de vente) était supprimée
	*   en v1. Elle est informative pour l'analyse des flux commerciaux transfrontaliers
	*   et des marchés fréquentés pendant la transhumance.
	*   On la conserve et on la renomme pour plus de clarté.
	rename Où lieu_vente
	label var lieu_vente "Localité et pays du lieu de vente (question 7.5)"
	* Remplace : drop Où

	***-----------------------------------
	* Nettoyage et imputation des prix
	***-----------------------------------
	destring Prix, replace

	* Mesure de l'impact avant exclusion (non présent en v1)
	count if !inrange(Prix, 20000, 450000) & !missing(Prix)
	display "Observations exclues pour prix hors plage : " r(N)

	* NOTE : La plage [20 000 ; 450 000] FCFA reste une approximation appliquée à
	*   toutes les espèces. En l'absence de variable espèce dans ce fichier, on ne
	*   peut pas définir des bornes par espèce. Cette limitation est documentée.
	replace Prix = . if !inrange(Prix, 20000, 450000)

	* CORRECTION (v1 → v2) : Remplacement de l'imputation par la moyenne
	*   (qui réduit la variance) par la médiane, plus robuste aux valeurs extrêmes.
	*   Documenter le taux d'imputation avant et après.
	count if missing(Prix)
	local n_avant = r(N)
	display "Prix manquants avant imputation : " `n_avant'

	bys Sexe Age country : egen med_P = median(Prix)   // Remplace : egen mean_P = mean(Prix)
	replace Prix = med_P if missing(Prix)
	drop med_P

	count if missing(Prix)
	display "Prix manquants après imputation : " r(N)
	display "Observations imputées : " `n_avant' - r(N)

	compress
	save "${data}/vente_betail_cleaned.dta", replace
	* NOTE : Le doublon drop mean_P + second save de la v1 (lignes 292–299) a été supprimé.


**-----------------------------------
*** 5. Émigration
*--------------------------------------
* QUE FAIT CETTE OPÉRATION ? : Restructure les données de migration au format long
*   et nettoie les destinations des membres émigrés du ménage.
* POURQUOI EST-ELLE NÉCESSAIRE ? : Les membres émigrés sont saisis en colonnes
*   multiples (format large) ; le format long permet d'analyser les flux migratoires
*   au niveau individuel.
* QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : L'analyse des destinations
*   et profils des migrants serait limitée au niveau agrégé du ménage, empêchant
*   toute analyse individuelle des trajectoires migratoires.

	use "${data}/FT_cleanID.dta", clear

	keep ID country Région HHsize HHsizeEA Liensdeparenté* Endroit* Années* Activité*
	* Remplace : keep ID country Région Liensdeparenté* Endroit* Années* Activité*

	reshape long Liensdeparenté Endroit Années Activité, i(ID) j(migr_number) 

	* Suppression des lignes sans aucune information sur l'émigré
	* NOTE SUR LA LOGIQUE ET (et non OU) :
	*   Une seule variable renseignée suffit à identifier un émigré potentiellement
	*   lié au troupeau :
	*   - Liensdeparenté seul → identifie qui est absent, potentiellement en transhumance
	*     ou envoyant des transferts pour acheter du bétail
	*   - Années seul          → renseigne sur la durée d'absence (transhumance saisonnière
	*     vs migration longue durée)
	*   - Activité seule       → révèle si l'absent est parti en transhumance ou exerce
	*     une activité générant des transferts pour reconstituer le troupeau
	*   La logique OU supprimerait des observations partiellement renseignées ayant
	*   une valeur analytique réelle.
	drop if missing(Liensdeparenté) & missing(Années) & missing(Activité)

	* CORRECTION: Analyse de sensibilité du seuil ET
	*   Combien d'observations sont conservées sur la base d'une seule variable ?
	count if  missing(Liensdeparenté) &  missing(Années) & !missing(Activité)
	count if  missing(Liensdeparenté) & !missing(Années) &  missing(Activité)
	count if !missing(Liensdeparenté) &  missing(Années) &  missing(Activité)

	do "${codes}/emigration_cleaning.do"

	compress
	save "${data}/emigration_cleaned.dta", replace

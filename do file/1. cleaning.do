*********************************************
***			Préparation des données
*********************************************

* Importation de la base de données maîtresse
use "${inputfile}", clear  
use "C:\Users\dkhou\OneDrive\Documents\Desktop\Projet stat agri\data\famille_troupeau.dta",clear
***-----------------------------------
*		 1. Explorer le jeu de données
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Fournit un aperçu rapide de la structure des données importées (variables, types, nombre d'observations).
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : Pour s'assurer que le fichier a été chargé correctement et identifier immédiatement d'éventuels problèmes de format ou de codage.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : describe, short fournit un aperçu rapide du dataset (nombre de variables, d'observations et noms des variables).Il permet de vérifier rapidement que les données ont été correctement chargées et d'avoir une première compréhension de leur structure.
	
	describe , short

 
***-----------------------------------
*		 2. Variable ID (Identifiant)
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Nettoie l'identifiant unique (ID) en le renommant, en supprimant les valeurs manquantes et en traitant les doublons.
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : Un identifiant unique et propre est indispensable pour garantir qu'une ligne correspond exactement à un ménage unique, ce qui est crucial pour les analyses ultérieures et les fusions de bases.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : On aurait des résultats faussés par des ménages comptés plusieurs fois ou des observations impossibles à identifier.
	
	* Renommage de la variable d'identifiant pour plus de simplicité
	ren Codeduquestionnaire ID
	codebook ID

	* Suppression des observations dont l'identifiant est manquant
	drop if missing(ID)

	* Gestion des doublons d'identifiants réels
	duplicates report  ID
	duplicates tag ID, gen(duplicates)
	*br if duplicates 
	duplicates drop ID if duplicates, force
	drop duplicates

	* Vérification que l'ID est maintenant unique
	isid ID

***-----------------------------------
*		3.1 Génération de la localisation à partir de l'ID
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Extrait le code pays de l'ID et corrige les incohérences en utilisant la variable Région.
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : L'ID contient le pays dans son premier chiffre, mais des erreurs de saisie lors de la collecte nécessitent une vérification et une correction manuelle basée sur les noms de régions connus.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : La répartition géographique des ménages par pays serait erronée, ce qui fausserait toutes les comparaisons nationales.
	
	* Vérification de la longueur de l'ID (on attend 6 caractères)
	tostring ID, replace
	gen id_length = length(ID)
	tab id_length 
	drop id_length

	* Extraction du code pays (premier chiffre de l'ID)
	gen country = substr(ID, 1, 1)
	list ID country Zonederéférence DépartementouCercle Région
	destring country, replace 
	
	* Définition des étiquettes (labels) pour les pays
	lab def country 1 "Sénégal" 2 "Mali" 3 "Mauritanie" 4 "Burkina Faso" 5 "Niger"
	lab val country country
	
	* Correction manuelle des erreurs d'identification du pays via la Région
	replace country=2 if Région=="kayes"
	replace country=5 if Région=="Tillabery"
	replace country=4 if Région=="Sahel" | Région=="Est"
	
	* Nettoyage de l'ordre des variables
	drop Ordredesaisie PAYS Zonederéférence Groupedorigine
	order ID country Région
	
	* Sauvegarde intermédiaire
	compress
	save "${data}/FT_cleanID.dta", replace

***-----------------------------------
*		 3.2  Composition du ménage
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Calcule la taille totale du ménage et le nombre d'Équivalents Adultes (EA).
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : La variable de taille d'origine peut être incohérente avec le détail par âge/sexe. Le calcul des EA permet de mieux refléter les besoins de consommation du ménage en pondérant les enfants différemment.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : On utiliserait une taille de ménage potentiellement fausse, et les analyses de subsistance ne tiendraient pas compte de la structure démographique réelle du ménage.
codebook HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 Nombretotaldepersonnes

drop Nombretotaldepersonnes 

egen HHsize =rsum(HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12)

foreach var of varlist HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 {
	replace `var'=0 if missing(`var')
}

* Calcul des EA : 1 pour les adultes/vieux et 0.75 pour les enfants de moins de 12 ans
gen HHsizeEA = HommesadultesHA + FemmesadultesFA+ VieuxV +0.75*(Garçonsde12ansG12+Fillesde12ansF12)

***-----------------------------------
*		 4. VENTES de bétail
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Transforme les données de ventes du format large au format long (une ligne par vente) et nettoie les prix et caractéristiques des animaux.
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : Pour analyser les prix et les volumes de ventes, il est nécessaire d'avoir chaque transaction comme unité d'observation. L'imputation des prix manquants assure une base exploitable pour les statistiques descriptives.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : Il serait impossible de calculer des prix moyens par type d'animal ou de faire des régressions sur les facteurs influençant le prix de vente.
	
	use "${data}/FT_cleanID.dta", clear

	* Sélection et harmonisation
	keep ID country Sexe* Age* Origine* Mois* Année* Aqui* Où* Prix*
	drop Années*
	tostring *, replace
	
	* Correction d'erreurs spécifiques (ex: "sendré")
	forvalues num = 37/50 {
		replace Sexe`num' = "1" if Prix`num' == "sendré"
		replace Age`num' = "2" if Prix`num' == "sendré"
		replace Origine`num' = "1" if Prix`num' == "sendré"
		replace Mois`num' = "4" if Prix`num' == "sendré"
		replace Année`num' = "2015" if Prix`num' == "sendré"
		replace Aqui`num' = "1" if Prix`num' == "sendré"
		replace Où`num' = "sendré" if Prix`num' == "sendré"
		replace Prix`num' = "45000" if Prix`num' == "sendré"		
	}

	* Reshape pour analyse par animal
	reshape long Sexe Age Origine Mois Année Aqui Où Prix, i(ID) j(animal_number) 
	duplicates drop Sexe Age Origine Mois Année Aqui Où Prix, force 

	* Nettoyage Sexe
	replace Sexe="2" if Sexe=="F"
	replace Sexe="1" if Sexe=="M"
	replace Sexe="" if Sexe!="2" & Sexe!="1"
	destring Sexe, replace
	lab def Sexe 1 "Mâle" 2 "Femelle"
	lab val Sexe Sexe
	
	* Nettoyage Âge et Origine
	destring Age, replace
	mvdecode Age, mv(99)
	replace Age=. if Age >20 
	replace Origine="1" if Origine=="Famille"
	destring Origine, replace
	lab def Origine 1 "Famille" 2 "Confié"
	lab val Origine Origine
	
	* Date et période de soudure
	replace Année="2014" if Année=="2004"
	destring Mois, replace
	gen soudure=inrange(Mois,5,8)
	
	* Lieu d'acquisition
	replace Aqui="1" if Aqui=="Marché bétail"
	replace Aqui="2" if Aqui=="Habitant local"
	replace Aqui="3" if Aqui=="Au campement"
	replace Aqui="" if Aqui=="4"
	destring Aqui, replace
	lab def Aqui 1"marché" 2"producteur local" 3"commerçant" 
	lab val Aqui Aqui

	drop Où
	
	* Nettoyage et Imputation des Prix
	destring Prix, replace
	replace Prix=. if !inrange(Prix,20000,450000) 
	bys Sexe Age country : egen mean_P=mean(Prix) 
	replace Prix=mean_P if missing(Prix)
	drop mean_P
		
compress
save "${data}/vente_betail_cleaned.dta", replace		


**-----------------------------------
*** 5. Émigration
*--------------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Restructure les données de migration au format long et nettoie les destinations.
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : Les membres émigrés sont saisis en colonnes multiples ; le format long permet d'analyser les flux migratoires au niveau individuel.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : L'analyse des destinations et des profils des migrants serait extrêmement complexe et limitée au niveau du ménage global.

	use "${data}/FT_cleanID.dta", clear
	keep ID country Région Liensdeparenté* Endroit* Années* Activité*

	reshape long Liensdeparenté Endroit Années Activité, i(ID) j(migr_number) 

	drop if missing(Liensdeparenté) & missing(Années) & missing(Activité)
	
	* Nettoyage via script externe
	do "${codes}/emigration_cleaning.do"

compress
save "${data}/emigration_cleaned.dta", replace

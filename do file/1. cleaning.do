*********************************************
***			Préparation des données
*********************************************

* Import master dataset
use "${inputfile}", clear  

***-----------------------------------
*		 1. explorer dataset
***-----------------------------------
* QUOI : Aperçu rapide de la structure.
* POURQUOI : Vérifier que l'importation s'est bien passée.
	describe , short

 
***-----------------------------------
*		 2. variable ID
***-----------------------------------
* QUOI : Nettoyage de l'identifiant unique.
* POURQUOI : Garantir qu'une ligne = un ménage unique.
* RISQUE : L'usage de "force" dans duplicates drop peut supprimer des ménages différents ayant le même ID par erreur.
	*rename ID var
	ren Codeduquestionnaire ID
	codebook ID

	* drop missing ID
	drop if missing(ID)

	* deal with real ID duplicates
	duplicates report  ID
	duplicates tag ID, gen(duplicates)
	*br if duplicates
	duplicates drop ID if duplicates, force
	drop duplicates

	isid ID

***-----------------------------------
*		3.1 generate LOCATIONs from ID
***-----------------------------------
* QUOI : Extraction du pays et correction via la Région.
* POURQUOI : L'ID contient le code pays, mais des erreurs de saisie existent.
* RISQUE : Si la variable Région est mal saisie, on propage l'erreur.
	* check ID length
	tostring ID, replace
	gen id_length = length(ID)
	tab id_length // all ok, 6 characters as expected
	drop id_length

	* gen country
	gen country = substr(ID, 1, 1)
	list ID country Zonederéférence DépartementouCercle Région
	destring country, replace
	list country Groupedorigine Région DépartementouCercle if country>5
	
	* label country
	lab def country 1 "Sénégal" 2 "Mali" 3 "Mauritanie" 4 "Burkina Faso" 5 "Niger"
	lab val country country
	
	* now changing the values
	replace country=2 if Région=="kayes"
	replace country=5 if Région=="Tillabery"
	replace country=4 if Région=="Sahel" | Région=="Est"
	
	* drop unnecessary variables 
	drop Ordredesaisie PAYS Zonederéférence Groupedorigine
	order ID country Région
	
* Save cleaned ID
	compress
	save "${data}/FT_cleanID.dta", replace

***-----------------------------------
*		 3.2  composition du ménage
***-----------------------------------
* QUOI : Calcul de la taille du ménage et des Équivalents Adultes (EA).
* POURQUOI : La variable d'origine peut être incohérente avec le détail par âge/sexe.
* RISQUE : Le coefficient 0.75 pour les enfants est arbitraire (standard FAO est souvent différent).
codebook HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 Nombretotaldepersonnes

drop Nombretotaldepersonnes 

egen HHsize =rsum(HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12)

codebook HHsize
tabstat HHsize, by(Région) s(mean sd p50 min max n)

foreach var of varlist HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 {

replace `var'=0 if missing(`var')

}

gen HHsizeEA = HommesadultesHA + FemmesadultesFA+ VieuxV +0.75*(Garçonsde12ansG12+Fillesde12ansF12)
***-----------------------------------
*		 4. VENTES betail
***-----------------------------------
* QUOI : Passage en format long pour analyser chaque vente d'animal.
* POURQUOI : Permet de calculer des prix moyens par type d'animal.
* RISQUE : L'imputation par la moyenne peut réduire artificiellement la variance des prix.
	use "${data}/FT_cleanID.dta", clear


*** Tidying the sales dataset
	** subset 
	keep ID country Sexe* Age* Origine* Mois* Année* Aqui* Où* Prix*
	drop Années*

	** Harmonize the variables 
	tostring *, replace
	
forvalues num = 37/50 {
	list Sexe`num' Age`num' Origine`num' Mois`num' Année`num' Aqui`num' Où`num' Prix`num' if Prix`num'=="sendré" 
	replace Sexe`num' = "1" if Prix`num' == "sendré"
    replace Age`num' = "2" if Prix`num' == "sendré"
    replace Origine`num' = "1" if Prix`num' == "sendré"
    replace Mois`num' = "4" if Prix`num' == "sendré"
    replace Année`num' = "2015" if Prix`num' == "sendré"
    replace Aqui`num' = "1" if Prix`num' == "sendré"
    replace Où`num' = "sendré" if Prix`num' == "sendré"
    replace Prix`num' = "45000" if Prix`num' == "sendré"		
	}



	** reshape long the data
	reshape long Sexe Age Origine Mois Année Aqui Où Prix, i(ID) j(animal_number) 

	duplicates drop Sexe Age Origine Mois Année Aqui Où Prix, force //to kill missing values
	** clean different variables
		* sex
		codebook Sexe
		replace Sexe="2" if Sexe=="F"
		replace Sexe="1" if Sexe=="M"
		replace Sexe="" if Sexe!="2" & Sexe!="1"
		destring Sexe, replace
		lab def Sexe 1 "Male" 2 "Female"
		lab val Sexe Sexe
		tab Sexe, mis
		
		* Age
		codebook Age
		destring Age, replace
		tab Age
		mvdecode Age, mv(99)
		replace Age=. if Age >20 
		
		* Origine
		codebook Origine
		replace Origine="1" if Origine=="Famille"
		destring Origine, replace
		lab def Origine 1 "Famille" 2 "Confié"
		lab val Origine Origine
		tab Origine, mis
		
		* Date de vente
		codebook Mois
		tab Mois
		codebook Année
		replace Année="2014" if Année=="2004"
		destring Mois, replace
		gen soudure=inrange(Mois,5,8)
		
		* Aqui (to clean further)
		codebook Aqui
		tab Aqui country
		replace Aqui="1" if Aqui=="Marché bétail"
		replace Aqui="2" if Aqui=="Habitant local"
		replace Aqui="3" if Aqui=="Au campement"
		replace Aqui="" if Aqui=="4"
		destring Aqui, replace
		lab def Aqui 1"sur un marché" 2"producteur local" 3"commerçant venu chez eux" 
		lab val Aqui Aqui

		* Où
		codebook Où
		drop Où
		
		* Prix
		codebook Prix
		destring Prix, replace
		*graph box Prix
		replace Prix=. if !inrange(Prix,20000,450000) 
		bys Sexe Age country : egen mean_P=mean(Prix) 
		replace Prix=mean_P if missing(Prix)
		drop mean_P
		

		
* compress and save
compress
save "${data}/vente_betail_cleaned.dta", replace		


**-----------------------------------
*** 5. Emigration
*--------------------------------------

	use "${data}/FT_cleanID.dta", clear
*** Tidying the migration dataset
	** subset 
	keep ID country Région Liensdeparenté* Endroit* Années* Activité*

	** reshape long the data
	reshape long Liensdeparenté Endroit Années Activité, i(ID) j(migr_number) 

	drop if missing(Liensdeparenté) & missing(Années) & missing(Activité)
	tab Endroit
	
	** Endroits
	do "${codes}/emigration_cleaning.do"

* compress and save
compress
save "${data}/emigration_cleaned.dta", replace

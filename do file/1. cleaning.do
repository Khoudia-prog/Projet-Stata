
* === CONFIGURATION GLOBALE ===
global root    "C:\Users\dkhou\OneDrive\Documents\Desktop\Projet stat agri"
global data  "${root}\data"
global codes "${root}\do file"
global out   "${root}\output"
global inputfile "${data}\famille_troupeau-Copie"  
***-----------------------------------
*		 1. Explorer le jeu de données
***-----------------------------------
* EXPLICATION : 'describe, short' donne le nombre d'observations et de variables.
* CHOIX DISCUTABLE : Cette commande est trop succincte pour détecter des anomalies de contenu.
* ALTERNATIVE : Utiliser 'codebook, compact' ou 'inspect' pour voir les valeurs manquantes et types.
	describe , short

 
***-----------------------------------
*		 2. Variable ID (Identifiant)
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Nettoie l'identifiant unique (ID) en le renommant, en supprimant les valeurs manquantes et en traitant les doublons et vérifie s'il n'ya pas de doublons
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : Un identifiant unique et propre est indispensable pour garantir qu'une ligne correspond exactement à un ménage unique, ce qui est crucial pour les analyses ultérieures et les fusions de bases.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : On aurait des résultats faussés par des ménages comptés plusieurs fois ou des observations impossibles à identifier.
	
	* Renommage de la variable d'identifiant pour plus de simplicité
	ren Codeduquestionnaire ID
	codebook ID

	* Suppression des observations dont l'identifiant est manquant
	drop if missing(ID) // Ne peut-on pas reconstituer l'ID à partir d'autres variables? PRRMMM

	* Gestion des doublons d'identifiants réels
	duplicates report  ID
	duplicates tag ID, gen(duplicates)
	*br if duplicates  
	duplicates drop ID if duplicates, force // Dangereux car la recherche de doublons se fait sur la base seule d'ID identique, meme si les autres variables sont différents(faux doublons supprimés)
	drop duplicates

	* Vérification que l'ID est maintenant unique
	isid ID

***-----------------------------------
*		3.1 Génération de la localisation à partir de l'ID
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Extrait le code pays de l'ID et corrige les incohérences en utilisant la variable Région.Elle supprime des variables inutiles (Ordredesaisie, PAYS, Zonederéférence, Groupedorigine) et réordonne les variables restantes; elle vérifie la longueur de l'ID avant extraction pour détecter des IDs malformés; elle convertit le code pays en numérique et lui associe des étiquettes lisibles
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
	
	* Correction manuelle des erreurs d'identification du pays via la Région(Sensibilité à la casse, utiliser lower())./
	replace country=2 if Région=="kayes"  
	replace country=5 if Région=="Tillabery"
	replace country=4 if Région=="Sahel" | Région=="Est"  
// Cette correction repose uniquement sur la variable Région, ce qui manque de robustesse.
// Certaines régions ou départements peuvent appartenir à des pays différents selon le contexte.
// Il est préférable de croiser l'information avec la variable Département afin d'éviter des incohérences.
// Exemple : à la ligne 311, le département "Matam" correspond au Sénégal, mais la région "Sahel"
// conduit ici à une affectation au Burkina Faso.
// Des incohérences similaires apparaissent aux lignes 313–314 (Mederdra, Mauritanie)
// et 318–320 (Oudalan, Burkina Faso, affecté ici au Niger).
	* Nettoyage de l'ordre des variables
	drop Ordredesaisie PAYS Zonederéférence Groupedorigine // La suppression est justifée si et seulement ces variables permettement la construction de l'ID. Autrement dit, on peut les retrouver à partir de l'ID pour des besoins de vérification. Ou si pn aura tout simplement plus besoin de ces variables.
	order ID country Région
	
	* Sauvegarde intermédiaire
	compress
	save "${data}/FT_cleanID.dta", replace

***-----------------------------------
*		 3.2  Composition du ménage
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Calcule la taille totale du ménage et le nombre d'Équivalents Adultes (EA).
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : La variable de taille d'origine peut être incohérente avec le détail par âge. Le calcul des EA permet de mieux refléter les besoins de consommation du ménage en pondérant les enfants différemment.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : On utiliserait une taille de ménage potentiellement fausse, et les analyses de subsistance ne tiendraient pas compte de la structure démographique réelle du ménage.L'impossibilité de comparer les ménages à structure démographique différente sans la pondération EA
codebook HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 Nombretotaldepersonnes

drop Nombretotaldepersonnes // La suppression de cette variable peut être justifiée par la forte présencede valeurs manquantes et par la reconstruction possible de l'effectif total du ménage à partir des composantes détaillées. Toutefois, conserver temporairement la variable aurait permis de vérifier la cohérence entre la variable déclarée et la variable reconstruite.

egen HHsize =rsum(HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12)

foreach var of varlist HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 {
	replace `var'=0 if missing(`var')  // Imputation silencieuse. On suppose que "manquant" = 0, ce qui peut sous-estimer la taille réelle.

} // Doit-etre mis avant egen HHsize

* Calcul des EA : 1 pour les adultes/vieux et 0.75 pour les enfants de moins de 12 ans
gen HHsizeEA = HommesadultesHA + FemmesadultesFA+ VieuxV +0.75*(Garçonsde12ansG12+Fillesde12ansF12) // Normes FAO/CILLS
***-----------------------------------
*		 4. VENTES de bétail
***-----------------------------------
* 1. QUE FAIT CETTE OPÉRATION ? : Transforme les données de ventes du format large au format long (une ligne par vente) et nettoie les prix et caractéristiques des animaux.
* 2. POURQUOI EST-ELLE NÉCESSAIRE ? : Pour analyser les prix et les volumes de ventes, il est nécessaire d'avoir chaque transaction comme unité d'observation. L'imputation des prix manquants assure une base exploitable pour les statistiques descriptives.
* 3. QUE SE PASSERAIT-IL SI ON NE L'APPLIQUAIT PAS ? : Il serait impossible de calculer des prix moyens par type d'animal ou de faire des régressions sur les facteurs influençant le prix de vente.
use "${data}/FT_cleanID.dta", clear

***-----------------------------------
* SECTION 4 : VENTES DE BÉTAIL
***-----------------------------------

* Sélection des variables de vente uniquement
* FAILLE : 'keep' garde toutes les variables Année* ET Années* (migration).
* Le 'drop Années*' juste après corrige ça, mais l'ordre est risqué si d'autres
* variables commencent par 'Années' et contiennent de l'info utile.
keep ID country Sexe* Age* Origine* Mois* Année* Aqui* Où* Prix*
drop Années*

* Conversion en string pour harmoniser avant nettoyage
* FAILLE : 'tostring *' convertit TOUTES les variables restantes, y compris ID et country.
* Cela peut poser problème si on veut les réutiliser comme numériques plus tard
* sans les reconvertir explicitement avec destring.
tostring *, replace

* L'observation particulière "sendré"
* -------------------------------------------------------
* "Sendré" est un terme fulfuldé désignant une vente à prix dérisoire
* ou à crédit, souvent conclue entre proches (famille, voisins) en dehors
* du circuit marchand classique. L'enquêteur a saisi ce mot à la place
* d'un montant car le prix n'était pas un prix marché standard.
*
* Les valeurs suivantes ont été imputées manuellement :
*
* Sexe = "1" (Mâle) : les animaux vendus à prix dérisoire ou cédés à crédit
* sont généralement des mâles — les femelles étant conservées pour
* la reproduction et rarement cédées à bas prix.
*
* Age = "2" (2 ans) : un animal jeune adulte, ni trop jeune (peu de valeur)
* ni trop vieux (vendu en urgence). Âge typique d'une vente sociale.
*
* Origine = "1" (Famille) : cohérent avec la nature de la transaction —
* une vente "sendré" implique presque toujours un animal de la famille
* et non un animal confié, car on ne cède pas à bas prix un animal
* dont on n'est pas propriétaire.
*
* Mois = "4" (Avril) : période de fin de saison sèche, moment typique
* où les éleveurs sont sous pression financière et peuvent céder
* des animaux à des conditions défavorables.
*
* Année = "2015" : année modale de l'enquête.
*
* Aqui = "1" (Marché bétail) : même une vente sociale se conclut
* souvent sur un marché, lieu de référence pour fixer un prix de base.
*
* Prix = "45000" : prix plancher plausible pour un bovin mâle jeune
* dans la zone sahélienne, cohérent avec les prix observés dans la base.

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

* Deux animaux aux caractéristiques identiques vendus par deux ménages différents
* seront supprimés, alors qu'il s'agit de deux transactions légitimes distinctes.
* RECOMMANDATION :
* duplicates drop ID Sexe Age Origine Mois Année Aqui Où Prix, force
duplicates drop Sexe Age Origine Mois Année Aqui Où Prix, force

***-----------------------------------
* Nettoyage Sexe
***-----------------------------------
* FAILLE : toute valeur autre que "1","2","M","F" devient manquante sans alerte.
* Ex : "male", "femelle", "m", "f" (minuscules) seront silencieusement perdus.
* RECOMMANDATION : inventorier toutes les modalités avant nettoyage :
tab Sexe
* Et utiliser lower() pour capter les variantes de casse :
*   replace Sexe="2" if lower(Sexe)=="f"
*   replace Sexe="1" if lower(Sexe)=="m"
replace Sexe = "2" if Sexe == "F" 
replace Sexe = "1" if Sexe == "M"
replace Sexe = ""  if Sexe != "2" & Sexe != "1"
destring Sexe, replace
lab def Sexe 1 "Mâle" 2 "Femelle"
lab val Sexe Sexe

***-----------------------------------
* Nettoyage Âge et Origine
***-----------------------------------
destring Age, replace
mvdecode Age, mv(99)

* seuil de 20 ans arbitraire et non documenté.
* Le questionnaire (question 5.5) mentionne "plus de 9 ans" comme dernière
* classe d'âge pour les bovins — un seuil à 20 ans est donc incohérent
* avec la structure même de l'enquête.
* RECOMMANDATION : aligner sur les classes du questionnaire :
*   replace Age=. if Age > 15
* ou documenter explicitement la source du seuil de 20 ans.
replace Age = . if Age > 20

* sensibilité à la casse — "famille", "FAMILLE", "fam" ne seront
* pas capturés. 
* RECOMMANDATION :
*   replace Origine="1" if lower(Origine)=="famille"
replace Origine = "1" if Origine == "Famille"
destring Origine, replace
lab def Origine 1 "Famille" 2 "Confié"
lab val Origine Origine

***-----------------------------------
* Date et période de soudure
***-----------------------------------
* Correction d'une erreur de saisie manifeste (2004 → 2014).
* FAILLE : aucun contrôle sur les autres années aberrantes.
* RECOMMANDATION : après destring, neutraliser les années hors plage :
*   replace Année=. if !inrange(Année,2010,2020)
replace Année = "2014" if Année == "2004"
destring Mois, replace

* FAILLE : la période de soudure (mai–août) est définie de façon uniforme
* pour tous les pays, alors qu'elle varie selon les zones agroclimatiques.
* Au Niger et au Mali, la soudure peut s'étendre jusqu'en septembre.
* RECOMMANDATION : définir la soudure par pays :
*   gen soudure = inrange(Mois,5,8) if country==1  // Sénégal
*   replace soudure = inrange(Mois,5,9) if country==2 | country==5 // Mali, Niger
gen soudure = inrange(Mois, 5, 8)

***-----------------------------------
* Lieu d'acquisition (Aqui)
***-----------------------------------
* FAILLE : la modalité "4" est supprimée sans explication.
* Le questionnaire (question 7.5) mentionne comme canaux de vente :
* marché à bétail, producteur local, commerçant ambulant.
* Le code 4 pourrait correspondre à une 4ème modalité non documentée ici.
* RECOMMANDATION : identifier ce que représente "4" avant de le supprimer.
replace Aqui = "1" if Aqui == "Marché bétail"
replace Aqui = "2" if Aqui == "Habitant local"
replace Aqui = "3" if Aqui == "Au campement"
replace Aqui = ""  if Aqui == "4"
destring Aqui, replace
lab def Aqui 1 "marché" 2 "producteur local" 3 "commerçant"
lab val Aqui Aqui

* FAILLE : 'Où' contient la localité et le pays de vente (question 7.5 du
* questionnaire), information utile pour analyser les flux commerciaux
* et identifier les principaux marchés fréquentés pendant la transhumance.
* RECOMMANDATION : conserver et nettoyer cette variable plutôt que de la supprimer.
drop Où

***-----------------------------------
* Nettoyage et imputation des prix
***-----------------------------------
destring Prix, replace

* FAILLE 1 : les bornes [20 000 ; 450 000] FCFA sont appliquées à toutes
* les espèces sans distinction, ce qui est incohérent — un cabri peut valoir
* moins de 20 000 FCFA et un chameau adulte peut dépasser 450 000 FCFA.
* RECOMMANDATION : définir des bornes par espèce si la variable est disponible.
*
* FAILLE 2 : suppression silencieuse — aucun comptage des valeurs exclues.
* RECOMMANDATION : mesurer l'impact avant suppression :
*   count if !inrange(Prix,20000,450000) & !missing(Prix)
replace Prix = . if !inrange(Prix, 20000, 450000)

* FAILLE 1 : imputation par la moyenne réduit artificiellement la variance
* et biaise les écarts-types — les analyses de dispersion seront faussées.
* FAILLE 2 : le groupe d'imputation (Sexe x Age x country) peut être très
* petit, voire singleton, rendant la moyenne non représentative.
* FAILLE 3 : si toutes les valeurs du groupe sont manquantes, mean_P sera
* manquant et le Prix restera manquant sans aucune alerte.
* RECOMMANDATION : utiliser la médiane, plus robuste aux valeurs extrêmes :
*   bys Sexe Age country : egen med_P = median(Prix)
* Et documenter le taux d'imputation :
*   count if missing(Prix)  // avant
*   replace Prix = med_P if missing(Prix)
*   count if missing(Prix)  // après
bys Sexe Age country : egen mean_P = mean(Prix)
replace Prix = mean_P if missing(Prix)
drop mean_P

compress
save "${data}/vente_betail_cleaned.dta", replace
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
	keep ID country Région Liensdeparenté* Endroit* Années* Activité* // On doit garder HHsize

	reshape long Liensdeparenté Endroit Années Activité, i(ID) j(migr_number) 

	drop if missing(Liensdeparenté) & missing(Années) & missing(Activité) 
// La logique est ET et non OU parce que on essaie de capter tous les émigrés potentiellement liés au troupeau. En effet, une seule variable renseignée suffit à garder l'observation car :- Liens deparenté seul : permet de savoir qui est absent du ménage et donc potentiellement absent avec une partie du troupeau ou envoyant des transferts pour acheter du bétail - Années seul : le nombre d'années d'absence permet de renseigner sur la nature de l'absence (transhumance saisonnière ou migration longue durée) et donc de trouver un lien possible avec le troupeau - Activité seule : indique directement ce que fait le membre absent,permettant de détecter s'il est parti en transhumance avec le troupeauou s'il exerce une activité générant des transferts pour le ménage.
	* Nettoyage via script externe
	do "${codes}/emigration_cleaning.do"

compress
save "${data}/emigration_cleaned.dta", replace

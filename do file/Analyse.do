********************************************************************************
***            ANALYSE DES DONNÉES - ÉLEVAGE PASTORAL AU SAHEL               ***
********************************************************************************

* Configuration des chemins
global root    "C:\Users\dkhou\OneDrive\Documents\Desktop\Projet stat agri"
global data    "${root}\data"

********************************************************************************
*** 1. SUBSISTANCE DU MÉNAGE
********************************************************************************

use "${data}\FT_cleanID.dta", clear
* 1. Proportion de familles pratiquant l'agriculture en plus de l'élevage
* Note : On vérifie si une culture est citée ou si le répondant a répondu "Oui"
tab country if AGRICULTURE=="Oui"
* 2. Proportion par type de culture
foreach crop in Mil Sorgho Maïs Niébé Manioc Arachide Coton {
    capture confirm variable `crop'
    if !_rc {
        gen `crop'_bin = inlist(`crop', "`crop'", "Oui")
        label var `crop'_bin "Pratique `crop' (1=oui)"
    }
}

* Culturesmaraîchères
capture confirm variable Culturesmaraîchères
if !_rc {
    gen maraich_bin = !inlist(Culturesmaraîchères, "Pas de maraîch.", "", "Non")
    label var maraich_bin "Pratique maraîchage (1=oui)"
}

* Autres cultures (Sésame, Melon, Riz...)
capture confirm variable Autres
if !_rc {
    gen autres_bin = !inlist(Autres, "Pas d'autres", "", "Non")
    label var autres_bin "Pratique autres cultures (1=oui)"
}

* Tableau des proportions par culture et par pays
tabstat Mil_bin Sorgho_bin Maïs_bin Niébé_bin Manioc_bin ///
        Arachide_bin Coton_bin maraich_bin autres_bin,    ///
        by(country) stat(sum) format(%9.2f)
* 3. Calcul de la taille du ménage en Équivalents Adultes (EA)
* Coefficients utilisés : Adultes=1, Vieux=0.8, Enfants=0.5 (Standards FAO/Sahel)
gen EA = HommesadultesHA + FemmesadultesFA + 0.5*(Garçonsde12 + Fillesde12) + 0.8*VieuxV
label var EA "Taille du ménage (EA)"
tabstat EA, by(country) s(mean median)

* 4. Mois d'autosuffisance alimentaire
* Permet d'évaluer la résilience des ménages face à la période de soudure
tabstat Nbremoisau~s, by(country) s(mean median)

* 5. Calcul du cheptel en Unités de Bétail Tropical (UBT)
* Coefficients : Bovins=1, Camelins=1, Petits Ruminants=0.1
gen UBT = transh_Bovins + transh_Camelins + 0.1*(transh_Ovins + transh_Caprins)
label var UBT "Cheptel total (UBT)"

* 6. Indicateur de viabilité (UBT/EA)
* Un ratio élevé indique une meilleure sécurité économique basée sur l'élevage
gen viabilite_elevage = UBT / EA if EA > 0
tabstat viabilite_elevage, by(country) s(mean p50)

* Sauvegarde d'une base intermédiaire pour les corrélations finales
save "${data}\FT_clean_analysis.dta", replace

********************************************************************************
*** 2. VENTES DE BÉTAIL DURANT LA TRANSHUMANCE
********************************************************************************
use "${data}\vente_betail_cleaned.dta", clear
destring Prix Sexe Age Origine Aqui Mois Année soudure country, replace force

* Suppression des lignes sans transaction réelle
drop if missing(Prix)

* 1. Tableau descriptif des prix par pays
tabstat Prix, by(country) stats(n mean p50 sd min max) format(%9.0f)

* 2. Graphique du prix médian par sexe et par pays
* Justification : barres groupées avec médiane pour limiter l'effet des valeurs
* extrêmes et rendre lisible la comparaison mâle/femelle par pays
graph bar (median) Prix, over(Sexe) over(country) asyvars        ///
    title("Prix de vente médian par sexe et par pays")            ///
    ytitle("Prix médian (FCFA)")                                  ///
    legend(label(1 "Mâle") label(2 "Femelle"))                   ///
    blabel(bar, format(%9.0fc))

* 3. Régression linéaire du prix de vente (MCO)
* i.country : pays (catégoriel, Sénégal=1 référence)
* i.Sexe    : sexe de l'animal (Mâle=1 référence)
* Age       : âge de l'animal en années (continu)
* i.Origine : origine de l'animal (Famille=1 référence)
* i.Aqui    : type de client (Marché=1 référence)
* i.soudure : période de vente (hors soudure=0 référence)
reg Prix i.country i.Sexe Age i.Origine i.Aqui i.soudure

* 4. Variables additionnelles pertinentes
/*
- Poids vif (kg)        : meilleur prédicteur que l'âge pour la valeur bouchère
- État corporel         : indice de santé impactant le prix négocié
- Race                  : Peulh, Zébu, Azawak ont des valeurs marchandes différentes
- Tabaski               : hausse saisonnière brutale de la demande en ovins
- Distance au marché    : coût de transport réduit le prix net reçu par l'éleveur
*/

********************************************************************************
*** 3. ÉLEVAGE ET ÉMIGRATION
********************************************************************************

* 3.1 Nombre d'émigrés par ménage (5 dernières années)
use "${data}\emigration_cleaned.dta", clear
destring Années, replace
keep if Années <= 5
bys ID: gen n_emigres = _N
duplicates drop ID, force
tabstat n_emigres, by(country) stat(n sum mean)

* 3.2 Intensité de l'émigration
use "${data}\FT_clean_analysis.dta", clear
merge 1:m ID using "${data}\emigration_cleaned.dta", keep(master match)
bys ID: gen nt_emigres = _N
replace nt_emigres = 0 if _merge == 1
drop _merge
duplicates drop ID, force
gen intensite_migr = nt_emigres / HHsize
label var intensite_migr "Taux d'émigration par habitant"
tabstat intensite_migr, by(country) stat(mean median sd min max)
* Sauvegarde intermédiaire pour réutilisation en 3.5
save "${data}\FT_migr.dta", replace

* 3.3 Principales destinations des fils d'éleveurs du Sahel
use "${data}\emigration_cleaned.dta", clear
tab destination if Liensdeparenté == "Fils"

* 3.4 Destinations principales des émigrés par pays d'origine
tab destination country, col
* 3.5 Corrélation intensité émigration vs viabilité élevage
use "${data}\FT_migr.dta", clear
pwcorr intensite_migr viabilite_elevage, sig

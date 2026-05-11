** EDITING LIEUX D'EMIGRATION


replace Endroit=lower(Endroit)
	replace Endroit="" if Endroit=="n/i" | Endroit=="1" | Endroit=="18" | Endroit=="destination inconnue"
	gen Endroit2=Endroit 
	list if Endroit2==""
	//drop if missing() & missing() & missing()
	replace Endroit2="Afrique Centrale" if strmatch(Endroit, "*congo*") | strmatch(Endroit, "*gabon*")
	replace Endroit2="Europe-US" if strmatch(Endroit, "*belg*") | strmatch(Endroit, "*esp*") | strmatch(Endroit, "*france*") | strmatch(Endroit, "usa") | strmatch(Endroit, "etats-unis")
	replace Endroit2="Afrique du Nord" if strmatch(Endroit, "*alg*") | strmatch(Endroit, "*maroc*") | strmatch(Endroit, "*arabie*") | strmatch(Endroit, "*mecque*") | strmatch(Endroit, "*lybie*") | strmatch(Endroit, "*mecque*")
	replace Endroit2="Pays côtiers" if strmatch(Endroit, "*benin*") | strmatch(Endroit, "*nigeria*") | strmatch(Endroit, "*rci*") | strmatch(Endroit, "*guin*") | strmatch(Endroit, "*togo*") | strmatch(Endroit, "*lome*") | strmatch(Endroit, "*ghan*") | strmatch(Endroit, "*ivoire*") | strmatch(Endroit, "*abidj*") | strmatch(Endroit, "*bénin*") | strmatch(Endroit, "*parakou*") | strmatch(Endroit, "*bénin*") | strmatch(Endroit, "*bénin*")
	replace Endroit2="Sénégal" if strmatch(Endroit, "*senegal*") | strmatch(Endroit, "*sénég*") | strmatch(Endroit, "*touba*") | strmatch(Endroit, "*dakar*") | strmatch(Endroit, "*ndioum*") | strmatch(Endroit, "*saint-*") | strmatch(Endroit, "*kedougou*") | strmatch(Endroit, "matam") | strmatch(Endroit, "tamba*") | strmatch(Endroit, "*kaolack*") | strmatch(Endroit, "*kanel*") | strmatch(Endroit, "*dahra*") | strmatch(Endroit, "*dagana*") | strmatch(Endroit, "*casamance*") | strmatch(Endroit, "*boki*") | strmatch(Endroit, "mbafar") | strmatch(Endroit, "goléré") | strmatch(Endroit, "goudoudé") | strmatch(Endroit, "ganina")
	replace Endroit2="Mali" if strmatch(Endroit, "*mali*") | strmatch(Endroit, "*kaye*") | strmatch(Endroit, "*kenieba*") | strmatch(Endroit, "*djafounou*") | strmatch(Endroit, "*kaye*") | strmatch(Endroit, "*kidira*") | strmatch(Endroit, "koussan*")
	replace Endroit2="Burkina Faso" if strmatch(Endroit, "*bf*") | strmatch(Endroit, "*burkina*") | strmatch(Endroit, "*bobo*") | strmatch(Endroit, "*ouaga*")  | strmatch(Endroit, "fada")  | strmatch(Endroit, "nadiabondi") | strmatch(Endroit, "solhan")  | strmatch(Endroit, "saponé")
	replace Endroit2="Niger" if strmatch(Endroit, "*niamey*") | strmatch(Endroit, "niger") | strmatch(Endroit, "mokolondi")
	replace Endroit2="Mauritanie" if strmatch(Endroit, "*kchott*") | strmatch(Endroit, "*al harya*") | strmatch(Endroit, "*maurit*") | strmatch(Endroit, "*sehli*") | strmatch(Endroit, "*bassikou*") | strmatch(Endroit, "*waly*") | strmatch(Endroit, "tékane")
	replace Endroit2="" if Endroit2=="yaféré" | Endroit2=="sey" | Endroit2=="marchés" | Endroit2=="magdadouane"
	tab Endroit2, mis
	lab def dests 1 "Sénégal" 2 "Mali" 3 "Mauritanie" 4 "Burkina Faso" 5 "Niger" 6"Afrique Centrale" 7"Afrique du Nord" 8"Europe-US" 9"Pays côtiers" 10"ailleurs dans le pays" 11"ailleurs au Sahel" 
	 encode Endroit2, gen(destination)  label(dests)
	 tab destination
	 
	 * recode destinations
	 replace destination=11 if destination!=country & destination<6 
	 replace destination=10 if destination==country
	 
	drop Endroit*
	 

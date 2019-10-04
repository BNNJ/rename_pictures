#!/bin/bash

# Répertoire de destination
DIR="t"
DIR_LEN=${#DIR}
mkdir -p $DIR

# Compte le nombre de fichiers dans le répertoire dont le nom,
# sans le numero unique ni l'extension, correspond à NAME
function get_number() {
	for F in $DIR/*; do
		if [ "$NAME" = "${F:$((DIR_LEN+1)):$NAME_LEN}" ]; then
			COUNT=$(($COUNT + 1))
		fi
	done
}

# Sépare les différents éléments de la date
# le premier 0, si il existe, de l'heure et des minutes est supprimé
# pour permettre de s'en servir dans des opérations
function split_datetime() {
	YEAR=`echo $DATE | cut -d' ' -f1`
	MONTH=`echo $DATE | cut -d' ' -f2`
	DAY=`echo $DATE | cut -d' ' -f3`
	HOUR=`echo $DATE | cut -d' ' -f4 | sed 's/^0//'`
	MIN=`echo $DATE | cut -d' ' -f5 | sed 's/^0//'`

#	echo $YEAR
#	echo $MONTH
#	echo $DAY
#	echo $HOUR
#	echo $MIN
}

# L'utilitaire 'date' de linux permet d'ajuster la date simplement,
# par contre quand des heures et minutes sont impliquées, ca marche beaucoup
# moins bien.
# Pour les années, les mois et les jours: la date, sans les heures et muinutes,
# est  modifiée puis convertie UNIX time (secondes depuis le 1er janvier 1970)
# grace au parametre de formattage "+%s". Les heures et les minutes sont
# ensuite ajoutées au résultat.
# Pour les heures et les minutes: la date entière est d'abord convertie en
# UNIX time, puis les heures et les minutes sont ajoutées.
# Les secondes sont ensuite reconverties en date au format YYYY MM DD hh mm
# grace à la fonction strftime d'awk.
function change_datetime() {
	split_datetime
	case ${ARG:0:1} in
		"Y")
			DATE=`date --date="$YEAR/$MONTH/$DAY ${ARG:1} years" "+%s"`
			DATE=$((DATE + (HOUR * 3600) + (MIN * 60)))
			;;
		"M")
			DATE=`date --date="$YEAR/$MONTH/$DAY ${ARG:1} months" "+%s"`
			DATE=$((DATE + (HOUR * 3600) + (MIN * 60)))
			;;
		"D")
			DATE=`date --date="$YEAR/$MONTH/$DAY ${ARG:1} days" "+%s"`
			DATE=$((DATE + (HOUR * 3600) + (MIN * 60)))
			;;
		"h")
			DATE=`date --date="$YEAR/$MONTH/$DAY $HOUR:$MIN" "+%s"`
			if [ "${ARG:1:1}" = "+" ]; then
				DATE=$((DATE + ${ARG:2} * 3600))
			else
				DATE=$((DATE - ${ARG:2} * 3600))
			fi
			;;
		"m")
			DATE=`date --date="$YEAR/$MONTH/$DAY $HOUR:$MIN" "+%s"`
			if [ "${ARG:1:1}" = "+" ]; then
				DATE=$((DATE + ${ARG:2} * 60))
			else
				DATE=$((DATE - ${ARG:2} * 60))
			fi
			;;
	esac
	DATE=`gawk -v DATE="$DATE" 'BEGIN {
		print strftime("%Y %m %d %H %M", DATE)
	}'`
}

# La date est convertie en UNIX time pour être passée en paramètre à strftime
function format_date() {
	split_datetime
	DATE=`date --date="$YEAR/$MONTH/$DAY $HOUR:$MIN" "+%s"`
	DATE=`gawk -v DATE="$DATE" 'BEGIN {
		print strftime("%Y-%m-%d_%H-%M", DATE)
	}'`
}

for FILE in *.jpeg *.jpg *.JPG *.JPEG; do

	# Pour ne pas traiter literalement *.jpg, *.jpeg, etc, si le répertoire est vide
	[ -e "$FILE" ] || continue

	# cut -d: -f3-	:	sépare les champs délimités par ':',
	#					et ne les garde qu'à partir du 3eme
	# sed 's/^ *//'	:	Supprime les espaces devant la date
	# sed 's/:/ /g'	:	Remplace les ':' par des espaces
	#					(pour traiter plus facilement la date par la suite)
	DATE=`identify -verbose $FILE | grep exif:DateTimeOriginal | cut -d: -f3- | sed 's/^ *//' | sed 's/:/ /g'`

	# Change la date et l'heure en fonction des arguments passés au script
	for ARG in $@; do
		change_datetime
	done

	# Transforme la date dans le format voulu
	format_date

	# ajoute "APN-" devant la date et stocke tout dans NAME
	NAME="APN-"$DATE""
	NAME_LEN=${#NAME}
	
	COUNT=1
	get_number

	# ajoute le compte, sur 3 chiffres, et précédé par un "-", à NAME
	NAME="$NAME-`printf "%03d" $COUNT`.jpg"
	echo $FILE =\> $DIR/$NAME

	# déplace le fichier en le renommant
	mv $FILE $DIR/$NAME
done

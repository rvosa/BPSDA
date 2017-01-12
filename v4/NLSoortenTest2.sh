#!/bin/sh
# Get input
NLSpeciesInput="$1"
customPrescence="$2"
allergenicSpecies="$3"
allergenicSpeciesExceptions="$4"
outPath="$5"

# # Test if variables come trough
# cat ${NLSpeciesInput} > ${outPath}
# echo "${customPrescence}" > ${outPath}
# cat ${allergenicSpecies} > ${outPath}
# cat ${allergenicSpeciesExceptions} > ${outPath}
 
# Modify input
# Personal note: this works!
NL_SPECIES=$(cat ${NLSpeciesInput} | tr "\n\r" "@" | awk -F "scientific_name;uninomial;specific_epithet;infra_specific_epithet;authorship;dutch_name;rank;nsr_id;presence_status;concept_url;rijk;phylum;klasse;orde;familie;genus;species" '{print $2}' | tr '@' '\n' | awk -F ';' 'BEGIN{OFS=";"}{print $11,$15,$2,$3,$4,$9}' | sed '/;;;;;/d' | sort)
# # To test if this works
# echo "${NL_SPECIES}" > ${outPath}

# Dutch species with given presence status codes are filtered (stay in list).
CODES=$(echo "${customPrescence}" | sed 's/[0-9]/;&/g' | tr 'X' '$' | tr -d ',' | sed 's/;/|;/g' | awk '{print ";"$0}' | sed 's/;|//g' | sed 's/|/$|/g' | tr -s "$" | awk '{print $0"$"}')
NL_SPECIES_FILTERED=$(echo -e "${NL_SPECIES}" | egrep "${CODES}" | sort) 
# # To test if this works
# echo "${NL_SPECIES_FILTERED}" > ${outPath}

# Write filtered Dutch species to file
echo "${NL_SPECIES_FILTERED}" > NL_SPECIES_FILTERED.txt
# # To test if this works
# cat NL_SPECIES_FILTERED.txt > ${outPath}


# oude zooi die misschien recycled kan worden
##################################################################################################################### 
# # inPath="$1"
# # outPath="$2"
# # length="$3"
# # multiplier="$4"
# # 
# # dingen=$(cat ${inPath})
# # dingen="${dingen}
# # mafkees"
# # dingen="${dingen}
# # ${length}"
# # dingen="${dingen}
# # ${multiplier}"
# # echo "${dingen}" > ${outPath}
# 
# 
# # ./bashTest.sh "test.txt" "uitvoer.txt" 45 67
# # Input in galaxy die is gescheiden door spaties, wordt gezien als het tweede argument.
# # Maar input variabelen zouden als het goed is geen spaties moeten hebben.
# # je moet bash file executable maken met "chmod +x <filenaam>"
###################################################################################################################### 

#echo -e "${allergenicSpecies}" > ALLERGENIC_SPECIES.txt


touch temp.txt
while read FILELINE
do
    # Everything is transformed to lowercase.
    KINGDOM=$(echo "$FILELINE" | awk -F ';' '{print $1}' | tr [A-Z] [a-z])
    FAMILY=$(echo "$FILELINE" | awk -F ';' '{print $2}' | tr [A-Z] [a-z])
    GENUS=$(echo "$FILELINE" | awk -F ';' '{print $3}' | tr [A-Z] [a-z])
    SPECIES=$(echo "$FILELINE" | awk -F ';' '{print $4}' | tr [A-Z] [a-z])
    SUBSPECIES=$(echo "$FILELINE" | awk -F ';' '{print $5}' | tr [A-Z] [a-z])

    # If there is no scientific name, then the occurance of the family must be checked.
    if [[ ${GENUS} == "" ]]
    then
        # Get the kingdom.
        PRESENT=$(cat NL_SPECIES_FILTERED.txt | egrep -i "^${KINGDOM} {0,}; {0,}${FAMILY} {0,}" | uniq  | awk -F ";" 'BEGIN{OFS=";"}{print $1,$2}' | awk 'NR==1{print $1}' | tr [A-Z] [a-z])
        # Check if substrig is found, instead of full correct string.
        if [[ ${PRESENT} =~ ^${KINGDOM}\ {0,}\;\ {0,}${FAMILY}\ {0,}$ ]]
        then
            echo "${FILELINE}" >> temp.txt
        fi
    
    # Bij sp. (species) geld dit voor alle soorten van dit genus.
    # Hier wordt dus gekeken of het genus in dat geval voorkomt.
    elif [[ ${SPECIES} == "sp." ]]
        then
        PRESENT=$(cat NL_SPECIES_FILTERED.txt | awk -F ";" '{print $3}' | tr -d " " | tr [A-Z] [a-z] | egrep -i "^${GENUS}$" | awk 'NR==1{print $1}')
        if [[ ${PRESENT} == ${GENUS} ]]
        then
            echo "${FILELINE}" >> temp.txt
        fi
    else
        # Controleren of subspecies voorkomt.
        # Deze if/else/elif constructie is niet zo netjes.....
        KINGDOM_GENUS_SPECIES_AND_POSSILBLE_SUBSPECIES=$(cat NL_SPECIES_FILTERED.txt | awk -F ';' 'BEGIN{OFS = ";"}{print $1,$3,$4,$5}' | tr [A-Z] [a-z] | egrep -i "${KINGDOM}\ {0,};\ {0,}${GENUS}\ {0,};\ {0,}${SPECIES}\ {0,}")
        if [[ ${KINGDOM_GENUS_SPECIES_AND_POSSILBLE_SUBSPECIES} != "" && ${SUBSPECIES} != "" ]]
        then
            PRESENT_SUBSPECIES=$(echo "${KINGDOM_GENUS_SPECIES_AND_POSSILBLE_SUBSPECIES}" | awk -F ";" '{print $4}' | tr -d ' ' | tr '\n' ' ')
            IFS=" " read -a PRESENT_SUBSPECIES_ARRAY <<< ${PRESENT_SUBSPECIES}
            case "${PRESENT_SUBSPECIES_ARRAY[@]}" in
                *"${SUBSPECIES}"*)
                    echo "${FILELINE}" >> temp.txt
                ;; 
            esac


        # Hier normaal controleren
        elif [[ ${KINGDOM_GENUS_SPECIES_AND_POSSILBLE_SUBSPECIES} != "" && ${SUBSPECIES} == "" ]]
        then
            STUB=$(echo "STUB")
            if [[ ${KINGDOM_GENUS_SPECIES_AND_POSSILBLE_SUBSPECIES} =~ ^${KINGDOM}\ {0,}\;\ {0,}${GENUS}\ {0,}\;\ {0,}${SPECIES} ]]
            then
                echo "${FILELINE}" >> temp.txt
            fi

        
        # Kijken of hij in uitzonderingenlijst zit.
        else
            EXCEPTION=$(cat "${allergenicSpeciesExceptions}" | egrep "${FILELINE}")
            if [[ ${EXCEPTION} == ${FILELINE} ]]
            then
                echo "${FILELINE}" >> temp.txt
            fi
        fi
    fi
done < "${allergenicSpecies}"
cat temp.txt > ${outPath}
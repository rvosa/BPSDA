#!/bin/sh

# In order to work, this script must be made executable (chmod +x <name of this script>)

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


touch DUTCH_ALLERGENIC.txt
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
            echo "${FILELINE}" >> DUTCH_ALLERGENIC.txt
        fi
    
    # Bij sp. (species) geld dit voor alle soorten van dit genus.
    # Hier wordt dus gekeken of het genus in dat geval voorkomt.
    elif [[ ${SPECIES} == "sp." ]]
        then
        PRESENT=$(cat NL_SPECIES_FILTERED.txt | awk -F ";" '{print $3}' | tr -d " " | tr [A-Z] [a-z] | egrep -i "^${GENUS}$" | awk 'NR==1{print $1}')
        if [[ ${PRESENT} == ${GENUS} ]]
        then
            echo "${FILELINE}" >> DUTCH_ALLERGENIC.txt
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
                    echo "${FILELINE}" >> DUTCH_ALLERGENIC.txt
                ;; 
            esac


        # Hier normaal controleren
        elif [[ ${KINGDOM_GENUS_SPECIES_AND_POSSILBLE_SUBSPECIES} != "" && ${SUBSPECIES} == "" ]]
        then
            STUB=$(echo "STUB")
            if [[ ${KINGDOM_GENUS_SPECIES_AND_POSSILBLE_SUBSPECIES} =~ ^${KINGDOM}\ {0,}\;\ {0,}${GENUS}\ {0,}\;\ {0,}${SPECIES} ]]
            then
                echo "${FILELINE}" >> DUTCH_ALLERGENIC.txt
            fi

        
        # Kijken of hij in uitzonderingenlijst zit.
        else
            EXCEPTION=$(cat "${allergenicSpeciesExceptions}" | egrep "${FILELINE}")
            if [[ ${EXCEPTION} == ${FILELINE} ]]
            then
                echo "${FILELINE}" >> DUTCH_ALLERGENIC.txt
            fi
        fi
    fi
done < "${allergenicSpecies}"
# # To test if this works
# cat DUTCH_ALLERGENIC.txt > ${outPath}

sort ${allergenicSpecies} DUTCH_ALLERGENIC.txt | uniq -u > DIFFERECE.txt
cat DIFFERECE.txt | awk '{print $0";no"}' > ALLERGENIC.txt
cat DUTCH_ALLERGENIC.txt | awk '{print $0";yes"}' >> ALLERGENIC.txt
sort ALLERGENIC.txt > ALLERGENIC_SORTED.txt
echo "Rijk;Familie;Genus;Soort;Ondersoort;Latijnse naam;Engelse populaire naam;Nederlandse populaire naam;Bron;TaxID;In Nederland" > Dutch_Allergens_Plants_Animals_Fungi.csv
cat ALLERGENIC_SORTED.txt | sed 's/Rijk;Familie;Genus;Soort;Ondersoort;Latijnse naam;Engelse populaire naam;Nederlandse populaire naam;Bron;TaxID;yes//g' | awk '{if ($0 != "") print $0}' >> Dutch_Allergens_Plants_Animals_Fungi.csv
# To test if this works
cat Dutch_Allergens_Plants_Animals_Fungi.csv > ${outPath}
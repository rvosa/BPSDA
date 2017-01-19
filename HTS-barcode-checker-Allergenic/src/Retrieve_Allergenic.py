#!/usr/bin/env python
# versie: 0.8
# datum: 19-1-2017

	# invoer uitvoer nog veranderen....
		# in openFile invoer aanpassen
	# Invoerbestand meegeven? Of wat is de locatie?

	# data aanpassen -> Wanneer is invoer laatst bewerkt? 
		# Tijd erbij zetten?

# Create a local database containing the hay fever appendices
# Database contains the hay fever species names and synonymes based on:
# and the species ncbi species taxon identifier

# import the modules used by this script
import argparse, logging, os, sys, urllib2, re, unicodedata, requests, time, csv

from Bio import Entrez

parser = argparse.ArgumentParser(description = 'Create a table containing the Hay fever species')

parser.add_argument('-db', '--Hay_fever_db', metavar='Hay fever database name', dest='db',type=str,
			help='Name and path to the location for the hay fever database', nargs='+')
parser.add_argument('-f', '--force', dest='f', action='store_true',
			help='Force updating the allergen database')
parser.add_argument('-l', '--logging', metavar='log level', dest='l', type=str,
			help = 'Set log level to: debug, info, warning (default) or critical see readme for more details.', default='warning')
parser.add_argument('-lf', '--log_file', metavar='log file', dest='lf', type=str,
			help = 'Path to the log file')

args = parser.parse_args()

def openFile():
	# opens file with allergen information

	logging.debug('Opening input data and making Allergen_dict')
	Allergen_list = []
	pat = "input_hay_fever.csv"	# location of the file with taxon names of allergen species
	with open(pat, 'rb') as csvfile:
		reader = csv.reader(csvfile, delimiter=',')		
		for line in reader:
			if line[0] == "Fungi" or line[0] == "Plantae" or line[0] == "Animalia":
				Allergen_list.append(line[1])
	logging.debug('data: %s' % Allergen_list)
	return Allergen_list


def local_hay_fever_data ():
	
	# open the local CITES database(s) to retrieve the date and path of output file
	results_dic = {}
	logging.debug('Hay fever files %s' % ' '.join(args.db))
	logging.debug('Trying to open the Allergen databases provided by the user.')
	for path in args.db:
		logging.debug('Trying to open Allergen database %s.' % path)
		try:
			for line in open(path, 'r'):
				line = line.rstrip().split(',')
				if line[0] == 'Date':
					results_dic['Date'] = line[1]
					results_dic['output'] = path
			if len(results_dic) == 0:
				logging.debug('No date found in Allergen database %s, new CITES copy will be writen to this location.' % path)
				results_dic['output'] = path
		except:
			logging.debug('Could not open Allergen database %s, new Allergen copy will be writen to this location.' % path)
			results_dic['output'] = path
	return results_dic

def TNRS (name):
	
	# Send the TNRS request
	logging.debug('Send TNRS request to server. %s' % name)
	TNRS_req = requests.get('http://resolver.globalnames.org/name_resolvers.json',
		params={'query':name}, allow_redirects=True)
	logging.debug('url: %s' % TNRS_req.url)		# Fout kan ook in de .url zitten
	redirect_url, time_count = TNRS_req.url, 0

	# send retrieve requests at 5 second intervals till
	# the api returns the JSON object with the results
	while redirect_url and time_count < 10:

		# Try to Download the JSON object with the TNRS results.
		try:
			retrieve_response = requests.get(redirect_url)
			retrieve_results = retrieve_response.json()
		except:
			retrieve_results = []
		
		# if the results contains the JSON object
		# retrieve all accepted names for the species
		# and return these
		if u'name_string' in retrieve_results[u'data'][0][u'results'][0].keys():
			logging.debug('Parsing TNRS results.')
			name_list = [name,[]]
			try:
				logging.debug(retrieve_results[u'data'])
				for lijst in retrieve_results[u'data']:
					for lijst_2 in lijst[u'results']:
						if lijst_2[u'data_source_title'] == 'NCBI':
							synonym = lijst_2[u'name_string']
							logging.debug('Synoniem gevonden: %s' % synonym)
							if synonym not in name and synonym != '':
								if ' ' in name:
									if len(synonym.split(' ')) >= len(name.split(' ')):
										name_list[1].append(str(synonym))
								else:
									if ' ' not in synonym:
										name_list[1].append(str(synonym))					
			except:
				pass

			# return the list with species names
			return name_list
		
		# time out before sending the new request
		# use a counter to keep track of the time, if there is
		# still no server reply the function will return an empty list
		time.sleep(5)
		time_count += 5

	logging.warning('Timeout for species %s.' % name)
	return [name,[]]


def get_taxid (species):

	# get taxon id based on species name (if not provided by TNRS search)

	# correct species name for parsing and set temp email
	Entrez.email = "HTS-barcode-checker@gmail.com"
	species = species.replace(' ', '+').strip()
	logging.debug('Search for species: %s.' % species)
	
	# Do a taxonomy search to determine the number of subtaxa
	# If there are more subtaxa then NCBI returns by default (20)
	# do a second search with the retmax parameter set to the 
	# expected number of taxa.
	try:
		# Connect to Entrez to obtain subtree size (species + ' [subtree]')
		search = Entrez.esearch(term = (species + ' [subtree]'), db = "taxonomy")
		record = Entrez.read(search)
		count = record['Count']
		logging.debug('Aantal gevonden IDs: %s' % count)
	
		
		# is subtree size exceeds 20 the entire tree needs to be redownloaded
		if count > 20:
			search = Entrez.esearch(term = (species + ' [subtree]'), db = "taxonomy", retmode = "xml", retmax = count)
			record = Entrez.read(search)
		

		# if the tree isnt empty, return the taxon ID list.
		if record[u'IdList'] != []:
			return record[u'IdList']
	except:
		pass

	return ['empty']

def obtain_tax (taxid):

	organism = ''

	# based on the taxid the species and taxonomy are retrieved from the Entrez database
	try:
		Entrez.email = "CITES_check@gmail.com"
		search = Entrez.efetch(db="taxonomy", id= taxid, retmode="xml")
		record = Entrez.read(search)
		organism = '\"' + record[0]['ScientificName'] + '\"'
		handle.close()
	except:
		pass

	return organism


def combine_sets (hay_fever_list):

	# Expand the hay fever information with TNRS synonyms and Taxonomic IDs

	# parse through the different hay fever appendixes and
	# and try to retrieve the TNRS synonyms and NCBI Taxonomic IDs
	# for each species

	taxon_id_dic, hay_fever_length, failed = {}, len(hay_fever_list), 0
	total = hay_fever_length

	logging.info('Total number of hay fever entries: %i.' % hay_fever_length)
	for cell in hay_fever_list:
		logging.debug("Searching for species: %s" % cell)
		# create a list of all lower taxon id's
		temp_name, temp_taxon_list, count = cell.replace(' sp.',''), ['empty'], 0

			
		# break when a cell turns out to be empty			
		if temp_name == '' or temp_name == ' ': 
			failed += 1
			continue			

		# grab the TAXON IDs for the species name
		while temp_taxon_list[0] == 'empty' and count <= 20:
			temp_taxon_list = get_taxid(temp_name)
			count += 1

		if temp_taxon_list[0] == 'empty': 
			logging.warning('No taxon ID found for: %s.' % temp_name)
			failed += 1

		# if no TAXON ID was found for the name
		# check if taxon IDs can be obtained for
		# the species synonyms
		if temp_taxon_list[0] == 'empty':
			logging.debug('Looking for synonym species: %s.' % temp_name)
			temp_taxon_list = []
			TNRS_data = TNRS(temp_name)
			if len(TNRS_data[1]) > 0:
				for name in TNRS_data[1]:
					count, temp_tnrs = 0, ['empty']
					while temp_tnrs[0] == 'empty' and count <= 20:
						temp_tnrs = get_taxid(name)
						count += 1
					if temp_tnrs[0] != 'empty': 
						temp_taxon_list += temp_tnrs

				# print the synomyms for who a taxon id could be found
				if len(temp_taxon_list) > 0: 
					logging.debug('Synonym found for %s, taxon ID(s) = %s.' % (temp_name, ' '.join(temp_taxon_list)))
			
		if temp_taxon_list == []: 
			logging.critical('No synonym found for: %s.' % temp_name)
			failed += 1

		# expand the taxon_id_dic with the taxid's as
		# keys and the hay fever species / hay fever cell and 
		# taxid linked species as values
		for taxid in temp_taxon_list:		
			if taxid in taxon_id_dic:
				if appendix > int(taxon_id_dic[taxid][2]): continue
			

			taxon_id_dic[taxid] = [cell,obtain_tax(taxid)]

		# print the number of remaining CITES entries to process
		hay_fever_length -= 1
		logging.debug('%i hay fever entries remaining' % hay_fever_length)
			
		# Failed is te hoog. failed+=1 voor taxid en TNRS
		logging.info('No taxon ID found for %i out of the %i species' % (failed, total))	
	
	return taxon_id_dic
			

def write_csv (date, taxon_id_dic, file_path):

	# write the CITES results to the database
	logging.debug('Writing Allergen results to %s.' % file_path)
	db = open(file_path, 'w')
	db.write('#Date of last update:\nDate,' + date + '\n#taxon id,Allergen species,taxon species\n')
	for taxid in taxon_id_dic:
		db.write(','.join([taxid] + taxon_id_dic[taxid]) + '\n')
	db.close()
			

def main ():

	# set log level
	log_level = getattr(logging, args.l.upper(), None)
	log_format = '%(funcName)s [%(lineno)d]: %(levelname)s: %(message)s'
	if not isinstance(log_level, int):
		raise ValueError('Invalid log level: %s' % loglevel)
		return
	if args.lf == '':
		logging.basicConfig(format=log_format, level=log_level)
	else:
		logging.basicConfig(filename=args.lf, filemode='a', format=log_format, level=log_level)
		# Data hier aanpassen naar laatste wijziging input file ( hay-fever-list )
	data = "2-11-2016"

	# try to open the hay fever database and check if the current version
	# (if there is one) is up to date
	file_data = local_hay_fever_data()
	for i in file_data:
		logging.debug('Hay fever files %s - path %s' % (i, file_data[i]))
	output_path = file_data['output']
	logging.debug('Test if the current version of the hay fever database is up to date.')
	try:
		if data == file_data['Date'] and args.f != True:
			logging.info('Local hay fever database is up to data.')
			return
	except:
		pass

	logging.info('Downloading new copy of hay fever database.')

	# Opening hay fever input file
	hay_fever_dict = openFile()

	# use TNRS to grab the species synonyms and
	# taxid if available. Expand the taxids with 
	# taxids from lower ranked records
	logging.debug('Get taxon IDs for hay fever species.')
	taxon_id_dic = combine_sets(hay_fever_dict)

	# write the results to the output location
	logging.debug('Write hay fever info to output file %s.' % output_path)
	write_csv(data, taxon_id_dic, output_path)


if __name__ == "__main__":
	main()


#!/usr/bin/env python3

import cgi
import cgitb

import sys
import json
import base64

import MySQLdb

# TODO: get these from a config file.
db = MySQLdb.connect(
	host="HOSTNAME",
	user="USERNAME",
	passwd="PASSWORD",
	db="DATABASE")

# Removes everything but alphanumerics and ".""
def sanitize(in_string):
	return ''.join([x for x in in_string if \
		x.isalpha() or x.isnumeric() or x == '.'])

# TODO: Get parameters and sanitize them.
# If filename is TOWN.HI, read the file on disk and return it.
# Otherwise, or in the case of exceptions, return {} or a blank data entry.

def main(parameters):
	print('Content-Type: application/json\r\n\r\n', end='')
	
	try:
		filename = parameters["filename"].value

		# No absurdly long file names, please.
		if len(filename) > 12:
			raise ValueError("Filename too long")

		if filename != sanitize(filename):
			raise ValueError("Improperly formatted filename")

		# Prepare our return values.

		file_data = { "filename": filename, "value": "" }

		canonical_filename = filename.lower()

		if canonical_filename == "town.hi":
			contents = open("town.hi", "rb").read()

			encoded_contents = base64.b64encode(contents).decode("ascii")
			file_data["value"] = encoded_contents

		print(json.dumps(file_data))
		return

	except Exception as e:
		# Don't reveal what kind of exception was raised. No need to
		# help the hackers.
		print("{}")
		return

cgitb.enable() # for debugging
parameters = cgi.FieldStorage()

main(parameters)
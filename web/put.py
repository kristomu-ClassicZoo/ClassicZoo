#!/usr/bin/env python3

import cgi
import cgitb

import sys
import json
import base64

# Removes everything but alphanumerics and ".""
def sanitize(in_string):
	return ''.join([x for x in in_string if \
		x.isalpha() or x.isnumeric() or x == '.'])

def main():
	print('Content-Type: text/html\r\n\r\n', end='')
	
	try:
		data = sys.stdin.buffer.read()
		buf = json.loads(data)

		filename = buf["filename"]

		# No absurdly long file names, please.
		if len(filename) > 12:
			return

		if filename != sanitize(filename):
			return

		canonical_filename = filename.lower()
		encoded_contents = buf["value"]
		contents = base64.b64decode(encoded_contents)

		print(f'Filename is {canonical_filename}<br>')
		print(f'Length of contents: {len(contents)}')

		#if canonical_filename[-3:] == ".hi":
		#	open(canonical_filename, "wb").write(contents)
		#	print(f'Would have saved to file or database here.')

		print("Okay")

	except KeyError as e:
		# Don't reveal what kind of exception was raised. No need to
		# help the hackers.
		return

cgitb.enable() # for debugging
main()
# Copyright (c) 2021 Adrian Siekierka
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#!/usr/bin/env python3
from struct import unpack
import os, sys

f = open(sys.argv[1], 'rb')
hdr_magic, hdr_version = unpack('<HH', f.read(4))
extra_ticks = 0

if hdr_magic != 0xD327:
	print("Invalid magic!")
elif hdr_version != 0x0001:
	print("Invalid version!")
else:
	f.seek(0, os.SEEK_END)
	f_end = f.tell()
	f.seek(26)
	while f.tell() != f_end:
		fpos = f.tell()
		cmd_type = unpack('<B', f.read(1))[0]
		if cmd_type == 0:
			count, delta_x, deltaY, shift_pressed, key_pressed = unpack('<hbbBB', f.read(6))
			print(f"- [{fpos}] Input: {count} x {delta_x},{deltaY}; shift={shift_pressed}, key={key_pressed}")
		elif cmd_type == 1:
			tickSpeed = unpack('<h', f.read(2))[0]
			print(f"- [{fpos}] Tick speed: {tickSpeed}")
		elif cmd_type == 2:
			rand_seed = unpack('<I', f.read(4))[0]
			print(f"- [{fpos}] Random seed: {rand_seed}")
		elif cmd_type == 3:
			print(f"- [{fpos}] Game start")
		elif cmd_type == 4:
			pit_ticks = unpack('<H', f.read(2))[0]
			print(f"- [{fpos}] PIT ticks +{pit_ticks}")
			extra_ticks += pit_ticks
		else:
			print(f"Unknown command type {cmd_type}!")

f.close()

print(f"Sum of extra PIT ticks = {extra_ticks}")

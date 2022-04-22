@echo off

if not exist BIN mkdir BIN
del BIN\*.*

if not exist DIST mkdir DIST
del DIST\*.*

cd DIST
if not exist FIXDEMO mkdir FIXDEMO
del FIXDEMO\*.*
cd ..

echo.
echo [ Building ZZT.EXE ]
echo.
TPC /B /EBIN /GD /ISRC_F10 /USRC_F10 SRC_F10\ZZT.PAS
if errorlevel 1 goto error
echo.
echo [ Compressing ZZT.EXE ]
echo.
cd BIN
..\TOOLS\UPX.EXE --8086 ZZT.EXE
cd ..

echo.
echo [ Creating DIST/ ]
echo.

copy BIN\ZZT.EXE DIST\ZZT.EXE
copy BIN\ZZT.DAT DIST\ZZT.DAT
copy LICENSE.TXT DIST\LICENSE.TXT
copy README.TXT DIST\README.TXT
copy HOWTO.TXT DIST\HOWTO.TXT
copy SRC_F10\FIXWEAVE.CFG DIST\FIXWEAVE.CFG
copy SRC_F10\FIXWEAVE.INI DIST\FIXWEAVE.INI
copy DEMO.ZZT DIST\FIXDEMO\DEMO.ZZT
copy DEMO.INI DIST\FIXDEMO\DEMO.INI
copy DEMO.CFG DIST\FIXDEMO\DEMO.CFG
copy DEMO.0 DIST\FIXDEMO\DEMO.0
copy DEMO.1 DIST\FIXDEMO\DEMO.1
copy FIXDEMO.OBJ DIST\FIXDEMO\FIXDEMO.OBJ

goto done
:error
echo.
echo [ Error detected! Stopping. ]
:done
copy DIST\ZZT.EXE DIST\FIXW10.EXE
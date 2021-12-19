@echo off

if not exist BIN mkdir BIN
del BIN\*.*

if not exist DIST mkdir DIST
del DIST\*.*

cd DIST
if not exist SOFTDEMO mkdir SOFTDEMO
del SOFTDEMO\*.*
cd..

echo.
echo [ Building DATPACK.EXE ]
echo.
TPC /B /EBIN TOOLS\DATPACK.PAS
if errorlevel 1 goto error
echo.
echo [ Building ZZT.DAT ]
echo.
cd DOC
..\BIN\DATPACK.EXE /C ..\BIN\ZZT.DAT *.*
if errorlevel 1 goto error
cd ..

echo.
echo [ Building ZZT.EXE ]
echo.
TPC /B /EBIN /GD /ISRC_W20 /USRC_W20 SRC_W20\ZZT.PAS
if errorlevel 1 goto error
echo.
echo [ Compressing ZZT.EXE ]
echo.
cd BIN
..\TOOLS\LZEXE.EXE ZZT.EXE
cd ..

echo.
echo [ Creating DIST/ ]
echo.

copy BIN\ZZT.EXE DIST\ZZT.EXE
copy BIN\ZZT.DAT DIST\ZZT.DAT
copy LICENSE.TXT DIST\LICENSE.TXT
copy README.TXT DIST\README.TXT
copy SRC_W20\BLUEDRGN.PAR DIST\BLUEDRGN.PAR
copy SRC_W20\TEMPLATE.CFG DIST\TEMPLATE.CFG
copy SRC_W20\TEMPLATE.PAR DIST\TEMPLATE.PAR
copy SRC_W20\SOFTDEMO.CFG DIST\SOFTDEMO\SOFTDEMO.CFG
copy SRC_W20\SOFTDEMO.PAR DIST\SOFTDEMO\SOFTDEMO.PAR
copy SOFTDEMO.ZZT DIST\SOFTDEMO\SOFTDEMO.ZZT

goto done
:error
echo.
echo [ Error detected! Stopping. ]
:done
copy DIST\ZZT.EXE DIST\SWEAVE20.EXE

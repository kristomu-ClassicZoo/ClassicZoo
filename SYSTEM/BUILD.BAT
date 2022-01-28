@echo off

echo [ Building BIN2PAS.EXE ] >> BUILD.LOG
TPC /B /Q /EBUILD TOOLS\BIN2PAS.PAS >> BUILD.LOG
if errorlevel 1 goto error

echo [ Converting ASCII.CHR ] >> BUILD.LOG
BUILD\BIN2PAS SRC\ASCII.CHR SRC\F_ASCII.PAS F_ASCII >> BUILD.LOG
if errorlevel 1 goto error

echo [ Building DATPACK.EXE ] >> BUILD.LOG
TPC /B /Q /EBUILD TOOLS\DATPACK.PAS >> BUILD.LOG
if errorlevel 1 goto error

echo [ Building %ENGINE%.DAT ] >> BUILD.LOG
cd DOC
..\BUILD\DATPACK.EXE /C ..\BUILD\%ENGINE%.DAT *.* >> ..\BUILD.LOG
if errorlevel 1 goto error
cd ..

echo [ Building %ENGINE%.EXE ] >> BUILD.LOG
TPC /B /Q /EBUILD /GD /ISRC /USRC %COMPARGS% SRC\ZZT.PAS >> BUILD.LOG
if errorlevel 1 goto error
goto done

:error
echo.
echo [ Error detected! Stopping. ]
:done
exit

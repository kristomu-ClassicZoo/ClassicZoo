@echo off

echo [ Building BIN2PAS.EXE ] >> BUILD.LOG
TPC /B /Q /EBUILD TOOLS\BIN2PAS.PAS >> BUILD.LOG
if errorlevel 1 goto error

echo [ Converting ASCII.CHR ] >> BUILD.LOG
BUILD\BIN2PAS SRC\ASCII.CHR SRC\F_ASCII.PAS F_ASCII >> BUILD.LOG
if errorlevel 1 goto error

echo [ Building ZZT.DAT ] >> BUILD.LOG
cd DOC
..\BUILD\DATPACK.EXE /C ..\BUILD\ZZT.DAT *.* >> BUILD.LOG
if errorlevel 1 goto error
cd ..
goto done

:error
echo.
echo [ Error detected! Stopping. ]
:done
exit

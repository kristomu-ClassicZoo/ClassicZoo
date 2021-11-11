@echo off

echo [ Converting screens ] >> BUILD.LOG

BUILD\CSIPACK /C SCREENS\M_FOREST.BIN BUILD\M_FOREST.CSI >> BUILD.LOG
if errorlevel 1 goto error
BUILD\BIN2PAS BUILD\M_FOREST.CSI SRC\M_FOREST.PAS >> BUILD.LOG
if errorlevel 1 goto error
BUILD\CSIPACK /C SCREENS\M_MONSTE.BIN BUILD\M_MONSTE.CSI >> BUILD.LOG
if errorlevel 1 goto error
BUILD\BIN2PAS BUILD\M_MONSTE.CSI SRC\M_MONSTE.PAS >> BUILD.LOG
if errorlevel 1 goto error
BUILD\CSIPACK /C SCREENS\M_PROVIN.BIN BUILD\M_PROVIN.CSI >> BUILD.LOG
if errorlevel 1 goto error
BUILD\BIN2PAS BUILD\M_PROVIN.CSI SRC\M_PROVIN.PAS >> BUILD.LOG
if errorlevel 1 goto error
BUILD\CSIPACK /C SCREENS\S_CONFIG.BIN BUILD\S_CONFIG.CSI >> BUILD.LOG
if errorlevel 1 goto error
BUILD\BIN2PAS BUILD\S_CONFIG.CSI SRC\S_CONFIG.PAS >> BUILD.LOG
if errorlevel 1 goto error

echo [ Building SUPERZ.DAT ] >> BUILD.LOG
cd DOC
..\BUILD\DATPACK.EXE /C ..\BUILD\SUPERZ.DAT *.* >> BUILD.LOG
if errorlevel 1 goto error
cd ..
goto done

:error
echo.
echo [ Error detected! Stopping. ]
:done
exit

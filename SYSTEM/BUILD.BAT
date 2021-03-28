@echo off

echo [ Building ZZT.EXE ] >> BUILD.LOG
TPC /B /Q /EBUILD /GD /ISRC /USRC %COMPARGS% SRC\ZZT.PAS >> BUILD.LOG
if errorlevel 1 goto error
goto done

:error
echo.
echo [ Error detected! Stopping. ]
:done
exit

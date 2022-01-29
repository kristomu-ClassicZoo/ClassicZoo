# DEVDOC - Readme

## Compilation instructions

To compile ClassicZoo, you're going to need:

* A Linux-based environment,
* DOSBox,
* At least one of:
    * Turbo Pascal 5.5 (can be found online via Embarcadero),
    * Free Pascal's 8086 cross-compiler variant,
* (optional) UPX for compressing EXEs.

You might need to edit the following files:

* build.properties - branding information (name, version, copyright string),
* build.releases - compilation flags for each build (Free Pascal, PC-98, etc).

If you wish to use Turbo Pascal 5.5, put an installation on it in `VENDOR/TP`, in a way so that `VENDOR/TP/TPC.EXE` is the Turbo Pascal 5.5 compiler executable.

If you wish to use Free Pascal, set the `FPC_PATH` environment variable to point to the directory Free Pascal is in, so that `$FPC_PATH/bin/ppcross8086` is the Free Pascal cross-compiler executable.

From there, simply run `./build.sh`, and the compilation process should begin.

### Common errors

* `TIMERSYS.PAS(31,7) Fatal: Can't find unit SDL2 used by TimerSys`
   * `git submodule init && git submodule update`

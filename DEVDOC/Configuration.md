# DevDocs - Configuration

## build.properties

This file is a key-value list used for populating branding information in the executable.
Any field given in it will have all occurences of `%FIELD_NAME%` replaced with
the given value. Currently used fields are:

* NAME - program name,
* VERSION - program version.

Other locations which include branding information are:

* DOC/ABOUT.HLP (name, version, release date),
* DOC/LICENSE.HLP (copyright).

## build.releases

This file is used to configure `make.sh` when ran in series to produce a release by `build.sh`.
It's a list of parameters passed to `make.sh`, which can be as follows:

### -a: architecture

This option takes a quadruplet (for example `tp55-i8086-msdos-dos`) with the following components:

* compiler - `tp55` or `fpc`
* architecture - `native`, `i8086`, `m68k`, `i386`, `x86_64`, `arm`
* platform - based on Free Pascal target strings; `msdos`, `win32`, `win64`, `linux`, `amiga`
* platform unit - the subdirectory ; `basic`, `dos`, `nec98`, `sdl2`

For Free Pascal, this also involves loading configuration files of the format `SYSTEM/architecture.platform.platform_unit.cfg`.
Any of the three components can be replaced with "any" as a wildcard.

### -d: define flags

This option accepts define flags to be used during the compilation process. It can be specified multiple times.
Please refer to the define flags list in the document for a list of supported values.

### -e: executable name

This option sets the output executable name.

### -g: debug build

This option enables a debug build. This is particularly useful for Free Pascal, as it embeds gdb/line info information in the executable.

### -n: engine

This option selects an engine - `ZZT` by default - with the following effects:

* The E_engine define is set,
* The E_engine directory is included in the compilation path,
* Occurences of `%ENGINE%` in the code are replaced with the engine name,
* The .DAT file is renamed to engine.DAT.

Currently, `ZZT` and `SUPERZ` are the supported engine names. 

### -o: output archive filename

This option sets the output ZIP name, by default `zoo-compiler-arch-platform-platform_unit.zip`, where `compiler` is `fpc` or `tpc`.

### -p: build.properties file

This option sets the build.properties file used, by default `build.properties`.

### -r: disable cleanup

This option ensures that the temporary directory in /tmp is not removed upon a successful compilation.

## Define flags

### Internal

### User-provided

* `DEBUGWND` - Enable debugging-related text windows. This also gates some more advanced debugging functionality.
* `EDITOR` - Enable the editor.
* `EXTCHEAT` - Enable additional cheats which take up more binary space.
* `FASTVID` - Enable controlling window/board transition speed, complete with optimized short paths for when they're set to "instant".
* `MEMBOUND` - Enable memory bound checks. Not guaranteed to be exhaustive. This is meant to be used on platforms which actually have proper memory access checks, like Windows/Linux.
* `NODIRS` - Disable subdirectory support.
* `PRINTTXT` - Enable printing text window contents.
* `RAWMEM` - Read from/write to packed data structures directly. This saves binary size and CPU time, at the cost of enforcing unaligned code generation.
  As such, it is primarily used on DOS.
* `ZETAEMU` - Enable custom routines for better supporting the Zeta emulator.

### User-provided, platform-specific

* `AUD16BIT` (SDL2) - Enable 16-bit audio code instead of 8-bit.
* `BASICSYS` (Basic) - Using the Basic platform, which adds certain custom video calls (Lock/UnlockScreenUpdate) to handle its framebuffer.
* `PLAYSTEP` (DOS) - Enable the player stepping sound.

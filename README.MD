# Weave ZZT 2.7

Unlike previous versions of Weave, this version really is meant to be the forever version.

Designed with the full scope of the ZZTer audience in mind, this version hopes to supply the needs of anyone that wants to tweak something about ZZT. Weave version 2 makes extensive use of accessory files to allow ZZTers to enhance their game's experience without diving into the Pascal code.

## Using

The DOS executables provided in BIN are already ready to take on ZZT. With your own copy of Turbo Pascal 5.5, you can compile both executables yourself using the BUILDW27.BAT files provided in the different subdirectories.

## SOFT and FIRM weaves

There are two directory structures in the project, one for SOFT and one for FIRM weaving. 

"Soft" weaving is for making cosmetic and numeric changes to ZZT without changing the code, and uses .CFG and .PAR accessory files to allow players to customize the experience per ZZT world.

"Firm" weaving is for adding a few additional functions, conditionals, directions, colors, and other beneficial changes to ZZT while using the same code pathways as the original EXE. By adding this additional limitation of using only existing code pathways, the system remains sufficiently constrained to keep "ZZT Feel" while adding quality-of-life enhancements for the developer and a few new options for gameplay.

## File types in this project:

There are a few different kinds of files found in this project:

* PAS files
    * These are Turbo Pascal 5.5 source files for Weave.
* CFG files contain:
    * Custom strings.
    * Custom sounds.
    * Custom colors.
    * Custom element parameters.
    * Custom game settings.
* INI files contain:
    * Custom flags and counters.
    * Custom keybinds.
* BAT files
    * These are used to compile Weave in DOS or DOSBox.
* TXT and DOC files
    * These are documents designed to be shipped with Weave.
* OBJ files
    * These are ZZT-OOP code to be loaded into objects.
* ZZT files
    * These are the demonstrative ZZT worlds for Weave.
* EXE files
    * SWEAVE20 and FWEAVE20 are the Weave ZZT executables.
    * LZEXE is the tool used to compress the weave EXEs.

## Files in this project:

Below are listed the files in the various folders of the project.

### SOFT_W26 directory

* DOC
    * ABOUT.HLP
        * for a minimal ZZT.DAT.
* TOOLS
    * DATPACK.PAS, etc.
        * For making ZZT.DAT and shrinking ZZT.EXE.
* SRC_W26
    * ALL .PAS FILES (ELEMENTS.PAS, EXTMEM.PAS, etc.)
        * Forked from the ZZT Reconstruction and ClassicZoo.
        * Reconstruction: github.com/asiekierka/reconstruction-of-zzt
        * ClassicZoo: github.com/OpenZoo/ClassicZoo
    * BLUEDRGN.CFG
        * "Blue Dragon Mode" parameters file.
    * SOFTDEMO.CFG
        * Parameters for the SoftWeave demo.
    * TEMPLATE.CFG
        * Basic parameters file with common options.
    * EXTENDED.CFG
        * Extended parameters file with more options.
* BUILDW26.BAT
    * Used in DOS or DOSBox to build SoftWeave from source.
* LICENSE.TXT
    * MIT License, required by reconstruction-of-zzt.
* README.TXT
    * A brief explanation of Soft Weaving.
* SOFTDEMO.ZZT
    * The SoftWeave demo file.

### FIRM_W27 directory

* TOOLS
    * LZEXE.EXE, LZEXE.DOC
        * For shrinking ZZT.EXE.
* SRC_W27
    * ALL .PAS FILES (ELEMENTS.PAS, EXTMEM.PAS, etc.)
        * Forked from the ZZT Reconstruction and ClassicZoo.
        * Reconstruction: github.com/asiekierka/reconstruction-of-zzt
        * ClassicZoo: github.com/OpenZoo/ClassicZoo
    * EXAMPLE.OBJ
        * Example object used in the FirmWeave demo.
    * ANGRY.OBJ, GREET.OBJ
        * Appended code used in the FirmWeave demo.
    * BEARBUL.OBJ, WONKY.OBJ
        * Custom bullets from the FirmWeave demo.
    * FIRMDEMO.CFG
        * Element parameters for the FirmWeave demo.
    * TEMPLATE.CFG
        * Basic parameters file with common options.
    * EXTENDED.CFG
        * Extended parameters file with more options.
    * FIRMDEMO.INI
        * Counters and Keybinds for the FirmWeave demo.
    * TEMPLATE.INI
        * Standard Counters and Keybinds template file.
* BUILDW27.BAT
    * Used in DOS or DOSBox to build FirmWeave from source.
* LICENSE.TXT
    * MIT License, required by reconstruction-of-zzt.
* README.TXT
    * A brief explanation of Firm Weaving.
* FIRMDEMO.ZZT
    * The FirmWeave demo file.

### BIN directory

The completed releases as compiled by the above are provided here in the SOFT and FIRM directories.

## Questions

Hit me up in the ZZT Discord if you've got feedback or there's something to add. I'm not married to anything here so if there's a better way to do something, or you REALLY have to have like, breakable linewalls or walkable ricochets or something like that, Later versions of Weave could open that up. If you want to be able to create your own custom elements from accessory files, you're not alone. HardWeave and FixWeave both have specs and are in development, providing the more hardcore modders with the extensible element platform of their dreams.

Discord of ZZT Link: museumofzzt dot com slash discord

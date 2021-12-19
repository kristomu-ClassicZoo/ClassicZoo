# Weave ZZT 2.0

Unlike previous versions of Weave, this version really is meant to be the forever version.

Designed with the full scope of the ZZTer audience in mind, this version hopes to supply the needs of anyone that wants to tweak something about ZZT. Weave version 2 makes extensive use of accessory files to allow ZZTers to enhance their game's experience without diving into the Pascal code.

## Using

The DOS executables provided in BIN are already ready to take on ZZT. With your own copy of Turbo Pascal 5.5, you can compile both executables yourself using the BUILDW20.BAT files provided in the different subdirectories.

## SOFT and FIRM weaves

There are two directory structures in the project, one for SOFT and one for FIRM weaving. 

"Soft" weaving is for making cosmetic and numeric changes to ZZT without changing the code, and uses .CFG and .PAR accessory files to allow players to customize the experience per ZZT world.

"Firm" weaving is for adding a few additional functions, conditionals, directions, colors, and other beneficial changes to ZZT while using the same code pathways as the original EXE. By adding this additional limitation of using only existing code pathways, the system remains sufficiently constrained to keep "ZZT Feel" while adding quality-of-life enhancements for the developer and a few new options for gameplay.

## File types in this project:

There are a few different kinds of files found in this project:

* PAS files
    * These are Turbo Pascal 5.5 source files for WeaveZZT.
* CFG files
    * These are custom string and sound files for ZZT worlds.
* PAR files
    * These are custom color and parameter files for ZZT worlds.
* OOP files
    * These are custom command files for ZZT worlds.
* FLG files
    * These list custom flags and counters for ZZT worlds.
* KB files
    * These list custom keybinds for ZZT worlds.
* BAT files
    * These are used to compile WeaveZZT in DOS or DOSBox.
* TXT and DOC files
    * These are documents designed to be shipped with Weave.
* OBJ files
    * These are ZZT-OOP code to be loaded into objects.
* ZZT files
    * These are the demonstrative ZZT worlds for Weave./
* EXE files
    * SWEAVE20 and FWEAVE20 are the Weave ZZT executables.
    * LZEXE is the tool used to compress the weave EXEs.

## Files in this project:

Below are listed the files in the various folders of the project.

### SOFT_W20 directory

* DOC
    * ABOUT.HLP
        * for a minimal ZZT.DAT.
* TOOLS
    * DATPACK.PAS, etc.
        * For making ZZT.DAT and shrinking ZZT.EXE.
* SRC_W20
    * ALL .PAS FILES (ELEMENTS.PAS, EXTMEM.PAS, etc.)
        * Forked from the ZZT Reconstruction and ClassicZoo.
        * Reconstruction: github.com/asiekierka/reconstruction-of-zzt
        * ClassicZoo: github.com/OpenZoo/ClassicZoo
    * BLUEDRGN.PAR
        * "Blue Dragon Mode" parameters file.
    * SOFTDEMO.CFG
        * Strings and sounds for the SoftWeave demo.
    * SOFTDEMO.PAR
        * Colors and parameters for the SoftWeave demo.
    * TEMPLATE.CFG
        * Base string and sound file for new Weavers.
    * TEMPLATE.PAR
        * Base color and parameter file for new Weavers.
* BUILDW20.BAT
    * Used in DOS or DOSBox to build SoftWeave from source.
* LICENSE.TXT
    * MIT License, required by reconstruction-of-zzt.
* README.TXT
    * A brief explanation of Soft Weaving.
* SOFTDEMO.ZZT
    * The SoftWeave demo file.

### FIRM_W20 directory

* DOC
    * ABOUT.HLP
        * for a minimal ZZT.DAT.
* TOOLS
    * DATPACK.PAS, etc.
        * For making ZZT.DAT and shrinking ZZT.EXE.
* SRC_W20
    * ALL .PAS FILES (ELEMENTS.PAS, EXTMEM.PAS, etc.)
        * Forked from the ZZT Reconstruction and ClassicZoo.
        * Reconstruction: github.com/asiekierka/reconstruction-of-zzt
        * ClassicZoo: github.com/OpenZoo/ClassicZoo
    * EXAMPLE.OBJ
        * Example object used in the FirmWeave demo.
    * WONKY.OBJ
        * Example custom bullet from the FirmWeave demo.
    * FIRMDEMO.CFG
        * Strings and sounds for the FirmWeave demo.
    * FIRMDEMO.PAR
        * Colors and parameters for the FirmWeave demo.
    * FIRMDEMO.KB
        * Custom keybinds for the FirmWeave demo.
    * FIRMDEMO.FLG
        * Custom flags and counters for the FirmWeave demo.
    * TEMPLATE.CFG
        * Base string and sound file for new Weavers.
    * TEMPLATE.PAR
        * Base color and parameter file for new Weavers.
    * TEMPLATE.OOP
        * Base custom command file for new Weavers.
    * EXTENDED.OOP
        * Fully enabled commands for confident Weavers.
    * TEMPLATE.KB
        * Base Keybinds file for new Weavers.
    * TEMPLATE.FLG
        * Base flags and counters file for new Weavers.
* BUILDW20.BAT
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

Hit me up in the ZZT Discord if you've got feedback or there's something to add. I'm not married to anything here so if there's a better way to do something, or you REALLY have to have like, breakable linewalls or walkable ricochets or something like that, Weave 2.1 could open that up. If you want to be able to create your own custom elements from accessory files, you're not alone. HardWeave will be packaged with 2.1 and give you the extensible element platform of your dreams.

Discord of ZZT Link: discord dot com slash invite slash Nar4Upf
# WeaveZZT 2.8

Unlike previous versions of Weave, this version really is meant to be the forever version.

Designed with the full scope of the ZZTer audience in mind, this version hopes to supply the needs of anyone that wants to tweak something about ZZT. Weave 2 makes extensive use of accessory files to allow ZZTers to enhance their game's experience without diving into the Pascal code.

## Using

The DOS executables provided in BIN are already ready to take on ZZT. With your own copy of Turbo Pascal 5.5, you can compile both executables yourself using the BUILDW28.BAT files provided in the different subdirectories.

## Types of weaving

There are two primary types of weaving. WeaveZZT 2.8 supports both.  They are referred to as "Soft" and "Firm" weaving.

"Soft" weaving is for making cosmetic and numeric changes to ZZT without changing the code. To "Soft" weave, you will use a .CFG file, examples of which are included in this repository.

"Firm" weaving adds functions, conditionals, directions, colors, and other beneficial changes to ZZT. To "Firm" weave, you will use .CFG, .INI, and sometimes .OBJ files, examples of which are all included with this repository.

## File types in this project:

There are a few different kinds of files found in this project:

* PAS files:
    * The Turbo Pascal 5.5 source files for Weave.
* CFG files:
    * Custom strings.
    * Custom sounds.
    * Custom colors.
    * Custom element parameters.
    * Custom game settings.
    * WEAVEZZT.CFG includes custom startup behavior.
* INI files:
    * Custom flags and counters.
    * Custom keybinds.
* BAT files:
    * Used to compile Weave in DOS or DOSBox.
* TXT, DOC, and HTM files:
    * Documents designed to be shipped with Weave.
* OBJ files:
    * ZZT-OOP code to be loaded into objects.
* ZZT files
    * Demonstration ZZT worlds for Weave.
* EXE files
    * WEAVE28 is the Weave ZZT executable.
    * LZEXE is the tool used to compress the weave EXE.

## Files in this project:

Below are listed the files in the various folders of the project.

### WEAVE_28 directory

* TOOLS
    * LZEXE.EXE, LZEXE.DOC
        * For shrinking ZZT.EXE.
* SRC_W28
    * ALL .PAS FILES (ELEMENTS.PAS, EXTMEM.PAS, etc.)
        * Forked from the ZZT Reconstruction and ClassicZoo.
        * Reconstruction: github.com/asiekierka/reconstruction-of-zzt
        * ClassicZoo: github.com/OpenZoo/ClassicZoo
    * EXAMPLE.OBJ
        * Example object used in the WeaveZZT demo.
    * ANGRY.OBJ, GREET.OBJ
        * Appended code used in the WeaveZZT demo.
    * THING.OBJ
        * Function code used in the WeaveZZT demo.
    * BEARBUL.OBJ, WONKY.OBJ
        * Custom bullets from the WeaveZZT demo.
    * WEAVEDMO.CFG
        * Element parameters for the WeaveZZT demo.
    * TEMPLATE.CFG
        * Basic parameters file with common options.
    * EXTENDED.CFG
        * Extended parameters file with more options.
    * WEAVEDMO.INI
        * Counters and Keybinds for the WeaveZZT demo.
    * TEMPLATE.INI
        * Standard Counters and Keybinds template file.
    * Using_Weave_with_Zeta.htm
        * A simple tutorial to get you started using Weave with Zeta. Included with the Weave 2 download.
* BUILDW28.BAT
    * Used in DOS or DOSBox to build Weave from source.
* LICENSE.TXT
    * MIT License, required by reconstruction-of-zzt.
* README.TXT
    * A brief explanation of Weaving.
* WEAVEDMO.ZZT
    * The WeaveZZT demo file.

## Questions

Hit me up in the ZZT Discord if you've got feedback or there's something to add. I'm not married to anything here so if there's a better way to do something, or you REALLY have to have like, breakable linewalls or walkable ricochets or something like that, Later versions of Weave could open that up. If you want to be able to create your own custom elements from accessory files, you're not alone. HardWeave and FixWeave both have specs and are in development, providing the more hardcore modders with the extensible element platform of their dreams.

Discord of ZZT Link: museumofzzt dot com slash discord

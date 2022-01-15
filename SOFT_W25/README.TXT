Soft Weave 2.5
Part of the Weave 2 Project

- - - - -

What is it?

  If you run your ZZT 3.2 compatible games with Soft Weave it will play them exactly as 3.2 does, bugs and all, with two exceptions:
    *  It attempts to load them into EMS/XMS. If your machine or emulator does not have either of those, Weave 2 will probably not work. Sorry, them's the breaks.
    *  Any tricks involving out-of-bounds won't work. Out-of-bounds stat movement is now checked for and prevented, and there's no guarantee that elements greater than 53 will work as they do in ZZT 3.2, because those also rely on memory configurations which won't have remained the same between versions.

  If you want to enhance games, you may change fundamental strings, sounds, and attributes by copying the provided TEMPLATE.CFG or EXTENDED.CFG file and renaming them the same name as your .ZZT file, then altering them per the directions in the template files themselves. Changes to the files will take effect on reload of the .ZZT world.

- - - - -

How use it?

  Enhancement can take many forms. You can tweak the amount of damage done by enemies and hazards or increase the benefit of helpful items, creating an "easy mode" for an existing classic game. You can customize the look of a player to increase "immersion", inasfar as ZZT is able to lay claim to that term. Is it really a white on blue smiley smooching those kobolds? Or would a blue dragon avatar be more your speed?

  You could also choose to put in some wild settings and develop a brand new game that takes the core mechanics of ZZT, plus a couple tweaks, and gives us something totally new. That's good because now you I can play all the cool games y'all will make when like, tigers are char 2 and the player is char 227 or whatever. (call it "Life of Tiger")

  If you find you started in SoftWeave and want more, you can take your existing .CFG file and upgrade to FirmWeave - all changes made to that point will be preserved, and you can then start adding new content from there.  See the FirmWeave EXTENDED.INI file to get a sense of what all you can do.

- - - - -

What isn't it?

  Soft Weaving is not mysterious.  Every change is in plain text and can be viewed by anyone who wants to play your game.

  Soft Weaving is not definitive.  You can't set default step values on items like pushers or duplicators (though I could probably be talked into providing this behavior).  However, it provides near complete control over element definitions, default strings & messages, and default sounds.  Use FirmWeave if you'd like to experiment with new commands as well.

  Soft Weaving is not indestructible. Extreme values in your .CFG file may crash ZZT. However I've been surprised by how well ZZT's logic copes with what should be impossible, so don't be shy. Just remember to back up your .CFG files and guard them the same you would a .ZZT file.  They're part of the game now.

- - - - -

  Everyone's Weaver status was revoked on January 1, 2022. You'll have to earn it back; it's my hope that Soft Weaving is a pathway to doing that.

  As always, hit me up in the ZZT Discord if you've got feedback or there's something to add. I'm not married to anything here so if there's a better way to do something, or you REALLY have to have like, breakable linewalls or walkable ricochets or something, later versions of SoftWeave could open that up.

  Discord of ZZT Link: https://discord.com/invite/Nar4Upf
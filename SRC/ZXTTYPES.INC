{ Populate this file with supported extension enums. }
{ Don't forget to call ZxtRegisterExtension() for each! }
TExtensionType = (
	ExtUnlockExtensions, { This one has to be first. }
	ExtFixPutBottomRow,
	ExtFixBindDoubleFree, { on by default }
	ExtFixKoopoBug,
	ExtFixRecursiveElementPush, { on by default }
	ExtFixConveyorStatCheck,
	ExtFixConveyorMissingFinalDraw, { on by default }
	ExtFixConveyorStatSwapping, { on by default }
	ExtFixBlinkWallShift,
	ExtDieItem,
	ExtDieUnderTile,
	ExtIfRnd,
	ExtGMDirByAt,
	ExtGMPutPlayer,
	ExtTypeEnd { This one has to be last. }
);

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
	ExtFixBoardEdgeTouch, { ZZT only }
	ExtFixPassageDestroy,
	ExtFixPassageColorDamage,
	ExtFixPlayerUnpauseDamage,
	ExtSuperzEnter, { ZZT only }
	ExtDieItem,
	ExtDieUnderTile,
	ExtIfRnd,
	ExtGMDirByAt,
	ExtQuirkArgTile2,
	ExtMaxStatCount,
	ExtTypeEnd { This one has to be last. }
);

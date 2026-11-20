package mobile;

/** Player's choice of touch controls, stored in the game save. */
class MobileSettings
{
	/** Gameplay layouts the player can choose from. */
	public static final MODES:Array<String> = ['Hitbox', 'Pad Right', 'Pad Left', 'Pad Duo', 'None'];
	public static final MODE_INFO:Array<String> = [
		'Tap anywhere in one of four lanes across the screen.',
		'Four arrow buttons in the bottom right corner.',
		'Four arrow buttons in the bottom left corner.',
		'Arrow buttons on both sides of the screen.',
		'No touch controls in songs (keyboard or gamepad).'
	];

	public static var mode:String = 'Hitbox';
	/** 0..1, how visible the controls are. */
	public static var opacity:Float = 0.6;
	/** Extra SPACE button for mods with dodge mechanics. */
	public static var spaceButton:Bool = true;
	/** Show the menu D-pad and buttons. */
	public static var menuButtons:Bool = true;

	public static function load():Void
	{
		var data:Dynamic = FlxG.save.data;
		if (data == null) return;
		if (data.mobileMode != null && MODES.contains(data.mobileMode)) mode = data.mobileMode;
		if (data.mobileOpacity != null) opacity = Math.max(0, Math.min(1, data.mobileOpacity));
		if (data.mobileSpace != null) spaceButton = data.mobileSpace;
		if (data.mobileMenuButtons != null) menuButtons = data.mobileMenuButtons;
	}

	public static function save():Void
	{
		FlxG.save.data.mobileMode = mode;
		FlxG.save.data.mobileOpacity = opacity;
		FlxG.save.data.mobileSpace = spaceButton;
		FlxG.save.data.mobileMenuButtons = menuButtons;
		FlxG.save.flush();
	}
}

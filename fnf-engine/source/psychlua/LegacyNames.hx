package psychlua;

/**
 * Psych Engine 0.7 moved most classes into packages (ClientPrefs ->
 * backend.ClientPrefs, PlayState -> states.PlayState...) and moved settings
 * into ClientPrefs.data. Mods made for 0.4 - 0.6 still use the old names;
 * this maps them so their Lua and HScript code keeps working.
 */
class LegacyNames
{
	public static final CLASSES:Map<String, String> = [
		'ClientPrefs' => 'backend.ClientPrefs',
		'Conductor' => 'backend.Conductor',
		'CoolUtil' => 'backend.CoolUtil',
		'Paths' => 'backend.Paths',
		'MusicBeatState' => 'backend.MusicBeatState',
		'MusicBeatSubstate' => 'backend.MusicBeatSubstate',
		'Highscore' => 'backend.Highscore',
		'WeekData' => 'backend.WeekData',
		'Song' => 'backend.Song',
		'StageData' => 'backend.StageData',
		'Achievements' => 'backend.Achievements',
		'CustomFadeTransition' => 'backend.CustomFadeTransition',
		'Controls' => 'backend.Controls',
		'Difficulty' => 'backend.Difficulty',
		'PlayState' => 'states.PlayState',
		'FreeplayState' => 'states.FreeplayState',
		'StoryMenuState' => 'states.StoryMenuState',
		'MainMenuState' => 'states.MainMenuState',
		'TitleState' => 'states.TitleState',
		'LoadingState' => 'states.LoadingState',
		'CreditsState' => 'states.CreditsState',
		'Character' => 'objects.Character',
		'Note' => 'objects.Note',
		'NoteSplash' => 'objects.NoteSplash',
		'StrumNote' => 'objects.StrumNote',
		'HealthIcon' => 'objects.HealthIcon',
		'Alphabet' => 'objects.Alphabet',
		'BGSprite' => 'objects.BGSprite',
		'AttachedSprite' => 'objects.AttachedSprite',
		'AttachedText' => 'objects.AttachedText',
		'MenuCharacter' => 'objects.MenuCharacter',
		'MenuItem' => 'objects.MenuItem',
		'GameOverSubstate' => 'substates.GameOverSubstate',
		'PauseSubState' => 'substates.PauseSubState',
		'DialogueBoxPsych' => 'cutscenes.DialogueBoxPsych',
		'DialogueBox' => 'cutscenes.DialogueBox',
		'CutsceneHandler' => 'cutscenes.CutsceneHandler',
		'FunkinLua' => 'psychlua.FunkinLua',
		'ModchartSprite' => 'psychlua.ModchartSprite',
		'FlxRuntimeShader' => 'flixel.addons.display.FlxRuntimeShader',
		'flixel.system.FlxSound' => 'flixel.sound.FlxSound',
		'FlxSound' => 'flixel.sound.FlxSound',
		'OptionsState' => 'options.OptionsState'
	];

	/** Static members of ClientPrefs that exist in 1.0 (anything else lives in ClientPrefs.data). */
	static final CLIENTPREFS_STATIC = ['data', 'defaultData', 'keyBinds', 'gamepadBinds', 'defaultKeys', 'defaultButtons', 'saveSettings',
		'loadPrefs', 'getGameplaySetting', 'reloadVolumeKeys', 'toggleVolumeKeys', 'clearInvalidKeys', 'loadDefaultKeys'];

	static final RENAMED_PREFS:Map<String, String> = ['globalAntialiasing' => 'antialiasing'];

	public static function resolveClass(name:String):Dynamic
	{
		if (name == null) return null;
		var c:Dynamic = Type.resolveClass(name);
		if (c == null && CLASSES.exists(name)) c = Type.resolveClass(CLASSES.get(name));
		return c;
	}

	/** ClientPrefs.downScroll (0.6) -> ClientPrefs.data.downScroll (1.0). */
	public static function fixVariable(classVar:String, variable:String):String
	{
		if (classVar == null || variable == null) return variable;
		if (classVar != 'ClientPrefs' && classVar != 'backend.ClientPrefs') return variable;
		var first = variable.split('.')[0];
		if (CLIENTPREFS_STATIC.contains(first)) return variable;
		if (RENAMED_PREFS.exists(first)) variable = RENAMED_PREFS.get(first) + variable.substr(first.length);
		return 'data.' + variable;
	}

	/** Old class names for HScript `import` statements. */
	public static function install():Void
	{
		#if HSCRIPT_ALLOWED
		for (old => modern in CLASSES)
		{
			var c = Type.resolveClass(modern);
			if (c != null && !crowplexus.iris.Iris.proxyImports.exists(old)) crowplexus.iris.Iris.proxyImports.set(old, c);
		}
		#end
	}
}

/**
 * Object given to HScript as `ClientPrefs`: supports both the 1.0 style
 * (ClientPrefs.data.downScroll) and the old one (ClientPrefs.downScroll).
 */
class LegacyClientPrefs
{
	public function new() {}

	public var data(get, never):backend.ClientPrefs.SaveVariables;
	public var defaultData(get, never):backend.ClientPrefs.SaveVariables;
	public var keyBinds(get, never):Map<String, Array<flixel.input.keyboard.FlxKey>>;
	function get_data() return ClientPrefs.data;
	function get_defaultData() return ClientPrefs.defaultData;
	function get_keyBinds() return ClientPrefs.keyBinds;

	public function getGameplaySetting(name:String, ?defaultValue:Dynamic, ?customDefaultValue:Bool = false):Dynamic
		return ClientPrefs.getGameplaySetting(name, defaultValue, customDefaultValue);
	public function saveSettings() ClientPrefs.saveSettings();
	public function loadPrefs() ClientPrefs.loadPrefs();

	// old field names
	public var downScroll(get, never):Bool;
	public var middleScroll(get, never):Bool;
	public var opponentStrums(get, never):Bool;
	public var ghostTapping(get, never):Bool;
	public var flashing(get, never):Bool;
	public var lowQuality(get, never):Bool;
	public var shaders(get, never):Bool;
	public var antialiasing(get, never):Bool;
	public var globalAntialiasing(get, never):Bool;
	public var framerate(get, never):Int;
	public var camZooms(get, never):Bool;
	public var hideHud(get, never):Bool;
	public var noteOffset(get, never):Int;
	public var showFPS(get, never):Bool;
	public var scoreZoom(get, never):Bool;
	public var healthBarAlpha(get, never):Float;
	public var timeBarType(get, never):String;
	public var noReset(get, never):Bool;
	public var pauseMusic(get, never):String;
	public var comboStacking(get, never):Bool;
	public var splashAlpha(get, never):Float;
	public var cacheOnGPU(get, never):Bool;
	public var autoPause(get, never):Bool;
	public var noteSplashes(get, never):Bool;

	function get_downScroll() return ClientPrefs.data.downScroll;
	function get_middleScroll() return ClientPrefs.data.middleScroll;
	function get_opponentStrums() return ClientPrefs.data.opponentStrums;
	function get_ghostTapping() return ClientPrefs.data.ghostTapping;
	function get_flashing() return ClientPrefs.data.flashing;
	function get_lowQuality() return ClientPrefs.data.lowQuality;
	function get_shaders() return ClientPrefs.data.shaders;
	function get_antialiasing() return ClientPrefs.data.antialiasing;
	function get_globalAntialiasing() return ClientPrefs.data.antialiasing;
	function get_framerate() return ClientPrefs.data.framerate;
	function get_camZooms() return ClientPrefs.data.camZooms;
	function get_hideHud() return ClientPrefs.data.hideHud;
	function get_noteOffset() return ClientPrefs.data.noteOffset;
	function get_showFPS() return ClientPrefs.data.showFPS;
	function get_scoreZoom() return ClientPrefs.data.scoreZoom;
	function get_healthBarAlpha() return ClientPrefs.data.healthBarAlpha;
	function get_timeBarType() return ClientPrefs.data.timeBarType;
	function get_noReset() return ClientPrefs.data.noReset;
	function get_pauseMusic() return ClientPrefs.data.pauseMusic;
	function get_comboStacking() return ClientPrefs.data.comboStacking;
	function get_splashAlpha() return ClientPrefs.data.splashAlpha;
	function get_cacheOnGPU() return ClientPrefs.data.cacheOnGPU;
	function get_autoPause() return ClientPrefs.data.autoPause;
	function get_noteSplashes() return ClientPrefs.data.splashAlpha > 0;
}

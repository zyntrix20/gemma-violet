package psychlua;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import objects.Character;
import objects.Note;

enum CompatEngine
{
	CODENAME;
	VSLICE;
}

/**
 * Runs a script written for Codename Engine (or a V-Slice script translated
 * at import time) inside Psych Engine.
 *
 * Psych calls its own callback names (onCreatePost, onBeatHit, goodNoteHit...);
 * this class forwards them to the names the other engine uses (postCreate,
 * beatHit, onPlayerHit... / onCreate, onBeatHit(event), onNoteHit(event)...),
 * wrapping arguments in event objects with the fields scripts usually read.
 */
class CompatHScript extends HScript
{
	public var engine:CompatEngine;

	public function new(file:String, engine:CompatEngine)
	{
		this.engine = engine;
		super(null, file, null, true);
		installShims();
		try
		{
			execute();
		}
		catch (e:IrisError)
		{
			Iris.error(Printer.errorToString(e, false), cast {fileName: file, showLine: false});
			throw e;
		}
	}

	function installShims()
	{
		var game:PlayState = PlayState.instance;
		set('game', game);
		set('importScript', function(_) return null);
		set('disableScript', function() active = false);
		set('FlxPoint', {get: function(x:Float = 0, y:Float = 0) return flixel.math.FlxPoint.get(x, y), weak: function(x:Float = 0, y:Float = 0) return flixel.math.FlxPoint.weak(x, y)});
		set('FlxAngle', flixel.math.FlxAngle);
		set('FlxRect', flixel.math.FlxRect);
		set('FlxSound', flixel.sound.FlxSound);
		set('FlxGroup', flixel.group.FlxGroup);
		set('FlxSpriteGroup', flixel.group.FlxSpriteGroup);
		set('FlxTypedGroup', flixel.group.FlxGroup.FlxTypedGroup);
		set('FlxBackdrop', flixel.addons.display.FlxBackdrop);
		set('FlxTrail', flixel.addons.effects.FlxTrail);
		set('CoolUtil', CoolUtil);
		set('Json', haxe.Json);
		set('Reflect', Reflect);

		if (game == null) return;

		// stage objects are reachable by their name, like in Codename stage scripts
		for (name => obj in game.variables)
			if (name != null && name.length > 0 && !exists(name)) set(name, obj);

		switch (engine)
		{
			case CODENAME:
				set('stage', {
					getSprite: function(name:String) return game.variables.get(name),
					stageSprites: game.variables
				});
				set('strumLines', {
					members: [
						{characters: [game.dad], cpu: true},
						{characters: [game.boyfriend], cpu: false},
						{characters: [game.gf], cpu: true}
					]
				});
				set('PlayState', PlayState);
				set('player', {characters: [game.boyfriend]});
				set('cpu', {characters: [game.dad]});
				set('__script__', this);
				set('CustomShader', CompatClasses.CompatCustomShader);
				set('FunkinShader', CompatClasses.CompatCustomShader);
				set('GameOverSubstate', substates.GameOverSubstate);
				set('Options', {
					flashingMenu: ClientPrefs.data.flashing,
					lowMemoryMode: ClientPrefs.data.lowQuality,
					camZoomOnBeat: ClientPrefs.data.camZooms,
					downscroll: ClientPrefs.data.downScroll,
					middlescroll: ClientPrefs.data.middleScroll,
					antialiasing: ClientPrefs.data.antialiasing,
					gameplayShaders: ClientPrefs.data.shaders,
					ghostTapping: ClientPrefs.data.ghostTapping,
					naughtyness: true
				});
				set('camZoomingStrength', 1.0);
				set('camZoomingInterval', 4);
				set('maxCamZoom', 1.35);
				set('playCutscenes', PlayState.isStoryMode);
				set('enableCameraHacks', false);
				set('curCameraTarget', 0);
				set('curBeatFloat', 0.0);
				set('curStepFloat', 0.0);
				set('inst', FlxG.sound.music);
				set('vocals', game.vocals);
				set('scrollSpeed', game.songSpeed);
				set('isStoryMode', PlayState.isStoryMode);
				set('difficulty', Difficulty.getString(false));
				set('SONG', PlayState.SONG);
			case VSLICE:
				var shim = new VSlicePlayStateShim(game);
				set('PlayState', {instance: shim});
				set('Conductor', {instance: new VSliceConductorShim()});
				set('currentStage', shim.currentStage);
				// stage scripts call these without "this."
				set('getNamedProp', shim.currentStage.getNamedProp);
				set('getBoyfriend', shim.currentStage.getBoyfriend);
				set('getDad', shim.currentStage.getDad);
				set('getGirlfriend', shim.currentStage.getGirlfriend);
				set('add', game.add);
				set('remove', game.remove);
				set('insert', game.insert);
				set('FunkinSprite', {
					create: function(x:Float = 0, y:Float = 0, ?key:String) {
						var spr = new FlxSprite(x, y);
						if (key != null) spr.loadGraphic(Paths.image(key));
						return spr;
					},
					createSparrow: function(x:Float = 0, y:Float = 0, key:String) {
						var spr = new FlxSprite(x, y);
						spr.frames = Paths.getSparrowAtlas(key);
						return spr;
					}
				});
				set('FunkinSound', {
					playOnce: function(key:String, volume:Float = 1) return FlxG.sound.play(Paths.sound(stripLib(key)), volume),
					load: function(key:String, volume:Float = 1, ?_:Dynamic, ?__:Dynamic, ?___:Dynamic) return FlxG.sound.load(Paths.sound(stripLib(key)), volume)
				});
				set('Save', {instance: {hasBeatenLevel: function(_) return true, hasBeatenSong: function(_) return true}});
				set('PlayStatePlaylist', {isStoryMode: PlayState.isStoryMode, campaignId: ''});
				set('VideoCutscene', {
					play: function(path:String, ?_:Dynamic) {
						var name = haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(path));
						game.startVideo(name);
					},
					isPlaying: function() return game.videoCutscene != null
				});
				set('HapticUtil', {vibrate: function(?a, ?b, ?c, ?d) {}, vibrateByPreset: function(?a) {}});
				var noop = Reflect.makeVarArgs(function(_) return null);
				for (name in ['AdjustColorShader', 'WiggleEffectRuntime', 'RuntimeRainShader', 'DropShadowShader', 'BuildingEffectShader',
					'OverlayBlend', 'SserafimShader', 'BlendModeEffect', 'RuntimePostEffectShader', 'GaussianBlurShader', 'ScreenWipeShader'])
					if (!exists(name)) set(name, CompatClasses.CompatDummyShader);
				set('StageProp', FlxSprite);
				set('FunkinSpriteBase', FlxSprite);
				set('Sequence', CompatClasses.CompatSequence);
				set('id', game.songName);
				set('variation', '');
				set('refresh', noop);
				set('Constants', {
					DEFAULT_DIFFICULTY: 'normal',
					DEFAULT_VARIATION: 'default',
					DEFAULT_CHARACTER: 'bf',
					DEFAULT_STAGE: 'mainStage',
					DEFAULT_SONG: 'tutorial',
					PIXEL_ART_SCALE: 6,
					COUNTDOWN_VOLUME: 0.6,
					HEALTH_MAX: 2.0,
					HEALTH_STARTING: 1.0,
					HEALTH_MIN: 0.0
				});
				set('Preferences', {
					flashingLights: ClientPrefs.data.flashing,
					naughtyness: true,
					downscroll: ClientPrefs.data.downScroll,
					zoomCamera: ClientPrefs.data.camZooms,
					autoPause: ClientPrefs.data.autoPause,
					framerate: ClientPrefs.data.framerate,
					lockedSubtitles: false,
					subtitles: false,
					vibration: 0,
					strumlineBackgroundOpacity: 0
				});
				set('FunkinMemory', {
					cacheTexture: noop, cacheSound: noop, cacheMusic: noop, purgeCache: noop, preparePurgeCache: noop,
					permanentCacheTexture: noop, clearFreeplay: noop, clearStickers: noop
				});
				set('CharacterType', {BF: 'bf', DAD: 'dad', GF: 'gf', OTHER: 'other'});
				set('CutsceneType', {STARTING: 'starting', MIDSONG: 'midsong', ENDING: 'ending'});
				set('WiggleEffectType', {DREAMY: 0, WAVY: 1, HEAT_WAVE_HORIZONTAL: 2, HEAT_WAVE_VERTICAL: 3, FLAG: 4});
				set('FullScreenScaleMode', {wideScale: {x: 1, y: 1}, gameCutoutSize: {x: 0, y: 0}, hasFakeCutouts: false, enabled: false});
				set('RetroCameraFade', {fadeWhite: noop, fadeBlack: noop, fadeToBlack: noop, fadeFromBlack: noop});
				set('FlxTweenUtil', {pauseTween: noop, resumeTween: noop, pauseTweensOf: noop, resumeTweensOf: noop});
				set('GameOverSubState', {instance: null, reset: noop, musicSuffix: '', blueBallSuffix: ''});
				set('PauseSubState', {musicSuffix: '', reset: noop});
				set('MathUtil', {
					lerp: function(a:Float, b:Float, r:Float) return a + (b - a) * r,
					coolLerp: function(a:Float, b:Float, r:Float) return a + (b - a) * r,
					smoothLerp: function(a:Float, b:Float, elapsed:Float, duration:Float, ?precision:Float) return a + (b - a) * Math.min(1, elapsed / Math.max(0.0001, duration)),
					smoothLerpPrecision: function(a:Float, b:Float, elapsed:Float, duration:Float, ?precision:Float) return a + (b - a) * Math.min(1, elapsed / Math.max(0.0001, duration))
				});
		}
	}

	static function stripLib(key:String):String
	{
		if (key == null) return key;
		var i = key.indexOf(':');
		return i >= 0 ? key.substr(i + 1) : key;
	}

	// ------------------------------------------------------------ callbacks

	static function makeEvent(fields:Dynamic):Dynamic
	{
		var ev:Dynamic = fields != null ? fields : {};
		ev.cancelled = false;
		ev.eventCanceled = false;
		ev.cancel = function() {
			ev.cancelled = true;
			ev.eventCanceled = true;
		};
		ev.preventAnim = function() ev.animCancelled = true;
		ev.cancelAnim = function() ev.animCancelled = true;
		return ev;
	}

	static function noteEvent(note:Note, player:Bool):Dynamic
	{
		var game = PlayState.instance;
		var char:Character = (note != null && note.gfNote) ? game.gf : (player ? game.boyfriend : game.dad);
		return makeEvent({
			note: note,
			noteType: note != null ? note.noteType : '',
			direction: note != null ? note.noteData : 0,
			character: char,
			characters: [char],
			player: player,
			isPlayer: player,
			animSuffix: '',
			healthGain: 0.0,
			score: 0,
			strumTime: note != null ? note.strumTime : 0.0,
			sustain: note != null && note.isSustainNote
		});
	}

	/** Psych callback -> list of [target function, arguments]. */
	function targets(funcName:String, args:Array<Dynamic>):Array<{name:String, args:Array<Dynamic>, ev:Dynamic}>
	{
		var game = PlayState.instance;
		inline function t(name:String, a:Array<Dynamic>, ?ev:Dynamic) return {name: name, args: a, ev: ev};
		switch (engine)
		{
			case CODENAME:
				return switch (funcName)
				{
					case 'onCreatePost': [t('postCreate', [])];
					case 'onUpdate': [t('update', args)];
					case 'onUpdatePost': [t('postUpdate', args)];
					case 'onBeatHit': [t('beatHit', [CompatTime.beat()])];
					case 'onStepHit': [t('stepHit', [CompatTime.step()])];
					case 'onSectionHit': [t('measureHit', [CompatTime.section()])];
					case 'onSongStart': [t('onSongStart', []), t('onStartSong', [])];
					case 'onEndSong':
						var ev = makeEvent(null);
						[t('onSongEnd', [ev], ev)];
					case 'onStartCountdown':
						var ev = makeEvent(null);
						[t('onStartCountdown', [ev], ev)];
					case 'onCountdownTick':
						var ev = makeEvent({swagCounter: args != null && args.length > 1 ? args[1] : 0});
						[t('onCountdown', [ev], ev)];
					case 'goodNoteHit':
						var ev = noteEvent(args[0], true);
						[t('onPlayerHit', [ev], ev), t('onNoteHit', [ev], ev)];
					case 'opponentNoteHit':
						var ev = noteEvent(args[0], false);
						[t('onDadHit', [ev], ev), t('onNoteHit', [ev], ev)];
					case 'noteMiss':
						var ev = noteEvent(args[0], true);
						[t('onPlayerMiss', [ev], ev)];
					case 'onEvent':
						var ev = makeEvent({event: {name: args[0], params: [args[1], args[2]], time: args[3]}});
						[t('onEvent', [ev], ev)];
					case 'onPause':
						var ev = makeEvent(null);
						[t('onGamePause', [ev], ev)];
					case 'onGameOver':
						var ev = makeEvent(null);
						[t('onGameOver', [ev], ev)];
					case 'onDestroy': [t('destroy', [])];
					default: [];
				}
			case VSLICE:
				return switch (funcName)
				{
					case 'onUpdate': [t('onUpdate', [makeEvent({elapsed: args[0]})])];
					case 'onBeatHit': [t('onBeatHit', [makeEvent({beat: CompatTime.beat(), step: CompatTime.step()})])];
					case 'onStepHit': [t('onStepHit', [makeEvent({beat: CompatTime.beat(), step: CompatTime.step()})])];
					case 'onSongStart': [t('onSongStart', [makeEvent(null)])];
					case 'onEndSong':
						var ev = makeEvent(null);
						[t('onSongEnd', [ev], ev)];
					case 'onStartCountdown':
						var ev = makeEvent(null);
						[t('onCountdownStart', [ev], ev)];
					case 'onCountdownTick':
						[t('onCountdownStep', [makeEvent({step: args != null && args.length > 1 ? args[1] : 0})])];
					case 'goodNoteHit':
						var ev = noteEvent(args[0], true);
						[t('onNoteHit', [ev], ev)];
					case 'opponentNoteHit':
						var ev = noteEvent(args[0], false);
						[t('onNoteHit', [ev], ev)];
					case 'noteMiss':
						var ev = noteEvent(args[0], true);
						[t('onNoteMiss', [ev], ev)];
					case 'onEvent':
						var value:Dynamic = args[1];
						try value = haxe.Json.parse(args[1]) catch (e:Dynamic) {}
						var ev = makeEvent({eventData: {eventKind: args[0], value: value, time: args[3]}});
						[t('onSongEvent', [ev], ev)];
					case 'onPause':
						var ev = makeEvent(null);
						[t('onPause', [ev], ev)];
					case 'onGameOver': [t('onGameOver', [makeEvent(null)])];
					case 'onDestroy': [t('onDestroy', [makeEvent(null)])];
					default: [];
				}
		}
	}

	var active:Bool = true;

	override public function exists(field:String):Bool
	{
		if (!active || interp == null) return false;
		for (target in targets(field, [null, null, null, null]))
			if (super.exists(target.name)) return true;
		return false;
	}

	override function call(funcToRun:String, ?args:Array<Dynamic>):crowplexus.iris.Iris.IrisCall
	{
		if (!active || interp == null) return null;
		if (engine == CODENAME && funcToRun == 'onUpdate')
		{
			interp.variables.set('curBeatFloat', Conductor.songPosition / Conductor.crochet);
			interp.variables.set('curStepFloat', Conductor.songPosition / Conductor.stepCrochet);
		}
		var cancelled = false;
		var result:crowplexus.iris.Iris.IrisCall = null;
		for (target in targets(funcToRun, args != null ? args : []))
		{
			if (!super.exists(target.name)) continue;
			var r = safeCall(target.name, target.args);
			if (r != null) result = r;
			if (target.ev != null && target.ev.cancelled == true) cancelled = true;
		}
		if (cancelled) return {funName: funcToRun, signature: null, returnValue: LuaUtils.Function_Stop};
		return result;
	}

	/** Runs the script's own create function (called right after loading). */
	public function runCreate()
	{
		var name = engine == CODENAME ? 'create' : 'onCreate';
		if (super.exists(name)) safeCall(name, engine == CODENAME ? [] : [makeEvent(null)]);
		if (engine == VSLICE && super.exists('onSongLoaded')) safeCall('onSongLoaded', [makeEvent(null)]);
	}

	var errors:Int = 0;

	/** Scripts from another engine often touch things Psych doesn't have: never let that crash the song. */
	function safeCall(name:String, args:Array<Dynamic>):crowplexus.iris.Iris.IrisCall
	{
		try
		{
			var func:Dynamic = interp.variables.get(name);
			if (func == null) return null;
			var ret = Reflect.callMethod(null, func, args != null ? args : []);
			return {funName: name, signature: func, returnValue: ret};
		}
		catch (e:IrisError)
		{
			reportError(name, Printer.errorToString(e, false));
		}
		catch (e:Dynamic)
		{
			reportError(name, Std.string(e));
		}
		return null;
	}

	function reportError(name:String, msg:String)
	{
		errors++;
		var file = filePath != null ? haxe.io.Path.withoutDirectory(filePath) : 'script';
		var line = msg.split('\n')[0];
		// show each distinct error once
		if (PlayState.instance != null && !shownErrors.contains(line) && shownErrors.length < 3)
		{
			shownErrors.push(line);
			PlayState.instance.addTextToDebug('[$file] $name: $line', 0xFFFF8080);
		}
		trace('[$file] $name: $msg');
		// a script that keeps failing every frame is switched off
		if (errors >= 30)
		{
			active = false;
			if (PlayState.instance != null) PlayState.instance.addTextToDebug('[$file] turned off (too many errors)', 0xFFFF8080);
		}
	}

	var shownErrors:Array<String> = [];
}

/** The parts of V-Slice's PlayState that scripts use most, mapped onto Psych's. */
class VSlicePlayStateShim
{
	var game:PlayState;

	public var currentStage:VSliceStageShim;
	public var camGame(get, never):FlxCamera;
	public var camHUD(get, never):FlxCamera;
	public var camOther(get, never):FlxCamera;
	public var cameraFollowPoint(get, never):flixel.FlxObject;
	public var health(get, set):Float;
	public var songScore(get, set):Int;
	public var defaultCameraZoom(get, set):Float;
	public var currentCameraZoom(get, set):Float;
	public var isInCutscene(get, never):Bool;
	public var currentSong(get, never):Dynamic;
	public var iconP1(get, never):objects.HealthIcon;
	public var iconP2(get, never):objects.HealthIcon;
	public var camCutscene(get, never):FlxCamera;
	public var mayPauseGame(get, set):Bool;
	public var controls(get, never):Controls;
	public var vocals(get, never):FlxSound;
	public var isPracticeMode(get, never):Bool;
	public var opponentStrumline(get, never):Dynamic;
	public var playerStrumline(get, never):Dynamic;
	public var isChartingMode:Bool = false;
	public var isMinimalMode:Bool = false;
	public var justUnpaused:Bool = false;
	public var disableKeys:Bool = false;
	public var subtitles:Dynamic = null;
	public var comboPopUps:Dynamic = null;
	public var currentVariation:String = 'default';
	public var currentDifficulty(get, never):String;

	public function new(game:PlayState)
	{
		this.game = game;
		currentStage = new VSliceStageShim(game);
	}

	function get_camGame() return game.camGame;
	function get_camHUD() return game.camHUD;
	function get_camOther() return game.camOther;
	function get_cameraFollowPoint() return game.camFollow;
	function get_health() return game.health;
	function set_health(v:Float) return game.health = v;
	function get_songScore() return game.songScore;
	function set_songScore(v:Int) return game.songScore = v;
	function get_defaultCameraZoom() return game.defaultCamZoom;
	function set_defaultCameraZoom(v:Float) return game.defaultCamZoom = v;
	function get_currentCameraZoom() return FlxG.camera.zoom;
	function set_currentCameraZoom(v:Float) return FlxG.camera.zoom = v;
	function get_isInCutscene() return game.inCutscene;
	function get_currentSong() return {id: game.songName, songName: PlayState.SONG.song};
	function get_iconP1() return game.iconP1;
	function get_iconP2() return game.iconP2;
	function get_camCutscene() return game.camOther;
	function get_mayPauseGame() return Reflect.getProperty(game, 'canPause') == true;
	function set_mayPauseGame(v:Bool) { Reflect.setProperty(game, 'canPause', v); return v; }
	function get_controls() return Controls.instance;
	function get_vocals() return game.vocals;
	function get_isPracticeMode() return game.practiceMode;
	function get_opponentStrumline() return {members: game.opponentStrums.members, strumlineNotes: game.opponentStrums, visible: true};
	function get_playerStrumline() return {members: game.playerStrums.members, strumlineNotes: game.playerStrums, visible: true};
	function get_currentDifficulty() return Difficulty.getString(false).toLowerCase();

	/** Dialogue isn't supported: continue straight to the countdown instead of waiting forever. */
	public function startConversation(?_:Dynamic) game.startCountdown();
	public function togglePauseButton(?_:Dynamic) {}
	public function refresh() {}
	public function tweenCameraToPosition(?x:Float, ?y:Float, ?duration:Float, ?ease:Dynamic)
	{
		game.isCameraOnForcedPos = true;
		if (x == null || y == null) return;
		if (duration == null || duration <= 0) game.camFollow.setPosition(x, y);
		else FlxTween.tween(game.camFollow, {x: x, y: y}, duration, {ease: ease != null ? ease : FlxEase.linear});
	}
	public function cancelCameraFollowTween() {}
	public function cancelCameraZoomTween() {}
	public function cancelAllCameraTweens() {}

	public function add(obj:flixel.FlxBasic) return game.add(obj);
	public function remove(obj:flixel.FlxBasic) return game.remove(obj);
	public function insert(pos:Int, obj:flixel.FlxBasic) return game.insert(pos, obj);
	public function startCountdown() return game.startCountdown();
	public function endSong(?_:Dynamic) return game.endSong();
	public function tweenCameraZoom(zoom:Float, duration:Float, ?direct:Bool, ?ease:Dynamic)
		FlxTween.tween(game, {defaultCamZoom: direct == true ? zoom : game.defaultCamZoom * zoom}, duration, {ease: ease != null ? ease : FlxEase.linear});
	public function resetCamera(?_:Dynamic, ?__:Dynamic) game.isCameraOnForcedPos = false;
}

class VSliceStageShim
{
	var game:PlayState;

	public function new(game:PlayState)
		this.game = game;

	public function getNamedProp(name:String):Dynamic return game.variables.get(name);
	public function getBoyfriend(?_:Dynamic):Character return game.boyfriend;
	public function getDad(?_:Dynamic):Character return game.dad;
	public function getGirlfriend(?_:Dynamic):Character return game.gf;
	public function add(obj:flixel.FlxBasic) return game.add(obj);
	public function remove(obj:flixel.FlxBasic) return game.remove(obj);
	public function refresh() {}
}

class VSliceConductorShim
{
	public var instance(get, never):VSliceConductorShim;
	public var currentBeat(get, never):Int;
	public var currentStep(get, never):Int;
	public var currentBeatTime(get, never):Float;
	public var currentStepTime(get, never):Float;
	public var beatLengthMs(get, never):Float;
	public var stepLengthMs(get, never):Float;
	public var bpm(get, never):Float;
	public var songPosition(get, never):Float;

	public function new() {}

	function get_instance() return this;
	function get_currentBeat() return CompatTime.beat();
	function get_currentStep() return CompatTime.step();
	function get_currentBeatTime() return Conductor.songPosition / Conductor.crochet;
	function get_currentStepTime() return Conductor.songPosition / Conductor.stepCrochet;
	function get_beatLengthMs() return Conductor.crochet;
	function get_stepLengthMs() return Conductor.stepCrochet;
	function get_bpm() return Conductor.bpm;
	function get_songPosition() return Conductor.songPosition;
}
/** Reads PlayState's private beat counters. */
class CompatTime
{
	public static function beat():Int
		return PlayState.instance != null ? @:privateAccess PlayState.instance.curBeat : 0;

	public static function step():Int
		return PlayState.instance != null ? @:privateAccess PlayState.instance.curStep : 0;

	public static function section():Int
		return PlayState.instance != null ? @:privateAccess PlayState.instance.curSection : 0;
}
#end

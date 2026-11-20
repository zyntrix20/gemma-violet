package mobile;

#if android
import lime.system.JNI;
#end

enum PickState
{
	IDLE;
	PICKING;
	COPYING;
	DONE(path:String);
	CANCELLED;
	ERROR(message:String);
}

/**
 * Thin wrapper around the native helpers (see android/modtools/ModTools.java).
 * On desktop the same API is backed by lime's file dialog so the import
 * flow can be tested without a phone.
 */
class NativeBridge
{
	#if android
	static inline final CLASS:String = "org/funkinmods/engine/ModTools";

	static var _getStorageDir:Dynamic;
	static var _pick:Dynamic;
	static var _getState:Dynamic;
	static var _getResult:Dynamic;
	static var _reset:Dynamic;
	static var _toast:Dynamic;
	static var _inState:Dynamic;
	static var _inResult:Dynamic;
	static var _inReset:Dynamic;

	static function jni(name:String, sig:String):Dynamic
		return JNI.createStaticMethod(CLASS, name, sig);
	#else
	static var desktopState:PickState = IDLE;
	#end

	/** Writable folder where the engine keeps assets, mods and imports. */
	public static function getStorageDir():String
	{
		#if android
		if (_getStorageDir == null) _getStorageDir = jni("getStorageDir", "()Ljava/lang/String;");
		return _getStorageDir();
		#elseif sys
		return Sys.getCwd();
		#else
		return '';
		#end
	}

	/** Opens the system file picker for a mod archive. Poll `pollPick()` afterwards. */
	public static function pickModArchive():Void
	{
		#if android
		if (_pick == null) _pick = jni("pickModArchive", "()V");
		_pick();
		#elseif desktop
		desktopState = PICKING;
		var dialog = new lime.ui.FileDialog();
		dialog.onSelect.add(function(path:String) desktopState = DONE(path));
		dialog.onCancel.add(function() desktopState = CANCELLED);
		if (!dialog.browse(OPEN, 'zip', null, 'Select a mod archive'))
			desktopState = ERROR('File dialogs are not supported here.');
		#end
	}

	public static function pollPick():PickState
	{
		#if android
		if (_getState == null)
		{
			_getState = jni("getPickState", "()I");
			_getResult = jni("getPickResult", "()Ljava/lang/String;");
		}
		var state:Int = _getState();
		return switch (state)
		{
			case 1: PICKING;
			case 2: COPYING;
			case 3: DONE(_getResult());
			case 4: CANCELLED;
			case 5: ERROR(_getResult());
			default: IDLE;
		}
		#elseif desktop
		return desktopState;
		#else
		return IDLE;
		#end
	}

	public static function resetPick():Void
	{
		#if android
		if (_reset == null) _reset = jni("resetPick", "()V");
		_reset();
		#elseif desktop
		desktopState = IDLE;
		#end
	}

	/** A mod archive opened from another app ("Open with" / "Share"). */
	public static function pollIncoming():PickState
	{
		#if android
		if (_inState == null)
		{
			_inState = jni("getIncomingState", "()I");
			_inResult = jni("getIncomingResult", "()Ljava/lang/String;");
			_inReset = jni("resetIncoming", "()V");
		}
		var state:Int = _inState();
		return switch (state)
		{
			case 2: COPYING;
			case 3: DONE(_inResult());
			case 5: ERROR(_inResult());
			default: IDLE;
		}
		#else
		return IDLE;
		#end
	}

	public static function resetIncoming():Void
	{
		#if android
		if (_inReset != null) _inReset();
		#end
	}

	/** Called every frame: opens the Mods screen when a mod was shared to the app. */
	public static function checkIncoming():Void
	{
		#if android
		var state = FlxG.state;
		if (state == null || Std.isOfType(state, PlayState) || Std.isOfType(state, CopyState)) return;
		switch (pollIncoming())
		{
			case DONE(path):
				resetIncoming();
				states.ModsHubState.pendingImport = path;
				if (!Std.isOfType(state, states.ModsHubState))
					MusicBeatState.switchState(new states.ModsHubState());
			case ERROR(message):
				resetIncoming();
				toast(message);
			default:
		}
		#end
	}

	public static function toast(text:String):Void
	{
		#if android
		if (_toast == null) _toast = jni("toast", "(Ljava/lang/String;)V");
		_toast(text);
		#else
		trace(text);
		#end
	}
}

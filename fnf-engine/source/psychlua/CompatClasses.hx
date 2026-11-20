package psychlua;

#if HSCRIPT_ALLOWED
import flixel.addons.display.FlxRuntimeShader;
import flixel.system.FlxAssets.FlxShader;

/**
 * Stand-in for V-Slice's built-in shader classes (AdjustColorShader,
 * WiggleEffectRuntime, DropShadowShader...). It draws the sprite normally and
 * accepts any property or setter call, so scripts that use them keep running.
 */
class CompatDummyShader extends FlxShader
{
	// properties V-Slice scripts commonly set on their shaders
	public var hue:Dynamic = 0;
	public var saturation:Dynamic = 0;
	public var brightness:Dynamic = 0;
	public var contrast:Dynamic = 0;
	public var angle:Dynamic = 0;
	public var distance:Dynamic = 0;
	public var threshold:Dynamic = 0;
	public var strength:Dynamic = 0;
	public var amount:Dynamic = 0;
	public var intensity:Dynamic = 0;
	public var color:Dynamic = 0;
	public var effectType:Dynamic = 0;
	public var waveSpeed:Dynamic = 0;
	public var waveFrequency:Dynamic = 0;
	public var waveAmplitude:Dynamic = 0;
	public var uTime:Dynamic = 0;
	public var iTime:Dynamic = 0;
	public var time:Dynamic = 0;
	public var scale:Dynamic = 1;
	public var rainColor:Dynamic = 0;
	public var lightStrength:Dynamic = 0;
	public var baseBrightness:Dynamic = 0;
	public var baseHue:Dynamic = 0;
	public var baseSaturation:Dynamic = 0;
	public var baseContrast:Dynamic = 0;
	public var useAltMask:Dynamic = false;
	public var antialiasAmt:Dynamic = 0;
	public var blendColor:Dynamic = 0;

	public function new(?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic)
	{
		super();
	}

	public function setAdjustColor(?b:Float, ?h:Float, ?c:Float, ?s:Float) {}
	public function setFloat(?name:String, ?v:Dynamic) {}
	public function setFloatArray(?name:String, ?v:Dynamic) {}
	public function setInt(?name:String, ?v:Dynamic) {}
	public function setBool(?name:String, ?v:Dynamic) {}
	public function setColor(?v:Dynamic) {}
	public function setAmount(?v:Dynamic) {}
	public function setDistance(?v:Dynamic) {}
	public function setAngle(?v:Dynamic) {}
	public function setStrength(?v:Dynamic) {}
	public function attachedSprite(?v:Dynamic) {}
	public function loadAltMask(?v:Dynamic) {}
	public function update(?elapsed:Float) {}
}

/** Codename's CustomShader('name'): loads shaders/name.frag/.vert from the mod. */
class CompatCustomShader extends FlxRuntimeShader
{
	public function new(name:String, ?glslVersion:Dynamic)
	{
		var frag:String = null;
		var vert:String = null;
		#if MODS_ALLOWED
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders/'))
		{
			if (frag == null && FileSystem.exists(folder + name + '.frag')) frag = File.getContent(folder + name + '.frag');
			if (vert == null && FileSystem.exists(folder + name + '.vert')) vert = File.getContent(folder + name + '.vert');
		}
		#end
		if (!ClientPrefs.data.shaders) frag = vert = null;
		try
		{
			super(frag, vert);
		}
		catch (e:Dynamic)
		{
			super(null, null);
		}
	}

	/** Codename-style uniform setters. */
	public function hset(name:String, value:Dynamic)
	{
		try
		{
			if (Std.isOfType(value, Bool)) setBool(name, value);
			else if (Std.isOfType(value, Int)) setInt(name, value);
			else if (Std.isOfType(value, Array)) setFloatArray(name, value);
			else setFloat(name, value);
		}
		catch (e:Dynamic) {}
	}

	public function hget(name:String):Dynamic
	{
		try return getFloat(name) catch (e:Dynamic) return null;
	}
}

/**
 * V-Slice's Sequence: runs callbacks at given times (seconds), used by
 * cutscene scripts: new Sequence([{time: 0, callback: f}, ...]).
 */
class CompatSequence
{
	var timers:Array<FlxTimer> = [];
	public var running:Bool = true;

	public function new(entries:Array<Dynamic>, ?timeScale:Float = 1, ?autoStart:Bool = true)
	{
		if (entries == null) return;
		for (entry in entries)
		{
			var time:Float = entry.time != null ? entry.time : 0;
			var cb:Dynamic = entry.callback;
			if (cb == null) continue;
			timers.push(new FlxTimer().start(Math.max(0.0001, time * timeScale), function(_) {
				if (running) try cb() catch (e:Dynamic) trace('Sequence callback failed: $e');
			}));
		}
	}

	public function destroy()
	{
		running = false;
		for (t in timers) t.cancel();
		timers = [];
	}

	public function pause() for (t in timers) t.active = false;
	public function resume() for (t in timers) t.active = true;
}
#end

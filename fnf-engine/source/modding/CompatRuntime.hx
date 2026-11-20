package modding;

import backend.StageData.StageFile;
import flixel.tweens.FlxEase.EaseFunction;
import haxe.Json;
import objects.Character;
import psychlua.ModchartSprite;

/**
 * Runtime support for content converted from V-Slice (and Codename) mods.
 *
 * Converted stages carry a "vslice" block describing where characters stand
 * (V-Slice anchors characters by their feet, Psych by the top-left corner)
 * and camera offsets. Converted charts can also contain V-Slice camera
 * events (FocusCamera, ZoomCamera, SetCameraBop) that Psych has no
 * equivalent for. Everything here is a no-op for regular Psych content.
 */
class CompatRuntime
{
	static var meta:Dynamic = null;
	static var layoutActive:Bool = false;
	static var stageZoom:Float = 1;
	static var zoomTween:FlxTween = null;
	static var camTween:FlxTween = null;
	static var leftRight:Map<String, Bool> = [];
	static var bopRate:Int = 0; // 0 = Psych's default (every section)
	static var bopIntensity:Float = 1;

	public static function reset():Void
	{
		meta = null;
		layoutActive = false;
		bopRate = 0;
		bopIntensity = 1;
		leftRight.clear();
		zoomTween = null;
		camTween = null;
	}

	/** Called by PlayState right after characters and stage objects are created. */
	public static function applyStageLayout(game:PlayState, stage:StageFile):Void
	{
		reset();
		if (stage == null) return;
		stageZoom = stage.defaultZoom;
		var data:Dynamic = Reflect.field(stage, 'vslice');
		if (data == null) return;
		meta = data;

		var chars:Dynamic = ModFiles.field(meta, 'characters');
		if (chars == null || Reflect.fields(chars).length == 0) return;
		layoutActive = true;
		place(game.boyfriend, game.boyfriendGroup, ModFiles.field(chars, 'bf'));
		place(game.dad, game.dadGroup, ModFiles.field(chars, 'dad'));
		if (game.gf != null) place(game.gf, game.gfGroup, ModFiles.field(chars, 'gf'));
	}

	static function place(char:Character, group:FlxSpriteGroup, data:Dynamic):Void
	{
		if (char == null || group == null || data == null) return;
		var pos:Array<Float> = ModFiles.pair(ModFiles.field(data, 'position'), 0);
		var scale:Float = ModFiles.toFloat(ModFiles.field(data, 'scale'), 1);
		if (scale != 1)
		{
			char.scale.set(char.scale.x * scale, char.scale.y * scale);
			char.updateHitbox();
		}
		// V-Slice: feet (bottom center) of the character sit on `position`
		var targetX = pos[0] - char.width / 2 + char.positionArray[0];
		var targetY = pos[1] - char.height + char.positionArray[1];
		group.x += targetX - char.x;
		group.y += targetY - char.y;
	}

	static function stageCamOffset(key:String):Array<Float>
	{
		if (meta == null) return [0, 0];
		var chars:Dynamic = ModFiles.field(meta, 'characters');
		var data:Dynamic = chars != null ? ModFiles.field(chars, key) : null;
		return ModFiles.pair(data != null ? ModFiles.field(data, 'cameraOffsets') : null, 0);
	}

	static function focusPoint(char:Character, key:String):FlxPoint
	{
		var mid = char.getMidpoint();
		var charCam:Array<Float> = char.vsliceCamera != null ? char.vsliceCamera : [0, 0];
		var stageCam = stageCamOffset(key);
		mid.x += charCam[0] + stageCam[0];
		mid.y += charCam[1] + stageCam[1];
		return mid;
	}

	/** Overrides Psych's camera target on converted V-Slice stages. */
	public static function adjustCamera(game:PlayState, focus:String):Void
	{
		if (!layoutActive || game.camFollow == null) return;
		var char:Character = switch (focus)
		{
			case 'dad': game.dad;
			case 'gf': game.gf;
			default: game.boyfriend;
		}
		if (char == null) return;
		var p = focusPoint(char, focus);
		game.camFollow.setPosition(p.x, p.y);
		p.put();
	}

	static function getEase(name:String):EaseFunction
	{
		if (name == null) return FlxEase.linear;
		var f:Dynamic = Reflect.field(FlxEase, name);
		if (f == null) f = Reflect.field(FlxEase, name.charAt(0).toLowerCase() + name.substr(1));
		return f != null ? f : FlxEase.linear;
	}

	static function parse(value:String):Dynamic
	{
		if (value == null) return null;
		var v = value.trim();
		if (v.length == 0) return null;
		if (v.startsWith('{') || v.startsWith('['))
		{
			try return Json.parse(v) catch (e:Dynamic) {}
		}
		var f = Std.parseFloat(v);
		return Math.isNaN(f) ? v : f;
	}

	/** Handles events that only exist in V-Slice charts. */
	public static function onEvent(game:PlayState, name:String, value1:String, value2:String):Void
	{
		switch (name)
		{
			case 'FocusCamera':
				var v:Dynamic = parse(value1);
				var charId:Int = 0;
				var ox:Float = 0;
				var oy:Float = 0;
				var ease:String = 'CLASSIC';
				var duration:Float = 4;
				if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) charId = Std.int(v);
				else if (v != null && !Std.isOfType(v, String))
				{
					charId = Std.int(ModFiles.toFloat(ModFiles.field(v, 'char'), 0));
					ox = ModFiles.toFloat(ModFiles.field(v, 'x'), 0);
					oy = ModFiles.toFloat(ModFiles.field(v, 'y'), 0);
					ease = ModFiles.field(v, 'ease', 'CLASSIC');
					duration = ModFiles.toFloat(ModFiles.field(v, 'duration'), 4);
				}

				var tx:Float = ox;
				var ty:Float = oy;
				var char:Character = null;
				var key = 'bf';
				switch (charId)
				{
					case 0: char = game.boyfriend; key = 'bf';
					case 1: char = game.dad; key = 'dad';
					case 2: char = game.gf; key = 'gf';
					default:
				}
				if (char != null)
				{
					var p:FlxPoint;
					if (layoutActive) p = focusPoint(char, key);
					else
					{
						// regular Psych stage: reuse Psych's own camera math
						switch (charId)
						{
							case 1: game.moveCamera(true);
							case 2: game.moveCameraToGirlfriend();
							default: game.moveCamera(false);
						}
						p = FlxPoint.get(game.camFollow.x, game.camFollow.y);
					}
					tx += p.x;
					ty += p.y;
					p.put();
				}

				game.isCameraOnForcedPos = true;
				if (camTween != null) camTween.cancel();
				camTween = null;
				switch (ease)
				{
					case 'INSTANT':
						game.camFollow.setPosition(tx, ty);
						FlxG.camera.snapToTarget();
					case 'CLASSIC' | null:
						game.camFollow.setPosition(tx, ty);
					default:
						var secs = Math.max(0.01, duration * Conductor.stepCrochet / 1000 / game.playbackRate);
						camTween = FlxTween.tween(game.camFollow, {x: tx, y: ty}, secs, {ease: getEase(ease)});
				}

			case 'ZoomCamera':
				var v:Dynamic = parse(value1);
				var zoom:Float = 1;
				var duration:Float = 4;
				var ease:String = 'linear';
				var direct:Bool = false;
				if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) zoom = v;
				else if (v != null && !Std.isOfType(v, String))
				{
					zoom = ModFiles.toFloat(ModFiles.field(v, 'zoom'), 1);
					duration = ModFiles.toFloat(ModFiles.field(v, 'duration'), 4);
					ease = ModFiles.field(v, 'ease', 'linear');
					direct = ModFiles.field(v, 'mode', 'stage') == 'direct';
				}
				var target = direct ? zoom : stageZoom * zoom;
				if (zoomTween != null) zoomTween.cancel();
				zoomTween = null;
				if (ease == 'INSTANT' || duration <= 0)
				{
					game.defaultCamZoom = target;
					FlxG.camera.zoom = target;
				}
				else
				{
					var secs = Math.max(0.01, duration * Conductor.stepCrochet / 1000 / game.playbackRate);
					zoomTween = FlxTween.tween(game, {defaultCamZoom: target}, secs, {ease: getEase(ease)});
				}

			case 'SetCameraBop':
				var v:Dynamic = parse(value1);
				if (v != null && !Std.isOfType(v, String) && !Std.isOfType(v, Float))
				{
					var intensity = ModFiles.toFloat(ModFiles.field(v, 'intensity'), 1);
					var rate = Std.int(ModFiles.toFloat(ModFiles.field(v, 'rate'), 4));
					if (rate <= 0)
					{
						bopRate = 0;
						game.camZoomingMult = 0;
					}
					else if (rate == 4)
					{
						bopRate = 0;
						game.camZoomingMult = intensity;
					}
					else
					{
						// custom bop speed: Psych only bops per section, so do it here
						bopRate = rate;
						bopIntensity = intensity;
						game.camZoomingMult = 0;
					}
				}

			case 'SetHealthIcon':
				var v:Dynamic = parse(value1);
				if (v != null && !Std.isOfType(v, String) && !Std.isOfType(v, Float))
				{
					var id:String = ModFiles.field(v, 'id');
					var charId = Std.int(ModFiles.toFloat(ModFiles.field(v, 'char'), 0));
					if (id != null) (charId == 0 ? game.iconP1 : game.iconP2).changeIcon(id);
				}

			case 'CameraFlash':
				var v:Dynamic = parse(value1);
				var color:FlxColor = FlxColor.WHITE;
				var duration:Float = 1;
				var hud = false;
				if (v != null && !Std.isOfType(v, String) && !Std.isOfType(v, Float))
				{
					var c:Dynamic = ModFiles.field(v, 'color');
					if (c != null)
					{
						var rgb = ModFiles.colorToRGB(c, [255, 255, 255]);
						color = FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]);
					}
					duration = ModFiles.toFloat(ModFiles.field(v, 'duration'), 1);
					hud = ModFiles.toBool(ModFiles.field(v, 'hud'), false);
				}
				if (ClientPrefs.data.flashing) (hud ? game.camHUD : game.camGame).flash(color, duration / game.playbackRate, null, true);
		}
	}

	/** Makes props marked with "danceEvery" bop to the beat, like in V-Slice. */
	public static function onBeat(game:PlayState, beat:Int):Void
	{
		if (bopRate > 0 && beat % bopRate == 0 && game.camZooming && ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35)
		{
			FlxG.camera.zoom += 0.015 * bopIntensity;
			game.camHUD.zoom += 0.03 * bopIntensity;
		}
		if (meta == null) return;
		var dancers:Array<Dynamic> = ModFiles.field(meta, 'dancers');
		if (dancers == null) return;
		for (d in dancers)
		{
			var every = Std.int(ModFiles.toFloat(ModFiles.field(d, 'danceEvery'), 0));
			if (every <= 0 || beat % every != 0) continue;
			var name:String = ModFiles.field(d, 'name');
			var spr:Dynamic = game.variables.get(name);
			if (spr == null || !Std.isOfType(spr, ModchartSprite)) continue;
			var sprite:ModchartSprite = cast spr;
			if (sprite.animation.exists('danceLeft') && sprite.animation.exists('danceRight'))
			{
				var right = leftRight.get(name) == true;
				sprite.playAnim(right ? 'danceRight' : 'danceLeft', true);
				leftRight.set(name, !right);
			}
			else if (sprite.animation.exists('idle'))
				sprite.playAnim('idle', true);
		}
	}
}

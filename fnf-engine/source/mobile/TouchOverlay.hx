package mobile;

import flixel.input.keyboard.FlxKey;
import openfl.Lib;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

enum OverlayMode
{
	HIDDEN;
	MENU;
	GAMEPLAY;
}

private class TouchButton
{
	public var id:String;
	public var label:String;
	public var color:Int;
	public var x:Float = 0;
	public var y:Float = 0;
	public var w:Float = 0;
	public var h:Float = 0;
	public var round:Bool;
	public var arrow:Int = -1; // 0..3 draws an arrow (left, down, up, right)
	public var enabled:Bool = true;
	public var pressed:Bool = false;
	public var keyCode:Int = -1;

	public var shape:Shape = new Shape();
	public var text:TextField;

	public function new(id:String, label:String, color:Int, round:Bool, arrow:Int = -1)
	{
		this.id = id;
		this.label = label;
		this.color = color;
		this.round = round;
		this.arrow = arrow;
		if (label != null && label.length > 0)
		{
			text = new TextField();
			text.selectable = false;
			text.mouseEnabled = false;
			text.text = label;
		}
	}

	public inline function contains(px:Float, py:Float):Bool
		return px >= x && px <= x + w && py >= y && py <= y + h;
}

/**
 * On-screen controls drawn above the game.
 *
 * Touches are translated into the keyboard keys the player has bound in the
 * options, so menus, gameplay and mod scripts that read keys all work.
 *
 *  - Menus: D-pad on the left, A / B / C / X / Y on the right.
 *  - Gameplay: the layout picked in Options > Mobile Controls
 *    (hitbox lanes or arrow pads), a pause button and an optional SPACE button.
 *  - The Android back button acts as ESCAPE (back / pause).
 */
class TouchOverlay extends Sprite
{
	public static var instance(default, null):TouchOverlay;

	/** Mods or states can force the overlay off (e.g. custom touch menus). */
	public static var forceHidden:Bool = false;

	/** Set by the Mobile Controls menu to show the gameplay layout behind the menu buttons. */
	public static var previewGameplay:Bool = false;

	public var mode(default, null):OverlayMode = HIDDEN;

	var menuButtons:Array<TouchButton> = [];
	var gameButtons:Array<TouchButton> = [];
	var touches:Map<Int, TouchButton> = [];
	var lastW:Int = 0;
	var lastH:Int = 0;
	var dirty:Bool = true;
	var lastLayoutKey:String = '';

	static final NOTE_COLORS = [0xC24B99, 0x00FFFF, 0x12FA05, 0xF9393F];
	static final NOTE_IDS = ['note_left', 'note_down', 'note_up', 'note_right'];

	public static function init():Void
	{
		if (instance != null) return;
		MobileSettings.load();
		instance = new TouchOverlay();
		Lib.current.stage.addChild(instance);
	}

	/** Re-reads settings and redraws (after changing them in the options). */
	public static function refresh():Void
	{
		if (instance == null) return;
		instance.releaseAll();
		instance.lastLayoutKey = '';
		instance.dirty = true;
	}

	function new()
	{
		super();
		mouseEnabled = false;
		mouseChildren = false;

		Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;

		// Menu controls
		menuButtons.push(new TouchButton('ui_left', '', 0xC24B99, true, 0));
		menuButtons.push(new TouchButton('ui_down', '', 0x00FFFF, true, 1));
		menuButtons.push(new TouchButton('ui_up', '', 0x12FA05, true, 2));
		menuButtons.push(new TouchButton('ui_right', '', 0xF9393F, true, 3));
		menuButtons.push(new TouchButton('accept', 'A', 0x4CAF50, true));
		menuButtons.push(new TouchButton('back', 'B', 0xE53935, true));
		menuButtons.push(new TouchButton('ctrl', 'C', 0x9E9E9E, true));
		menuButtons.push(new TouchButton('reset', 'X', 0xFFB300, true));
		menuButtons.push(new TouchButton('space', 'Y', 0x42A5F5, true));

		// Gameplay: 4 hitbox lanes, two sets of 4 arrow buttons, pause, space
		for (i in 0...4) gameButtons.push(new TouchButton(NOTE_IDS[i], '', NOTE_COLORS[i], false));
		for (i in 0...4) gameButtons.push(new TouchButton(NOTE_IDS[i], '', NOTE_COLORS[i], true, i));
		for (i in 0...4) gameButtons.push(new TouchButton(NOTE_IDS[i], '', NOTE_COLORS[i], true, i));
		gameButtons.push(new TouchButton('pause', 'II', 0xFFFFFF, true));
		gameButtons.push(new TouchButton('space', 'SPACE', 0x42A5F5, true));

		for (b in gameButtons.concat(menuButtons))
		{
			addChild(b.shape);
			if (b.text != null) addChild(b.text);
		}

		var stage = Lib.current.stage;
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
		stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onHardwareKey, false, 100);
		stage.addEventListener(KeyboardEvent.KEY_UP, onHardwareKey, false, 100);
		// touches also arrive as mouse events: hide the ones that hit our buttons from the game
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 1000);
		stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseOther, false, 1000);
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 1000);
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	// ------------------------------------------------------------------ mode

	function detectMode():OverlayMode
	{
		if (forceHidden || FlxG.state == null) return HIDDEN;
		var state = FlxG.state;
		var name = Type.getClassName(Type.getClass(state));
		if (name == null || name.indexOf('editors') >= 0 || name == 'mobile.CopyState')
			return HIDDEN;
		if (Std.isOfType(state, PlayState))
		{
			var play:PlayState = cast state;
			if (state.subState == null && !play.inCutscene && !play.endingSong)
				return MobileSettings.mode == 'None' ? HIDDEN : GAMEPLAY;
		}
		return (MobileSettings.menuButtons || previewGameplay) ? MENU : HIDDEN;
	}

	function onFrame(_):Void
	{
		// keep the overlay above everything else that is added to the stage
		if (parent != null && parent.getChildIndex(this) != parent.numChildren - 1)
			parent.setChildIndex(this, parent.numChildren - 1);

		var newMode = detectMode();
		if (newMode != mode)
		{
			releaseAll();
			mode = newMode;
			dirty = true;
		}

		var stage = Lib.current.stage;
		var key = '${stage.stageWidth}x${stage.stageHeight}-${MobileSettings.mode}-${MobileSettings.spaceButton}-${MobileSettings.opacity}-$previewGameplay';
		if (key != lastLayoutKey)
		{
			lastLayoutKey = key;
			lastW = stage.stageWidth;
			lastH = stage.stageHeight;
			layout();
			dirty = true;
		}
		if (dirty) redraw();
	}

	function activeButtons():Array<TouchButton>
	{
		return switch (mode)
		{
			case MENU: menuButtons;
			case GAMEPLAY: gameButtons.filter(b -> b.enabled);
			default: [];
		}
	}

	// ---------------------------------------------------------------- layout

	function layout():Void
	{
		var w:Float = lastW;
		var h:Float = lastH;
		var unit:Float = Math.min(w, h) / 6.5; // button size

		// D-pad (bottom left)
		var cx = unit * 1.8;
		var cy = h - unit * 1.8;
		place(menuButtons[0], cx - unit * 1.05, cy, unit);
		place(menuButtons[1], cx, cy + unit * 1.05, unit);
		place(menuButtons[2], cx, cy - unit * 1.05, unit);
		place(menuButtons[3], cx + unit * 1.05, cy, unit);

		// Action buttons (bottom right)
		var rx = w - unit * 1.3;
		var ry = h - unit * 1.3;
		place(menuButtons[4], rx, ry - unit * 1.2, unit * 1.15); // A
		place(menuButtons[5], rx - unit * 1.25, ry, unit * 1.15); // B
		place(menuButtons[6], rx - unit * 2.4, ry - unit * 0.1, unit * 0.8); // C
		place(menuButtons[7], rx - unit * 1.25, ry - unit * 1.3, unit * 0.8); // X
		place(menuButtons[8], rx, ry - unit * 2.45, unit * 0.8); // Y

		// Gameplay layouts
		for (b in gameButtons) b.enabled = false;
		var lanes = gameButtons.slice(0, 4);
		var padA = gameButtons.slice(4, 8);
		var padB = gameButtons.slice(8, 12);
		var pause = gameButtons[12];
		var space = gameButtons[13];

		switch (MobileSettings.mode)
		{
			case 'Pad Right':
				placePad(padA, w - unit * 2.3, h - unit * 2.3, unit * 1.25);
			case 'Pad Left':
				placePad(padA, unit * 2.3, h - unit * 2.3, unit * 1.25);
			case 'Pad Duo':
				placePad(padA, unit * 2.3, h - unit * 2.3, unit * 1.15);
				placePad(padB, w - unit * 2.3, h - unit * 2.3, unit * 1.15);
			case 'None':
			default: // Hitbox
				var lane = w / 4;
				for (i in 0...4)
				{
					var b = lanes[i];
					b.x = lane * i;
					b.y = 0;
					b.w = lane;
					b.h = h;
					b.enabled = true;
				}
		}

		place(pause, w / 2, unit * 0.45, unit * 0.65);
		pause.enabled = MobileSettings.mode != 'None';
		space.w = unit * 1.6;
		space.h = unit * 0.55;
		space.x = w - space.w - unit * 0.2;
		space.y = unit * 0.15;
		space.enabled = MobileSettings.spaceButton && MobileSettings.mode != 'None';

		for (b in menuButtons.concat(gameButtons))
		{
			if (b.text == null) continue;
			b.text.defaultTextFormat = new TextFormat('_sans', Std.int(Math.max(12, b.h * 0.38)), 0xFFFFFF, true);
			b.text.text = b.label;
			b.text.width = b.w;
			b.text.height = b.h;
			b.text.autoSize = CENTER;
		}
	}

	/** Arrow buttons in a diamond around (cx, cy). */
	function placePad(pad:Array<TouchButton>, cx:Float, cy:Float, size:Float):Void
	{
		var d = size * 0.95;
		place(pad[0], cx - d, cy, size); // left
		place(pad[1], cx, cy + d, size); // down
		place(pad[2], cx, cy - d, size); // up
		place(pad[3], cx + d, cy, size); // right
		for (b in pad) b.enabled = true;
	}

	inline function place(b:TouchButton, centerX:Float, centerY:Float, size:Float):Void
	{
		b.w = size;
		b.h = size;
		b.x = centerX - size / 2;
		b.y = centerY - size / 2;
	}

	function redraw():Void
	{
		dirty = false;
		var active = activeButtons();
		var preview = (mode == MENU && previewGameplay) ? gameButtons.filter(b -> b.enabled) : [];
		var alphaMul = MobileSettings.opacity / 0.6;

		for (b in gameButtons.concat(menuButtons))
		{
			var isActive = active.indexOf(b) >= 0;
			var isPreview = !isActive && preview.indexOf(b) >= 0;
			var show = isActive || isPreview;
			b.shape.visible = show;
			if (b.text != null) b.text.visible = show;
			if (!show) continue;

			var mul = alphaMul * (isPreview ? 0.6 : 1);
			var g = b.shape.graphics;
			g.clear();
			if (b.round)
			{
				g.lineStyle(3, b.color, Math.min(1, (b.pressed ? 0.9 : 0.55) * mul));
				g.beginFill(b.color, Math.min(1, (b.pressed ? 0.45 : 0.18) * mul));
				g.drawCircle(b.x + b.w / 2, b.y + b.h / 2, b.w / 2);
				g.endFill();
				if (b.arrow >= 0) drawArrow(b, Math.min(1, (b.pressed ? 1 : 0.7) * mul));
			}
			else
			{
				// hitbox lane: thin border, colored flash while held
				g.lineStyle(2, b.color, Math.min(1, 0.3 * mul));
				g.beginFill(b.color, b.pressed ? Math.min(1, 0.25 * Math.max(mul, 0.5)) : 0.0);
				g.drawRect(b.x + 2, b.y + 2, b.w - 4, b.h - 4);
				g.endFill();
			}

			if (b.text != null)
			{
				b.text.x = b.x + (b.w - b.text.width) / 2;
				b.text.y = b.y + (b.h - b.text.height) / 2;
				b.text.alpha = Math.min(1, (b.pressed ? 1 : 0.75) * mul);
			}
		}
	}

	function drawArrow(b:TouchButton, alpha:Float):Void
	{
		var g = b.shape.graphics;
		var cx = b.x + b.w / 2;
		var cy = b.y + b.h / 2;
		var s = b.w * 0.22;
		// arrow pointing up, rotated per direction
		var pts:Array<Array<Float>> = [
			[0, -s * 1.2], [s * 1.1, s * 0.2], [s * 0.4, s * 0.2], [s * 0.4, s * 1.1],
			[-s * 0.4, s * 1.1], [-s * 0.4, s * 0.2], [-s * 1.1, s * 0.2]
		];
		var angle = switch (b.arrow)
		{
			case 0: -Math.PI / 2;
			case 1: Math.PI;
			case 3: Math.PI / 2;
			default: 0.0;
		}
		var cos = Math.cos(angle);
		var sin = Math.sin(angle);
		g.lineStyle();
		g.beginFill(0xFFFFFF, alpha);
		for (i => p in pts)
		{
			var px = cx + p[0] * cos - p[1] * sin;
			var py = cy + p[0] * sin + p[1] * cos;
			if (i == 0) g.moveTo(px, py) else g.lineTo(px, py);
		}
		g.endFill();
	}

	// ----------------------------------------------------------------- input

	function buttonAt(x:Float, y:Float):TouchButton
	{
		var active = activeButtons();
		// round buttons are checked first so they win over lanes
		var i = active.length;
		while (i-- > 0)
		{
			var b = active[i];
			if (b.round)
			{
				var dx = x - (b.x + b.w / 2);
				var dy = y - (b.y + b.h / 2);
				var r = b.w * 0.6; // slightly forgiving
				if (dx * dx + dy * dy <= r * r) return b;
			}
		}
		for (b in active)
			if (!b.round && b.contains(x, y)) return b;
		return null;
	}

	inline function slidable(b:TouchButton):Bool
		return !b.round || b.arrow >= 0;

	function onTouchBegin(e:TouchEvent):Void
	{
		if (mode == HIDDEN) return;
		var b = buttonAt(e.stageX, e.stageY);
		if (b == null) return;
		touches.set(e.touchPointID, b);
		press(b);
	}

	function onTouchMove(e:TouchEvent):Void
	{
		if (mode == HIDDEN || !touches.exists(e.touchPointID)) return;
		var current = touches.get(e.touchPointID);
		var b = buttonAt(e.stageX, e.stageY);
		// allow sliding between lanes / arrows
		if (b != current && b != null && slidable(current) && slidable(b))
		{
			touches.set(e.touchPointID, b);
			releaseIfUnused(current);
			press(b);
		}
	}

	function onTouchEnd(e:TouchEvent):Void
	{
		var b = touches.get(e.touchPointID);
		if (b == null) return;
		touches.remove(e.touchPointID);
		releaseIfUnused(b);
	}

	function releaseIfUnused(b:TouchButton):Void
	{
		for (other in touches)
			if (other == b) return;
		release(b);
	}

	function press(b:TouchButton):Void
	{
		if (b.pressed) return;
		b.keyCode = keyFor(b.id);
		// two buttons can map to the same key (Pad Duo): only send it once
		var already = keyHeldByOther(b);
		b.pressed = true;
		if (!already) sendKey(b.keyCode, true);
		dirty = true;
	}

	function release(b:TouchButton):Void
	{
		if (!b.pressed) return;
		b.pressed = false;
		if (!keyHeldByOther(b)) sendKey(b.keyCode, false);
		dirty = true;
	}

	function keyHeldByOther(b:TouchButton):Bool
	{
		for (o in gameButtons.concat(menuButtons))
			if (o != b && o.pressed && o.keyCode == b.keyCode) return true;
		return false;
	}

	public function releaseAll():Void
	{
		touches.clear();
		var sent:Array<Int> = [];
		for (b in gameButtons.concat(menuButtons))
		{
			if (!b.pressed) continue;
			b.pressed = false;
			if (!sent.contains(b.keyCode))
			{
				sent.push(b.keyCode);
				sendKey(b.keyCode, false);
			}
		}
		dirty = true;
	}

	/** Picks the key to simulate for an action, respecting the player's binds. */
	function keyFor(action:String):Int
	{
		var preferred:Null<FlxKey> = switch (action)
		{
			case 'accept': FlxKey.ENTER;
			case 'back': FlxKey.ESCAPE;
			case 'pause': FlxKey.ENTER;
			case 'reset': FlxKey.R;
			case 'ui_left' | 'note_left': FlxKey.LEFT;
			case 'ui_down' | 'note_down': FlxKey.DOWN;
			case 'ui_up' | 'note_up': FlxKey.UP;
			case 'ui_right' | 'note_right': FlxKey.RIGHT;
			case 'ctrl': return FlxKey.CONTROL;
			case 'space': return FlxKey.SPACE;
			default: null;
		}

		var binds:Array<FlxKey> = ClientPrefs.keyBinds.get(action);
		if (binds != null)
		{
			if (preferred != null && binds.contains(preferred)) return preferred;
			for (k in binds)
				if (k != FlxKey.NONE) return k;
		}
		return preferred != null ? preferred : -1;
	}

	var mouseBlocked:Bool = false;

	function onMouseDown(e:MouseEvent):Void
	{
		if (mode == HIDDEN) return;
		if (buttonAt(e.stageX, e.stageY) != null)
		{
			mouseBlocked = true;
			e.stopImmediatePropagation();
		}
	}

	function onMouseOther(e:MouseEvent):Void
	{
		if (mouseBlocked) e.stopImmediatePropagation();
	}

	function onMouseUp(e:MouseEvent):Void
	{
		if (!mouseBlocked) return;
		mouseBlocked = false;
		e.stopImmediatePropagation();
	}

	var sending:Bool = false;

	function sendKey(keyCode:Int, down:Bool):Void
	{
		if (keyCode < 0) return;
		sending = true;
		var type = down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP;
		Lib.current.stage.dispatchEvent(new KeyboardEvent(type, true, false, 0, keyCode));
		sending = false;
	}

	/** Turns the Android back button into ESCAPE so it works as back/pause. */
	function onHardwareKey(e:KeyboardEvent):Void
	{
		if (sending) return;
		#if android
		if (e.keyCode == 0x4000010E) // lime APP_CONTROL_BACK
		{
			e.stopImmediatePropagation();
			e.preventDefault();
			sendKey(FlxKey.ESCAPE, e.type == KeyboardEvent.KEY_DOWN);
		}
		#end
	}
}

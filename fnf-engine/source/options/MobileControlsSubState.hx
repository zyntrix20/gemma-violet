package options;

import mobile.MobileSettings;
import mobile.TouchOverlay;

/**
 * Options > Mobile Controls: choose the gameplay layout (hitbox or arrow
 * pads), how visible the controls are and which extra buttons to show.
 * The chosen layout is previewed on screen while this menu is open.
 */
class MobileControlsSubState extends MusicBeatSubstate
{
	static final ROWS:Array<String> = ['Controls', 'Opacity', 'SPACE button', 'Menu buttons'];

	var curRow:Int = 0;
	var rowTexts:Array<FlxText> = [];
	var infoText:FlxText;
	var bg:FlxSprite;

	public function new()
	{
		super();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.55;
		bg.scrollFactor.set();
		add(bg);

		var title = new FlxText(0, 30, FlxG.width, 'MOBILE CONTROLS', 40);
		title.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.scrollFactor.set();
		add(title);

		for (i in 0...ROWS.length)
		{
			var t = new FlxText(0, 120 + i * 56, FlxG.width, '', 30);
			t.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.borderSize = 2;
			t.scrollFactor.set();
			add(t);
			rowTexts.push(t);
		}

		infoText = new FlxText(140, 360, FlxG.width - 280, '', 20);
		infoText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.scrollFactor.set();
		add(infoText);

		TouchOverlay.previewGameplay = true;
		TouchOverlay.refresh();
		updateTexts();
	}

	function rowValue(i:Int):String
	{
		return switch (i)
		{
			case 0: MobileSettings.mode;
			case 1: Std.int(Math.round(MobileSettings.opacity * 100)) + '%';
			case 2: MobileSettings.spaceButton ? 'ON' : 'OFF';
			default: MobileSettings.menuButtons ? 'ON' : 'OFF';
		}
	}

	function updateTexts()
	{
		for (i => t in rowTexts)
		{
			var selected = i == curRow;
			t.text = (selected ? '< ' : '') + ROWS[i] + ': ' + rowValue(i) + (selected ? ' >' : '');
			t.color = selected ? FlxColor.YELLOW : FlxColor.WHITE;
			t.alpha = selected ? 1 : 0.7;
		}

		var info = switch (curRow)
		{
			case 0: MobileSettings.MODE_INFO[MobileSettings.MODES.indexOf(MobileSettings.mode)];
			case 1: 'How visible the touch controls are.';
			case 2: 'Extra SPACE button in songs, for mods with dodge or attack mechanics.';
			default: 'D-pad and A/B buttons in menus. Turn off only if you use a keyboard or gamepad.';
		}
		infoText.text = info + '\n\nUP/DOWN: choose   LEFT/RIGHT: change   B: save and exit';
	}

	function change(dir:Int)
	{
		switch (curRow)
		{
			case 0:
				var modes = MobileSettings.MODES;
				var i = FlxMath.wrap(modes.indexOf(MobileSettings.mode) + dir, 0, modes.length - 1);
				MobileSettings.mode = modes[i];
			case 1:
				MobileSettings.opacity = Math.max(0.1, Math.min(1, Math.round((MobileSettings.opacity + dir * 0.1) * 10) / 10));
			case 2:
				MobileSettings.spaceButton = !MobileSettings.spaceButton;
			default:
				MobileSettings.menuButtons = !MobileSettings.menuButtons;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		TouchOverlay.refresh();
		updateTexts();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.UI_UP_P)
		{
			curRow = FlxMath.wrap(curRow - 1, 0, ROWS.length - 1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			updateTexts();
		}
		if (controls.UI_DOWN_P)
		{
			curRow = FlxMath.wrap(curRow + 1, 0, ROWS.length - 1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			updateTexts();
		}
		if (controls.UI_LEFT_P) change(-1);
		if (controls.UI_RIGHT_P || controls.ACCEPT) change(1);

		if (controls.BACK)
		{
			MobileSettings.save();
			TouchOverlay.previewGameplay = false;
			TouchOverlay.refresh();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
		}
	}

	override function destroy()
	{
		TouchOverlay.previewGameplay = false;
		super.destroy();
	}
}

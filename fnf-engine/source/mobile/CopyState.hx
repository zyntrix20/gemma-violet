package mobile;

import flixel.FlxState;
import flixel.ui.FlxBar;

/**
 * Shown once after install/update while the engine unpacks its built-in
 * assets from the APK into the storage folder. Copies a few files per frame
 * so the screen keeps updating.
 */
class CopyState extends FlxState
{
	var files:Array<String>;
	var index:Int = 0;
	var failed:Int = 0;
	var progress:Float = 0;
	var label:FlxText;

	override function create()
	{
		super.create();
		files = StorageSetup.assetList();

		var title = new FlxText(0, FlxG.height / 2 - 70, FlxG.width, 'Preparing the engine...', 32);
		title.alignment = CENTER;
		add(title);

		var bar = new FlxBar(FlxG.width * 0.15, FlxG.height / 2, LEFT_TO_RIGHT, Std.int(FlxG.width * 0.7), 24, this, 'progress', 0, 1);
		bar.createFilledBar(0xFF303030, 0xFFB57EDC);
		add(bar);

		label = new FlxText(0, FlxG.height / 2 + 40, FlxG.width, '', 20);
		label.alignment = CENTER;
		add(label);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (files == null) return;

		var start = haxe.Timer.stamp();
		// spend ~25ms per frame copying
		while (index < files.length && haxe.Timer.stamp() - start < 0.025)
		{
			if (!StorageSetup.copyAsset(files[index])) failed++;
			index++;
		}

		progress = files.length > 0 ? index / files.length : 1;
		label.text = '$index / ${files.length}' + (failed > 0 ? '  ($failed skipped)' : '');

		if (index >= files.length)
		{
			files = null;
			StorageSetup.markCopied();
			#if LUA_ALLOWED
			Mods.pushGlobalMods();
			#end
			Mods.loadTopMod();
			FlxG.switchState(() -> new states.TitleState());
		}
	}
}

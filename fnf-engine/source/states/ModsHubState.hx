package states;

import flixel.ui.FlxBar;
import flixel.util.FlxSpriteUtil;
import mobile.NativeBridge;
import modding.ModImporter;

/**
 * "Mods" screen: import a mod archive from the device, then jump straight
 * to Freeplay. Also links to Psych's mod manager (enable / disable / order).
 */
class ModsHubState extends MusicBeatState
{
	static final OPTIONS:Array<String> = ['IMPORT MOD (.ZIP)', 'MANAGE MODS', 'FREEPLAY', 'BACK'];

	var bg:FlxSprite;
	var buttons:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var curSelected:Int = 0;

	var modListText:FlxText;
	var hintText:FlxText;

	// import overlay
	var overlay:FlxSprite;
	var statusText:FlxText;
	var progressBar:FlxBar;
	var progressValue:Float = 0;

	var picking:Bool = false;
	var importer:ModImporter = null;
	var importedZip:String = null;
	var showingResult:Bool = false;
	var lastImport:ImportResult = null;

	override function create()
	{
		super.create();
		persistentUpdate = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Mods Menu", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF6A4BAE;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		var title = new Alphabet(60, 40, 'MODS', true);
		add(title);

		for (i => option in OPTIONS)
		{
			var btn = FlxSpriteUtil.drawRoundRect(new FlxSprite(60, 170 + i * 105).makeGraphic(520, 85, FlxColor.TRANSPARENT), 0, 0, 520, 85, 20, 20, FlxColor.BLACK);
			btn.alpha = 0.55;
			add(btn);
			buttons.push(btn);

			var txt = new FlxText(btn.x, btn.y + 24, 520, option, 32);
			txt.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(txt);
			labels.push(txt);
		}

		var panel = FlxSpriteUtil.drawRoundRect(new FlxSprite(620, 40).makeGraphic(620, 600, FlxColor.TRANSPARENT), 0, 0, 620, 600, 20, 20, FlxColor.BLACK);
		panel.alpha = 0.5;
		add(panel);

		modListText = new FlxText(645, 60, 570, '', 22);
		modListText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(modListText);

		hintText = new FlxText(20, FlxG.height - 66, FlxG.width - 40, '', 16);
		hintText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(hintText);

		overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		overlay.alpha = 0.85;
		overlay.visible = false;
		add(overlay);

		statusText = new FlxText(80, 160, FlxG.width - 160, '', 26);
		statusText.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		statusText.visible = false;
		add(statusText);

		progressBar = new FlxBar(FlxG.width * 0.15, 110, LEFT_TO_RIGHT, Std.int(FlxG.width * 0.7), 24, this, 'progressValue', 0, 1);
		progressBar.createFilledBar(0xFF303030, 0xFFB57EDC);
		progressBar.visible = false;
		add(progressBar);

		refreshModList();
		changeSelection();
	}

	function refreshModList()
	{
		Mods.updatedOnState = false;
		var list = Mods.parseList();
		var text = 'INSTALLED MODS (${list.all.length})\n\n';
		if (list.all.length == 0)
			text += 'No mods yet.\n\nTap "IMPORT MOD" and pick a .zip file.\nPsych Engine, V-Slice and Codename Engine\nmods are supported.';
		else
		{
			var shown = 0;
			for (mod in list.all)
			{
				if (shown >= 16)
				{
					text += '...and ${list.all.length - shown} more\n';
					break;
				}
				var pack:Dynamic = Mods.getPack(mod);
				var name:String = (pack != null && pack.name != null) ? pack.name : mod;
				var on = list.enabled.contains(mod);
				text += (on ? '+ ' : '- ') + name + (on ? '' : ' (disabled)') + '\n';
				shown++;
			}
		}
		modListText.text = text;

		#if sys
		hintText.text = 'You can also copy mod folders into: ' + haxe.io.Path.normalize(Sys.getCwd() + '/' + Paths.mods());
		#end
	}

	function changeSelection(change:Int = 0)
	{
		if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		curSelected = FlxMath.wrap(curSelected + change, 0, OPTIONS.length - 1);
		for (i => btn in buttons)
		{
			var selected = i == curSelected;
			btn.alpha = selected ? 0.85 : 0.45;
			btn.color = selected ? 0xFF9B59D0 : FlxColor.WHITE;
			labels[i].alpha = selected ? 1 : 0.7;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (picking)
		{
			updatePicker();
			return;
		}
		if (importer != null)
		{
			updateImport();
			return;
		}
		if (showingResult)
		{
			if (controls.ACCEPT || FlxG.mouse.justPressed)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				hideOverlay();
				if (lastImport != null && lastImport.success && hasSongs(lastImport)) openFreeplay();
			}
			else if (controls.BACK)
				hideOverlay();
			return;
		}

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);

		if (FlxG.mouse.justPressed)
		{
			for (i => btn in buttons)
			{
				if (FlxG.mouse.overlaps(btn))
				{
					curSelected = i;
					changeSelection();
					select();
					return;
				}
			}
		}

		if (controls.ACCEPT) select();
		else if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}
	}

	function select()
	{
		switch (curSelected)
		{
			case 0:
				FlxG.sound.play(Paths.sound('confirmMenu'));
				startPicker();
			case 1:
				FlxG.sound.play(Paths.sound('confirmMenu'));
				MusicBeatState.switchState(new ModsMenuState());
			case 2:
				FlxG.sound.play(Paths.sound('confirmMenu'));
				openFreeplay();
			default:
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
		}
	}

	function openFreeplay()
	{
		Mods.updatedOnState = false;
		Mods.loadTopMod();
		MusicBeatState.switchState(new FreeplayState());
	}

	// ---------------------------------------------------------------- import

	function showOverlay(text:String, showBar:Bool)
	{
		overlay.visible = statusText.visible = true;
		progressBar.visible = showBar;
		statusText.size = 26;
		statusText.y = 160;
		statusText.text = text;
	}

	function hideOverlay()
	{
		overlay.visible = statusText.visible = progressBar.visible = false;
		showingResult = false;
	}

	function startPicker()
	{
		picking = true;
		showOverlay('Choose a mod archive (.zip)...', false);
		NativeBridge.pickModArchive();
	}

	function updatePicker()
	{
		switch (NativeBridge.pollPick())
		{
			case PICKING:
				statusText.text = 'Choose a mod archive (.zip)...';
			case COPYING:
				statusText.text = 'Reading the file...';
			case DONE(path):
				picking = false;
				NativeBridge.resetPick();
				startImport(path);
			case CANCELLED:
				picking = false;
				NativeBridge.resetPick();
				hideOverlay();
			case ERROR(message):
				picking = false;
				NativeBridge.resetPick();
				showResultText('Could not open the file.\n\n$message\n\nPress A to continue.', null);
			case IDLE:
				picking = false;
				hideOverlay();
		}
	}

	function startImport(path:String)
	{
		var lower = path.toLowerCase();
		if (lower.endsWith('.rar') || lower.endsWith('.7z'))
		{
			showResultText('.rar and .7z archives are not supported.\nPlease re-pack the mod as a .zip file.\n\nPress A to continue.', null);
			return;
		}
		importedZip = path;
		progressValue = 0;
		showOverlay('Importing...', true);
		importer = new ModImporter(path, Paths.mods());
		importer.runAsync();
	}

	function updateImport()
	{
		progressValue = importer.progress;
		statusText.text = importer.status;
		if (!importer.finished) return;

		var result = importer.result;
		importer = null;

		// the copy in import/ is no longer needed
		#if sys
		try
		{
			if (importedZip != null && importedZip.indexOf('/import/') >= 0 && FileSystem.exists(importedZip))
				FileSystem.deleteFile(importedZip);
		}
		catch (e:Dynamic) {}
		#end
		importedZip = null;

		refreshModList();
		if (!result.success)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			showResultText('IMPORT FAILED\n\n${result.error}\n\nPress A to continue.', result);
			return;
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));
		var text = 'IMPORT COMPLETE\n\n';
		for (mod in result.mods)
		{
			text += '"${mod.name}" (${ModImporter.formatName(mod.format)})\n';
			if (mod.songs.length > 0)
			{
				var list = mod.songs.slice(0, 8).join(', ');
				if (mod.songs.length > 8) list += ' +${mod.songs.length - 8} more';
				text += '${mod.songs.length} song(s): $list\n';
			}
			else text += 'No songs found (this may be a script or skin mod).\n';
			for (w in mod.warnings.slice(0, 3))
				text += '! $w\n';
			if (mod.warnings.length > 3) text += '! ...${mod.warnings.length - 3} more notes\n';
			text += '\n';
		}
		text += hasSongs(result) ? 'Press A to open Freeplay, B to stay here.' : 'Press A to continue.';
		showResultText(text, result);
	}

	function hasSongs(result:ImportResult):Bool
	{
		for (m in result.mods)
			if (m.songs.length > 0) return true;
		return false;
	}

	function showResultText(text:String, result:ImportResult)
	{
		lastImport = result;
		showOverlay(text, false);
		statusText.size = text.length > 500 ? 18 : 24;
		statusText.y = Math.max(20, (FlxG.height - statusText.height) / 2);
		showingResult = true;
	}
}

package states;

import flixel.util.FlxSpriteUtil;
import modding.ModFiles;
import openfl.events.KeyboardEvent;
import openfl.display.BitmapData;

private typedef ModInfo =
{
	var folder:String;
	var name:String;
	var description:String;
	var format:String;
	var songs:Array<String>;
	var enabled:Bool;
	var size:Float; // bytes, -1 = not computed yet
}

/**
 * "My mods": every installed mod with its icon, format, songs and size.
 * Search by name, enable / disable, delete, or jump to Freeplay.
 */
class ModListState extends MusicBeatState
{
	static final ACTIONS:Array<String> = ['PLAY', 'ON / OFF', 'DELETE', 'SEARCH'];
	static final VISIBLE_ROWS:Int = 11;

	var all:Array<ModInfo> = [];
	var shown:Array<ModInfo> = [];
	var curSelected:Int = 0;
	var scroll:Int = 0;
	var query:String = '';
	var searching:Bool = false;
	var confirmDelete:Bool = false;

	var rows:Array<FlxText> = [];
	var rowBgs:Array<FlxSprite> = [];
	var icon:FlxSprite;
	var infoTitle:FlxText;
	var infoText:FlxText;
	var searchText:FlxText;
	var actionBtns:Array<FlxSprite> = [];
	var actionLabels:Array<FlxText> = [];
	var promptText:FlxText;

	override function create()
	{
		super.create();

		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF4B3A82;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		var listBg = FlxSpriteUtil.drawRoundRect(new FlxSprite(30, 30).makeGraphic(520, 660, FlxColor.TRANSPARENT), 0, 0, 520, 660, 20, 20, FlxColor.BLACK);
		listBg.alpha = 0.55;
		add(listBg);

		searchText = new FlxText(50, 44, 480, '', 22);
		searchText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(searchText);

		for (i in 0...VISIBLE_ROWS)
		{
			var rb = new FlxSprite(42, 86 + i * 54).makeGraphic(496, 48, FlxColor.WHITE);
			rb.alpha = 0;
			add(rb);
			rowBgs.push(rb);

			var t = new FlxText(56, 96 + i * 54, 470, '', 24);
			t.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(t);
			rows.push(t);
		}

		var infoBg = FlxSpriteUtil.drawRoundRect(new FlxSprite(580, 30).makeGraphic(670, 660, FlxColor.TRANSPARENT), 0, 0, 670, 660, 20, 20, FlxColor.BLACK);
		infoBg.alpha = 0.55;
		add(infoBg);

		icon = new FlxSprite(605, 55);
		add(icon);

		infoTitle = new FlxText(775, 60, 450, '', 30);
		infoTitle.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(infoTitle);

		infoText = new FlxText(605, 220, 620, '', 20);
		infoText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(infoText);

		for (i => label in ACTIONS)
		{
			var b = FlxSpriteUtil.drawRoundRect(new FlxSprite(605 + i * 158, 600).makeGraphic(148, 66, FlxColor.TRANSPARENT), 0, 0, 148, 66, 16, 16, FlxColor.WHITE);
			b.color = switch (i)
			{
				case 0: 0xFF3E9B4F;
				case 1: 0xFF4A6FD1;
				case 2: 0xFFC0392B;
				default: 0xFF7D5BA6;
			}
			add(b);
			actionBtns.push(b);
			var t = new FlxText(b.x, b.y + 20, 148, label, 22);
			t.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(t);
			actionLabels.push(t);
		}

		promptText = new FlxText(605, 548, 620, 'A: play   X: on/off   C: delete   Y: search   B: back', 16);
		promptText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(promptText);

		loadMods();
		applyFilter();
	}

	// ---------------------------------------------------------------- data

	function loadMods()
	{
		all = [];
		Mods.updatedOnState = false;
		var list = Mods.parseList();
		for (folder in list.all)
		{
			var dir = Paths.mods(folder) + '/';
			var pack:Dynamic = Mods.getPack(folder);
			var info:Dynamic = ModFiles.readJson(dir + '_import.json');
			var format:String = info != null ? ModFiles.field(info, 'format', 'Psych Engine') : guessFormat(dir);
			all.push({
				folder: folder,
				name: (pack != null && pack.name != null && Std.string(pack.name).length > 0) ? pack.name : folder,
				description: pack != null && pack.description != null ? pack.description : '',
				format: format,
				songs: listSongs(dir),
				enabled: list.enabled.contains(folder),
				size: -1
			});
		}
	}

	static function guessFormat(dir:String):String
	{
		if (ModFiles.exists(dir + '_polymod_meta.json') || ModFiles.isDir(dir + '_vslice_scripts')) return 'V-Slice';
		if (ModFiles.isDir(dir + '_codename_scripts')) return 'Codename Engine';
		return 'Psych Engine';
	}

	static function listSongs(dir:String):Array<String>
	{
		var names:Array<String> = [];
		for (file in ModFiles.list(dir + 'weeks'))
		{
			if (!file.toLowerCase().endsWith('.json')) continue;
			var week:Dynamic = ModFiles.readJson(dir + 'weeks/' + file);
			var songs:Array<Dynamic> = week != null ? ModFiles.field(week, 'songs', []) : [];
			for (s in songs)
			{
				var n:String = Std.isOfType(s, Array) ? Std.string(s[0]) : Std.string(s);
				if (!names.contains(n)) names.push(n);
			}
		}
		return names;
	}

	static function folderSize(path:String):Float
	{
		var total:Float = 0;
		try
		{
			for (item in FileSystem.readDirectory(path))
			{
				var p = path + '/' + item;
				if (FileSystem.isDirectory(p)) total += folderSize(p);
				else total += FileSystem.stat(p).size;
			}
		}
		catch (e:Dynamic) {}
		return total;
	}

	function applyFilter()
	{
		var q = query.toLowerCase();
		shown = q.length == 0 ? all.copy() : all.filter(m -> m.name.toLowerCase().indexOf(q) >= 0 || m.folder.toLowerCase().indexOf(q) >= 0
			|| m.songs.filter(s -> s.toLowerCase().indexOf(q) >= 0).length > 0);
		curSelected = 0;
		scroll = 0;
		refresh();
	}

	// ------------------------------------------------------------------ ui

	function current():ModInfo
		return shown.length > 0 ? shown[curSelected] : null;

	function refresh()
	{
		searchText.text = searching ? 'Search: $query|' : (query.length > 0 ? 'Search: "$query" (${shown.length} found)' : 'MY MODS (${all.length})');

		if (curSelected < scroll) scroll = curSelected;
		if (curSelected >= scroll + VISIBLE_ROWS) scroll = curSelected - VISIBLE_ROWS + 1;
		for (i in 0...VISIBLE_ROWS)
		{
			var idx = scroll + i;
			var mod = idx < shown.length ? shown[idx] : null;
			rows[i].text = mod == null ? '' : (mod.enabled ? '' : '[OFF] ') + mod.name;
			rows[i].color = mod != null && !mod.enabled ? FlxColor.GRAY : FlxColor.WHITE;
			rowBgs[i].alpha = (mod != null && idx == curSelected) ? 0.25 : 0;
			rowBgs[i].color = 0xFFB57EDC;
		}

		var mod = current();
		if (mod == null)
		{
			icon.visible = false;
			infoTitle.text = all.length == 0 ? 'No mods installed' : 'Nothing found';
			infoText.text = all.length == 0 ? 'Go back and use "IMPORT MOD (.ZIP)" to add one.' : 'Try another search.';
			return;
		}

		if (mod.size < 0) mod.size = folderSize(Paths.mods(mod.folder));
		loadIcon(mod);

		infoTitle.text = mod.name;
		var text = 'Format: ${mod.format}\n';
		text += 'Status: ${mod.enabled ? "enabled" : "disabled"}\n';
		text += 'Size: ${Std.int(mod.size / 1024 / 1024 * 10) / 10} MB\n';
		text += 'Folder: mods/${mod.folder}\n\n';
		if (mod.songs.length > 0)
		{
			var list = mod.songs.slice(0, 10).join(', ');
			if (mod.songs.length > 10) list += ' +${mod.songs.length - 10} more';
			text += '${mod.songs.length} song(s): $list\n\n';
		}
		else text += 'No songs (script, skin or character mod).\n\n';
		if (mod.description.length > 0) text += mod.description;
		if (confirmDelete) text = 'DELETE "${mod.name}"?\n\nAll its files will be removed from the phone.\n\nPress A to delete, B to cancel.';
		infoText.text = text;
	}

	function loadIcon(mod:ModInfo)
	{
		var file = Paths.mods(mod.folder + '/pack.png');
		var bmp:BitmapData = FileSystem.exists(file) ? Paths.bitmapFromFile(file) : null;
		if (bmp != null)
		{
			icon.loadGraphic(bmp, true, 150, 150);
			if (icon.width > 150 || icon.height > 150) icon.setGraphicSize(150, 150);
		}
		else icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		icon.updateHitbox();
		icon.setPosition(605, 55);
		icon.visible = true;
	}

	// ---------------------------------------------------------------- input

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (searching)
		{
			// typed text arrives through the window text input; a tap on the game ends the search
			if (FlxG.mouse.justPressed) stopSearch();
			return;
		}

		if (confirmDelete)
		{
			if (controls.ACCEPT) deleteCurrent();
			else if (controls.BACK)
			{
				confirmDelete = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				refresh();
			}
			return;
		}

		if (controls.UI_UP_P) moveSelection(-1);
		if (controls.UI_DOWN_P) moveSelection(1);

		if (FlxG.mouse.justPressed)
		{
			for (i => b in actionBtns)
				if (FlxG.mouse.overlaps(b))
				{
					doAction(i);
					return;
				}
			for (i => rb in rowBgs)
				if (FlxG.mouse.overlaps(rb) && scroll + i < shown.length)
				{
					if (curSelected == scroll + i) doAction(0);
					else
					{
						curSelected = scroll + i;
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
						refresh();
					}
					return;
				}
		}

		if (controls.ACCEPT) doAction(0);
		else if (controls.RESET) doAction(1);
		else if (FlxG.keys.justPressed.CONTROL || FlxG.keys.justPressed.DELETE) doAction(2);
		else if (FlxG.keys.justPressed.SPACE) doAction(3);
		else if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new ModsHubState());
		}
	}

	function moveSelection(dir:Int)
	{
		if (shown.length == 0) return;
		curSelected = FlxMath.wrap(curSelected + dir, 0, shown.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		refresh();
	}

	function doAction(i:Int)
	{
		var mod = current();
		switch (i)
		{
			case 0: // play
				if (mod == null) return;
				FlxG.sound.play(Paths.sound('confirmMenu'));
				if (!mod.enabled) setEnabled(mod, true);
				Mods.currentModDirectory = mod.folder;
				Mods.updatedOnState = false;
				MusicBeatState.switchState(new FreeplayState());
			case 1: // on / off
				if (mod == null) return;
				setEnabled(mod, !mod.enabled);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				refresh();
			case 2: // delete
				if (mod == null) return;
				confirmDelete = true;
				FlxG.sound.play(Paths.sound('scrollMenu'));
				refresh();
			default: // search
				startSearch();
		}
	}

	function setEnabled(mod:ModInfo, on:Bool)
	{
		mod.enabled = on;
		var lines:Array<String> = [];
		for (m in all) lines.push(m.folder + '|' + (m.enabled ? '1' : '0'));
		File.saveContent('modsList.txt', lines.join('\n'));
		Mods.updatedOnState = false;
	}

	function deleteCurrent()
	{
		var mod = current();
		confirmDelete = false;
		if (mod == null) return;
		try
		{
			ModFiles.deleteRecursive(Paths.mods(mod.folder));
		}
		catch (e:Dynamic)
		{
			infoText.text = 'Could not delete: $e';
			return;
		}
		all.remove(mod);
		setEnabled(mod, false); // rewrites modsList.txt without it
		FlxG.sound.play(Paths.sound('cancelMenu'));
		applyFilter();
	}

	// --------------------------------------------------------------- search

	function startSearch()
	{
		searching = true;
		FlxG.sound.play(Paths.sound('scrollMenu'));
		var window = FlxG.stage.window;
		window.textInputEnabled = true;
		window.onTextInput.add(onTextInput);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onSearchKey, false, 50);
		#if mobile mobile.TouchOverlay.forceHidden = true; #end
		refresh();
	}

	function stopSearch()
	{
		if (!searching) return;
		searching = false;
		var window = FlxG.stage.window;
		window.onTextInput.remove(onTextInput);
		window.textInputEnabled = false;
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onSearchKey);
		#if mobile mobile.TouchOverlay.forceHidden = false; #end
		applyFilter();
	}

	function onTextInput(text:String)
	{
		query += text;
		applyFilter();
	}

	function onSearchKey(e:KeyboardEvent)
	{
		switch (e.keyCode)
		{
			case 8: // backspace
				if (query.length > 0) query = query.substr(0, query.length - 1);
				applyFilter();
			case 13 | 27 | 0x4000010E: // enter, escape, android back
				e.stopImmediatePropagation();
				stopSearch();
			default:
		}
	}

	override function destroy()
	{
		stopSearch();
		super.destroy();
	}
}

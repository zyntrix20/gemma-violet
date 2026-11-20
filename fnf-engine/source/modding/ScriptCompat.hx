package modding;

#if HSCRIPT_ALLOWED
import psychlua.CompatHScript;
import crowplexus.iris.Iris;
import crowplexus.hscript.Printer;
#end

/**
 * Loads the scripts of converted V-Slice / Codename mods into the song.
 *
 * The converters write `_compat/scripts.json` listing which script belongs to
 * which song, stage, character, event or note type. This picks the ones that
 * apply to the current song and runs them through CompatHScript.
 */
class ScriptCompat
{
	public static function load(game:PlayState):Void
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED)
		var mod = Mods.currentModDirectory;
		if (mod == null || mod.length == 0) return;
		var dir = Paths.mods(mod) + '/';
		var manifest:Dynamic = ModFiles.readJson(dir + '_compat/scripts.json');
		if (manifest == null) return;

		var engine = ModFiles.field(manifest, 'engine', 'codename') == 'vslice' ? VSLICE : CODENAME;
		var files:Array<String> = [];
		function addAll(list:Dynamic)
		{
			if (list == null) return;
			var arr:Array<Dynamic> = cast list;
			for (f in arr)
			{
				var s = Std.string(f);
				if (!files.contains(s)) files.push(s);
			}
		}
		function fromMap(mapName:String, key:String)
		{
			var map:Dynamic = ModFiles.field(manifest, mapName);
			if (map == null || key == null) return;
			addAll(ModFiles.field(map, key));
			// case-insensitive match
			for (k in Reflect.fields(map))
				if (k.toLowerCase() == key.toLowerCase() && k != key) addAll(Reflect.field(map, k));
		}

		addAll(ModFiles.field(manifest, 'global'));
		fromMap('songs', Paths.formatToSongPath(PlayState.SONG.song));
		fromMap('songs', game.songName);
		fromMap('stages', PlayState.curStage);
		if (game.dad != null) fromMap('characters', game.dad.curCharacter);
		if (game.boyfriend != null) fromMap('characters', game.boyfriend.curCharacter);
		if (game.gf != null) fromMap('characters', game.gf.curCharacter);
		var events:Dynamic = ModFiles.field(manifest, 'events');
		if (events != null) for (k in Reflect.fields(events)) addAll(Reflect.field(events, k));
		var notes:Dynamic = ModFiles.field(manifest, 'noteTypes');
		if (notes != null) for (k in Reflect.fields(notes)) addAll(Reflect.field(notes, k));

		var loaded = 0;
		for (f in files)
		{
			var path = dir + f;
			if (!FileSystem.exists(path)) continue;
			try
			{
				var script = new CompatHScript(path, engine);
				game.hscriptArray.push(script);
				script.runCreate();
				loaded++;
			}
			catch (e:Dynamic)
			{
				game.addTextToDebug('Script "$f" could not run: ' + Std.string(e).split('\n')[0], 0xFFFF6060);
			}
		}
		if (loaded > 0) trace('Loaded $loaded compatibility script(s) for $mod');
		#end
	}
}

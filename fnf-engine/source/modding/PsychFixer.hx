package modding;

import modding.ConvertContext.PsychSongEntry;

using StringTools;

/**
 * Final pass for every imported mod (any format):
 *  - every song that has a chart shows up in Freeplay, even if no week lists it
 *  - weeks are unlocked and visible in Freeplay
 *  - mods with songs don't run globally, so they can't affect other mods
 */
class PsychFixer
{
	static final NOT_SONGS = ['characters', 'stages', 'weeks', 'songs', 'levels', 'notestyles', 'dialogue', 'events', 'notetypes', 'scripts'];

	public static function run(ctx:ConvertContext):Void
	{
		var listed:Array<String> = [];
		for (file in ModFiles.list(ctx.path('weeks')))
		{
			if (!file.toLowerCase().endsWith('.json')) continue;
			var path = ctx.path('weeks/$file');
			var week:Dynamic = ModFiles.readJson(path);
			if (week == null) continue;
			var songs:Array<Dynamic> = ModFiles.field(week, 'songs', []);
			for (s in songs)
				listed.push(ModFiles.formatSong(Std.isOfType(s, Array) ? Std.string(s[0]) : Std.string(s)));

			// everything playable from Freeplay
			var changed = false;
			if (ModFiles.toBool(ModFiles.field(week, 'hideFreeplay'), false)) { week.hideFreeplay = false; changed = true; }
			if (!ModFiles.toBool(ModFiles.field(week, 'startUnlocked'), true)) { week.startUnlocked = true; changed = true; }
			if (ModFiles.toBool(ModFiles.field(week, 'hiddenUntilUnlocked'), false)) { week.hiddenUntilUnlocked = false; changed = true; }
			if (changed)
			{
				try ModFiles.writeJson(path, week) catch (e:Dynamic) {}
			}
		}

		var entries:Array<PsychSongEntry> = [];
		for (folder in ModFiles.list(ctx.path('data')))
		{
			var dir = ctx.path('data/$folder');
			var lowerFolder = folder.toLowerCase();
			if (!ModFiles.isDir(dir) || NOT_SONGS.contains(lowerFolder)) continue;
			if (listed.contains(ModFiles.formatSong(folder))) continue;

			var diffs:Array<String> = [];
			var songName:String = null;
			var opponent:String = 'dad';
			for (file in ModFiles.list(dir))
			{
				var lower = file.toLowerCase();
				if (!lower.endsWith('.json') || lower == 'events.json') continue;
				var base = lower.substr(0, lower.length - 5);
				var diff:String = null;
				if (base == lowerFolder) diff = 'normal';
				else if (base.startsWith(lowerFolder + '-')) diff = base.substr(lowerFolder.length + 1);
				if (diff == null) continue;

				if (songName == null)
				{
					var json:Dynamic = ModFiles.readJson('$dir/$file');
					var song:Dynamic = json != null ? ModFiles.field(json, 'song', json) : null;
					if (song == null || Std.isOfType(song, String) || ModFiles.field(song, 'notes') == null) continue; // not a chart
					songName = ModFiles.field(song, 'song', folder);
					opponent = ModFiles.field(song, 'player2', 'dad');
				}
				diffs.push(diff);
			}
			if (diffs.length == 0) continue;
			if (songName == null || ModFiles.formatSong(songName) != lowerFolder) songName = folder;

			var info = ctx.characterIcon(opponent);
			var entry:PsychSongEntry = {
				name: songName,
				id: lowerFolder,
				icon: info.icon,
				color: info.color,
				difficulties: [for (d in ConvertContext.sortDifficulties(diffs)) ConvertContext.difficultyName(d)]
			};
			entries.push(entry);
			if (ctx.songs.filter(s -> s.id == entry.id).length == 0) ctx.songs.push(entry);
		}
		if (entries.length > 0)
		{
			ctx.writeWeekList(ctx.writeFreeplayWeeks(entries));
			ctx.log('Added ${entries.length} song(s) that were not in any week to Freeplay.');
		}

		// a mod with songs must not leak into other mods' songs or the menus
		var hasSongs = listed.length > 0 || entries.length > 0;
		var packPath = ctx.path('pack.json');
		if (hasSongs && ModFiles.exists(packPath))
		{
			var pack:Dynamic = ModFiles.readJson(packPath);
			if (pack != null && ModFiles.toBool(ModFiles.field(pack, 'runsGlobally'), false))
			{
				pack.runsGlobally = false;
				try ModFiles.writeJson(packPath, pack) catch (e:Dynamic) {}
			}
		}
	}

	/** Song names listed in the mod's week files (for the import summary). */
	public static function listSongs(ctx:ConvertContext):Array<String>
	{
		var names:Array<String> = [];
		for (file in ModFiles.list(ctx.path('weeks')))
		{
			if (!file.toLowerCase().endsWith('.json')) continue;
			var week:Dynamic = ModFiles.readJson(ctx.path('weeks/$file'));
			var songs:Array<Dynamic> = week != null ? ModFiles.field(week, 'songs', []) : [];
			for (s in songs)
			{
				var name:String = Std.isOfType(s, Array) ? Std.string(s[0]) : Std.string(s);
				if (!names.contains(name)) names.push(name);
			}
		}
		return names;
	}
}

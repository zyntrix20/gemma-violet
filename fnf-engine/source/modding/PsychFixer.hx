package modding;

import modding.ConvertContext.PsychSongEntry;

using StringTools;

/**
 * Psych Engine mods work as they are. This only fills gaps so the songs show
 * up in Freeplay: mods that ship charts but no week file get one generated.
 */
class PsychFixer
{
	static final NOT_SONGS = ['characters', 'stages', 'weeks', 'songs', 'levels', 'notestyles', 'dialogue'];

	public static function run(ctx:ConvertContext):Void
	{
		var weeks = ModFiles.list(ctx.path('weeks')).filter(f -> f.toLowerCase().endsWith('.json'));
		if (weeks.length > 0) return;

		var entries:Array<PsychSongEntry> = [];
		for (folder in ModFiles.list(ctx.path('data')))
		{
			var dir = ctx.path('data/$folder');
			if (!ModFiles.isDir(dir) || NOT_SONGS.contains(folder.toLowerCase())) continue;

			var diffs:Array<String> = [];
			var songName:String = null;
			var opponent:String = 'dad';
			var lowerFolder = folder.toLowerCase();
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
					if (song != null && !Std.isOfType(song, String))
					{
						songName = ModFiles.field(song, 'song', folder);
						opponent = ModFiles.field(song, 'player2', 'dad');
					}
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
			ctx.songs.push(entry);
		}
		if (entries.length > 0)
		{
			ctx.writeWeekList(ctx.writeFreeplayWeeks(entries));
			ctx.log('Created a Freeplay week for ${entries.length} song(s).');
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

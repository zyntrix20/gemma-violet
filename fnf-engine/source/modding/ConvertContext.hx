package modding;

using StringTools;

typedef PsychSongEntry =
{
	var name:String; // display name written into week files
	var id:String; // formatted folder name
	var icon:String;
	var color:Array<Int>;
	var difficulties:Array<String>; // display names, e.g. ["Easy", "Normal", "Hard"]
}

/** Shared state while converting one mod folder. */
class ConvertContext
{
	public var modDir:String; // with trailing slash
	public var modName:String;
	public var warnings:Array<String> = [];
	public var songs:Array<PsychSongEntry> = [];
	public var weeksCreated:Int = 0;
	public var charactersConverted:Int = 0;
	public var stagesConverted:Int = 0;
	public var log:String->Void;

	public function new(modDir:String, modName:String, ?log:String->Void)
	{
		if (!modDir.endsWith('/')) modDir += '/';
		this.modDir = modDir;
		this.modName = modName;
		this.log = log != null ? log : function(_) {};
	}

	public inline function path(rel:String):String
		return modDir + rel;

	public function warn(msg:String):Void
	{
		if (!warnings.contains(msg)) warnings.push(msg);
		log('Warning: ' + msg);
	}

	public function uniqueSongId(base:String):String
	{
		var id = base;
		var n = 2;
		while (songs.filter(s -> s.id == id).length > 0)
			id = '$base-${n++}';
		return id;
	}

	public static function difficultyName(diff:String):String
	{
		if (diff == null || diff.length == 0) return 'Normal';
		return diff.charAt(0).toUpperCase() + diff.substr(1);
	}

	/** Chart file name Psych expects for a difficulty (normal has no suffix). */
	public static function chartFile(songId:String, diff:String):String
	{
		var d = ModFiles.formatSong(diff);
		return (d == 'normal' || d == '') ? '$songId.json' : '$songId-$d.json';
	}

	public static function sortDifficulties(diffs:Array<String>):Array<String>
	{
		var order = ['easy', 'normal', 'hard', 'erect', 'nightmare'];
		var copy = diffs.copy();
		copy.sort(function(a, b)
		{
			var ia = order.indexOf(a.toLowerCase());
			var ib = order.indexOf(b.toLowerCase());
			if (ia < 0) ia = 100;
			if (ib < 0) ib = 100;
			return ia - ib;
		});
		return copy;
	}

	/** Reads healthicon + bar color of a character (mod first, then base game). */
	public function characterIcon(charId:String):{icon:String, color:Array<Int>}
	{
		var fallback = {icon: charId != null && charId.length > 0 ? charId : 'face', color: [146, 113, 253]};
		if (charId == null || charId.length == 0) return fallback;
		for (p in [path('characters/$charId.json'), 'assets/shared/characters/$charId.json'])
		{
			var json:Dynamic = ModFiles.readJson(p);
			if (json != null)
			{
				var icon:String = ModFiles.field(json, 'healthicon', charId);
				var color = ModFiles.colorToRGB(ModFiles.field(json, 'healthbar_colors'), fallback.color);
				// converted V-Slice characters only have generic bar colors: keep the default Freeplay color
				if (Reflect.hasField(json, 'vslice_camera')) color = fallback.color;
				return {icon: icon, color: color};
			}
		}
		return fallback;
	}

	/** Writes week JSON files grouping songs by their difficulty set. */
	public function writeWeek(fileName:String, weekName:String, songsInWeek:Array<PsychSongEntry>, ?options:Dynamic):Void
	{
		if (songsInWeek.length == 0) return;
		var diffs:Array<String> = [];
		for (s in songsInWeek)
			for (d in s.difficulties)
				if (!diffs.contains(d)) diffs.push(d);
		diffs = sortDifficulties(diffs);

		var week:Dynamic = {
			songs: [for (s in songsInWeek) ([s.name, s.icon, s.color] : Array<Dynamic>)],
			weekCharacters: ['', 'bf', 'gf'],
			weekBackground: '',
			weekBefore: '',
			storyName: weekName,
			weekName: weekName,
			freeplayColor: [146, 113, 253],
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: true,
			hideFreeplay: false,
			difficulties: diffs.join(', ')
		};
		if (options != null)
			for (f in Reflect.fields(options))
				Reflect.setField(week, f, Reflect.field(options, f));

		ModFiles.writeJson(path('weeks/$fileName.json'), week);
		weeksCreated++;
	}

	/** Puts songs that are not in any week into Freeplay-only weeks (one per difficulty set). */
	public function writeFreeplayWeeks(leftovers:Array<PsychSongEntry>):Array<String>
	{
		var names:Array<String> = [];
		var groups:Map<String, Array<PsychSongEntry>> = [];
		var order:Array<String> = [];
		for (s in leftovers)
		{
			var key = s.difficulties.join(',');
			if (!groups.exists(key))
			{
				groups.set(key, []);
				order.push(key);
			}
			groups.get(key).push(s);
		}
		var base = ModFiles.formatSong(modName);
		if (base.length == 0) base = 'mod';
		for (i => key in order)
		{
			var wid = base + '-freeplay' + (i > 0 ? '-${i + 1}' : '');
			writeWeek(wid, modName, groups.get(key));
			names.push(wid);
		}
		return names;
	}

	/** Appends week names to weeks/weekList.txt so they keep their order. */
	public function writeWeekList(names:Array<String>):Void
	{
		if (names.length == 0) return;
		var file = path('weeks/weekList.txt');
		var existing:Array<String> = [];
		if (ModFiles.exists(file))
			existing = [for (l in ModFiles.readText(file).split('\n')) if (l.trim().length > 0) l.trim()];
		for (n in names)
			if (!existing.contains(n)) existing.push(n);
		ModFiles.writeText(file, existing.join('\n'));
	}
}

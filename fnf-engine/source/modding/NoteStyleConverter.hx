package modding;

using StringTools;

typedef NoteStyleResult =
{
	var pixel:Bool;
	var arrowSkin:String; // Psych arrowSkin image key, or null to keep the default
}

/**
 * Turns a V-Slice note style (data/notestyles/<id>.json) into something Psych can use.
 *
 *  - Pixel styles switch the song to Psych's pixel UI.
 *  - Custom styles get their note, strumline and hold images merged into one
 *    Sparrow atlas named the way Psych expects ("purple0", "arrowLEFT",
 *    "left press", "purple hold piece"...), saved as images/noteSkins/vslice-<id>.
 *
 * Image merging needs the game's bitmap code, so it is injected through
 * `composeImages` (left null in tests, in which case custom styles are skipped).
 */
class NoteStyleConverter
{
	/** Stacks images vertically into `out`. Returns each input's [width, height], or null on failure. */
	public static var composeImages:(inputs:Array<String>, out:String) -> Array<Array<Int>> = null;

	static final DIRS = ['left', 'down', 'up', 'right'];
	static final COLORS = ['purple', 'blue', 'green', 'red'];

	var ctx:ConvertContext;
	var cache:Map<String, NoteStyleResult> = [];

	public function new(ctx:ConvertContext)
	{
		this.ctx = ctx;
	}

	public function get(id:String):NoteStyleResult
	{
		if (id == null || id.length == 0) id = 'funkin';
		if (cache.exists(id)) return cache.get(id);
		var result:NoteStyleResult;
		try
		{
			result = convert(id, 0);
		}
		catch (e:Dynamic)
		{
			ctx.warn('Note style "$id" could not be converted ($e); using the default notes.');
			result = {pixel: false, arrowSkin: null};
		}
		cache.set(id, result);
		return result;
	}

	function convert(id:String, depth:Int):NoteStyleResult
	{
		var none:NoteStyleResult = {pixel: false, arrowSkin: null};
		if (depth > 4) return none;
		switch (id.toLowerCase())
		{
			case 'funkin': return none;
			case 'pixel': return {pixel: true, arrowSkin: null};
		}

		var data:Dynamic = ModFiles.readJson(ctx.path('data/notestyles/$id.json'));
		if (data == null)
		{
			ctx.warn('Note style "$id" is not in the mod; using the default notes.');
			return none;
		}
		var fallback:String = ModFiles.field(data, 'fallback', 'funkin');
		var assets:Dynamic = ModFiles.field(data, 'assets', {});
		var note:Dynamic = ModFiles.field(assets, 'note');
		var strum:Dynamic = ModFiles.field(assets, 'noteStrumline');
		var hold:Dynamic = ModFiles.field(assets, 'holdNote');

		// styles that only override a few things fall back to their parent's notes
		if (note == null || strum == null) return convert(fallback, depth + 1);

		var isPixel = ModFiles.toBool(ModFiles.field(note, 'isPixel'), false);
		if (isPixel)
		{
			// Psych draws pixel notes its own way (grid images); use its pixel UI
			return {pixel: true, arrowSkin: null};
		}

		var noteImg = ModFiles.stripLibrary(ModFiles.field(note, 'assetPath', ''));
		var strumImg = ModFiles.stripLibrary(ModFiles.field(strum, 'assetPath', ''));
		var holdImg = hold != null ? ModFiles.stripLibrary(ModFiles.field(hold, 'assetPath', '')) : '';
		if (!hasImage(noteImg) || !hasImage(strumImg) || !hasXml(noteImg) || !hasXml(strumImg))
		{
			var parent = convert(fallback, depth + 1);
			if (parent.arrowSkin == null && !parent.pixel)
				ctx.warn('Note style "$id": its note images are not in the mod; using the default notes.');
			return parent;
		}
		if (holdImg.length == 0 || !hasImage(holdImg)) holdImg = 'NOTE_hold_assets';
		if (!hasImage(holdImg))
		{
			ctx.warn('Note style "$id" has no hold note image; using the default notes.');
			return none;
		}
		if (composeImages == null) return none;

		var key = 'noteSkins/vslice-' + ModFiles.formatSong(id);
		var inputs = noteImg == strumImg ? [noteImg, holdImg] : [noteImg, strumImg, holdImg];
		ModFiles.ensureDir(ctx.path('images/noteSkins'));
		var sizes = composeImages([for (i in inputs) imagePath(i)], ctx.path('images/$key.png'));
		if (sizes == null)
		{
			ctx.warn('Note style "$id" could not be converted; using the default notes.');
			return none;
		}

		// build the Psych atlas XML
		var out = Xml.createDocument();
		var atlas = Xml.createElement('TextureAtlas');
		atlas.set('imagePath', 'vslice-' + ModFiles.formatSong(id) + '.png');
		out.addChild(atlas);

		var y = 0;
		var noteMap:Map<String, String> = [];
		var noteData:Dynamic = ModFiles.field(note, 'data', {});
		for (i => dir in DIRS)
		{
			var d:Dynamic = ModFiles.field(noteData, dir);
			if (d != null) noteMap.set(ModFiles.field(d, 'prefix', ''), COLORS[i] + '0');
		}
		var strumMap:Map<String, String> = [];
		var strumData:Dynamic = ModFiles.field(strum, 'data', {});
		for (dir in DIRS)
		{
			inline function add(suffix:String, psych:String)
			{
				var d:Dynamic = ModFiles.field(strumData, dir + suffix);
				if (d != null) strumMap.set(ModFiles.field(d, 'prefix', ''), psych);
			}
			add('Static', 'arrow' + dir.toUpperCase());
			add('Press', dir + ' press');
			add('Confirm', dir + ' confirm');
		}

		copyFrames(atlas, xmlPath(noteImg), noteMap, y);
		if (noteImg != strumImg)
		{
			y += sizes[0][1];
			copyFrames(atlas, xmlPath(strumImg), strumMap, y);
			y += sizes[1][1];
		}
		else
		{
			copyFrames(atlas, xmlPath(noteImg), strumMap, 0);
			y += sizes[0][1];
		}

		// hold strip: 8 columns (piece, end) x 4 directions
		var holdSize = sizes[sizes.length - 1];
		var colW = Std.int(holdSize[0] / 8);
		for (i in 0...4)
		{
			var names = [[COLORS[i] + ' hold piece'], [COLORS[i] + ' hold end']];
			if (i == 0) names[1].push('pruple end hold');
			for (part in 0...2)
				for (n in names[part])
				{
					var st = Xml.createElement('SubTexture');
					st.set('name', n + '0000');
					st.set('x', Std.string((i * 2 + part) * colW));
					st.set('y', Std.string(y));
					st.set('width', Std.string(colW));
					st.set('height', Std.string(holdSize[1]));
					atlas.addChild(st);
				}
		}
		ModFiles.writeText(ctx.path('images/$key.xml'), out.toString());
		ctx.log('Converted note style "$id"');
		return {pixel: false, arrowSkin: key};
	}

	/** Copies frames whose name starts with a mapped prefix, renaming the prefix. */
	function copyFrames(atlas:Xml, xmlFile:String, map:Map<String, String>, yOffset:Int):Void
	{
		var text = ModFiles.readText(xmlFile);
		var src = Xml.parse(text).firstElement();
		var prefixes = [for (k in map.keys()) if (k.length > 0) k];
		prefixes.sort((a, b) -> b.length - a.length);
		for (st in src.elementsNamed('SubTexture'))
		{
			var name = st.get('name');
			if (name == null) continue;
			for (p in prefixes)
			{
				if (!name.startsWith(p)) continue;
				var rest = name.substr(p.length);
				var copy = Xml.createElement('SubTexture');
				for (attr in st.attributes()) copy.set(attr, st.get(attr));
				copy.set('name', map.get(p) + rest);
				copy.set('y', Std.string(Std.parseInt(st.get('y')) + yOffset));
				atlas.addChild(copy);
				break;
			}
		}
	}

	function imagePath(key:String):String
	{
		var mod = ctx.path('images/$key.png');
		return ModFiles.exists(mod) ? mod : 'assets/shared/images/$key.png';
	}

	inline function xmlPath(key:String):String
	{
		var mod = ctx.path('images/$key.xml');
		return ModFiles.exists(mod) ? mod : 'assets/shared/images/$key.xml';
	}

	inline function hasImage(key:String):Bool
		return key.length > 0 && (ModFiles.exists(ctx.path('images/$key.png')) || ModFiles.exists('assets/shared/images/$key.png'));

	inline function hasXml(key:String):Bool
		return ModFiles.exists(ctx.path('images/$key.xml')) || ModFiles.exists('assets/shared/images/$key.xml');
}

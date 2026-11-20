package modding;

import haxe.io.Path;
import modding.ZipArchive.ZipEntry;
import sys.FileSystem;
import sys.io.File;

using StringTools;

enum ModFormat
{
	PSYCH;
	VSLICE;
	CODENAME;
}

typedef ImportedMod =
{
	var folder:String;
	var name:String;
	var format:ModFormat;
	var songs:Array<String>;
	var weeks:Int;
	var warnings:Array<String>;
}

typedef ImportResult =
{
	var success:Bool;
	var error:String;
	var mods:Array<ImportedMod>;
}

private typedef ModRoot =
{
	var prefix:String; // path inside the archive, with trailing slash ('' = archive root)
	var build:Bool; // whole game folder: content lives in assets/<library>/
	var files:Array<{entry:ZipEntry, rel:String}>;
}

/**
 * Imports a mod archive (.zip) into the mods folder.
 *
 * Works out where the mod(s) are inside the archive, which engine they were
 * made for, extracts them and converts V-Slice / Codename content so it
 * shows up in Freeplay and Story Mode.
 *
 * Safe to run on a background thread; read `progress` and `status` from the UI.
 */
class ModImporter
{
	/** Folders Psych never treats as mods. */
	static final RESERVED:Array<String> = [
		'characters', 'custom_events', 'custom_notetypes', 'data', 'songs', 'music', 'sounds', 'shaders', 'videos', 'images', 'stages', 'weeks',
		'fonts', 'scripts', 'achievements'
	];

	static final LIBRARY = ~/^(shared|preload|tutorial|week\d+|weekend\d+)$/i;
	static final CONTENT_DIRS = ['data', 'songs', 'weeks', 'images', 'characters', 'stages', 'music', 'sounds', 'scripts', 'shared'];

	public var progress(default, null):Float = 0;
	public var status(default, null):String = '';
	public var finished(default, null):Bool = false;
	public var result(default, null):ImportResult = null;

	var zipPath:String;
	var modsDir:String;
	var log:Array<String> = [];

	public function new(zipPath:String, ?modsDir:String = 'mods/')
	{
		this.zipPath = zipPath;
		if (!modsDir.endsWith('/')) modsDir += '/';
		this.modsDir = modsDir;
	}

	public function getLog():Array<String>
		return log.copy();

	function say(s:String):Void
	{
		status = s;
		log.push(s);
	}

	public function runAsync():Void
	{
		#if (target.threaded)
		sys.thread.Thread.create(run);
		#else
		run();
		#end
	}

	public function run():ImportResult
	{
		var archive:ZipArchive = null;
		try
		{
			say('Reading archive...');
			archive = new ZipArchive(zipPath);
			if (archive.entries.length == 0) throw 'The archive is empty.';

			var roots = findRoots(archive);
			if (roots.length == 0)
				throw 'No Friday Night Funkin\' mod files were found in this archive.\nA mod should contain folders like "data", "songs", "images" or "weeks".';

			var totalBytes:Float = 0;
			for (r in roots)
				for (f in r.files) totalBytes += f.entry.size;
			var doneBytes:Float = 0;

			var imported:Array<ImportedMod> = [];
			for (root in roots)
			{
				var format = detectFormat(root);
				var name = modDisplayName(archive, root, roots.length);
				var folder = uniqueFolder(ModFiles.safeFolderName(name));
				var target = modsDir + folder + '/';

				// replace an older import of the same mod
				if (ModFiles.exists(target)) ModFiles.deleteRecursive(target);
				ModFiles.ensureDir(target);

				say('Extracting "$name" (${formatName(format)} mod)...');
				for (f in root.files)
				{
					var dst = target + f.rel;
					ModFiles.ensureDir(Path.directory(dst));
					File.saveBytes(dst, archive.read(f.entry));
					doneBytes += f.entry.size;
					progress = totalBytes > 0 ? 0.85 * doneBytes / totalBytes : 0.85;
				}

				var ctx = new ConvertContext(target, name, function(s) log.push(s));
				switch (format)
				{
					case VSLICE:
						say('Converting V-Slice files for "$name"...');
						new VSliceConverter(ctx).run();
					case CODENAME:
						say('Converting Codename files for "$name"...');
						new CodenameConverter(ctx).run();
					case PSYCH:
						PsychFixer.run(ctx);
				}

				enableMod(folder);
				try
				{
					ModFiles.writeJson(target + '_import.json', {
						format: formatName(format),
						archive: Path.withoutDirectory(zipPath),
						date: Date.now().toString(),
						warnings: ctx.warnings
					});
				}
				catch (e:Dynamic) {}
				var songNames = [for (s in ctx.songs) s.name];
				if (songNames.length == 0) songNames = PsychFixer.listSongs(ctx);
				imported.push({
					folder: folder,
					name: name,
					format: format,
					songs: songNames,
					weeks: ctx.weeksCreated,
					warnings: ctx.warnings
				});
			}

			progress = 1;
			say('Done!');
			result = {success: true, error: null, mods: imported};
		}
		catch (e:Dynamic)
		{
			say('Import failed: $e');
			result = {success: false, error: Std.string(e), mods: []};
		}
		if (archive != null) archive.close();
		finished = true;
		return result;
	}

	public static function formatName(f:ModFormat):String
	{
		return switch (f)
		{
			case PSYCH: 'Psych Engine';
			case VSLICE: 'V-Slice';
			case CODENAME: 'Codename Engine';
		}
	}

	// ------------------------------------------------------------ detection

	static function dirOf(p:String):String
	{
		var i = p.lastIndexOf('/');
		return i >= 0 ? p.substr(0, i + 1) : '';
	}

	function findRoots(archive:ZipArchive):Array<ModRoot>
	{
		var names = [for (e in archive.entries) e.name];
		var candidates:Map<String, Bool> = []; // prefix -> isBuild

		inline function add(prefix:String, build:Bool)
		{
			if (!candidates.exists(prefix) || build) candidates.set(prefix, build);
		}

		var buildRe = ~/^(.*?)assets\/(shared|preload|songs|data|images|week\d+|weekend\d+|base_game)\//i;
		var modsRe = ~/^(.*?)mods\/([^\/]+)\/(data|songs|weeks|images|characters|stages|scripts|shared|_polymod_meta\.json|pack\.json)/i;
		var markers = [
			~/^(.*?)data\/songs\/[^\/]+\/[^\/]+-chart(-[^\/]+)?\.json$/i, // V-Slice chart
			~/^(.*?)songs\/[^\/]+\/charts\/[^\/]+\.json$/i, // Codename chart
			~/^(.*?)data\/characters\/[^\/]+\.xml$/i, // Codename character
			~/^(.*?)data\/([^\/]+)\/[^\/]+\.json$/i, // Psych chart folder
			~/^(.*?)weeks\/[^\/]+\.json$/i, // Psych week
			~/^(.*?)songs\/[^\/]+\/Inst(-[^\/]+)?\.ogg$/i, // audio
			~/^(.*?)characters\/[^\/]+\.json$/i // Psych character
		];

		for (n in names)
		{
			var file = n.substr(n.lastIndexOf('/') + 1).toLowerCase();
			if (file == '_polymod_meta.json' || file == 'pack.json') add(dirOf(n), false);
			if (modsRe.match(n)) add(modsRe.matched(1) + 'mods/' + modsRe.matched(2) + '/', false);
			if (buildRe.match(n)) add(buildRe.matched(1), true);
			for (re in markers)
			{
				if (re.match(n))
				{
					add(re.matched(1), false);
					break;
				}
			}
		}

		// pick roots: drop candidates nested inside another root,
		// except mods/<x>/ folders inside a game build
		var prefixes = [for (p in candidates.keys()) p];
		prefixes.sort((a, b) -> a.length - b.length);
		var chosen:Array<String> = [];
		for (p in prefixes)
		{
			var nested = false;
			for (c in chosen)
			{
				if (!p.startsWith(c)) continue;
				var inner = p.substr(c.length);
				var allowed = candidates.get(c) && inner.toLowerCase().startsWith('mods/') && !inner.toLowerCase().startsWith('mods/assets');
				if (!allowed)
				{
					nested = true;
					break;
				}
			}
			if (!nested) chosen.push(p);
		}

		// a game build that ships its mods in mods/ is just a wrapper: import those
		// instead of the build's own (base game) assets
		var roots:Array<ModRoot> = [];
		for (p in chosen)
		{
			var build = candidates.get(p);
			if (build && chosen.filter(o -> o != p && o.startsWith(p)).length > 0) continue;
			var files:Array<{entry:ZipEntry, rel:String}> = [];
			for (e in archive.entries)
			{
				if (!e.name.startsWith(p)) continue;
				var rel = e.name.substr(p.length);

				// skip content that belongs to a deeper chosen root
				var deeper = false;
				for (other in chosen)
					if (other != p && other.length > p.length && e.name.startsWith(other)) deeper = true;
				if (deeper) continue;

				if (build)
				{
					if (!rel.toLowerCase().startsWith('assets/')) continue;
					rel = rel.substr(7);
					rel = stripLibrary(rel, true);
				}
				if (rel.length == 0) continue;
				files.push({entry: e, rel: rel});
			}
			if (files.length == 0) continue;
			if (!build && !hasContent(files)) continue;
			roots.push({prefix: p, build: build, files: files});
		}

		// V-Slice mods mirror the asset libraries (shared/, week1/...): flatten them
		for (r in roots)
		{
			if (r.build || detectFormat(r) != VSLICE) continue;
			for (f in r.files) f.rel = stripLibrary(f.rel, false);
		}
		return roots;
	}

	static function stripLibrary(rel:String, build:Bool):String
	{
		var parts = rel.split('/');
		if (build && parts.length > 1 && parts[0].toLowerCase() == 'base_game') parts.shift();
		if (parts.length > 1 && LIBRARY.match(parts[0])) parts.shift();
		return parts.join('/');
	}

	static function hasContent(files:Array<{entry:ZipEntry, rel:String}>):Bool
	{
		for (f in files)
		{
			var top = f.rel.split('/')[0].toLowerCase();
			if (CONTENT_DIRS.contains(top) || f.rel == '_polymod_meta.json' || f.rel == 'pack.json') return true;
		}
		return false;
	}

	static function detectFormat(root:ModRoot):ModFormat
	{
		var vslice = ~/^(?:[^\/]+\/)?data\/(songs\/[^\/]+\/[^\/]+-(chart|metadata)(-[^\/]+)?\.json|levels\/[^\/]+\.json)$/i;
		var codename = ~/^(songs\/[^\/]+\/charts\/[^\/]+\.json|data\/(characters|stages)\/[^\/]+\.xml|data\/weeks\/weeks\/[^\/]+\.xml)$/i;
		var v = 0, c = 0;
		for (f in root.files)
		{
			if (f.rel == '_polymod_meta.json') return VSLICE;
			if (vslice.match(f.rel)) v++;
			if (codename.match(f.rel)) c++;
		}
		if (v == 0 && c == 0) return PSYCH;
		return v >= c ? VSLICE : CODENAME;
	}

	function modDisplayName(archive:ZipArchive, root:ModRoot, rootCount:Int):String
	{
		// metadata files first
		for (f in root.files)
		{
			if (f.rel == '_polymod_meta.json' || f.rel == 'pack.json')
			{
				try
				{
					var json:Dynamic = haxe.Json.parse(archive.readString(f.entry));
					var title:String = ModFiles.field(json, f.rel == 'pack.json' ? 'name' : 'title');
					if (title != null && title.trim().length > 0) return title.trim();
				}
				catch (e:Dynamic) {}
			}
		}
		// then folder names
		var p = Path.removeTrailingSlashes(root.prefix);
		if (p.length > 0)
		{
			var name = p.substr(p.lastIndexOf('/') + 1);
			if (name.toLowerCase() != 'mods' && name.toLowerCase() != 'assets') return name;
		}
		// fall back to the archive name
		var file = Path.withoutDirectory(Path.withoutExtension(zipPath));
		return rootCount > 1 ? '$file ${root.prefix}' : file;
	}

	function uniqueFolder(name:String):String
	{
		if (RESERVED.contains(name.toLowerCase())) name += ' Mod';
		return name;
	}

	/** Adds (or re-enables) the mod in modsList.txt. */
	function enableMod(folder:String):Void
	{
		var listFile = 'modsList.txt';
		var lines:Array<String> = [];
		if (FileSystem.exists(listFile))
			lines = [for (l in File.getContent(listFile).split('\n')) if (l.trim().length > 0) l.trim()];
		var found = false;
		for (i in 0...lines.length)
		{
			if (lines[i].split('|')[0] == folder)
			{
				lines[i] = '$folder|1';
				found = true;
			}
		}
		if (!found) lines.push('$folder|1');
		File.saveContent(listFile, lines.join('\n'));
	}
}

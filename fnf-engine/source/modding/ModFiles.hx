package modding;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/** File helpers shared by the importer and converters (no Flixel dependency). */
class ModFiles
{
	/** Same rules as Paths.formatToSongPath. */
	public static function formatSong(name:String):String
	{
		var invalid = ~/[~&;:<>#\s]/g;
		var hide = ~/[.,'"%?!]/g;
		return hide.replace(invalid.replace(name, '-'), '').trim().toLowerCase();
	}

	public static function safeFolderName(name:String):String
	{
		var clean = ~/[\\\/:*?"<>|\x00-\x1F]/g.replace(name, '').trim();
		clean = ~/\s+/g.replace(clean, ' ');
		while (clean.endsWith('.')) clean = clean.substr(0, clean.length - 1);
		if (clean.length > 60) clean = clean.substr(0, 60).trim();
		return clean.length > 0 ? clean : 'Imported Mod';
	}

	public static function readText(path:String):String
	{
		var text = File.getContent(path);
		if (text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
		return text;
	}

	public static function readJson(path:String):Dynamic
	{
		if (!FileSystem.exists(path)) return null;
		var text = readText(path);
		try
		{
			return Json.parse(text);
		}
		catch (e:Dynamic)
		{
			// many mods ship slightly broken JSON (trailing commas, comments)
			try return tjson.TJSON.parse(text) catch (e2:Dynamic) {}
		}
		return null;
	}

	public static function writeJson(path:String, data:Dynamic):Void
	{
		ensureDir(Path.directory(path));
		File.saveContent(path, Json.stringify(data, null, '\t'));
	}

	public static function writeText(path:String, text:String):Void
	{
		ensureDir(Path.directory(path));
		File.saveContent(path, text);
	}

	public static function ensureDir(dir:String):Void
	{
		if (dir == null || dir.length == 0 || FileSystem.exists(dir)) return;
		ensureDir(Path.directory(Path.removeTrailingSlashes(dir)));
		FileSystem.createDirectory(dir);
	}

	public static function exists(path:String):Bool
		return path != null && FileSystem.exists(path);

	public static function isDir(path:String):Bool
		return FileSystem.exists(path) && FileSystem.isDirectory(path);

	public static function list(dir:String):Array<String>
	{
		if (!isDir(dir)) return [];
		var items = FileSystem.readDirectory(dir);
		items.sort(Reflect.compare);
		return items;
	}

	/** Moves a file, falling back to copy + delete (e.g. across storage volumes). */
	public static function move(src:String, dst:String, overwrite:Bool = true):Void
	{
		if (!FileSystem.exists(src) || src == dst) return;
		ensureDir(Path.directory(dst));
		if (FileSystem.exists(dst))
		{
			if (!overwrite) return;
			if (FileSystem.isDirectory(dst)) deleteRecursive(dst) else FileSystem.deleteFile(dst);
		}
		try
		{
			FileSystem.rename(src, dst);
		}
		catch (e:Dynamic)
		{
			File.copy(src, dst);
			FileSystem.deleteFile(src);
		}
	}

	public static function copy(src:String, dst:String, overwrite:Bool = true):Void
	{
		if (!FileSystem.exists(src) || (!overwrite && FileSystem.exists(dst))) return;
		ensureDir(Path.directory(dst));
		File.copy(src, dst);
	}

	public static function deleteRecursive(path:String):Void
	{
		if (!FileSystem.exists(path)) return;
		if (FileSystem.isDirectory(path))
		{
			for (item in FileSystem.readDirectory(path))
				deleteRecursive(path + '/' + item);
			FileSystem.deleteDirectory(path);
		}
		else FileSystem.deleteFile(path);
	}

	/** Removes empty folders left behind after moving files around. */
	public static function pruneEmpty(dir:String):Bool
	{
		if (!isDir(dir)) return false;
		var empty = true;
		for (item in FileSystem.readDirectory(dir))
		{
			var p = dir + '/' + item;
			if (FileSystem.isDirectory(p))
			{
				if (!pruneEmpty(p)) empty = false;
			}
			else empty = false;
		}
		if (empty) FileSystem.deleteDirectory(dir);
		return empty;
	}

	/** Lists files under `dir` (relative paths, forward slashes). */
	public static function walk(dir:String, ?prefix:String = ''):Array<String>
	{
		var out:Array<String> = [];
		for (item in list(dir))
		{
			var rel = prefix + item;
			var full = dir + '/' + item;
			if (FileSystem.isDirectory(full)) out = out.concat(walk(full, rel + '/'));
			else out.push(rel);
		}
		return out;
	}

	/** Finds a file case-insensitively inside a folder. Returns the real name or null. */
	public static function findCaseInsensitive(dir:String, name:String):String
	{
		var lower = name.toLowerCase();
		for (item in list(dir))
			if (item.toLowerCase() == lower) return item;
		return null;
	}

	public static function colorToRGB(color:Dynamic, ?fallback:Array<Int>):Array<Int>
	{
		if (fallback == null) fallback = [146, 113, 253];
		if (color == null) return fallback;
		if (Std.isOfType(color, Array))
		{
			var arr:Array<Dynamic> = cast color;
			if (arr.length >= 3) return [Std.int(arr[0]), Std.int(arr[1]), Std.int(arr[2])];
			return fallback;
		}
		var s:String = Std.string(color).trim();
		if (s.startsWith('#')) s = s.substr(1);
		else if (s.startsWith('0x') || s.startsWith('0X')) s = s.substr(2);
		if (s.length == 8) s = s.substr(2); // AARRGGBB
		if (s.length != 6) return fallback;
		var v = Std.parseInt('0x' + s);
		if (v == null) return fallback;
		return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
	}

	public static function rgbToHex(rgb:Array<Int>):String
	{
		var v = ((rgb[0] & 0xFF) << 16) | ((rgb[1] & 0xFF) << 8) | (rgb[2] & 0xFF);
		return '#' + StringTools.hex(v, 6);
	}

	/** Strips a "library:" prefix used by V-Slice asset paths (e.g. "shared:characters/dad"). */
	public static function stripLibrary(path:String):String
	{
		if (path == null) return null;
		var i = path.indexOf(':');
		return i >= 0 ? path.substr(i + 1) : path;
	}

	public static function field(obj:Dynamic, name:String, ?def:Dynamic):Dynamic
	{
		if (obj == null || !Reflect.hasField(obj, name)) return def;
		var v = Reflect.field(obj, name);
		return v == null ? def : v;
	}

	public static function toFloat(v:Dynamic, def:Float):Float
	{
		if (v == null) return def;
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return v;
		var f = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}

	public static function toBool(v:Dynamic, def:Bool):Bool
	{
		if (v == null) return def;
		if (Std.isOfType(v, Bool)) return v;
		var s = Std.string(v).toLowerCase().trim();
		return s == 'true' || s == '1' || s == 'yes';
	}

	/** Returns [x, y] from a number or an array (V-Slice uses both for scale/scroll). */
	public static function pair(v:Dynamic, def:Float):Array<Float>
	{
		if (v == null) return [def, def];
		if (Std.isOfType(v, Array))
		{
			var a:Array<Dynamic> = cast v;
			if (a.length == 0) return [def, def];
			var x = toFloat(a[0], def);
			return [x, a.length > 1 ? toFloat(a[1], x) : x];
		}
		var f = toFloat(v, def);
		return [f, f];
	}
}

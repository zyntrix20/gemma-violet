package modding;

using StringTools;

import haxe.io.Bytes;
import haxe.zip.Uncompress;
import sys.io.File;
import sys.io.FileInput;

typedef ZipEntry =
{
	var name:String;
	var method:Int;
	var compressedSize:Int;
	var size:Int;
	var localOffset:Int;
	var encrypted:Bool;
	var isDirectory:Bool;
}

/**
 * Minimal streaming ZIP reader.
 *
 * Reads the central directory once, then decompresses entries one at a time,
 * so even very large mod archives never have to fit in memory.
 * Supports stored and deflated entries (what every common zip tool writes).
 */
class ZipArchive
{
	public var entries(default, null):Array<ZipEntry> = [];
	public var byName(default, null):Map<String, ZipEntry> = [];

	var input:FileInput;
	var fileSize:Int;

	public function new(path:String)
	{
		input = File.read(path, true);
		input.seek(0, SeekEnd);
		fileSize = input.tell();
		readCentralDirectory();
	}

	public function close():Void
	{
		if (input != null) input.close();
		input = null;
	}

	/** Normalizes a path inside the archive: forward slashes, no leading slash, no "..". */
	public static function normalize(path:String):String
	{
		path = path.split('\\').join('/');
		var out:Array<String> = [];
		for (part in path.split('/'))
		{
			if (part == '' || part == '.') continue;
			if (part == '..')
			{
				out.pop();
				continue;
			}
			out.push(part);
		}
		return out.join('/');
	}

	function readCentralDirectory():Void
	{
		// find "End of central directory" record (max comment length 65535)
		var searchLen = Std.int(Math.min(fileSize, 65557));
		input.seek(fileSize - searchLen, SeekBegin);
		var tail = input.read(searchLen);
		var eocd = -1;
		var i = searchLen - 22;
		while (i >= 0)
		{
			if (tail.get(i) == 0x50 && tail.get(i + 1) == 0x4B && tail.get(i + 2) == 0x05 && tail.get(i + 3) == 0x06)
			{
				eocd = i;
				break;
			}
			i--;
		}
		if (eocd < 0) throw 'This file is not a valid .zip archive.';

		var count = tail.getUInt16(eocd + 10);
		var cdSize = tail.getInt32(eocd + 12);
		var cdOffset = tail.getInt32(eocd + 16);

		if (count == 0xFFFF || cdOffset == -1 || cdSize == -1)
		{
			// ZIP64: look for the locator right before the EOCD record
			var loc = eocd - 20;
			if (loc < 0 || tail.getInt32(loc) != 0x07064B50)
				throw 'This archive uses ZIP64 and could not be read.';
			var recOffset = readInt64AsInt(tail, loc + 8);
			input.seek(recOffset, SeekBegin);
			var rec = input.read(56);
			if (rec.getInt32(0) != 0x06064B50) throw 'Broken ZIP64 archive.';
			count = readInt64AsInt(rec, 32);
			cdSize = readInt64AsInt(rec, 40);
			cdOffset = readInt64AsInt(rec, 48);
		}

		input.seek(cdOffset, SeekBegin);
		var cd = input.read(cdSize);
		var pos = 0;
		for (n in 0...count)
		{
			if (pos + 46 > cd.length || cd.getInt32(pos) != 0x02014B50) break;
			var flags = cd.getUInt16(pos + 8);
			var method = cd.getUInt16(pos + 10);
			var csize = cd.getInt32(pos + 20);
			var usize = cd.getInt32(pos + 24);
			var nameLen = cd.getUInt16(pos + 28);
			var extraLen = cd.getUInt16(pos + 30);
			var commentLen = cd.getUInt16(pos + 32);
			var offset = cd.getInt32(pos + 42);
			var rawName = cd.getString(pos + 46, nameLen);

			// ZIP64 extra field holds the real sizes / offset
			var e = pos + 46 + nameLen;
			var eEnd = e + extraLen;
			while (e + 4 <= eEnd)
			{
				var id = cd.getUInt16(e);
				var len = cd.getUInt16(e + 2);
				if (id == 0x0001)
				{
					var p = e + 4;
					if (usize == -1) { usize = readInt64AsInt(cd, p); p += 8; }
					if (csize == -1) { csize = readInt64AsInt(cd, p); p += 8; }
					if (offset == -1) { offset = readInt64AsInt(cd, p); p += 8; }
				}
				e += 4 + len;
			}

			var name = normalize(rawName);
			var entry:ZipEntry = {
				name: name,
				method: method,
				compressedSize: csize,
				size: usize,
				localOffset: offset,
				encrypted: (flags & 1) != 0,
				isDirectory: rawName.endsWith('/') || rawName.endsWith('\\')
			};
			if (name.length > 0 && !entry.isDirectory && !isJunk(name))
			{
				entries.push(entry);
				byName.set(name, entry);
			}
			pos += 46 + nameLen + extraLen + commentLen;
		}
	}

	static function readInt64AsInt(b:Bytes, pos:Int):Int
	{
		var low = b.getInt32(pos);
		var high = b.getInt32(pos + 4);
		if (high != 0 || low < 0) throw 'This archive is larger than 2 GB, which is not supported.';
		return low;
	}

	static function isJunk(name:String):Bool
	{
		if (name.startsWith('__MACOSX/') || name.indexOf('/__MACOSX/') >= 0) return true;
		var file = name.substr(name.lastIndexOf('/') + 1);
		return file == '.DS_Store' || file == 'Thumbs.db' || file == 'desktop.ini';
	}

	public function read(entry:ZipEntry):Bytes
	{
		if (entry.encrypted) throw 'The file "${entry.name}" is password protected.';

		input.seek(entry.localOffset, SeekBegin);
		var header = input.read(30);
		if (header.getInt32(0) != 0x04034B50) throw 'Broken archive at "${entry.name}".';
		var nameLen = header.getUInt16(26);
		var extraLen = header.getUInt16(28);
		input.seek(entry.localOffset + 30 + nameLen + extraLen, SeekBegin);

		var data = entry.compressedSize > 0 ? input.read(entry.compressedSize) : Bytes.alloc(0);
		switch (entry.method)
		{
			case 0:
				return data;
			case 8:
				return inflate(data, entry.size);
			default:
				throw 'The file "${entry.name}" uses an unsupported compression method (${entry.method}). Re-save the archive as a normal .zip.';
		}
	}

	public function readString(entry:ZipEntry):String
		return read(entry).toString();

	static function inflate(src:Bytes, size:Int):Bytes
	{
		var out = Bytes.alloc(size);
		if (size == 0) return out;
		var u = new Uncompress(-15); // raw deflate stream
		var srcPos = 0;
		var dstPos = 0;
		try
		{
			while (dstPos < size)
			{
				var r = u.execute(src, srcPos, out, dstPos);
				srcPos += r.read;
				dstPos += r.write;
				if (r.done || (r.read == 0 && r.write == 0)) break;
			}
		}
		catch (e:Dynamic)
		{
			u.close();
			throw e;
		}
		u.close();
		if (dstPos < size) throw 'A file in the archive is damaged.';
		return out;
	}
}

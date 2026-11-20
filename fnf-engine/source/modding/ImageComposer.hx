package modding;

import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Point;

/** Game-side image helper used by the converters (needs OpenFL, so it is not part of the tests). */
class ImageComposer
{
	public static function install():Void
	{
		NoteStyleConverter.composeImages = composeVertical;
	}

	/** Stacks images top to bottom into one PNG. Returns [width, height] of each input. */
	public static function composeVertical(inputs:Array<String>, out:String):Array<Array<Int>>
	{
		try
		{
			var bitmaps = [for (i in inputs) BitmapData.fromBytes(openfl.utils.ByteArray.fromBytes(sys.io.File.getBytes(i)))];
			var w = 0, h = 0;
			for (b in bitmaps)
			{
				if (b == null) return null;
				w = Std.int(Math.max(w, b.width));
				h += b.height;
			}
			var result = new BitmapData(w, h, true, 0);
			var y = 0;
			for (b in bitmaps)
			{
				result.copyPixels(b, b.rect, new Point(0, y));
				y += b.height;
			}
			var png = result.encode(result.rect, new PNGEncoderOptions());
			ModFiles.ensureDir(haxe.io.Path.directory(out));
			sys.io.File.saveBytes(out, png);
			var sizes = [for (b in bitmaps) [b.width, b.height]];
			for (b in bitmaps) b.dispose();
			result.dispose();
			return sizes;
		}
		catch (e:Dynamic)
		{
			trace('Could not compose images: $e');
			return null;
		}
	}
}

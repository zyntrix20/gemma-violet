package mobile;

import haxe.io.Path;

/**
 * Psych Engine reads most files straight from disk (that is how mods work),
 * but on Android the built-in assets live inside the APK. On first launch
 * (and after every update) we copy them into the app's storage folder and
 * make that folder the working directory, so the engine behaves exactly
 * like the desktop build.
 */
class StorageSetup
{
	static inline final STAMP_FILE:String = '.engine_assets';

	public static var storageDir(default, null):String = '';

	public static function init():Void
	{
		#if mobile
		storageDir = Path.addTrailingSlash(NativeBridge.getStorageDir());
		try
		{
			if (!FileSystem.exists(storageDir)) FileSystem.createDirectory(storageDir);
			Sys.setCwd(storageDir);
		}
		catch (e:Dynamic)
		{
			trace('Could not change working directory: $e');
		}
		#elseif sys
		storageDir = Path.addTrailingSlash(Sys.getCwd());
		#end

		#if sys
		for (folder in ['mods', 'import'])
			if (!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
		if (!FileSystem.exists('modsList.txt')) File.saveContent('modsList.txt', '');
		#end
	}

	/** Returns the list of embedded files that should be on disk. */
	public static function assetList():Array<String>
	{
		return [for (id in lime.utils.Assets.list()) if (id.startsWith('assets/')) id];
	}

	public static function currentStamp():String
	{
		var meta = lime.app.Application.current.meta;
		return '${meta.get("version")}-${meta.get("build")}-${assetList().length}';
	}

	public static function needsCopy():Bool
	{
		#if mobile
		try
		{
			return !FileSystem.exists(STAMP_FILE) || File.getContent(STAMP_FILE).trim() != currentStamp();
		}
		catch (e:Dynamic) {}
		return true;
		#else
		return false;
		#end
	}

	public static function copyAsset(id:String):Bool
	{
		#if sys
		try
		{
			var bytes = lime.utils.Assets.getBytes(id);
			if (bytes == null) return false;
			var dir = Path.directory(id);
			if (dir.length > 0 && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			File.saveBytes(id, bytes);
			return true;
		}
		catch (e:Dynamic)
		{
			trace('Failed to copy $id: $e');
		}
		#end
		return false;
	}

	public static function markCopied():Void
	{
		#if sys
		try File.saveContent(STAMP_FILE, currentStamp()) catch (e:Dynamic) {}
		#end
	}
}

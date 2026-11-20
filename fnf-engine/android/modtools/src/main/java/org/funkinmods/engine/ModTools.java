package org.funkinmods.engine;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.util.Log;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

import org.haxe.extension.Extension;

/**
 * Small native helper used by the engine on Android:
 *  - tells Haxe where the app's storage folder is
 *  - opens the system file picker so the player can choose a mod archive
 *  - copies the chosen file into the app folder, where Haxe can read it
 *
 * Haxe polls getPickState() every frame while a pick is running.
 */
public class ModTools extends Extension {

	private static final String TAG = "ModTools";
	private static final int REQUEST_PICK_MOD = 0x4D4F44; // "MOD"

	public static final int STATE_IDLE = 0;
	public static final int STATE_PICKING = 1;
	public static final int STATE_COPYING = 2;
	public static final int STATE_DONE = 3;
	public static final int STATE_CANCELLED = 4;
	public static final int STATE_ERROR = 5;

	private static volatile int pickState = STATE_IDLE;
	private static volatile String pickResult = "";

	public static String getStorageDir() {
		try {
			File dir = mainContext.getExternalFilesDir(null);
			if (dir != null) {
				dir.mkdirs();
				if (dir.canWrite()) return dir.getAbsolutePath();
			}
		} catch (Throwable e) {
			Log.e(TAG, "External files dir unavailable", e);
		}
		return mainContext.getFilesDir().getAbsolutePath();
	}

	public static void pickModArchive() {
		pickState = STATE_PICKING;
		pickResult = "";
		mainActivity.runOnUiThread(new Runnable() {
			@Override public void run() {
				try {
					Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
					intent.addCategory(Intent.CATEGORY_OPENABLE);
					intent.setType("*/*");
					intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[] {
						"application/zip",
						"application/x-zip",
						"application/x-zip-compressed",
						"application/octet-stream",
						"application/vnd.android.package-archive"
					});
					mainActivity.startActivityForResult(intent, REQUEST_PICK_MOD);
				} catch (Throwable e) {
					Log.e(TAG, "Could not open the file picker", e);
					pickResult = "Could not open the file picker: " + e.getMessage();
					pickState = STATE_ERROR;
				}
			}
		});
	}

	public static int getPickState() {
		return pickState;
	}

	public static String getPickResult() {
		return pickResult;
	}

	public static void resetPick() {
		pickState = STATE_IDLE;
		pickResult = "";
	}

	public static void toast(final String text) {
		mainActivity.runOnUiThread(new Runnable() {
			@Override public void run() {
				Toast.makeText(mainContext, text, Toast.LENGTH_LONG).show();
			}
		});
	}

	@Override
	public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
		if (requestCode != REQUEST_PICK_MOD) return true;

		if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
			pickState = STATE_CANCELLED;
			return false;
		}

		final Uri uri = data.getData();
		pickState = STATE_COPYING;
		new Thread(new Runnable() {
			@Override public void run() {
				copyToImportFolder(uri);
			}
		}).start();
		return false;
	}

	private static void copyToImportFolder(Uri uri) {
		InputStream in = null;
		OutputStream out = null;
		try {
			File importDir = new File(getStorageDir(), "import");
			importDir.mkdirs();

			String name = queryDisplayName(uri);
			if (name == null || name.length() == 0) name = "mod.zip";
			name = name.replaceAll("[\\\\/:*?\"<>|]", "_");
			File target = new File(importDir, name);

			in = mainContext.getContentResolver().openInputStream(uri);
			if (in == null) throw new Exception("The file could not be opened");
			out = new FileOutputStream(target);
			byte[] buffer = new byte[1 << 16];
			int read;
			while ((read = in.read(buffer)) != -1) out.write(buffer, 0, read);
			out.flush();

			pickResult = target.getAbsolutePath();
			pickState = STATE_DONE;
		} catch (Throwable e) {
			Log.e(TAG, "Copy failed", e);
			pickResult = "Could not read the file: " + e.getMessage();
			pickState = STATE_ERROR;
		} finally {
			try { if (in != null) in.close(); } catch (Throwable ignored) {}
			try { if (out != null) out.close(); } catch (Throwable ignored) {}
		}
	}

	private static String queryDisplayName(Uri uri) {
		Cursor cursor = null;
		try {
			cursor = mainContext.getContentResolver().query(uri, null, null, null, null);
			if (cursor != null && cursor.moveToFirst()) {
				int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
				if (index >= 0) return cursor.getString(index);
			}
		} catch (Throwable ignored) {
		} finally {
			if (cursor != null) cursor.close();
		}
		String path = uri.getLastPathSegment();
		if (path != null && path.lastIndexOf('/') >= 0) path = path.substring(path.lastIndexOf('/') + 1);
		return path;
	}
}

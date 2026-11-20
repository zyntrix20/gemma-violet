package modding;

using StringTools;

typedef TranslatedScript =
{
	var kind:String; // song, stage, module, event, notekind, character, other
	var id:String;
	var code:String;
}

/**
 * Turns a V-Slice scripted class (.hxc), e.g.
 *
 *     class BopeeboSong extends Song {
 *         public function new() { super('bopeebo'); }
 *         override function onBeatHit(event) { super.onBeatHit(event); ... }
 *     }
 *
 * into a plain HScript file with top-level functions, which CompatHScript
 * runs with V-Slice-like helpers (PlayState.instance.currentStage, Conductor.instance...).
 */
class ScriptTranslator
{
	static final MODIFIERS = ~/(^|[\s;{}])((?:public|private|override|static|inline|final|dynamic|macro)\s+)+(?=(function|var|final)\b)/g;

	public static function translate(source:String):TranslatedScript
	{
		var code = source.replace('\r\n', '\n');

		var header = ~/class\s+(\w+)\s+extends\s+([\w.]+)[^{]*\{/;
		if (!header.match(code)) return null;
		var parent = header.matched(2);
		parent = parent.substr(parent.lastIndexOf('.') + 1);
		var bodyStart = header.matchedPos().pos + header.matchedPos().len;
		var bodyEnd = matchBrace(code, bodyStart - 1);
		if (bodyEnd < 0) return null;
		var before = code.substr(0, header.matchedPos().pos);
		var body = code.substring(bodyStart, bodyEnd);

		// constructor -> id, then drop it
		var id = '';
		var hasCtor = false;
		var ctor = ~/function\s+new\s*\(/;
		if (ctor.match(body))
		{
			var p = ctor.matchedPos();
			var open = body.indexOf('{', p.pos + p.len);
			var close = open >= 0 ? matchBrace(body, open) : -1;
			if (close > 0)
			{
				var ctorBody = body.substring(open, close);
				var sup = ~/super\s*\(\s*['"]([^'"]+)['"]/;
				if (sup.match(ctorBody)) id = sup.matched(1);
				// keep any extra setup code from the constructor
				var extra = ~/super\s*\([^;]*\)\s*;/.replace(ctorBody.substr(1), '');
				var startCut = p.pos;
				// include preceding modifiers
				var mods = ~/((?:public|private|override)\s+)+$/;
				var pre = body.substr(0, startCut);
				if (mods.match(pre)) startCut = mods.matchedPos().pos;
				body = body.substr(0, startCut) + '\nfunction __ctorExtra() {' + extra + '\n}\n' + body.substr(close + 1);
				hasCtor = true;
			}
		}

		body = MODIFIERS.map(body, r -> r.matched(1));
		// super calls have no meaning here
		// statement calls are dropped, calls used as values become null
		body = ~/(^|[;{}\n])(\s*)super\.\w+\s*\(([^()]|\([^()]*\))*\)\s*;/g.replace(body, '$1$2');
		body = ~/super\.\w+\s*\(([^()]|\([^()]*\))*\)/g.replace(body, 'null');
		body = ~/\bthis\./g.replace(body, '');

		// keep only imports of classes that exist in this engine
		var imports:Array<String> = [];
		for (line in before.split('\n'))
		{
			var l = line.trim();
			if (!l.startsWith('import ')) continue;
			var cls = l.substr(7).replace(';', '').trim();
			if (cls.startsWith('flixel.') || cls.startsWith('openfl.') || cls.startsWith('haxe.') || cls.startsWith('StringTools') || cls.startsWith('Math'))
				imports.push(l.endsWith(';') ? l : l + ';');
		}

		var kind = switch (parent)
		{
			case 'Song': 'song';
			case 'Stage': 'stage';
			case 'Module': 'module';
			case 'SongEvent': 'event';
			case 'NoteKind': 'notekind';
			default: parent.endsWith('Character') ? 'character' : 'other';
		}

		var out = '// Translated from a V-Slice script (${header.matched(1)} extends $parent)\n';
		out += imports.join('\n') + '\n';
		out += body + '\n';
		if (hasCtor) out += '__ctorExtra();\n';
		return {kind: kind, id: id, code: out};
	}

	/** Index of the brace matching the one at `openPos`, skipping strings and comments. */
	public static function matchBrace(s:String, openPos:Int):Int
	{
		var depth = 0;
		var i = openPos;
		var len = s.length;
		while (i < len)
		{
			var c = s.charAt(i);
			if (c == '/' && i + 1 < len && s.charAt(i + 1) == '/')
			{
				var nl = s.indexOf('\n', i);
				i = nl < 0 ? len : nl;
				continue;
			}
			if (c == '/' && i + 1 < len && s.charAt(i + 1) == '*')
			{
				var end = s.indexOf('*/', i + 2);
				i = end < 0 ? len : end + 2;
				continue;
			}
			if (c == '"' || c == "'")
			{
				var j = i + 1;
				while (j < len && s.charAt(j) != c)
				{
					if (s.charAt(j) == '\\') j++;
					j++;
				}
				i = j + 1;
				continue;
			}
			if (c == '{') depth++;
			else if (c == '}')
			{
				depth--;
				if (depth == 0) return i;
			}
			i++;
		}
		return -1;
	}
}

package modding;

import haxe.Json;
import modding.ConvertContext.PsychSongEntry;

using StringTools;

/**
 * Converts a Codename Engine mod folder (already extracted into
 * `mods/<name>/`) into Psych Engine's layout:
 *
 *   songs/<song>/charts/<diff>.json + meta.json -> data/<song>/<song>[-diff].json
 *   songs/<song>/song/Inst.ogg, Voices*.ogg     -> songs/<song>/Inst.ogg, Voices*.ogg
 *   data/characters/*.xml -> characters/*.json
 *   data/stages/*.xml     -> stages/*.json
 *   data/weeks/weeks/*.xml -> weeks/*.json
 *
 * Codename HScript files use a different API and are skipped.
 */
class CodenameConverter
{
	static final STAGE_RENAMES:Map<String, String> = [
		'stage' => 'stage',
		'spooky' => 'spooky',
		'philly' => 'philly',
		'limo' => 'limo',
		'mall' => 'mall',
		'mall-evil' => 'mallEvil',
		'school' => 'school',
		'school-evil' => 'schoolEvil',
		'tank' => 'tank'
	];

	static final NOTE_TYPES:Map<String, String> = [
		'No Anim Note' => 'No Animation',
		'Alt Anim Note' => 'Alt Animation',
		'Hurt Note' => 'Hurt Note',
		'GF Sing' => 'GF Sing',
		'GF Sing Note' => 'GF Sing'
	];

	var ctx:ConvertContext;
	var songsByFolder:Map<String, PsychSongEntry> = [];
	var convertedStages:Array<String> = [];

	public function new(ctx:ConvertContext)
	{
		this.ctx = ctx;
	}

	public function run():Void
	{
		convertCharacters();
		convertStages();
		convertSongs();
		convertWeeks();
		if (!ModFiles.exists(ctx.path('pack.json')))
			ModFiles.writeJson(ctx.path('pack.json'), {
				name: ctx.modName,
				description: 'Converted from a Codename Engine mod.',
				color: [146, 113, 253],
				restart: false,
				runsGlobally: false
			});
		reportScripts();
	}

	// ------------------------------------------------------------ helpers

	static function attr(x:Xml, name:String, ?def:String):String
	{
		var v = x.get(name);
		return v != null ? v : def;
	}

	static function attrF(x:Xml, name:String, def:Float):Float
		return ModFiles.toFloat(x.get(name), def);

	static function attrB(x:Xml, name:String, def:Bool):Bool
		return ModFiles.toBool(x.get(name), def);

	/** Parses Codename index lists like "2..12,0,1". */
	static function parseIndices(s:String):Array<Int>
	{
		var out:Array<Int> = [];
		if (s == null) return out;
		for (part in s.split(','))
		{
			part = part.trim();
			if (part.length == 0) continue;
			var range = part.split('..');
			if (range.length == 2)
			{
				var a = Std.parseInt(range[0]);
				var b = Std.parseInt(range[1]);
				if (a == null || b == null) continue;
				if (a <= b) for (i in a...b + 1) out.push(i);
				else
				{
					var i = a;
					while (i >= b) out.push(i--);
				}
			}
			else
			{
				var v = Std.parseInt(part);
				if (v != null) out.push(v);
			}
		}
		return out;
	}

	static function readXml(path:String):Xml
	{
		if (!ModFiles.exists(path)) return null;
		try
		{
			var text = ModFiles.readText(path);
			return Xml.parse(text).firstElement();
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	// --------------------------------------------------------- characters

	function convertCharacters():Void
	{
		var dir = ctx.path('data/characters');
		for (file in ModFiles.list(dir))
		{
			if (!file.toLowerCase().endsWith('.xml')) continue;
			var id = file.substr(0, file.length - 4);
			var target = ctx.path('characters/$id.json');
			if (ModFiles.exists(target)) continue;
			var xml = readXml('$dir/$file');
			if (xml == null)
			{
				ctx.warn('Character "$id" has invalid XML.');
				continue;
			}

			var anims:Array<Dynamic> = [];
			for (a in xml.elementsNamed('anim'))
			{
				anims.push({
					anim: attr(a, 'name', 'idle'),
					name: attr(a, 'anim', attr(a, 'name', 'idle')),
					fps: Std.int(attrF(a, 'fps', 24)),
					loop: attrB(a, 'loop', false),
					indices: parseIndices(a.get('indices')),
					offsets: [Math.round(attrF(a, 'x', 0)), Math.round(attrF(a, 'y', 0))]
				});
			}

			var isPlayer = attrB(xml, 'isPlayer', false);
			var camX = attrF(xml, 'camx', 0);
			var sprite = attr(xml, 'sprite', id);
			ModFiles.writeJson(target, {
				animations: anims,
				image: 'characters/$sprite',
				scale: attrF(xml, 'scale', 1),
				sing_duration: attrF(xml, 'holdTime', 4),
				healthicon: attr(xml, 'icon', id),
				position: [attrF(xml, 'x', 0), attrF(xml, 'y', 0)],
				camera_position: [isPlayer ? -camX : camX, attrF(xml, 'camy', 0)],
				flip_x: attrB(xml, 'flipX', false),
				no_antialiasing: !attrB(xml, 'antialiasing', true),
				healthbar_colors: ModFiles.colorToRGB(xml.get('color'), [161, 161, 161]),
				vocals_file: '',
				_editor_isPlayer: isPlayer
			});
			ctx.charactersConverted++;
		}
	}

	// ------------------------------------------------------------- stages

	function convertStages():Void
	{
		var dir = ctx.path('data/stages');
		for (file in ModFiles.list(dir))
		{
			if (!file.toLowerCase().endsWith('.xml')) continue;
			var id = file.substr(0, file.length - 4);
			var target = ctx.path('stages/$id.json');
			if (ModFiles.exists(target)) continue;
			var xml = readXml('$dir/$file');
			if (xml == null)
			{
				ctx.warn('Stage "$id" has invalid XML.');
				continue;
			}
			var stage:Dynamic = convertStage(xml);

			// a copy of a base-game stage without its images: use Psych's own version instead
			var images = [for (o in (stage.objects : Array<Dynamic>)) if (o.image != null && o.image != '') (o.image : String)];
			var found = images.filter(i -> ModFiles.exists(ctx.path('images/$i.png')) || ModFiles.exists('assets/shared/images/$i.png')).length;
			if (images.length > 0 && found == 0 && STAGE_RENAMES.exists(id)) continue;

			ModFiles.writeJson(target, stage);
			convertedStages.push(id);
			ctx.stagesConverted++;
		}
	}

	function convertStage(xml:Xml):Dynamic
	{
		var folder = attr(xml, 'folder', '');
		if (folder.length > 0 && !folder.endsWith('/')) folder += '/';

		var objects:Array<Dynamic> = [];
		var dancers:Array<Dynamic> = [];
		var stage:Dynamic = {
			directory: '',
			defaultZoom: attrF(xml, 'zoom', 1.05),
			isPixelStage: false,
			stageUI: 'normal',
			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,
			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1
		};
		var seen = {bf: false, dad: false, gf: false};
		var count = 0;

		function addChar(node:Xml, key:String):Void
		{
			var defaults = switch (key)
			{
				case 'bf': [770.0, 100.0];
				case 'dad': [100.0, 100.0];
				default: [400.0, 130.0];
			}
			var pos = [attrF(node, 'x', defaults[0]), attrF(node, 'y', defaults[1])];
			var cam = [attrF(node, 'camxoffset', 0), attrF(node, 'camyoffset', 0)];
			switch (key)
			{
				case 'bf':
					stage.boyfriend = pos;
					stage.camera_boyfriend = cam;
					seen.bf = true;
					objects.push({type: 'boyfriend'});
				case 'dad':
					stage.opponent = pos;
					stage.camera_opponent = cam;
					seen.dad = true;
					objects.push({type: 'dad'});
				default:
					stage.girlfriend = pos;
					stage.camera_girlfriend = cam;
					seen.gf = true;
					objects.push({type: 'gf'});
			}
		}

		function walk(parent:Xml, filters:Int):Void
		{
			for (node in parent.elements())
			{
				switch (node.nodeName.toLowerCase())
				{
					case 'high-memory':
						walk(node, 2);
					case 'low-memory':
						walk(node, 1);
					case 'boyfriend' | 'bf' | 'player':
						addChar(node, 'bf');
					case 'dad' | 'opponent':
						addChar(node, 'dad');
					case 'girlfriend' | 'gf':
						addChar(node, 'gf');
					case 'sprite' | 'spr' | 'sparrow':
						count++;
						var name = attr(node, 'name', 'sprite$count');
						var scale = node.exists('scale') ? ModFiles.pair(node.get('scale'), 1) : [attrF(node, 'scalex', 1), attrF(node, 'scaley', 1)];
						var scroll = node.exists('scroll') ? ModFiles.pair(node.get('scroll'), 1) : [attrF(node, 'scrollx', 1), attrF(node, 'scrolly', 1)];
						var anims:Array<Dynamic> = [];
						for (a in node.elementsNamed('anim'))
						{
							anims.push({
								anim: attr(a, 'name', 'idle'),
								name: attr(a, 'anim', attr(a, 'name', 'idle')),
								fps: Std.int(attrF(a, 'fps', 24)),
								loop: attrB(a, 'loop', false),
								indices: parseIndices(a.get('indices')),
								offsets: [Math.round(attrF(a, 'x', 0)), Math.round(attrF(a, 'y', 0))]
							});
						}
						var obj:Dynamic = {
							type: anims.length > 0 ? 'animatedSprite' : 'sprite',
							name: name,
							image: folder + attr(node, 'sprite', name),
							x: attrF(node, 'x', 0),
							y: attrF(node, 'y', 0),
							scale: scale,
							scroll: scroll,
							alpha: attrF(node, 'alpha', 1),
							angle: attrF(node, 'angle', 0),
							color: node.exists('color') ? ModFiles.rgbToHex(ModFiles.colorToRGB(node.get('color'), [255, 255, 255])) : '#FFFFFF',
							filters: filters,
							flipX: attrB(node, 'flipX', false),
							flipY: attrB(node, 'flipY', false),
							antialiasing: attrB(node, 'antialiasing', true)
						};
						if (anims.length > 0)
						{
							obj.animations = anims;
							obj.firstAnimation = anims[0].anim;
							var type = attr(node, 'type', '').toLowerCase();
							if (type == 'beat' || type == 'onbeat') dancers.push({name: name, danceEvery: 1});
						}
						objects.push(obj);
					case 'box' | 'solid':
						count++;
						var name = attr(node, 'name', 'box$count');
						objects.push({
							type: 'square',
							name: name,
							image: '',
							x: attrF(node, 'x', 0),
							y: attrF(node, 'y', 0),
							scale: [attrF(node, 'width', 1), attrF(node, 'height', 1)],
							scroll: node.exists('scroll') ? ModFiles.pair(node.get('scroll'), 1) : [attrF(node, 'scrollx', 1), attrF(node, 'scrolly', 1)],
							alpha: attrF(node, 'alpha', 1),
							angle: 0,
							color: ModFiles.rgbToHex(ModFiles.colorToRGB(node.get('color'), [0, 0, 0])),
							filters: filters
						});
					default:
				}
			}
		}
		walk(xml, 3);

		// Codename adds missing characters on top of the stage
		if (!seen.gf) objects.push({type: 'gf'});
		if (!seen.dad) objects.push({type: 'dad'});
		if (!seen.bf) objects.push({type: 'boyfriend'});
		stage.objects = objects;
		if (dancers.length > 0) stage.vslice = {dancers: dancers};
		return stage;
	}

	function resolveStage(stage:String):String
	{
		if (stage == null || stage.length == 0) return 'stage';
		if (convertedStages.contains(stage) || ModFiles.exists(ctx.path('stages/$stage.json'))) return stage;
		if (STAGE_RENAMES.exists(stage)) return STAGE_RENAMES.get(stage);
		ctx.warn('Stage "$stage" is not included in the mod; using the default stage.');
		return 'stage';
	}

	// -------------------------------------------------------------- songs

	function convertSongs():Void
	{
		var root = ctx.path('songs');
		var folders = ModFiles.list(root).filter(f -> ModFiles.isDir('$root/$f/charts'));
		for (folder in folders)
		{
			try
			{
				convertSong(folder);
			}
			catch (e:Dynamic)
			{
				ctx.warn('Song "$folder" could not be converted: $e');
			}
		}
	}

	function convertSong(folder:String):Void
	{
		var dir = ctx.path('songs/$folder');
		var meta:Dynamic = ModFiles.readJson('$dir/meta.json');
		if (meta == null) meta = {};
		var name:String = ModFiles.field(meta, 'displayName', ModFiles.field(meta, 'name', folder));
		var id = ctx.uniqueSongId(ModFiles.formatSong(name));
		if (id.length == 0) id = ctx.uniqueSongId(ModFiles.formatSong(folder));
		var bpm = ModFiles.toFloat(ModFiles.field(meta, 'bpm'), 100);
		var beatsPerMeasure = ModFiles.toFloat(ModFiles.field(meta, 'beatsPerMeasure'), 4);

		var globalEvents:Array<Dynamic> = [];
		var ev:Dynamic = ModFiles.readJson('$dir/events.json');
		if (ev != null) globalEvents = ModFiles.field(ev, 'events', []);

		// audio: songs/<song>/song/*.ogg -> songs/<id>/*.ogg
		var audioDir = '$dir/song';
		var outDir = ctx.path('songs/$id');
		var audioFiles = ModFiles.list(audioDir).filter(f -> f.toLowerCase().endsWith('.ogg'));

		var diffs:Array<String> = [];
		var diffNames:Array<String> = [];
		var hasVoices = audioFiles.filter(f -> f.toLowerCase().startsWith('voices')).length > 0;
		var player1 = 'bf';
		var player2 = 'dad';
		var gfVersion = 'gf';
		var playerSuffix = '';
		var opponentSuffix = '';

		for (chartFile in ModFiles.list('$dir/charts'))
		{
			if (!chartFile.toLowerCase().endsWith('.json')) continue;
			var diff = chartFile.substr(0, chartFile.length - 5);
			var chart:Dynamic = ModFiles.readJson('$dir/charts/$chartFile');
			if (chart == null) continue;

			var result = convertChart(chart, globalEvents, bpm, beatsPerMeasure);
			player1 = result.player1;
			player2 = result.player2;
			gfVersion = result.gf;
			playerSuffix = result.playerSuffix;
			opponentSuffix = result.opponentSuffix;

			var song:Dynamic = {
				song: name,
				notes: result.sections,
				events: [],
				bpm: bpm,
				needsVoices: hasVoices && ModFiles.toBool(ModFiles.field(meta, 'needsVoices'), true),
				speed: ModFiles.toFloat(ModFiles.field(chart, 'scrollSpeed'), 1),
				offset: 0,
				player1: player1,
				player2: player2,
				gfVersion: gfVersion,
				stage: resolveStage(ModFiles.field(chart, 'stage', 'stage')),
				format: 'psych_v1'
			};
			ModFiles.writeJson(ctx.path('data/$id/' + ConvertContext.chartFile(id, diff)), song);
			if (result.events.length > 0 && !ModFiles.exists(ctx.path('data/$id/events.json')))
				ModFiles.writeJson(ctx.path('data/$id/events.json'), {song: {events: result.events, notes: [], format: 'psych_v1'}});
			diffs.push(diff);
		}
		if (diffs.length == 0) throw 'no charts';
		diffs = ConvertContext.sortDifficulties(diffs);
		diffNames = [for (d in diffs) ConvertContext.difficultyName(d)];

		// move audio, renaming per-strumline vocals to Psych's names
		for (f in audioFiles)
		{
			var lower = f.toLowerCase();
			var target = f;
			if (lower == 'inst.ogg') target = 'Inst.ogg';
			else if (lower == 'voices.ogg') target = 'Voices.ogg';
			else if (playerSuffix.length > 0 && lower == 'voices$playerSuffix.ogg'.toLowerCase()) target = 'Voices-Player.ogg';
			else if (opponentSuffix.length > 0 && lower == 'voices$opponentSuffix.ogg'.toLowerCase()) target = 'Voices-Opponent.ogg';
			ModFiles.move('$audioDir/$f', '$outDir/$target');
		}
		if (!ModFiles.exists('$outDir/Inst.ogg')) ctx.warn('Song "$name" has no instrumental (Inst.ogg).');
		ModFiles.deleteRecursive('$dir/charts');
		ModFiles.pruneEmpty(dir);

		var icon:String = ModFiles.field(meta, 'icon', null);
		var info = ctx.characterIcon(player2);
		var entry:PsychSongEntry = {
			name: name,
			id: id,
			icon: icon != null ? icon : info.icon,
			color: ModFiles.colorToRGB(ModFiles.field(meta, 'color'), info.color),
			difficulties: diffNames
		};
		ctx.songs.push(entry);
		songsByFolder.set(folder.toLowerCase(), entry);
		songsByFolder.set(ModFiles.formatSong(name), entry);
		ctx.log('Converted song: $name (${diffNames.join(", ")})');
	}

	function convertChart(chart:Dynamic, globalEvents:Array<Dynamic>, bpm:Float, beatsPerMeasure:Float)
	{
		var strumLines:Array<Dynamic> = ModFiles.field(chart, 'strumLines', []);
		var noteTypes:Array<String> = ModFiles.field(chart, 'noteTypes', []);
		var events:Array<Dynamic> = ModFiles.field(chart, 'events', []);
		events = events.concat(globalEvents);
		events.sort((a, b) -> ModFiles.toFloat(a.time, 0) < ModFiles.toFloat(b.time, 0) ? -1 : 1);

		var player1 = 'bf', player2 = 'dad', gf = 'gf';
		var playerSuffix = '', opponentSuffix = '';
		var foundPlayer = false, foundOpp = false, foundGf = false;
		for (sl in strumLines)
		{
			var type = Std.int(ModFiles.toFloat(ModFiles.field(sl, 'type'), 0));
			var chars:Array<String> = ModFiles.field(sl, 'characters', []);
			var suffix:String = ModFiles.field(sl, 'vocalsSuffix', '');
			if (suffix.length > 0 && !suffix.startsWith('-')) suffix = '-' + suffix;
			if (type == 1 && !foundPlayer)
			{
				if (chars.length > 0) player1 = chars[0];
				playerSuffix = suffix;
				foundPlayer = true;
			}
			else if (type == 0 && !foundOpp)
			{
				if (chars.length > 0) player2 = chars[0];
				opponentSuffix = suffix;
				foundOpp = true;
			}
			else if (type == 2 && !foundGf)
			{
				if (chars.length > 0) gf = chars[0];
				foundGf = true;
			}
		}

		// tempo map
		var changes:Array<{t:Float, bpm:Float}> = [{t: 0, bpm: bpm}];
		for (e in events)
			if (e.name == 'BPM Change')
			{
				var params:Array<Dynamic> = ModFiles.field(e, 'params', []);
				if (params.length > 0) changes.push({t: ModFiles.toFloat(e.time, 0), bpm: ModFiles.toFloat(params[0], bpm)});
			}

		function bpmAt(time:Float):Float
		{
			var b = bpm;
			for (c in changes)
			{
				if (c.t > time + 0.5) break;
				b = c.bpm;
			}
			return b;
		}

		// camera: strumline index -> section focus
		var camEvents = events.filter(e -> e.name == 'Camera Movement');
		function focusAt(time:Float):Int
		{
			var type = 0;
			for (e in camEvents)
			{
				if (ModFiles.toFloat(e.time, 0) > time + 1) break;
				var params:Array<Dynamic> = ModFiles.field(e, 'params', [0]);
				var sl:Dynamic = strumLines[Std.int(ModFiles.toFloat(params[0], 0))];
				type = sl != null ? Std.int(ModFiles.toFloat(ModFiles.field(sl, 'type'), 0)) : 0;
			}
			return type;
		}

		var lastTime:Float = 0;
		for (sl in strumLines)
		{
			var notes:Array<Dynamic> = ModFiles.field(sl, 'notes', []);
			for (n in notes) lastTime = Math.max(lastTime, ModFiles.toFloat(n.time, 0) + ModFiles.toFloat(ModFiles.field(n, 'sLen'), 0));
		}

		var sectionTimes:Array<Float> = [];
		var sections:Array<Dynamic> = [];
		var t:Float = 0;
		var lastBpm = bpm;
		while (t <= lastTime + 1 || sections.length == 0)
		{
			var b = bpmAt(t);
			var focus = focusAt(t + 1);
			var sec:Dynamic = {sectionNotes: [], sectionBeats: beatsPerMeasure, mustHitSection: focus == 1};
			if (focus == 2) sec.gfSection = true;
			if (b != lastBpm)
			{
				sec.changeBPM = true;
				sec.bpm = b;
				lastBpm = b;
			}
			sectionTimes.push(t);
			sections.push(sec);
			t += (60000 / b) * beatsPerMeasure;
			if (sections.length > 20000) break;
		}

		var allNotes:Array<Array<Dynamic>> = [];
		for (sl in strumLines)
		{
			var type = Std.int(ModFiles.toFloat(ModFiles.field(sl, 'type'), 0));
			var notes:Array<Dynamic> = ModFiles.field(sl, 'notes', []);
			for (n in notes)
			{
				var id = Std.int(ModFiles.toFloat(n.id, 0));
				if (id < 0 || id > 3) continue;
				var lane = type == 1 ? id : id + 4;
				var arr:Array<Dynamic> = [ModFiles.toFloat(n.time, 0), lane, Math.max(0, ModFiles.toFloat(ModFiles.field(n, 'sLen'), 0))];
				var typeIndex = Std.int(ModFiles.toFloat(ModFiles.field(n, 'type'), 0));
				var typeName:String = typeIndex > 0 && typeIndex <= noteTypes.length ? noteTypes[typeIndex - 1] : null;
				if (type == 2 && typeName == null) typeName = 'GF Sing';
				if (typeName != null) arr.push(NOTE_TYPES.exists(typeName) ? NOTE_TYPES.get(typeName) : typeName);
				allNotes.push(arr);
			}
		}
		allNotes.sort((a, b) -> a[0] < b[0] ? -1 : (a[0] > b[0] ? 1 : 0));
		var secIndex = 0;
		for (n in allNotes)
		{
			while (secIndex + 1 < sectionTimes.length && sectionTimes[secIndex + 1] <= n[0]) secIndex++;
			sections[secIndex].sectionNotes.push(n);
		}

		// events
		var baseSpeed = ModFiles.toFloat(ModFiles.field(chart, 'scrollSpeed'), 1);
		if (baseSpeed <= 0) baseSpeed = 1;
		function targetOf(index:Dynamic):String
		{
			var sl:Dynamic = strumLines[Std.int(ModFiles.toFloat(index, 0))];
			var type = sl != null ? Std.int(ModFiles.toFloat(ModFiles.field(sl, 'type'), 0)) : 0;
			return type == 1 ? 'bf' : (type == 2 ? 'gf' : 'dad');
		}
		var psychEvents:Array<Dynamic> = [];
		for (e in events)
		{
			var time = ModFiles.toFloat(e.time, 0);
			var name:String = e.name;
			var p:Array<Dynamic> = ModFiles.field(e, 'params', []);
			var converted:Array<Dynamic> = switch (name)
			{
				case 'Camera Movement' | 'BPM Change' | 'Time Signature Change' | 'Continuous BPM Change':
					null; // handled by sections
				case 'Play Animation':
					['Play Animation', Std.string(p[1]), targetOf(p[0])];
				case 'Add Camera Zoom':
					var amount = ModFiles.toFloat(p[0], 0.015);
					var hud = Std.string(p[1]).toLowerCase().indexOf('hud') >= 0;
					['Add Camera Zoom', Std.string(hud ? 0 : amount), Std.string(hud ? amount : amount * 2)];
				case 'Scroll Speed Change':
					var tween = ModFiles.toBool(p[0], false);
					var speed = ModFiles.toFloat(p[1], baseSpeed);
					var steps = ModFiles.toFloat(p[2], 4);
					var secs = tween ? steps * (60000 / bpmAt(time)) / 4 / 1000 : 0;
					['Change Scroll Speed', Std.string(speed / baseSpeed), Std.string(secs)];
				case 'Camera Position':
					['Camera Follow Pos', Std.string(p[0]), Std.string(p[1])];
				case 'Camera Zoom':
					var tween = ModFiles.toBool(p[0], true);
					var zoom = ModFiles.toFloat(p[1], 1);
					var steps = ModFiles.toFloat(p[3], 4);
					var ease = Std.string(p[4] != null ? p[4] : 'linear') + Std.string(p[5] != null && p[5] != 'NONE' ? p[5] : '');
					var mode = Std.string(p[6] != null ? p[6] : 'direct');
					['ZoomCamera', Json.stringify({zoom: zoom, duration: tween ? steps : 0, ease: tween ? ease : 'INSTANT', mode: mode == 'stage' ? 'stage' : 'direct'}), ''];
				case 'Camera Flash':
					// params: [reversed, color, time (seconds), camera]
					var color = p.length > 1 ? Std.string(p[1]) : '#FFFFFF';
					var hud = p.length > 3 && Std.string(p[3]).toLowerCase().indexOf('hud') >= 0;
					['CameraFlash', Json.stringify({color: color, duration: ModFiles.toFloat(p[2], 1), hud: hud, reversed: ModFiles.toBool(p[0], false)}), ''];
				case 'Camera Modulo Change':
					// params: [bop every N beats, intensity]
					['SetCameraBop', Json.stringify({rate: ModFiles.toFloat(p[0], 4), intensity: ModFiles.toFloat(p[1], 1)}), ''];
				case 'Alt Animation Toggle':
					// params: [alt sing, alt idle, strumline]
					['Alt Idle Animation', targetOf(p[2]), ModFiles.toBool(p[1], false) ? '-alt' : ''];
				default:
					[name, p.length > 0 ? Std.string(p[0]) : '', p.length > 1 ? Std.string(p[1]) : ''];
			}
			if (converted != null) psychEvents.push([time, [converted]]);
		}

		return {
			sections: sections,
			events: psychEvents,
			player1: player1,
			player2: player2,
			gf: gf,
			playerSuffix: playerSuffix,
			opponentSuffix: opponentSuffix
		};
	}

	// -------------------------------------------------------------- weeks

	function convertWeeks():Void
	{
		var used:Array<PsychSongEntry> = [];
		var weekNames:Array<String> = [];
		var dir = ctx.path('data/weeks/weeks');
		var files = ModFiles.list(dir).filter(f -> f.toLowerCase().endsWith('.xml'));

		// optional ordering file
		var orderFile = ctx.path('data/weeks/weeks.txt');
		if (ModFiles.exists(orderFile))
		{
			var order = [for (l in ModFiles.readText(orderFile).split('\n')) if (l.trim().length > 0 && !l.trim().startsWith('#')) l.trim().toLowerCase()];
			files.sort((a, b) ->
			{
				var ia = order.indexOf(a.substr(0, a.length - 4).toLowerCase());
				var ib = order.indexOf(b.substr(0, b.length - 4).toLowerCase());
				if (ia < 0) ia = 1000;
				if (ib < 0) ib = 1000;
				return ia - ib;
			});
		}

		for (file in files)
		{
			var id = file.substr(0, file.length - 4);
			var xml = readXml('$dir/$file');
			if (xml == null) continue;
			var weekId = ModFiles.formatSong(id);
			if (ModFiles.exists(ctx.path('weeks/$weekId.json'))) weekId += '-cne';

			var list:Array<PsychSongEntry> = [];
			for (s in xml.elementsNamed('song'))
			{
				var songName = s.firstChild() != null ? s.firstChild().nodeValue.trim() : '';
				var entry = songsByFolder.get(songName.toLowerCase());
				if (entry == null) entry = songsByFolder.get(ModFiles.formatSong(songName));
				if (entry == null)
				{
					ctx.warn('Week "$id" lists song "$songName", which is not in the mod.');
					continue;
				}
				list.push(entry);
				used.push(entry);
			}

			var sprite = attr(xml, 'sprite', id);
			ModFiles.copy(ctx.path('images/menus/storymenu/weeks/$sprite.png'), ctx.path('images/storymenu/$weekId.png'));

			var chars = attr(xml, 'chars', ',bf,gf').split(',');
			var weekChars = [for (i in 0...3)
			{
				var c = i < chars.length ? chars[i].trim() : '';
				(c != '' && c != 'none' && ModFiles.exists('assets/shared/images/menucharacters/$c.json')) ? c : '';
			}];

			var name = attr(xml, 'name', id);
			ctx.writeWeek(weekId, name.length > 0 ? name : id, list, {hideStoryMode: false, weekCharacters: weekChars});
			weekNames.push(weekId);
		}

		var leftovers = ctx.songs.filter(s -> !used.contains(s));
		weekNames = weekNames.concat(ctx.writeFreeplayWeeks(leftovers));
		ctx.writeWeekList(weekNames);
	}

	function reportScripts():Void
	{
		var scripts = ModFiles.walk(ctx.modDir).filter(f -> f.endsWith('.hx') && !f.startsWith('_codename_scripts/') && !f.startsWith('_compat/'));
		if (scripts.length == 0) return;

		var manifest:Dynamic = {engine: 'codename', songs: {}, stages: {}, characters: {}, global: [], events: {}, noteTypes: {}};
		function push(mapName:String, key:String, file:String)
		{
			var map:Dynamic = Reflect.field(manifest, mapName);
			var list:Array<String> = Reflect.field(map, key);
			if (list == null) Reflect.setField(map, key, list = []);
			if (!list.contains(file)) list.push(file);
		}

		var used = 0;
		for (f in scripts)
		{
			var target = '_codename_scripts/$f';
			// keep Psych from running them with its own API
			ModFiles.move(ctx.path(f), ctx.path(target));
			var parts = f.split('/');
			var file = parts[parts.length - 1];
			var name = file.substr(0, file.length - 3);
			var lower = f.toLowerCase();
			if (lower.startsWith('songs/') && parts.length >= 3)
			{
				var entry = songsByFolder.get(parts[1].toLowerCase());
				push('songs', entry != null ? entry.id : ModFiles.formatSong(parts[1]), target);
				used++;
			}
			else if (lower.startsWith('data/stages/'))
			{
				push('stages', name, target);
				if (STAGE_RENAMES.exists(name)) push('stages', STAGE_RENAMES.get(name), target);
				used++;
			}
			else if (lower.startsWith('data/characters/'))
			{
				push('characters', name, target);
				used++;
			}
			else if (lower.startsWith('data/events/'))
			{
				push('events', name, target);
				used++;
			}
			else if (lower.startsWith('data/notes/'))
			{
				push('noteTypes', name, target);
				used++;
			}
			else if (lower == 'data/global.hx' || lower.startsWith('data/scripts/') || lower.startsWith('scripts/'))
			{
				(manifest.global : Array<String>).push(target);
				used++;
			}
		}
		if (used > 0)
		{
			ModFiles.writeJson(ctx.path('_compat/scripts.json'), manifest);
			ctx.warn('$used Codename script(s) will run through the compatibility layer. Simple ones work; scripts that use Codename-only features may not.');
		}
		if (scripts.length > used)
			ctx.warn('${scripts.length - used} Codename script(s) (menus/states) are not used in songs and were skipped.');
	}
}

package modding;

import haxe.Json;
import modding.ConvertContext.PsychSongEntry;

using StringTools;

/**
 * Converts a V-Slice (Funkin' 0.3+ / Polymod) mod folder, already extracted
 * into `mods/<name>/`, into Psych Engine's layout:
 *
 *   data/songs/<id>/<id>-chart[-var].json + metadata -> data/<song>/<song>[-diff].json
 *   songs/<id>/Inst[-var].ogg, Voices-<char>[-var].ogg -> songs/<song>/Inst.ogg, Voices-Player/Opponent.ogg
 *   data/characters/*.json -> characters/*.json
 *   data/stages/*.json     -> stages/*.json (+ "vslice" layout block)
 *   data/levels/*.json     -> weeks/*.json
 *
 * Song variations (Erect, Pico mix...) become separate Freeplay entries.
 * Scripts (.hxc) cannot run in Psych and are reported as warnings.
 */
class VSliceConverter
{
	static final STAGE_RENAMES:Map<String, String> = [
		'mainStage' => 'stage',
		'spookyMansion' => 'spooky',
		'phillyTrain' => 'philly',
		'limoRide' => 'limo',
		'mallXmas' => 'mall',
		'mallEvil' => 'mallEvil',
		'school' => 'school',
		'schoolEvil' => 'schoolEvil',
		'tankmanBattlefield' => 'tank',
		'phillyStreets' => 'phillyStreets',
		'phillyBlazin' => 'phillyBlazin'
	];

	static final NOTE_KINDS:Map<String, String> = [
		'alt' => 'Alt Animation',
		'noanim' => 'No Animation',
		'no-anim' => 'No Animation',
		'hey' => 'Hey!',
		'gf' => 'GF Sing',
		'hurt' => 'Hurt Note'
	];

	var ctx:ConvertContext;
	var convertedStages:Array<String> = [];
	var pixelStages:Array<String> = [];
	/** V-Slice song id -> Psych entries per variation ('' = default) */
	var songMap:Map<String, Map<String, PsychSongEntry>> = [];
	var charactersWithDeath:Array<String> = [];
	var currentVariations:Array<String> = [];

	public function new(ctx:ConvertContext)
	{
		this.ctx = ctx;
	}

	public function run():Void
	{
		convertCharacters();
		convertStages();
		convertSongs();
		markPixelStages();
		convertLevels();
		convertPackMeta();
		reportScripts();
	}

	// ------------------------------------------------------------ characters

	function convertCharacters():Void
	{
		var dir = ctx.path('data/characters');
		for (file in ModFiles.list(dir))
		{
			if (!file.toLowerCase().endsWith('.json')) continue;
			var id = file.substr(0, file.length - 5);
			var data:Dynamic = ModFiles.readJson('$dir/$file');
			if (data == null || ModFiles.field(data, 'animations') == null) continue;
			var target = ctx.path('characters/$id.json');
			if (ModFiles.exists(target)) continue; // mod already ships a Psych version

			try
			{
				ModFiles.writeJson(target, convertCharacter(id, data));
				ctx.charactersConverted++;
			}
			catch (e:Dynamic)
			{
				ctx.warn('Character "$id" could not be converted: $e');
			}
		}
	}

	function convertCharacter(id:String, data:Dynamic):Dynamic
	{
		var mainAsset:String = ModFiles.stripLibrary(ModFiles.field(data, 'assetPath', 'characters/$id'));
		var renderType:String = ModFiles.field(data, 'renderType', 'sparrow');
		var images:Array<String> = [mainAsset];
		var anims:Array<Dynamic> = [];
		var hasDeath = false;

		var sourceAnims:Array<Dynamic> = ModFiles.field(data, 'animations', []);
		for (anim in sourceAnims)
		{
			var name:String = ModFiles.field(anim, 'name', 'idle');
			if (name == 'firstDeath') hasDeath = true;
			var animAsset:String = ModFiles.stripLibrary(ModFiles.field(anim, 'assetPath'));
			if (animAsset != null && animAsset.length > 0 && !images.contains(animAsset))
			{
				if (renderType == 'multisparrow') images.push(animAsset);
			}
			var offsets:Array<Float> = ModFiles.pair(ModFiles.field(anim, 'offsets'), 0);
			var indices:Array<Dynamic> = ModFiles.field(anim, 'frameIndices', []);
			anims.push({
				anim: name,
				name: ModFiles.field(anim, 'prefix', name),
				fps: Std.int(ModFiles.toFloat(ModFiles.field(anim, 'frameRate'), 24)),
				loop: ModFiles.toBool(ModFiles.field(anim, 'looped'), false),
				indices: [for (i in indices) Std.int(ModFiles.toFloat(i, 0))],
				offsets: [Math.round(offsets[0]), Math.round(offsets[1])]
			});
		}
		if (hasDeath) charactersWithDeath.push(id);

		var icon:Dynamic = ModFiles.field(data, 'healthIcon');
		var iconId:String = icon != null ? ModFiles.field(icon, 'id', id) : id;
		var offsets = ModFiles.pair(ModFiles.field(data, 'offsets'), 0);
		var camOffsets = ModFiles.pair(ModFiles.field(data, 'cameraOffsets'), 0);
		var isPixel = ModFiles.toBool(ModFiles.field(data, 'isPixel'), false);
		// V-Slice has no per-character bar colors: use its red (opponent) / green (player) bar
		var designedAsPlayer = ModFiles.toBool(ModFiles.field(data, 'flipX'), false);
		var color = ModFiles.colorToRGB(ModFiles.field(data, 'healthBarColor'), designedAsPlayer ? [102, 255, 51] : [255, 0, 0]);

		return {
			animations: anims,
			image: images.join(','),
			scale: ModFiles.toFloat(ModFiles.field(data, 'scale'), 1),
			sing_duration: ModFiles.toFloat(ModFiles.field(data, 'singTime'), 8),
			healthicon: iconId,
			position: offsets,
			camera_position: [0, 0],
			vslice_camera: camOffsets,
			flip_x: ModFiles.toBool(ModFiles.field(data, 'flipX'), false),
			no_antialiasing: isPixel,
			healthbar_colors: color,
			vocals_file: '',
			_editor_isPlayer: ModFiles.toBool(ModFiles.field(data, 'flipX'), false)
		};
	}

	// ---------------------------------------------------------------- stages

	function convertStages():Void
	{
		var dir = ctx.path('data/stages');
		for (file in ModFiles.list(dir))
		{
			if (!file.toLowerCase().endsWith('.json')) continue;
			var id = file.substr(0, file.length - 5);
			var data:Dynamic = ModFiles.readJson('$dir/$file');
			if (data == null || ModFiles.field(data, 'props') == null) continue;
			var target = ctx.path('stages/$id.json');
			if (ModFiles.exists(target)) continue;
			try
			{
				ModFiles.writeJson(target, convertStage(data));
				convertedStages.push(id);
				ctx.stagesConverted++;
			}
			catch (e:Dynamic)
			{
				ctx.warn('Stage "$id" could not be converted: $e');
			}
		}
	}

	function convertStage(data:Dynamic):Dynamic
	{
		var entries:Array<{z:Float, obj:Dynamic}> = [];
		var dancers:Array<Dynamic> = [];
		var props:Array<Dynamic> = ModFiles.field(data, 'props', []);
		var usedNames:Array<String> = ['gf', 'dad', 'boyfriend', 'gfGroup', 'dadGroup', 'boyfriendGroup'];

		for (num => prop in props)
		{
			var name:String = ModFiles.field(prop, 'name', 'prop$num');
			while (usedNames.contains(name)) name += '_';
			usedNames.push(name);

			var asset:String = ModFiles.stripLibrary(ModFiles.field(prop, 'assetPath', ''));
			var pos = ModFiles.pair(ModFiles.field(prop, 'position'), 0);
			var scale = ModFiles.pair(ModFiles.field(prop, 'scale'), 1);
			var anims:Array<Dynamic> = ModFiles.field(prop, 'animations', []);
			var isPixel = ModFiles.toBool(ModFiles.field(prop, 'isPixel'), false);
			var obj:Dynamic = {
				name: name,
				x: pos[0],
				y: pos[1],
				scale: scale,
				scroll: ModFiles.pair(ModFiles.field(prop, 'scroll'), 1),
				alpha: ModFiles.toFloat(ModFiles.field(prop, 'alpha'), 1),
				angle: ModFiles.toFloat(ModFiles.field(prop, 'angle'), 0),
				color: '#FFFFFF',
				filters: 3,
				flipX: ModFiles.toBool(ModFiles.field(prop, 'flipX'), false),
				flipY: ModFiles.toBool(ModFiles.field(prop, 'flipY'), false),
				antialiasing: !isPixel
			};

			if (asset.startsWith('#'))
			{
				// solid color rectangle; V-Slice uses "scale" as its size
				obj.type = 'square';
				obj.color = asset;
				obj.image = '';
			}
			else if (anims.length > 0)
			{
				obj.type = 'animatedSprite';
				obj.image = asset;
				obj.animations = [
					for (a in anims)
					{
						var o = ModFiles.pair(ModFiles.field(a, 'offsets'), 0);
						var idx:Array<Dynamic> = ModFiles.field(a, 'frameIndices', []);
						{
							anim: ModFiles.field(a, 'name', 'idle'),
							name: ModFiles.field(a, 'prefix', ModFiles.field(a, 'name', 'idle')),
							fps: Std.int(ModFiles.toFloat(ModFiles.field(a, 'frameRate'), 24)),
							loop: ModFiles.toBool(ModFiles.field(a, 'looped'), false),
							indices: [for (i in idx) Std.int(ModFiles.toFloat(i, 0))],
							offsets: [Math.round(o[0]), Math.round(o[1])]
						}
					}
				];
				var first:String = ModFiles.field(prop, 'startingAnimation');
				if (first != null) obj.firstAnimation = first;
				if (ModFiles.field(prop, 'animType', 'sparrow') == 'animateatlas')
					ctx.warn('Stage prop "$name" uses an Animate atlas, which Psych stages cannot load.');
			}
			else
			{
				obj.type = 'sprite';
				obj.image = asset;
			}

			var every = ModFiles.toFloat(ModFiles.field(prop, 'danceEvery'), 0);
			if (every > 0 && anims.length > 0) dancers.push({name: name, danceEvery: every});
			entries.push({z: ModFiles.toFloat(ModFiles.field(prop, 'zIndex'), num), obj: obj});
		}

		var chars:Dynamic = ModFiles.field(data, 'characters', {});
		var layout:Dynamic = {};
		for (key in ['bf', 'dad', 'gf'])
		{
			var c:Dynamic = ModFiles.field(chars, key);
			var type = switch (key)
			{
				case 'bf': 'boyfriend';
				case 'dad': 'dad';
				default: 'gf';
			}
			var defaultZ = switch (key)
			{
				case 'bf': 300;
				case 'dad': 200;
				default: 100;
			}
			entries.push({z: c != null ? ModFiles.toFloat(ModFiles.field(c, 'zIndex'), defaultZ) : defaultZ, obj: {type: type}});
			if (c != null)
			{
				Reflect.setField(layout, key, {
					position: ModFiles.pair(ModFiles.field(c, 'position'), 0),
					cameraOffsets: ModFiles.pair(ModFiles.field(c, 'cameraOffsets'), 0),
					scale: ModFiles.toFloat(ModFiles.field(c, 'scale'), 1)
				});
			}
		}

		// stable sort by zIndex
		var indexed = [for (i => e in entries) {i: i, e: e}];
		indexed.sort((a, b) -> a.e.z == b.e.z ? a.i - b.i : (a.e.z < b.e.z ? -1 : 1));

		var directory:String = ModFiles.field(data, 'directory', '');
		return {
			directory: directory,
			defaultZoom: ModFiles.toFloat(ModFiles.field(data, 'cameraZoom'), 1),
			isPixelStage: false,
			stageUI: 'normal',
			boyfriend: [0, 0],
			girlfriend: [0, 0],
			opponent: [0, 0],
			hide_girlfriend: ModFiles.field(chars, 'gf') == null,
			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1,
			objects: [for (x in indexed) x.e.obj],
			vslice: {characters: layout, dancers: dancers}
		};
	}

	function markPixelStages():Void
	{
		for (id in pixelStages)
		{
			var file = ctx.path('stages/$id.json');
			if (!convertedStages.contains(id) || !ModFiles.exists(file)) continue;
			var data:Dynamic = ModFiles.readJson(file);
			if (data == null) continue;
			data.isPixelStage = true;
			data.stageUI = 'pixel';
			ModFiles.writeJson(file, data);
		}
	}

	function resolveStage(stage:String):String
	{
		if (stage == null || stage.length == 0) return 'stage';
		if (convertedStages.contains(stage) || ModFiles.exists(ctx.path('stages/$stage.json'))) return stage;
		var base = stage.endsWith('Erect') ? stage.substr(0, stage.length - 5) : stage;
		if (convertedStages.contains(base) || ModFiles.exists(ctx.path('stages/$base.json'))) return base;
		if (STAGE_RENAMES.exists(base)) return STAGE_RENAMES.get(base);
		ctx.warn('Stage "$stage" is not included in the mod; using the default stage.');
		return 'stage';
	}

	// ----------------------------------------------------------------- songs

	function convertSongs():Void
	{
		var root = ctx.path('data/songs');
		var originalAudioFolders:Array<String> = [];
		for (songFolder in ModFiles.list(root))
		{
			var dir = '$root/$songFolder';
			if (!ModFiles.isDir(dir)) continue;

			// collect variations from metadata files
			var variations:Array<String> = [];
			for (file in ModFiles.list(dir))
			{
				var lower = file.toLowerCase();
				if (!lower.endsWith('.json')) continue;
				var m = ~/^(.+)-metadata(?:-([^.]+))?\.json$/i;
				if (m.match(file)) variations.push(m.matched(2) != null ? m.matched(2) : '');
			}
			variations.sort((a, b) -> a == '' ? -1 : (b == '' ? 1 : Reflect.compare(a, b)));

			currentEntries(songFolder);
			currentVariations = variations;
			for (variation in variations)
			{
				try
				{
					convertSong(songFolder, dir, variation);
				}
				catch (e:Dynamic)
				{
					ctx.warn('Song "$songFolder"${variation != '' ? ' ($variation)' : ''} could not be converted: $e');
				}
			}
			originalAudioFolders.push(songFolder);
		}

		// remove the original V-Slice audio files that were copied to new names
		for (folder in originalAudioFolders)
		{
			var keep = false;
			var entries = songMap.get(folder);
			if (entries != null)
				for (e in entries)
					if (e.id == folder) keep = true;
			if (!keep) ModFiles.deleteRecursive(ctx.path('songs/$folder'));
		}
	}

	function findFile(dir:String, file:String):String
	{
		var real = ModFiles.findCaseInsensitive(dir, file);
		return real != null ? '$dir/$real' : null;
	}

	function convertSong(songFolder:String, dir:String, variation:String):PsychSongEntry
	{
		var suffix = variation != '' ? '-$variation' : '';
		var metaPath = findFile(dir, '$songFolder-metadata$suffix.json');
		var chartPath = findFile(dir, '$songFolder-chart$suffix.json');
		if (metaPath == null || chartPath == null)
		{
			// some mods name files differently from the folder; take any match
			for (f in ModFiles.list(dir))
			{
				if (metaPath == null && f.toLowerCase().endsWith('-metadata$suffix.json'.toLowerCase())) metaPath = '$dir/$f';
				if (chartPath == null && f.toLowerCase().endsWith('-chart$suffix.json'.toLowerCase())) chartPath = '$dir/$f';
			}
		}
		if (metaPath == null || chartPath == null)
		{
			ctx.warn('Song "$songFolder$suffix" has no chart file.');
			return null;
		}

		var meta:Dynamic = ModFiles.readJson(metaPath);
		var chart:Dynamic = ModFiles.readJson(chartPath);
		if (meta == null || chart == null) throw 'invalid JSON';

		var playData:Dynamic = ModFiles.field(meta, 'playData', {});
		var chars:Dynamic = ModFiles.field(playData, 'characters', {});
		var difficulties:Array<String> = ModFiles.field(playData, 'difficulties', []);
		if (difficulties.length == 0) difficulties = [for (f in Reflect.fields(ModFiles.field(chart, 'notes', {}))) f];
		if (difficulties.length == 0) throw 'no difficulties';

		var baseName:String = ModFiles.field(meta, 'songName', songFolder);
		var name = baseName;
		if (variation != '')
		{
			var parentName:String = null;
			for (v => e in currentEntries(songFolder)) if (v == '') parentName = e.name;
			if ((parentName != null && parentName.toLowerCase() == name.toLowerCase()) || name.toLowerCase().indexOf(variation.toLowerCase()) < 0)
				name = '$name (${ConvertContext.difficultyName(variation)})';
		}
		var id = ctx.uniqueSongId(ModFiles.formatSong(name));
		if (id.length == 0) id = ctx.uniqueSongId(ModFiles.formatSong(songFolder + suffix));

		var player:String = ModFiles.field(chars, 'player', 'bf');
		var opponent:String = ModFiles.field(chars, 'opponent', 'dad');
		var girlfriend:String = ModFiles.field(chars, 'girlfriend', 'gf');
		var stage = resolveStage(ModFiles.field(playData, 'stage', 'mainStage'));
		var noteStyle:String = ModFiles.field(playData, 'noteStyle', 'funkin');
		if (noteStyle == 'pixel' && !pixelStages.contains(stage)) pixelStages.push(stage);

		// ---- audio
		var audioDir = ctx.path('songs/$songFolder');
		var outAudio = ctx.path('songs/$id');
		var instrumental:String = ModFiles.field(chars, 'instrumental', variation);
		var instFile = findFile(audioDir, instrumental != '' ? 'Inst-$instrumental.ogg' : 'Inst.ogg');
		if (instFile == null) instFile = findFile(audioDir, 'Inst$suffix.ogg');
		if (instFile == null) instFile = findFile(audioDir, 'Inst.ogg');
		if (instFile == null) ctx.warn('Song "$name" has no instrumental (Inst.ogg).');
		else if (instFile != '$outAudio/Inst.ogg') ModFiles.copy(instFile, '$outAudio/Inst.ogg');

		var playerVocals:Array<String> = ModFiles.field(chars, 'playerVocals', [player]);
		var opponentVocals:Array<String> = ModFiles.field(chars, 'opponentVocals', [opponent]);
		var hasVoices = false;
		function copyVoices(list:Array<String>, fallbackChar:String, target:String):Bool
		{
			var candidates = list.concat([fallbackChar]);
			for (c in candidates)
			{
				for (name in ['Voices-$c$suffix.ogg', 'Voices-$c.ogg'])
				{
					var f = findFile(audioDir, name);
					if (f != null)
					{
						if (f != '$outAudio/$target') ModFiles.copy(f, '$outAudio/$target');
						return true;
					}
				}
			}
			return false;
		}
		var gotPlayer = copyVoices(playerVocals, player, 'Voices-Player.ogg');
		var gotOpponent = copyVoices(opponentVocals, opponent, 'Voices-Opponent.ogg');
		if (gotOpponent && !gotPlayer)
		{
			// vocals named after a different character id: take any other Voices-<x> file
			var re = new EReg('^Voices-(.+)' + EReg.escape(suffix) + '\\.ogg$', 'i');
			for (f in ModFiles.list(audioDir))
			{
				if (!re.match(f)) continue;
				var who = re.matched(1).toLowerCase();
				if (opponentVocals.map(v -> v.toLowerCase()).contains(who) || who == opponent.toLowerCase()) continue;
				if (variation == '' && currentVariations.filter(v -> v != '' && who.endsWith('-' + v.toLowerCase())).length > 0) continue;
				ModFiles.copy('$audioDir/$f', '$outAudio/Voices-Player.ogg');
				gotPlayer = true;
				break;
			}
		}
		if (gotPlayer || gotOpponent) hasVoices = true;
		if (!hasVoices)
		{
			var single = findFile(audioDir, 'Voices$suffix.ogg');
			if (single == null) single = findFile(audioDir, 'Voices.ogg');
			if (single != null)
			{
				if (single != '$outAudio/Voices.ogg') ModFiles.copy(single, '$outAudio/Voices.ogg');
				hasVoices = true;
			}
		}

		// ---- charts
		var offsets:Dynamic = ModFiles.field(meta, 'offsets', {});
		var instOffset = ModFiles.toFloat(ModFiles.field(offsets, 'instrumental'), 0);
		var gameOverChar:String = charactersWithDeath.contains(player) ? player : null;

		var timeChanges:Array<Dynamic> = ModFiles.field(meta, 'timeChanges', [{t: 0, bpm: 100}]);
		var pack = convertChart(chart, difficulties, timeChanges);
		var diffNames:Array<String> = [];
		for (diff in difficulties)
		{
			var sections:Array<Dynamic> = pack.sections.get(diff);
			if (sections == null) continue;
			var song:Dynamic = {
				song: name,
				notes: sections,
				events: [],
				bpm: pack.bpm,
				needsVoices: hasVoices,
				speed: pack.speeds.get(diff),
				offset: instOffset,
				player1: player,
				player2: opponent,
				gfVersion: girlfriend,
				stage: stage,
				format: 'psych_v1'
			};
			if (gameOverChar != null) song.gameOverChar = gameOverChar;
			Reflect.setField(song, 'artist', ModFiles.field(meta, 'artist', ''));
			Reflect.setField(song, 'charter', ModFiles.field(meta, 'charter', ''));
			ModFiles.writeJson(ctx.path('data/$id/' + ConvertContext.chartFile(id, diff)), song);
			diffNames.push(ConvertContext.difficultyName(diff));
		}
		if (pack.events.length > 0)
			ModFiles.writeJson(ctx.path('data/$id/events.json'), {song: {events: pack.events, notes: [], format: 'psych_v1'}});

		var iconInfo = ctx.characterIcon(opponent);
		var entry:PsychSongEntry = {
			name: name,
			id: id,
			icon: iconInfo.icon,
			color: iconInfo.color,
			difficulties: diffNames
		};
		ctx.songs.push(entry);
		currentEntries(songFolder).set(variation, entry);
		ctx.log('Converted song: $name (${diffNames.join(", ")})');
		return entry;
	}

	function currentEntries(songFolder:String):Map<String, PsychSongEntry>
	{
		if (!songMap.exists(songFolder)) songMap.set(songFolder, []);
		return songMap.get(songFolder);
	}

	/** Builds Psych sections + events from a V-Slice chart. */
	function convertChart(chart:Dynamic, difficulties:Array<String>, rawTimeChanges:Array<Dynamic>):{bpm:Float, sections:Map<String, Array<Dynamic>>, speeds:Map<String, Float>, events:Array<Dynamic>}
	{
		var timeChanges = [for (t in rawTimeChanges) {t: ModFiles.toFloat(ModFiles.field(t, 't'), 0), bpm: ModFiles.toFloat(ModFiles.field(t, 'bpm'), 100)}];
		timeChanges.sort((a, b) -> a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));
		if (timeChanges.length == 0) timeChanges.push({t: 0, bpm: 100});
		var songBpm = timeChanges[0].bpm;

		function bpmAt(time:Float):Float
		{
			var bpm = songBpm;
			for (c in timeChanges)
			{
				if (c.t > time + 0.5) break;
				bpm = c.bpm;
			}
			return bpm;
		}

		var notesObj:Dynamic = ModFiles.field(chart, 'notes', {});
		var speedObj:Dynamic = ModFiles.field(chart, 'scrollSpeed', {});
		var events:Array<Dynamic> = ModFiles.field(chart, 'events', []);
		events = events.copy();
		events.sort((a, b) -> ModFiles.toFloat(a.t, 0) < ModFiles.toFloat(b.t, 0) ? -1 : 1);

		var lastTime:Float = 0;
		var notesPerDiff:Map<String, Array<Dynamic>> = [];
		for (diff in difficulties)
		{
			var notes:Array<Dynamic> = ModFiles.field(notesObj, diff, []);
			notes = notes.copy();
			notes.sort((a, b) -> ModFiles.toFloat(a.t, 0) < ModFiles.toFloat(b.t, 0) ? -1 : 1);
			notesPerDiff.set(diff, notes);
			if (notes.length > 0)
			{
				var n = notes[notes.length - 1];
				lastTime = Math.max(lastTime, ModFiles.toFloat(n.t, 0) + ModFiles.toFloat(ModFiles.field(n, 'l'), 0));
			}
		}
		for (e in events) lastTime = Math.max(lastTime, ModFiles.toFloat(e.t, 0));

		// camera focus per section (FocusCamera with char 0 = player, 1 = opponent)
		var focusEvents = events.filter(e -> e.e == 'FocusCamera');
		function mustHitAt(time:Float):Bool
		{
			var must = false;
			for (e in focusEvents)
			{
				if (ModFiles.toFloat(e.t, 0) > time + 1) break;
				var v:Dynamic = e.v;
				var c:Dynamic = (Std.isOfType(v, Int) || Std.isOfType(v, Float) || Std.isOfType(v, String)) ? v : ModFiles.field(v, 'char', 0);
				var ci = Std.int(ModFiles.toFloat(c, 0));
				if (ci == 0) must = true;
				else if (ci == 1) must = false;
			}
			return must;
		}

		// section grid (4 beats per section, following BPM changes)
		var sectionTimes:Array<Float> = [];
		var sectionBpms:Array<Float> = [];
		var t:Float = 0;
		while (t <= lastTime + 1 || sectionTimes.length == 0)
		{
			var bpm = bpmAt(t);
			sectionTimes.push(t);
			sectionBpms.push(bpm);
			t += (60000 / bpm) * 4;
			if (sectionTimes.length > 20000) break;
		}

		var sections:Map<String, Array<Dynamic>> = [];
		var speeds:Map<String, Float> = [];
		for (diff in difficulties)
		{
			var secs:Array<Dynamic> = [];
			var lastBpm = songBpm;
			for (i => st in sectionTimes)
			{
				var sec:Dynamic = {sectionNotes: [], sectionBeats: 4, mustHitSection: mustHitAt(st + 1)};
				if (sectionBpms[i] != lastBpm)
				{
					sec.changeBPM = true;
					sec.bpm = sectionBpms[i];
					lastBpm = sectionBpms[i];
				}
				secs.push(sec);
			}

			var secIndex = 0;
			for (note in notesPerDiff.get(diff))
			{
				var time = ModFiles.toFloat(note.t, 0);
				var data = Std.int(ModFiles.toFloat(note.d, 0));
				if (data < 0 || data > 7) continue;
				while (secIndex + 1 < sectionTimes.length && sectionTimes[secIndex + 1] <= time) secIndex++;
				var arr:Array<Dynamic> = [time, data, Math.max(0, ModFiles.toFloat(ModFiles.field(note, 'l'), 0))];
				var kind:String = ModFiles.field(note, 'k');
				if (kind != null && kind.length > 0 && kind != 'normal')
					arr.push(NOTE_KINDS.exists(kind.toLowerCase()) ? NOTE_KINDS.get(kind.toLowerCase()) : kind);
				secs[secIndex].sectionNotes.push(arr);
			}
			sections.set(diff, secs);

			var speed:Float = ModFiles.toFloat(ModFiles.field(speedObj, diff), Math.NaN);
			if (Math.isNaN(speed)) speed = ModFiles.toFloat(ModFiles.field(speedObj, 'default'), 1);
			if (Std.isOfType(speedObj, Float) || Std.isOfType(speedObj, Int)) speed = speedObj;
			speeds.set(diff, speed);
		}

		// events
		var baseSpeed = speeds.get(difficulties[0]);
		if (baseSpeed == null || baseSpeed <= 0) baseSpeed = 1;
		var psychEvents:Array<Dynamic> = [];
		for (e in events)
		{
			var time = ModFiles.toFloat(e.t, 0);
			var name:String = e.e;
			var v:Dynamic = e.v;
			var converted:Array<Dynamic> = switch (name)
			{
				case 'PlayAnimation':
					var target:String = Std.string(ModFiles.field(v, 'target', 'bf'));
					['Play Animation', Std.string(ModFiles.field(v, 'anim', 'idle')), target];
				case 'ScrollSpeed':
					var scroll = ModFiles.toFloat(ModFiles.field(v, 'scroll'), 1);
					var absolute = ModFiles.toBool(ModFiles.field(v, 'absolute'), false);
					var steps = ModFiles.toFloat(ModFiles.field(v, 'duration'), 4);
					var instant = ModFiles.field(v, 'ease', 'linear') == 'INSTANT';
					var secs = instant ? 0 : steps * (60000 / bpmAt(time)) / 4 / 1000;
					['Change Scroll Speed', Std.string(absolute ? scroll / baseSpeed : scroll), Std.string(secs)];
				case 'SetHealthIcon':
					// no direct equivalent; keep for scripts
					[name, Json.stringify(v), ''];
				default:
					[name, (Std.isOfType(v, String) ? v : Json.stringify(v)), ''];
			}
			psychEvents.push([time, [converted]]);
		}

		return {bpm: songBpm, sections: sections, speeds: speeds, events: psychEvents};
	}

	// ---------------------------------------------------------------- levels

	function convertLevels():Void
	{
		var used:Array<PsychSongEntry> = [];
		var weekNames:Array<String> = [];
		var dir = ctx.path('data/levels');
		for (file in ModFiles.list(dir))
		{
			if (!file.toLowerCase().endsWith('.json')) continue;
			var id = file.substr(0, file.length - 5);
			var level:Dynamic = ModFiles.readJson('$dir/$file');
			if (level == null) continue;

			var weekId = ModFiles.formatSong(id);
			if (ModFiles.exists(ctx.path('weeks/$weekId.json'))) weekId += '-vslice';
			var levelName:String = ModFiles.field(level, 'name', id);
			var songIds:Array<String> = ModFiles.field(level, 'songs', []);

			var baseSongs:Array<PsychSongEntry> = [];
			var variationSongs:Map<String, Array<PsychSongEntry>> = [];
			for (sid in songIds)
			{
				var entries = songMap.get(sid);
				if (entries == null)
				{
					var real = ModFiles.findCaseInsensitive(ctx.path('data/songs'), sid);
					if (real != null) entries = songMap.get(real);
				}
				if (entries == null)
				{
					ctx.warn('Week "$levelName" lists song "$sid", which is not in the mod.');
					continue;
				}
				for (variation => entry in entries)
				{
					used.push(entry);
					if (variation == '') baseSongs.push(entry);
					else
					{
						if (!variationSongs.exists(variation)) variationSongs.set(variation, []);
						variationSongs.get(variation).push(entry);
					}
				}
			}

			// title image -> images/storymenu/<week>.png
			var title:String = ModFiles.stripLibrary(ModFiles.field(level, 'titleAsset', ''));
			if (title.length > 0)
				ModFiles.copy(ctx.path('images/$title.png'), ctx.path('images/storymenu/$weekId.png'));

			var weekChars = storyCharacters(level);
			var background:String = ModFiles.field(level, 'background', '');
			var weekBg = '';
			if (background.length > 0 && !background.startsWith('#'))
			{
				var bgPath = ModFiles.stripLibrary(background);
				if (ModFiles.exists(ctx.path('images/$bgPath.png')))
				{
					ModFiles.copy(ctx.path('images/$bgPath.png'), ctx.path('images/menubackgrounds/menu_$weekId.png'));
					weekBg = weekId;
				}
			}

			var visible = ModFiles.toBool(ModFiles.field(level, 'visible'), true);
			if (baseSongs.length > 0)
			{
				ctx.writeWeek(weekId, levelName, baseSongs, {
					hideStoryMode: !visible,
					weekCharacters: weekChars,
					weekBackground: weekBg
				});
				weekNames.push(weekId);
			}
			for (variation => list in variationSongs)
			{
				var vid = '$weekId-${ModFiles.formatSong(variation)}';
				ctx.writeWeek(vid, '$levelName (${ConvertContext.difficultyName(variation)})', list, {weekCharacters: weekChars});
				weekNames.push(vid);
			}
		}

		// songs that are not part of any level still go to Freeplay
		var leftovers = ctx.songs.filter(s -> !used.contains(s));
		weekNames = weekNames.concat(ctx.writeFreeplayWeeks(leftovers));
		ctx.writeWeekList(weekNames);
	}

	/** Maps story menu props to Psych menu characters when possible. */
	function storyCharacters(level:Dynamic):Array<String>
	{
		var result:Array<String> = ['', '', ''];
		var props:Array<Dynamic> = ModFiles.field(level, 'props', []);
		for (i in 0...Std.int(Math.min(3, props.length)))
		{
			var p:Dynamic = props[i];
			var asset:String = ModFiles.stripLibrary(ModFiles.field(p, 'assetPath', ''));
			if (asset.length == 0) continue;
			var charName = asset.substr(asset.lastIndexOf('/') + 1);

			// prop shipped by the mod: build a Psych menu character from it
			if (ModFiles.exists(ctx.path('images/$asset.png')))
			{
				var menuName = 'vslice-' + ModFiles.formatSong(charName);
				ModFiles.copy(ctx.path('images/$asset.png'), ctx.path('images/menucharacters/$menuName.png'));
				ModFiles.copy(ctx.path('images/$asset.xml'), ctx.path('images/menucharacters/$menuName.xml'));
				var anims:Array<Dynamic> = ModFiles.field(p, 'animations', []);
				var idle = '';
				var confirm = '';
				for (a in anims)
				{
					var an:String = ModFiles.field(a, 'name', '');
					if (idle == '' && (an == 'idle' || an == 'danceLeft')) idle = ModFiles.field(a, 'prefix', '');
					if (an == 'confirm') confirm = ModFiles.field(a, 'prefix', '');
				}
				if (idle == '' && anims.length > 0) idle = ModFiles.field(anims[0], 'prefix', '');
				ModFiles.writeJson(ctx.path('images/menucharacters/$menuName.json'), {
					image: 'menucharacters/$menuName',
					scale: ModFiles.toFloat(ModFiles.field(p, 'scale'), 1),
					position: [0, 0],
					idle_anim: idle,
					confirm_anim: confirm.length > 0 ? confirm : idle,
					flipX: false,
					antialiasing: !ModFiles.toBool(ModFiles.field(p, 'isPixel'), false)
				});
				result[i] = menuName;
			}
			else if (ModFiles.exists('assets/shared/images/menucharacters/$charName.json'))
				result[i] = charName;
		}
		return result;
	}

	// ----------------------------------------------------------------- misc

	function convertPackMeta():Void
	{
		var meta:Dynamic = ModFiles.readJson(ctx.path('_polymod_meta.json'));
		if (!ModFiles.exists(ctx.path('pack.json')))
		{
			ModFiles.writeJson(ctx.path('pack.json'), {
				name: meta != null ? ModFiles.field(meta, 'title', ctx.modName) : ctx.modName,
				description: meta != null ? ModFiles.field(meta, 'description', 'Converted from a V-Slice mod.') : 'Converted from a V-Slice mod.',
				color: [146, 113, 253],
				restart: false,
				runsGlobally: false
			});
		}
		if (ModFiles.exists(ctx.path('_polymod_icon.png')) && !ModFiles.exists(ctx.path('pack.png')))
			ModFiles.copy(ctx.path('_polymod_icon.png'), ctx.path('pack.png'));
	}

	function reportScripts():Void
	{
		var scripts = ModFiles.walk(ctx.path('scripts')).filter(f -> f.endsWith('.hxc') || f.endsWith('.hx'));
		if (scripts.length > 0)
			ctx.warn('${scripts.length} V-Slice script(s) (.hxc) were skipped: custom cutscenes and mechanics from them will not play.');
		// Psych would try to run V-Slice scripts from scripts/ and fail; move them aside
		if (ModFiles.isDir(ctx.path('scripts')))
		{
			for (f in ModFiles.walk(ctx.path('scripts')))
				if (f.endsWith('.hxc') || f.endsWith('.hx'))
					ModFiles.move(ctx.path('scripts/$f'), ctx.path('_vslice_scripts/$f'));
			ModFiles.pruneEmpty(ctx.path('scripts'));
		}
	}
}

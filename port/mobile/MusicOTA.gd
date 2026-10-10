extends Node

const MANIFEST_URL = "https://raw.githubusercontent.com/x8lua/buckshot-mobile-port/main/music/manifest.json"
const MAX_MANIFEST_BYTES = 65536
const MAX_AUDIO_BYTES = 64 * 1024 * 1024
const TRACK_IDS = ["menu", "batch_0", "batch_0_secondloop", "batch_1", "batch_1_secondloop", "batch_2", "batch_2_secondloop"]

var manifest_url = MANIFEST_URL
var cache_dir = "user://music_ota"
var allow_local_test_http = false
var _index: Dictionary = {}
var _streams: Dictionary = {}
var _busy = false
var last_status = "idle"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_index()
	if not OS.get_cmdline_user_args().has("--ota-test"):
		sync.call_deferred()

func _allowed_url(url: String) -> bool:
	if allow_local_test_http and url.begins_with("http://127.0.0.1:"): return true
	return url.begins_with("https://github.com/x8lua/buckshot-mobile-port/releases/download/") or url.begins_with("https://raw.githubusercontent.com/x8lua/buckshot-mobile-port/main/music/")

func _valid_entry(entry) -> bool:
	if not entry is Dictionary: return false
	if not entry.get("url") is String or not _allowed_url(entry.url): return false
	if entry.get("format") not in ["ogg", "wav"]: return false
	if not entry.get("sha256") is String or entry.sha256.length() != 64: return false
	for character in entry.sha256:
		if character not in "0123456789abcdef": return false
	return entry.get("loop", true) is bool

func _digest(bytes: PackedByteArray) -> String:
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hash.update(bytes)
	return hash.finish().hex_encode()

func _audio_path(entry: Dictionary) -> String:
	return cache_dir.path_join(entry.sha256 + "." + entry.format)

func _read_audio(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path): return PackedByteArray()
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_AUDIO_BYTES: return PackedByteArray()
	var bytes = file.get_buffer(file.get_length())
	file.close()
	return bytes

func _prune_audio():
	var retained = []
	for entry in _index.values(): retained.append(_audio_path(entry).get_file())
	var directory = DirAccess.open(cache_dir)
	if directory == null: return
	for filename in directory.get_files():
		if filename.get_extension() not in ["ogg", "wav"] or filename.get_basename().length() != 64: continue
		if filename not in retained: directory.remove(filename)

func _load_index():
	_index = {}
	var path = cache_dir.path_join("index.json")
	if not FileAccess.file_exists(path): return
	if FileAccess.get_file_as_bytes(path).size() > MAX_MANIFEST_BYTES: return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema") != 1 or not parsed.get("tracks") is Dictionary: return
	for key in parsed.tracks:
		if key in TRACK_IDS and _valid_entry(parsed.tracks[key]):
			_index[key] = parsed.tracks[key]

func _write_atomic(path: String, bytes: PackedByteArray) -> bool:
	var temporary = path + ".download"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

func _fetch(url: String, limit: int) -> Dictionary:
	if not _allowed_url(url): return {}
	var request = HTTPRequest.new()
	request.timeout = 20.0
	request.body_size_limit = limit
	request.max_redirects = 5
	request.use_threads = true
	add_child(request)
	var error = request.request(url, ["Cache-Control: no-cache"])
	if error != OK:
		request.queue_free()
		return {}
	var response = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200: return {}
	return {"bytes": response[3]}

func _decode(bytes: PackedByteArray, entry: Dictionary) -> AudioStream:
	var stream: AudioStream
	if entry.format == "ogg":
		stream = AudioStreamOggVorbis.load_from_buffer(bytes)
		if stream:
			stream.loop = entry.get("loop", true)
	else:
		stream = AudioStreamWAV.load_from_buffer(bytes)
		if stream:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if entry.get("loop", true) else AudioStreamWAV.LOOP_DISABLED
			stream.loop_begin = 0
			stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	if stream == null or stream.get_length() <= 0.0: return null
	return stream

func get_override(track_id: String, fallback: AudioStream) -> AudioStream:
	if not _index.has(track_id): return fallback
	var entry = _index[track_id]
	var identity = entry.sha256 + str(entry.get("loop", true))
	if _streams.has(identity): return _streams[identity]
	var path = _audio_path(entry)
	if not FileAccess.file_exists(path): return fallback
	var bytes = _read_audio(path)
	if _digest(bytes) != entry.sha256: return fallback
	var stream = _decode(bytes, entry)
	if stream == null: return fallback
	_streams[identity] = stream
	return stream

func sync() -> bool:
	if _busy: return false
	_busy = true
	last_status = "checking"
	var response = await _fetch(manifest_url, MAX_MANIFEST_BYTES)
	if response.is_empty():
		last_status = "offline"
		_busy = false
		return false
	var manifest = JSON.parse_string(response.bytes.get_string_from_utf8())
	if not manifest is Dictionary or manifest.get("schema") != 1 or not manifest.get("tracks") is Dictionary or manifest.tracks.size() > TRACK_IDS.size():
		last_status = "invalid_manifest"
		_busy = false
		return false
	for key in manifest.tracks:
		if key not in TRACK_IDS or not _valid_entry(manifest.tracks[key]):
			last_status = "invalid_manifest"
			_busy = false
			return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir)) != OK:
		last_status = "cache_error"
		_busy = false
		return false
	# Keep the last verified version of failed downloads; absent IDs revert to built-in.
	var next_index = _index.duplicate(true)
	for key in _index:
		if not manifest.tracks.has(key): next_index.erase(key)
	var all_ok = true
	for key in manifest.tracks:
		var entry = manifest.tracks[key]
		var path = _audio_path(entry)
		var bytes = _read_audio(path)
		var cached = not bytes.is_empty() and _digest(bytes) == entry.sha256
		if not cached:
			var audio_response = await _fetch(entry.url, MAX_AUDIO_BYTES)
			if audio_response.is_empty():
				all_ok = false
				continue
			bytes = audio_response.bytes
		if _digest(bytes) != entry.sha256:
			all_ok = false
			continue
		var stream = _decode(bytes, entry)
		if stream == null or (not cached and not _write_atomic(path, bytes)):
			all_ok = false
			continue
		next_index[key] = entry
	var index_bytes = JSON.stringify({"schema": 1, "tracks": next_index}).to_utf8_buffer()
	if _write_atomic(cache_dir.path_join("index.json"), index_bytes):
		_index = next_index
		# Existing players hold their stream. Only subsequent track loads see updates.
		_streams.clear()
		_prune_audio()
	else:
		all_ok = false
	last_status = "updated" if all_ok else "partial_failure"
	_busy = false
	return all_ok

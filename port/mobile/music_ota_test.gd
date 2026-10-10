extends SceneTree

var failures = []
func _initialize(): run.call_deferred()
func check(value, label):
	print("CHECK ", label, " ", "PASS" if value else "FAIL")
	if not value: failures.append(label)

func new_ota(url: String, directory: String):
	var ota = load("res://mobile/MusicOTA.gd").new()
	ota.allow_local_test_http = true
	ota.manifest_url = url
	ota.cache_dir = directory
	root.add_child(ota)
	return ota

func run():
	await process_frame
	var origin = OS.get_environment("BUCKSHOT_OTA_TEST_URL")
	var directory = OS.get_environment("BUCKSHOT_OTA_TEST_CACHE")
	if origin.is_empty() or directory.is_empty():
		push_error("Run through ci/test_music_ota.py")
		quit(1)
		return
	var ota = new_ota(origin + "/manifest/1", directory)
	var fallback = AudioStreamWAV.new()
	check(ota.get_override("batch_0", fallback) == fallback, "no cache uses built-in music")
	check(await ota.sync(), "HTTP manifest and audio download succeed")
	var first = ota.get_override("batch_0", fallback)
	check(first != fallback and is_equal_approx(first.get_length(), 0.12), "verified WAV decoded for playback")
	check(first.loop_mode == AudioStreamWAV.LOOP_FORWARD and first.loop_end > 0, "downloaded track loops")
	var player = AudioStreamPlayer.new()
	root.add_child(player)
	player.stream = first
	player.play()
	ota.manifest_url = origin + "/manifest/2"
	check(await ota.sync(), "new version replaces cached index")
	var second = ota.get_override("batch_0", fallback)
	check(second != first and is_equal_approx(second.get_length(), 0.24), "next track selection sees new version")
	check(player.stream == first and player.playing, "update does not interrupt current playback")
	check(await ota.sync(), "unchanged version reuses downloaded file")
	ota.manifest_url = origin + "/manifest/bad_hash"
	check(not await ota.sync(), "wrong SHA256 rejected")
	check(is_equal_approx(ota.get_override("batch_0", fallback).get_length(), 0.24), "failed update retains last verified version")
	ota.manifest_url = origin + "/manifest/bad_url"
	check(not await ota.sync() and ota.last_status == "invalid_manifest", "unapproved host rejected")
	ota.manifest_url = origin + "/manifest/missing"
	check(not await ota.sync(), "failed audio request leaves cache usable")
	var offline = new_ota(origin + "/offline", directory)
	check(not await offline.sync(), "offline request does not block playback")
	check(is_equal_approx(offline.get_override("batch_0", fallback).get_length(), 0.24), "restart loads cached music offline")
	var path = ota._audio_path(ota._index["batch_0"])
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1, 2, 3]))
	file.close()
	var corrupt = new_ota(origin + "/manifest/2", directory)
	check(corrupt.get_override("batch_0", fallback) == fallback, "corrupt cache falls back to built-in")
	check(await corrupt.sync() and corrupt.get_override("batch_0", fallback) != fallback, "corrupt cache repaired from download")
	corrupt.manifest_url = origin + "/manifest/3"
	check(await corrupt.sync(), "OGG audio downloads and decodes")
	var ogg = corrupt.get_override("batch_0", fallback)
	check(ogg is AudioStreamOggVorbis and ogg.loop, "downloaded OGG loops for playback")
	check(not FileAccess.file_exists(path), "superseded audio removed after successful update")
	corrupt.manifest_url = origin + "/manifest/empty"
	check(await corrupt.sync() and corrupt.get_override("batch_0", fallback) == fallback, "removing entry restores built-in track")
	check(not ota._allowed_url("http://github.com/x8lua/buckshot-mobile-port/releases/download/a/b.wav"), "production downloads require HTTPS")
	player.stop()
	print("MUSIC_OTA_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

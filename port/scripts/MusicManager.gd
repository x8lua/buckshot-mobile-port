class_name MusicManager extends Node

@export var trackArray : Array[TrackInstance]
@export var speaker_music : AudioStreamPlayer2D
@export var speakerController_music : SpeakerController
@export var filter : FilterController
@export var roundManager : RoundManager

func _ready():
	#LoadTrack()
	pass

func EndTrack():
	speaker_music.stop()

func LoadTrack_FadeIn():
	speakerController_music.SnapVolume(false)
	LoadTrack()
	speakerController_music.FadeIn()

var trackset = false
func LoadTrack():
	var currentBatch = roundManager.playerData.currentBatchIndex
	var currentTrack
	var ota_track_id = "batch_%d" % currentBatch
	if (roundManager.playerData.playerEnteringFromDeath && !trackset):
		currentTrack = trackArray[currentBatch].audiofile_secondloop
		ota_track_id += "_secondloop"
		trackset = true
	else:
		currentTrack = trackArray[currentBatch].audiofile
	filter.lowPassDefaultValue = trackArray[currentBatch].defaultLowPassHz
	filter.effect_lowPass.cutoff_hz = filter.lowPassDefaultValue
	filter.moving = false
	if MobileRuntime.enabled and is_instance_valid(MobileRuntime.music_ota):
		currentTrack = MobileRuntime.music_ota.get_override(ota_track_id, currentTrack)
	speaker_music.stream = currentTrack
	speaker_music.play()

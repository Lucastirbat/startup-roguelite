extends Node

# Autoload: background music + one-shot SFX.

const MUSIC := "res://assets/sound/background.mp3"
const SFX := {
	"win": "res://assets/sound/win_sound.mp3",
	"lose": "res://assets/sound/lose_sound.mp3",
	"click_left": "res://assets/sound/click.wav",
	"click_right": "res://assets/sound/click2.wav",
	"tick": "res://assets/sound/clicklow.wav",
}

var music := AudioStreamPlayer.new()
var sfx := AudioStreamPlayer.new()

func _ready() -> void:
	var stream: AudioStreamMP3 = load(MUSIC)
	stream.loop = true
	music.stream = stream
	music.volume_db = -12.0
	add_child(music)
	add_child(sfx)

# Mobile browsers keep the audio context suspended until a user gesture,
# so the music starts on the first tap/click/key instead of at boot.
func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed)
	if pressed:
		music.play()
		set_process_input(false)

func play(name: String) -> void:
	if not SFX.has(name):
		return
	sfx.stream = load(SFX[name])
	sfx.play()

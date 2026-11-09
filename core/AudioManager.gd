extends Node
## 全局音频管理器（Autoload）
## 职责：统一管理配音(VO)与音效(SFX)的加载、缓存与播放，避免各场景重复持有播放器。
## 设计：VO 单通道（新发音打断旧发音，符合语言教学直觉），SFX 多通道轮询（允许叠音）。

const VO_DIR := "res://assets/audio/vo/"
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_VOICES := 4
const VO_DB := 0.0
const SFX_DB := -4.0

var muted := false

var _vo_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vo_player = _create_player("VOPlayer", VO_DB)
	for i in SFX_VOICES:
		_sfx_players.append(_create_player("SFXPlayer%d" % i, SFX_DB))


func _create_player(node_name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = db
	add_child(p)
	return p


## 播放单词配音。file_stem 为 assets/audio/vo/ 下的文件名（不含扩展名）。
func play_vo(file_stem: String) -> void:
	if muted or file_stem.is_empty():
		return
	var stream := _load_stream(VO_DIR + file_stem + ".mp3")
	if stream == null:
		# 配音文件缺失时静默跳过：MVP 阶段允许无声跑通全流程
		return
	_vo_player.stream = stream
	_vo_player.play()


## 播放音效：success / error / tap / level
func play_sfx(sfx_name: String) -> void:
	if muted or sfx_name.is_empty():
		return
	var stream := _load_stream(SFX_DIR + sfx_name + ".wav")
	if stream == null:
		return
	var p := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	p.stream = stream
	p.play()


func stop_vo() -> void:
	if _vo_player and _vo_player.playing:
		_vo_player.stop()


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	if muted:
		stop_vo()
	return muted


func _load_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	_cache[path] = stream
	return stream

extends Node
## 全局音频管理器（Autoload）
## 职责：统一管理配音(VO)、音效(SFX)、循环音效与背景音乐(BGM)的加载与播放。
## 设计：
##   * VO 单通道 —— 新发音打断旧发音，符合语言教学直觉；
##   * SFX 多通道轮询 —— 允许叠音；
##   * LOOP 单通道 —— 刷牙「刷刷」等需要无缝循环的环境动作音；
##   * BGM 单通道 —— 极轻的晨间循环铺底（-20dB），不盖过人声。

const VO_DIR := "res://assets/audio/vo/"
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_VOICES := 4
const VO_DB := 0.0
const SFX_DB := -4.0
const LOOP_DB := -9.0
const BGM_DB := -20.0

var muted := false

var _vo_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _loop_player: AudioStreamPlayer
var _bgm_player: AudioStreamPlayer
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vo_player = _create_player("VOPlayer", VO_DB)
	for i in SFX_VOICES:
		_sfx_players.append(_create_player("SFXPlayer%d" % i, SFX_DB))
	_loop_player = _create_player("LoopSFXPlayer", LOOP_DB)
	_bgm_player = _create_player("BGMPlayer", BGM_DB)


func _create_player(node_name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.volume_db = db
	add_child(p)
	return p


## 播放配音。file_stem 为 assets/audio/vo/ 下的文件名（不含扩展名）。
func play_vo(file_stem: String) -> void:
	if muted or file_stem.is_empty():
		return
	var stream := _load_stream(VO_DIR + file_stem + ".mp3")
	if stream == null:
		# 配音文件缺失时静默跳过：允许无声跑通全流程
		return
	_vo_player.stream = stream
	_vo_player.play()


## 播放一次性音效
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


## 启动无缝循环音效（刷牙刷刷 / 洗脸水声等）
func start_loop_sfx(sfx_name: String) -> void:
	if muted or sfx_name.is_empty():
		return
	var stream := _load_stream(SFX_DIR + sfx_name + ".wav") as AudioStreamWAV
	if stream == null:
		return
	_setup_wav_loop(stream)
	if _loop_player.stream == stream and _loop_player.playing:
		return
	_loop_player.stream = stream
	_loop_player.play()


func stop_loop_sfx() -> void:
	if _loop_player and _loop_player.playing:
		_loop_player.stop()


## 背景音乐（整局循环一次即可，音量很低）
func play_bgm(bgm_name: String = "bgm_morning") -> void:
	if muted:
		return
	var stream := _load_stream(SFX_DIR + bgm_name + ".wav") as AudioStreamWAV
	if stream == null:
		return
	_setup_wav_loop(stream)
	if _bgm_player.playing and _bgm_player.stream == stream:
		return
	_bgm_player.stream = stream
	_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player and _bgm_player.playing:
		_bgm_player.stop()


## Godot 导入的 WAV 默认不循环，运行时把 loop 打开
func _setup_wav_loop(stream: AudioStreamWAV) -> void:
	if stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	var frames := int(stream.get_length() * float(stream.mix_rate))
	stream.loop_end = max(1, frames)


func stop_vo() -> void:
	if _vo_player and _vo_player.playing:
		_vo_player.stop()


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	if muted:
		stop_vo()
		stop_loop_sfx()
	return muted


func _load_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	_cache[path] = stream
	return stream

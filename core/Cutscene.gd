extends CanvasLayer
## 过场动画层（关卡间插入视频用）
##
## 用法：story.json 每关可配
##   "video_before": "res://assets/videos/xxx.ogv"   关卡开始前播放
##   "video_after" : "res://assets/videos/xxx.ogv"   通关后播放
## 格式必须是 Godot 4 支持的 Ogg Theora (.ogv)，转换命令：
##   ffmpeg -i brush.mp4 -q:v 6 brush.ogv
## 文件缺失 / 未配置时优雅跳过，不影响关卡流程。孩子点击屏幕可跳过视频。

signal finished

@onready var _root: Control = $Root
@onready var _video: VideoStreamPlayer = $Root/Video

var _playing := false


func _ready() -> void:
	visible = false
	_root.gui_input.connect(_on_root_gui_input)
	_video.finished.connect(_on_video_finished)


## 播放过场视频；path 为空或文件不存在时立即发出 finished
func play_video(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		finished.emit.call_deferred()
		return
	var stream := load(path) as VideoStream
	if stream == null:
		push_warning("过场视频加载失败，已跳过：%s" % path)
		finished.emit.call_deferred()
		return
	_video.stream = stream
	visible = true
	_playing = true
	_video.play()


func _on_root_gui_input(event: InputEvent) -> void:
	# 小朋友点击屏幕任意处即可跳过
	if _playing and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_finish()


func _on_video_finished() -> void:
	_finish()


func _finish() -> void:
	if not _playing:
		return
	_playing = false
	_video.stop()
	visible = false
	finished.emit()

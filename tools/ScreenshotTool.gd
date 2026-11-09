extends Node
## 截图自检（非游戏逻辑）：跑真实渲染管线，抓两帧存盘供人工检查。
## 用法：Godot_console.exe --path <project> res://tools/ScreenshotTool.tscn

func _ready() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.4).timeout
	_capture("res://.preview/shot_level1.png")

	# 模拟空闲 10s 触发的幽灵小手提示
	main._on_idle_timeout()
	await get_tree().create_timer(1.0).timeout
	_capture("res://.preview/shot_ghost_hand.png")

	get_tree().quit()


func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("captured: ", path)

extends Node
## 截图自检（非游戏逻辑）：跑真实渲染管线，抓多帧存盘供人工检查。
## 用法：Godot_console.exe --path <project> res://tools/ScreenshotTool.tscn

func _ready() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.4).timeout
	_capture("res://.preview/shot_l1_bedroom_wake.png")

	# 幽灵小手提示（第 1 关，无走路过场）
	main._on_idle_timeout()
	await get_tree().create_timer(1.0).timeout
	_capture("res://.preview/shot_ghost_hand.png")

	# 各场景关：等待「走出旧房间 + 换背景 + 走进新房间」的过场结束后再截图
	var shots := [
		[1, "shot_l2_living_drink.png"],
		[2, "shot_l3_bathroom_brush.png"],
		[6, "shot_l7_entry_shoes.png"],
		[7, "shot_l8_checklist.png"],
	]
	for shot in shots:
		main._start_level(shot[0])
		await get_tree().create_timer(3.8).timeout
		_capture("res://.preview/" + str(shot[1]))

	# 穿裤子成功瞬间：最后一拍，截完立即退出（不触发切关过场）
	main._start_level(5)
	await get_tree().create_timer(3.8).timeout
	var z: BaseProp = main.get_node("PropLayer").get_child(0).get_node("DropZone")
	z._drop_data(Vector2.ZERO, {"card_id": "card_pants"})
	await get_tree().create_timer(1.6).timeout
	_capture("res://.preview/shot_pants_success.png")

	get_tree().quit()


func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("captured: ", path)

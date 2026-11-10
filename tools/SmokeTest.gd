extends Node
## 冒烟测试（headless 可跑）
## 用法：Godot_console.exe --path <project> res://tools/SmokeTest.tscn
## 覆盖：story 加载 / 卡片装配 / 小人初始姿态 / 拖错反馈 / 拖对过关 /
##       情境配音配置 / 幽灵小手提示 / 自检清单 / 通关结算 / 重开

var _fails := 0


func _ready() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _run(main)


func _run(main: Node) -> void:
	var binder: Node = main.get_node("BinderUI")
	var end_screen: Node = main.get_node("EndScreen")
	var character: Node = main.get_node("Character")
	var checklist: Node = main.get_node("ChecklistUI")

	await _wait(40)
	_check(main._levels.size() == 8, "story.json 加载 8 关（7 道具关 + 自检清单）")
	_check(str(main._levels[5].get("id", "")) == "pants", "第 6 关是新增的穿裤子关")
	_check(str(main._levels[5].get("req_card", "")) == "card_pants", "穿裤子关要求 card_pants")
	_check(main._levels[0].has("video_before") and main._levels[0].has("video_after"),
			"关卡支持 video_before / video_after 过场字段")
	_check(main._state == main.State.PLAYING, "初始状态 PLAYING")
	_check(binder.get_card(main._current_level().get("req_card")) != null, "正确卡片已装配")
	_check(binder.get_card("card_wake") != null, "第 1 关卡片包含 Wake up")
	_check(character != null and character._head != null, "小人角色已构建")
	_check(absf(character.rotation + PI * 0.5) < 0.01, "第 1 关小人躺在床上")
	_check(character._faces["asleep"].visible == true, "躺下时是闭眼表情")
	_check(character._item.visible == false, "小人不预先手持道具")
	_check(checklist != null and checklist._buttons.size() == 6, "自检清单有 6 个徽章（含裤子）")
	_check(str(main._current_level().get("vo", {}).get("intro", "")) == "vo_act1_intro",
			"情境配音配置已接入 story.json")
	_check(main.get_node_or_null("Cutscene") != null, "过场动画层已接入主场景")

	# 0) 过场层：空路径应立即（延迟帧）发出 finished，不卡死流程
	var cut_done := {"ok": false}
	main._cutscene.finished.connect(func(): cut_done.ok = true)
	main._cutscene.play_video("")
	await _wait(3)
	_check(cut_done.ok, "空视频路径直接跳过过场并发出 finished")

	var prop: Node = main.get_node("PropLayer").get_child(0)
	var zone: BaseProp = prop.get_node("DropZone")
	_check(zone.required_card == "card_wake", "接收端 required_card 注入成功")

	# 1) 拖入无效数据 → 不应触发任何信号
	var counter := {"n": 0}
	var _on_any := func(_p, _c): counter.n += 1
	zone.matched.connect(_on_any)
	zone.mismatched.connect(_on_any)
	_check(zone._can_drop_data(Vector2.ZERO, "bad data") == false, "非法拖拽数据被拒绝")
	_check(zone._can_drop_data(Vector2.ZERO, {"card_id": "card_wake"}) == true, "合法拖拽数据被接受")

	# 2) 拖错卡片 → mismatched，关卡不推进
	zone._drop_data(Vector2.ZERO, {"card_id": "card_shoes"})
	await _wait(10)
	_check(counter.n == 1, "拖错触发 mismatched 一次")
	_check(main._index == 0, "拖错后关卡不推进")
	_check(main._state == main.State.PLAYING, "拖错后仍可继续尝试")

	# 3) 幽灵小手提示（模拟 10s 空闲超时）
	main._on_idle_timeout()
	await _wait(30)
	var ghost: TextureRect = binder.get_node("Root/GhostHand")
	_check(ghost.visible == true, "空闲超时显示幽灵小手")
	main._on_card_drag_started("card_wake")
	await _wait(2)
	_check(ghost.visible == false, "开始拖拽后隐藏小手")

	# 4) 拖对卡片 → 起床动画（3s）后自动进下一关
	zone._drop_data(Vector2.ZERO, {"card_id": "card_wake"})
	await _wait(10)
	_check(main._state == main.State.LOCKED, "匹配成功进入 LOCKED")
	await _seconds(3.4)
	_check(main._index == 1, "起床动画结束后进入第 2 关")
	_check(main._state == main.State.PLAYING, "新关卡回到 PLAYING")
	_check(character.rotation == 0.0, "小人已站起")

	# 5) 连通全流程直至结算（清单关改为点徽章）
	var guard := 0
	var pants_seen := {"ok": false}
	while main._state != main.State.FINISHED and guard < 40:
		guard += 1
		var lv: Dictionary = main._current_level()
		if str(lv.get("kind", "")) == "checklist":
			_check(checklist._root.visible == true, "自检清单关已显示")
			for i in 6:
				checklist._on_badge_pressed(i)
			await _seconds(2.6)
			continue
		var req := str(lv.get("req_card", ""))
		var p: Node = main.get_node("PropLayer").get_child(0)
		var z: BaseProp = p.get_node("DropZone")
		if req == "card_pants":
			# 穿裤子关：先验证拖错裤子之外的东西只触发 mismatched
			var before: int = main._index
			z._drop_data(Vector2.ZERO, {"card_id": "card_shirt"})
			await _wait(10)
			_check(main._index == before and main._state == main.State.PLAYING,
					"穿裤子关拖错不推进")
			pants_seen.ok = true
		z._drop_data(Vector2.ZERO, {"card_id": req})
		await _seconds(2.3)
		if str(lv.get("id", "")) == "pants":
			_check(pants_seen.ok, "穿裤子关流程覆盖")
	_check(main._state == main.State.FINISHED, "全部 8 关完成")
	_check(end_screen.visible == true, "结算页显示")
	_check(character._pants_on == true, "通关时小人已穿上裤子")

	# 6) 重开
	end_screen.restart_pressed.emit()
	await _wait(20)
	_check(main._index == 0, "重开后回到第 1 关")
	_check(main._state == main.State.PLAYING, "重开后状态 PLAYING")
	_check(absf(character.rotation + PI * 0.5) < 0.01, "重开后小人重新躺回床上")

	print("SMOKE RESULT: %s (%d 失败)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [PASS] ", label)
	else:
		_fails += 1
		print("  [FAIL] ", label)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _seconds(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

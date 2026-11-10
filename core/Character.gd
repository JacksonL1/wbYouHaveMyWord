class_name Character
extends Node2D
##
## 小人角色（分部件骨骼式动画）
## ============================
## 用 Node2D 层级 + Tween 驱动，不需要逐帧精灵表：
##   根节点原点 = 脚底中心，向上为 -Y；整体 rotation 控制「躺 / 坐 / 站」。
##
## 对外接口（由 Main.gd 调用）：
##   setup_for_level(level_id)   进入关卡时摆好姿态、服装、手持道具、表情
##   play_action()               播放本关的循环小动作（刷刷 / 擦脸 / 举杯…）
##   play_success(level_id)      通关反馈动画；返回建议停留秒数
##   play_wrong()                拖错时的轻微摇头
##   stop_action()               停止循环动作
##
## 姿态约定：
##   躺下 = rotation -90° + BED_POS（头朝左，正好落在枕头位置）
##   站立 = rotation   0° + STAND_POS（床左侧，不遮挡中央道具拖拽热区）
##

const CHAR_DIR := "res://assets/character/"
const STAND_POS := Vector2(330.0, 500.0)
const BED_POS := Vector2(760.0, 390.0)
const BASE_SCALE := 0.72
const HEAD_Y := -250.0
const LYING_ROT := -PI * 0.5

## 各关卡手里拿的小道具
const ITEM_FILE := {
	"brush": "mini_brush.png",
	"drink": "mini_cup.png",
	"wash": "mini_towel.png",
	"shirt": "mini_shirt.png",
	"shoes": "mini_shoe.png",
}
## 通关后需要的停留时长（起床动画最长）
const SUCCESS_HOLD := {
	"wake": 3.0,
	"brush": 1.9,
	"shirt": 1.8,
	"shoes": 1.8,
}

var _leg_l: Sprite2D
var _leg_r: Sprite2D
var _shoe_l: Sprite2D
var _shoe_r: Sprite2D
var _body: Sprite2D
var _arm_l: Node2D
var _arm_r: Node2D
var _head: Node2D
var _faces: Dictionary = {}
var _item: Sprite2D
var _zzz: Sprite2D
var _bubbles: Node2D
var _bubble_sprites: Array[Sprite2D] = []

var _main_tween: Tween
var _action_tween: Tween
var _breathe_tween: Tween
var _fx_tween: Tween
var _arm_tween: Tween
var _bubble_time := 0.0
var _level_id := ""
var _dressed := false
var _shoes_on := false


func _ready() -> void:
	_build()
	scale = Vector2.ONE * BASE_SCALE
	reset_to_stand()


# --------------------------------------------------------------------------
# 场景构建（代码生成，避免手写 tscn 里十几个 ext_resource 容易错位）
# --------------------------------------------------------------------------
func _tex(file: String) -> Texture2D:
	var path := CHAR_DIR + file
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _sprite(file: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(file)
	s.position = pos
	return s


func _build() -> void:
	# 腿（旋转轴在自身中心，站立时固定）
	_leg_l = _sprite("leg.png", Vector2(-22, -52))
	_leg_r = _sprite("leg.png", Vector2(22, -52))
	add_child(_leg_l)
	add_child(_leg_r)

	# 鞋子：穿鞋关通关后才显示
	_shoe_l = _sprite("shoe.png", Vector2(-24, -6))
	_shoe_r = _sprite("shoe.png", Vector2(24, -6))
	_shoe_l.visible = false
	_shoe_r.visible = false
	add_child(_shoe_l)
	add_child(_shoe_r)

	# 躯干
	_body = _sprite("body_pajama.png", Vector2(0, -150))
	add_child(_body)

	# 手臂：Node2D 当肩关节（旋转轴），Sprite 挂在下方
	_arm_l = _make_arm(Vector2(-56, -196))
	_arm_r = _make_arm(Vector2(56, -196))
	add_child(_arm_l)
	add_child(_arm_r)

	# 右手手心挂手持道具
	var hand := Node2D.new()
	hand.position = Vector2(0, 92)
	_arm_r.add_child(hand)
	_item = _sprite("mini_brush.png", Vector2(-14, -46))
	_item.scale = Vector2.ONE * 0.8
	_item.visible = false
	hand.add_child(_item)

	# 头 + 四张可切换的脸
	_head = Node2D.new()
	_head.position = Vector2(0, HEAD_Y)
	add_child(_head)
	_head.add_child(_sprite("head.png", Vector2.ZERO))
	for face_name in ["awake", "asleep", "brush", "happy"]:
		var f := _sprite("face_%s.png" % face_name, Vector2.ZERO)
		f.visible = false
		_head.add_child(f)
		_faces[face_name] = f

	# 睡觉 Zzz（反向旋转抵消整体旋转，始终竖直）
	_zzz = _sprite("zzz.png", Vector2(58, -350))
	_zzz.visible = false
	add_child(_zzz)

	# 泡泡粒子（刷牙 / 洗脸时从嘴边冒出）
	_bubbles = Node2D.new()
	_bubbles.position = Vector2(6, -214)
	_bubbles.visible = false
	add_child(_bubbles)
	for i in 5:
		var b := _sprite("bubble.png", Vector2(-20 + i * 12, 0))
		b.scale = Vector2.ONE * (0.72 + 0.09 * i)
		b.modulate.a = 0.0
		_bubbles.add_child(b)
		_bubble_sprites.append(b)


func _make_arm(shoulder: Vector2) -> Node2D:
	var pivot := Node2D.new()
	pivot.position = shoulder
	pivot.add_child(_sprite("arm.png", Vector2(0, 48)))
	return pivot


# --------------------------------------------------------------------------
# 基础状态
# --------------------------------------------------------------------------
func _set_face(name: String) -> void:
	for key in _faces:
		(_faces[key] as Sprite2D).visible = (key == name)


func _apply_outfit() -> void:
	_body.texture = _tex("body_shirt.png") if _dressed else _tex("body_pajama.png")
	_shoe_l.visible = _shoes_on
	_shoe_r.visible = _shoes_on


func _reset_limbs() -> void:
	_arm_l.rotation = 0.0
	_arm_r.rotation = 0.0
	_leg_l.rotation = 0.0
	_leg_r.rotation = 0.0
	_head.position = Vector2(0, HEAD_Y)


func reset_to_stand() -> void:
	_kill_all()
	rotation = 0.0
	position = STAND_POS
	scale = Vector2.ONE * BASE_SCALE
	_set_face("awake")
	_reset_limbs()
	_zzz.visible = false
	_bubbles.visible = false
	_item.visible = false
	_dressed = false
	_shoes_on = false
	_apply_outfit()
	_start_breathe()


## 进入关卡：按剧情决定「躺 / 站、衣服、鞋子、手里拿什么、什么表情」
func setup_for_level(level_id: String) -> void:
	_kill_all()
	_level_id = level_id
	_dressed = level_id in ["shoes", "checklist"]
	_shoes_on = level_id == "checklist"
	_apply_outfit()
	_reset_limbs()

	# 手持道具
	var file: String = str(ITEM_FILE.get(level_id, ""))
	_item.visible = not file.is_empty()
	_item.modulate.a = 1.0
	if not file.is_empty():
		_item.texture = _tex(file)

	scale = Vector2.ONE * BASE_SCALE
	if level_id == "wake":
		rotation = LYING_ROT
		position = BED_POS
		_set_face("asleep")
		_zzz.visible = true
		_zzz.modulate.a = 0.9
		_zzz.rotation = -LYING_ROT
	elif level_id == "checklist":
		# 清单关：小人缩小站到画面下方中央，避开五个徽章
		rotation = 0.0
		position = Vector2(640.0, 686.0)
		scale = Vector2.ONE * 0.62
		_set_face("happy")
		_zzz.visible = false
		_zzz.rotation = 0.0
	else:
		rotation = 0.0
		position = STAND_POS
		_set_face("brush" if level_id == "brush" else "awake")
		_zzz.visible = false
		_zzz.rotation = 0.0

	_start_breathe()
	play_action()


func get_success_hold() -> float:
	return float(SUCCESS_HOLD.get(_level_id, 1.5))


# --------------------------------------------------------------------------
# 循环小动作（每关进关后持续播放，通关时停止）
# --------------------------------------------------------------------------
func play_action() -> void:
	stop_action()
	match _level_id:
		"wake":
			_action_tween = create_tween().set_loops()
			_action_tween.tween_property(_zzz, "position:y", -370.0, 1.1) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_action_tween.tween_property(_zzz, "position:y", -350.0, 1.1) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"brush":
			# 「刷刷」：右臂在嘴边左右快速摆动 + 身体轻晃 + 泡泡
			_action_tween = create_tween().set_loops()
			_action_tween.tween_property(_arm_r, "rotation", -1.86, 0.28) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_action_tween.tween_property(_arm_r, "rotation", -1.30, 0.28) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_sway_body(0.56)
			_start_bubbles()
		"wash":
			_action_tween = create_tween().set_loops()
			_action_tween.tween_property(_arm_r, "rotation", -1.48, 0.36) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_action_tween.tween_property(_arm_r, "rotation", -0.92, 0.36) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_sway_body(0.72)
			_start_bubbles()
		"drink":
			_action_tween = create_tween().set_loops()
			_action_tween.tween_property(_arm_r, "rotation", -1.22, 0.9) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_action_tween.tween_property(_arm_r, "rotation", -0.95, 0.9) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"shirt":
			_action_tween = create_tween().set_loops()
			_action_tween.tween_property(_arm_r, "rotation", -0.36, 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_action_tween.tween_property(_arm_r, "rotation", -0.12, 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"shoes", "checklist":
			_action_tween = create_tween().set_loops()
			_action_tween.tween_property(_arm_r, "rotation", -0.5, 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_action_tween.tween_property(_arm_r, "rotation", 0.1, 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			pass


func _sway_body(period: float) -> void:
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween().set_loops()
	_fx_tween.tween_property(_body, "rotation", 0.045, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fx_tween.tween_property(_body, "rotation", -0.045, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 泡泡用逐帧正弦驱动（而非 Tween）：5 颗错峰上浮，任何时刻都看得见
func _process(delta: float) -> void:
	if not _bubbles.visible:
		return
	_bubble_time += delta
	for i in _bubble_sprites.size():
		var b := _bubble_sprites[i] as Sprite2D
		var phase: float = fmod(_bubble_time * 0.85 + float(i) * 0.2, 1.0)
		# 从嘴边往右上方飘散，避免盖住头发和脸
		b.position.y = -phase * 58.0
		b.position.x = 16.0 + phase * 54.0 + sin(phase * 5.0 + float(i)) * 5.0
		b.modulate.a = sin(phase * PI) * 0.9


func _start_bubbles() -> void:
	_bubble_time = 0.0
	_bubbles.visible = true


func _start_breathe() -> void:
	if _breathe_tween and _breathe_tween.is_valid():
		_breathe_tween.kill()
	_breathe_tween = create_tween().set_loops()
	_breathe_tween.tween_property(_head, "position:y", HEAD_Y - 4.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_property(_head, "position:y", HEAD_Y, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_action() -> void:
	if _action_tween and _action_tween.is_valid():
		_action_tween.kill()
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_body.rotation = 0.0
	_bubbles.visible = false
	for b in _bubble_sprites:
		(b as Sprite2D).modulate.a = 0.0


# --------------------------------------------------------------------------
# 通关动画
# --------------------------------------------------------------------------
func play_success(level_id: String = "") -> void:
	if not level_id.is_empty():
		_level_id = level_id
	stop_action()
	if _main_tween and _main_tween.is_valid():
		_main_tween.kill()
	match _level_id:
		"wake":
			play_wake_up()
		"drink":
			_drink_finish()
		"brush":
			_set_face("happy")
			_item.visible = false
			_cheer()
		"wash":
			_set_face("happy")
			_item.visible = false
			_cheer()
		"shirt":
			_dress_up()
		"shoes":
			_put_on_shoes()
		"checklist":
			_cheer()
		_:
			_cheer()


## 重头戏：从床上慢慢起来 —— 撑起 → 睁眼 → 伸懒腰 → 站到床边
func play_wake_up() -> void:
	_zzz.visible = false
	_item.visible = false
	if _breathe_tween and _breathe_tween.is_valid():
		_breathe_tween.kill()

	var t := create_tween()
	_main_tween = t
	# 1) 撑起上半身（还闭着眼）
	t.tween_property(self, "rotation", deg_to_rad(-58.0), 0.95) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "position", Vector2(722, 398), 0.95) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 2) 睁开眼
	t.tween_callback(_open_eyes)
	t.tween_interval(0.18)
	# 3) 坐直 + 伸懒腰
	t.tween_property(self, "rotation", deg_to_rad(-16.0), 0.72) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "position", Vector2(560, 442), 0.72) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_stretch)
	t.tween_interval(0.42)
	# 4) 站起来，轻轻走到床边
	t.tween_property(self, "rotation", 0.0, 0.82) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "position", STAND_POS, 0.82) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(_lower_arms)
	t.tween_callback(_happy_hop)


func _open_eyes() -> void:
	_set_face("awake")
	_start_breathe()


func _stretch() -> void:
	_arm_tween = create_tween().set_parallel(true)
	_arm_tween.tween_property(_arm_l, "rotation", 2.6, 0.34).set_trans(Tween.TRANS_BACK)
	_arm_tween.tween_property(_arm_r, "rotation", -2.6, 0.34).set_trans(Tween.TRANS_BACK)


func _lower_arms() -> void:
	_arm_tween = create_tween().set_parallel(true)
	_arm_tween.tween_property(_arm_l, "rotation", 0.0, 0.32)
	_arm_tween.tween_property(_arm_r, "rotation", 0.0, 0.32)
	_set_face("happy")


func _happy_hop() -> void:
	var t := create_tween()
	t.tween_property(self, "position:y", STAND_POS.y - 20.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", STAND_POS.y, 0.24) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _cheer() -> void:
	_set_face("happy")
	var t := create_tween()
	_main_tween = t
	t.tween_property(_arm_l, "rotation", 2.3, 0.26).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(_arm_r, "rotation", -2.3, 0.26).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "position:y", position.y - 16.0, 0.18)
	t.tween_property(self, "position:y", position.y, 0.26).set_trans(Tween.TRANS_BOUNCE)
	t.tween_interval(0.35)
	t.tween_property(_arm_l, "rotation", 0.0, 0.3)
	t.parallel().tween_property(_arm_r, "rotation", 0.0, 0.3)


func _drink_finish() -> void:
	_set_face("happy")
	var t := create_tween()
	_main_tween = t
	t.tween_property(_arm_r, "rotation", -1.7, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.42)
	t.tween_property(_arm_r, "rotation", -0.3, 0.4)
	t.tween_property(_item, "modulate:a", 0.0, 0.2)


func _dress_up() -> void:
	_set_face("happy")
	var t := create_tween()
	_main_tween = t
	# 衣服举高 → 闪一下 → 换成穿上 T 恤
	t.tween_property(_arm_r, "rotation", -1.9, 0.3).set_trans(Tween.TRANS_BACK)
	t.tween_interval(0.28)
	t.tween_callback(func() -> void:
		_dressed = true
		_apply_outfit()
		_item.visible = false
		AudioManager.play_sfx("sparkle"))
	t.tween_property(self, "scale", Vector2.ONE * BASE_SCALE * 1.08, 0.16) \
		.set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2.ONE * BASE_SCALE, 0.28) \
		.set_trans(Tween.TRANS_BACK)
	t.tween_property(_arm_r, "rotation", 0.0, 0.35)


func _put_on_shoes() -> void:
	_set_face("happy")
	var t := create_tween()
	_main_tween = t
	t.tween_property(_arm_r, "rotation", -1.2, 0.28)
	t.tween_interval(0.22)
	t.tween_callback(func() -> void:
		_shoes_on = true
		_apply_outfit()
		_item.visible = false
		AudioManager.play_sfx("snap"))
	# 原地踏两下
	t.tween_property(_leg_l, "rotation", -0.35, 0.18)
	t.tween_property(_leg_l, "rotation", 0.0, 0.18)
	t.tween_property(_leg_r, "rotation", 0.35, 0.18)
	t.tween_property(_leg_r, "rotation", 0.0, 0.18)
	t.tween_property(_arm_r, "rotation", 0.0, 0.3)


## 拖错：轻轻摇头，不惩罚、不中断循环动作
func play_wrong() -> void:
	var t := create_tween()
	t.tween_property(_head, "rotation", 0.14, 0.09)
	t.tween_property(_head, "rotation", -0.14, 0.16)
	t.tween_property(_head, "rotation", 0.0, 0.12)


func _kill_all() -> void:
	for tw in [_main_tween, _action_tween, _breathe_tween, _fx_tween, _arm_tween]:
		if tw and tw.is_valid():
			tw.kill()
	_zzz.visible = false
	_bubbles.visible = false
	for b in _bubble_sprites:
		(b as Sprite2D).modulate.a = 0.0
	_body.rotation = 0.0
	_head.rotation = 0.0

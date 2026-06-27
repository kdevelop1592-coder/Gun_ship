extends CharacterBody3D

const SPEED = 10.0
const TURN_SPEED = 2.0
const ZOOM_SPEED = 2.0
const MIN_ZOOM = 5.0
const MAX_ZOOM = 40.0

@onready var camera = $Camera3D
var camera_offset = Vector3.ZERO

func _ready():
	if is_multiplayer_authority():
		camera.current = true
		# 카메라가 부모(배)의 회전을 따라가지 않도록 독립(Top Level) 설정
		camera.top_level = true
		# 배와 카메라 사이의 초기 거리 유지
		camera_offset = camera.global_position - global_position

var cannonball_scene = preload("res://cannonball.tscn")

func _input(event):
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size -= ZOOM_SPEED
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size += ZOOM_SPEED
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			rpc("fire_cannon", -1) # 좌현 발사
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			rpc("fire_cannon", 1)  # 우현 발사
		
		# Clamp zoom level
		camera.size = clamp(camera.size, MIN_ZOOM, MAX_ZOOM)

@rpc("any_peer", "call_local")
func fire_cannon(side: int):
	if not cannonball_scene: return
	
	var ball = cannonball_scene.instantiate()
	var game_container = get_node_or_null("/root/Main/GameContainer")
	if game_container:
		game_container.add_child(ball)
	else:
		get_tree().root.add_child(ball)
		
	# 방향 및 발사 위치 계산 (side가 -1이면 왼쪽, 1이면 오른쪽)
	var right_dir = global_transform.basis.x * side
	var spawn_pos = global_position + right_dir * 2.5 + Vector3(0, 1.5, 0)
	
	ball.global_position = spawn_pos
	
	# 발사 속도 부여 (바깥쪽 + 살짝 위쪽 포물선)
	var shoot_dir = right_dir + Vector3(0, 0.2, 0)
	ball.linear_velocity = shoot_dir.normalized() * 30.0

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	# Input mapping (Arrow keys or WASD)
	var turn_input = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		turn_input -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		turn_input += 1.0
		
	var forward_input = 0.0
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		forward_input -= 1.0
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		forward_input += 1.0

	# Rotate ship (positive Y rotation is counter-clockwise)
	rotate_y(turn_input * TURN_SPEED * delta)
	
	# Move forward based on rotation (-Z is forward in Godot)
	var forward_dir = -global_transform.basis.z
	velocity = forward_dir * forward_input * SPEED
	
	move_and_slide()
	
	# Update camera position to follow ship
	if camera.top_level:
		camera.global_position = global_position + camera_offset

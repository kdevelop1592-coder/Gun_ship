extends CharacterBody3D

const SPEED = 10.0
const TURN_SPEED = 2.0
const ZOOM_SPEED = 2.0
const MIN_ZOOM = 5.0
const MAX_ZOOM = 40.0
@onready var camera = $Camera3D
var camera_offset = Vector3.ZERO
var wake_particles: GPUParticles3D

var max_health: float = 100.0
var current_health: float = 100.0

func _ready():
	add_to_group("player")
	setup_wake_particles()
	
	# 시각적 요소(배, 대포)들을 묶어서 180도 회전하던 꼼수 코드를 완전히 제거했습니다!
	# 이제 에디터에 배치된 그대로의 위치와 계층 구조를 사용합니다.
	
	if is_multiplayer_authority():
		camera.current = true
		# 카메라가 부모(배)의 회전을 따라가지 않도록 독립(Top Level) 설정
		camera.top_level = true
		# 배와 카메라 사이의 초기 거리 유지
		camera_offset = camera.global_position - global_position

func setup_wake_particles():
	wake_particles = GPUParticles3D.new()
	wake_particles.emitting = false
	wake_particles.amount = 40
	wake_particles.lifetime = 1.2
	wake_particles.local_coords = false # 파티클이 배를 따라가지 않고 수면에 남도록 설정
	
	# 배의 뒤쪽(Z축 방향) 수면(Y축) 근처에 위치
	wake_particles.position = Vector3(0, -0.5, 2.5)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(1, 1)
	mesh.material = mat
	wake_particles.draw_pass_1 = mesh
	
	var proc = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(1.2, 0.1, 0.1)
	proc.direction = Vector3(0, 0, 1) # 뒤로 이동
	proc.spread = 15.0
	proc.initial_velocity_min = 1.0
	proc.initial_velocity_max = 3.0
	proc.gravity = Vector3(0, 0, 0)
	
	var scale_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.5))
	scale_curve.curve = curve
	proc.scale_curve = scale_curve
	
	var color_curve = GradientTexture1D.new()
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 0.8))
	grad.add_point(1.0, Color(1, 1, 1, 0.0))
	color_curve.gradient = grad
	proc.color_ramp = color_curve
	
	wake_particles.process_material = proc
	add_child(wake_particles)

var cannonball_scene = preload("res://cannonball.tscn")
var active_cannon_side: int = 0 # 0: 양쪽, -1: 좌현, 1: 우현 (기본값 양쪽)

func _input(event):
	if not is_multiplayer_authority():
		return
	
	# 포대 선택 키 처리 (Q: 좌현, E: 우현, R: 양쪽)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			active_cannon_side = -1
			print("좌포대 선택됨")
		elif event.physical_keycode == KEY_E:
			active_cannon_side = 1
			print("우포대 선택됨")
		elif event.physical_keycode == KEY_R:
			active_cannon_side = 0
			print("양쪽 포대 선택됨")
			
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size -= ZOOM_SPEED
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size += ZOOM_SPEED
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if active_cannon_side == 0:
				rpc("fire_cannon", -1) # 좌현 발사
				rpc("fire_cannon", 1)  # 우현 발사
			else:
				rpc("fire_cannon", active_cannon_side) # 선택된 포대만 발사
		
		# Clamp zoom level
		camera.size = clamp(camera.size, MIN_ZOOM, MAX_ZOOM)

@rpc("any_peer", "call_local")
func fire_cannon(side: int):
	if not cannonball_scene: return
	
	var ball = cannonball_scene.instantiate()
	ball.shooter_name = name
	
	var game_container = get_node_or_null("/root/Main/GameContainer")
	if game_container:
		game_container.add_child(ball)
	else:
		get_tree().root.add_child(ball)
		
	var spawn_node: Node3D = null
	if side == -1 and has_node("CannonLeft/SpawnPoint"):
		spawn_node = get_node("CannonLeft/SpawnPoint")
	elif side == 1 and has_node("CannonRight/SpawnPoint"):
		spawn_node = get_node("CannonRight/SpawnPoint")
		
	if spawn_node:
		# 시작 위치는 에디터의 SpawnPoint 위치를 그대로 사용합니다.
		ball.global_position = spawn_node.global_position
		
		# === [발사 방향 설정] ===
		# 눈에 보이지 않는 'SpawnPoint(Marker3D)' 노드가 바라보는 방향(-X축)을 사용합니다!
		# 대포 모델 자체는 가만히 두고, SpawnPoint만 회전시키면 포탄이 날아가는 방향(고각/편각)을 마음대로 바꿀 수 있습니다.
		var shoot_dir = -spawn_node.global_transform.basis.x.normalized()
		
		ball.linear_velocity = shoot_dir * 30.0
	else:
		# SpawnPoint가 없을 경우를 대비한 기존 로직
		var right_dir = global_transform.basis.x * side
		var shoot_dir = right_dir + Vector3(0, 0.2, 0)
		
		var spawn_pos = global_position
		if side == -1 and has_node("CannonLeft"):
			spawn_pos = $CannonLeft.global_position
		elif side == 1 and has_node("CannonRight"):
			spawn_pos = $CannonRight.global_position
		else:
			spawn_pos = global_position + right_dir * 2.5 + Vector3(0, 1.5, 0)
		
		ball.global_position = spawn_pos + right_dir * 1.0
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
	
	# 물결 파티클 제어 (앞으로 이동할 때만 방출)
	if wake_particles:
		wake_particles.emitting = (forward_input > 0.1)
	
	# Update camera position to follow ship
	if camera.top_level:
		camera.global_position = global_position + camera_offset

# 데미지를 입었을 때 호출되는 함수
@rpc("any_peer", "call_local")
func take_damage(amount: float):
	if not is_multiplayer_authority():
		return
	
	current_health -= amount
	print("플레이어 피격! 남은 체력: ", current_health)
	
	if current_health <= 0:
		die()

func die():
	print("플레이어 파괴됨!")
	# 폭발 파티클 재생 등을 여기에 추가할 수 있습니다.
	queue_free()

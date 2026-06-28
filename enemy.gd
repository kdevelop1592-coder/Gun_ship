extends CharacterBody3D

const SPEED = 5.0
const TURN_SPEED = 2.0
const ATTACK_RANGE = 30.0
const FIRE_COOLDOWN = 3.0

var max_health: float = 100.0
var current_health: float = 100.0

var wake_particles: GPUParticles3D
var cannonball_scene = preload("res://cannonball.tscn")
var fire_timer: float = 0.0

func _ready():
	add_to_group("enemy")
	setup_wake_particles()
	
	# 적군 구분을 위한 빨간색 조명 추가
	var red_light = OmniLight3D.new()
	red_light.light_color = Color(1, 0.2, 0.2)
	red_light.light_energy = 5.0
	red_light.omni_range = 10.0
	red_light.position = Vector3(0, 3, 0)
	add_child(red_light)

func setup_wake_particles():
	wake_particles = GPUParticles3D.new()
	wake_particles.emitting = false
	wake_particles.amount = 40
	wake_particles.lifetime = 1.2
	wake_particles.local_coords = false
	
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
	proc.direction = Vector3(0, 0, 1)
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

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
		
	var target = get_closest_player()
	if not target:
		wake_particles.emitting = false
		return
		
	var to_target = target.global_position - global_position
	to_target.y = 0
	var distance = to_target.length()
	
	var forward_dir = -global_transform.basis.z
	var move_speed = 0.0
	
	if distance > ATTACK_RANGE:
		# 타겟을 향해 회전하며 전진
		var target_dir = to_target.normalized()
		var angle_diff = forward_dir.signed_angle_to(target_dir, Vector3.UP)
		rotate_y(sign(angle_diff) * min(abs(angle_diff), TURN_SPEED * delta))
		move_speed = SPEED
	else:
		# 공격 사거리 내: 옆면(좌현 또는 우현)을 타겟으로 향하도록 회전
		var right_dir = global_transform.basis.x
		var left_dir = -global_transform.basis.x
		
		# 더 가까운 옆면 찾기
		var angle_to_right = right_dir.angle_to(to_target.normalized())
		var angle_to_left = left_dir.angle_to(to_target.normalized())
		
		var target_side_dir = right_dir
		var fire_side = 1
		if angle_to_left < angle_to_right:
			target_side_dir = left_dir
			fire_side = -1
			
		# 타겟을 바라보도록 90도 틀기 (옆면을 보여줌)
		var desired_forward = to_target.normalized().rotated(Vector3.UP, PI/2 * fire_side)
		var angle_diff = forward_dir.signed_angle_to(desired_forward, Vector3.UP)
		rotate_y(sign(angle_diff) * min(abs(angle_diff), TURN_SPEED * delta))
		
		# 사격 쿨다운
		fire_timer -= delta
		if fire_timer <= 0.0 and abs(angle_diff) < 0.2:
			rpc("fire_cannon", fire_side)
			fire_timer = FIRE_COOLDOWN
			
	velocity = forward_dir * move_speed
	move_and_slide()
	
	if wake_particles:
		wake_particles.emitting = (move_speed > 0.1)

func get_closest_player() -> Node3D:
	var closest = null
	var min_dist = INF
	
	var container = get_parent()
	if container:
		for child in container.get_children():
			# Player 식별: health가 있고 이름이 Enemy로 시작하지 않는 것
			if child.has_method("take_damage") and not child.name.begins_with("Enemy_"):
				var dist = global_position.distance_to(child.global_position)
				if dist < min_dist:
					min_dist = dist
					closest = child
	return closest

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
		ball.global_position = spawn_node.global_position
		var shoot_dir = -spawn_node.global_transform.basis.x.normalized()
		# 적군은 명중률을 높이기 위해 약간의 고각을 고정으로 추가할 수 있음
		shoot_dir.y += tan(deg_to_rad(5.0))
		ball.linear_velocity = shoot_dir.normalized() * 30.0
	else:
		var right_dir = global_transform.basis.x * side
		ball.global_position = global_position + right_dir * 2.0 + Vector3(0, 1.0, 0)
		ball.linear_velocity = right_dir * 30.0

@rpc("any_peer", "call_local")
func take_damage(amount: float):
	if not is_multiplayer_authority():
		return
	
	current_health -= amount
	print("적 피격! 남은 체력: ", current_health)
	
	if current_health <= 0:
		die()

func die():
	print("적 파괴됨!")
	queue_free()

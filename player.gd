extends CharacterBody3D

const SPEED = 10.0
const TURN_SPEED = 2.0
const ZOOM_SPEED = 2.0
const MIN_ZOOM = 5.0
const MAX_ZOOM = 40.0

@onready var camera = $Camera3D

func _ready():
	if is_multiplayer_authority():
		camera.current = true

func _input(event):
	if not is_multiplayer_authority():
		return
	
	# Mouse scroll for zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size -= ZOOM_SPEED
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size += ZOOM_SPEED
		
		# Clamp zoom level
		camera.size = clamp(camera.size, MIN_ZOOM, MAX_ZOOM)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	# Input mapping (Arrow keys or WASD)
	var turn_input = Input.get_axis("ui_right", "ui_left")
	var forward_input = Input.get_axis("ui_down", "ui_up")

	# Rotate ship (positive Y rotation is counter-clockwise)
	rotate_y(turn_input * TURN_SPEED * delta)
	
	# Move forward based on rotation (-Z is forward in Godot)
	var forward_dir = -global_transform.basis.z
	velocity = forward_dir * forward_input * SPEED
	
	move_and_slide()

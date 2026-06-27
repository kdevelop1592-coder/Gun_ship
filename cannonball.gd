extends RigidBody3D

func _ready():
	# 3초 후 자동 소멸
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)

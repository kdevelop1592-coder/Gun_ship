extends RigidBody3D

var damage: float = 20.0
var shooter_name: String = ""

func _ready():
	# 3초 후 자동 소멸
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if body.has_method("take_damage"):
		# 자신을 쏜 주체에게는 데미지를 주지 않음
		if body.name != shooter_name:
			body.rpc("take_damage", damage)
	queue_free() # 충돌 후 폭발(소멸)

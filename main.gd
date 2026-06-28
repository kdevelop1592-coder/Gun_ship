extends Node

const PORT = 7000
const MAX_PLAYERS = 4

var peer = ENetMultiplayerPeer.new()

@onready var host_button = $LobbyUI/VBoxContainer/HostButton
@onready var join_button = $LobbyUI/VBoxContainer/HBoxContainer/JoinButton
@onready var address_input = $LobbyUI/VBoxContainer/HBoxContainer/AddressInput
@onready var lobby_ui = $LobbyUI
@onready var game_container = $GameContainer

var player_scene = preload("res://player.tscn")
var enemy_scene = preload("res://enemy.tscn")
var hud_scene = preload("res://hud.tscn")
var enemy_spawn_timer: Timer
var enemy_count: int = 0

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

func _on_host_pressed():
	var error = peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		print("Cannot host: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Hosting on port ", PORT)
	_start_game()
	_add_player(1)

func _on_join_pressed():
	var address = address_input.text
	if address == "":
		address = "127.0.0.1"
		
	var error = peer.create_client(address, PORT)
	if error != OK:
		print("Cannot join: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Joining ", address)

func _start_game():
	lobby_ui.hide()
	
	if hud_scene:
		var hud = hud_scene.instantiate()
		add_child(hud)
		
	# Load game map here if needed
	var map = Node3D.new()
	map.name = "Map"
	game_container.add_child(map)
	
	# 태양(DirectionalLight) 추가
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	map.add_child(sun)
	
	# 기본 하늘(Environment) 세팅
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.7, 0.9) # 하늘색 배경
	var we = WorldEnvironment.new()
	we.environment = env
	map.add_child(we)
	
	# 바다(Sea) 메쉬 추가
	var sea = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(500, 500) # 바다 크기
	sea.mesh = plane_mesh
	
	var sea_mat = StandardMaterial3D.new()
	sea_mat.albedo_color = Color(0.15, 0.45, 0.75, 0.85) # 푸른 바다색
	sea_mat.roughness = 0.1
	sea_mat.metallic = 0.1
	sea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.material_override = sea_mat
	
	# 물이 배보다 약간 아래에 위치하도록 Y값 조정
	sea.position.y = -0.2
	map.add_child(sea)
	
	# 서버(호스트)일 경우에만 적 스폰 타이머 작동
	if multiplayer.is_server():
		enemy_spawn_timer = Timer.new()
		enemy_spawn_timer.wait_time = 10.0 # 10초마다 스폰
		enemy_spawn_timer.autostart = true
		enemy_spawn_timer.timeout.connect(_on_spawn_enemy)
		add_child(enemy_spawn_timer)

func _on_spawn_enemy():
	if not enemy_scene: return
	
	var enemy = enemy_scene.instantiate()
	enemy_count += 1
	enemy.name = "Enemy_" + str(enemy_count)
	
	# 플레이어 주변 무작위 위치 스폰 (반경 30~50)
	var angle = randf() * PI * 2
	var dist = randf_range(30.0, 50.0)
	enemy.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	
	game_container.add_child(enemy)

func _on_player_connected(id):
	print("Player connected: ", id)
	_add_player(id)

func _on_player_disconnected(id):
	print("Player disconnected: ", id)
	if game_container.has_node(str(id)):
		game_container.get_node(str(id)).queue_free()

func _on_connected_ok():
	print("Connected to server")
	_start_game()

func _on_connected_fail():
	print("Connection failed")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	print("Server disconnected")
	lobby_ui.show()
	for c in game_container.get_children():
		c.queue_free()
	multiplayer.multiplayer_peer = null

func _add_player(id):
	if not player_scene: return
	var player = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	game_container.add_child(player)

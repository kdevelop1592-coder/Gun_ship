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
	
	# Load game map here if needed
	var map = Node3D.new()
	map.name = "Map"
	game_container.add_child(map)
	
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	map.add_child(sun)
	
	var env = Environment.new()
	var sky = Sky.new()
	env.sky = sky
	var we = WorldEnvironment.new()
	we.environment = env
	map.add_child(we)

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

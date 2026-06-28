extends CanvasLayer

@onready var map_area = $MinimapContainer/MapArea

# 맵 스케일 (게임 세계의 1단위가 미니맵에서 몇 픽셀로 표시될지)
var map_scale: float = 2.0
var max_range: float = 100.0 # 미니맵에 표시할 최대 반경

func _process(delta):
	# 미니맵을 매 프레임 다시 그리도록 갱신
	map_area.queue_redraw()

func _ready():
	map_area.draw.connect(_on_map_area_draw)

func _on_map_area_draw():
	var players = get_tree().get_nodes_in_group("player")
	var my_player = null
	
	# 내 플레이어 찾기 (멀티플레이어 권한을 가진 플레이어)
	for p in players:
		if p.is_multiplayer_authority():
			my_player = p
			break
			
	if not my_player:
		# 멀티플레이어가 아직 연결 안 됐을 수도 있으므로 첫 번째 플레이어를 임시로 사용
		if players.size() > 0:
			my_player = players[0]
		else:
			return
			
	var center_pos = my_player.global_position
	var map_center = map_area.size / 2.0
	
	# 1. 플레이어 자신 그리기 (파란색)
	map_area.draw_circle(map_center, 4.0, Color(0.2, 0.6, 1.0))
	
	# 플레이어가 바라보는 방향 (선)
	var forward_dir = -my_player.global_transform.basis.z
	var dir_2d = Vector2(forward_dir.x, forward_dir.z).normalized()
	map_area.draw_line(map_center, map_center + dir_2d * 15.0, Color(0.2, 0.6, 1.0), 2.0)
	
	# 2. 적군 그리기 (빨간색)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		var rel_pos = e.global_position - center_pos
		var dist = Vector2(rel_pos.x, rel_pos.z).length()
		
		# 최대 표시 반경 내에 있는 적만 표시 (선택사항)
		if dist <= max_range:
			# 3D의 X, Z 좌표를 2D 미니맵의 X, Y 좌표로 변환
			var map_pos = map_center + Vector2(rel_pos.x, rel_pos.z) * map_scale
			
			# 미니맵 경계를 벗어나지 않도록 클램핑
			map_pos.x = clamp(map_pos.x, 0, map_area.size.x)
			map_pos.y = clamp(map_pos.y, 0, map_area.size.y)
			
			map_area.draw_circle(map_pos, 3.0, Color(1.0, 0.2, 0.2))
			
			# 적의 방향 표시 (선택사항)
			var e_forward = -e.global_transform.basis.z
			var e_dir_2d = Vector2(e_forward.x, e_forward.z).normalized()
			map_area.draw_line(map_pos, map_pos + e_dir_2d * 10.0, Color(1.0, 0.2, 0.2), 1.5)
	
	# 3. 다른 플레이어 그리기 (녹색)
	for p in players:
		if p != my_player:
			var rel_pos = p.global_position - center_pos
			var dist = Vector2(rel_pos.x, rel_pos.z).length()
			if dist <= max_range:
				var map_pos = map_center + Vector2(rel_pos.x, rel_pos.z) * map_scale
				map_pos.x = clamp(map_pos.x, 0, map_area.size.x)
				map_pos.y = clamp(map_pos.y, 0, map_area.size.y)
				map_area.draw_circle(map_pos, 3.0, Color(0.2, 1.0, 0.2))

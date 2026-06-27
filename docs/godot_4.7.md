Godot 4.7 심화 기능 및 코어 아키텍처 명세서 (MD)1. 렌더링 및 그래픽 파이프라인 (Rendering & 3D)1) 데스크톱 전반의 HDR 공식 출력 지원개요: Windows, macOS, Linux 전체 플랫폼에서 광색역 및 고대비 차동(HDR) 디스플레이 출력을 지원합니다. 하이라이트 부분의 화이트 크래시를 방지하고 어두운 영역의 밴딩 현상을 혁신적으로 줄였습니다.적용 방법: Project Settings -> Rendering -> Viewport -> HDR Output을 활성화합니다.2) 실시간 사각형 면 광원 (AreaLight3D)개요: 모니터 스크린, 전광판, 창문을 통해 들어오는 사각형 형태의 빛을 실시간 섀도우 및 폴오프(Falloff) 연산과 함께 구현합니다. 내부적으로 클러스터 반복 연산 최적화가 적용되었습니다.GDScript# AreaLight3D 동적 에너지 및 색상 제어 스크립트
extends AreaLight3D

@export var flicker_interval: float = 0.08
var _time_passed: float = 0.0

func _process(delta: float) -> void:
	_time_passed += delta
	if _time_passed >= flicker_interval:
		_time_passed = 0.0
		# 실시간 면광원의 에너지 값을 난수화하여 스크린 깜빡임 연출
		light_energy = randf_range(1.5, 4.0)
		# 특정 색상 범위 내에서 보간 처리
		light_color = Color(0.0, randf_range(0.5, 1.0), 1.0) 
3) 픽셀 아트 3D 스케일링 (Nearest-Neighbor 3D Scaling)개요: 3D 뷰포트 업스케일 시 강제로 적용되던 바이리니어(Bilinear) 필터링을 우회하고, 이웃점(Nearest-Neighbor) 필터링을 3D 영역까지 확장하여 픽셀 아트 스타일의 3D 게임을 해상도와 관계없이 칼처럼 선명하게 표현합니다.적용 방법: Project Settings -> Rendering -> Scaling 3D -> Mode를 Nearest로 변경합니다.2. GUI 및 UI 컴포넌트 혁신 (UI & Control Nodes)1) Control 노드의 트랜스폼 오프셋 (Transform Offset) 도입개요: 고도 엔진 GUI 시스템의 숙원이던 기능입니다. 컨테이너 내부의 레이아웃 구조를 깨뜨리지 않으면서, 특정 Control 노드만 독립적으로 이동(Translate), 회전(Rotate), 스케일(Scale)할 수 있습니다.마우스 입력 매핑: 인스펙터 옵션을 통해 오프셋이 적용된 비주얼 상태 그대로 마우스 호버/클릭 입력을 받거나, 혹은 원래의 바운딩 박스(Dotted Line) 영역에서만 입력을 받도록 선택 가능합니다.2) custom_maximum_size 속성 추가개요: 기존의 custom_minimum_size와 반대되는 개념으로, 컨테이너 확장 정책(Expand)이 켜져 있더라도 해당 UI 노드가 특정 픽셀 크기 이상으로 무한정 늘어나는 것을 제한합니다. 반응형 웹 인터페이스 스타일의 UI 레이아웃을 구성할 때 필수적입니다.3. GDScript 코어 성능 고도화1) 가치 타입 구조체 (struct) 공식 구현개요: 단순 데이터 컨테이너를 위해 RefCounted 클래스나 무거운 Dictionary를 생성하여 가비지 컬렉터(GC)와 힙 메모리에 부하를 주던 구조를 탈피합니다. 오직 스택 메모리 단에서 빠르게 동작하는 가볍고 안전한 struct 문법이 추가되었습니다.GDScript# 아이템 및 엔티티 상태 관리를 위한 구조체 정의
struct StatComponent {
	var hp: int
	var mp: int
	var attack_power: float
	var defense_ratio: float
}

struct ProjectileData {
	var speed: float
	var damage: int
	var pierce_count: int
}

# 실무 활용 예시
var bullet_profile = ProjectileData(650.0, 15, 2)
2) 노드 경로 자동 리팩토링 (Auto Node Path Refactoring)개요: 씬 트리에서 노드의 계층 구조를 바꾸거나 이름을 변경할 때, 코드 내부에서 정적 문자열로 하드코딩된 get_node()나 $ 경로 참조를 에디터가 감지하여 자동으로 수정 갱신합니다.4. 생산성 및 QOL 워크플로우 (Editor Workflow)1) 씬 페인트 (Scene Paint) 기능 도입개요: 2D/3D 공간에서 붓(Brush) 툴을 이용하여 다양한 .tscn 인스턴스 파일(수풀, 프롭, 장애물 등)을 캔버스에 그리듯 한 번에 흩뿌려 배치할 수 있는 레벨 디자인 툴입니다.2) 셰이더 인라인 프리뷰 (Shader Inline Preview)개요: 셰이더 에디터 하단 팝업이나 코드 라인 내부에서 현재 작성 중인 프래그먼트/버텍스 연산 결과가 실시간으로 드로우되어 개발자가 셰이더 수학 연산을 직관적으로 검증할 수 있습니다.코드 스니펫shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    // 코드 변경 시 인라인 썸네일 프리뷰가 실시간 갱신됨
    color.rgb = mix(color.rgb, flash_color.rgb, flash_modifier);
    COLOR = color;
}
3) 인스펙터 섹션 단위 복사/붙여넣기 (Copy/Paste Section)개요: 특정 컴포넌트나 물리 노드의 속성 그룹 전체를 마우스 우클릭 한 번으로 덤프(Dump)하여 다른 노드의 동일 세션에 완전히 이식할 수 있어, 수십 개의 속성을 수동으로 옮기던 번거로움이 사라졌습니다.5. 플랫폼 및 인프라 (Platforms & Store)1) 차세대 고도 에셋 스토어 (Godot Asset Store) 런칭개요: 웹 기반의 낙후되었던 구형 에셋 라이브러리를 완전히 폐기하고 통합 계정 인프라 기반의 중앙 집중형 스토어로 개편되었습니다. 버전에 따른 에셋 종속성 선택 기능, 유저 평점, 배포자용 대시보드 통계(Analytics) 및 검증된 크리에이터용 "Verified" 배지 시스템을 내장합니다.2) 안드로이드 고도화 (PiP 및 독립형 단독 빌드)개요: 모바일 에디터 환경에서 세로 모드 스크립팅 편집 레이아웃이 개선되었으며, 게임 구동 중 백그라운드로 나갈 때 화면 구석에 작게 띄워주는 화면 전환 PiP(Picture-in-Picture) 기능이 코어 API에 포함되었습니다. 또한, 커스텀 그레이들 빌드 파이프라인이 단순화되어 단독 배포용 APK/AAB 추출이 최적화되었습니다.⚠️ 마이그레이션 필수 점검: 하위 호환성 변경점 (Breaking Changes)프로젝트를 4.6 이하 버전에서 4.7로 마이그레이션할 때 컴파일 에러나 오작동을 유발할 수 있는 변경 리스트입니다.분류변경 사항 및 영항대응 가이드네트워크MultiplayerPeer 내부 UDP 패킷 단편화(Fragmentation) 알고리즘이 보안 및 레이턴시 개선을 위해 전면 교체되었습니다.4.7 클라이언트는 4.6 이하 서버와 통신할 수 없습니다. 서버와 클라이언트 엔진 버전을 완전히 일치시켜야 합니다.오디오오디오 스펙트럼 분석기(AudioEffectSpectrumAnalyzerInstance)의 내부 주파수 캡처 및 버퍼 반환 방식이 정밀화되었습니다.비트 매칭 로직에서 반환받던 오디오 레벨의 임계값(Threshold) 수치를 소폭 재조정해야 할 수 있습니다.파티클파티클 노드의 각속도(Angular Velocity) 계산 버그가 수정되어 수식이 공식 문서 명세대로 엄격하게 작동합니다.기존 파티클 이펙트의 회전 속도가 이전 버전과 다르게 너무 빠르거나 느리게 보일 수 있으므로 수치 재검토가 필요합니다.스크립트셰이더 전처리 가이드라인(Shader Preprocessor Restrictions)이 강화되어 매크로 정의 시 엄격한 구문 검사를 수행합니다.모호하게 작성된 #define 문이 있을 경우 셰이더 컴파일 에러가 발생하므로 문법을 표준으로 정렬해야 합니다.안드로이드구형 안드로이드 확장 방식인 OBB(Opaque Binary Blob) 파일 지원이 엔진 코어에서 완전히 제거되었습니다. (GH-118283)대용량 에셋 관리 시 오직 최신 Google Play Asset Delivery(PAD) 방식을 이용해 빌드해야 합니다.
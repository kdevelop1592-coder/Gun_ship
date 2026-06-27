# 고도 엔진(Godot) 저폴리 잔디 구현 가이드

> Waterfowl 스타일의 잔디를 구현하기 위한 단계별 가이드입니다.

---

## 구현 방식 비교

| 방식 | 장점 | 단점 | 적합한 상황 |
|------|------|------|-------------|
| **MultiMeshInstance3D** | GPU 효율적, 수천 개 인스턴스 | 동적 변경 어려움 | 정적 잔디 대량 배치 |
| **Shader (GDShader)** | 바람 애니메이션, 색상 제어 | 단독으로 인스턴스 불가 | MultiMesh와 함께 사용 |
| **GPUParticles3D** | 동적 스폰, LOD 쉬움 | 세밀한 제어 어려움 | 풀, 먼지, 낙엽 등 |

---

## 권장 구현 흐름

```
기본 메시 → MultiMesh 배치 → 셰이더 적용 → LOD 최적화
```

---

## 1단계 — 잔디 메시 만들기

얇은 쿼드(quad) 두세 장을 X자로 교차시킨 단순한 메시를 사용합니다.

```gdscript
# GDScript로 절차적 잔디 메시 생성
func create_grass_mesh() -> Mesh:
    var st = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    # 앞면
    st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(-0.05, 0,    0))
    st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3( 0.05, 0,    0))
    st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(-0.05, 0.35, 0))
    st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3( 0.05, 0,    0))
    st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3( 0.05, 0.35, 0))
    st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(-0.05, 0.35, 0))

    # 뒷면 (양면 렌더링)
    st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3( 0.05, 0,    0))
    st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(-0.05, 0,    0))
    st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3( 0.05, 0.35, 0))
    st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(-0.05, 0,    0))
    st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(-0.05, 0.35, 0))
    st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3( 0.05, 0.35, 0))

    return st.commit()
```

> **팁:** Blender에서 직접 만든 `.glb` 메시를 임포트해도 됩니다. X자 교차 쿼드가 가장 흔한 방식입니다.

---

## 2단계 — MultiMesh로 수천 개 배치

```gdscript
extends Node3D

@export var grass_count: int = 5000
@export var area_size: float = 20.0

func _ready():
    var mmi = MultiMeshInstance3D.new()
    var mm = MultiMesh.new()

    mm.mesh = create_grass_mesh()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_custom_data = true   # 인스턴스별 색상 변화에 사용
    mm.instance_count = grass_count

    for i in grass_count:
        var t = Transform3D()

        # 랜덤 위치
        t.origin = Vector3(
            randf_range(-area_size, area_size),
            0.0,
            randf_range(-area_size, area_size)
        )

        # 랜덤 Y축 회전
        t.basis = t.basis.rotated(Vector3.UP, randf() * TAU)

        # 랜덤 스케일 (0.8 ~ 1.2배)
        var scale = randf_range(0.8, 1.2)
        t.basis = t.basis.scaled(Vector3(scale, scale, scale))

        mm.set_instance_transform(i, t)

        # 인스턴스별 색상 오프셋 (셰이더에서 사용)
        mm.set_instance_custom_data(i, Color(randf(), randf(), 0, 0))

    mmi.multimesh = mm
    add_child(mmi)
```

---

## 3단계 — 셰이더 적용 (바람 + 색상)

`grass.gdshader` 파일을 생성하고 MultiMeshInstance3D의 Material에 적용합니다.

```glsl
shader_type spatial;
render_mode cull_disabled;  // 양면 렌더링

// 바람 설정
uniform float wind_strength : hint_range(0.0, 0.5) = 0.08;
uniform float wind_speed    : hint_range(0.0, 5.0)  = 1.5;
uniform vec2  wind_direction = vec2(1.0, 0.5);

// 색상 설정 (Waterfowl 팔레트)
uniform vec4 color_bottom : source_color = vec4(0.15, 0.35, 0.06, 1.0);
uniform vec4 color_top    : source_color = vec4(0.38, 0.60, 0.13, 1.0);
uniform float color_variation : hint_range(0.0, 0.3) = 0.1;

void vertex() {
    // UV.y = 0이 바닥, 1이 끝부분 → 위쪽일수록 많이 흔들림
    float height_factor = UV.y;

    // 바람 계산
    float wave = sin(TIME * wind_speed
                 + VERTEX.x * wind_direction.x
                 + VERTEX.z * wind_direction.y) * wind_strength;

    VERTEX.x += wave * height_factor;
    VERTEX.z += wave * 0.3 * height_factor;
}

void fragment() {
    // 아래→위 그라디언트 색상
    vec4 base_color = mix(color_bottom, color_top, UV.y);

    // INSTANCE_CUSTOM에서 색상 변화량 읽기
    float variation = (INSTANCE_CUSTOM.r - 0.5) * color_variation;
    base_color.rgb += vec3(variation);

    ALBEDO = base_color.rgb;
    ROUGHNESS = 0.9;
    SPECULAR = 0.05;
}
```

---

## 4단계 — LOD 최적화

```gdscript
# 거리에 따라 인스턴스 수 줄이기
func update_lod(camera_pos: Vector3):
    var dist = global_position.distance_to(camera_pos)

    if dist < 10.0:
        multimesh.visible_instance_count = grass_count        # 100%
    elif dist < 25.0:
        multimesh.visible_instance_count = grass_count / 2   # 50%
    elif dist < 50.0:
        multimesh.visible_instance_count = grass_count / 4   # 25%
    else:
        multimesh.visible_instance_count = 0                  # 숨김
```

> Godot 4.x에서는 `GeometryInstance3D`의 `lod_bias` 속성으로 자동 LOD도 활용할 수 있습니다.

---

## Waterfowl 스타일 핵심 포인트

### 색상 팔레트

```
바닥 어두운 초록:  #274D0F  (rgb 0.15, 0.30, 0.06)
중간 초록:         #3B6D11  (rgb 0.23, 0.43, 0.07)
끝부분 밝은 초록:  #639922  (rgb 0.39, 0.60, 0.13)
강조 포인트:       #97C459  (rgb 0.59, 0.77, 0.35)
```

### 탑다운 시점 배치 팁

- 카메라가 위에서 내려다보는 구도이므로 잔디를 **살짝 눕혀서** 배치합니다.
- Billboard 모드를 쓰지 않고 고정된 방향으로 배치해야 자연스럽습니다.
- 높이를 낮게(0.2~0.4 유닛) 유지하면 탑다운에서 알맞은 밀도감이 나옵니다.

### 작은 디테일 추가

```gdscript
# 잔디 사이에 작은 꽃이나 돌 추가 (확률적 스폰)
for i in grass_count:
    if randf() < 0.02:  # 2% 확률
        spawn_detail(mm.get_instance_transform(i).origin)
```

---

## 씬 구조 예시

```
World
├── GrassManager (Node3D + GDScript)
│   └── MultiMeshInstance3D
│       └── Material: grass.gdshader
├── Terrain (MeshInstance3D)
└── Camera3D
```

---

## 참고 리소스

- [Godot 공식 문서 — MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html)
- [Godot Shading Language 레퍼런스](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/index.html)
- [GDShader 튜토리얼 — Spatial](https://docs.godotengine.org/en/stable/tutorials/shaders/your_first_spatial_shader.html)

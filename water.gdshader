shader_type spatial;
render_mode specular_toon;

uniform vec3 albedo_color : source_color = vec3(0.15, 0.45, 0.75);
uniform vec3 deep_color : source_color = vec3(0.05, 0.25, 0.55);

uniform float metallic = 0.2;
uniform float roughness = 0.1;

// Gerstner Wave Properties
// Direction X, Direction Z, Steepness, Wavelength
uniform vec4 wave1 = vec4(1.0, 0.5, 0.2, 10.0);
uniform vec4 wave2 = vec4(-0.2, 0.7, 0.15, 6.0);
uniform vec4 wave3 = vec4(0.8, -0.6, 0.1, 4.0);

uniform float speed = 1.0;

vec3 gerstner_wave(vec4 wave, vec3 p, inout vec3 tangent, inout vec3 binormal) {
    float steepness = wave.z;
    float wavelength = wave.w;
    float k = 2.0 * PI / wavelength;
    float c = sqrt(9.8 / k);
    vec2 d = normalize(wave.xy);
    float f = k * (dot(d, p.xz) - c * TIME * speed);
    float a = steepness / k;
    
    // X, Z 방향의 수평 오프셋 (정점을 밀집시켜 날카로운 마루 생성)
    tangent += vec3(
        -d.x * d.x * (steepness * sin(f)),
        d.x * (steepness * cos(f)),
        -d.x * d.y * (steepness * sin(f))
    );
    binormal += vec3(
        -d.x * d.y * (steepness * sin(f)),
        d.y * (steepness * cos(f)),
        -d.y * d.y * (steepness * sin(f))
    );
    return vec3(
        d.x * (a * cos(f)),
        a * sin(f),
        d.y * (a * cos(f))
    );
}

// 간단한 의사 난수 생성 함수 (노이즈)
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
    vec3 grid_point = VERTEX;
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 binormal = vec3(0.0, 0.0, 1.0);
    vec3 p = grid_point;
    
    // 거스너 파동 중첩
    p += gerstner_wave(wave1, grid_point, tangent, binormal);
    p += gerstner_wave(wave2, grid_point, tangent, binormal);
    p += gerstner_wave(wave3, grid_point, tangent, binormal);
    
    // 바둑판 현상 완화를 위한 노이즈 기반 미세 변위
    float noise = random(grid_point.xz * 0.1) * 0.2;
    p.y += noise * sin(TIME * speed * 2.0);
    
    vec3 normal = normalize(cross(binormal, tangent));
    
    VERTEX = p;
    NORMAL = normal;
}

void fragment() {
    // 높이에 따른 수심 색상 보간 (깊을수록 짙은 파란색)
    float height_mix = smoothstep(-1.0, 1.0, VERTEX.y);
    vec3 final_color = mix(deep_color, albedo_color, height_mix);
    
    // 마루(Crest) 부근에 밝은 거품(Foam) 효과 살짝 추가
    if (VERTEX.y > 0.8) {
        final_color = mix(final_color, vec3(0.9, 0.95, 1.0), smoothstep(0.8, 1.5, VERTEX.y));
    }
    
    ALBEDO = final_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = 0.8; // 반사율을 높여 윤슬(빗반사) 효과 강조
    ALPHA = 0.9;
}

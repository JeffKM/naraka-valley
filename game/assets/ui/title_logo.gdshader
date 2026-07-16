shader_type canvas_item;
// 타이틀 로고 동적 붉은 효과(owner 2026-07-06) — 파란 여우불 대신 "붉은 기운이 글씨(먹 잉크)를
// 타고 흐르는" 런타임 효과. 정적 PNG(먹 나비 + 붓글씨)는 그대로 두고 셰이더로 붉은빛만 얹는다.
//
// 원리: 어두운 잉크 픽셀(글자·나비)일수록 ink=1 → 피안화 붉은빛을 가법 합성. 가로 스윕(sweep)과
//       느린 맥동(pulse)을 TIME으로 흘려 "흐르는" 느낌. TIME은 트리 일시정지 중에도 렌더가
//       돌려 계속 애니메이트된다(타이틀은 get_tree().paused 상태라 이게 중요).

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// 지각 밝기 — 어두울수록(글자·나비 잉크) 0에 가깝다.
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// 어두운 잉크일수록 1(밝은 크림 글로우·투명 여백은 0). 알파로 게이트.
	float ink = smoothstep(0.5, 0.06, lum) * tex.a;
	// 가로로 흐르는 스윕 + 전체 맥동.
	float sweep = 0.5 + 0.5 * sin(UV.x * 7.0 - TIME * 2.2);
	float pulse = 0.65 + 0.35 * sin(TIME * 1.3);
	float glow = ink * sweep * pulse;
	// 피안화 붉은빛(#c0403a 계열)을 가법으로 얹는다.
	vec3 red = vec3(0.80, 0.17, 0.15);
	COLOR = vec4(tex.rgb + red * glow, tex.a);
}

# 물↔흙(4_0) Wang 물가 스타듀식 단차 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 안식 물↔흙 경계(Wang pair `4_0`)를 손그림 원본 blit에서 base 픽셀 합성 + 스타듀식 수직 단차(흙↑·물↓ 웅덩이)로 승격한다.

**Architecture:** 기존 `_bake_field_wang` 일반 합성기를 재사용한다. 물↔흙은 표면 위계상 **흙=upper / 물=lower** 라, 이 베이커에 `up=_bf_earth, lo=_bf_water`를 넘기면 "흙 밑동→물 드롭섀도"(스타듀 겹②)가 자동으로 나온다. 여기에 **얕은물 밝은 림**(겹①) 파라미터를 베이커에 추가해 물 안쪽 가장자리를 밝게 한다. 렌더 ② 루프는 무수정 — 베이커가 `_wang_tiles[40]`을 덮어쓰면 기존 blit이 합성 타일을 그대로 쓴다(잔디↔흙과 동일 메커니즘). 순수 시각(`out` 픽셀만)·결정적(좌표해시)·`_grid`/충돌/세이브 불변.

**Tech Stack:** Godot 4 / GDScript. 헤드리스 단위검증(`playtest/*_test.gd` = `extends SceneTree`) + `game/run_tests.sh` 워치독 러너.

## Global Constraints

- **결정성:** 시드는 `_gd_h01(x,y,salt)` 좌표 해시만. `randi/randf`·`Math.random`류 **금지**(save.dat·회귀 오탐). 재빌드·재진입 동일 픽셀.
- **저작맵 불가침(ADR-0005/0015):** 순수 시각(`out` 픽셀). `_grid`·충돌·세이브·워프 불변. 물 통과 불가(SOLID) 물리 그대로.
- **범위 격리(접근 C):** 4_0 pair 타일만. **북단 강둑(`CLIFF_BANK`) pseudo-Z ledge·물 내부 텍스처·`_soften_field_edges`(밭·길) 무수정.**
- **하위호환:** `_bake_field_wang` 신규 파라미터는 기본 `0.0`/`0` → 잔디(`_bake_grass_dirt_wang`)·밭 경로 출력 픽셀 불변(회귀 0). 물 경로만 림 활성.
- **표면 매핑(불변):** `_SURF_RANK = {1:4, 0:3, 2:2, 3:1, 4:0}` = 잔디>흙>길>밭>물. surface id: 잔디1·흙0·길2·밭3·물4. `_wang_pair_key(lo,up)=lo*10+up`. 물↔흙 = `_wang_pair_key(4,0)=40`.
- **퍼포먼스:** 로드 시 1회 bake(16 코너키 × TILE²). 얕은물 림은 물 pair 1개 한정. per-pixel 밴드 전면 처리 금지(홈빌드 17s·bana_test 행 회피).
- **워크트리 격리:** 이미 격리 워크트리(`worktree-scatter-variation-adr0058`) 안. 첫 헤드리스 전 `.godot` 비었으면 `godot --headless --import` 1회.
- **회귀 스코프:** `./run_tests.sh scatter_variation building_grounding reclaim`(변경 계층만). bana_test 전체는 flaky 오탐 배제.

## 파일 구조

- **Modify** `game/main.gd`
  - `_W01_*` 상수 뒤(~:3660)에 `_W40_*` 상수 신설 + `_bake_water_dirt_wang()` 래퍼(Task 1·2)
  - `_bake_field_wang`(~:3729) 시그니처에 얕은물 림 파라미터 2개 추가 + 림 패스(~:3782 뒤)(Task 2)
  - `_build_ground16`(~:3790) `_bake_grass_dirt_wang()` 호출 뒤에 `_bake_water_dirt_wang()` 1줄(Task 1)
- **Modify** `game/playtest/scatter_variation_test.gd` — Task 4(물↔흙) 단언 누적(Task 1·2)

---

### Task 1: 물↔흙 base 합성 (드롭섀도 단차·림 없이)

물↔흙(4_0)을 손그림 blit에서 `_bake_field_wang` base 합성으로 승격한다. 흙(upper)/물(lower) base 픽셀로 합성 → 톤불일치 제거 + 흙 밑동 드롭섀도(단차 겹②). 얕은물 림은 Task 2.

**Files:**
- Modify: `game/main.gd` (`_bake_grass_dirt_wang` 뒤 ~:3663, `_build_ground16` ~:3790)
- Test: `game/playtest/scatter_variation_test.gd`

**Interfaces:**
- Consumes: `_bake_field_wang(pk, up_field, lo_field, rag, micro, edge_dark, shadow_depth, shadow_dark) -> void`(기존 8-arg), `_wang_pair_key(lo,up) -> int`, `_bf_earth: Image`, `_bf_water: Image`, `_wang_tiles: Dictionary`
- Produces: `_bake_water_dirt_wang() -> void`, 상수 `_W40_RAG/_W40_MICRO/_W40_EDGE_DARK/_W40_SHADOW/_W40_SHADOW_DARK`

- [ ] **Step 1: 실패하는 테스트 추가**

`game/playtest/scatter_variation_test.gd`의 `_initialize`에서 `print("결과...` 직전(line 56 앞)에 추가:

```gdscript
	# ── Task 4(Wang 물↔흙): base 합성 + 단차 ──
	var wkey: int = m._wang_pair_key(4, 0)   # = 40
	var wt: Dictionary = m._wang_tiles.get(wkey, {})
	_check("④ 물↔흙(40) 합성 타일 16 코너키 존재", wt.size() == 16)
	# all-upper(bits=15) 타일 중앙 = 흙 base(_bf_earth), all-lower(bits=0) = 물 base(_bf_water).
	var P: int = m._GF * 2
	var cc := int(m.TILE / 2)
	if wt.has(15) and wt.has(0):
		var earth_px: Color = (wt[15] as Image).get_pixel(cc, cc)
		var water_px: Color = (wt[0] as Image).get_pixel(cc, cc)
		_check("④ all-흙 코너 = _bf_earth 픽셀", earth_px.is_equal_approx(m._bf_earth.get_pixel(cc % P, cc % P)))
		_check("④ all-물 코너 = _bf_water 픽셀", water_px.is_equal_approx(m._bf_water.get_pixel(cc % P, cc % P)))
	else:
		_check("④ all-흙/all-물 코너키 존재", false)
	# 결정성: 재-bake 시 동일 픽셀(좌표해시 순수).
	m._bake_water_dirt_wang()
	var again: PackedByteArray = (m._wang_tiles[wkey][12] as Image).get_data()
	m._bake_water_dirt_wang()
	_check("④ 물↔흙 합성 결정적", again == (m._wang_tiles[wkey][12] as Image).get_data())
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd game && ./run_tests.sh scatter_variation`
Expected: FAIL — `_bake_water_dirt_wang` 미정의(런타임 에러) 또는 `④ 물↔흙(40) 합성 타일 16 코너키 존재` 실패(현재 40은 손그림이라 코너키는 있으나, 합성 검증 `④ all-흙 코너 = _bf_earth 픽셀`이 손그림≠base라 실패).

- [ ] **Step 3: `_W40_*` 상수 + `_bake_water_dirt_wang()` 래퍼 추가**

`game/main.gd`의 `_bake_grass_dirt_wang()` 함수 정의(~:3661-3663) 바로 뒤에 추가:

```gdscript
# ★[ADR-0058 확장·물가 단차·owner 2026-07-17] 물(4)↔흙(0) 전환 = 흙(upper)/물(lower) base 합성.
#   _bake_field_wang이 흙 밑동→물 남쪽 드롭섀도(겹②·"흙이 물 위로 솟음")를 만든다. 스타듀 물가처럼
#   "물이 흙보다 아래"인 웅덩이 단차. 손그림 Wang 4_0 덮음 → 톤불일치 불가. 얕은물 림(겹①)은 Task 2.
#   ⚠️ 접근 C: 북단 강둑(CLIFF_BANK) pseudo-Z는 무수정. 물가 rag는 잔디(0.20)보다 얌전(진흙 shore).
const _W40_RAG := 0.12         # 물가 경계 래그드 진폭
const _W40_MICRO := 0.08       # per-px 미세 지터
const _W40_EDGE_DARK := 0.14   # 흙 경계 1px 엣지다크(흙 밑동 정의)
const _W40_SHADOW := 5         # 흙 밑동 남쪽 물에 드리우는 드롭섀도 깊이(px) — 단차 겹②(잔디 4보다 깊게)
const _W40_SHADOW_DARK := 0.42 # 드롭섀도 최대 어둠
func _bake_water_dirt_wang() -> void:
	_bake_field_wang(_wang_pair_key(4, 0), _bf_earth, _bf_water, _W40_RAG, _W40_MICRO, _W40_EDGE_DARK, _W40_SHADOW, _W40_SHADOW_DARK)
```

- [ ] **Step 4: `_build_ground16`에서 호출**

`game/main.gd` `_build_ground16` 내 `_bake_grass_dirt_wang()` 호출(line 3790) 바로 다음 줄에 추가:

```gdscript
	_bake_grass_dirt_wang()   # ★[ADR-0058 확장] 잔디↔흙 전환을 base에서 합성(불일치-불가) — 손그림 Wang 0_1 덮음
	_bake_water_dirt_wang()   # ★[ADR-0058 확장] 물↔흙 단차 base 합성 — 손그림 Wang 4_0 덮음(스타듀 웅덩이)
```

- [ ] **Step 5: 테스트 통과 + 회귀 확인**

Run: `cd game && ./run_tests.sh scatter_variation building_grounding reclaim`
Expected: 3개 모두 PASS(`scatter_variation` = 0 실패; `building_grounding`·`reclaim` 회귀 0 — 물↔흙 픽셀만 변화, grid/충돌/접지 불변).

- [ ] **Step 6: 커밋**

```bash
git add game/main.gd game/playtest/scatter_variation_test.gd
git commit -m "🎨 feat(terrain): 물↔흙(4_0) base 합성 + 흙 밑동 드롭섀도 단차 (ADR-0058 확장)"
```

---

### Task 2: 얕은물 밝은 림 (스타듀 겹①)

`_bake_field_wang`에 얕은물 림 파라미터 2개를 추가하고(기본 0 → 잔디·밭 무영향), 물↔흙 래퍼에서 활성화한다. lower(물) 픽셀이 upper(흙)에 가까울수록 밝게 → 스타듀 물가 하이라이트.

**Files:**
- Modify: `game/main.gd` (`_bake_field_wang` ~:3729 시그니처·~:3782 뒤 림 패스, `_W40_*` 상수·`_bake_water_dirt_wang` 인자)
- Test: `game/playtest/scatter_variation_test.gd`

**Interfaces:**
- Consumes: `_bake_field_wang` 기존 본문(`umask`, `img`, `TILE` 스코프)
- Produces: `_bake_field_wang(..., rim_light: float = 0.0, rim_px: int = 0) -> void`(10-arg 확장), 상수 `_W40_RIM/_W40_RIM_PX`

- [ ] **Step 1: 실패하는 테스트 추가**

`game/playtest/scatter_variation_test.gd`의 `_initialize`에서 Task 1이 추가한 블록 뒤(여전히 `print("결과...` 직전)에 추가:

```gdscript
	# ── Task 4(림): 얕은물 밝은 림이 물 픽셀을 밝힌다(rim on > rim off) ──
	const _TMPK := 987654   # 실제 _wang_tiles[40] 불침범용 임시 키
	m._bake_field_wang(_TMPK, m._bf_earth, m._bf_water, m._W40_RAG, m._W40_MICRO, m._W40_EDGE_DARK, m._W40_SHADOW, m._W40_SHADOW_DARK, 0.0, 0)
	var lum_off := _tile_luma(m._wang_tiles[_TMPK][1] as Image)   # bits=1: NW만 흙, 나머지 물(경계 존재)
	m._bake_field_wang(_TMPK, m._bf_earth, m._bf_water, m._W40_RAG, m._W40_MICRO, m._W40_EDGE_DARK, m._W40_SHADOW, m._W40_SHADOW_DARK, 0.30, 2)
	var lum_on := _tile_luma(m._wang_tiles[_TMPK][1] as Image)
	_check("④ 얕은물 림 활성 시 물 픽셀 더 밝음(rim on > off)", lum_on > lum_off)
	m._wang_tiles.erase(_TMPK)
	# 하위호환: 잔디↔흙(0_1) 재-bake는 rim 기본 0이라 결정적·불변(회귀 0 방증).
	var g_before: PackedByteArray = (m._wang_tiles[m._wang_pair_key(0,1)][12] as Image).get_data()
	m._bake_grass_dirt_wang()
	_check("④ 잔디↔흙 rim 무영향(재-bake 동일)", g_before == (m._wang_tiles[m._wang_pair_key(0,1)][12] as Image).get_data())
```

그리고 파일 하단(`_neighbor_corr` 뒤, line 102 이후)에 헬퍼 추가:

```gdscript
func _tile_luma(img: Image) -> float:
	var s := 0.0
	for j in img.get_height():
		for i in img.get_width():
			var c := img.get_pixel(i, j)
			s += (c.r + c.g + c.b) * c.a
	return s
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd game && ./run_tests.sh scatter_variation`
Expected: FAIL — `_bake_field_wang`이 아직 8-arg라 10-arg 호출이 "Too many arguments" 파싱/런타임 에러.

- [ ] **Step 3: `_bake_field_wang` 시그니처 확장 + 림 패스 추가**

`game/main.gd` `_bake_field_wang` 시그니처(line 3729)를 교체:

```gdscript
func _bake_field_wang(pk: int, up_field: Image, lo_field: Image, rag: float, micro: float, edge_dark: float, shadow_depth: int, shadow_dark: float, rim_light: float = 0.0, rim_px: int = 0) -> void:
```

그리고 드롭섀도 패스(line 3772-3782)와 `tmap[bits] = img`(line 3783) **사이**에 얕은물 림 패스 삽입:

```gdscript
		# ★[물가 얕은물 림·ADR-0058] lower(물) 픽셀이 upper(흙) 경계에서 rim_px 안쪽일수록 밝게 = 스타듀 겹①.
		#   밑동 가까울수록 강하게(선형 감쇄). 기본 rim_light=0 → 잔디·밭 호출 무영향(하위호환).
		if rim_light > 0.0 and rim_px > 0:
			for i in TILE:
				for j in TILE:
					if bool(umask[j][i]):
						continue   # lower(물) 픽셀만
					var dist := rim_px + 1
					for kk in range(1, rim_px + 1):
						var found := false
						for d: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]:
							var ni := i + d.x * kk
							var nj := j + d.y * kk
							if ni >= 0 and nj >= 0 and ni < TILE and nj < TILE and bool(umask[nj][ni]):
								found = true
								break
						if found:
							dist = kk
							break
					if dist <= rim_px:
						var amt: float = rim_light * (1.0 - float(dist - 1) / float(rim_px))
						img.set_pixel(i, j, img.get_pixel(i, j).lightened(amt))
		tmap[bits] = img
```

> ⚠️ 기존 `tmap[bits] = img`(line 3783)를 위 블록 **말미의 것으로 대체**한다(중복 금지 — 림 패스 뒤 1회만).

- [ ] **Step 4: `_W40_*` 림 상수 추가 + 래퍼 인자 확장**

`game/main.gd`의 `_W40_SHADOW_DARK` 상수 뒤(Task 1에서 추가한 블록)에 2줄 추가:

```gdscript
const _W40_SHADOW_DARK := 0.42 # 드롭섀도 최대 어둠
const _W40_RIM := 0.30         # ★얕은물 밝은 림 강도(lightened·겹①)
const _W40_RIM_PX := 2         # ★얕은물 림 폭(px, 물 안쪽)
```

`_bake_water_dirt_wang()` 본문의 `_bake_field_wang(...)` 호출을 림 인자 포함으로 교체:

```gdscript
func _bake_water_dirt_wang() -> void:
	_bake_field_wang(_wang_pair_key(4, 0), _bf_earth, _bf_water, _W40_RAG, _W40_MICRO, _W40_EDGE_DARK, _W40_SHADOW, _W40_SHADOW_DARK, _W40_RIM, _W40_RIM_PX)
```

- [ ] **Step 5: 테스트 통과 + 회귀 + 육안**

Run: `cd game && ./run_tests.sh scatter_variation building_grounding reclaim`
Expected: 3개 모두 PASS.

육안(선택): `home_full_dump` 하네스가 있으면 안식 연못 3면 before/after 대조. ★owner 라이브 톤 확인은 별도 세션(레버 `_W40_*` 조정).

- [ ] **Step 6: 커밋**

```bash
git add game/main.gd game/playtest/scatter_variation_test.gd
git commit -m "🎨 feat(terrain): 물↔흙 얕은물 밝은 림 (스타듀 물가 겹①·ADR-0058 확장)"
```

---

## Self-Review

**Spec coverage:**
- 구현 ① `_bake_field_wang` 림 파라미터 2개 → Task 2 Step 3·4 ✅
- 구현 ② `_bake_water_dirt_wang()` 래퍼 → Task 1 Step 3 ✅
- 구현 ③ `_build_ground16` 호출 → Task 1 Step 4 ✅
- 렌더 ② 루프 무수정 → 계획에 수정 태스크 없음(의도) ✅
- 레버 7상수(`_W40_*`) → Task 1(드롭섀도 5개) + Task 2(림 2개) ✅
- 불변식(결정성·저작불가침·강둑 무수정·하위호환·퍼프) → Global Constraints + 각 Task 회귀 스텝 ✅
- 테스트(결정성·림 실효·하위호환·회귀) → Task 1 Step 1(결정성·base) + Task 2 Step 1(림·하위호환) + 각 Step 5(회귀) ✅

**Placeholder scan:** 코드 스텝 전부 실제 GDScript·실제 명령·기대 출력 명시. "적절히 처리"류 없음. ✅

**Type consistency:** `_bake_water_dirt_wang()`(Task 1 정의·Task 2 인자 교체)·`_bake_field_wang(...,rim_light,rim_px)`(Task 2 확장)·`_wang_pair_key(4,0)=40`·상수 `_W40_RAG/MICRO/EDGE_DARK/SHADOW/SHADOW_DARK`(Task 1)·`_W40_RIM/RIM_PX`(Task 2)·테스트 헬퍼 `_tile_luma`(Task 2)·`_bf_earth/_bf_water`(기존)·`_GF`/`TILE`/`P`(기존) — 정의·참조 일관. ✅

**주의(실행자):** Task 1은 `_bake_field_wang`을 기존 8-arg로 호출(림 없음). Task 2에서 시그니처를 10-arg로 확장하고 래퍼 호출을 림 포함으로 교체한다(순서 준수). Task 2 Step 3의 `tmap[bits] = img`는 기존 line 3783을 **대체**(중복 금지).

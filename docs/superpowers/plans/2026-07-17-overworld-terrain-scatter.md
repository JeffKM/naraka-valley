# 지상 지형 변주(스타듀-정통 스캐터) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 안식 농원 지상 지형의 clutter 스캐터를 구역-키드 가중 테이블 + 풀무리 이웃-확산으로 풍성화한다(ADR-0058).

**Architecture:** 기존 `_g16_blend_scatter`(단일 draw call 스캐터 데칼) 위 증분. ⓐ전역 `_GD_TABLES`/`_GD_SPARSE`를 구역-키드 조회로 감싸(폴백=전역·회귀0) 안식 테이블을 풀무리↑로 튜닝, ⓑ풀무리 판정을 저주파 노이즈에서 CA 이웃-확산 마스크로 승격(스타듀 풀 확산 본뜸). 순수 시각·결정적·저작맵 불가침.

**Tech Stack:** Godot 4 / GDScript. 헤드리스 단위검증(`playtest/*_test.gd` = `extends SceneTree`) + `game/run_tests.sh` 워치독 러너.

## Global Constraints

- **결정성:** 시드는 `_gd_h01(x,y,salt)` 좌표 해시만. `randi/randf`·`Math.random`류 **금지**(save.dat·회귀 오탐). 동일 구역+좌표 → 매 로드 동일 픽셀.
- **저작맵 불가침(ADR-0005/0015):** 스캐터는 GROUND/PATH 빈 셀만. 건물·프롭·밭·절벽·물·워프·구역 가장자리 불침범. `_g16_blend_scatter`의 `occupied` 회피·`_GD_TABLES.has(terrain)` 게이트 유지.
- **흙-지배 base 유지(ADR-0053):** "풀무리 증가"=스캐터 tuft 데칼 밀도·가중↑이지 **base 잔디패치 부활 아님**. `_G16_GRASS_PATCHES=false` 불변.
- **퍼포먼스:** 로드 시 `_ground_detail_tex`로 1회 bake. 신규 패스는 **셀 단위·2패스 상한**(per-pixel 밴드 처리 금지 — 홈빌드 17s·bana_test 행 회피).
- **재점령 공존(ADR-0055):** 본 작업=정적 base 스캐터. 재점령 잡초(`_draw_encroach_weeds`) 동적 레이어 불간섭.
- **회귀 스코프:** `./run_tests.sh building_grounding reclaim`(변경 계층만). bana_test 전체는 flaky 오탐 배제.
- **워크트리 격리:** 구현 착수 전 `EnterWorktree`(CLAUDE.md 규칙 — save.dat 경합). 새 워크트리는 첫 헤드리스 전 `godot --headless --import` 1회.

## 파일 구조

- **Modify** `game/main.gd`
  - `_GD_TABLES`(~:430)·`_GD_SPARSE`(~:458) 인근에 구역-키드 딕셔너리·조회 헬퍼 신설(Task 1·2)
  - `_g16_blend_scatter`(~:3714) 테이블 조회 지점 3곳 교체(Task 1) + 풀무리 게이트 교체(Task 3)
  - `_build_ground16`(~:3542) 스캐터 직전 풀무리 마스크 계산 1회 추가(Task 3)
  - `_g16_cluster_cleanup`(~:3806) CA 로직 재활용(Task 3)
- **Create** `game/playtest/scatter_variation_test.gd` — 본 작업 단위검증(Task 1~3 누적)
- **Create** `docs/design/terrain-scatter-variant-roster.md` — 변종 아트 로스터·스펙카드(Task 4·병렬 아트트랙 입력)

---

### Task 1: 구역-키드 스캐터 조회 (행위 보존 리팩터·폴백=전역)

전역 테이블을 구역-키드 조회로 감싼다. 구역 오버라이드가 비어 있으면 전역으로 폴백 → 스캐터 출력 픽셀 동일(회귀 0).

**Files:**
- Modify: `game/main.gd` (`_GD_SPARSE` 바로 뒤 ~:466, `_g16_blend_scatter` ~:3730-3740)
- Test: `game/playtest/scatter_variation_test.gd`

**Interfaces:**
- Produces: `_gd_table_for(terrain: int) -> Array`, `_gd_sparse_for() -> Array`, `var _REGION_GD_TABLES: Dictionary`, `var _REGION_GD_SPARSE: Dictionary`

- [ ] **Step 1: 실패하는 테스트 작성**

`game/playtest/scatter_variation_test.gd` 생성:

```gdscript
extends SceneTree
# [ADR-0058] 지상 스캐터 변주 — 구역-키드 테이블 + 풀무리 이웃-확산 단위검증.
# 순수 시각(_ground_detail_tex bake)·결정적·저작맵 불가침. 좀비 방지: 끝에서 quit().

var _fail := 0
func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok: _fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("══ 지상 스캐터 변주(ADR-0058) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m: Node = await _spawn_main()
	_check("⓪ 부팅 = 안식 농원(HOME)", m._region == RegionCatalog.HOME)

	# ── Task 1: 구역-키드 조회 + 전역 폴백 ──
	_check("① 미지 구역은 전역 GROUND 테이블로 폴백", _same_table(
		m._call_table_for(m, "nonexistent_region", m.GROUND), m._GD_TABLES[m.GROUND]))
	_check("① 미지 구역 sparse도 전역 폴백", _same_table(
		m._call_sparse_for(m, "nonexistent_region"), m._GD_SPARSE))

	print("결과: %d 실패" % _fail)
	quit(1 if _fail > 0 else 0)

func _same_table(a: Array, b: Array) -> bool:
	return a.size() == b.size() and (a.is_empty() or a[0][1] == b[0][1])

# 테스트가 구역을 강제로 바꿔 조회를 검증하기 위한 래퍼(구현이 _region을 읽으므로 임시 세팅).
func _call_table_for(m: Node, region: String, terrain: int) -> Array:
	var saved = m._region
	m._region = region
	var r: Array = m._gd_table_for(terrain)
	m._region = saved
	return r

func _call_sparse_for(m: Node, region: String) -> Array:
	var saved = m._region
	m._region = region
	var r: Array = m._gd_sparse_for()
	m._region = saved
	return r
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd game && ./run_tests.sh scatter_variation`
Expected: FAIL — `_gd_table_for` 미정의(파싱/런타임 에러).

- [ ] **Step 3: 최소 구현 — 구역-키드 딕셔너리 + 조회 헬퍼**

`game/main.gd`의 `_GD_SPARSE_DENSITY` 상수(~:466) 바로 뒤에 추가:

```gdscript
# ★[ADR-0058] 구역-키드 스캐터 테이블 — 각 구역 고유 clutter 정체성(심심함 최대 레버).
#   비면 전역 _GD_TABLES/_GD_SPARSE 폴백(회귀 0). 구역이 지어질 때 자기 엔트리를 채운다.
#   구조: { region_id: { GROUND:[[tex,weight,shadow]...], PATH:[...] } }. Task 2에서 home 채움.
var _REGION_GD_TABLES := {}
var _REGION_GD_SPARSE := {}

# 현재 구역(_region)의 terrain 스캐터 테이블 — 구역 오버라이드 → 전역 폴백.
func _gd_table_for(terrain: int) -> Array:
	var rt: Dictionary = _REGION_GD_TABLES.get(_region, {})
	if rt.has(terrain):
		return rt[terrain]
	return _GD_TABLES.get(terrain, [])

func _gd_sparse_for() -> Array:
	return _REGION_GD_SPARSE.get(_region, _GD_SPARSE)
```

- [ ] **Step 4: `_g16_blend_scatter` 조회 지점 3곳 교체**

`game/main.gd` `_g16_blend_scatter` 내부(~:3734-3740) 3줄 교체:

```gdscript
			# (GROUND 클러스터 분기)
				if _scatter_is_clump(x, y):            # Task 3에서 이 헬퍼로 교체 예정 — 지금은 다음 줄 유지
					table = _gd_table_for(GROUND)      # 구 _GD_TABLES[GROUND]
				elif _gd_h01(x, y, 71) < _GD_SPARSE_DENSITY:
					table = _gd_sparse_for()           # 구 _GD_SPARSE
				else:
					continue
			else:
				table = _gd_table_for(terrain)         # 구 _GD_TABLES[terrain]
```

> ⚠️ **주의:** 이 Task에서는 `_scatter_is_clump(x,y)` 대신 **기존 `_gd_cluster(x, y) >= GD_CLUSTER_CUT` 그대로 둔다**(Task 3에서 교체). 위 블록에서 첫 줄만 `if _gd_cluster(x, y) >= GD_CLUSTER_CUT:`로 두고, `table =` 3곳만 헬퍼로 바꾼다.

정확히 이 Task의 diff(첫 줄 불변):

```gdscript
				if _gd_cluster(x, y) >= GD_CLUSTER_CUT:
					table = _gd_table_for(GROUND)
				elif _gd_h01(x, y, 71) < _GD_SPARSE_DENSITY:
					table = _gd_sparse_for()
				else:
					continue
			else:
				table = _gd_table_for(terrain)
```

- [ ] **Step 5: 테스트 통과 + 회귀 확인**

Run: `cd game && ./run_tests.sh scatter_variation building_grounding reclaim`
Expected: 3개 모두 PASS(`scatter_variation` = 0 실패; `building_grounding`·`reclaim` 회귀 0 — 폴백이라 스캐터 출력 불변).

- [ ] **Step 6: 커밋**

```bash
git add game/main.gd game/playtest/scatter_variation_test.gd
git commit -m "🎨 feat(scatter): 구역-키드 스캐터 조회 도입 (ADR-0058, 폴백=전역·회귀0)"
```

---

### Task 2: 안식 테이블 = 풀무리 증가

안식(HOME) GROUND 테이블을 구역 오버라이드로 채워 풀 tuft 가중을 올린다(맨 잔디 여백↓). base는 tan 유지(스캐터 데칼만 변화).

**Files:**
- Modify: `game/main.gd` (`_REGION_GD_TABLES` 초기값)
- Test: `game/playtest/scatter_variation_test.gd`

**Interfaces:**
- Consumes: `_gd_table_for(terrain)`, `_REGION_GD_TABLES`, `RegionCatalog.HOME`, `GD_GRASS1/2`, `GD_WEED_U/D`, `GD_FLOWER`, `GD_PEBBLE`, `GD_TWIG1/2`, `GD_STONE1/2`

- [ ] **Step 1: 실패하는 테스트 추가**

`scatter_variation_test.gd`의 `_initialize`에서 `print("결과...` 직전에 추가:

```gdscript
	# ── Task 2: 안식 테이블 = 풀무리 ↑ ──
	var home_ground: Array = m._REGION_GD_TABLES.get(RegionCatalog.HOME, {}).get(m.GROUND, [])
	_check("② 안식 GROUND 오버라이드 존재", not home_ground.is_empty())
	# 풀 tuft(GD_GRASS1) 가중이 전역(30)보다 높다.
	var home_grass_w := _weight_of(home_ground, m.GD_GRASS1)
	var glob_grass_w := _weight_of(m._GD_TABLES[m.GROUND], m.GD_GRASS1)
	_check("② 안식 풀 tuft 가중 > 전역", home_grass_w > glob_grass_w)
	# 맨 잔디 여백(null)이 전역(44)보다 낮다 → 풀무리 체감↑.
	_check("② 안식 맨 여백(null) 가중 < 전역", _weight_of(home_ground, null) < _weight_of(m._GD_TABLES[m.GROUND], null))
```

그리고 파일 하단에 헬퍼 추가:

```gdscript
func _weight_of(table: Array, tex: Variant) -> int:
	for e in table:
		if e[0] == tex:
			return int(e[1])
	return 0
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd game && ./run_tests.sh scatter_variation`
Expected: FAIL — "② 안식 GROUND 오버라이드 존재" 실패(아직 `{}`).

- [ ] **Step 3: 안식 테이블 채우기**

`game/main.gd`의 `var _REGION_GD_TABLES := {}`를 교체:

```gdscript
var _REGION_GD_TABLES := {
	# ★[ADR-0058] 안식 농원 = 풀무리 증가(owner 2026-07-17). 전역 대비 GD_GRASS 가중↑·맨 여백↓.
	#   ⚠️ base는 tan-지배 유지(ADR-0053) — 이건 스캐터 tuft 데칼 밀도이지 잔디패치 아님.
	RegionCatalog.HOME: {
		GROUND: [
			[null, 34, false],       # 맨 잔디 여백 44→34(풀무리 체감↑)
			[GD_GRASS1, 38, false],  # 짧은 풀포기 주력 30→38
			[GD_GRASS2, 9, false],   # 중간 풀포기 5→9
			[GD_WEED_U, 4, false],
			[GD_WEED_D, 3, true],
			[GD_FLOWER, 2, true],
			[GD_PEBBLE, 1, true],
			[GD_TWIG1, 4, false],
			[GD_TWIG2, 3, false],
			[GD_STONE1, 4, true],
			[GD_STONE2, 3, true],
		],
		# PATH는 전역 폴백(오버라이드 없음).
	},
}
```

- [ ] **Step 4: 테스트 통과 + 회귀**

Run: `cd game && ./run_tests.sh scatter_variation building_grounding reclaim`
Expected: 모두 PASS(building_grounding·reclaim = 안식 스캐터 톤만 변화, grid/충돌/접지 불변).

- [ ] **Step 5: 커밋**

```bash
git add game/main.gd game/playtest/scatter_variation_test.gd
git commit -m "🎨 feat(scatter): 안식 GROUND 테이블 풀무리 증가 (ADR-0058 owner 확정)"
```

---

### Task 3: 풀무리 CA 이웃-확산 마스크 (유일한 정당 인접 메커닉)

풀무리 판정을 저주파 노이즈(`_gd_cluster >= cut`) 단독에서 **seed + CA 이웃-확산**으로 승격 — 스타듀 풀 확산(만개 풀이 흙 이웃으로 번짐)을 본떠 유기적 clump. 기존 `_g16_cluster_cleanup` CA 로직 재활용. 구역별 cut 오버라이드로 안식 clump 면적↑.

**Files:**
- Modify: `game/main.gd` (`_build_ground16` 스캐터 직전 마스크 계산·`_g16_blend_scatter` 게이트·구역 cut 딕셔너리)
- Test: `game/playtest/scatter_variation_test.gd`

**Interfaces:**
- Produces: `_compute_scatter_clump() -> void`, `var _scatter_clump: Array` ([y][x] int 0/1), `_scatter_is_clump(x:int,y:int) -> bool`, `var _REGION_CLUSTER_CUT: Dictionary`

- [ ] **Step 1: 실패하는 테스트 추가**

`scatter_variation_test.gd`의 `_initialize` `print("결과...` 직전에 추가:

```gdscript
	# ── Task 3: 풀무리 CA 이웃-확산 마스크 ──
	m._compute_scatter_clump()
	var first: Array = m._scatter_clump.duplicate(true)
	m._compute_scatter_clump()
	_check("③ 마스크 결정적(재계산 동일)", str(first) == str(m._scatter_clump))
	# 비-GROUND 셀은 clump=0(저작 셀 불침범).
	var bad := false
	for yy in m._outdoor_h:
		for xx in m._grid_w:
			if m._grid[yy][xx] != m.GROUND and m._scatter_clump[yy][xx] == 1:
				bad = true
	_check("③ 비-GROUND 셀은 clump 아님", not bad)
	# 이웃-상관: clump 셀의 직교이웃이 clump일 확률 > 전역 clump 비율(유기적 응집).
	_check("③ clump 이웃-상관 > 전역비율", _neighbor_corr(m) > _global_rate(m))
```

파일 하단에 헬퍼 추가:

```gdscript
func _global_rate(m: Node) -> float:
	var g := 0; var tot := 0
	for yy in m._outdoor_h:
		for xx in m._grid_w:
			if m._grid[yy][xx] == m.GROUND:
				tot += 1
				if m._scatter_clump[yy][xx] == 1: g += 1
	return float(g) / max(1, tot)

func _neighbor_corr(m: Node) -> float:
	var hit := 0; var tot := 0
	for yy in m._outdoor_h:
		for xx in m._grid_w:
			if m._grid[yy][xx] == m.GROUND and m._scatter_clump[yy][xx] == 1:
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx = xx + d.x; var ny = yy + d.y
					if nx >= 0 and nx < m._grid_w and ny >= 0 and ny < m._outdoor_h and m._grid[ny][nx] == m.GROUND:
						tot += 1
						if m._scatter_clump[ny][nx] == 1: hit += 1
	return float(hit) / max(1, tot)
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd game && ./run_tests.sh scatter_variation`
Expected: FAIL — `_compute_scatter_clump` 미정의.

- [ ] **Step 3: 마스크 계산 + 구역 cut 딕셔너리 구현**

`game/main.gd`의 `_gd_sparse_for()` 뒤에 추가:

```gdscript
# ★[ADR-0058 B] 구역별 풀무리 문턱(↓=clump 면적↑). 안식은 풀무리↑라 전역보다 낮춘다.
var _REGION_CLUSTER_CUT := { RegionCatalog.HOME: 0.52 }   # 전역 GD_CLUSTER_CUT=0.60

# 풀무리 마스크 — 저주파 seed + CA 이웃-확산(스타듀 풀 확산 본뜸). 결정적·셀단위·2패스 상한.
#   _gd_cluster로 seed(GROUND만) → 이웃≥5 성장·<2 사멸 2패스 → 유기적 clump. _g16_cluster_cleanup 계보.
var _scatter_clump: Array = []

func _compute_scatter_clump() -> void:
	var W := _grid_w
	var H := _outdoor_h
	var cut: float = _REGION_CLUSTER_CUT.get(_region, GD_CLUSTER_CUT)
	var mask := []
	for y in H:
		var row := []
		for x in W:
			row.append(1 if (_grid[y][x] == GROUND and _gd_cluster(x, y) >= cut) else 0)
		mask.append(row)
	for _p in 2:
		var snap: Array = mask.duplicate(true)
		for y in H:
			for x in W:
				if _grid[y][x] != GROUND:
					mask[y][x] = 0
					continue
				var gn := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and nx < W and ny >= 0 and ny < H and snap[ny][nx] == 1:
							gn += 1
				if snap[y][x] == 1 and gn < 2:
					mask[y][x] = 0
				elif snap[y][x] == 0 and gn >= 5:
					mask[y][x] = 1
	_scatter_clump = mask

func _scatter_is_clump(x: int, y: int) -> bool:
	if _scatter_clump.is_empty():
		return _gd_cluster(x, y) >= _REGION_CLUSTER_CUT.get(_region, GD_CLUSTER_CUT)  # 안전 폴백
	return _scatter_clump[y][x] == 1
```

- [ ] **Step 4: `_build_ground16`에서 스캐터 직전 마스크 계산**

`game/main.gd` `_build_ground16` 내 `if _G16_SCATTER:` 직전(~:3706)에 추가:

```gdscript
	if _G16_SCATTER:
		_compute_scatter_clump()   # ★[ADR-0058 B] 풀무리 CA 마스크 1회 계산(스캐터가 참조)
		_g16_blend_scatter(out)
```

- [ ] **Step 5: `_g16_blend_scatter` 게이트를 마스크로 교체**

`game/main.gd` `_g16_blend_scatter`의 GROUND 분기 첫 줄(Task 1에서 유지했던) 교체:

```gdscript
				if _scatter_is_clump(x, y):          # 구 _gd_cluster(x,y) >= GD_CLUSTER_CUT
					table = _gd_table_for(GROUND)
```

- [ ] **Step 6: 테스트 통과 + 회귀 + 육안**

Run: `cd game && ./run_tests.sh scatter_variation building_grounding reclaim`
Expected: 모두 PASS.

육안(선택): `godot --headless --path . --script res://tools/map_dump.gd`(있으면)로 안식 before/after 대조. ★owner 라이브 톤 확인은 별도 세션.

- [ ] **Step 7: 커밋**

```bash
git add game/main.gd game/playtest/scatter_variation_test.gd
git commit -m "🎨 feat(scatter): 풀무리 CA 이웃-확산 마스크 (ADR-0058 B·유기적 clump)"
```

---

### Task 4: 변종 아트 로스터·스펙카드 (병렬 아트트랙 입력)

코드 트랙 산출물 = 변종 로스터 문서. 아트 생산 자체는 owner-Gemini/PixelLab 병렬(비차단). 우선순위: 풀 tuft → 잡초 → twig/stone.

**Files:**
- Create: `docs/design/terrain-scatter-variant-roster.md`

- [ ] **Step 1: 로스터 문서 작성**

`docs/design/terrain-scatter-variant-roster.md` 생성 — 각 항목에 카테고리·현재 변종 수·목표 추가 수·용도·[ADR-0025] 스펙카드(크기 32-native·톤·프롬프트 방향·배치). 우선순위 표:

```markdown
# 지형 스캐터 변종 로스터 (ADR-0058 C·ADR-0025 스펙카드)

> 병렬 아트트랙(owner 페이스). 코드 트랙(Task 1~3)은 변종 슬롯을 데이터로 이미 열어둠 —
> 신규 변종 PNG는 `_REGION_GD_TABLES` 엔트리 추가 + 재빌드만으로 자동 반영(엔진 변경 0).

| 우선 | 카테고리 | 현재 | 목표+ | 근거(taxonomy 레버) |
|---|---|---|---|---|
| 1 | 풀 tuft | GD_GRASS1~3 | +2~3 | 레버 #4 — 스타듀 풀=4 tuft 하위구성, 변종이 반복 은폐 |
| 2 | 잡초 | GD_WEED_U/D | +2 | base + special + large 다종 |
| 3 | twig/stone | GD_TWIG1/2·STONE1/2 | +1~2 | 개활지 clutter 다양화 |

각 스펙카드: 32-native·NW광원·flat(풀 tuft는 그림자 없음)·마스터 팔레트 remap(ADR-0057)·
저승 톤(muted somber). 프롬프트는 docs/design/gemini-regen-batch.md §스캐터 참조.
```

- [ ] **Step 2: 커밋**

```bash
git add docs/design/terrain-scatter-variant-roster.md
git commit -m "📝 docs(scatter): 변종 아트 로스터·스펙카드 (ADR-0058 C 병렬 트랙)"
```

---

## Self-Review

**Spec coverage:**
- §2.A 구역-키드 테이블 → Task 1(구조·폴백) + Task 2(안식 튜닝) ✅
- §2.B 풀 이웃-확산 CA → Task 3 ✅
- §2.C 변종 확대 로스터 → Task 4 ✅
- §3 스코프 아웃(계절=S7·던전=S5) → 계획에 미포함(의도) ✅
- §4 불변식(결정성·저작불가침·흙지배·퍼프·재점령·회귀) → Global Constraints + 각 Task 회귀 스텝 ✅
- §7 owner 결정(풀무리↑·안식만 실테이블·우선순위) → Task 2·3·4에 반영 ✅

**Placeholder scan:** 코드 스텝 전부 실제 GDScript·실제 명령·기대 출력 명시. "적절히 처리"류 없음. ✅

**Type consistency:** `_gd_table_for(terrain)`·`_gd_sparse_for()`·`_compute_scatter_clump()`·`_scatter_is_clump(x,y)`·`_scatter_clump`·`_REGION_GD_TABLES`·`_REGION_GD_SPARSE`·`_REGION_CLUSTER_CUT` — Task 1·3에서 정의, 이후 참조 일관. Task 1 Step 4의 `_scatter_is_clump` 언급은 Step 5 주의문에서 "Task 3까지 `_gd_cluster` 유지"로 명시 정정. ✅

**주의(실행자):** Task 1은 GROUND 분기 첫 줄을 `_gd_cluster(x,y) >= GD_CLUSTER_CUT` 그대로 두고 `table=` 3곳만 교체. Task 3 Step 5에서 그 첫 줄을 `_scatter_is_clump(x,y)`로 교체한다(순서 준수).

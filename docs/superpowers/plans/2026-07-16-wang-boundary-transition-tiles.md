# Wang 경계 전환 타일 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 안식 농원(HOME) 지면 오버레이의 per-pixel 랜덤 지터 경계를 PixelLab 손그림 Wang 16타일 전환(오버행)으로 교체한다.

**Architecture:** `_build_ground16()`의 ②경계 지터 블록(main.gd 3454~3493)만 Wang 전환 blit으로 교체하는 접근 A(순수 시각 오버레이). 각 셀의 4코너 꼭짓점 표면(인접 4셀 위계 최대)으로 4비트 코너키를 만들어, 위계 상위 2표면 쌍의 전환 tileset에서 매칭 타일을 blit한다. `_grid`·충돌·세이브·TileMap terrain은 불변.

**Tech Stack:** Godot 4 / GDScript(헤드리스 SceneTree 테스트), PixelLab MCP `create_topdown_tileset`, Python(PIL) 슬라이스 글루.

## Global Constraints

- **순수 시각 오버레이만.** `_grid`·충돌 WALL·`user://save.dat`·`ground` TileMap terrain 구조 전부 불변. `_ground_detail_tex` 픽셀만 바뀐다.
- **오버행 위계 = 잔디 > 흙 > 길 > 밭 > 물.** 경계에서 위계 높은 쪽이 upper(볼록). surf값 매핑: 잔디=1, 흙=0, 길=2, 밭=3, 물=4.
- **회귀는 선별 실행.** `game/run_tests.sh building_grounding reclaim`만. 전체 실행 금지(bana_test flaky 오탐).
- **워크트리 격리.** Task 2 이후 코드·에셋 수정은 `EnterWorktree`로 격리 워크트리에서. 새 워크트리는 첫 헤드리스 실행 전 `godot --headless --import` 1회.
- **새 PNG는 재임포트 필요.** 에셋 추가/변경 후 `godot --headless --import`(run_game.sh가 실행 전 자동 재임포트하나, 테스트/덤프 전엔 수동 1회).
- **PixelLab 파라미터(세션2와 동일 결):** `tile_size=32`, `detail="low detail"`, `outline="selective outline"`, `shading="basic shading"`, `view="high top-down"`.
- **canonical base tile ID(톤 단일 소스):** 흙=`a2f59b0e-252e-4a83-a6e4-b080f2290d36`, 잔디=`60dcdf27-d238-44ae-95c8-5cb6b04f4c46`(둘 다 tileset `8ffcb621`). 길=흙과 동일 dirt(`a2f59b0e`). 밭=`90d8a650` lower, 물=`8d56f11b` lower(Task 1에서 base ID 최종 확정).
- **흙↔잔디 tileset = `8ffcb621` 재활용**(이미 완성된 dirt→grass 16타일 Wang, 오버행=잔디 upper).

---

## File Structure

- `game/tools/wang_boundary_scan.gd` (신규) — HOME `_g16_surface` 전 셀 순회로 실발생 경계쌍·삼중점 빈도 출력(조사, Task 1)
- `game/assets/terrain16/wang/<lo>_<up>_image.png`, `<lo>_<up>_metadata.json` (신규) — 경계쌍별 전환 tileset 에셋(Task 2)
- `game/tools/slice_wang_pair.py` (신규) — PixelLab tileset PNG+metadata를 game 에셋 경로로 정리·검증하는 글루(Task 2)
- `game/main.gd` (수정) — Wang 전환 로더·코너 인덱서 헬퍼 추가(Task 3) + `_build_ground16` ②블록 교체(Task 4) + mute/튜닝(Task 5)
- `game/playtest/wang_boundary_test.gd` (신규) — 코너 인덱서·로더 단위검증(Task 3)
- `game/tools/home_pilot_dump.gd` (신규) — 경계 before/after 육안 크롭 덤프(Task 6)

---

## Task 1: 경계쌍·삼중점 스캔 (조사)

목적: 어떤 경계쌍을 생성해야 하는지 확정하고 owner에 크레딧 소요를 보고한다. 코드 변경 없음(조사 스크립트만).

**Files:**
- Create: `game/tools/wang_boundary_scan.gd`

**Interfaces:**
- Consumes: main 노드의 `_g16_surface(x,y)`, `_grid_w`, `_outdoor_h`, `RegionCatalog.HOME`
- Produces: 콘솔에 경계쌍 목록(정규화 `lo<up` 위계쌍)과 각 빈도, 삼중점 셀 수

- [ ] **Step 1: 스캔 스크립트 작성**

```gdscript
# game/tools/wang_boundary_scan.gd
extends SceneTree
# HOME 지면 표면 경계쌍 스캔 — 어떤 Wang 전환 tileset을 생성해야 하는지 확정(조사).
# 실행: godot --headless --path game --script res://tools/wang_boundary_scan.gd

const RANK := {1: 4, 0: 3, 2: 2, 3: 1, 4: 0}   # 잔디>흙>길>밭>물

func _initialize() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	# ground16 표면 격자 재현(_build_ground16 ①과 동일 산출 — surf만 필요).
	var W: int = m._grid_w
	var H: int = m._outdoor_h
	var surf: Array = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append(m._g16_surface(x, y))
		surf.append(row)
	m._g16_cluster_cleanup(surf)
	for y in H:
		for x in W:
			if int(surf[y][x]) == 1 and m._g16_near_building(x, y):
				surf[y][x] = 0
	# 셀 4코너 꼭짓점 표면으로 경계쌍·삼중점 집계
	var pair_count := {}   # "lo_up" → 셀수
	var triple := 0
	for y in H:
		for x in W:
			if int(surf[y][x]) < 0:
				continue
			var cs := [_vsurf(surf, x, y, W, H), _vsurf(surf, x+1, y, W, H),
					_vsurf(surf, x, y+1, W, H), _vsurf(surf, x+1, y+1, W, H)]
			var uniq := {}
			for c in cs:
				if c >= 0:
					uniq[c] = true
			if uniq.size() < 2:
				continue
			if uniq.size() >= 3:
				triple += 1
			var ks: Array = uniq.keys()
			ks.sort_custom(func(a, b): return RANK[a] > RANK[b])
			var key := "%d_%d" % [ks[1], ks[0]]   # lo_up (위계: up=ks[0] 최상)
			pair_count[key] = int(pair_count.get(key, 0)) + 1
	print("── 경계쌍(lo_up = 위계 낮음_높음) → 경계 셀 수 ──")
	for k in pair_count:
		print("  %s : %d" % [k, pair_count[k]])
	print("삼중점(3표면 코너) 셀 수: %d" % triple)
	print("surf 코드: 0맨흙 1잔디 2길 3밭 4물")
	quit()

func _vsurf(surf: Array, vx: int, vy: int, W: int, H: int) -> int:
	var best := -1
	var best_r := -1
	for d in [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(0,0)]:
		var cx := vx + d.x
		var cy := vy + d.y
		if cx < 0 or cy < 0 or cx >= W or cy >= H:
			continue
		var s: int = surf[cy][cx]
		if s < 0:
			continue
		if RANK[s] > best_r:
			best_r = RANK[s]
			best = s
	return best
```

- [ ] **Step 2: 스캔 실행**

Run: `cd game && godot --headless --path "$PWD" --script res://tools/wang_boundary_scan.gd`
Expected: 경계쌍 목록 출력(예: `0_1 : NNN`(흙↔잔디), `1_2`(길↔잔디) 등)과 삼중점 셀 수. 셀 수 0인 쌍은 생성 불요.

- [ ] **Step 3: canonical base ID 확정**

Run(길/밭/물 base 확인):
```
mcp: get_topdown_tileset(90d8a650-24ae-40f7-8705-e7d975702ff7)   # 밭 base
mcp: get_topdown_tileset(8d56f11b-fa1d-4a08-9eed-05cf64063f04)   # 물 base
```
각 반환의 `base_tile_ids.lower`를 밭·물 canonical로 기록. 길=흙과 동일 `a2f59b0e`.

- [ ] **Step 4: owner 보고 후 생성 목록 확정**

스캔 결과의 셀수>0 쌍만 생성 대상. 흙↔길(`0_2`)은 동일 dirt 소스라 톤차 미미 → 생성 스킵(base 유지, 경계 사실상 비가시). owner에 「생성할 쌍 N개 · 흙↔잔디는 재활용 · 예상 크레딧」 보고하고 승인받는다.

- [ ] **Step 5: 커밋**

```bash
git add game/tools/wang_boundary_scan.gd
git commit -m "🔧 chore(wang): 경계쌍 스캔 스크립트 — 생성 대상 tileset 확정"
```

---

## Task 2: PixelLab 전환 tileset 생성·정리

목적: Task 1이 확정한 쌍마다 canonical base로 전환 tileset을 생성하고 game 에셋 경로로 정리한다. (에이전트가 MCP로 실행 — TDD 사이클 아님, 절차+검증.)

**Files:**
- Create: `game/assets/terrain16/wang/<lo>_<up>_image.png`, `<lo>_<up>_metadata.json` (쌍마다)
- Create: `game/tools/slice_wang_pair.py`

**Interfaces:**
- Produces: 각 쌍 `<lo>_<up>_image.png`(32px 타일 16개 아틀라스) + `<lo>_<up>_metadata.json`(`tileset_data.tiles[].corners`+`bounding_box`)

- [ ] **Step 1: 흙↔잔디는 8ffcb621 재활용 — 다운로드**

생성 없이 기존 완성분을 받는다. `get_topdown_tileset(8ffcb621-...)`의 `download_png`/`download_metadata` URL에서 받아 `game/assets/terrain16/wang/0_1_image.png`·`0_1_metadata.json`로 저장(0=흙 lo, 1=잔디 up).

- [ ] **Step 2: 나머지 쌍 생성(비동기 ~100s/개)**

Task 1 목록의 각 쌍 (lo, up)에 대해 canonical base 지정 생성. 예(길↔잔디 `2_1`, lo=길=흙dirt `a2f59b0e`, up=잔디 `60dcdf27`):
```
mcp: create_topdown_tileset(
  lower_description="warm packed dirt walking path, neutral earthen",
  upper_description="muted earthy green grass, scattered blades, stardew meadow",
  lower_base_tile_id="a2f59b0e-252e-4a83-a6e4-b080f2290d36",
  upper_base_tile_id="60dcdf27-d238-44ae-95c8-5cb6b04f4c46",
  tile_size={"width":32,"height":32}, detail="low detail",
  outline="selective outline", shading="basic shading", view="high top-down",
  transition_size=0.5, transition_description="grass tufts creeping over dirt edge")
```
밭·물 쌍은 `transition_size=0.25`(furrow/수면 가독, spec §7.4). 각 `create` 후 `get_topdown_tileset(id)`로 `status: completed` 확인.

- [ ] **Step 3: 정리 글루 작성**

```python
# game/tools/slice_wang_pair.py
# PixelLab tileset 다운로드본(PNG+metadata)을 game 에셋 경로로 복사·검증.
# 16타일 코너 커버리지(15개 코너조합 all 커버)를 확인해 누락 조기 발견.
# 사용: python3 slice_wang_pair.py <src_meta.json> <src_img.png> <lo> <up>
import json, sys, shutil, os
from PIL import Image

def main() -> None:
    meta_path, img_path, lo, up = sys.argv[1:5]
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "terrain16", "wang")
    os.makedirs(out_dir, exist_ok=True)
    stem = f"{lo}_{up}"
    meta = json.load(open(meta_path))
    tiles = meta["tileset_data"]["tiles"]
    seen = set()
    for t in tiles:
        c = t["corners"]
        bits = ((1 if c["NW"]=="upper" else 0) | (1 if c["NE"]=="upper" else 0)<<1
                | (1 if c["SW"]=="upper" else 0)<<2 | (1 if c["SE"]=="upper" else 0)<<3)
        seen.add(bits)
    missing = [b for b in range(16) if b not in seen]
    if missing:
        print(f"⚠️ {stem}: 코너조합 누락 {missing} (렌더 시 base 폴백)")
    shutil.copy(meta_path, os.path.join(out_dir, f"{stem}_metadata.json"))
    Image.open(img_path).convert("RGBA").save(os.path.join(out_dir, f"{stem}_image.png"))
    print(f"{stem}: {len(seen)}/16 코너조합, 저장 완료")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: 각 쌍 정리 실행**

Run(쌍마다): `cd game && python3 tools/slice_wang_pair.py <다운받은_meta> <다운받은_png> <lo> <up>`
Expected: `<lo>_<up>: 16/16 코너조합, 저장 완료`. 누락 경고 시 그 쌍 재생성.

- [ ] **Step 5: 재임포트 + 커밋**

```bash
cd game && godot --headless --path "$PWD" --import
git add game/assets/terrain16/wang/ game/tools/slice_wang_pair.py
git commit -m "🎨 feat(wang): 경계쌍 전환 tileset 생성·정리 (canonical base chaining)"
```

---

## Task 3: Wang 전환 로더·코너 인덱서 (main.gd 헬퍼 + 단위검증)

**Files:**
- Modify: `game/main.gd` (지터 블록 상수 근처 `_GJIT`(3373) 뒤에 헬퍼 추가)
- Test: `game/playtest/wang_boundary_test.gd`

**Interfaces:**
- Consumes: `_grid_w`, `_outdoor_h`, `TILE`
- Produces:
  - `_surf_rank(s: int) -> int`
  - `_corner_bits(nw: int, ne: int, sw: int, se: int) -> int` (nw|ne<<1|sw<<2|se<<3)
  - `_wang_pair_key(lo: int, up: int) -> int` (lo*10+up)
  - `_wang_vertex_surf(surf: Array, vx: int, vy: int) -> int`
  - `_load_wang_pairs() -> void` (에셋 폴더 스캔 → `_wang_tiles[pair_key] = { corner_bits: Image }`)
  - `var _wang_tiles: Dictionary`

- [ ] **Step 1: 단위검증 실패 테스트 작성**

```gdscript
# game/playtest/wang_boundary_test.gd
extends SceneTree
# Wang 경계 전환 헬퍼 단위검증(순수 함수 + 로더). run_tests.sh 워치독과 함께.
var _fail := 0
func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok: _fail += 1

func _spawn() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("══ Wang 경계 전환 헬퍼 검증 ══")
	var m: Node = await _spawn()
	# ① 위계: 잔디>흙>길>밭>물
	_check("① 위계 잔디(1)>흙(0)>길(2)>밭(3)>물(4)",
		m._surf_rank(1) > m._surf_rank(0) and m._surf_rank(0) > m._surf_rank(2)
		and m._surf_rank(2) > m._surf_rank(3) and m._surf_rank(3) > m._surf_rank(4))
	# ② 코너 비트: NW=1비트, SE=8비트
	_check("② _corner_bits(1,0,0,0)=1", m._corner_bits(1,0,0,0) == 1)
	_check("② _corner_bits(0,0,0,1)=8", m._corner_bits(0,0,0,1) == 8)
	_check("② _corner_bits(1,1,1,1)=15", m._corner_bits(1,1,1,1) == 15)
	# ③ 꼭짓점 표면 = 인접 4셀 위계 최대(-1 제외)
	var surf := [[0, 1], [3, -1]]   # 흙·잔디 / 밭·건물
	_check("③ 꼭짓점(1,1)=인접{흙,잔디,밭} 중 잔디(위계최대)",
		m._wang_vertex_surf(surf, 1, 1) == 1)
	_check("③ 꼭짓점(0,0)=코너 흙 하나만",
		m._wang_vertex_surf(surf, 0, 0) == 0)
	# ④ pair_key 유일
	_check("④ pair_key(0,1)≠pair_key(1,0)",
		m._wang_pair_key(0,1) != m._wang_pair_key(1,0))
	# ⑤ 로더: 흙↔잔디(0_1) 16 코너조합 로드
	m._load_wang_pairs()
	var pk: int = m._wang_pair_key(0, 1)
	_check("⑤ 흙↔잔디 tileset 로드됨", m._wang_tiles.has(pk))
	_check("⑤ 16 코너조합 커버", m._wang_tiles.has(pk) and (m._wang_tiles[pk] as Dictionary).size() == 16)
	print("결과: %d 실패" % _fail)
	quit()
```

- [ ] **Step 2: 실패 확인**

Run: `cd game && ./run_tests.sh wang_boundary`
Expected: FAIL — `_surf_rank`/`_corner_bits`/`_wang_vertex_surf`/`_wang_pair_key`/`_load_wang_pairs`/`_wang_tiles` 미정의로 파싱 또는 단언 실패.

- [ ] **Step 3: main.gd에 헬퍼 구현**

`_GJIT`(약 3373) 상수 뒤에 추가:
```gdscript
# ── Wang 경계 전환 타일 (spec 2026-07-16) ──────────────────────────────
# 표면 위계: 잔디>흙>길>밭>물. 경계에서 위계 높은 쪽이 upper(오버행=볼록).
const _SURF_RANK := {1: 4, 0: 3, 2: 2, 3: 1, 4: 0}
var _wang_tiles: Dictionary = {}   # pair_key → { corner_bits(0..15): Image }
const _WANG_DIR := "res://assets/terrain16/wang/"

func _surf_rank(s: int) -> int:
	return int(_SURF_RANK.get(s, -1))

func _corner_bits(nw: int, ne: int, sw: int, se: int) -> int:
	return nw | (ne << 1) | (sw << 2) | (se << 3)

func _wang_pair_key(lo: int, up: int) -> int:
	return lo * 10 + up

# 꼭짓점 (vx,vy)를 공유하는 최대 4셀 중 위계 최대 표면(-1=건물/절벽 제외, 없으면 -1).
func _wang_vertex_surf(surf: Array, vx: int, vy: int) -> int:
	var best := -1
	var best_r := -1
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var cx := vx + d.x
		var cy := vy + d.y
		if cx < 0 or cy < 0 or cx >= _grid_w or cy >= _outdoor_h:
			continue
		var s: int = surf[cy][cx]
		if s < 0:
			continue
		var r := _surf_rank(s)
		if r > best_r:
			best_r = r
			best = s
	return best

# 에셋 폴더의 <lo>_<up>_metadata.json + _image.png를 슬라이스해 코너키→Image 캐시.
func _load_wang_pairs() -> void:
	if not _wang_tiles.is_empty():
		return
	var dir := DirAccess.open(_WANG_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with("_metadata.json"):
			continue
		var stem := f.replace("_metadata.json", "")   # "lo_up"
		var parts := stem.split("_")
		if parts.size() != 2:
			continue
		var lo := int(parts[0])
		var up := int(parts[1])
		var png := _WANG_DIR + stem + "_image.png"
		if not ResourceLoader.exists(png):
			continue
		var jf := FileAccess.open(_WANG_DIR + f, FileAccess.READ)
		var meta: Dictionary = JSON.parse_string(jf.get_as_text())
		jf.close()
		var atlas: Image = (load(png) as Texture2D).get_image()
		if atlas.get_format() != Image.FORMAT_RGBA8:
			atlas.convert(Image.FORMAT_RGBA8)
		var tmap: Dictionary = {}
		for t in meta["tileset_data"]["tiles"]:
			var c: Dictionary = t["corners"]
			var bits := _corner_bits(
				1 if c["NW"] == "upper" else 0,
				1 if c["NE"] == "upper" else 0,
				1 if c["SW"] == "upper" else 0,
				1 if c["SE"] == "upper" else 0)
			var b: Dictionary = t["bounding_box"]
			tmap[bits] = atlas.get_region(Rect2i(int(b["x"]), int(b["y"]), int(b["width"]), int(b["height"])))
		_wang_tiles[_wang_pair_key(lo, up)] = tmap
```

- [ ] **Step 4: 통과 확인**

Run: `cd game && ./run_tests.sh wang_boundary`
Expected: PASS — `결과: 0 실패`. (사전: Task 2 흙↔잔디 에셋 `0_1_*` 존재 + 재임포트 완료.)

- [ ] **Step 5: 커밋**

```bash
git add game/main.gd game/playtest/wang_boundary_test.gd
git commit -m "🔧 feat(wang): 코너 인덱서·전환 로더 헬퍼 + 단위검증"
```

---

## Task 4: `_build_ground16` ②지터 블록 교체

**Files:**
- Modify: `game/main.gd` (② 경계 지터 디더 블록, 약 3454~3493 삭제 → Wang 전환 blit)

**Interfaces:**
- Consumes: Task 3의 `_load_wang_pairs`, `_wang_vertex_surf`, `_surf_rank`, `_corner_bits`, `_wang_pair_key`, `_wang_tiles`; 기존 `surf`(로컬), `out`(Image), `TILE`
- Produces: 경계 셀에 전환 타일이 blit된 `_ground_detail_tex`

- [ ] **Step 1: 회귀 baseline 확인(교체 전)**

Run: `cd game && ./run_tests.sh building_grounding reclaim`
Expected: 둘 다 PASS(교체 전 기준선 — 이후 회귀 0 증명용).

- [ ] **Step 2: ②블록 교체**

main.gd에서 `# ② 경계 지터 디더`로 시작하는 블록(주석 3454~3458 + `var dirs`~`out.set_pixel(px, py, ...)` 약 3459~3493) **전체**를 아래로 치환. `_load_wang_pairs()`는 `_build_ground16` 진입 직후(`_load_big_fields()` 다음)에 1회 호출 추가.

```gdscript
	# ② Wang 경계 전환 — 4코너 표면이 2종 이상인 경계 셀에 손그림 전환 타일 blit(지터 대체).
	#    위계 상위 2표면을 (lo,up) 쌍으로 취해 그 tileset의 코너키 타일을 셀에 통째로 덮는다.
	#    삼중점(3종+)은 상위 2종만 쌍으로, 최하위 코너는 lower로 흡수(스타듀 폴백). 순수 셀·미생성
	#    쌍·미커버 코너조합은 스킵(①의 base blit 유지). _grid·충돌·세이브 불변(픽셀만).
	for y in _outdoor_h:
		for x in _grid_w:
			if int(surf[y][x]) < 0:
				continue   # 건물·절벽 = 오버레이 투명(절벽 오버레이가 덮음)
			var c_nw := _wang_vertex_surf(surf, x, y)
			var c_ne := _wang_vertex_surf(surf, x + 1, y)
			var c_sw := _wang_vertex_surf(surf, x, y + 1)
			var c_se := _wang_vertex_surf(surf, x + 1, y + 1)
			var uniq := {}
			for cv in [c_nw, c_ne, c_sw, c_se]:
				if cv >= 0:
					uniq[cv] = true
			if uniq.size() < 2:
				continue   # 순수 셀 = ① base blit 유지
			var ks: Array = uniq.keys()
			ks.sort_custom(func(a, b): return _surf_rank(a) > _surf_rank(b))
			var up_s: int = ks[0]
			var lo_s: int = ks[1]
			var pk := _wang_pair_key(lo_s, up_s)
			if not _wang_tiles.has(pk):
				continue   # 이 쌍 미생성(스킵된 쌍) → base 유지
			var bits := _corner_bits(
				1 if c_nw == up_s else 0,
				1 if c_ne == up_s else 0,
				1 if c_sw == up_s else 0,
				1 if c_se == up_s else 0)
			var tmap: Dictionary = _wang_tiles[pk]
			if not tmap.has(bits):
				continue   # 미커버 코너조합 → base 유지
			out.blit_rect(tmap[bits] as Image, Rect2i(0, 0, TILE, TILE), Vector2i(x * TILE, y * TILE))
```

`_build_ground16` 진입부(`_load_big_fields()` 호출 직후 줄)에 추가:
```gdscript
	_load_wang_pairs()
```

- [ ] **Step 3: 회귀 재확인(교체 후)**

Run: `cd game && ./run_tests.sh building_grounding reclaim wang_boundary`
Expected: 셋 다 PASS. building_grounding의 "건물 footprint 중심 픽셀 = _bf_earth" 단언이 여전히 통과(건물 발치는 잔디억제로 순수 맨흙 셀 → 경계 아님 → 전환 blit 없음).

- [ ] **Step 4: 결정성 확인**

Run: `cd game && godot --headless --path "$PWD" --script res://tools/wang_boundary_scan.gd` (표면 격자 재현 — 두 번 실행해 동일 출력이면 surf 결정적, 따라서 전환 blit도 결정적).
Expected: 두 실행 출력 동일.

- [ ] **Step 5: 커밋**

```bash
git add game/main.gd
git commit -m "🎨 feat(wang): _build_ground16 ②지터 → Wang 전환 blit 교체 (crisp 경계·오버행)"
```

---

## Task 5: mute 후처리 + transition_size 튜닝

목적: 전환 타일의 잔디 형광 억제(세션2 톤 일치)와 밭·물 전환대 두께 육안 조정. (시각 튜닝 — 단언보다 육안 하네스.)

**Files:**
- Modify: `game/main.gd` (`_load_wang_pairs`의 잔디 포함 타일에 mute 적용)

**Interfaces:**
- Consumes: 세션2 `_mute_grass_pixels(img, sat_mul, sat_cap)`(main.gd 기존)

- [ ] **Step 1: 잔디 포함 전환 타일에 mute 적용**

`_load_wang_pairs`의 `atlas` 로드 직후, 잔디(up=1 또는 lo=1)가 포함된 쌍이면 아틀라스 전체에 mute를 태운다(잔디 픽셀만 반응, 흙/길/물은 대상 밖 — 세션2 `_mute_grass_pixels` 동일 소스):
```gdscript
		if lo == 1 or up == 1:
			_mute_grass_pixels(atlas)   # 세션2 파라미터 기본값(sat_mul=0.74, sat_cap=0.38)
```
(적용 위치: `atlas.convert(...)` 다음 줄, `get_region` 슬라이스 전.)

- [ ] **Step 2: 재임포트 후 육안 덤프(Task 6 하네스로)**

Task 6의 `home_pilot_dump.gd`를 먼저 만들었다면 그것으로, 아니면 Task 6 완료 후 이 스텝 재실행. 잔디 전환대가 인접 `_bf_grass`(muted)와 톤 일치하는지 육안.

- [ ] **Step 3: transition_size 판정**

밭(3)·물(4) 포함 쌍의 전환대가 furrow/수면 가독을 해치면(육안), Task 2로 돌아가 그 쌍만 `transition_size=0.25`로 재생성. 여전히 나쁘면 그 쌍 에셋을 폴더에서 빼 하드 경계(base 유지)로 폴백.

- [ ] **Step 4: 커밋**

```bash
git add game/main.gd
git commit -m "🎨 fix(wang): 잔디 전환 타일 mute — 세션2 톤 일치(형광 억제)"
```

---

## Task 6: 육안 하네스 + 최종 선별 회귀

**Files:**
- Create: `game/tools/home_pilot_dump.gd`

- [ ] **Step 1: 경계 크롭 덤프 스크립트 작성**

```gdscript
# game/tools/home_pilot_dump.gd
# Wang 경계 전환 육안 덤프 — HOME 지면 오버레이 전체 + 경계 밀집 영역 크롭을 PNG로.
# ★ --headless 없이(실렌더): godot --path game --script res://tools/home_pilot_dump.gd
extends SceneTree

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame
	# 지면 오버레이 텍스처를 직접 저장(카메라 무관 — 전체 베이크 확인).
	var tex: ImageTexture = m._ground_detail_tex
	if tex != null:
		var img := tex.get_image()
		img.save_png("/tmp/wang_ground_full.png")
		# 경계 밀집 영역 크롭(마당 중앙 32×24칸 = 1024×768px, 필요 시 좌표 조정).
		var T: int = m.TILE
		var crop := img.get_region(Rect2i(20 * T, 16 * T, 32 * T, 24 * T))
		crop.save_png("/tmp/wang_ground_crop.png")
		print("saved /tmp/wang_ground_full.png · /tmp/wang_ground_crop.png (%dx%d)" % [img.get_width(), img.get_height()])
	else:
		print("✗ _ground_detail_tex 없음")
	quit()
```

- [ ] **Step 2: 덤프 실행 + 육안**

Run: `cd game && godot --path "$PWD" --script res://tools/home_pilot_dump.gd`
Expected: `/tmp/wang_ground_crop.png`에 crisp Wang 경계(랜덤 지터 없음)·잔디가 흙 위로 볼록(오버행)·격자 반복 없는 변주. Read 도구로 PNG를 열어 육안 확인.

- [ ] **Step 3: 최종 선별 회귀**

Run: `cd game && ./run_tests.sh building_grounding reclaim wang_boundary`
Expected: 셋 다 PASS.

- [ ] **Step 4: 커밋**

```bash
git add game/tools/home_pilot_dump.gd
git commit -m "🔧 chore(wang): 경계 육안 덤프 하네스(home_pilot_dump)"
```

---

## Task 7: owner 라이브 확인 (핸드오프)

목적: 코드 검증 밖의 최종 판정(경계쌍 완결성·오버행 강도·톤)을 owner 라이브 플레이로.

- [ ] **Step 1: PR 생성**

`/git:pr`로 브랜치→PR. 본문에 before(지터)/after(Wang) 크롭 첨부·생성한 쌍 목록·스킵한 쌍(흙↔길 등) 명시.

- [ ] **Step 2: owner 라이브 확인 대기**

owner가 인게임에서 확인. 지적 사항(특정 경계 미흡·오버행 과/부족·톤)이 나오면 Task 2(재생성)·Task 5(mute/size)로 순환.

- [ ] **Step 3: 메모리 갱신**

`terrain-tiles-pixellab-lowcolor-regen-adr0057`의 잔여 항목 ③(Wang 경계) 완료로 갱신. 잔여 ⑤(전 구역 확산)만 남김.

---

## Self-Review

**Spec coverage (spec §별 → task):**
- §5 렌더 통합(②블록만 교체) → Task 4 ✓
- §5.2 코너 vertex 산출 → Task 3 `_wang_vertex_surf` ✓
- §5.3 전환 선택·삼중점 폴백 → Task 4 blit 로직 ✓
- §6.1 canonical base → Global Constraints + Task 1 Step 3 ✓
- §6.2 흙↔잔디 재활용 → Task 2 Step 1 ✓
- §6.3 재생성 → Task 2 Step 2 ✓
- §6.4 mute → Task 5 ✓
- §6.5 저장·임포트 → Task 2 Step 5 ✓
- §7.1 경계쌍 스캔 → Task 1 ✓
- §7.4 밭·물 transition_size → Task 2 Step 2 + Task 5 Step 3 ✓
- §8 불변식 → Task 4 Step 1·3(회귀) ✓
- §9 검증(하네스·회귀) → Task 6 ✓

**Placeholder scan:** 코드 스텝은 실제 GDScript/Python/명령 포함. Task 1·2·5의 육안·MCP 스텝은 절차·판정기준 명시(TDD 부적합 성격). owner 보고(Task 1 Step 4)는 의도적 게이트.

**Type consistency:** `_surf_rank`/`_corner_bits`/`_wang_pair_key`/`_wang_vertex_surf`/`_load_wang_pairs`/`_wang_tiles` 시그니처가 Task 3 정의 = Task 4 사용 일치. surf 코드(0맨흙1잔디2길3밭4물)·pair_key(`lo*10+up`)·corner_bits(nw|ne<<1|sw<<2|se<<3) 전 task 동일.

**Note:** Task 2/3 순서 의존 — Task 3 로더 테스트(Step 4)는 Task 2의 `0_1_*` 에셋을 요구. subagent-driven 실행 시 Task 2를 Task 3보다 먼저 완료(또는 Task 3 Step 1~3만 먼저, Step 4는 Task 2 후).

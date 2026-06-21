# 환경 아트 32px native로 상향 — 캐릭터 선명도 일치 (ADR-0012 절충 개정)

ADR-0012는 캐릭터를 2배(standard size56, native ~58–70px)로 올리되 **환경 아트는
16px로 유지하고 TileMapLayer를 ×2 스케일해 렌더**하기로 했다("작업량 1/4 이점 보존",
"신규 환경 아트도 16px로 만들면 됨"). 그 결과 인게임에서 **캐릭터·작물은 native 32px급
선명, 환경(지형·실내·가구·밭)은 16px를 ×2 업스케일해 흐릿**한 불일치가 생겼다. 특히
가구는 32px 원본을 16px로 다운스케일한 뒤 다시 ×2로 그려 **이중으로 뭉갰다**.

## 결정

**환경 아트를 전부 32px native로 올린다(= TILE).** 캐릭터·작물과 픽셀밀도를 맞춰
한 화면이 한 해상도로 읽히게 한다. 그리드·좌표·게임 로직·`TILE=32`는 불변이다.

- **타일 소스 = 32px**: `TILE_ART 16→32`. 지형(풀↔길·밭↔풀·길↔밭)을
  `create_topdown_tileset tile_size=32`로 재생성 → 공식 컨버터로 32px
  `combined_terrain.tres` 재합성. 실내 바닥·벽은 32px topdown base에서 추출.
- **렌더 1:1**: Ground/Field `TileMapLayer`의 `scale=(2,2)` 제거(더는 ×2 업스케일 안 함).
  `_draw_props`의 `×2`도 제거 — 가구는 기존 **32px `_raw` 원본을 native로 직접 사용**
  (다운스케일 폐기, gen 0).
- **밭 작물 연결**: P2.2가 만든 32px 작물 스프라이트(혼령초·피안화·영혼 호박 각
  씨앗/새싹/수확)를 밭에 연결. 그레이박스 점(코드 도형)을 작물 스프라이트로 교체
  (`_draw_crops` — `field.growth_stage` 0/1/2 → 3프레임 매핑, T2.3 seam 해소).
  밭 오버레이 타일은 경작 고랑(DRY/WET 흙 톤)만 남긴다.
- **UI 불변**: `CanvasLayer scale=(2,2)`는 유지(640×360 내부해상도에 320×180 레이아웃).

## 근거

- 얼굴 가독성을 위해 캐릭터를 native 고해상도로 만든 이상(ADR-0012), 환경만 16px이면
  같은 화면에서 선명도가 어긋난다. 사용자 1순위(인게임 비주얼 일관성)에 맞춘다.
- 잔량(Tier 1, 1840 gen)이 충분해 ADR-0012가 지키려던 "작업량/비용 1/4" 동기의
  실익이 작다. 재생성 비용은 지형 5 gen + 실내 2 gen 수준(가구·작물은 gen 0 재사용).
- 타일 *그리드*(`TILE=32`)와 좌표는 안 바꿔 좌석·밤 스폿·NPC 출근·밭·동선과
  회귀 8종이 전부 불변(시각만 교체 = 드롭인). 오히려 `×2` 핵을 제거해 렌더가 단순해진다.

## ADR-0012와의 관계

ADR-0012의 **캐릭터 standard size56 + 공통 proportions**, **TILE=32 그리드**,
**내부해상도 640×360**, **UI CanvasLayer ×2**는 그대로 유효하다. 이 ADR은 ADR-0012의
*"환경 아트 16px 유지(렌더 ×2)"* 절충 한 가지만 뒤집어 **환경 아트도 32px native**로
바꾼다. ADR-0003의 룩(탑다운 3/4뷰·치비·정수배·역할별 외곽선·초상화=대화 얼굴)도 불변.

## 결과

- 신규 환경 아트는 이제 **32px로 만든다**(렌더 ×2 안 함). PixelLab 지형은
  `create_topdown_tileset tile_size=32`, 실내 단일 면 타일은 32px topdown base 추출
  (`tools/extract_base_tile.py`), 가구는 `create_map_object` 32px raw 그대로.
- 검증: 회귀 8종(cafe·cafe_margin·night_bar·weave·milestone·npc_station·lighting·bana)
  PASS, 헤드리스 부팅·임포트 클린, map_dump 육안(환경 선명·작물 연결) 확인.
- 레시피·발견은 [p2.0-spike-prompts.md §11](../design/p2.0-spike-prompts.md)에 잠금.

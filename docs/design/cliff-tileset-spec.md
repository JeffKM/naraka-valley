# 다단 절벽 타일 세트 스펙 카드 (S1-10, ADR-0025 생성 전 승인 게이트)

> **워크플로우:** 이 카드로 **owner 승인** → PixelLab **단일 응집본 생성** → 타일 슬라이스 → `enforce_chunk`/×2 청키화 → `quantize_to_palette.py` 마스터 팔레트 스냅 → 임포트·배선 → 인게임 시각확인. **승인 전 생성 금지**(ADR-0025 "아무렇게 만든다" 방지).
> **근거:** [ADR-0044](../adr/0044-world-map-richness-pseudo-z-terrain-south-water-topology.md) pseudo-Z 다단 · [asset-ruleset §4.1](./asset-ruleset.md) 절벽 규격 · [ADR-0012/0013] 16논리×2=32px · S1-2(타일종·충돌) / S1-3(배치) 완료.
> **grill 잠금(2026-07-02, Q1~Q3 → 2라운드):** ①범위=**전체 방향 세트**(재사용·리컬러 대비) ②물가=**연못 강둑 단차 적용**(이번에) ③재질=**흙 절벽+풀 오버행** ④코너=**외부+내부 완전 세트** ⑤파이프라인=**단일 응집본→마스터팔레트 양자화**(리컬러=램프 교체).

---

## 1. 룩 · 재질 (owner 잠금)

- **재질 = 흙 절벽 + 풀 오버행.** 스타듀식 cozy. 회색 암석(기존 `cliff_face.png`) 폐기.
  - **LIP(고지 밑단)** = 고지 풀이 절벽 위로 살짝 **늘어진 밝은 오버행 라인**(초록). 걷기 O · 고지↔저지 풀 연속감의 핵.
  - **FACE(절벽면)** = warm **흙/암반 단면**([§9] warm 베이스 — 살짝 가라앉힌 갈색, 세로 결·잔돌 텍스처). SOLID.
  - **FACE_BASE(접지단)** = 흙 절벽 최하단 + **SE 방향 self-shadow**([§1.3(b)] 저승 구조물 = **차가운 청보라-슬레이트** 자기그림자, 구워도 됨). SOLID.
- **광원 = NW 고정**([§1]). 밝은 엣지가 **항상 좌상단**. 동↔서면은 **단순 flip 금지 — 픽셀 재보정**([§4], [ADR-0044 §1]).
- **접지/투사 그림자(a)는 굽지 않음** — 별도 오버레이(§1.3(a))가 담당. 스프라이트엔 self-shadow(b)만.
- **청키 2px 블록**([§0.1]) 강제 — 2×2 비율 ≥95%.

## 2. 타일 인벤토리 (전체 세트)

논리 16px → ×2 = **32px native PNG**. 걷기/충돌은 타일종이 결정([ADR-0044 §1]):
LIP=걷기 O / FACE·FACE_BASE=SOLID.

### A. 남향(South) 정면 — 세로 3논리행 (H=2)
| 파일 | 타일종 | 통과 | 역할 |
|---|---|---|---|
| `cliff_s_lip.png` | CLIFF_LIP | 걷기 O | 고지 풀 오버행(밝은 상단 라인) |
| `cliff_s_face.png` | CLIFF_FACE | SOLID | 흙 절벽 상단면 |
| `cliff_s_base.png` | CLIFF_FACE_BASE | SOLID | 접지단 + SE 청보라 self-shadow |

### B. 동향(East) — Lip 1열 + Face 2열 (높이의 가로 치환)
| 파일 | 타일종 | 통과 | 역할 |
|---|---|---|---|
| `cliff_e_lip.png` | CLIFF_LIP(동변) | 걷기 O | 동쪽 풀 오버행 열 |
| `cliff_e_face.png` | CLIFF_FACE(동면) | SOLID | 흙 절벽 동면(2열 반복 사용) |

### C. 서향(West) — 동향의 NW광원 재보정 미러
| 파일 | 타일종 | 통과 | 역할 |
|---|---|---|---|
| `cliff_w_lip.png` | CLIFF_LIP(서변) | 걷기 O | 서쪽 풀 오버행 열 |
| `cliff_w_face.png` | CLIFF_FACE(서면) | SOLID | 흙 절벽 서면(밝은 엣지 좌상단 유지) |

### D. 북향(North) — 상단 lip만 (면 안 보임)
| 파일 | 타일종 | 통과 | 역할 |
|---|---|---|---|
| `cliff_n_lip.png` | CLIFF_LIP(북변) | 걷기 O | 고지 북쪽 가장자리 풀 엣지 |

### E. 코너 — 외부(볼록) 4 + 내부(오목) 4
> **외부(convex)** = 고지 모서리가 저지로 튀어나온 볼록 코너. **내부(concave)** = 저지가 고지 안으로 파고든 오목 코너. flip 허용은 거울대칭쌍만(NW광원 재보정 주의).

| 파일 | 통과 | 역할 |
|---|---|---|
| `cliff_out_se.png` / `cliff_out_sw.png` / `cliff_out_ne.png` / `cliff_out_nw.png` | SOLID | 외부 코너(edge-to-edge 마감·초록 leak 방지, [ADR-0044 §1] 넝쿨핵 폐기) |
| `cliff_in_se.png` / `cliff_in_sw.png` / `cliff_in_ne.png` / `cliff_in_nw.png` | SOLID | 내부 오목 코너 |

### F. 물가 강둑 (ADR-0044 §2)
| 파일 | 통과 | 역할 |
|---|---|---|
| `cliff_bank.png` | SOLID | 물(연못·강) 상단 강둑 단차 1행 — 수면과 저지 사이 의사 고저차 |
| `cliff_beach.png` *(S3 이관)* | — | 바다 진입부 고지수풀↔백사장 수평 절벽 런. 생성은 **S3(황천해)**에서(연못엔 불요) |

### G. 계단
| 파일 | 통과 | 역할 |
|---|---|---|
| `stairs_east.png` | 걷기 O(프롭) | 동향 절벽 종단 계단(현 남향 placeholder 교체) |
| `stairs_south.png` *(선택)* | 걷기 O(프롭) | 남향 계단 흙룩 재생성(기존 `stairs.png` 재사용 가능 시 생략) |

**S1-10 생성분 = A~E 전체 + F `cliff_bank` + G `stairs_east`.** `cliff_beach`·`stairs_south`는 표기만(생성 S3/선택).

## 3. pseudo-Z 기하 정합 (H=2, 불변)

[ADR-0044 §1] 표준 수직 구조 그대로 — 아트는 이 배치에 1:1로 맞춘다:

```
y-1  PLATEAU_GRASS  (고지 풀, 걷기 O)      ← 기존 지면 타일
y+0  CLIFF_LIP      (걷기 O · 밝은 오버행)   ← cliff_s_lip
y+1  CLIFF_FACE     (SOLID)                ← cliff_s_face
y+2  CLIFF_FACE_BASE(SOLID · SE self-shadow)← cliff_s_base
y+3  LOWER_GRASS    (저지 풀, 걷기 O)       ← 기존 지면 타일
```

- **H=2 마스터 표준**(Face+Base) 유지. z축 아님([ADR-0013] 2D 평면 데이터·세이브·카메라 불변).
- 동/서향 = 위 구조를 90° 가로 치환(Lip 1열 + Face 2열).

## 4. 생성 파이프라인 (단일 응집본 → 마스터팔레트 양자화)

1. **단일 응집본 생성** — PixelLab로 **절벽 구조 1장**(고지 블록에 남·동·서면 + 외/내 코너가 한 장면에 함께 보이는 흙 절벽 지형)을 **half-res**([§0])로 생성. 한 번에 뽑아 **톤·그레인·광원 응집성**을 확보(owner: "색감만 바꾸기 편하게").
2. **타일 슬라이스** — 응집본을 16논리 그리드로 잘라 §2 파일들로 분해(부족한 코너/방향은 추가 컷 or 재보정).
3. **청키 ×2** — `tools/enforce_chunk.py`(또는 §0 half-res ×2)로 32px 청키화(2×2 ≥95%).
4. **마스터 팔레트 양자화** — `tools/quantize_to_palette.py`로 [§16] 램프 nearest 스냅(흙=warm 갈색 램프 / self-shadow=청보라-슬레이트 / 풀=warm 녹색). **리컬러 = 이 양자화 램프만 교체**(가장 싼 재색).
5. **임포트** — `godot --headless --import` 1회.

- **동↔서 flip 금지**: 슬라이스 후 서면은 NW광원 재보정([§1], [ADR-0044 §1]) — 자동 미러 후 밝은 엣지를 좌상단으로 리터치.

## 5. 프롬프트 (NW 광원 강제 세트 + 흙 절벽)

[§1.1] 강제 세트에 재질 키워드를 얹는다:
```
Flat 2D pixel art, light source from top-left (NW), distinct directional step-shading,
1px highlight on top and left edges, crisp dark shadows cast to bottom-right (SE),
strict adherence to 2-3 color values max, no smooth gradients.
top-down cozy farm cliff, earthen dirt cliff face with grassy overhang lip on top,
warm brown soil strata, cool slate-violet self-shadow at the base,
Stardew-like chunky pixels, NOT isometric, NOT rocky grey stone.
```
- 산출은 **half-res 캔버스**(§0)로 목표의 절반 해상도. 응집본이라 넉넉한 캔버스에 절벽 지형 전체를 담는다.

## 6. 코드 배선 (생성·승인 후 = ★워크트리 격리 필요)

> 순수 아트를 넘어 코드를 건드리므로 **`EnterWorktree` 후 구현**([worktree-isolation-rule]). 첫 헤드리스 전 `--import` 1회.

- **텍스처 맵 확장** — 현재 `SOLID_TEX`엔 `CLIFF_FACE`만. **CLIFF_LIP·CLIFF_FACE_BASE도 텍스처 배선**(LIP은 걷기 O지만 렌더 텍스처 필요 — placeholder 색 제거). 방향/코너 변종을 타일 렌더가 선택하도록 배치 컨텍스트→아트 매핑 추가.
- **연못 강둑 배치** — `_build`에서 `SPIRIT_POND_RECT` **상단 가장자리에 강둑 단차(`cliff_bank`) ≥1행** 배치([ADR-0044 §2]). 물 Wang(water_grass)은 유지, 위에 강둑 단차만 얹음. **회귀:** 연못 낚시/물뿌리개 앵커(Slice 3 예약) 좌표 불변 확인.
- **동향 계단** — `PROP_STAIRS`를 `stairs_east`로 교체(노치 x21..23 y14..15 동향 종단에 정렬).
- **불변식:** `_grid` 타일종·충돌 로직(S1-2/S1-3)·`layout.json`·세이브 불변 — **아트/텍스처만 교체**. `game/run_tests.sh` 전체 회귀 0.

## 7. 완료 기준

- §2 A~E + `cliff_bank` + `stairs_east` 생성·양자화·임포트.
- 안식 농원 인게임 시각확인(home_full_dump): 동·남·SE외부코너·동향계단·연못강둑이 흙룩+풀오버행+NW광원으로 일관, 회색 placeholder·초록 leak 0.
- `run_tests.sh` 전체 통과·부팅 클린·회귀 0.
- ROADMAP S1-10 체크·shrimp 동기화.

## 8. 범위 경계 (하류)

- **인게임 배치·검증 이번 범위** = 안식 농원이 실제 까는 **동·남·SE외부코너·동향계단 + 연못 강둑**.
- **N/W면·나머지 외/내 코너·`cliff_beach`** = 생성·임포트는 하되(전체 세트 방침), **인게임 배치·시각검증은 그 지형이 생기는 S2(나루)·S3(삼도천/황천해)** 에서([ADR-0044 §3]).
- **리컬러(저승/절기 톤 변주)** = §16 램프 교체로 후속 대응(§4-4).

---

## 9. 실구현 결과 (2026-07-02)

> owner 승인 → 워크트리 `worktree-s1-10-cliff-art`에서 생성·배선·회귀.

- **생성 도구 = PixelLab `create_tiles_pro`(square_topdown, top-down, segmentation).** `create_map_object`는 "cliff/plateau/staircase"를 **3D 아이소메트릭 블록**으로 렌더해 평면 벽 타일에 부적합 → 폐기. tiles_pro는 번호 매긴 응집 배치(16변종)로 평면 타일을 뽑아 게임의 이산 타일종(LIP/FACE/BASE)에 직결. **파이프라인:** tiles_pro → `enforce_chunk.chunkify`(÷2 BOX→×2, 2px 청키) → `assets/tiles/` 저장 → `SOLID_TEX` 배선.
- **코어 남향 세트(인게임 적용·검증):** `cliff_s_lip`(풀 오버행)·`cliff_s_face`(warm 흙 strata)·`cliff_s_base`(어두운 접지+슬레이트). `SOLID_TEX`에 배선 → 동·남·코너 밴드 전부 즉시 흙룩 업그레이드(단일 타일종/방향, 회귀 로직 불변). home_full_dump 사인오프.
- **물가 강둑(인게임):** 신규 타일종 `CLIFF_BANK`(=15, N_TILES 16, SOLID) + `cliff_bank.png`(흙 strata + 물가 둥근 돌 ledge, owner 스크린샷 정합). `_build_home`에서 연못 북단 **2행**(y-1=`CLIFF_FACE` 흙 밴크 + y0=`CLIFF_BANK` 돌 ledge)로 물 최상단 grass 전이행을 덮어 배치. 물 Wang·연못 크기·낚시 앵커(Slice 3 예약) 좌표 **불변**. ※ 돌 ledge↔수면 사이 얇은 grass rim은 물 Wang 고유 전이(물→돌 전용 전이 타일은 S3 물 작업) — greybox-art 수용.
- **전체 방향/코너 세트 파일(S2/3 재사용, 인게임 미배치):** `cliff_out_{nw,ne,se,sw}`·`cliff_in_{nw,ne,se,sw}`(batch2 AI 외/내 코너 + rot90)·`cliff_{e,w,n}_lip`·`cliff_{e,w}_face`(남향 세트 rot90 파생). NW광원 재보정은 S2/3 배치 시(spec §8·§4). 옛 회색 암석 `cliff_face/corner_l/corner_r/inner.png` 삭제(참조 0).
- **동향 계단(`stairs_east`) ✅ 완료(2026-07-02 재시도):** 1차 map_object가 3D 블록+오답 팔레트라 보류했으나, **`view="side"` + "flat orthographic front, NO grass/dirt base, transparent" 프롬프트**로 재생성 → 흙 절벽에 통합된 warm 돌계단 획득. 좌우 반전(고지=서/왼쪽·저지=동/오른쪽)·96×64(노치 3칸)·바닥정렬·청키화 → `stairs_east.png`. `PROP_STAIRS` 배선 교체(placement (21,14) 불변·통과 O)·옛 `stairs.png` 삭제. home_full_dump 노치 사인오프. ※교훈: map_object는 `view="side"`+base 금지로 평면 프롭 유도 가능(low top-down은 3D 유발).
- **마스터 팔레트:** 저승 객체 슬레이트 램프는 여전히 TBD(master-palette.md). 이번 절벽은 tiles_pro가 warm 흙+슬레이트를 근사 생성 → 정밀 양자화는 저승 램프 큐레이션 확정 시 일괄(리컬러 파이프라인 §4-4).

## 10. 아트 재생성 패스 (2026-07-03, owner "절벽이 이상하게 생성됨" 피드백)

> owner가 스타듀 레퍼런스(청키 둥근 자갈 바위벽 + 풀 오버행 / 물가 둥근 boulder 강둑)를 제시. S1-10 1차 산출(`cliff_s_face`=밋밋한 갈색 그라데이션)이 "이상하다"는 판정 → **코어 남향 세트 + 강둑 아트만 재생성**(메카닉·`SOLID_TEX` 배선·타일종 전부 불변, PNG 4장만 교체).

- **재생성 = PixelLab `create_tiles_pro`(square_topdown, top-down, segmentation, seed 70301).** 4-넘버 프롬프트로 16변종 한 번에 뽑음: ①풀 오버행 립 ②청키 둥근 자갈 바위벽 면 ③어두운 접지 베이스+슬레이트 그림자 ④모래↔물 둥근 boulder 강둑. 베스트(tile 0/4/8/12) 선택 → `enforce_chunk.chunkify`(2px 캐논) → `cliff_s_lip/face/base.png`·`cliff_bank.png` 덮어쓰기. 1차 산출에서 **밋밋 갈색 → 자갈벽으로 확 개선**, home_full_dump 사인오프.
- **가이드 정합(owner 공유 Gemini 문서):** "면 최소 2칸 높이"는 `_lay_south_band`가 이미 Lip+Face+Face_Base(2 SOLID행=32px 벽)로 충족 — 아트가 이 2칸 벽을 *제대로 된 바위벽으로 보이게* 함. **미구현(하류 분리):** "절벽 상단 엣지(Lip)를 Front 레이어로 캐릭터 머리 위에 덮기" = 현재 lip은 Ground 타일이라 항상 캐릭터 뒤 렌더 → front-overhang은 별도 렌더 메카닉(S2/3 또는 별도 슬라이스).
- **하류 유지:** `cliff_beach`(S3)·정밀 팔레트 양자화는 §8·§9 그대로.

### 10.1 방향/코너 세트 재생성 (2026-07-04, "같은 룩으로" owner 요청)

> 남향 코어를 새 룩으로 바꾸자, orphan 방향/코너 변종 13종(옛 rot90+AI 코너)이 톤 불일치. owner "방향/코너도 같은 룩으로 재생성" → **새 남향 세트(`cliff_s_lip`/`cliff_s_face`)에서 파생**해 룩을 픽셀 단위로 일치시킴(PixelLab 불요·결정적). 전부 orphan(코드 참조 0)이라 **PNG만 교체**, 배선·타일종·회귀 불변.

- **방향 면(`cliff_e_face`·`cliff_w_face`)** = `cliff_s_face`(바위=무방향). 서면은 좌우반전으로 결 변화만.
- **방향 립(`cliff_e_lip`·`cliff_w_lip`·`cliff_n_lip`)** = `cliff_s_lip` 회전/반전(풀이 항상 고지쪽 — 동=풀좌/서=풀우/북=풀아래). NW광원 정밀 재보정은 인게임 배치(S2/3) 때.
- **외부(볼록) 코너 4** = 바위 면 기반 + 고지 코너에만 풀 nub(대각 마스크 fx+fy>1.25). 바위-다수.
- **내부(오목) 코너 4** = 풀 채운 타일 기반 + 저지(notch) 코너에만 바위 nub. 풀-다수.
- 파생 후 `enforce_chunk` 2px 캐논 유지. 몽타주 육안 확인(방향·볼록/오목 semantics 정합). 인게임 배치·NW광원 재보정은 여전히 S2(나루)/S3(삼도천·황천해) — greybox-ready.

### 10.2 유기적 자연 절벽 피벗 (2026-07-04, owner Gemini 가이드 5·6차)

> owner가 스타듀 맵 정밀비교 가이드 연속 제공 → **절벽 시스템 문법 교정** + **에셋 유기화** 확정:
> - **문법**: 스타듀 절벽은 **남향(아래)에만 바위벽**, 동/서/북은 **잔디 립 경계만**(바위벽 없음), 좌우 코너는 90°가 아닌 **곡선 대각 전이**, 발치 **검정 반투명 그림자**. → 옛 box-model(동/서 밴드 바위벽·90° 코너)·`_lay_east_band`·orphan out/in·e/w_face 폐기 대상.
> - **에셋**: 청키 자갈면(§10.1)이 "인공적 벽돌/옹벽"으로 읽힘 → **유기적 흙/퇴적암**으로 재생성(불규칙 삐죽 풀잎 립·수평 침식결 흙면·warm 베이스).

- **단계 1·2 완료(라이브 선반영):** PixelLab tiles_pro(seed 70402, 유기 프롬프트) → 립=t5(불규칙 흙 하단), 면=t8(warm 흙 수평 침식결), 베이스=t13(차분 warm 흙)+**검정 반투명 그림자 굽기**(파란빛 t14 폐기). `enforce_chunk` → `cliff_s_lip/face/base.png` **라이브 교체**(SOLID_TEX 배선 불변 — 안식 남향밴드·동향밴드·연못강둑 즉시 유기화). home_full_dump 사인오프: 그리드 경계 소멸·warm 톤 일관.
- **단계 3(하류, ADR-0044 개정 슬라이스):** ①잔디 입체화(클러스터 명암 + 4~5 변종 노이즈 배치 + 지상 장식 프롭) ②**남향-only 오토타일러**(동/서/북=잔디 립, 곡선 대각 전이 타일, 그림자 자동합성) 라이브 통합 ③옛 90°코너·측벽(out/in/e_w_face) 폐기 ④상단 립 Front 레이어(머리 덮기). §10.1 파생 코너는 이 단계에서 곡선 전이로 대체.
- **단계 3 후속 증분 완료(2026-07-04, 워크트리 cliff-south-followup — ②남향-only 오토타일러는 PR#193 Increment A로 선완료):**
  - **③ 잔디 입체화(부분):** 동향 잔디 능선을 x20 4칸 간격 bush 7개 → y1~25 2칸 지그재그(x19↔20) 13개로 연속 산등성이화(`PROP_LAYOUT_HOME`). 필드 변종 노이즈·클러스터 명암은 owner 차분함 선호(`_GD_CLUMP_DAMP=0.42`) 존중해 보류(육안 후 별도).
  - **④ 곡선 대각 전이 코너:** 신규 타일종 4종(`CLIFF_CORNER_SW/SE × Face/Base`, 전부 SOLID) + 오토타일러 코너 로직(벽 서/동 바깥 끝=맵경계·능선과 만나는 진짜 끝 감지). 아트=`make_cliff_corners.py` 절차 파생(`cliff_s_face/base` + lip 풀을 1/4 코사인 곡선으로 전이, 결정적·2px 캐논). §10.1 파생 out/in 코너를 이 곡선 전이로 대체.
  - **⑤ 벽면 오버행(owner 결정 = 벽면 전체 front, 스타듀 표준):** CLIFF_LIP은 고지 위·안 닿음 → 캐릭터가 절벽 밑 1~2칸에 서면 Face/Base를 `_front_props`(z=1)에서 재렌더해 상체 가림(`_cliff_face_cells` 캐시 + `_front_cliff_cells_for` 판정, 밑 3칸부터 감쇠). 그리드·충돌 불변(순수 시각).
  - **⑥ orphan 폐기:** `_lay_east_band`·`_lay_corner_step`(라이브 참조 0·cliff_test 전용) 제거 + cliff_test 옛 동향밴드·코너스텝 케이스 폐기·①~⑥ 재번호. orphan 에셋 13종(`cliff_e/w_face`·`cliff_e/w/n_lip`·`cliff_out/in_*`) git rm. `_lay_south_band`는 격리 테스트 원시어휘로 유지.
  - **회귀:** 전체 46개 PASS + `cliff_test ⑥`·`front_cliff_test`(신규) 추가. home_full_dump(SW/SE 곡선 코너)·오버행 시뮬 육안 사인오프. **미결(owner 육안 후):** ③ 필드 잔디 변종 강화 방향.

### 10.3 품질 3항목 정식화 → [ADR-0056] (2026-07-07, `grill-with-docs`)

> owner 라이브 확인이 봉합한 회귀 2건(PR#234 절벽 안보임·PR#235 하얀 사각형) 뒤, 남은 **품질 3항목**을 `grill-with-docs`로 정식화해 [ADR-0056](../adr/0056-cliff-quality-visual-overlays-fringe-bakedao-pond-bank.md)에 박제했다. 유실된 Gemini 가이드 대신 현 코드+스타듀 불변식 역설계. **대원칙 = 데이터-안전 국소 오버레이**(`_grid`·충돌·세이브 불변, ④만 세이브-안전 예외).

- **① 상단 완충** = CLIFF_LIP 상단 엣지 ragged 풀 늘어짐 오버레이(새 타일종 X). ★구현 훅 = **`_build_ground16`** 인라인(HOME 지면 오버레이는 흙-지배 flip의 이 함수 — `_build_path_grass_fringe`는 *그 외 구역* 전용이라 절벽 있는 HOME엔 안 붙는다). grass_out(dir=0) *기술*만 재활용·풀 소스 `_bf_grass`.
- **② FACE 원근 AO** = **코드 0**, 아트 베이크 트랙. `cliff_s_face`(하단 감쇄)·`cliff_s_base`(접지 드롭섀도우 0.65) — ⚠️ **§10.2 단계1·2 기존 접지 그림자를 *정밀화*, 이중 금지.** 스펙은 [required-assets-roster] 등록.
- **④ 수변 뱅크** = `_build_home` 하드코딩 2행(연못 북단 CLIFF_FACE+CLIFF_BANK) 삭제 → `_autotile_pond_siblings`(SPIRIT_POND_RECT 북단 유도). Full 일반화(물/길 교차·`cliff_bank_water`·`cliff_beach`)는 **§8대로 S2/S3 연기**. ★통합 초안이 이를 `_autotile_south_cliffs` 인라인 IF로 흡수했으나 고지 마스크(x0..20/y0..26)와 연못(x26..33/y34..40)이 안 겹쳐 **죽은 코드** → sibling 함수가 유일 정답([ADR-0056] §결정-④).
- **§3 불변식:** 하프타일 콜라이더·Y-Sort는 현 엔진에 없음. 실제 = whole-tile SOLID(−8..8) 타일종 충돌 + `_front_cliff_cells_for` 근접 재렌더 front. front 텍스처는 **ImageTexture 변환 필수**(CompressedTexture2D `draw_texture`=하얀사각형).

**미구현(후속 빌드 슬라이스, 워크트리 격리):** ①④ 코드·② 아트 재생성.

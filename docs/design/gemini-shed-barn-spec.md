# [REVISION 4] 축사 — 지붕 윗면 노출 회복 (2026-07-02, owner "그렇게 진행")

> ✅ **실행 완료.** REVISION 3의 half-res 재생성이 *선명도*는 잡았으나 축사 지붕이 다시 **정면 flat 감블**로
> 나와(지붕 윗면 0) 본가·창고와 시점이 어긋났다(owner "축사 지붕 뒤에까지 안 보여"). REVISION 2에서 요구한
> **지붕 Y축 깊이면 노출(§1)** 이 재생성 과정에서 유실된 것.
>
> **교정** = PixelLab `create_map_object` (view=`low top-down`, 88×96, high detail)로 **지붕 윗면이 용마루
> 뒤로 물러나며 보이도록** 프롬프트 강화 재생성 — 명사는 여전히 "wooden farm outbuilding"(barn→빨강벽 방지),
> "sloped ROOF TOP SURFACE clearly visible receding backward … roof depth visible from above like a farmhouse
> roof" 명시. 밑단 풀 덤불(263px)은 초록 우세 픽셀 마스킹으로 제거(접지 그림자는 코드가 절차적으로 깖).
> raw = `assets/_staging_phaseC/pixellab_halfres/barn_hr_v2_clean.png`(→ barn_hr.png 갱신). 파이프라인은
> REVISION 3 그대로 `tools/facade_halfres_x2.py`. **최종 축사 = 152×136 → 150×166**(지붕 윗면만큼 세로 증가).
> home_barn/home_full_dump 육안: 본가·창고와 지붕 윗면 깊이·팔레트·석재 기초 정합 확인. main.gd:303 stale 주석
> (192×128) 교정. 헤드리스 full_dump는 [[headless-test-classcache-flakiness]](Reclaim class_name)로 1회
> 실패 → `--editor --quit` 캐시 재생성 후 성공(로직버그 아님).
>
> **후속(문·길 폭 정합, owner "문이 2칸이자나 입구·길도 2칸으로 잇게"):** 아트 문이 2패널 미닫이인데
> 리세스·진입로가 1칸이라 불일치. 아트 문 중심 = footprint(x3..6) 경계 x5.0 → **2패널 문 = 타일 x4·x5**.
> ① 문 리세스 2칸화(`BARN_EXT_DOOR`=x5 + 신규 `BARN_EXT_DOOR_W`=x4, 둘 다 PATH) ② `_carve_paths`에
> **문 앞 2칸 폭 흙길**(x4·x5, y17..19) 추가 — y16 리세스는 아트 밑에 가려 y17부터 깔아 문 밑단과 이어짐
> ③ 축사 돌봄 RMB([S1-7]) 두 문칸 어디서나 발동하게 확장 ④ home_expansion_test = 문 2칸+진입로 검증으로 갱신
> (livestock 포함 전 통과). 육안: home_barn 덤프에서 2패널 문↔2칸 흙길 정합 확인.
>
> **전수 규칙화(owner "입구 2칸인 건물은 길도 2칸"):** facade 아트 보유 7건물의 문 폭을 월드 타일 그리드로
> 측정 → **2칸 문 = 축사·창고**뿐(둘 다 짝수 폭 footprint라 아트 문이 타일 경계 straddle = 양문). 나머지는
> 1칸: 본가(홀수9·단문 x44)·카페(단문)·멜(홀수5·좁은 양짝)·미호(한옥 미닫이 실폭~1칸)·바나(단문). **창고도
> 축사와 동일 처리** — `STOREHOUSE_EXT_DOOR_E`(x31) 신설·리세스 2칸·`_carve_paths` 진입로 2칸(x30·x31,
> y8..20). 진입 트리거는 서패널(x30)만(enterable 회귀 0 — 재진입 테스트 통과). 다른 구역 건물(만물상·혼백관·
> 생선가게·목공방·대장간·길드 등)은 아직 전용 facade 아트가 없어(placeholder WALL 박스) 문 폭 판정 대상 아님 —
> 각 구역 아트 생성 시 같은 규칙 적용. **원칙: 문 폭(타일) = 입구 앞 진입로 폭.**

---

# [REVISION 3] 창고·축사 — half-res 네이티브 재생성으로 **선명도 + 2px 캐논 동시 달성** (2026-07-02, owner "A안" 확정)

> ✅ **실행 완료.** REVISION 2의 `place_facade.py`(풀해상 생성 → **÷2 BOX 청키화**)는 그 ÷2 다운샘플이
> 선명한 기와·판자결을 뭉개, 창고·축사가 본가보다 흐릿·뭉툭했다(**owner 지적 "선명도 문제"가 정확한 진단** —
> "기와 굵기"는 결과였을 뿐). [asset-ruleset §0/§0.1]의 정석은 *half-res 생성 → ×2 nearest*(본가
> `assets/_staging_phaseC/chunky/house_src.png` 144px가 그 예)인데, place_facade가 *풀해상 → ÷2*로 이를 어긴 게 근본 원인.
>
> **교정 = 창고·축사를 PixelLab `create_map_object`로 half-res 네이티브 재생성**(창고 96×104·축사 88×80,
> view=low top-down) → `tools/facade_halfres_x2.py`(알파 하드임계 → ×2 nearest → bbox 트림)로 굳힘.
> 결과: **홀수 런 비율 0%(완벽 2px 블록 = 캐논 준수) + 본가급 선명도** 동시 달성 — B(÷2 청키화=캐논O·선명X)와
> C(원본 1px=선명O·캐논X)의 트레이드오프를 모두 해소. raw = `assets/_staging_phaseC/pixellab_halfres/{storehouse,barn}_hr.png`.
> 최종 = 창고 158×162 / 축사 152×136. 축사는 **갈색 목재벽 + 빨간 감블지붕**(owner 요청 — 프롬프트에 "barn"이
> 들어가면 빨간벽 헛간이 강제돼, 명사를 "wooden farm outbuilding"으로 바꿔 교정).
>
> **본가 그림자 부양 이슈**(별건, 같은 세션)도 해결: `house_ext.png` 하단의 부유 픽셀(y296~297 좌우 6px) + 공백
> 14행이 `getbbox` 트림을 실제 밑단보다 16px 아래로 잡아 접지 타원이 떠 있었다 → 하단 트림(298→282px)으로 밀착.

---

# [REVISION 2] 창고(Shed)·축사(Barn) — 본가와 **지붕 시점 통일**(3/4 지붕 윗면 노출)

> ✅ **실행 완료 (2026-07-02).** Gemini 대기 대신 **PixelLab `create_map_object` view="low top-down"**로 재생성(owner 승인 "지금 진행"). facade+지붕 윗면 깊이는 low top-down이 정확히 대응. 산출→`tools/place_facade.py`(2px 청크화+bbox 트림, chunkiness 1.00 정합)→`assets/buildings/{storehouse,barn}_ext.png` 교체(창고 156×160·축사 164×144). raw 소스=`assets/_staging_phaseC/pixellab/{storehouse,barn}_src.png`. home_full_dump 육안: 본가와 지붕 윗면 깊이·팔레트·석재 기초·밀착 그림자 정합 확인. 아래 명세는 생성 프롬프트의 근거로 보존.


## 왜 다시 손보나 (육안 피드백 2026-07-02)
home_full_dump 육안 결과 **창고·축사가 본가와 시점이 어긋난다.** 본가는 지붕의 **윗면(Y축 깊이면)이 뒤로 물러나며 보여** 입체감이 있는데, 창고·축사는 지붕이 **정면에 눌러붙은 납작한 삼각형/곡면**이라 종이 판넬처럼 보인다. [REVISION 1](이 파일 이전 판)에서 "처마 1~2px 돌출"만 요구한 게 원인 — 그건 지붕 *윗면 노출*이 아니라 얇은 처마 그림자였다. 이번 판은 **본가(gemini-farmhouse-spec)와 동일한 지붕 규격**을 명시한다.

> **그림자(공중 부양 느낌)는 코드에서 이미 교정됨** — 접지 타원을 밑단에 밀착시키는 수정을 `_blit_facade_anchored`(main.gd)·`home_full_dump.gd`에 적용 완료. 이 스펙은 **시점(지붕)만** 다룬다. 아트에 접지 그림자를 굽지 말 것(코드가 절차적으로 깐다 — [asset-ruleset §11]).

## 0. 불변 규격 (바꾸지 말 것)
* **완전한 정면 Facade**: 좌/우 측면 벽 렌더 **전면 금지**(이소메트릭 금지). 카메라를 똑바로 바라보는 정면 벽 + **지붕 윗면 깊이만** 상단 노출. ([ADR-0036] §2)
* **문 중심 = rect 중앙 하단**(좌우대칭): 창고 문열 30 / 축사 문열 6. 문 픽셀 중심 열이 좌우 정중앙에 오게.
* **Chunky 픽셀**: 진한 단색 외곽선 + 굵은 2px 블록 그레인(얇은 그라데이션 금지).
* **따뜻한 팔레트 유지**: 지금 라이브의 목재 브라운 + 벽돌빛 지붕 톤 그대로(구버전 다크 톤으로 회귀 금지).
* **NW 광원**(좌상단): 밝은 면=좌/상, 그림자=우/하. ([asset-ruleset] §1)
* **배경 완전 투명**(단색 회색 배경 금지 — flood-fill 트림 대상).

## 1. ★핵심 — 지붕 Y축 깊이면(윗면) 노출 (본가와 동일)
* 본가처럼 **지붕의 윗면(하늘을 보는 면)이 용마루 뒤로 물러나며 보이게** 그릴 것. 즉 정면 지붕 경사면 위쪽에 **지붕 윗면 슬랩이 1~2 논리 타일(렌더 32~64px) 깊이로 노출**되어야 한다. "정면 삼각형 실루엣"만 있고 윗면이 0인 현재 상태 금지.
* **축사(맞배/감블 지붕)**: 곡면 감블 지붕도 **용마루에서 뒤로 물러나는 윗면 한 단**을 반드시 노출. 정면 곡면 아래에 어두운 처마 그늘, 그 위에 밝은 지붕 윗면 슬랩.
* **창고(박공 지붕)**: 박공 삼각형 위에 **뒤로 눕는 지붕 윗면**을 본가 비율만큼 노출. 현재의 얇은 지붕 띠 → 본가급 깊이 슬랩으로 확장.
* 지붕 윗면은 **정면 경사면보다 명도 한 단 낮게**(하늘을 보지만 광원이 NW라 살짝 눌린 톤) — 본가 지붕의 윗면/경사면 명도 대비를 그대로 따를 것.

## 2. 하단 주춧돌(지면 flush) — 유지·정합
* **창고**: 하단에 회색 돌 주춧돌 3px 슬랩(현재도 있음 — 유지). 지면 flush.
* **축사**: 대형 슬라이딩 도어 하단에 두터운 석조 받침대(현재도 있음 — 유지). 지면 flush.
* (접지 그림자는 코드가 깔므로 아트 밑단은 이 주춧돌에서 **깔끔히 끝날 것** — 밑단 아래로 늘어지는 풀·그림자 금지.)

## 3. 문틀 입체화 — 유지
* 문짝이 벽면 안쪽으로 들어가 보이게 문틀 상단·좌측에 어두운 아웃라인(Recessed Door).

## 4. 산출·규격
* **창고**: footprint 6×6 타일(STOREHOUSE_EXT_RECT). 지붕 윗면 노출로 art 높이가 footprint(192px)보다 **위로 솟는 것 정상**(bottom-center 앵커 — 밑단=footprint 하단, 지붕이 위 타일로 오버행).
* **축사**: footprint 4×3 타일(BARN_EXT_RECT). 감블 지붕 윗면 노출로 위로 솟음.
* 밑단(주춧돌) 폭 = footprint 폭에 가깝게(좌우 대칭). 지붕 오버행은 좌우로 살짝 넓어도 됨.
* 산출 후 파이프라인: `process_chunky_phaseC.py`(배경 트림+2px 청크) → `assets/buildings/{storehouse,barn}_ext.png` 교체 → `home_full_dump.gd`로 육안 확인.

## 참고 비교
* **본가(목표 시점)** = `assets/buildings/house_ext.png` — 붉은 지붕 윗면이 뒤로 물러나며 보이는 그 입체감이 정답.
* **현재 창고/축사(고칠 것)** = 지붕 윗면 0, 정면 눌러붙음.

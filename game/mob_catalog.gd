extends RefCounted
class_name MobCatalog
# ★[S5-T5 / ADR-0063 결정 8] 잡귀 로스터 — 갱도 6종(밴드당 2 · 행동 아키타입 4 커버).
#
# 목적: "무엇이 어느 깊이에 나오고, 몇 대 맞으면 죽고, 얼마나 아프고, 어떻게 움직이는가"의 단일
#       출처. WeaponCatalog(무기 5종)·FishCatalog(어종)와 **문법이 1:1**이다 — 순수 static 데이터 +
#       조회. 개체 상태(위치·HP·행동 위상)는 Mob(mob.gd)이 들고, 배치는 MineFloors가 굴린다.
#
# 세 파일의 경계(어기면 T5 설계가 무너진다):
#   · MobCatalog(여기) = **종 데이터**. 무대·좌표·시계·인벤토리·렌더를 하나도 모른다.
#   · Mob(mob.gd)      = **개체 상태 + 행동 스텝**(순수 함수 — 입력은 dt·플레이어 위치·지형 콜백뿐).
#   · MineFloors       = **배치**(층 생성 시 결정 롤로 "어디에 무엇이 서는가"만).
#   · main             = **배선**(틱 폴링·접촉 피해·스윙 판정·드랍·그레이박스 렌더).
#
# 설계 메모(어기면 ADR-0063 결정 8·9 / ADR-0031 결정 3 위반):
#   - **갱도 잡귀는 관계-중립**이다. 이 파일엔 바나·affinity·호감도 참조가 한 줄도 없고, 처치 보상은
#     전투 base XP + 자재 드랍뿐이다(나락만 바나 도메인 — ADR-0031 결정 3).
#   - ★[S5-T7] **나락 강몹 3종·보스 3기가 합류했다**(아래 "나락 로스터" 절). 다만 `MOBS`에 섞지 않고
#     `NARAK_MOBS`·`BOSSES` 별 dict에 둔다 — 갱도 밴드 게이팅(`spawn_pool`)이 60층 축을 도는데
#     무한 깊이 종이 그 표에 끼면 축이 오염된다(ADR-0063 결정 8 후단이 경고한 그 지점).
#     조회(`has`/`max_hp`/…)만 `_entry`로 세 dict를 아울러, Mob·main은 어느 dict인지 몰라도 된다.
#   - **아키타입은 4개뿐**이다(통통·추적·위장·원거리). 표의 6종은 이 넷 위에 *플래그*(배회·넉백
#     저항·돌 부수기)를 얹어 갈린다 — 새 아키타입을 만들지 않는 이유는 ADR-0063이 "아키타입 4 커버"로
#     못 박았고, 행동 코드가 6갈래로 갈리면 결정적 스텝 검증이 6배로 늘기 때문이다.
#     · 그슨대 "배회·충돌" = 추적 + `wanders`(어그로 밖에선 어슬렁) + `breaks_rocks`(막히면 돌을 깬다)
#     · 불가사리 "넉백 저항·중장" = 추적 + `kb_resist`(★넉백 축 자체가 장비 클러스터 서랍이라
#       지금은 플래그 보관 — ADR-0063 결정 4 "몹 체급별 넉백 차이는 서랍")
#   - **HP/데미지/XP는 ADR-0063 결정 8 표 그대로**(스타듀 대응 몹 1:1 상속). 이동 속도·어그로 반경·
#     점프 주기·사거리·드랍률은 표에 없던 값이라 *이 태스크가 새로 정한 잠정치*다(아래 주석에 근거).
#   - 그레이박스 색은 여기 두지 않는다 — main의 `_MOB_COLORS`가 든다(`_MINE_NODE_COLORS` 선례:
#     카탈로그는 렌더를 모른다).

# ── 행동 아키타입(4종 — ADR-0063 결정 8) ─────────────────────────────────────
const ARCH_HOP := "hop"            # 통통 접근·점프 돌진(멈춤 ↔ 짧은 돌진 반복 — Green Slime 결)
const ARCH_CHASE := "chase"        # 등속 추적(부유·중장·배회형이 공유하는 축 — Bat/Golem/Metal Head)
const ARCH_DISGUISE := "disguise"  # 바위 위장(정지·무해 → 곡괭이 타격으로 활성화 — Rock Crab)
const ARCH_RANGED := "ranged"      # 원거리 화염구(제자리·사거리 안이면 발사 — Squid Kid)
const ARCHETYPES := [ARCH_HOP, ARCH_CHASE, ARCH_DISGUISE, ARCH_RANGED]

# ── 종 id(코드용 안정 id — 세이브엔 안 들어간다: 몹은 층 한정 비영속) ─────────
const HEOTGEOT := "mob_heotgeot"        # 헛것(1층+ · Green Slime 대응)
const EODUKKAEBI := "mob_eodukkaebi"    # 어둑깨비(11층+ · Bat 대응)
const DALGYAL := "mob_dalgyal"          # 달걀귀신(21층+ · Rock Crab 대응)
const GEUSEUNDAE := "mob_geuseundae"    # 그슨대(21층+ · Stone Golem 대응)
const BULGASARI := "mob_bulgasari"      # 불가사리(41층+ · Metal Head 대응)
const HWAGWI := "mob_hwagwi"            # 화귀(41층+ · Squid Kid 대응)

# ── 잡귀 부산물 2종(★신설 아이템 — ItemCatalog.MATERIALS에 등록) ─────────────
# "잡귀를 잡으면 무엇이 남는가"의 자리. 카페·제작 하류 소재이고 **품질 무차원 CAT_MATERIAL**이다
# (원목·수액·광물과 같은 판단 — 품질은 줍기·릴 격투의 축). id 상수는 ItemCatalog가 진실원이라
# 여기서는 **문자열 리터럴로 둔다**(const 초기화식에서 타 클래스 상수를 안 읽는 이 저장소의 관례 —
# main.MINE_ROCK_COST 주석과 같은 이유). mob_test가 `ItemCatalog.has_item`으로 두 쪽을 대조한다.
const DROP_NEOKGARU := "neokgaru"       # 넋가루 — 흩어진 잡귀가 남기는 회백색 가루(범용)
const DROP_HONBULSSI := "honbulssi"     # 혼불씨 — 잡귀 속에 남은 불씨(심층 종 산출)

# ── 종 표(ADR-0063 결정 8 — HP/데미지/XP는 원문 그대로) ──────────────────────
# 스키마:
#   name_ko    : 표시명(*명명 전부 잠정* — ADR-0063 결정 8 owner 큐)
#   arch       : 위 4 아키타입 중 하나
#   hp         : 최대 HP(★ADR 표 그대로)
#   damage     : 플레이어에게 주는 **고정 데미지**(변동 롤 없음 — ADR-0063 결정 4)
#   xp         : 처치 전투 XP(★ADR 표 그대로 · 관계-중립 base)
#   floor_min  : 출현 시작 층 · floor_max: 0 = 무제한(상위 종이 하위를 대체하지 않고 얹힌다 — 노드 결)
#   weight     : 스폰 가중(같은 밴드 안 등장 비율)
#   speed      : 이동 속도(px/s · 0 = 제자리). ★플레이어 160px/s 대비
#   aggro      : 어그로 반경(칸). 이 안에 들어오면 추적·발사가 시작된다
#   wanders    : 어그로 밖에서 어슬렁거리나(false = 제자리 대기)
#   kb_resist  : 넉백 저항(★플래그 보관 — 넉백 축은 장비 클러스터 서랍)
#   breaks     : 길이 막히면 일반 돌을 부수나(★부순 바위 = 채광 XP 0 — ADR-0063 결정 9)
#   reach      : 원거리 사거리(칸 · 0 = 근접 전용)
#   cooldown   : 발사 간격(초 · 원거리 전용)
#   shot_speed : 화염구 속도(px/s · 원거리 전용)
#
# ★ 잠정치의 근거(ADR 표에 없어 이 태스크가 정한 값 — 보고에 목록화됨):
#   · 속도는 **전부 플레이어(160px/s)보다 느리다**. 스타듀 갱도의 계약이 "도망칠 수 있다"이고,
#     추격을 못 떼면 이중 시계(채굴 ↔ 전투)가 전투 일방으로 무너진다.
#     헛것 = 돌진 순간만 빠르고 평균이 느림 / 어둑깨비 = 가장 빠름(박쥐) / 그슨대 = 가장 느림(골렘).
#   · 어그로 반경 6~9칸 = 화면 반쪽(내부해상도 640×360 → 20×11칸). "화면에 보이면 온다"가 기준.
#   · 화귀는 HP 1 유리대포라 **접근 전 처리**가 정답이 되게 사거리(7)를 어그로 밖으로 두지 않았다.
const MOBS := {
	HEOTGEOT: {
		"name_ko": "헛것", "arch": ARCH_HOP,
		"hp": 24, "damage": 5, "xp": 3,
		"floor_min": 1, "floor_max": 0, "weight": 40,
		"speed": 120.0, "aggro": 7.0, "wanders": true, "kb_resist": false, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	EODUKKAEBI: {
		"name_ko": "어둑깨비", "arch": ARCH_CHASE,
		"hp": 24, "damage": 6, "xp": 3,
		"floor_min": 11, "floor_max": 0, "weight": 34,
		"speed": 110.0, "aggro": 9.0, "wanders": true, "kb_resist": false, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	DALGYAL: {
		"name_ko": "달걀귀신", "arch": ARCH_DISGUISE,
		"hp": 30, "damage": 5, "xp": 4,
		"floor_min": 21, "floor_max": 0, "weight": 22,
		"speed": 60.0, "aggro": 6.0, "wanders": false, "kb_resist": false, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	GEUSEUNDAE: {
		"name_ko": "그슨대", "arch": ARCH_CHASE,
		"hp": 45, "damage": 8, "xp": 5,
		"floor_min": 21, "floor_max": 0, "weight": 26,
		"speed": 48.0, "aggro": 8.0, "wanders": true, "kb_resist": false, "breaks": true,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	BULGASARI: {
		"name_ko": "불가사리", "arch": ARCH_CHASE,
		"hp": 40, "damage": 15, "xp": 6,
		"floor_min": 41, "floor_max": 0, "weight": 26,
		"speed": 84.0, "aggro": 9.0, "wanders": true, "kb_resist": true, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	HWAGWI: {
		"name_ko": "화귀", "arch": ARCH_RANGED,
		"hp": 1, "damage": 18, "xp": 15,
		"floor_min": 41, "floor_max": 0, "weight": 18,
		"speed": 0.0, "aggro": 7.0, "wanders": false, "kb_resist": false, "breaks": false,
		"reach": 7.0, "cooldown": 2.2, "shot_speed": 96.0,
	},
}

# 밴드 순 id 목록(테스트·아트 로스터 순회의 단일 출처 — dict 삽입 순서를 신뢰하지 않는다).
const _ORDER := [HEOTGEOT, EODUKKAEBI, DALGYAL, GEUSEUNDAE, BULGASARI, HWAGWI]

# ══ ★[S5-T7 / ADR-0063 결정 7·8] 나락 로스터 — 강몹 3종 + 관문 보스 3기 ═══════════
# 불교 지옥 결(나락(奈落) = 나라카 정합). HP/데미지/XP는 ADR-0063 결정 8 후단 표 그대로이고,
# 나머지(속도·어그로·사거리)는 갱도 6종과 같은 결로 이 태스크가 정한 *잠정치*다.
#
# ★ **새 아키타입을 만들지 않았다** — 셋 다 기존 4종(통통·추적·위장·원거리) 위에 플래그만 얹는다:
#   · 야차 "고속 돌진" = 통통(HOP). 멈춤↔돌진 리듬 그대로에 속도만 갱도 최속(120)보다 위(150)다.
#     평균 속도는 여전히 1/4로 깎여(HOP_PAUSE:HOP_DASH) 플레이어 160px/s에서 도망칠 수 있다.
#   · 나찰 "원거리+고HP" = 원거리(RANGED). 화귀가 HP 1 유리대포인 것과 **정반대 극**(190)이라,
#     같은 아키타입이 깊이에 따라 전혀 다른 문제로 읽힌다(새 갈래 0 · 행동 검증 비용 0).
#   · 아귀 "탱커 추적" = 추적(CHASE) + `kb_resist`. 불가사리의 중장 축을 그대로 물려받는다.
# ★ 보스도 같은 규율이다 — **페이즈 없음·미니언 없음**(ADR-0063 "패턴 단순" 서랍 준수). 고HP·고데미지
#   + 넓은 어그로가 전부이고, 나찰왕만 원거리다. 미니언 스폰은 Mob.step 이벤트 축을 하나 늘려야 해서
#   (순수 스텝 규율의 표면적 확대) 허용된 상한 안에서도 안 넣었다 — *스코프 판단, 보고에 명시*.

# ── 나락 강몹 3종 ───────────────────────────────────────────────────────────
const YACHA := "mob_yacha"        # 야차(夜叉) — 고속 돌진
const NACHAL := "mob_nachal"      # 나찰(羅刹) — 원거리 + 고HP
const AGWI := "mob_agwi"          # 아귀(餓鬼) — 탱커 추적

# ── 관문 보스 3기(깊이 10/25/50 보장 출현 — NarakFloors.BOSS_BY_DEPTH와 같은 문자열) ──
const BOSS_OKJOL := "boss_okjol"              # 문지기 옥졸(獄卒) — 깊이 10
const BOSS_NACHALWANG := "boss_nachalwang"    # 업화 나찰왕(羅刹王) — 깊이 25
const BOSS_DAEAGWI := "boss_daeagwi"          # 심연 대아귀(大餓鬼) — 깊이 50

# 보스 드랍 = 카페 프리미엄 소재(★신설 아이템 1종 — ItemCatalog.MATERIALS에 등록).
# *명명 잠정*(owner 큐): 「나락혼정(奈落魂精)」 — 기존 혼탄·혼불씨의 혼(魂) 계열 위에 얹은 최상위
# 등급. 소비처는 S6(카페 가공)이라 지금은 **등록 + 드랍**까지다(ADR-0063 결정 7 "소비처는 S6").
const DROP_NARAK_HONJEONG := "narak_honjeong"

# 나락 강몹 표 — 스키마는 MOBS와 **완전 동일**하다(`_entry`가 둘을 구분 없이 읽는다).
# ★ `floor_min`은 여기서 **나락 깊이**를 뜻한다(갱도 층이 아니다 — 축이 다른 표라 dict가 갈려 있다).
const NARAK_MOBS := {
	YACHA: {
		"name_ko": "야차", "arch": ARCH_HOP,
		"hp": 150, "damage": 23, "xp": 20,
		"floor_min": 1, "floor_max": 0, "weight": 38,
		"speed": 150.0, "aggro": 9.0, "wanders": true, "kb_resist": false, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	NACHAL: {
		"name_ko": "나찰", "arch": ARCH_RANGED,
		"hp": 190, "damage": 25, "xp": 20,
		"floor_min": 5, "floor_max": 0, "weight": 30,
		"speed": 0.0, "aggro": 9.0, "wanders": false, "kb_resist": false, "breaks": false,
		"reach": 8.0, "cooldown": 1.8, "shot_speed": 120.0,
	},
	AGWI: {
		"name_ko": "아귀", "arch": ARCH_CHASE,
		"hp": 260, "damage": 30, "xp": 20,
		"floor_min": 15, "floor_max": 0, "weight": 26,
		"speed": 70.0, "aggro": 10.0, "wanders": true, "kb_resist": true, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
}
const _NARAK_ORDER := [YACHA, NACHAL, AGWI]

# 관문 보스 표 — `floor_min`은 **보장 출현 깊이**이고 `weight`는 0이다(가중 롤에 안 들어간다 =
# 확정 배치 경로로만 선다. NarakFloors._scatter_mobs가 보스 층에서 pool을 아예 안 본다).
const BOSSES := {
	BOSS_OKJOL: {
		"name_ko": "문지기 옥졸", "arch": ARCH_CHASE,
		"hp": 500, "damage": 28, "xp": 120,
		"floor_min": 10, "floor_max": 0, "weight": 0,
		"speed": 62.0, "aggro": 14.0, "wanders": false, "kb_resist": true, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
	BOSS_NACHALWANG: {
		"name_ko": "업화 나찰왕", "arch": ARCH_RANGED,
		"hp": 800, "damage": 34, "xp": 260,
		"floor_min": 25, "floor_max": 0, "weight": 0,
		"speed": 0.0, "aggro": 14.0, "wanders": false, "kb_resist": true, "breaks": false,
		"reach": 10.0, "cooldown": 1.4, "shot_speed": 140.0,
	},
	BOSS_DAEAGWI: {
		"name_ko": "심연 대아귀", "arch": ARCH_CHASE,
		"hp": 1200, "damage": 42, "xp": 500,
		"floor_min": 50, "floor_max": 0, "weight": 0,
		"speed": 74.0, "aggro": 16.0, "wanders": false, "kb_resist": true, "breaks": false,
		"reach": 0.0, "cooldown": 0.0, "shot_speed": 0.0,
	},
}
const _BOSS_ORDER := [BOSS_OKJOL, BOSS_NACHALWANG, BOSS_DAEAGWI]

# ── 드랍 표(*드랍률·수량 전부 잠정* — 스타듀 대응 몹 상속) ────────────────────
# 스키마: [{id, chance(0~1), min, max}] — 항목마다 독립 롤(한 몹이 둘 다 흘릴 수 있다).
# ★ 신규 아이템은 2종(넋가루·혼불씨)뿐이고 나머지는 **기존 광물 재사용**이다: 달걀귀신·그슨대가
#   돌을 흘리고(Rock Crab·Stone Golem 1:1) 불가사리가 유철 광석을 흘린다(Metal Head 1:1).
#   아이템 남발 없이 "잡귀도 채광 경제에 흘러든다"가 성립한다.
# ★ id를 리터럴로 두는 이유 = DROP_* 상수와 같다(const 초기화식 관례).
# ★[S7-T3 / ADR-0065 결정 4] "희귀 드랍"의 정의 = **표에 이 확률 이하로 걸린 항목**. 별도 rare 플래그를
#   달지 않은 이유: 희귀함은 이미 chance 숫자가 말하고 있고, 플래그를 달면 표와 어긋날 수 있는 진실이
#   둘 생긴다. 지금 이 문턱에 걸리는 건 나락철(0.10·0.15) — 심층 광석이라 결도 정확히 맞는다.
#   새 드랍을 낮은 확률로 추가하면 자동으로 희귀 취급이 된다(데이터 주도 — 코드 수정 0).
const RARE_DROP_CHANCE := 0.20

const DROPS := {
	HEOTGEOT: [{"id": DROP_NEOKGARU, "chance": 0.70, "min": 1, "max": 2}],
	EODUKKAEBI: [{"id": DROP_HONBULSSI, "chance": 0.55, "min": 1, "max": 1}],
	DALGYAL: [
		{"id": "stone", "chance": 0.60, "min": 1, "max": 2},
		{"id": DROP_NEOKGARU, "chance": 0.25, "min": 1, "max": 1},
	],
	GEUSEUNDAE: [
		{"id": "stone", "chance": 0.75, "min": 1, "max": 3},
		{"id": DROP_NEOKGARU, "chance": 0.30, "min": 1, "max": 1},
	],
	BULGASARI: [
		{"id": "ore_yucheol", "chance": 0.40, "min": 1, "max": 1},
		{"id": DROP_HONBULSSI, "chance": 0.40, "min": 1, "max": 1},
	],
	HWAGWI: [
		{"id": DROP_HONBULSSI, "chance": 0.80, "min": 1, "max": 2},
		{"id": DROP_NEOKGARU, "chance": 0.30, "min": 1, "max": 1},
	],
	# ── ★[S5-T7] 나락 강몹 — 갱도 잡귀보다 두꺼운 자재 + 심층 산출(혼불씨·나락철) ──
	YACHA: [
		{"id": DROP_HONBULSSI, "chance": 0.70, "min": 1, "max": 2},
		{"id": DROP_NEOKGARU, "chance": 0.40, "min": 1, "max": 2},
	],
	NACHAL: [
		{"id": DROP_HONBULSSI, "chance": 0.80, "min": 1, "max": 3},
		{"id": "ore_narakcheol", "chance": 0.10, "min": 1, "max": 1},
	],
	AGWI: [
		{"id": DROP_NEOKGARU, "chance": 0.85, "min": 2, "max": 4},
		{"id": "ore_narakcheol", "chance": 0.15, "min": 1, "max": 1},
	],
	# ── ★[S5-T7] 관문 보스 — 나락혼정 **확정 드랍**(chance 1.0)이 마일스톤의 물질적 형태다.
	#    깊을수록 수량이 는다(10/25/50 → 1/2/3). 서사 텍스트는 0이다(CONTEXT 확정).
	BOSS_OKJOL: [{"id": DROP_NARAK_HONJEONG, "chance": 1.0, "min": 1, "max": 1}],
	BOSS_NACHALWANG: [{"id": DROP_NARAK_HONJEONG, "chance": 1.0, "min": 2, "max": 2}],
	BOSS_DAEAGWI: [{"id": DROP_NARAK_HONJEONG, "chance": 1.0, "min": 3, "max": 3}],
}

# ── 조회 ─────────────────────────────────────────────────────────────────────
# ★[S5-T7] 세 표(갱도 6 · 나락 3 · 보스 3)를 아우르는 단일 진입점. 아래 조회들이 전부 이걸 지나므로
#   Mob·main·CombatSkill은 "이 종이 어느 표에 있나"를 영영 모른다(로스터 확장이 조회 코드를 안 건드린다).
#   ★ `set_*` 정적 이름을 안 쓰는 관례와 같은 이유로 이름을 `_entry`로 둔다(엔진 메서드 흡수 회피).
static func _entry(kind: String) -> Dictionary:
	if MOBS.has(kind):
		return MOBS[kind]
	if NARAK_MOBS.has(kind):
		return NARAK_MOBS[kind]
	if BOSSES.has(kind):
		return BOSSES[kind]
	return {}

static func has(kind: String) -> bool:
	return not _entry(kind).is_empty()

# ★ 갱도 6종만이다(로스터 순회의 기존 계약 — mob_test가 이 크기를 잠근다). 나락·보스는 아래 별 함수.
static func kinds() -> Array:
	return _ORDER

static func narak_kinds() -> Array:
	return _NARAK_ORDER

static func boss_kinds() -> Array:
	return _BOSS_ORDER

# 이 종이 관문 보스인가(드로우 크기·처치 마일스톤 판정의 단일 술어).
static func is_boss(kind: String) -> bool:
	return BOSSES.has(kind)

static func name_of(kind: String) -> String:
	var e := _entry(kind)
	return String(e["name_ko"]) if not e.is_empty() else ""

static func arch_of(kind: String) -> String:
	var e := _entry(kind)
	return String(e["arch"]) if not e.is_empty() else ""

static func max_hp(kind: String) -> int:
	var e := _entry(kind)
	return int(e["hp"]) if not e.is_empty() else 0

# 플레이어에게 주는 고정 데미지(ADR-0063 결정 4 — 변동 롤 없음).
static func damage_of(kind: String) -> int:
	var e := _entry(kind)
	return int(e["damage"]) if not e.is_empty() else 0

# 처치 전투 XP(관계-중립 base — ADR-0031 결정 3).
static func xp_of(kind: String) -> int:
	var e := _entry(kind)
	return int(e["xp"]) if not e.is_empty() else 0

static func speed_of(kind: String) -> float:
	var e := _entry(kind)
	return float(e["speed"]) if not e.is_empty() else 0.0

static func aggro_tiles(kind: String) -> float:
	var e := _entry(kind)
	return float(e["aggro"]) if not e.is_empty() else 0.0

static func wanders(kind: String) -> bool:
	var e := _entry(kind)
	return bool(e["wanders"]) if not e.is_empty() else false

# 넉백 저항 — ★플래그 보관. 넉백 감쇠 배선은 장비 클러스터 서랍이 열릴 때(ADR-0063 결정 4).
static func kb_resist(kind: String) -> bool:
	var e := _entry(kind)
	return bool(e["kb_resist"]) if not e.is_empty() else false

# 길이 막히면 일반 돌을 부수나(★그슨대 하나 — 부순 바위 = 채광 XP 0, ADR-0063 결정 9).
static func breaks_rocks(kind: String) -> bool:
	var e := _entry(kind)
	return bool(e["breaks"]) if not e.is_empty() else false

static func reach_tiles(kind: String) -> float:
	var e := _entry(kind)
	return float(e["reach"]) if not e.is_empty() else 0.0

static func cooldown_of(kind: String) -> float:
	var e := _entry(kind)
	return float(e["cooldown"]) if not e.is_empty() else 0.0

static func shot_speed(kind: String) -> float:
	var e := _entry(kind)
	return float(e["shot_speed"]) if not e.is_empty() else 0.0

static func is_ranged(kind: String) -> bool:
	return arch_of(kind) == ARCH_RANGED

# 위장형인가 — 스폰 직후 무해·부동이고 곡괭이 타격으로 깨어난다(Mob.awake).
static func is_disguise(kind: String) -> bool:
	return arch_of(kind) == ARCH_DISGUISE

# ── 밴드 게이팅(MineFloors 배치가 읽는 유일한 접점) ──────────────────────────
# 이 층에 나올 수 있는 종 목록(표 순서 보존 = 결정적). 노드 `MineFloors.node_pool`과 완전 동형이다.
static func spawn_pool(floor_no: int) -> Array:
	var out: Array = []
	for kind: String in _ORDER:
		var e: Dictionary = MOBS[kind]
		if floor_no < int(e["floor_min"]):
			continue
		var fmax := int(e["floor_max"])
		if fmax > 0 and floor_no > fmax:
			continue
		out.append(kind)
	return out

# ★[S5-T7 / ADR-0063 결정 7] **나락 전용 스폰 풀** — 갱도 `spawn_pool`을 재사용하지 않는다.
#   저쪽 밴드 축은 60층 상한을 전제로 짜여 있어서, 무한 깊이를 그 표에 흘리면 41층+ 갱도 종이
#   깊이 999에도 그대로 나오는(= 나락이 갱도의 연장이 되는) 오염이 생긴다. 표가 갈린 이상 풀도 갈린다.
#   ★ 여기 나오는 건 나락 3종뿐이다 — 갱도 잡귀는 한 마리도 안 섞인다(narak_run_test가 단언).
static func narak_pool(depth: int) -> Array:
	var out: Array = []
	if depth < 1:
		return out
	for kind: String in _NARAK_ORDER:
		if depth < int(NARAK_MOBS[kind]["floor_min"]):
			continue
		out.append(kind)
	return out

static func weight_of(kind: String) -> int:
	var e := _entry(kind)
	return int(e["weight"]) if not e.is_empty() else 0

# 가중 롤 — rng를 **인자로 받는다**(시드 소유·순차 소비 순서는 배치 쪽 책임. WeaponCatalog.roll_damage
# 와 같은 판단). 풀이 비면 ""(호출 측이 스폰을 건너뛴다).
static func roll_kind(pool: Array, rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		return ""
	var total := 0
	for kind: String in pool:
		total += weight_of(kind)
	if total <= 0:
		return ""
	var roll := rng.randi_range(0, total - 1)
	for kind: String in pool:
		roll -= weight_of(kind)
		if roll < 0:
			return kind
	return String(pool[pool.size() - 1])

# ── 처치 드랍(순수·결정적) ───────────────────────────────────────────────────
# 반환 = [{"id": String, "count": int}]. 시드는 호출 측이 만든다(main은 day·층·스폰 인덱스를 엮어
# 넘긴다 — 좌표 해시 금지 규율은 몹에도 그대로 적용된다: 이웃 몹이 연속값을 받으면 안 된다).
# ★ RNG 순차 소비: 표 순서대로 ①확률 롤 → ②수량 롤. 순서를 바꾸면 같은 시드가 다른 답을 낸다.
# ★[S7-T3 / ADR-0065 결정 4] 배수 2종(둘 다 기본 1.0 = 정확히 중립 — 무인자 호출 결과열 불변):
#   drop_scale : 일반 항목 확률 배수 · rare_scale : **희귀** 항목 확률 배수(혼불 바람이 1.5/2.0을 건다).
#   ★ 확률만 곱하고 **수량 롤은 안 건드린다** — 두 롤의 소비 순서·횟수가 그대로라 배수를 걸어도
#     스트림이 안 흔들린다(같은 시드에서 "몇 개 나오나"는 같고 "나오나 마나"만 갈린다).
#   ★ 확률은 1.0으로 클램프한다. 그래서 보스의 확정 드랍(chance 1.0)은 배수를 먹어도 그대로 1.0이다.
# ★[S7-T4 / ADR-0065 결정 5 ③] `luck_bonus` = 명부의 운 가산(기본 0.0 = 정확히 중립 — 무인자 호출
#   결과열 불변). **순서가 계약이다: base에 운을 먼저 더하고, 그 합에 날씨 배수를 곱한다**
#   ((base + luck) × scale). 운은 "명부가 오늘 나에게 얼마를 더 얹느냐"라 확률의 원점을 옮기는
#   축이고, 날씨는 그렇게 정해진 확률을 통째로 키우는 축이다 — 순서를 뒤집으면 혼불 바람이 운까지
#   1.5배로 증폭해 하루 변동폭이 두 축의 곱으로 튄다.
#   ★ 확정 드랍(chance ≥ 1.0 = 보스 관문 보상)은 운도 배수도 **안 탄다**: 흉일에 관문 보상이 사라지면
#     "관문을 넘으면 반드시 준다"는 계약이 깨진다(운은 곁다리를 흔들지 본상을 흔들지 않는다).
static func roll_drops(kind: String, seed_value: int,
		drop_scale: float = 1.0, rare_scale: float = 1.0, luck_bonus: float = 0.0) -> Array:
	var out: Array = []
	if not has(kind):
		return out
	var table: Array = DROPS.get(kind, [])
	if table.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mob_drop:%s:%d" % [kind, seed_value])
	for e: Dictionary in table:
		var base := float(e["chance"])
		var scale: float = rare_scale if base <= RARE_DROP_CHANCE else drop_scale
		# 확정 드랍은 base 그대로 통과(운·배수 면제) — 그 외만 (base + 운) × 배수.
		var p: float = base if base >= 1.0 else (base + luck_bonus) * maxf(scale, 0.0)
		var hit := rng.randf() < clampf(p, 0.0, 1.0)
		var n := rng.randi_range(int(e["min"]), int(e["max"]))
		if hit and n > 0:
			out.append({"id": String(e["id"]), "count": n})
	return out

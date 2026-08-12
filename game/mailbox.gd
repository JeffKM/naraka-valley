extends Node
class_name Mailbox
# ★[S9-T3 / ADR-0067 결정 7] 편지(저승식 전령) 채널 — 원장·발송 큐·편지 데이터 테이블.
#
# 목적: 서사가 *대화 밖에서* 플레이어에게 닿는 저비용 채널을 연다(애셋 0·컷신 0). 용도는 셋이다 —
#       ㉠ 관문 이벤트 **예고**(다음 비트로 가는 유도) ㉡ 사건의 **여진**(컷신 다음 날 아침 도착하는
#       짧은 편지) ㉢ 레시피 문구 전달. 스타듀 우편의 자리이되, **메뉴 해금 경로로는 쓰지 않는다**
#       (ADR-0064 발견 게이트 유지 — 결정 7이 그 한정을 명문화한 그대로다).
#
# 설계 메모:
#   - larder.gd·shipping_bin.gd와 같은 결의 **상태 노드**다: 단일 책임(편지 원장) + 얇은
#     to_save/load_save. 어느 칸에 우편함이 서는지·언제 [F]가 열리는지·무엇을 대화창에 띄우는지는
#     전부 main이 조율하고, 이 노드는 "무엇이 오는 중이고 무엇이 와 있고 무엇을 읽었나"만 안다
#     (DialogueBox를 모른다 — 곳간이 wallet을 모르는 그 디커플링).
#   - ★ **큐 → 다음 날 아침 도착**(같은 날 즉시 도착 없음). 발송은 `_outbox`에 쌓이고
#     `advance_day()`가 통째로 `_inbox`로 옮긴다. **도착 날짜를 계산하지 않는** 이유: 사건이 언제
#     불렀든 "다음 아침"이면 충분한데, 날짜 산술을 넣으면 밤 12시 경계·구세이브 이월에서 어긋날
#     여지만 생긴다. 큐에 있다 = 아직 안 왔다, advance_day를 한 번 탔다 = 왔다 — 그게 전부다.
#   - ★ **중복 발송 = 무시**(택1의 근거): 편지 한 통은 서사 비트 하나이고 본문이 고유하다. 같은
#     비트가 두 번 도착하면 그건 텍스처가 아니라 버그로 읽힌다. 그래서 `send`는 큐·보관함·기독
#     원장 어디에든 그 id의 흔적이 있으면 false를 돌려주고 아무 일도 하지 않는다(멱등). 사건 코드가
#     "이미 보냈나"를 스스로 기억할 필요가 없다는 뜻이기도 하다 — 관문이 여러 번 발화해도 안전하다.
#   - ★ **읽은 편지도 보관함에 남는다**(도착 순서 그대로). 원장이 미독/기독만 가르므로 재열람 UI는
#     나중에 같은 데이터 위에 얹힌다(지금 [F]는 *가장 오래된 미독*을 연다 — 결정 7의 순차 열람).
#   - 데이터 테이블(LETTERS)은 **gift_prefs.gd 규약**을 그대로 따른다: 행을 더하는 것이 본문 반영의
#     전부이고 코드는 0줄 바뀐다. T3은 파이프라인 + 중립 샘플 1통뿐이고, 메인 3인 × 3~5통(결정 12
#     볼륨 상한)은 T4~T6이 이 dict에 행만 더한다.

# ── 편지 데이터 테이블 ────────────────────────────────────────────────────────
# id → {
#   "from":  발신인(대화창 이름판에 그대로 선다 — 초상화 매핑이 없으면 슬롯이 꺼진다),
#   "lines": 본문 줄들(대화창 한 줄씩 넘긴다. 표정 태그 [smile] 등도 대화창 문법 그대로 먹는다),
#   "note":  트리거 메모(주석 층위 — 코드가 읽지 않는다. "누가 언제 이 편지를 보내는가"의 기록),
# }
#
# ★ 샘플 1통은 **프레임워크 결의 중립 문구**다(캐릭터 본문 아님 — placeholder 결). 캐릭터의 말은
#   ADR-0005대로 캐릭터 파일이 소유하므로, 채널 자체를 설명하는 이 한 통만 여기 산다.
# ★ lines는 **평 Array**로 둔다(PackedStringArray 생성자는 const 표현식이 아니라 파스 에러가 난다).
#   변환은 lines_of가 한 자리에서 하므로 테이블 작성자는 문자열만 나열하면 된다.
const LETTERS := {
	"herald_notice": {
		"from": "저승 전령",
		"lines": [
			"우편함에 낡은 부적 봉투가 꽂혀 있다.",
			"「전령이 다녀갔다. 앞으로 소식은 이 함으로 온다.」",
			"…받을 편지가 쌓이면, 여기서 열어 보면 되겠다.",
		],
		"note": "T3 파이프라인 샘플(중립) — 캐릭터 본문은 T4~T6이 행으로 더한다",
	},
	# ── ★[S9-T4 / ADR-0067 결정 7] 미호 관문 여진 4통 ─────────────────────────
	# 관문(♡1~4)이 성사된 날 큐에 들어가 **다음 날 아침** 도착한다. 매핑(어느 칸이 어느 편지를
	# 부르는가)은 miho.gd의 GATE_LETTERS가 들고, 여기엔 본문만 산다 — 발송 코드는 0줄이다
	# (`heart_gate_letter` 훅 하나로 main이 send를 부른다).
	# ★ 편지의 몫은 **여진**이다: 관문에서 이미 한 말을 되풀이하지 않고, 그 대화 뒤에 남은
	#   한 자락만 쓴다(그래서 전부 짧다). 봉인 법칙 그대로 — 증거·공명만이고 평결은 없다.
	"miho_gate1_seed": {
		"from": "미호",
		"lines": [
			"삐뚤삐뚤한 글씨의 쪽지와 함께, 씨앗 한 줌이 들어 있다.",
			"「아까 그거, 하루 한 번인 거 잊지 마! 아침에 쓰는 게 제일 잘 들어.」",
			"「그리고 놀라지 말라고 미리 말해 두는데, 불 색이 가끔 진해져. 그래도 안 뜨거워. 진짜야.」",
			"「— 미호」",
		],
		"note": "미호 ♡1 관문 여진(여우불 점화 다음 날 아침)",
	},
	"miho_gate2_sorry": {
		"from": "미호",
		"lines": [
			"접었다 편 자국이 여러 번 난 종이다.",
			"「어제 말하다 만 거, 미안해. 하려다가 목이 막혔어.」",
			"「언젠간 다 얘기할게. 도망가는 거 아니야. 준비하는 거야.」",
			"「오늘은 서쪽 끝줄 물 주는 거 잊지 말고. — 미호」",
		],
		"note": "미호 ♡2 관문 여진(말 돌린 것에 대한 사과)",
	},
	"miho_gate3_pumpkin": {
		"from": "미호",
		"lines": [
			"봉투 안에 마른 호박씨 몇 알이 같이 들어 있다.",
			"「어제 얘기 들어 줘서 고마워. 아침에 일어났는데 몸이 가벼웠어.」",
			"「이거 내가 받은 것 중에 제일 아끼는 씨야. 네 밭에 심어 줘.」",
			"「내가 태운 자리에 심는 건 못 하지만, 네 자리에 심는 건 할 수 있으니까.」",
			"「— 미호」",
		],
		"note": "미호 ♡3 관문 여진(첫 고백 다음 날 — 영혼 호박씨)",
	},
	"miho_gate4_okja": {
		"from": "미호",
		"lines": [
			"글씨가 평소보다 작다.",
			"「어제 한 얘기, 옥자한텐 말하지 마. 내가 본 걸 옥자는 모르니까.」",
			"「나는 읽는 것밖에 못 해. 푸는 건 내 몫이 아니더라.」",
			"「그래도 네가 카페에 들를 때마다 옥자 얼굴이 좀 펴져. 그건 내가 본 거야.」",
			"「— 미호」",
		],
		"note": "미호 ♡4 관문 여진(감정의 조각 다음 날 — 증언만·평결 없음)",
	},
	# ── ★[S9-T5 / ADR-0067 결정 7] 멜 관문 여진 4통 ──────────────────────────
	# 미호분과 같은 규약(매핑은 mel.gd의 GATE_LETTERS, 여기엔 본문만). ★ 멜의 편지는 **문서**의
	# 결로 쓴다 — 편지라기보단 명세서·전표에 가깝고, 손으로 덧붙인 한 줄이 진짜 하고 싶은 말이다.
	# 봉인 법칙 그대로: 장부에 적힌 것까지만이고 뜻은 안 정한다.
	"mel_gate1_margin": {
		"from": "멜",
		"lines": [
			"빳빳한 종이에 도장이 찍힌, 편지라기보단 명세서에 가까운 것이 들어 있다.",
			"「어제 조정한 단가, 오늘 아침부터 적용된다. 확인해라.」",
			"「아래 한 줄은 손으로 적은 거다. 장부엔 안 남긴다.」",
			"「— 값 매기는 일을 오래 했는데, 사람 값을 제대로 매겨 본 건 처음이야. 멜」",
		],
		"note": "멜 ♡1 관문 여진(마진 단가 조정 다음 날 아침)",
	},
	"mel_gate2_ash": {
		"from": "멜",
		"lines": [
			"봉투 안쪽에 검은 가루가 조금 묻어 있다.",
			"「어제 말하다 만 거, 신경 쓰지 마라. 내 정리가 덜 됐을 뿐이다.」",
			"「도망은 아니야. 계산이 안 끝난 거지.」",
			"「오늘 매출은 어제보다 높다. 그건 확실해. — 멜」",
		],
		"note": "멜 ♡2 관문 여진(말 돌린 것에 대한 건조한 해명)",
	},
	"mel_gate3_ledger": {
		"from": "멜",
		"lines": [
			"종이 한 장에 숫자가 잔뜩 적혀 있고, 맨 아랫줄만 글씨다.",
			"「어제 들어 줘서 고맙다는 말은 안 한다. 값을 못 매기는 건 장부에 못 적어서.」",
			"「대신 이걸 보낸다. 내가 살아서 굴린 돈의 총액이야. 세어 봤어. 처음으로.」",
			"「이만큼을 여기서 되돌려 놓는 데 몇 년 걸리는지도 계산해 뒀다. 나쁘지 않더라. 시간은 많으니까.」",
			"「— 멜」",
		],
		"note": "멜 ♡3 관문 여진(첫 고백 다음 날 — 갚을 총액을 처음 세어 본 기록)",
	},
	"mel_gate4_copy": {
		"from": "멜",
		"lines": [
			"봉투가 평소보다 두껍다. 안에 사본이 한 장 더 들어 있다.",
			"「어제 준 것 말고 한 장이 더 있었다. 네 몫이라 같이 보낸다.」",
			"「사장님한텐 말하지 마라. 내가 봤다는 것도, 네가 가졌다는 것도.」",
			"「읽는 데까지가 내 일이야. 맞추는 건 네 일이고.」",
			"「— 멜」",
		],
		"note": "멜 ♡4 관문 여진(사실의 조각 다음 날 — 사본만·평결 없음)",
	},
	# ── ★[S9-T6 / ADR-0067 결정 7] 바나 관문 여진 4통 ─────────────────────────
	# 미호·멜분과 같은 규약(매핑은 bana.gd의 GATE_LETTERS, 여기엔 본문만). ★ 바나의 편지는
	# **물건이 먼저 오고 말이 나중**인 결로 쓴다 — 봉투에 늘 뭔가가 들어 있고, 글은 짧고 눌러쓴다.
	# 봉인 법칙 그대로: 자기가 한 짓·자기가 본 것까지만이고 플레이어의 죄는 겨누지 않는다.
	"bana_gate1_whetstone": {
		"from": "바나",
		"lines": [
			"봉투 대신 기름종이에 싼 숫돌이 하나 놓여 있다.",
			"「어제 배운 자세, 자고 일어나면 잊는다. 그러니 아침에 한 번 더 해.」",
			"「이건 내가 쓰던 거다. 날 세우는 건 밤에 하지 말고.」",
			"「— 바나」",
		],
		"note": "바나 ♡1 관문 여진(막는 법을 배운 다음 날 아침)",
	},
	"bana_gate2_order": {
		"from": "바나",
		"lines": [
			"글씨가 눌러쓴 자국으로 깊게 파여 있다.",
			"「어제 말 끊은 거, 네 탓 아니다.」",
			"「도망은 아니야. 순서를 지키는 중이야. 나는 순서를 안 지켜서 그 꼴이 났거든.」",
			"「오늘 밤도 서 있을 테니 늦으면 그냥 자라. — 바나」",
		],
		"note": "바나 ♡2 관문 여진(말 돌린 것에 대한 짧은 해명)",
	},
	"bana_gate3_latch": {
		"from": "바나",
		"lines": [
			"봉투에 밤이슬에 젖었다 마른 자국이 있다.",
			"「어제 들어 줘서 고맙다는 말은 안 한다. 그건 네가 손해 본 일이라서.」",
			"「대신 하나 알려 줄게. 네 집 뒷문 걸쇠가 헐거워. 그런 건 보면 보이더라.」",
			"「고쳐 놨다. 이제 밖에선 안 열려. — 바나」",
		],
		"note": "바나 ♡3 관문 여진(첫 고백 다음 날 — 여는 손이 잠금을 고쳐 놓는다)",
	},
	"bana_gate4_lock": {
		"from": "바나",
		"lines": [
			"봉투 안에 낡은 쇠 걸쇠가 하나 들어 있다.",
			"「어제 보여 준 자국, 이걸로 생긴 거다. 이제 네가 가지고 있어.」",
			"「내가 들고 있으면 계속 잠그게 될 것 같아서.」",
			"「잠근 데까지가 내가 아는 전부다. 그 다음은 안 물을게. — 바나」",
		],
		"note": "바나 ♡4 관문 여진(행동의 조각 다음 날 — 자백만·평결 없음)",
	},
}

# 재고가 바뀐 프레임(main이 우편함 표식·미독 배지를 다시 그린다). larder.changed와 같은 결.
signal changed()

# 발송 큐 — 보냈으나 아직 도착하지 않은 편지 id(도착은 다음 날 아침).
var outbox: PackedStringArray = PackedStringArray()
# 보관함 — 도착한 편지 id(도착 순서 = 오래된 것이 앞. 읽어도 남는다).
var inbox: PackedStringArray = PackedStringArray()
# 기독 원장 {id: true}. 보관함에 있으면서 여기 없는 id = 미독.
var read_ledger: Dictionary = {}

# ── 테이블 조회(정적 — 어디서든 Mailbox.has_letter(id)로 읽는다) ───────────────
static func has_letter(id: String) -> bool:
	return LETTERS.has(id)

static func sender_of(id: String) -> String:
	if not LETTERS.has(id):
		return ""
	return str(LETTERS[id].get("from", ""))

static func lines_of(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not LETTERS.has(id):
		return out
	var raw: Variant = LETTERS[id].get("lines", [])
	var t := typeof(raw)
	if t != TYPE_ARRAY and t != TYPE_PACKED_STRING_ARRAY:
		return out
	for ln in raw:
		out.append(str(ln))
	return out

# ── 발송(사건 코드가 부르는 공용 창구) ────────────────────────────────────────
# 큐에 넣는다. **다음 날 아침에 도착**한다(같은 날 즉시 도착 없음).
# 거절(false)하는 경우: 테이블에 없는 id · 이미 큐에 있음 · 이미 도착함(읽었든 안 읽었든).
# ★ 거절이 곧 중복 방어다 — 호출 측은 "이미 보냈나"를 기억할 필요가 없다(위 설계 메모).
func send(letter_id: String) -> bool:
	if not has_letter(letter_id) or ever_sent(letter_id):
		return false
	outbox.append(letter_id)
	changed.emit()
	return true

# 이 편지가 이 세이브에서 이미 발송된 적이 있는가(큐 중 · 도착함 둘 다 포함).
func ever_sent(letter_id: String) -> bool:
	return outbox.has(letter_id) or inbox.has(letter_id)

# ── 아침 도착(main의 day advance 훅이 부른다) ─────────────────────────────────
# 큐에 있던 편지를 통째로 보관함으로 옮기고, **이번 아침에 도착한 id들**을 돌려준다(빈 배열 = 무소식).
# 도착분은 전부 미독이다(원장에 안 넣는다). 큐 순서가 곧 보관함 순서 = "오래된 것부터" 열람의 근거.
func advance_day() -> PackedStringArray:
	if outbox.is_empty():
		return PackedStringArray()
	var arrived := outbox.duplicate()
	for id in arrived:
		inbox.append(id)
	outbox = PackedStringArray()
	changed.emit()
	return arrived

# ── 열람 ──────────────────────────────────────────────────────────────────────
# 가장 오래된 미독 편지 id(없으면 ""). main의 [F]가 이걸 열고, 프롬프트 문구도 이걸 본다.
func next_unread() -> String:
	for id in inbox:
		if not read_ledger.has(id):
			return id
	return ""

# 열람 처리(기독 원장 적재). 보관함에 없는 id는 무시한다(늦게 눌린 입력·깨진 호출 방어).
# 이미 읽은 편지를 다시 넘겨도 조용히 통과한다(멱등).
func mark_read(letter_id: String) -> bool:
	if not inbox.has(letter_id) or read_ledger.has(letter_id):
		return false
	read_ledger[letter_id] = true
	changed.emit()
	return true

func is_read(letter_id: String) -> bool:
	return read_ledger.has(letter_id)

# 미독 통수(우편함 시각 신호·프롬프트 표기).
func unread_count() -> int:
	var n := 0
	for id in inbox:
		if not read_ledger.has(id):
			n += 1
	return n

# 우편함에 깃발이 서 있는가 = 읽을 것이 있는가(그레이박스 시각 신호의 술어).
func has_unread() -> bool:
	return unread_count() > 0

# 큐 대기 통수(테스트·디버그 — "보냈지만 아직 안 온" 편지 수).
func pending_count() -> int:
	return outbox.size()

# ── 세이브/로드 ───────────────────────────────────────────────────────────────
# 가법 키 두 축(큐 · 보관함+기독 원장). ★ 세이브 키 자체가 없는 구버전은 main이 load_save를 아예
# 안 불러 **빈 우편함**으로 시작한다(곳간·출하함·상자가 쓰는 그 하위호환 관례 — 마이그레이션 0).
func to_save() -> Dictionary:
	return {
		"outbox": outbox.duplicate(),
		"inbox": inbox.duplicate(),
		"read": read_ledger.duplicate(),
	}

# 복원: 세 축을 정제해 갈아끼운다. 손상 방어(테이블에 없는 id·중복·형식 불일치)는 곳간 load_save의
# 결 그대로다 — 편지 테이블에서 사라진 옛 id는 조용히 버린다(본문이 없는 편지는 열 수 없으므로,
# 남겨 두면 [F]가 빈 대화를 여는 함정이 된다).
func load_save(data: Dictionary) -> void:
	outbox = _sanitize_ids(data.get("outbox", PackedStringArray()), {})
	var seen: Dictionary = {}
	for id in outbox:
		seen[id] = true
	inbox = _sanitize_ids(data.get("inbox", PackedStringArray()), seen)
	read_ledger = {}
	var raw_read: Variant = data.get("read", {})
	if typeof(raw_read) == TYPE_DICTIONARY:
		for id in raw_read:
			var sid := str(id)
			# 기독 원장은 **보관함에 있는 편지만** 든다 — 도착한 적 없는 id의 기독 기록은 의미가 없고,
			# 남겨 두면 나중에 그 편지가 실제로 도착했을 때 미독 표시 없이 묻힌다.
			if inbox.has(sid) and bool(raw_read[id]):
				read_ledger[sid] = true
	changed.emit()

# id 배열 정제 — 테이블에 있는 id만·중복 제거(`claimed`에 이미 든 id도 제외). 형식이 배열이
# 아니면 빈 배열. 큐와 보관함이 같은 id를 동시에 들지 않도록 호출 측이 claimed를 넘긴다.
func _sanitize_ids(raw: Variant, claimed: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var t := typeof(raw)
	if t != TYPE_PACKED_STRING_ARRAY and t != TYPE_ARRAY:
		return out
	var seen: Dictionary = claimed.duplicate()
	for v in raw:
		var sid := str(v)
		if not has_letter(sid) or seen.has(sid):
			continue
		seen[sid] = true
		out.append(sid)
	return out

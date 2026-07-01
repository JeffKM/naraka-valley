# 대화 초상화 미드저니 생성 프롬프트 (옥자·미호·멜·바나)

> **목적:** 4캐릭터 대화 초상화를 **동일한 그림체**로 미드저니에서 뽑기 위한 공통 프롬프트 + 캐릭터별 슬롯.
> **규격 출처:** 프레이밍·표정 세트·출력 규격은 [portrait-spec-card.md](./portrait-spec-card.md)(§1 버스트·§3 5표정·§5 디자인 일치). 외형 세부는 §5가 권위.
> **후처리:** 미드저니는 투명 PNG를 못 뽑는다 → `plain background`로 생성 후 **removebg로 알파 제거** → `game/tools/make_okja_portraits.py`가 크롭·리사이즈(ADR-0001 허용 글루).
> **아트 방향(2026-07-01 owner 결정):** 매끈한 애니 일러스트 ✗ → **픽셀 텍스처가 살아있는 초상화**(Sun Haven·Stardew Valley Expanded 류: 또렷한 픽셀 그레인 + 페인터리 셰이딩). 픽셀 게임 룩(ADR-0012)과 정합.

## ★ 권장 방법 (MJ 필수): 표정별 1장씩 생성 + `--cref`

> **⚠️ 도구 선택 (2026-07-01 실측):** **Gemini는 한 장 2×3 그리드에 6칸 표정을 제각각 잘 그린다**(+ 픽셀 텍스처도 반영) → **Gemini면 아래 §0~§3 그리드 방식이 최선**(옥자 실제로 이렇게 뽑음). 반면 **MJ(niji)는 칸별 표정 제어를 못 한다** — 6칸을 그려도 표정 설명을 뭉뚱그려 다 비슷한 무표정으로 수렴. **아래 ★ 개별생성은 MJ 전용 우회책**이다.
>
> **★ MJ 우회:** **표정을 1장씩 따로** 뽑고, 같은 얼굴·의상은 **`--cref`(캐릭터 레퍼런스)로 고정**한다. 각 프롬프트가 표정 하나에 집중하므로 확실히 반영. **그리드 합성 불필요** — 5장 따로 주면 크롭 툴이 각각 처리.

**순서**
1. **중립(anchor) 먼저** — 아래 템플릿의 `{EXPRESSION}`에 중립을 넣어 옥자 1장 생성 → 마음에 드는 컷 확정. 이 이미지 URL이 앵커.
2. **나머지 표정** — 각 프롬프트 끝에 `--cref <중립 URL> --cw 50` 추가로 생성(같은 얼굴·의상 유지, 표정만 프롬프트대로). 표정이 앵커를 따라 안 바뀌면 `--cw`↓(0~30), 의상이 흐트러지면 `--cw`↑(70~100).
3. 각 장 **removebg** → 5장(중립·말하기·미소·수줍음·슬픔) 전달하면 내가 320² 버스트로 정규화·적용.

**단일 초상화 템플릿** (`{CHARACTER}` = §2 슬롯 그대로)
```
a single square anime bust portrait of {CHARACTER}, head and shoulders only, facing the viewer, eyes to camera, front or slight 3/4 angle, framed from just above the head down to the upper chest and collarbone. EXPRESSION: {EXPRESSION}. Style: detailed pixel-art bust portrait in the style of Sun Haven and Stardew Valley Expanded character portraits — painterly pixel shading with visible chunky pixels and subtle dithering, crisp readable pixel clusters, clean pixel edges, a warm limited palette, soft rim lighting, large expressive eyes, ornate but pixel-rendered lace and frills, cozy dark-fantasy JRPG portrait mood, high detail. pixel art, 16-bit RPG portrait. Plain flat solid background, no scenery, even soft lighting. --niji 6 --ar 1:1 --s 250
```
> 앵커(중립) 외에는 끝에 `--cref <중립 이미지 URL> --cw 50` 를 덧붙인다.

**`{EXPRESSION}` 표** (한 번에 하나씩)

| 파일 | `{EXPRESSION}` |
|---|---|
| 중립 (anchor) | `a calm, composed neutral face with the mouth closed` |
| 말하기 | `talking, mouth open mid-speech, engaged` |
| 미소 | `a big cheerful happy smile, mouth clearly curved upward showing teeth, eyes softly crinkled` |
| 수줍음 | `shy and bashful, rosy blushing cheeks, slightly averted eyes, a small closed-mouth smile` |
| 슬픔 | `sad and crying, teary eyes with visible tears running down the cheeks, inner eyebrows raised, mouth downturned in a frown` |
| 놀람 (예비) | `surprised, wide-open eyes, raised eyebrows, small open mouth` |

---

## 0. (참고) 한-장 그리드 방식 — 레이아웃 규칙 (표정 제어는 위 ★ 방법으로)

1. **레이아웃 = 3:2 캔버스에 2×3 균등 그리드(2행 × 3열 = 6칸)** — **모든 칸이 완전히 같은 크기의 정사각**(3:2라 6칸이 정사각), **칸 사이 여백(거터)** 으로 안 닿게. ⚠️ **큰 중앙 얼굴(히어로)·전신 인물·흩뿌린 썸네일·턴어라운드 금지** — MJ가 홀수(5)·"reference sheet"를 만나면 *중앙에 큰 얼굴 1개 + 작은 위성*이나 *전신+콜라주*로 그리는 함정. 그래서 **짝수 균등 6칸 + "visual-novel emote 세트"** 로 프레이밍함.
2. **표정 순서 고정 + 한눈에 구분되게 과장** — 위: (1)중립 · (2)말하기(입 열림) · (3)**활짝 웃는 미소(입꼬리 확실히 올라가고 이 보이며 눈 살짝 접힘)** / 아래: (4)수줍음(볼 홍조·시선 살짝 피함) · (5)**우는 슬픔(눈물 맺힘·눈썹 안쪽 올라감·입꼬리 내려감)** · (6)놀람(눈 크게·눈썹 올라감·입 살짝 벌림). **6번(놀람)은 예비** — 인게임 대화는 5표정만 씀([portrait-spec-card.md §3]). 미소·슬픔이 애매하면 재생성.
3. **6표정 모두 의상·헤어·모자·프레이밍 동일**, 얼굴 표정만 변경. 각 컷 = 머리 위 여백~가슴 상단 버스트, 정면(살짝 3/4), 시선 정면.

## 1. 공통 프롬프트 (스타일·포맷 — 캐릭터만 교체)

`{CHARACTER}`에 §2 캐릭터 블록을 넣어 통째로 복붙:

```
a clean uniform 2x3 grid (2 rows, 3 columns) of SIX equally-sized square bust portraits of the SAME character — every tile exactly the same size, NO enlarged central portrait, no hero image, no character turnaround, no full-body figure, like a flat contact sheet of six avatar icons, evenly spaced with even gutters of blank background between the tiles so they never touch or overlap, head and shoulders only in each tile. In every tile the character keeps the identical outfit, hairstyle and hat, faces the viewer with eyes to camera (front or slight 3/4 angle), framed from just above the head down to the upper chest and collarbone; ONLY the facial expression changes. Expressions by tile — top row: (1) calm neutral composed face, (2) talking with the mouth open mid-speech, (3) a big cheerful HAPPY SMILE with the mouth clearly curved upward showing teeth and the eyes softly crinkled; bottom row: (4) shy and bashful with rosy blushing cheeks and slightly averted eyes, (5) SAD and CRYING with teary eyes, visible tears on the cheeks, inner eyebrows raised and the mouth downturned, (6) surprised with wide-open eyes, raised eyebrows and a small open mouth. Each of the six expressions must be clearly distinct and easy to read at a glance, with the smile obviously happy and the sad face obviously crying.

CHARACTER: {CHARACTER}

Style: detailed pixel-art bust portrait in the style of Sun Haven and Stardew Valley Expanded character portraits — painterly pixel shading with visible chunky pixels and subtle dithering, crisp readable pixel clusters, clean pixel edges, a warm limited palette, soft rim lighting, large expressive eyes, ornate but pixel-rendered lace and frills, cozy dark-fantasy JRPG portrait mood, high detail. pixel art, 16-bit RPG portrait. Plain flat solid background, no scenery, even soft lighting for easy background removal.
--niji 6 --ar 3:2 --s 250 --no full body, hero portrait, oversized central portrait, enlarged central face, character turnaround, scattered thumbnails, text, watermark, signature
```

> **그림체 통일 팁:** 첫 캐릭터(옥자)를 마음에 들게 뽑은 뒤, 그 이미지를 나머지 3캐릭터 프롬프트 끝에 `--sref <옥자 이미지 URL>`로 물리면 룩이 확 붙는다. (옥자 자체엔 `--sref` 불필요.)

## 2. 캐릭터별 `{CHARACTER}` 슬롯

### 옥자 (okja) — 카페 점주 / 마녀
```
a composed elegant young woman in a black witch hat with a small burgundy feather, burgundy wavy hair, a solid burgundy dress with a lace neckline, large sharp calm eyes, round thin glasses, cool serene demeanor.
```

### 미호 (miho) — 여우 / 작물 양육 (따뜻함)
```
a warm gentle young woman with white fox ears, dark-brown long wavy hair, large soft eyes, a greyish-lavender white top with a hint of a yellow skirt, a small floating blue fox-fire flame beside her head. No glasses.
```

### 멜 (mel) — 강시 / 카페 운영 (장부·마진)
```
a young woman in a teal jiangshi (Chinese hopping-ghost) robe with a blue floral pattern, a matching teal jiangshi cap with a single red beaded tassel on the side, a straight blunt black bob cut, blue-grey eyes, a red prayer-bead (mala) necklace, red lips, blushing cheeks, a mandarin collar with frog buttons. No glasses.
```

### 바나 (bana) — 뱀파이어 / 야간 경비 (보호)
```
a young woman in a purple-and-black frilled gothic-lolita dress, blonde hair with a black front-bang streak, red eyes, small vampire fangs, a frilled choker. No glasses.
```

## 3. 바로 쓰는 완성본 (공통 + 슬롯 병합)

각 블록을 미드저니에 그대로 붙여넣으면 됨.

### 옥자
```
a clean uniform 2x3 grid (2 rows, 3 columns) of SIX equally-sized square bust portraits of the SAME character — every tile exactly the same size, NO enlarged central portrait, no hero image, no character turnaround, no full-body figure, like a flat contact sheet of six avatar icons, evenly spaced with even gutters of blank background between the tiles so they never touch or overlap, head and shoulders only in each tile. In every tile the character keeps the identical outfit, hairstyle and hat, faces the viewer with eyes to camera (front or slight 3/4 angle), framed from just above the head down to the upper chest and collarbone; ONLY the facial expression changes. Expressions by tile — top row: (1) calm neutral composed face, (2) talking with the mouth open mid-speech, (3) a big cheerful HAPPY SMILE with the mouth clearly curved upward showing teeth and the eyes softly crinkled; bottom row: (4) shy and bashful with rosy blushing cheeks and slightly averted eyes, (5) SAD and CRYING with teary eyes, visible tears on the cheeks, inner eyebrows raised and the mouth downturned, (6) surprised with wide-open eyes, raised eyebrows and a small open mouth. Each of the six expressions must be clearly distinct and easy to read at a glance, with the smile obviously happy and the sad face obviously crying. CHARACTER: a composed elegant young woman in a black witch hat with a small burgundy feather, burgundy wavy hair, a solid burgundy dress with a lace neckline, large sharp calm eyes, round thin glasses, cool serene demeanor. Style: detailed pixel-art bust portrait in the style of Sun Haven and Stardew Valley Expanded character portraits — painterly pixel shading with visible chunky pixels and subtle dithering, crisp readable pixel clusters, clean pixel edges, a warm limited palette, soft rim lighting, large expressive eyes, ornate but pixel-rendered lace and frills, cozy dark-fantasy JRPG portrait mood, high detail. pixel art, 16-bit RPG portrait. Plain flat solid background, no scenery, even soft lighting for easy background removal. --niji 6 --ar 3:2 --s 250 --no full body, hero portrait, oversized central portrait, enlarged central face, character turnaround, scattered thumbnails, text, watermark, signature
```

### 미호
```
a clean uniform 2x3 grid (2 rows, 3 columns) of SIX equally-sized square bust portraits of the SAME character — every tile exactly the same size, NO enlarged central portrait, no hero image, no character turnaround, no full-body figure, like a flat contact sheet of six avatar icons, evenly spaced with even gutters of blank background between the tiles so they never touch or overlap, head and shoulders only in each tile. In every tile the character keeps the identical outfit, hairstyle and hat, faces the viewer with eyes to camera (front or slight 3/4 angle), framed from just above the head down to the upper chest and collarbone; ONLY the facial expression changes. Expressions by tile — top row: (1) calm neutral composed face, (2) talking with the mouth open mid-speech, (3) a big cheerful HAPPY SMILE with the mouth clearly curved upward showing teeth and the eyes softly crinkled; bottom row: (4) shy and bashful with rosy blushing cheeks and slightly averted eyes, (5) SAD and CRYING with teary eyes, visible tears on the cheeks, inner eyebrows raised and the mouth downturned, (6) surprised with wide-open eyes, raised eyebrows and a small open mouth. Each of the six expressions must be clearly distinct and easy to read at a glance, with the smile obviously happy and the sad face obviously crying. CHARACTER: a warm gentle young woman with white fox ears, dark-brown long wavy hair, large soft eyes, a greyish-lavender white top with a hint of a yellow skirt, a small floating blue fox-fire flame beside her head, no glasses. Style: detailed pixel-art bust portrait in the style of Sun Haven and Stardew Valley Expanded character portraits — painterly pixel shading with visible chunky pixels and subtle dithering, crisp readable pixel clusters, clean pixel edges, a warm limited palette, soft rim lighting, large expressive eyes, ornate but pixel-rendered lace and frills, cozy dark-fantasy JRPG portrait mood, high detail. pixel art, 16-bit RPG portrait. Plain flat solid background, no scenery, even soft lighting for easy background removal. --niji 6 --ar 3:2 --s 250 --no full body, hero portrait, oversized central portrait, enlarged central face, character turnaround, scattered thumbnails, text, watermark, signature
```

### 멜
```
a clean uniform 2x3 grid (2 rows, 3 columns) of SIX equally-sized square bust portraits of the SAME character — every tile exactly the same size, NO enlarged central portrait, no hero image, no character turnaround, no full-body figure, like a flat contact sheet of six avatar icons, evenly spaced with even gutters of blank background between the tiles so they never touch or overlap, head and shoulders only in each tile. In every tile the character keeps the identical outfit, hairstyle and hat, faces the viewer with eyes to camera (front or slight 3/4 angle), framed from just above the head down to the upper chest and collarbone; ONLY the facial expression changes. Expressions by tile — top row: (1) calm neutral composed face, (2) talking with the mouth open mid-speech, (3) a big cheerful HAPPY SMILE with the mouth clearly curved upward showing teeth and the eyes softly crinkled; bottom row: (4) shy and bashful with rosy blushing cheeks and slightly averted eyes, (5) SAD and CRYING with teary eyes, visible tears on the cheeks, inner eyebrows raised and the mouth downturned, (6) surprised with wide-open eyes, raised eyebrows and a small open mouth. Each of the six expressions must be clearly distinct and easy to read at a glance, with the smile obviously happy and the sad face obviously crying. CHARACTER: a young woman in a teal jiangshi robe with a blue floral pattern, a matching teal jiangshi cap with a single red beaded tassel on the side, a straight blunt black bob cut, blue-grey eyes, a red prayer-bead mala necklace, red lips, blushing cheeks, a mandarin collar with frog buttons, no glasses. Style: detailed pixel-art bust portrait in the style of Sun Haven and Stardew Valley Expanded character portraits — painterly pixel shading with visible chunky pixels and subtle dithering, crisp readable pixel clusters, clean pixel edges, a warm limited palette, soft rim lighting, large expressive eyes, ornate but pixel-rendered lace and frills, cozy dark-fantasy JRPG portrait mood, high detail. pixel art, 16-bit RPG portrait. Plain flat solid background, no scenery, even soft lighting for easy background removal. --niji 6 --ar 3:2 --s 250 --no full body, hero portrait, oversized central portrait, enlarged central face, character turnaround, scattered thumbnails, text, watermark, signature
```

### 바나
```
a clean uniform 2x3 grid (2 rows, 3 columns) of SIX equally-sized square bust portraits of the SAME character — every tile exactly the same size, NO enlarged central portrait, no hero image, no character turnaround, no full-body figure, like a flat contact sheet of six avatar icons, evenly spaced with even gutters of blank background between the tiles so they never touch or overlap, head and shoulders only in each tile. In every tile the character keeps the identical outfit, hairstyle and hat, faces the viewer with eyes to camera (front or slight 3/4 angle), framed from just above the head down to the upper chest and collarbone; ONLY the facial expression changes. Expressions by tile — top row: (1) calm neutral composed face, (2) talking with the mouth open mid-speech, (3) a big cheerful HAPPY SMILE with the mouth clearly curved upward showing teeth and the eyes softly crinkled; bottom row: (4) shy and bashful with rosy blushing cheeks and slightly averted eyes, (5) SAD and CRYING with teary eyes, visible tears on the cheeks, inner eyebrows raised and the mouth downturned, (6) surprised with wide-open eyes, raised eyebrows and a small open mouth. Each of the six expressions must be clearly distinct and easy to read at a glance, with the smile obviously happy and the sad face obviously crying. CHARACTER: a young woman in a purple-and-black frilled gothic-lolita dress, blonde hair with a black front-bang streak, red eyes, small vampire fangs, a frilled choker, no glasses. Style: detailed pixel-art bust portrait in the style of Sun Haven and Stardew Valley Expanded character portraits — painterly pixel shading with visible chunky pixels and subtle dithering, crisp readable pixel clusters, clean pixel edges, a warm limited palette, soft rim lighting, large expressive eyes, ornate but pixel-rendered lace and frills, cozy dark-fantasy JRPG portrait mood, high detail. pixel art, 16-bit RPG portrait. Plain flat solid background, no scenery, even soft lighting for easy background removal. --niji 6 --ar 3:2 --s 250 --no full body, hero portrait, oversized central portrait, enlarged central face, character turnaround, scattered thumbnails, text, watermark, signature
```

## 4. 실전 팁 & 트러블슈팅

- **파라미터:** `--niji 6`(애니 모델) · `--ar 3:2`(3×2 칸이 정사각이 되는 비율) · `--s 250`(스타일 강도, 취향껏 100~500) · `--no full body, character turnaround, ...`(콜라주/전신 방지). `--style raw`를 붙이면 더 담백/사실적으로 빠짐.
- **⚠️ "큰 중앙 얼굴(히어로)" 함정:** MJ는 홀수(5)·"reference sheet"를 만나면 중앙에 큰 얼굴 1개 + 작은 위성 얼굴들, 또는 전신+콜라주를 그린다. 해법 = **짝수 균등 6칸(2×3)** + `visual-novel emote set` + `NO enlarged central portrait`/`--no hero portrait, oversized central portrait`. 그래도 중앙이 커지면 `--s`를 낮추고(50~100) `--style raw`를 붙인다(MJ가 구도를 덜 "예쁘게" 재해석 → 격자 준수↑).
- **투명 배경:** MJ는 진짜 알파를 못 뽑음 → `plain background`로 생성 → **removebg**로 배경 제거 → 파일명에 `-removebg-preview.png` 형태로 저장해 넘기면 크롭 툴이 바로 처리.
- **★ 픽셀 텍스처가 흐리멍덩할 때:** MJ(niji)는 "pixel art"를 넣어도 *매끈한 가짜 픽셀*로 뭉개는 경향. 확실히 하려면 ① `--style raw` + `--s` 낮춤(50~150), ② 프롬프트 앞쪽에 `pixel art::1.3`, ③ 그래도 매끈하면 **MJ 결과를 강하게 다운스케일(예: 폭 160~256px)→Aseprite에서 픽셀 보정**(ADR-0001 워크플로우: 생성→Aseprite 정리). 내가 넘겨받아 다운스케일 픽셀화까지 해줄 수 있음. ④ 진짜 도트가 필요하면 **Retro Diffusion**이 Sun Haven류 초상화를 MJ보다 잘 뽑음(대안 툴).
- **격자가 흐트러질 때:** 프롬프트 맨 앞에 `a 2x3 grid, six equal square tiles,`를 강조하거나, 표정을 2~3개씩 나눠 뽑고 합성한다.
- **미소·슬픔이 여전히 밋밋하면:** 표정 단어를 멀티프롬프트 가중치로 밀어준다 — 예: `... big happy smile::1.4 ... crying with tears::1.4 ...`. 그래도 약하면 `exaggerated expressions, expressive faces`를 스타일 절에 추가. (MJ는 은은한 표정으로 수렴하는 경향이 있어 슬픔=눈물, 미소=이 보임을 명시적으로 계속 강조해야 함.)
- **표정 순서·레이아웃은 고정**(§0) — 6칸(위3/아래3) 균등 정사각+여백이면 `make_okja_portraits.py`의 `RECTS`를 6칸으로 맞춰 크롭(내가 이미지 받으면 조정). 인게임엔 5표정만 쓰고 6번(놀람)은 예비.
- **캐릭터 간 룩 통일:** 옥자를 먼저 확정 → 나머지 3캐릭터에 `--sref <옥자 URL>`.
- **안경:** 옥자만 有(원형 얇은 안경). 미호·멜·바나는 **無**([portrait-spec-card.md §5] — 바나는 옛 초상화에만 있었고 새 디자인엔 제거).

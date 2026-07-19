# single_source/ — 단일출처 코히어런트 base 필드 (Retro Diffusion 트랙)

`_TERRAIN_SINGLE_SOURCE = true`(main.gd)일 때 여기의 파일이 base로 쓰인다.
비어 있거나 플래그 off면 현행 shipping 아트 그대로(회귀 안전).

넣을 파일 (셋 다 **한 팔레트·씸리스 tileable**):
- `grass_field.png`
- `dirt_field.png`
- `water_field.png`

생성 규격·절차는 `docs/design/tileset-single-source-spike/RETRO-DIFFUSION-SPEC.md` 참조.

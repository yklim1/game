# ART_ASSET_SPEC.md — 스프라이트 에셋 규격 (Feral Bloom)

> 대상: AI(SDXL/ComfyUI)로 스프라이트를 생성·후처리하는 담당자(사람 또는 스크립트).
> 목적: **이 문서대로 PNG를 만들어 지정 폴더에 넣고 .tres 필드만 채우면** 게임에 그대로 반영되게 한다.
> 스타일·팔레트의 원본은 `docs/DESIGN.md` 2.3 절이며, 이 문서는 그 방향을 **엔진이 요구하는 수치 규격**으로 옮긴 것이다.
> 표기: **확인** = 코드/엔진 동작으로 검증함, **추정** = 근거 기반 판단(단정 아님).

---

## 0. 핵심 규칙 5줄

1. 모든 스프라이트는 **투명 배경 PNG(RGBA)**, **정사각 캔버스**, **콘텐츠 중앙 정렬**.
2. 콘텐츠(캐릭터 실루엣)가 **캔버스의 88~92%** 를 채우게 한다. 게임 내 크기는 "긴 변" 기준으로 정규화되므로 이 비율이 곧 체감 크기다.
3. 파일명은 **데이터의 `id` 와 동일**하게 짓는다(`spore_ant.png` ↔ `data/animals/spore_ant.tres`).
4. 넣기만 해서는 반영되지 않는다. 해당 `.tres`의 **텍스처 필드에 파일을 지정**해야 한다(§4).
5. 아직 아트가 없는 대상은 **건드리지 않아도 된다**. 필드가 비어 있으면 기존 플레이스홀더(`icon.svg` + 색)로 계속 동작한다. 한 종류씩 교체해도 문제없다. **확인**

---

## 1. 폴더 구조와 파일 명명

```
res://assets/sprites/
├── player/     player_cub.png
├── animals/    spore_ant.png, rabid_hare.png, mutant_crow.png, bile_toad.png, twisted_boar.png
├── abilities/  thorn_shot.png, feather_burst.png, claw_swipe.png, venom_gland.png, ...
├── pickups/    essence_gem.png, feed.png
├── fx/         death_shard.png
└── ui/icons/   (변이·능력 아이콘 — UI 미구현, §7 참고)
```

- 파일명: `snake_case`, 확장자 `.png`. 공백·대문자·한글 금지.
- 변형(진화 단계 등)은 접미사로: `player_cub_stage2.png`.
- 스프라이트시트/아틀라스는 **아직 쓰지 않는다**(현재 렌더링은 단일 정적 텍스처만 지원). 애니메이션은 추후 과제.

---

## 2. 종류별 규격표

"게임 내 표시 크기"는 코드가 텍스처의 **긴 변**을 그 픽셀 수로 맞춰 그리는 값이다. 원본 해상도가 달라도 게임 내 크기는 변하지 않는다. **확인**

| 종류 | 캔버스(권장) | 게임 내 표시 크기(px) | 크기 결정 방식 | 폴더 |
|---|---|---|---|---|
| 플레이어 | 128×128 | 51 | `player.tscn` 의 `sprite_display_size`(0이면 씬 기본 51px) | `player/` |
| 일반 적(소·중형) | 128×128 | 24~38 (아래 표) | `AnimalData.sprite_size`, 0이면 `radius × 2` | `animals/` |
| 대형 적/보스 | 256×256 | 52 이상 | 동일 | `animals/` |
| 투사체 | 64×64 | 15.4 (기본) | `AbilityData.projectile_size`, 0이면 씬 기본 | `abilities/` |
| 근접 잔상(부채꼴) | 256×256 | 236 | `AbilityData.area_radius × 2 × RunState.area_mult` | `abilities/` |
| 장판·오라 | 512×512 | 192~304 | 동일 | `abilities/` |
| 정수 젬 | 32×32 | 12 | `pickup.tscn` 의 `essence_size` | `pickups/` |
| 먹이 | 32×32 | 16 | `pickup.tscn` 의 `feed_size` | `pickups/` |
| 사망 조각 | 32×32 | 6.4 | `death_burst.tscn` 의 `shard_size`(0이면 씬 기본) | `fx/` |
| 변이/능력 아이콘 | 64×64 | — | **표시 UI 미구현(§7)** | `ui/icons/` |

### 2.1 현재 존재하는 적의 실제 표시 크기

엘리트는 코드가 자동으로 **1.6배 확대 + 앰버(`#FFB020`) 혼합**하므로 **별도 아트가 필요 없다**. **확인**

| id | 이름 | 표시 크기 | 엘리트 | 대표색 | 계열 |
|---|---|---|---|---|---|
| `spore_ant` | 포자 개미 | 24px | 38px | `#8D5AFF` | 곤충(스웜) |
| `mutant_crow` | 변이 까마귀 | 26px | 42px | `#6D59D9` | 조류(고속·지그재그) |
| `rabid_hare` | 광포한 토끼 | 30px | 48px | `#C79EFF` | 소형 포유류(러셔) |
| `bile_toad` | 쓸개즙 두꺼비 | 38px | 61px | `#3FBF6A` | 양서류(독) |
| `twisted_boar` | 뒤틀린 멧돼지 | 52px | 83px | `#FFB020` | 대형 짐승(탱커) |

> 24~52px는 **작다**. 128×128로 그리되 **실루엣 우선**(가는 디테일·얇은 선·작은 글자는 축소되면 사라진다). 아웃라인은 128px 캔버스 기준 **4~6px** 이상으로 굵게.

### 2.2 여백·피벗

- 피벗/앵커 = **이미지 중심**(엔진은 `Sprite2D.centered = true`). 발밑 기준 앵커는 지원하지 않으므로, 캐릭터의 **시각적 무게중심을 캔버스 정중앙**에 둔다.
- 캔버스 가장자리에 **4~6% 안전 여백**을 남긴다(글로우·아웃라인이 잘리지 않게). 즉 콘텐츠는 캔버스의 88~92%.
- 그림자를 넣을 경우 콘텐츠에 포함해 중앙 정렬 계산에 포함한다(별도 그림자 레이어 미지원).

---

## 3. 시점·방향 규칙

- **시점**: 톱다운(하이앵글) 3/4 뷰 고정. 캐릭터는 **화면 아래쪽(플레이어)을 향해 정면**으로 서 있는 한 장으로 그린다.
- **좌우 반전 없음**: 현재 코드는 이동 방향에 따라 `flip_h` 를 쓰지 않고 회전도 하지 않는다. 즉 **적·플레이어는 항상 같은 그림**이 보인다. 방향별 컷을 만들 필요 없다. **확인**
- **투사체만 회전한다**: 투사체 노드는 진행 방향으로 회전하므로, 아트는 **오른쪽(+X)을 향한 상태**로 그린다. **확인**
- **근접 잔상**도 발동 방향으로 회전한다. 부채꼴이 **오른쪽(+X)을 중심**으로 펼쳐지게 그린다.
- **장판·오라**는 회전하지 않는다. **방사 대칭**(원형)으로 그린다.

---

## 4. 데이터 필드 연결 방법 (어디에 지정하는가)

| 대상 | 파일 | 지정할 필드 |
|---|---|---|
| 적 | `data/animals/<id>.tres` | `sprite` = PNG, (선택) `sprite_size` = 표시 px, (선택) `tint_sprite` |
| 능력 이펙트 | `data/abilities/<id>.tres` | `attack_texture` = PNG, (투사체만) `projectile_size`, (선택) `tint_attack_texture` |
| 플레이어 | `scenes/player/player.tscn` 의 Player 노드 | `sprite_texture`, `sprite_display_size` |
| 젬·먹이 | `scenes/pickups/pickup.tscn` 의 Pickup 노드 | `essence_texture` / `feed_texture`, `essence_size` / `feed_size` |
| 사망 조각 | `scenes/effects/death_burst.tscn` | `shard_texture`, `shard_size` |

규칙:

- **`color` 필드는 지우지 말 것.** 실제 스프라이트를 넣어도 `AnimalData.color` 는 **사망 조각 이펙트 색**으로 계속 쓰인다. `AbilityData.color` 의 **알파 값**은 장판에 그대로 적용된다(근접 잔상은 0.14초 동안 알파가 감쇠하므로 알파 지정이 무의미하다). **확인**
- 기본적으로 실제 아트에는 색을 곱하지 않는다(원색 유지). 단색 실루엣 계열 아트를 색으로 구분하고 싶으면 `tint_sprite` / `tint_attack_texture` 를 켠다.
- 사망 조각(`shard_texture`)은 **동물 색으로 물들여** 쓰므로 **흰색/무채색**으로 그린다.

---

## 5. Godot 임포트 설정

### 5.1 프로젝트 전역으로 처리한 것 (이미 반영됨)

`project.godot` 의 `[importer_defaults] texture` — **새로 임포트되는 텍스처**에 자동 적용된다.

| 설정 | 값 | 근거 |
|---|---|---|
| `compress/mode` | `0` (무손실) | VRAM 블록 압축(S3TC/BPTC)은 **굵은 아웃라인과 알파 경계에 블록 아티팩트**를 만든다. 2D 전용이고 텍스처 수가 적어 VRAM 여유가 있으므로 화질을 택한다. |
| `mipmaps/generate` | `true` | 원화(128~512px)를 게임 내 24~52px로 **크게 축소**해 그린다. 밉맵이 없으면 캐릭터가 움직일 때 픽셀이 반짝이는 지글거림(aliasing)이 생긴다. |
| `process/fix_alpha_border` | `true` | 투명 픽셀의 RGB를 주변 색으로 메워, 선형 필터링 시 **경계에 검은 테두리(halo)** 가 생기는 것을 막는다. 투명 PNG + 선형 필터 조합에서 필수. |
| `detect_3d/compress_to` | `0` (끔) | 2D 전용 프로젝트인데 Godot이 3D 사용을 감지하면 텍스처를 자동으로 VRAM 압축으로 바꿔 버린다. 이를 차단해 위 무손실 설정을 지킨다. |

`project.godot` 의 렌더링 설정:

| 설정 | 값 | 근거 |
|---|---|---|
| `rendering/textures/canvas_textures/default_texture_filter` | `3` (Linear Mipmap) | 이 게임은 **픽셀아트가 아니라 굵은 아웃라인 카툰**이므로 Nearest(픽셀 보존)는 계단 현상만 남긴다. 축소 렌더링이 잦아 밉맵을 실제로 쓰려면 이 필터가 필요하다. |

> 검증: 이 설정으로 새로 임포트된 파일의 `.import` 에 `mipmaps/generate=true`, `detect_3d/compress_to=0` 이 실제로 기록되는 것을 확인했다. 또한 밉맵이 없는 기존 텍스처(`icon.svg`)도 필터 3에서 정상 렌더링됨을 스크린샷으로 확인했다. **확인**

### 5.2 파일별 `.import` 로만 처리되는 것

- **`[importer_defaults]` 는 "새로" 임포트되는 파일에만 적용된다.** 이미 `.import` 파일이 있는 기존 텍스처(예: `icon.svg`)는 예전 설정을 그대로 유지한다. **확인**
  - 기존 파일에 적용하려면: 해당 `.import` 를 지우고 재임포트하거나, 에디터 Import 독에서 값을 바꾸고 Reimport.
- 개별 예외가 필요한 경우도 파일별 `.import` 에서 처리한다:
  - **UI 아이콘**: 확대·축소가 거의 없으므로 `mipmaps/generate=false` 로 두어도 된다(용량·선명도 이득).
  - **아주 큰 장판 텍스처(512×512)**: 메모리가 부담되면 개별적으로 `compress/mode` 를 VRAM 압축으로 바꿀 수 있다(알파 경계 품질 저하 감수).

---

## 6. 팔레트 (DESIGN.md 2.3 준수)

| 용도 | HEX | 비고 |
|---|---|---|
| 배경/숲 바닥 | `#16241C` / `#241B18` | 아레나 배경(현재 `#16241C` 계열 단색) |
| 주인공/아군 | `#FFE7B3`(크림), `#4FE0C0`(청록) | 따뜻·밝은 계열로 적과 구분 |
| 포자/변이 발광 | `#9BFF57`(라임), `#FF5AD8`(마젠타) | 발광 부위 강조 |
| 적/위험 | `#8A4FFF`(병든 보라), `#FFB020`(앰버), `#3FBF6A`(독 초록) | 차갑거나 병든 계열 |
| XP/재화 | `#FFE14D` | 정수 젬 |

- **가독성 원칙**: 아군은 따뜻·밝게, 적은 차갑거나 병들게. 화면에 수십 마리가 겹쳐도 색만으로 위협 판단이 되어야 한다.
- 각 개체의 대표색은 §2.1(적)과 §8(체크리스트)에 개별 지정돼 있다. **AI 생성 후 후처리에서 이 색으로 색보정**해 통일하는 것을 권장한다.
- 공통 스타일 프롬프트는 DESIGN.md 2.3의 "공통 스타일" 문장을 시드로 고정하고 대상만 교체한다.

---

## 7. 아직 만들 필요 없는 것 (추후 과제)

- **변이/능력 아이콘**: `MutationData`/`AbilityData` 에 아이콘 필드도, 이를 표시하는 UI도 아직 없다. 카드·상점은 텍스트만 표시한다. 아이콘을 쓰려면 데이터 필드 + UI 작업이 먼저 필요하다.
- **애니메이션/스프라이트시트**: 현재 렌더링은 단일 정적 텍스처만 지원.
- **레이어드 진화 파츠**(DESIGN.md 4.1): 파츠 조합 렌더링 미구현.
- **보스**: 보스 개체가 아직 데이터에 없다.
- **배경 타일/분위기 오브젝트**: 아레나가 단색 `ColorRect` 다.

---

## 8. 생성 체크리스트 (작업 목록)

### P0 — 지금 넣으면 바로 게임에 반영되는 15종

| # | 대상 | 파일 경로 | 캔버스 | 표시 | 지정할 필드 | 대표색 |
|---|---|---|---|---|---|---|
| 1 | 플레이어(겁 많은 새끼 동물) | `player/player_cub.png` | 128×128 | 51px | `player.tscn` → `sprite_texture` | `#FFE7B3` |
| 2 | 포자 개미 | `animals/spore_ant.png` | 128×128 | 24px | `spore_ant.tres` → `sprite` | `#8D5AFF` |
| 3 | 변이 까마귀 | `animals/mutant_crow.png` | 128×128 | 26px | `mutant_crow.tres` → `sprite` | `#6D59D9` |
| 4 | 광포한 토끼 | `animals/rabid_hare.png` | 128×128 | 30px | `rabid_hare.tres` → `sprite` | `#C79EFF` |
| 5 | 쓸개즙 두꺼비 | `animals/bile_toad.png` | 128×128 | 38px | `bile_toad.tres` → `sprite` | `#3FBF6A` |
| 6 | 뒤틀린 멧돼지 | `animals/twisted_boar.png` | 256×256 | 52px | `twisted_boar.tres` → `sprite` | `#FFB020` |
| 7 | 가시(투사체) | `abilities/thorn_shot.png` | 64×64 | 15px | `thorn_shot.tres` → `attack_texture` | `#FFE14D` |
| 8 | 깃털(투사체) | `abilities/feather_burst.png` | 64×64 | 15px | `feather_burst.tres` → `attack_texture` | `#4FE0C0` |
| 9 | 발톱 휘두르기(근접 잔상) | `abilities/claw_swipe.png` | 256×256 | 236px | `claw_swipe.tres` → `attack_texture` | `#FF6659` (알파 0.7) |
| 10 | 독 분비(장판) | `abilities/venom_gland.png` | 512×512 | 192px | `venom_gland.tres` → `attack_texture` | `#3FBF6A` (알파 0.45) |
| 11 | 포자 구름(장판) | `abilities/spore_cloud.png` | 512×512 | 304px | `spore_cloud.tres` → `attack_texture` | `#FF5AD8` (알파 0.4) |
| 12 | 껍질 오라 | `abilities/shell_aura.png` | 512×512 | 236px | `shell_aura.tres` → `attack_texture` | `#6B9EBF` (알파 0.4) |
| 13 | 특성 정수(젬) | `pickups/essence_gem.png` | 32×32 | 12px | `pickup.tscn` → `essence_texture` | `#FFE14D` |
| 14 | 먹이 | `pickups/feed.png` | 32×32 | 16px | `pickup.tscn` → `feed_texture` | `#FF5AD8` |
| 15 | 사망 조각 | `fx/death_shard.png` | 32×32 | 6px | `death_burst.tscn` → `shard_texture` | 흰색/무채색(코드가 물들임) |

**권장 순서**: 2번(포자 개미) 1종을 먼저 끝까지 통과시켜 파이프라인을 검증한 뒤 나머지를 배치 생성한다.

### P1 — 필요 없음(코드가 자동 처리)

- 엘리트 변형: 1.6배 확대 + 앰버 혼합 자동. **별도 아트 불필요.**
- 방향별 컷·좌우 반전: 사용하지 않음. **불필요.**

### P2 — UI/시스템 작업이 먼저 필요 (지금 만들지 말 것)

- 변이 아이콘 24종, 능력 아이콘 6종 (표시 UI 없음)
- 보스, 배경 타일, 진화 파츠, 애니메이션 프레임

---

## 9. 검수 방법

새 스프라이트를 넣은 뒤 아래를 통과하면 완료로 본다.

```powershell
# 1) 임포트 (새 PNG를 엔진에 등록)
& $GODOT --headless --path D:\work\game --import

# 2) 자동 테스트 (회귀 없음 확인)
& $GODOT --headless --fixed-fps 60 --path D:\work\game res://scenes/tests/test_runner.tscn -- --combat=90 --soak=300

# 3) 육안 확인 (전투 화면 캡처)
& $GODOT --path D:\work\game res://scenes/tests/screenshot_capture.tscn -- --delay=9 --mode=gameplay --out=docs/screenshots/check.png
```

눈으로 볼 것:

- 크기가 다른 적들과 비교해 **상대적 크기**가 의도대로인가(§2.1 표).
- 어두운 배경(`#16241C`)에서 실루엣이 **또렷이 구분**되는가.
- 피격 시 **밝아지는 플래시**가 보이는가. (코드는 원래 색을 1.9배 밝힌다. 이미 흰색에 가까운 밝은 부위는 더 밝아질 여지가 없어 변화가 작다 — 완전한 흰색 위주의 아트는 피할 것.) **확인**
- 사망 시 튀는 조각 색이 대표색과 어울리는가(`AnimalData.color`).

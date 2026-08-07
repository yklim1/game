# Feral Bloom (가제)

동물 진화/변이 2D 로그라이트 서바이버. 1인 개발 / Cursor AI 기반.

변이 포자가 퍼진 야생에서, 작고 약한 동물 한 마리가 다른 동물의 특성(발톱·독·껍질·날개·엄니)을 흡수·변이하며 점점 리부짐한 괴수로 진화해 20분간 생존한다. 톤은 **어둡고 거친 다크 카툰** — 왕방울 눈·굵은 아웃라인의 실루엣은 남기되, 주인공은 차콜 털에 **진홍 발광 변이 문양**을 두른 "귀엽지만 상처 입고 사나운" 모습이다(승인 컨셉아트 `docs/concept/concept_hero_evolution_dark.png` 기준). (참고: Brotato형 코어 + Temtem:Swarm식 수집/시너지)

> 제목 후보: Feral Bloom / Beastly Bits / Mutant Menagerie (확정 전)

## 스택
- 엔진: Godot 4.7.x (GDScript, 타입 힌트 사용)
- 렌더러: GL Compatibility (2D + 넓은 호환성)
- 대상 플랫폼: PC (Steam 출시 목표)
- 버전관리: Git + GitHub

## 프로젝트 구조
- `scenes/` : 씬 파일(.tscn)
- `scripts/` : GDScript(.gd) — `tests/`는 테스트 전용, `tools/`는 개발용 생성 도구
- `assets/sprites/` : 2D 스프라이트(AI 생성 이미지 등)
- `assets/audio/` : 효과음(.wav) — 직접 합성한 플레이스홀더. 외부 사운드 파일은 쓰지 않는다.
- `data/` : 콘텐츠 정의 리소스(.tres) — `abilities/`, `animals/`, `waves/`, `mutations/`, `synergies/`
- `docs/` : 기획/설계/계획/아트 문서
- `docs/concept/` : 컨셉 아트 시안
- `docs/screenshots/` : 자동 캡처 스크린샷
- `.cursor/rules/` : 개발 규칙(범용 + 프로젝트 특화)

## 문서
- `docs/DESIGN.md` : 게임 디자인 문서(세계관·시스템·데이터 스키마·아키텍처)
- `docs/PLAN.md` : 단계별 개발 계획(Phase 0~출시, 버전 태그 v0.1~v1.0)
- `docs/ART_PIPELINE.md` : AI 아트 도구/라이선스/일관성 파이프라인
- `docs/ART_ASSET_SPEC.md` : 스프라이트 에셋 규격(캔버스·크기·명명·임포트 설정)과 생성 체크리스트

## 실행 방법
1. Godot 4.7.x 실행 → "가져오기(Import)"로 이 폴더의 `project.godot` 열기
2. 에디터에서 실행(F5)

## 자동 시뮬레이션 테스트 (사람 입력 없이 검증)

헤드리스로 게임을 실제로 돌리며 스폰·전투·XP/레벨업·3택 변이 카드·소굴 상점·계통 시너지·
게임오버·풀 재사용·UI 노드 누수·타격감(히트 플래시·넉백·사망 이펙트·화면 흔들림·히트스톱)·
효과음 트리거와 오디오 폴리포니·성능을 검증한다.
모두 통과하면 종료코드 0, 하나라도 실패하면 1을 반환한다.

```
"<Godot 콘솔 실행파일>" --headless --fixed-fps 60 --path . res://scenes/tests/test_runner.tscn -- --soak=300
```

- `--combat=<초>` : 전투 시뮬레이션 길이(기본 90). 웨이브 스케일링을 보려면 70초 이상.
- `--soak=<초>` : 소크 테스트 길이(기본 180). `--no-soak`으로 생략 가능.
- `--fixed-fps`는 실시간 동기화를 끄므로 5분 분량이 수 초 만에 끝난다.

창 모드로 몇 초 돌린 뒤 스크린샷을 저장하려면:

```
"<Godot 콘솔 실행파일>" --path . res://scenes/tests/screenshot_capture.tscn -- --delay=75 --out=docs/screenshots/phase2_gameplay.png
```

- `--mode=cards` : 강제로 레벨업시켜 3택 변이 카드 화면을 캡처
- `--mode=shop` : 강제로 웨이브를 종료시켜 소굴 상점 화면을 캡처
- `--mode=juice` : 히트 플래시·넉백·사망 이펙트·데미지 숫자·화면 흔들림이 동시에 보이는 순간을 캡처
- `--mode=sprite` / `--sprite-test` : 적 일부에만 런타임 생성 텍스처를 지정해 "실제 스프라이트 + 플레이스홀더 폴백" 혼재 상태를 캡처

## 플레이스홀더 효과음 생성

효과음은 외부 파일을 쓰지 않고 파형 합성으로 직접 만든다(라이선스 안전). 다시 만들려면:

```
"<Godot 콘솔 실행파일>" --headless --path . --script res://scripts/tools/generate_sfx.gd
"<Godot 콘솔 실행파일>" --headless --path . --import
```

> 새 `class_name` 스크립트를 추가한 직후에는 전역 클래스 캐시 갱신이 필요하다:
> `"<Godot 콘솔 실행파일>" --headless --path . --import`

## 개발 원칙
- 능력/동물/변이는 데이터(리소스 .tres)로 분리해 콘텐츠 재사용성을 높인다.
- 재미 우선: Phase 1 코어 루프(이동 + 자동공격 + 적 스폰 + 사망)가 재미없으면 폴리시 전에 방향 전환.

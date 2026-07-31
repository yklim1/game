# Feral Bloom (가제)

동물 진화/변이 2D 로그라이트 서바이버. 1인 개발 / Cursor AI 기반.

변이 포자가 퍼진 야생에서, 작고 약한 동물 한 마리가 다른 동물의 특성(발톱·독·껍질·날개·엄니)을 흡수·변이하며 점점 리부짐한 괴수로 진화해 20분간 생존한다. 톤은 왕방울 눈·굵은 아웃라인의 귀여움에 다크/타격감을 가미했다. (참고: Brotato형 코어 + Temtem:Swarm식 수집/시너지)

> 제목 후보: Feral Bloom / Beastly Bits / Mutant Menagerie (확정 전)

## 스택
- 엔진: Godot 4.7.x (GDScript, 타입 힌트 사용)
- 렌더러: GL Compatibility (2D + 넓은 호환성)
- 대상 플랫폼: PC (Steam 출시 목표)
- 버전관리: Git + GitHub

## 프로젝트 구조
- `scenes/` : 씬 파일(.tscn)
- `scripts/` : GDScript(.gd)
- `assets/sprites/` : 2D 스프라이트(AI 생성 이미지 등)
- `assets/audio/` : 사운드/음악
- `docs/` : 기획/설계/계획/아트 문서
- `docs/concept/` : 컨셉 아트 시안
- `.cursor/rules/` : 개발 규칙(범용 + 프로젝트 특화)

## 문서
- `docs/DESIGN.md` : 게임 디자인 문서(세계관·시스템·데이터 스키마·아키텍처)
- `docs/PLAN.md` : 단계별 개발 계획(Phase 0~출시, 버전 태그 v0.1~v1.0)
- `docs/ART_PIPELINE.md` : AI 아트 도구/라이선스/일관성 파이프라인

## 실행 방법
1. Godot 4.7.x 실행 → "가져오기(Import)"로 이 폴더의 `project.godot` 열기
2. 에디터에서 실행(F5)

## 개발 원칙
- 능력/동물/변이는 데이터(리소스 .tres)로 분리해 콘텐츠 재사용성을 높인다.
- 재미 우선: Phase 1 코어 루프(이동 + 자동공격 + 적 스폰 + 사망)가 재미없으면 폴리시 전에 방향 전환.

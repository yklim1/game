# Roguelite Survivor (Prototype)

Brotato 스타일 2D 로그라이트 서바이버. 1인 개발 / Cursor AI 기반.

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

## 실행 방법
1. Godot 4.7.x 실행 → "가져오기(Import)"로 이 폴더의 `project.godot` 열기
2. 에디터에서 실행(F5)

## 개발 메모
- 무기/적/업그레이드는 데이터(리소스)로 분리해 콘텐츠 재사용성을 높인다.
- 1주차 목표: 이동 + 자동공격 + 적 스폰 + 사망까지 "코어 루프" 검증.

# Cursor Rules 안내

이 폴더의 룰은 두 층위로 나뉩니다.

- **범용 (다른 게임 프로젝트로 복사 가능)**: `godot-gdscript-conventions.mdc`, `godot-architecture.mdc`, `godot-performance.mdc`
- **이 프로젝트 특화 (복사 금지)**: `project-survivor-specific.mdc`

## 다른 프로젝트로 재사용하는 법
1. 새 Godot 프로젝트의 `.cursor/rules/`에 위 `godot-*.mdc` 3개 파일만 복사한다.
2. `project-survivor-specific.mdc`는 복사하지 말고, 각 프로젝트에 맞게 새로 작성한다.
3. 범용 룰은 프로젝트 고유 명칭에 의존하지 않으므로 수정 없이 바로 적용된다.

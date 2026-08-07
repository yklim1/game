# assets/sprites

스프라이트(투명 PNG)를 넣는 곳. **규격과 체크리스트는 `docs/ART_ASSET_SPEC.md` 를 따른다.**

```
player/     플레이어
animals/    적(동물)
abilities/  투사체·근접 잔상·장판/오라
pickups/    정수 젬·먹이
fx/         사망 조각 등 이펙트
ui/icons/   변이·능력 아이콘 (표시 UI 미구현 — 아직 만들지 않는다)
```

파일명은 데이터의 `id` 와 같게 짓는다(`spore_ant.png` ↔ `data/animals/spore_ant.tres`).
PNG를 넣는 것만으로는 반영되지 않는다. 해당 `.tres`(또는 씬)의 텍스처 필드에 지정해야 한다.
필드가 비어 있으면 플레이스홀더(`icon.svg` + 색)로 계속 동작하므로 한 종류씩 교체해도 된다.

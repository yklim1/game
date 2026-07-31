# 2D 로그라이트 서바이버 — AI 아트 파이프라인 가이드

> 대상: 1인 개발, PC(Steam) 상업 출시. 2D 톱다운 서바이버. 아트 초심자, 예산 "가능하면 무료".
> 최종 확인일: 2026-07-31. 라이선스/약관은 수시로 바뀌므로 **출시 직전 각 공식 URL을 반드시 재확인**하세요.
> 표기 규칙: **확인** = 공식 문서/약관 문구로 검증됨, **추정** = 근거 기반 추론(단정 아님), **미확인** = 검증 못 함.

---

## 0. 핵심 요약 (먼저 읽기)

- **진짜 무료 + 상업 이용 가능한 조합**: 로컬에서 **FLUX.1 [schnell] (Apache-2.0)** 또는 **SDXL 1.0 (CreativeML OpenRAIL++-M)** 를 **ComfyUI / Automatic1111** 로 구동. 모델·툴·산출물 모두 상업 이용에 문제 없음(단 OpenRAIL 계열은 "금지 용도 조항" 준수 필수). **확인**
- **주의 1순위 — FLUX.1 [dev]**: 생성된 *이미지*는 상업 이용 가능하나, **모델 가중치(weights) 자체의 상업/프로덕션 사용은 금지**. dev를 로컬 상업 파이프라인의 엔진으로 쓰려면 BFL 상업 라이선스 필요. schnell과 혼동 금지. **확인**
- **Steam 공개(disclosure)**: 게임/스토어페이지/마케팅에 들어가는 AI 생성 **콘텐츠**는 Steamworks Content Survey에서 신고 필요(사전생성/실시간생성 구분). 반면 **코드 어시스턴트(Cursor 등) 같은 개발 도구는 신고 대상 아님**(2026-01 개정으로 명확화). **확인**

---

## 1. AI 이미지 생성 도구/모델 비교

### 1-A. 한눈에 보는 비교표

| 도구/모델 | 유형 | 비용 | 라이선스 | 상업 이용 | 무료 티어 | 공식 출처 |
|---|---|---|---|---|---|---|
| Stable Diffusion 1.5 | 로컬/오픈웨이트 | 무료 | CreativeML OpenRAIL-M | 가능(용도제한 조항 준수) | 해당없음(무료) | huggingface.co (아래 §7) |
| SDXL 1.0 (base+refiner) | 로컬/오픈웨이트 | 무료 | CreativeML **OpenRAIL++-M** | **가능**(용도제한 조항 준수) | 해당없음(무료) | stability.ai, github |
| FLUX.1 **[schnell]** | 로컬/오픈웨이트 | 무료 | **Apache-2.0** | **가능(가장 자유)** | 해당없음(무료) | huggingface.co |
| FLUX.1 **[dev]** | 로컬/오픈웨이트 | 무료(비상업) | **Non-Commercial License** | **모델 사용=불가**(이미지 상업이용 별개, 아래 주의) | 해당없음 | huggingface.co, github |
| FLUX.1 [pro] | 클라우드 API | 유료(per-gen) | API 상업 이용 포함 | 가능(유료) | 미확인(직접 확인 권장) | bfl.ai |
| ComfyUI | 실행환경 | 무료·오픈소스 | GPL-3.0(추정) | 툴 사용 무료 | 해당없음 | github (§7 확인 권장) |
| Automatic1111 (WebUI) | 실행환경 | 무료·오픈소스 | AGPL-3.0(추정) | 툴 사용 무료 | 해당없음 | github (§7 확인 권장) |
| Midjourney | 클라우드(유료) | $10~$120/월 | ToS: 유료구독자 산출물 소유 | **유료 플랜만 가능**(무료체험=CC BY-NC 4.0, 상업불가) | 무료체험(비상업) | docs.midjourney.com |
| OpenAI 이미지(DALL·E/GPT image) | 클라우드 | ChatGPT Plus $20/월 등 | ToS: Output 소유권 사용자에 양도 | **가능**(무료·유료 모두) | ChatGPT 무료 등급 | openai.com/policies |
| Leonardo.ai | 클라우드 | 무료/$12~$60월 | ToS 기준 | **가능**(무료=IP는 Leonardo 보유, 상업 라이선스 부여) | 150토큰/일(공개·워터마크) | leonardo.ai/pricing |
| Scenario | 클라우드(게임특화) | 무료/$15~$125월 | T&C: 유료=산출물 소유 | **유료 플랜만 가능**(무료=개인/평가용) | 50크레딧/일(상업불가) | scenario.com |
| Retro Diffusion (픽셀 특화) | Aseprite확장/웹 | $65 1회 / 웹 ~$0.01·건 | Astropulse: 산출물은 사용자 소유 | **가능** | 웹 50크레딧 체험 | astropulse.itch.io |
| PixelLab (픽셀 특화) | 웹/API | 크레딧·구독 | 미확인(약관 직접 확인) | 미확인 | 미확인 | pixellab.ai |

### 1-B. 로컬/오픈소스 상세

- **Stable Diffusion 1.5** — CreativeML **OpenRAIL-M**. 상업 이용 허용, 단 라이선스 "Attachment A 금지 용도"(불법·유해 콘텐츠 등)를 지키고 배포 시 조항 고지 의무. 경량이라 저사양에서 잘 돌아감(픽셀/스프라이트용 LoRA·모델 생태계 방대). *SD1.5의 정확한 라이선스 파일은 §7에서 재확인 권장(미러/재배포본마다 표기 차이 가능).*
- **SDXL 1.0** — CreativeML **OpenRAIL++-M** (2023-07-26). 상업/비상업 모두 허용, 금지 용도 조항(paragraph 5 / Attachment A) 준수 및 재배포 시 고지 의무. **확인** (stability.ai 공식 발표 + GitHub 라이선스 원문).
- **FLUX.1 [schnell]** — **Apache-2.0**. "personal, scientific, and commercial purposes"에 사용 가능이라 공식 명시. 1~4스텝 초고속. 상업 파이프라인에 가장 안전. **확인** (Hugging Face 모델 카드).
- **FLUX.1 [dev]** — **FLUX.1 [dev] Non-Commercial License**. 라이선스 원문: "You may only access, use, Distribute, or create Derivatives … for **Non-Commercial Purposes**", 상업 활동은 BFL 별도 라이선스 필요. 즉 **모델 가중치를 상업 게임 에셋 생산 엔진으로 쓰는 것은 불가**. (dev로 만든 이미지의 상업 이용 가능 여부는 별도 논점이며 해석 위험이 있으므로, 안전하게 가려면 dev 대신 schnell/SDXL 사용 권장.) **확인** (huggingface LICENSE.md, github model_licenses).
- **실행 환경(ComfyUI / Automatic1111)** — 둘 다 무료 오픈소스. ComfyUI는 노드형(배치·재현성·워크플로 공유에 강함, 스프라이트 대량생산에 유리), A1111은 입문 친화적. *구체 라이선스(GPL/AGPL 등)는 §7에서 확인 권장.*

### 1-C. 클라우드/유료 상세 (상업 조건 핵심)

- **Midjourney** — 유료 구독자는 산출물 소유("You own all Assets You create … to the fullest extent possible under applicable law"). **무료체험은 CC BY-NC 4.0으로 상업 불가.** 또한 **연 매출 $1M 초과** 기업/소속자는 Pro/Mega 필수. 기본은 이미지가 공개됨(비공개는 Pro+ Stealth). **확인** (docs.midjourney.com ToS).
- **OpenAI 이미지(DALL·E / GPT image)** — Terms of Use: "you own the Output. We hereby assign to you all our right, title, and interest … in and to Output." → 상업 이용 가능(무료·유료 무관). 단 무료/Plus는 학습에 사용될 수 있고, 순수 AI 산출물의 *저작권 등록/독점권*은 법적으로 제한적일 수 있음. **확인** (openai.com/policies).
- **Leonardo.ai** — 유료: 완전한 IP 소유 + 상업 이용. **무료(Apprentice 이전 등급): Leonardo가 IP 보유하되, 사용자에게 비독점·무료 상업 라이선스 부여 + 콘텐츠 공개.** 무료 150토큰/일, 워터마크. **확인** (leonardo.ai/pricing, 헬프센터).
- **Scenario (게임에셋 특화)** — 유료 플랜 = 전면 상업 라이선스 + 산출물 소유. **무료(50크레딧/일)는 개인·평가용, 상업 불가.** 스타일 일관성(커스텀 모델 학습)·게임 파이프라인에 특화. 커스텀 모델은 업로드 학습 데이터의 권리를 사용자가 책임. **확인** (scenario.com/pricing, T&C, FAQ).

### 1-D. 픽셀아트/게임에셋 특화

- **Retro Diffusion (Astropulse)** — 픽셀아트 전용 모델. Aseprite 확장($65 1회, Lite $20)은 로컬 정적 생성(구독·크레딧 없음), 웹/API는 건당 과금(~$0.01~). **"코드·모델은 Astropulse 소유·상업 불가, 산출물은 생성자 소유·상업 가능"** 을 공식 Q&A로 명시. 진짜 그리드 정렬 픽셀 출력이 강점. **확인** (astropulse.itch.io).
- **PixelLab** — 캐릭터/애니메이션/타일 등 인디 특화 API·웹. 방향 회전·애니메이션 지원. **라이선스/상업 조건은 미확인 → 사용 전 pixellab.ai 약관 직접 확인.**
- 참고: 순수 SD/DALL·E/Midjourney는 "진짜 픽셀아트"(정확한 격자·제한 팔레트)를 잘 못 만드는 경향 → 픽셀 스타일이면 전용 툴 또는 후처리 픽셀화가 현실적.

---

## 2. "진짜 무료로 상업적 게임 에셋" 조합

**권장(무료·상업 안전)**:
- 모델: **FLUX.1 [schnell] (Apache-2.0)** 또는 **SDXL 1.0 (OpenRAIL++-M)** — 둘 다 상업 가능. schnell이 라이선스가 가장 단순, SDXL이 LoRA/ControlNet 생태계가 가장 풍부.
- 실행: **ComfyUI**(대량·재현성) 또는 **A1111**(입문).
- **피해야 할 함정**: 로컬 파이프라인의 생성 엔진으로 **FLUX.1 [dev]** 사용(비상업 라이선스). dev 기반 LoRA/파생도 동일 제약. → schnell/SDXL로 대체.
- OpenRAIL 계열 준수: 불법·유해 용도 금지 조항(Attachment A)만 지키면 게임 에셋 상업 이용 OK.

**하드웨어 요구(추정, 커뮤니티 일반 기준 — 정확 수치는 각 배포 문서 확인)**:
- SD1.5: VRAM 4~6GB부터 실사용 가능(가장 가벼움).
- SDXL 1.0: VRAM 8GB 권장, 12GB+ 여유. 
- FLUX.1 (schnell/dev): VRAM 12GB 권장, 24GB+ 쾌적(양자화/저VRAM 모드로 8~12GB에서도 구동 사례 있음, **추정**).
- 저사양·GPU 없음: 클라우드 무료 티어(Leonardo)나 소액 종량제(Scenario 유료/Retro Diffusion 웹)가 현실적 대안.

---

## 3. 스타일 일관성 확보 파이프라인 (톱다운 스프라이트)

일관성이 최대 난관이므로 **여러 기법을 조합**하는 것이 핵심입니다.

1. **프롬프트 템플릿 고정**: 공통 접두/접미 블록을 만든다. 예) `top-down view, [subject], 2D game sprite, flat shading, clean silhouette, centered, transparent background, [팔레트 키워드], consistent lighting from top`. 대상만 교체.
2. **시드(seed) 고정 + 파라미터 고정**: 같은 시드·샘플러·스텝·CFG를 유지하면 변주 폭이 줄어 룩이 안정. (ComfyUI에서 워크플로 저장해 재사용.)
3. **스타일 레퍼런스**: Midjourney는 `--sref`(스타일 참조)·`--cref`, 로컬은 **IP-Adapter / reference-only(ControlNet)** 로 기준 이미지를 물려 룩 통일.
4. **ControlNet**: 톱다운 실루엣·포즈·구도 통제. 캐릭터/적을 같은 포즈·시점으로 뽑을 때 특히 유용(lineart, canny, pose, depth).
5. **img2img**: 이미 만든 기준 스프라이트를 낮은 denoise로 변주 → 같은 화풍의 변형(색만 다른 적, 무기 변형)에 효과적.
6. **LoRA 학습(최고 수준 일관성)**: 마음에 드는 소수 스프라이트로 스타일/캐릭터 LoRA를 학습(kohya_ss 등, 로컬 무료). 이후 모든 생성에 적용 → 화풍 재현성 최상. Scenario는 웹에서 커스텀 모델 학습을 제공(유료).
7. **팔레트 통일**: 공용 팔레트를 정해두고, 후처리에서 모든 에셋을 그 팔레트로 강제 매핑(§4).
8. **실전 순서 예시**: ① 기준 캐릭터 1~2장 확정 → ② (선택)LoRA 학습 → ③ 시드/템플릿 고정으로 적·무기·투사체·아이콘 대량 생성(ControlNet로 시점 고정) → ④ img2img로 변형 파생 → ⑤ §4 후처리로 배경 제거·픽셀화·팔레트 통일·시트화.

---

## 4. 후처리 실전 (무료 도구)

| 작업 | 무료 도구 | 비고 |
|---|---|---|
| 배경 제거(투명 PNG) | **rembg** (MIT, u2net 계열 모델), GIMP, Krita | rembg는 배치 자동화에 강함(CLI). 미세 경계는 수동 보정 권장 |
| 축소/픽셀화 | **Aseprite**(유료 $19.99)·**LibreSprite**(무료·GPL)·Krita·GIMP | 다운스케일 후 인덱스 컬러로 픽셀 느낌 강화 |
| 팔레트 통일 | Aseprite/LibreSprite(인덱스 컬러 지정), GIMP(Indexed 모드) | 공용 `.gpl`/`.pal` 팔레트로 전 에셋 매핑 |
| 스프라이트 시트화 | Aseprite(export sheet), **TexturePacker**(무료 등급 존재), 무료 스크립트 | 프레임/아틀라스 규격을 엔진에 맞춤 |
| 종합 편집 | **GIMP**(GPL, 무료), **Krita**(GPL, 무료) | 다듬기·합성·마스킹 |

- **Aseprite**: 앱 자체는 유료지만 소스는 공개. **본인이 만든 아트의 상업 이용은 자유**. 무료 대안은 **LibreSprite**(Aseprite 구버전 포크, GPL).
- 개별 도구 라이선스(예: rembg=MIT, GIMP/Krita/LibreSprite=GPL)는 "도구 자체" 라이선스이며, **당신이 만든 결과물(아트)의 상업 이용을 막지 않음**. (정확 버전 라이선스는 각 저장소 확인 권장.)

---

## 5. 추천 스택 2종

### (A) 완전 무료 우선 스택
- 구성: **로컬 FLUX.1 [schnell] 또는 SDXL 1.0 + ComfyUI** → **kohya_ss로 스타일 LoRA(선택)** → **rembg + LibreSprite/Krita + GIMP** 후처리.
- 장점: 비용 0원, 무제한 반복, 오프라인, 상업 라이선스 명확(Apache-2.0 / OpenRAIL++-M).
- 단점: **GPU(권장 VRAM 8~12GB+) 필요**, 초기 설치·학습 곡선, 일관성 확보에 손이 많이 감.
- 워크플로: 기준 캐릭터 확정 → (LoRA) → 시드/템플릿/ControlNet 고정 대량 생성 → 후처리 → 시트화.

### (B) 소액 예산 스택
- 구성: **Scenario(유료, 게임에셋·커스텀 모델 특화)** 를 메인으로, 픽셀 스타일이면 **Retro Diffusion($65 1회 Aseprite 확장)** 병행. 마무리 후처리는 무료 도구.
- 장점: GPU 불필요, 커스텀 모델로 일관성 쉽게 확보, 게임 파이프라인 친화, 상업 라이선스 명확(유료 플랜).
- 단점: 월 구독/크레딧 비용, 무료 티어는 상업 불가(Scenario·Midjourney), 클라우드 의존.
- 대안 조합: **Leonardo.ai 유료(월 $12~)** + 무료 후처리. (Midjourney는 룩은 좋으나 픽셀·톱다운 스프라이트·투명배경 배치 생산에는 상대적으로 불편.)

> 현실적 추천: **초기엔 (A)로 비용 0**으로 시작하되 일관성·시간이 부담되면 **(B) Scenario 또는 Retro Diffusion**을 부분 도입하는 하이브리드.

---

## 6. Steam 출시 시 AI 콘텐츠 공개(disclosure) 정책

출처: Steamworks **Content Survey** 공식 문서(partner.steamgames.com) + 2026-01-16/17 정책 개정 보도.

- **어디서**: Steamworks Content Survey의 **Generative AI 섹션**(General / Mature / Generative AI 3개 필수 섹션 중 하나). 신고 내용은 스토어페이지 "AI Generated Content Disclosure"로 공개됨. **확인**
- **무엇을 신고**: 게임에 실려 **플레이어가 소비하는** AI 생성 콘텐츠 — 아트, 사운드, 내러티브, 로컬라이제이션 등. **게임 본편 + 스토어페이지 + 마케팅/커뮤니티 에셋** 포함. **확인**
- **두 유형 구분**: **확인**
  - **Pre-Generated(사전 생성)**: 개발 중 AI로 만들어 게임에 포함되는 콘텐츠 → 간단 설명 제출. (Valve는 일반 콘텐츠와 동일 기준으로 불법/침해/마케팅 일치 여부 심사.)
  - **Live-Generated(실시간 생성)**: 게임 실행 중 AI가 생성하는 콘텐츠 → 추가로 **불법 콘텐츠 방지 가드레일**을 기술해야 함. (실시간 생성 성인용 성적 콘텐츠는 절대 금지.)
- **신고 대상 아님(2026-01 개정으로 명확화)**: 순수 **개발 효율용 AI 도구**(예: 코드 어시스턴트, 디버깅, 최종 산출물에 안 들어가는 아이디에이션용 컨셉 생성). → **Cursor로 코딩만 하는 것은 신고 불필요.** 그러나 **AI로 만든 아트를 게임/스토어에 넣으면 신고 필요.** **확인**
- 규칙 준수는 공개 여부와 무관하게 항상 필수(불법·침해 콘텐츠 금지). 승인·출시 후 서베이 수정은 Steam 지원 문의 필요. **확인**

---

## 7. 공식 출처 URL

- FLUX.1 schnell (Apache-2.0): https://huggingface.co/black-forest-labs/FLUX.1-schnell
- FLUX.1 dev 라이선스(비상업): https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md , https://github.com/black-forest-labs/flux/blob/main/model_licenses/LICENSE-FLUX1-dev
- Black Forest Labs(상업 라이선스 문의): https://www.bfl.ai
- SDXL 1.0 발표(OpenRAIL++-M): https://stability.ai/news-updates/stable-diffusion-sdxl-1-announcement
- SDXL 1.0 라이선스 원문: https://raw.githubusercontent.com/Stability-AI/generative-models/main/model_licenses/LICENSE-SDXL1.0
- SDXL base 모델/라이선스: https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0
- Stable Diffusion 1.5(라이선스 재확인용): https://huggingface.co/runwayml/stable-diffusion-v1-5 (미러: https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5)
- ComfyUI: https://github.com/comfyanonymous/ComfyUI
- Automatic1111 WebUI: https://github.com/AUTOMATIC1111/stable-diffusion-webui
- Midjourney ToS: https://docs.midjourney.com/hc/en-us/articles/32083055291277-Terms-of-Service
- OpenAI Terms of Use(개인): https://openai.com/policies/row-terms-of-use/ , 서비스 약관(API/기업): https://openai.com/policies/services-agreement/
- Leonardo.ai 가격/소유권: https://leonardo.ai/pricing , 상업 이용 안내: https://intercom.help/leonardo-ai/en/articles/8044018-commercial-usage
- Scenario 약관: https://www.scenario.com/terms-and-conditions , 가격: https://www.scenario.com/pricing
- Retro Diffusion(Aseprite 확장·라이선스 Q&A): https://astropulse.itch.io/retrodiffusion , 웹: https://astropulse.itch.io/retrodiffusionai
- PixelLab(약관 직접 확인 필요): https://www.pixellab.ai
- Steam Content Survey(AI 공개 정책 원문): https://partner.steamgames.com/doc/gettingstarted/contentsurvey?language=english

---

## 8. 면책

본 문서는 공식 문서 확인을 근거로 정리했으나 **법률 자문이 아닙니다.** 상업 출시 전 각 서비스 최신 약관을 직접 확인하고, 매출 규모·배포 방식이 특수하면 전문가 검토를 받으세요. 특히 "미확인/추정" 항목과 OpenRAIL 금지 용도 조항, FLUX dev 제약은 반드시 재확인하세요.

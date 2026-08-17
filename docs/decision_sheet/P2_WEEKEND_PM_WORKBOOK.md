# 🦙 Cloud Alpacas — P2 Weekend PM Workbook

> 화요일 의사결정 회의 전까지 **노트북 없이 모바일에서** B2B Phase 2의 공통 기준을 정리하는 PM 작업 노트입니다.
>
> **원칙:** 확정은 `✅`, 논의 중은 `⭐️ TBD`. Salesforce Object/Field/Flow는 화요일 전 임의 확정하지 않습니다.

## 0. Weekend Goal

화요일에 5명이 바로 작업할 수 있도록 준비한다.

- [x] ① B2B Story / 대표 Scenario
- [x] ② Common Object / Relationship Map
- [x] ③ Dummy Data Master — `P2_DUMMY_DATA_MASTER.md`
- [x] ③-1 Data Contract(Ownership/Relationship) — `P2_DATA_CONTRACT.md`
- [ ] ④ Feature별 Definition of Done

**현재:** Phase 1 B2C Fan 360 MVP 완료 → B2C 고도화 + B2B Collaboration/Sponsorship Expansion

---

# 1. [P2] B2B Story

## 이 매니저의 핵심 문제

> 팬은 늘고 있지만 구단 재정 운영상 적자. 팬 데이터를 활용해 어떤 기업과 제휴해야 할지 판단하고, 실제 Collaboration으로 검증한 뒤 장기 Partnership/Sponsorship으로 발전시키고 싶다.

### Pain → Need → Goal

| 구분 | 내용 |
|---|---|
| **Pain** | 팬은 늘고 있는데 구단 재정은 여전히 적자다. "유명한 회사"에 감으로 제안서를 보내는 방식이라, 실제로 팬층과 궁합이 맞는지 확인할 근거가 없다. 검증 없이 바로 장기 계약을 맺으면 리스크가 크고, 협업 성과를 다음 판단에 반영할 체계도 없다. |
| **Need** | Fan 360 데이터를 근거로 "우리 팬층과 실제로 Fit이 높은 기업"을 찾아낼 방법, 그리고 장기 계약 전에 리스크를 낮게 검증할 수 있는 단계(Lead → 단기 Collaboration)가 필요하다. |
| **Goal** | Fan 360 데이터 → 팬층 특성 발견 → 기업 Fit 가설 → 후보 검증 → 단기 Collaboration → 성과 기반 장기 Partnership/Sponsorship 전환까지, 감이 아니라 데이터로 이어지는 흐름을 만든다. |

### 이 매니저의 실제 업무

1. Fan 360 데이터(관심사·구매·관람·Engagement)를 분석해 뚜렷한 특성을 가진 팬층을 발견한다.
2. 그 팬층과 궁합이 좋을 만한 기업/브랜드 후보에 대한 가설을 세운다.
3. 가설에 맞는 실제 기업 후보를 찾아 **Business Fit**을 검토하고, 확인되면 Lead로 등록해 접촉·제안(Proposal)을 진행한다. *(`01_PROJECT.md` §6.11 — Lead는 "아직 관계 없는 가설 단계 후보", Proposal은 "실제 접촉 성사 후 Opportunity 진행 중 오가는 제안"으로 서로 다른 개념 — Salesforce 구현 방식은 화요일 TBD)*
4. 검증되지 않은 상대와 바로 장기 계약 대신, 단기 Collaboration으로 먼저 가설을 검증한다.
5. Collaboration 성과(팬 반응·참여율)를 Fan 360 데이터와 함께 다시 살펴보고, 장기 Partnership/Sponsorship 여부를 판단한다.

---

# 2. [P2] 대표 Scenario

## SCN-B2B-001

**Scenario:** 10~30대 여성 팬 × 브랜드 Collaboration

> ⚠️ Sanrio / Hello Kitty는 현재 Demo 예시일 뿐. 실제 브랜드 사용 여부는 팀 결정.
> ⚠️ 아래 수치는 **Demo/Workbook용 가상 데이터**다 — 실제 Dummy Data(§4)를 이 숫자에 맞춰 준비하거나, 팀 논의 후 조정한다. 사실로 확정된 값이 아니다.

### Trigger

이 매니저가 Fan 360 데이터를 정기적으로 살펴보던 중, 최근 3개월 사이 특정 팬층에서 뚜렷한 증가 추세를 발견한다.

### Fan Insight

우리 팬은:

- 전체 Fan 중 **10~30대 여성 비중이 최근 3개월간 18% → 27%로 증가** *(`P2_DUMMY_DATA_MASTER.md` §2.1 — 가입일 3개월 전/후 코호트로 정확히 재현됨)*
- 이 그룹의 **문선수 관련 굿즈 구매 전환율이 약 38%(8명 중 3명)** — 전체 평균(약 15%) 대비 약 2.5배 높음 *(`P2_DUMMY_DATA_MASTER.md` §2.2 — 정수 인원 8명으로 정확히 42%를 재현할 수 없어 실제 배정 가능한 값으로 조정)*
- 이 그룹의 **SNS 공유/반응률이 정확히 2배** *(`P2_DUMMY_DATA_MASTER.md` §2.3 — 대표팬 평균 2건, 비대표팬 평균 1건으로 설계)*

### Business Fit 가설

이 팬층과 잘 맞을 것 같은 기업:

- 캐릭터 IP 기반 굿즈/컬래버레이션 브랜드 (예: Sanrio/Hello Kitty류 — **Demo 예시**)
- 10~30대 여성 타깃 라이프스타일/뷰티 브랜드 *(가상 후보군, 팀 논의로 구체화 필요)*

### 전체 흐름

`Fan Insight → Candidate Discovery → Lead → Account/Contact → Opportunity → Short-term Collaboration → Performance → Partnership/Sponsorship`

### Demo 성공 기준

> "Fan 360 데이터가 B2B 영업에 어떻게 쓰이는지 이해된다."

---

# 3. [P2] Common Object / Relationship

| Business | Salesforce | Status |
|---|---|---|
| Fan | Person Account | ✅ Existing |
| Fan Insight | Report / Report Type | ✅ Direction |
| Partner Candidate | Lead 흡수 가능성 | ⭐️ TBD |
| Lead | Standard Lead | ⭐️ TBD |
| Partner | Account | ⭐️ P2 Candidate |
| Partner Contact | Contact | ⭐️ P2 Candidate |
| Opportunity | Opportunity | ✅ Standard 재사용 |
| Sponsorship Package | Product2 / Pricebook | ⭐️ TBD |
| Proposal | Opportunity 내 관리 가능성 | ⭐️ TBD |
| Collaboration(Campaign 사용 자체) | Campaign | ✅ 확정 |
| Collaboration(RecordType vs Lookup) | — | ⭐️ TBD — 잠정 Lookup(§3-③) |
| Quote | Standard Quote + QuoteLineItem | ✅ 확정 (Wireframe 근거, §3-④) |
| Performance | Report / Dashboard | ✅ No new Object 방향 |

### Relationship

```text
Fan 360
  ↓
Fan Insight / Grouping
  ↓
Candidate
  ↓
Lead
  ↓
Account ─ Contact
  ↓
Opportunity
  ├─ Product / Sponsorship Package
  ├─ Quote (확정)
  └─ Collaboration / Campaign (사용 확정, RecordType vs Lookup은 TBD)
          ↓
      Performance
          ↓
Partnership / Sponsorship
```

### 화요일 확인 — Architect 관점 사전 검토

> Decision 003 "Standard First, Custom When Needed" 원칙을 모든 항목에 기본 전제로 깔았다.
> 아래 권장안은 화요일 논의를 빠르게 시작하기 위한 **초안**이며, 팀 논의 결과가 우선한다.

#### ① Lead를 Standard Lead로 쓸 것인가?

| | A. Standard Lead 사용 | B. 비활성 Account로 관리 |
|---|---|---|
| 장점 | Convert 기능 기본 제공(Account+Contact+Opportunity 자동 생성), Lead Source/Status 등 표준 필드·리포트 즉시 사용 가능, 팀 러닝커브 낮음 | Account 하나로 후보~고객까지 이력을 끊김 없이 유지, 별도 Convert 로직 불필요 |
| 단점 | B2C의 Person Account와 별개 오브젝트라 팀이 "또 다른 오브젝트"를 배워야 함 | Salesforce가 원래 의도한 "후보 단계" 개념과 어긋나 억지스러움, Report/Dashboard에서 진짜 Account와 섞여 헷갈릴 위험 |
| **권장** | **A** — Lead는 Salesforce가 정확히 이 용도로 설계한 표준 오브젝트라, Standard First 원칙에 가장 잘 맞음 | |

#### ② Partner Candidate 별도 Object가 필요한가?

| | A. 별도 Custom Object | B. Lead에 흡수(Status/Field로 표현) |
|---|---|---|
| 장점 | "아직 Lead로 확정 짓기도 애매한, 가설 단계 후보"를 명확히 분리해서 관리 가능 | 새 Object 없이 Lead의 Status(`가설 단계`)나 커스텀 필드로 표현 — 구조 단순, 유지보수 부담 적음 |
| 단점 | MVP 단계에서 Object 하나 늘 때마다 Page Layout/권한/Flow를 전부 새로 관리해야 함 — Baby Team 리소스 부담 | "후보(가설)"와 "실제 영업 대상(Lead)"의 경계가 필드값 하나로만 구분되어, 화면상 구분이 약할 수 있음 |
| **권장** | **B** — MVP 범위와 팀 규모를 고려하면, Lead Status 세분화("Candidate" → "Qualified" → "Contacted")로 시작하고, 실제로 후보 수가 많아지고 관리가 복잡해질 때 A로 승격하는 것이 안전 | |

#### ③ Collaboration은 Campaign으로 표현할 것인가?

| | A. Campaign + RecordType 구분 | B. Campaign 그대로 + 단순 관계/필드 | C. 별도 Custom Object |
|---|---|---|---|
| 장점 | 표준 기능(Campaign Member 등) 활용 + 화면상 "Collaboration"임이 명확히 구분됨 | 표준 기능 그대로 활용, RecordType/Page Layout 추가 설정 없이 가장 단순 | Collaboration 고유 정보를 자유롭게 설계 가능 |
| 단점 | RecordType 추가 설정 부담 | "Collaboration"이라는 구분이 화면에 약하게만 드러남(Type 필드 등으로 대체) | Object 추가, Standard First 원칙과 충돌 |
| **팀 결정** | | ✅ **`P2_TECHNICAL_DECISION_SHEET.md` D안 권장 — B** | |

> ⭐️ 수정 이력: 처음엔 Architect 관점만으로 A(RecordType)를 권했으나, 이미 팀이
> Technical Decision Sheet D안에서 B로 방향을 정해둔 상태였다. 기존 팀 결정 문서를
> 먼저 확인하지 않고 판단한 게 원인이라, **B를 기본값으로 되돌리고 RecordType 도입
> 여부는 화요일 최종 확정 전까지 TBD로 유지**한다.

#### ④ Quote가 실제로 필요한가?

| | A. Standard Quote 도입 | B. 도입하지 않음(Opportunity로 충분) |
|---|---|---|
| 장점 | 정식 견적서 PDF 생성/버전 관리가 필요할 때 유용 | MVP 범위에서 "얼마에 제안하는가"는 Opportunity Amount + Product Line Item으로 이미 표현 가능 — 불필요한 복잡도 회피 |
| 단점 | Baby Team이 Quote Template까지 새로 학습해야 함 — Demo 범위 대비 과함 | 정식 견적서 문서가 필요한 경우 표현 불가 |
| **확정** | ✅ **A — Wireframe Object Map에 `Quote + QuoteLineItem (Standard)`이 Opportunity와 1:N, QuoteLineItem→Product2로 명시되어 있어 확정** | |

> ⭐️ 수정 이력: 처음엔 "MVP엔 불필요"로 B를 권했으나, 팀 Wireframe에 이미 Quote 화면이
> 설계되어 있는 걸 확인해 A로 정정한다. 승우님(E) 담당 영역에 Quote 생성/QuoteLineItem
> 연결이 포함된다.

#### ⑤ Sponsorship Package는 Product2로 충분한가?

| | A. Product2 재사용 | B. 별도 Object |
|---|---|---|
| 장점 | 이미 Ticket/Membership/Goods에서 쓰던 Product2 + Pricebook 패턴을 그대로 재사용 — 팀이 이미 익숙함(Decision 기록 다수) | Sponsorship 특유의 정보(노출 매체, 계약 기간, 독점 여부 등)를 필드로 자유롭게 설계 |
| 단점 | Sponsorship 특유의 속성이 늘어나면 Product2가 "팬 상품"과 "스폰서십 패키지"라는 이질적 개념을 한 오브젝트에 억지로 담게 될 위험 | Object 추가 부담, Pricebook 연동을 처음부터 다시 설계해야 함 |
| **권장** | **A** — Record Type으로 구분(Decision 004 방식과 동일 패턴)하고, Sponsorship 전용 필드만 최소로 추가. Product2 하나로 시작하고 필요해지면 분리하는 게 Standard First에 맞음 | |

---

# 4. [P2] Dummy Data Master

✅ 완료 — 별도 파일 `P2_DUMMY_DATA_MASTER.md`(Fan 30명 + SCN-B2B-001 Master Data + 계산 기준)와 `P2_DATA_CONTRACT.md`(Owner/Relationship)로 분리했다.

*(§5~§8은 화요일 회의 후 채운다 — 원본 Workbook 구조 유지)*

---

# 5. Feature별 Definition of Done

⭐️ TBD — 화요일 회의 후 각 담당자(승우/혜준/아론/은영)와 함께 채운다.

---

# 6. 모바일 대화 기록

## [날짜 / 주제]

**Question:**
**Discussion:**
**Insight:**
**Decision 후보:**
**TBD:**

---

# 7. 집에 돌아온 후

- [ ] Decision Log 정리
- [ ] `05_DECISIONS.md` 업데이트
- [ ] `03_SYSTEM.md` 업데이트
- [ ] `02_TEAM_GUIDE.md` / `members/` 업데이트
- [ ] `04_DEMO.md` 업데이트
- [ ] `data/DEMO_DATA_STANDARD.md` 업데이트
- [ ] Dummy Data Master 작성
- [ ] Org 연결 후 Metadata Verification

---

## ⭐ PM Note

> **이번 주말의 목표는 완성이 아니다.**
>
> 월요일에 팀원들이 바로 만들 수 있을 만큼 **Story / Scenario / Data / Ownership의 공통 언어를 만드는 것**이다.
>
> 좋은 PM은 모든 답을 미리 정하는 사람이 아니라, **팀이 좋은 결정을 내릴 수 있도록 질문과 기준을 준비하는 사람**이다.

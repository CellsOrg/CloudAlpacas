# 🦙 Cloud Alpacas — P2 Weekend PM Workbook

> 화요일 의사결정 회의 전까지 **노트북 없이 모바일에서** B2B Phase 2의 공통 기준을 정리하는 PM 작업 노트입니다.
>
> **원칙:** 확정은 `✅`, 논의 중은 `⭐️ TBD`. Salesforce Object/Field/Flow는 화요일 전 임의 확정하지 않습니다.

## 0. Weekend Goal

화요일에 5명이 바로 작업할 수 있도록 준비한다.

- [ ] ① B2B Story / 대표 Scenario
- [ ] ② Common Object / Relationship Map
- [ ] ③ Dummy Data Master
- [ ] ④ Feature별 Definition of Done

**현재:** Phase 1 B2C Fan 360 MVP 완료 → B2C 고도화 + B2B Collaboration/Sponsorship Expansion

---

# 1. [P2] B2B Story

## 이 매니저의 핵심 문제

> 팬은 늘고 있지만 구단 재정 운영상 적자. 팬 데이터를 활용해 어떤 기업과 제휴해야 할지 판단하고, 실제 Collaboration으로 검증한 뒤 장기 Partnership/Sponsorship으로 발전시키고 싶다.

### Pain → Need → Goal

| 구분 | 내용 |
|---|---|
| Pain | |
| Need | |
| Goal | |

### 이 매니저의 실제 업무

1.
2.
3.
4.

---

# 2. [P2] 대표 Scenario

## SCN-B2B-001

**Scenario:** 10~30대 여성 팬 × 브랜드 Collaboration

> ⚠️ Sanrio / Hello Kitty는 현재 Demo 예시일 뿐. 실제 브랜드 사용 여부는 팀 결정.

### Trigger


### Fan Insight

우리 팬은:

- 
- 
- 

### Business Fit 가설

이 팬층과 잘 맞을 것 같은 기업:

- 
- 

### 전체 흐름

`Fan Insight → Candidate Discovery → Lead → Account/Contact → Opportunity → Short-term Collaboration → Performance → Partnership/Sponsorship`

### Demo 성공 기준

> “Fan 360 데이터가 B2B 영업에 어떻게 쓰이는지 이해된다.”

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
| Collaboration | Campaign 가능성 | ⭐️ TBD |
| Quote | Standard Quote 가능성 | ⭐️ TBD |
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
  ├─ Quote ?
  └─ Collaboration / Campaign ?
          ↓
      Performance
          ↓
Partnership / Sponsorship
```

### 화요일 확인

- [ ] Lead를 Standard Lead로 쓸 것인가?
- [ ] Partner Candidate 별도 Object가 필요한가?
- [ ] Collaboration은 Campaign으로 표현할 것인가?
- [ ] Quote가 실제로 필요한가?
- [ ] Sponsorship Package는 Product2로 충분한가?

---

# 4. [P2] Dummy Data Master

## Fan Data

**권장 Demo 규모:** 30~50명  
현재 20명 전후 → 그룹 분석을 보여주려면 확대 검토.

### 반드시 의미 있게 보여줄 조합

- [ ] 연령 × 성별
- [ ] 성별 × Engagement
- [ ] 성별 × Fan Value
- [ ] Favorite Player × Engagement
- [ ] 관람 × 지출
- [ ] Life Cycle 차이

| 구분 | 목표 |
|---|---:|
| 전체 Fan | 30~50 |
| 남/여 | |
| 주요 연령대 | |
| Life Cycle | |
| Engagement | |
| Fan Value | |
| Favorite Player | |

## B2B Data

| Record | 수량 | Owner | 연결 |
|---|---:|---|---|
| Lead / Candidate | | 혜준 | Fan Insight |
| Account | | 아론 | Lead |
| Contact | | 아론 | Account |
| Opportunity | | 은영 | Account |
| Product | | 승우 | Opportunity |
| Quote | | 승우 | Opportunity |
| Campaign / Collaboration | | 승우 | Opportunity |
| Performance | | TBD | Collaboration |

### Shared Scenario ID

`SCN-B2B-001`

모든 Dummy Data는 가능하면 같은 Scenario로 연결한다.

---

# 5. [P2] Feature Owner / DoD

### 🦙 Sara — Fan 360 고도화 + B2B 연결
**Mission:** Fan 360 데이터를 B2B Fan Insight로 연결.

- [ ] Fan Grouping
- [ ] Fan Insight
- [ ] B2C → B2B 연결
- [ ] Scenario Fan Data
- [ ] QA

`Requirement → Data → Report/Screen → QA → B2B 연결`

### 🔎 Hyejun — Collab360 + Lead
**Mission:** Fan Insight를 Partner Candidate / Lead로 연결.

- [ ] Candidate / Lead
- [ ] Lead Score
- [ ] Matching / Recommendation
- [ ] Lead Conversion
- [ ] QA

### 🏢 Aaron — Account + Contact
**Mission:** 실제 제휴 기업과 담당자 관리.

- [ ] Partner Account
- [ ] Partner Contact
- [ ] Relationship
- [ ] Lead Conversion 연결
- [ ] QA

### 💼 Eunyeong — Opportunity
**Mission:** 제휴 가능성을 Business Opportunity로 관리.

- [ ] Opportunity
- [ ] Stage
- [ ] Benefit
- [ ] Proposal 위치
- [ ] QA

### 🎁 Seungwoo — Product + Quote + Campaign
**Mission:** Collaboration을 실행 가능한 상품/캠페인으로 연결.

- [ ] Product / Sponsorship Package
- [ ] Quote 필요성
- [ ] Campaign / Collaboration
- [ ] Performance 연결
- [ ] QA

---

# 6. 화요일 Decision Log

> 결론만 간단하게 기록. 집에 돌아와 공식 MD에 반영.

## A. Partner Candidate
**A:** Custom Object / **B:** Lead 흡수  
**결정:** ⭐️ TBD  
**이유:**

## B. AI Matching
**A:** Rule-based / **B:** Demo Sample Score  
**결정:** ⭐️ TBD  
**이유:**

## C. Quote
**A:** Standard Quote / **B:** Opportunity 대체  
**결정:** ⭐️ TBD  
**이유:**

## D. Campaign vs Collaboration
**A:** Campaign RecordType / **B:** 별도 구조  
**결정:** ⭐️ TBD  
**이유:**

## E. Lead Score
**A:** Rating / **B:** Lead_Score__c  
**결정:** ⭐️ TBD  
**이유:**

## F. Expected Benefit
**A:** 단기/중기/장기 Field / **B:** Long Text  
**결정:** ⭐️ TBD  
**이유:**

## G. Target Segment
**A:** Picklist / **B:** Text/Report  
**결정:** ⭐️ TBD  
**이유:**

## H. Segment Match
**A:** 수동 입력 / **B:** Flow/Formula  
**결정:** ⭐️ TBD  
**이유:**

## I. Recommendation Reason
**A:** 자동 생성 / **B:** 수동 입력  
**결정:** ⭐️ TBD  
**이유:**

## J. Fan Insight 화면
**A:** Report/Report Type / **B:** LWC  
**결정:** ⭐️ TBD  
**이유:**

## K. Account 집계
**A:** Roll-up/Formula / **B:** Report  
**결정:** ⭐️ TBD  
**이유:**

---

# 7. 모바일 대화 기록

## [날짜 / 주제]

**Question:**  
**Discussion:**  
**Insight:**  
**Decision 후보:**  
**TBD:**

---

# 8. 집에 돌아온 후

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

# Cloud Alpacas — P2 Dummy Data Master

> **이 문서는 실제 레코드 값을 담는 문서다.** `docs/data/DEMO_DATA_STANDARD.md`는 "어떤
> 규칙으로 데이터를 만드는가"만 정의하는 별도 문서이며, 이 문서는 그 규칙을 적용해
> 실제로 Org에 입력할 값을 담는다(`DEMO_DATA_STANDARD.md` 서두 원칙과 동일선상 — 규칙과
> 데이터를 같은 문서에 섞지 않는다).
>
> Naming Rule은 `DEMO_DATA_STANDARD.md` §6.2, Fan 분포 기준은 §6.4를 따른다.
> 기존 Fan(이루키·박서연·김도현·최민재·정하윤)과 이름이 겹치지 않는 새 30명이다.
> 기존 5명 + 이번 30명 = 총 35명 — 이 30명은 **구조/화면/Flow 검증용 소규모 QA
> 데이터**로 유지한다(삭제하지 않음). 최종 Demo 목표 규모(약 1,000명)와 분포 기준은
> `DEMO_DATA_STANDARD.md` §6.4를 따른다 — 이 문서는 그 목표를 향한 1차 소규모
> 데이터일 뿐, 1,000명 데이터 자체는 아직 생성하지 않는다.
>
> ✅ 아래 Object 배치(Lead=Standard Lead 등)는 2026-08-18 Technical Decision
> 회의로 **확정됐다**(`05_DECISIONS.md` Decision 017·018). Campaign(§3.6)은
> Decision D — **Campaign Record Type**으로 확정, Quote(§3.7)도 **Standard
> Quote 사용**으로 확정됐다. 아래 각 섹션에 확정 내용을 반영했다.

---

## 1. Fan(Person Account) 30명

**분포 요약**
- Current Segment(6종) × 5명씩 = 30명
- Engagement Level(6종) × 5명씩 = 30명
- Fan Value Tier: VIP 4명 / 우수 9명 / 일반 17명
- Gender: 남 15 / 여 15 (그중 **10~30대 여성 11명**을 SCN-B2B-001 대표 팬층으로 표시 —
  "팬층의 변화가 뚜렷하게 발견된다"는 Story를 보여주기 위해 기존 8명에서 3명
  확대했다. 모두 가상 Demo 데이터이며 실제 Org 수치가 아니다)
- 연령대: 10대 2 / 20대 9 / 30대 9 / 40대 6 / 50대+ 4

| # | 이름 | Gender__c | 연령대 | Acquisition_Channel__c | Favorite_Player__c | Current_Segment__c | Engagement_Level__c | Fan_Value_Tier__c | SCN-001 대표팬층 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 김서준 | 남 | 30대 | SNS | 문태양 | New Fan | 가입 팬 | 일반 | |
| 2 | 이하은 | 여 | 20대 | SNS | 문태양 | Active Fan | 관심 팬 | 일반 | ✅ |
| 3 | 박지훈 | 남 | 40대 | 검색 | 강도윤 | At-Risk Fan | 활동 팬 | 우수 | |
| 4 | 최유진 | 여 | 20대 | 지인 추천 | 문태양 | Dormant Fan | 충성 팬 | 일반 | ✅ |
| 5 | 정민준 | 남 | 30대 | 오프라인 | 이서준 | Churned Fan | 멤버십 팬 | 일반 | |
| 6 | 강수아 | 여 | 30대 | SNS | 문태양 | Unreachable Fan | 핵심 팬 | VIP | ✅ |
| 7 | 조은우 | 남 | 20대 | 검색 | 박현우 | New Fan | 가입 팬 | 일반 | |
| 8 | 윤지아 | 여 | 10대 | SNS | 문태양 | Active Fan | 관심 팬 | 일반 | ✅ |
| 9 | 장현우 | 남 | 50대+ | 지인 추천 | 강도윤 | At-Risk Fan | 활동 팬 | 일반 | |
| 10 | 임소연 | 여 | 20대 | SNS | 문태양 | Dormant Fan | 충성 팬 | 우수 | ✅ |
| 11 | 한도윤 | 남 | 40대 | 오프라인 | 이서준 | Churned Fan | 멤버십 팬 | 일반 | |
| 12 | 오예린 | 여 | 30대 | SNS | 문태양 | Unreachable Fan | 핵심 팬 | 일반 | ✅ |
| 13 | 서준호 | 남 | 20대 | 검색 | 박현우 | New Fan | 가입 팬 | 우수 | |
| 14 | 신지원 | 여 | 40대 | 지인 추천 | 강도윤 | Active Fan | 관심 팬 | 일반 | |
| 15 | 권태민 | 남 | 30대 | SNS | 문태양 | At-Risk Fan | 활동 팬 | 일반 | |
| 16 | 황서현 | 여 | 10대 | SNS | 문태양 | Dormant Fan | 충성 팬 | 일반 | ✅ |
| 17 | 안준영 | 남 | 50대+ | 오프라인 | 이서준 | Churned Fan | 멤버십 팬 | 우수 | |
| 18 | 송다인 | 여 | 20대 | SNS | 문태양 | Unreachable Fan | 핵심 팬 | VIP | ✅ |
| 19 | 류경민 | 남 | 40대 | 검색 | 박현우 | New Fan | 가입 팬 | 일반 | |
| 20 | 전하율 | 여 | 30대 | 지인 추천 | 문태양 | Active Fan | 관심 팬 | 일반 | ✅ |
| 21 | 배지호 | 남 | 20대 | SNS | 문태양 | At-Risk Fan | 활동 팬 | 일반 | |
| 22 | 홍시은 | 여 | 50대+ | 오프라인 | 이서준 | Dormant Fan | 충성 팬 | 우수 | |
| 23 | 남궁찬 | 남 | 30대 | SNS | 문태양 | Churned Fan | 멤버십 팬 | 일반 | |
| 24 | 문가은 | 여 | 40대 | 검색 | 박현우 | Unreachable Fan | 핵심 팬 | 일반 | |
| 25 | 백승우 | 남 | 20대 | 지인 추천 | 강도윤 | New Fan | 가입 팬 | VIP | |
| 26 | 곽나연 | 여 | 20대 | SNS | 문태양 | Active Fan | 관심 팬 | 우수 | ✅ |
| 27 | 심유찬 | 남 | 30대 | SNS | 문태양 | At-Risk Fan | 활동 팬 | 일반 | |
| 28 | 노아름 | 여 | 30대 | 오프라인 | 문태양 | Dormant Fan | 충성 팬 | 우수 | ✅ |
| 29 | 표재원 | 남 | 50대+ | 검색 | 박현우 | Churned Fan | 멤버십 팬 | 일반 | |
| 30 | 길민서 | 여 | 20대 | SNS | 문태양 | Unreachable Fan | 핵심 팬 | VIP | |

---

## 2. SCN-B2B-001 Fan Insight — 계산 기준 (Cross-Object Consistency)

> `DEMO_DATA_STANDARD.md`가 요구하는 "Fan Activity Pattern 집계값은 원본 Order/Admission과
> 일치해야 한다"는 원칙을 Fan Insight 숫자에도 그대로 적용한다. 아래 배정을 그대로
> Order/`Engagement_Signal__c`에 입력해야 Workbook §2의 수치가 Report에서 실제로 재현된다.

### 2.1 대표 팬 11명의 두 하위 그룹 — 가입일(`CreatedDate`) 기준

> 팬층 변화를 더 뚜렷하게 보여주기 위해, 기존 8명 대표팬층에 **전하율, 곽나연,
> 노아름 3명을 추가**해 11명으로 확대했다(§1 표에 ✅ 반영). 이 3명은 "최근 3개월
> 이내 가입"으로 재지정한다 — 원래 최근 가입자로 지정했던 비대표 남성 3명
> (김서준, 조은우, 서준호)은 최근 가입 지정에서 제외해, **최근 3개월 신규 가입자
> 총원(8명)은 그대로 유지**한다(before 시점 전체 인원이 흔들리지 않도록).

| 하위그룹 | 대상 | 가입일 |
|---|---|---|
| 기존 그룹 (3개월 이전 가입) | 이하은, 최유진, 강수아, 윤지아 | 2026-02 ~ 2026-04 |
| 신규 그룹 (최근 3개월 이내 가입) | 임소연, 오예린, 황서현, 송다인, **전하율, 곽나연, 노아름** | 2026-06 ~ 2026-08 |

비대표 19명 중 **류경민**만 최근 3개월 이내 가입으로 지정한다(성별·연령대는 대표군 아님) —
최근 가입자 총원은 대표 7명 + 비대표 1명 = 8명으로 기존과 동일하다.

**→ 10~30대 여성 비중 18% → 약 37%(목표 "35% 정도" 이상 달성) 계산**
- 3개월 전 시점 전체 인원 = 22명(현재 30명 − 최근 3개월 신규 8명), 그중 여성 10~30대 = 4명(기존 그룹, 변화 없음) → **4/22 = 18.2%("18%")**
- 현재 시점 전체 인원 = 30명, 그중 여성 10~30대 = 11명(기존 4 + 신규 7) → **11/30 = 36.7%(약 37%)**
- 기존 "18%→27%"보다 변화 폭을 더 크게(약 1.9배 → 약 2배) 조정해, "팬층의 변화가
  뚜렷하게 발견된다"는 Story를 더 명확히 뒷받침한다. **모두 가상 Demo 데이터이며
  실제 Org 집계 결과가 아니다.**

### 2.2 굿즈 구매 전환율 — 대표팬층 확대에 맞춰 재조정 (목표: 약 25%)

대표팬층이 8명→11명으로 늘어난 만큼, 기존 구매자 수(3명)를 그대로 유지하면 자연스럽게
전환율이 낮아진다 — "팬 수는 늘었지만 구매력은 낮다"는 Story와 정확히 맞아떨어진다.

| 대상 | 문태양 관련 굿즈 Order 배정 |
|---|---|
| 이하은, 최유진, 강수아 (3명, 변화 없음) | Goods Purchase Order 1건 이상, Product2 = 문태양 유니폼(홈) 또는 문태양 관련 굿즈 |
| 나머지 대표팬 8명(신규 3명 포함) | 굿즈 Order 없음 (SNS 반응만 있는 "관심 단계" 팬으로 남겨둠) |

→ 대표팬 굿즈 전환율 = 3/11 = **27.3% (약 25%, 목표 근접)** — 기존 37.5%(약 38%)보다
확연히 낮아져 "팬은 늘었지만 구매 전환은 오히려 둔화됐다"는 문제를 보여준다.

전체 평균 15% 수준은 유지한다 — 비대표 19명 중 1~2명에게만 추가로 배정한다.

| 대상 | 배정 |
|---|---|
| 비대표 19명 중 1~2명 | 문태양 관련 굿즈 Order 1건 이상 |

→ 전체 구매자 = 3(대표) + 1~2(비대표) = 4~5명 / 30명 = **13.3~16.7%(약 15%, 변화 없음)**
→ 대표팬 25%대 ÷ 전체 15% = **약 1.8배** — 이전(2.5배)보다 격차는 줄었지만, "구매력이
낮아졌다"는 문제 자체는 절대 수치(27.3%)로 더 뚜렷하게 드러난다.
→ 위 수치는 모두 가상 Demo 데이터이며 실제 Org 집계 결과가 아니다.

### 2.3 SNS 반응률 "2배 이상" — 정확히 2배로 설계

| 대상 | `Engagement_Signal__c` 건수 |
|---|---|
| 대표팬 11명(신규 3명 포함) | 각 2건씩 (Signal_Type__c = SNS Click, Source__c = Instagram, Player__c = 문태양) |
| 비대표팬 19명 | 각 1건씩 |

→ 대표팬 평균 2건 : 비대표팬 평균 1건 = **정확히 2배**

> ⚠️ **구현 상태 명확화**: 이 `Engagement_Signal__c` 레코드는 실제 SNS(Instagram
> 등) API에서 실시간으로 가져온 데이터가 아니라 **Demo용으로 직접 입력하는 Dummy
> Data**다. "Data Cloud 등 외부 소스에서 실제 SNS 반응을 실시간으로 가져온다"는
> 기능은 현재 구현되어 있지 않다 — 미구현 상태이며, 실제 연동 여부는 별도
> Technical TBD로 남긴다(`03_SYSTEM.md` §5 Future Scope, CLAUDE.md §5). 지금
> Demo에서는 "SNS 반응이 있었다"는 사실을 `Engagement_Signal__c`의 Dummy Data로만
> **표현**할 뿐, 실제 SNS 데이터를 가져오는 파이프라인이 있는 것처럼 서술하지 않는다.

---

## 3. Master Data — SCN-B2B-001: Hello Kitty Collaboration

> ⚠️ "산리오/Hello Kitty"는 Demo 예시다. 실제 브랜드명 사용 여부는 팀 결정 사항이며
> (`DEMO_DATA_STANDARD.md` §6.2), 아래는 그 결정 전까지 쓸 수 있는 임시 데이터다.
> 모든 레코드 Description에 `[SCN-B2B-001]`을 포함해 하나의 Scenario로 연결한다.

### 3.1 Lead

| Field | 값 |
|---|---|
| Company | 산리오코리아 |
| Last Name | 김하나 |
| Title | Licensing Manager |
| Lead Source | FRM 발굴 (Fan Insight 기반) |
| Status | Qualified |
| Description | [SCN-B2B-001] 10~30대 여성 팬층 × 문태양 관련 굿즈 구매율/SNS 반응률 Fit 가설로 발굴한 후보 |

### 3.2 Account (Lead Convert 후)

| Field | 값 |
|---|---|
| Account Name | 산리오코리아 |
| Record Type | Partner |
| Industry | Character IP / Licensing |
| Description | [SCN-B2B-001] |

### 3.3 Contact

| Field | 값 |
|---|---|
| Name | 김하나 |
| Title | Licensing Manager |
| Account | 산리오코리아 |
| Description | [SCN-B2B-001] |

### 3.4 Opportunity

| Field | 값 |
|---|---|
| Opportunity Name | 산리오코리아 × Cloud Alpacas — Hello Kitty Collaboration 2027 |
| Account | 산리오코리아 |
| Stage | Proposal/Price Quote |
| Amount | 50,000,000원 |
| Close Date | 2027-03-01 |
| Description | [SCN-B2B-001] |

### 3.5 Product2 — Sponsorship Package

| Field | 값 |
|---|---|
| Product Name | Hello Kitty 콜라보 굿즈 세트 |
| Record Type | Sponsorship Package |
| Product Code | SPN-2027-HK01 |
| Description | [SCN-B2B-001] |

Opportunity(3.4)에 Product Line Item으로 연결한다.

### 3.6 Campaign — Collaboration ✅ 확정 (Campaign Record Type)

> **확정 (2026-08-18)**: `P2_TECHNICAL_DECISION_SHEET.md` D안은 Draft 시점에
> Option B(단순 관계/필드)를 권장했지만, 실제 회의 결정은 **Option A — Campaign
> Record Type**이다(`05_DECISIONS.md` Decision 018-D). Campaign 자체에
> RecordType(Collaboration)을 부여하고, Opportunity와의 연결은 별도로 표준
> `Primary Campaign Source`(Opportunity 필드)를 그대로 사용한다 — 두 방식은
> 서로 배타적이지 않다(RecordType=Campaign의 분류, Primary Campaign Source=
> Opportunity와의 연결).

| Field | 값 |
|---|---|
| Campaign Name | Hello Kitty Collaboration Campaign |
| Record Type | Collaboration(B2B) — 정확한 RecordType 이름은 Org 반영 시 확정 |
| 연결 방식 | Opportunity.`Primary Campaign Source` = 이 Campaign |
| Description | [SCN-B2B-001] |

**Campaign Member로 등록할 대상** — 대표 팬층 8명(이하은, 최유진, 강수아, 윤지아, 임소연, 오예린, 황서현, 송다인)을 Campaign Member로 추가한다.

### 3.7 Quote

| Field | 값 |
|---|---|
| Quote Name | Hello Kitty Collaboration 2027 Quote |
| Opportunity | 산리오코리아 × Cloud Alpacas — Hello Kitty Collaboration 2027 (3.4) |
| Status | Draft |
| Expiration Date | 2027-02-01 |
| Description | [SCN-B2B-001] |

**QuoteLineItem**

| Field | 값 |
|---|---|
| Product | Hello Kitty 콜라보 굿즈 세트 (3.5, Opportunity Line Item과 동일 Product2 재사용) |
| Quantity | 1 |
| Unit Price | 50,000,000원 |

---

## 4. 이어지는 흐름 (Demo 검증용)

```
Fan Insight(위 8명 Report 집계 — §2 계산 기준대로 입력하면 재현됨)
  → Business Fit 가설(SCN-B2B-001)
  → Lead(산리오코리아, 김하나)
  → Account/Contact 전환
  → Opportunity(Hello Kitty Collaboration 2027)
  → Product(Hello Kitty 콜라보 굿즈 세트) + Quote(Hello Kitty Collaboration 2027 Quote)
  → Campaign(Primary Campaign Source로 연결, Member = 대표 팬층 8명)
  → Performance(Campaign Member 반응률 Report)
  → Partnership/Sponsorship 판단
```

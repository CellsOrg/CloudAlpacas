# Cloud Alpacas — P2 Dummy Data Master

> **이 문서는 실제 레코드 값을 담는 문서다.** `docs/data/DEMO_DATA_STANDARD.md`는 "어떤
> 규칙으로 데이터를 만드는가"만 정의하는 별도 문서이며, 이 문서는 그 규칙을 적용해
> 실제로 Org에 입력할 값을 담는다(`DEMO_DATA_STANDARD.md` 서두 원칙과 동일선상 — 규칙과
> 데이터를 같은 문서에 섞지 않는다).
>
> Naming Rule은 `DEMO_DATA_STANDARD.md` §6.2, Fan 분포 기준은 §6.4를 따른다.
> 기존 Fan(이루키·박서연·김도현·최민재·정하윤)과 이름이 겹치지 않는 새 30명이다.
> 기존 5명 + 이번 30명 = 총 35명 → "30~50명 권장 규모" 충족.
>
> ⚠️ 아래 Object 배치(Lead=Standard Lead 등)는 `P2_TECHNICAL_DECISION_SHEET.md`의
> A~K 항목이 화요일 회의에서 확정되기 전까지는 **잠정안**이다. Campaign(§3.6)은
> Decision Sheet D안과 충돌이 확인되어 TBD로 되돌렸다. **Quote(§3.7)는 Wireframe
> Object Map에 명시되어 있어 사용을 확정**했다(`P2_WEEKEND_PM_WORKBOOK.md` §3-④).

---

## 1. Fan(Person Account) 30명

**분포 요약**
- Current Segment(6종) × 5명씩 = 30명
- Engagement Level(6종) × 5명씩 = 30명
- Fan Value Tier: VIP 4명 / 우수 9명 / 일반 17명
- Gender: 남 15 / 여 15 (그중 **10~30대 여성 8명**을 SCN-B2B-001 대표 팬층으로 표시)
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
| 20 | 전하율 | 여 | 30대 | 지인 추천 | 강도윤 | Active Fan | 관심 팬 | 일반 | |
| 21 | 배지호 | 남 | 20대 | SNS | 문태양 | At-Risk Fan | 활동 팬 | 일반 | |
| 22 | 홍시은 | 여 | 50대+ | 오프라인 | 이서준 | Dormant Fan | 충성 팬 | 우수 | |
| 23 | 남궁찬 | 남 | 30대 | SNS | 문태양 | Churned Fan | 멤버십 팬 | 일반 | |
| 24 | 문가은 | 여 | 40대 | 검색 | 박현우 | Unreachable Fan | 핵심 팬 | 일반 | |
| 25 | 백승우 | 남 | 20대 | 지인 추천 | 강도윤 | New Fan | 가입 팬 | VIP | |
| 26 | 곽나연 | 여 | 20대 | SNS | 문태양 | Active Fan | 관심 팬 | 우수 | |
| 27 | 심유찬 | 남 | 30대 | SNS | 문태양 | At-Risk Fan | 활동 팬 | 일반 | |
| 28 | 노아름 | 여 | 30대 | 오프라인 | 이서준 | Dormant Fan | 충성 팬 | 우수 | |
| 29 | 표재원 | 남 | 50대+ | 검색 | 박현우 | Churned Fan | 멤버십 팬 | 일반 | |
| 30 | 길민서 | 여 | 20대 | SNS | 문태양 | Unreachable Fan | 핵심 팬 | VIP | |

---

## 2. SCN-B2B-001 Fan Insight — 계산 기준 (Cross-Object Consistency)

> `DEMO_DATA_STANDARD.md`가 요구하는 "Fan Activity Pattern 집계값은 원본 Order/Admission과
> 일치해야 한다"는 원칙을 Fan Insight 숫자에도 그대로 적용한다. 아래 배정을 그대로
> Order/`Engagement_Signal__c`에 입력해야 Workbook §2의 수치가 Report에서 실제로 재현된다.

### 2.1 대표 팬 8명의 두 하위 그룹 — 가입일(`CreatedDate`) 기준

| 하위그룹 | 대상 | 가입일 |
|---|---|---|
| 기존 그룹 (3개월 이전 가입) | 이하은, 최유진, 강수아, 윤지아 | 2026-02 ~ 2026-04 |
| 신규 그룹 (최근 3개월 이내 가입) | 임소연, 오예린, 황서현, 송다인 | 2026-06 ~ 2026-08 |

비대표 30명 중 **김서준, 조은우, 서준호, 류경민**도 최근 3개월 이내 가입으로 지정한다(성별·연령대는 대표군 아님).

**→ 10~30대 여성 비중 18%→27% 계산**
- 3개월 전 시점 전체 인원 = 22명(현재 30명 − 최근 3개월 신규 8명), 그중 여성 10~30대 = 4명(기존 그룹) → **4/22 = 18.2%**
- 현재 시점 전체 인원 = 30명, 그중 여성 10~30대 = 8명 → **8/30 = 26.7%**
- Workbook §2 표기 "18%→27%"와 정확히 일치.

### 2.2 굿즈 구매 전환율 — 목표 수치 조정 (42% → 약 38%)

8명이라는 정수 인원으로는 42%를 정확히 재현할 수 없다(3명=37.5%, 4명=50%). 정확하지 않은 숫자를 그대로 쓰기보다, **Workbook §2의 목표 수치를 "약 38%"로 낮춰서 데이터와 발표 내용을 일치**시킨다.

| 대상 | 문태양 관련 굿즈 Order 배정 |
|---|---|
| 이하은, 최유진, 강수아 (3명) | Goods Purchase Order 1건 이상, Product2 = 문태양 유니폼(홈) 또는 문태양 관련 굿즈 |
| 나머지 대표팬 5명 | 굿즈 Order 없음 (SNS 반응만 있는 "관심 단계" 팬으로 남겨둠) |

→ 대표팬 굿즈 전환율 = 3/8 = **37.5% (약 38%)**

전체 평균을 15%로 맞추려면 **전체 30명 기준**으로 계산해야 한다 — 이미 대표팬 3명이 구매자이므로, 비대표 22명 중 **1~2명에게만** 추가로 배정한다.

| 대상 | 배정 |
|---|---|
| 비대표 22명 중 1~2명 | 문태양 관련 굿즈 Order 1건 이상 |

→ 전체 구매자 = 3(대표) + 1~2(비대표) = 4~5명 / 30명 = **13.3~16.7%(약 15%)**
→ 대표팬 38% ÷ 전체 15% = **약 2.5배** (Workbook §2와 일치)

### 2.3 SNS 반응률 "2배 이상" — 정확히 2배로 설계

| 대상 | `Engagement_Signal__c` 건수 |
|---|---|
| 대표팬 8명 | 각 2건씩 (Signal_Type__c = SNS Click, Source__c = Instagram, Player__c = 문태양) |
| 비대표팬 22명 | 각 1건씩 |

→ 대표팬 평균 2건 : 비대표팬 평균 1건 = **정확히 2배**

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

### 3.6 Campaign — Collaboration ⭐️ TBD (RecordType 아님, 관계/필드 방식으로 잠정 구현)

> **정정**: 이전 초안에서 "Campaign RecordType 권장"이라고 안내했는데,
> `P2_TECHNICAL_DECISION_SHEET.md` D안의 팀 권장은 **B(단순 관계/필드)**였다.
> 확정 전까지는 표준 Campaign을 그대로 쓰고, Opportunity와의 연결은 RecordType이
> 아니라 **표준 `Primary Campaign Source`(Opportunity 필드)**로 잠정 처리한다.

| Field | 값 |
|---|---|
| Campaign Name | Hello Kitty Collaboration Campaign |
| Type | Other *(RecordType 미사용 — TBD)* |
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

# Opportunity Demo Data — Implementation + Validation Report

- 작성: 2026-08-29 (KST)
- 실행 org: `dohrphin@gmail.com.alpaca` (alias `prod`)
- 브랜치/워크트리: `feature/opportunity-demo-data` @ `ca-dev-lwc-demo-data` (신규 브랜치 생성 없음)
- 유형: **승인된 범위 내 business data mutation 실행 + 회귀 검증**. 코드/메타데이터/Agent publish 변경 없음.
- 상태: mutation은 org에 반영 완료. PR #90(Opportunity Stage UI)까지 merge된 시점에서 이 문서의 최종 데모 매트릭스(§15)가 **org current state와 일치함을 재확인**(2026-09 재검증). d'Alba 골드는 UI 테스트 중 임시로 Discovery로 바뀌었다가 PR #90 작업에서 Negotiation으로 재복원됨.

> **이 PR 범위**: 이 구현 보고서 1개만 main에 남긴다. 설계 단계 문서(`Opportunity_Demo_Data_Plan.md` — DESIGN ONLY, 당시 미결이던 4개 결정이 모두 확정되어 obsolete)와 일회성 롤백 아티팩트(`demo_data_snapshot_before/`, `demo_data_snapshot_after/` + `rollback.apex`)는 제외했다. 아래 본문에 남은 스냅샷·커밋 참조는 구현 당시 이력이며, 이 브랜치의 이전 커밋 히스토리에서 확인할 수 있다.

---

## 1. Executive Summary

승인된 6개 결정에 따라 데모 Opportunity 데이터를 **stage별로 일관되게** 정비했다.

| Opp | before | after | 한 줄 요약 |
|---|---|---|---|
| d'Alba 골드 (`006bm00000VXKvlAAH`) | Discovery / 데이터 빈약 / Quote In Review | **Negotiation** / rich / Quote **Presented** | 협상 단계 rich 데모. Partner_Tier=Gold, Needs/KPI/요구사항/Deal_Note 채움. **CloseDate 2026-09-05 유지**(마감 임박). |
| 삼성카드 (`006bm00000VjTP7AAN`) | `Proposal`(비활성 stage) / OLI·sync 없음 / Quote Draft | **Proposal/Quote** / OLI 1 + Quote sync + **Presented** | 제안/견적 단계 데모. Amount 402.5M→**744M**(rollup), Discovery/Qual 필드 채움. Expected_Benefit 3개 보존. |
| d'Alba 다이아몬드 (`006bm00000VonmrAAB`) | Qualification / 거의 빈 값 | **Qualification 유지** / 의도적 sparse | "정보 부족" 데모. Contact + 완료 Call 1건 + Interest/Fit만. **Needs/KPI/요구사항/예산 null 유지, Budget_Status Unknown 유지, Quote·Expected_Benefit 보존.** |
| Discovery (`006bm00000VjUD5AAN`, 우아한형제들) | 기존 clean Opp (활동 0) | **Discovery** / 필드 채움 + 활동 2건 | 신규 Opp 생성 대신 기존 clean Opp 재사용(Decision 3). Needs/KPI/요구사항/Segment/예산 + 완료 Meeting 1 + 예정 Task 1. |

**회귀 결과: Apex 88/88 PASS (0 fail), 골드 QA fixture(II 2건·Signal 6건) 100% 보존, Agent read-only action 4개 Opp 모두 정상 resolve.**

**Verdict: A (demo data implementation complete, regression green).**
> 최초 판정은 B였고, 유일한 blocker(골드 `Last_Contact_Date__c` 미래값)는 **2026-08-29 사용자 승인 후 1회 직접 override로 해결**(2026-09-03 → 2026-08-28, `Days_Since_Last_Contact__c` -4 → 1). §19-1 참조. → **A로 상향.**
- 완료: 6개 결정 전부 적용, PHASE 0–7 전부 통과, 회귀 green, 골드 Last Contact 이상 해결.
- 남은 것(블로커 아님, 설계상 정상): (b) 삼성·Discovery **Interaction Intelligence 미생성** — production LLM Flow(`CA_Generate_Meeting_Interaction_Intelligence`)는 `Meeting_Type__c='Offline'` Event만 처리 → 강제 생성 안 함, 라이브 데모에서 생성(§11). (c) 골드 Negotiation 진입 시 **org 전용 Flow `Negotiation_Followup_Flow`가 Task 1건 자동생성** — 정상 동작이나 repo에 없는 drift(§9, §19-2).

---

## 2. Git / Worktree 상태

```
worktree : ca-dev-lwc-demo-data
branch   : feature/opportunity-demo-data  (PR #88)
```

- 신규 브랜치 **생성 안 함** (지시대로 기존 워크트리/브랜치 사용).
- 다른 워크트리(#86 `feature/opportunity-proposal-integration`, #87 `feature/opportunity-deal-assistant`, `feature/opportunity-stage-ui-audit`, 그 외) **손대지 않음**.
- main에 남기는 파일: `P2_RESULT_REPORT/Opportunity_Demo_Data_Implementation_Report.md` (이 문서) 1개. 설계 문서·스냅샷·`rollback.apex`는 제외(상단 노트 참조).
- **코드/Apex/LWC/Flow/field/FlexiPage/permission set/.agent 파일 변경 0건.**

---

## 3. Pre-Mutation Snapshot (별도 보관, main 미포함)

DML 실행 **전** 15개 파일(`demo_data_snapshot_before/`)로 롤백 기준점을 확보했다. main에는 남기지 않는다. 핵심:

- Opp 3개(골드/삼성/다이아) 전체 필드, 관련 Account 2·Contact 2·Task 6·Event 3·II 2·Signal 6·Quote 3·QLI 3·OLI 1·OLI Schedule 3·PBE 2.
- 골드 context baseline (`gold_context_baseline.txt`): `NC hasQuote=true, quote 0Q0bm000003BT3NCAW "In Review", QLI 0QLbm000003lDWNGA2, quoteDiscount=null, maxDiscountPercent=6.00, lineItemDiscountUpdatable=false` / `DC stage=Discovery, daysUntilClose=7, quoteCount=1, syncedQuoteStatus="In Review", interactionCount=2, signalCount=6, negativeSignalCount=2, riskCategoryCount=1, openTaskCount=2, overdueTaskCount=0`.
- Apex regression baseline: **88/88 PASS**.

---

## 4. 승인된 6개 결정 — 적용 결과

| # | 결정 | 적용 결과 |
|---|---|---|
| **1** | 삼성카드 → Proposal/Quote 데모. 비활성 `Proposal` → 활성 `Proposal/Quote`. Negotiation으로 올리지 **않음**. | ✅ StageName `Proposal` → `Proposal/Quote` (Prob 75, Forecast Best Case). Negotiation 미승격. |
| **2** | 다이아몬드 기존 Quote + `Expected_Benefit_*` 값 삭제/덮어쓰기 **금지**(승우님 확인 전까지 보존). 다이아 = Qualification/sparse 데모. | ✅ Quote `0Q0bm000003F6rNCAS` 그대로, `Expected_Benefit_Short/Mid/Long_Term__c` 3개 그대로. Stage Qualification 유지. Needs/KPI/요구사항/Client_Budget **null 유지**, Budget_Status **Unknown 유지**. |
| **3** | 필요 시 소형 Discovery Opp **1개** 신규. Closed Won/Lost 생성 **금지**(기존 이력 레코드는 read-only). | ✅ 신규 생성 대신 **기존 clean Discovery Opp `006bm00000VjUD5AAN`(우아한형제들) 재사용** (활동 0건이었음). Closed Won/Lost 생성·수정 0건. |
| **4** | RecordType / Sales_Path / Path 메타데이터 **수정 금지**(별도 UI 태스크). | ✅ RecordType/Path/FlexiPage/Stage 정의 메타데이터 **미변경**. Stage picklist 값 변경(`Proposal`→`Proposal/Quote`)은 레코드 필드값 수정이지 메타데이터 변경 아님. |
| **5** | d'Alba 골드 synced Quote Status → `Presented`. Quote Id / QLI / OLI / Revenue Schedule / SyncedQuoteId 유지. Discount / PricebookEntry 변경 **없음**. | ✅ Quote `0Q0bm000003BT3NCAW` Status `In Review` → `Presented` (Status 필드만). QLI `0QLbm000003lDWNGA2`·OLI `00kbm00000k0x5fAAA`·revenue schedule 3건·SyncedQuoteId·Discount(null)·PBE 전부 불변. |
| **6** | 골드 CloseDate = 2026-09-05 유지 (마감 임박 Negotiation / Deal Intelligence 데모). | ✅ CloseDate `2026-09-05` 그대로. `DealContext.daysUntilClose = 7` (오늘 08-29 기준). |

---

## 5. 골드 (`006bm00000VXKvlAAH`) Mutation 결과

### 5.1 적용된 변경 (PHASE 1–2)

| 필드 | before | after |
|---|---|---|
| `StageName` | Discovery | **Negotiation** |
| `Probability` | 35 | **90** (stage 기본값 자동) |
| `ForecastCategoryName` | Best Case | **Commit** (자동) |
| `LastStageChangeDate` | (이전) | **2026-08-29T07:12:21Z** (자동) |
| `Partner_Tier__c` | null | **Gold** |
| `Customer_Needs__c` | null | 채움 (20-30대 여성 팬 대상 뷰티 브랜드 인지도 + Brand Day) |
| `Customer_KPI__c` | null | 채움 (인지도 15%p↑, SNS 언급 2배, Brand Day 1만명) |
| `Key_Requirements__c` | null | 채움 (전광판 필수, Brand Day 1회, 분기 리포트) |
| `Deal_Note__c` | null | 채움 (제안서 재전달 완료, 예산 승인 대기, 경쟁 없음) |
| `NextStep` | 콜라보레이션 패키지 견적서 구성 및 발송 | 고객사 예산 승인 결과 확인 후 최종 조건 합의 및 계약서 준비 |
| `Quote 0Q0bm000003BT3NCAW.Status` | In Review | **Presented** |

### 5.2 변경하지 않은 것 (의도적)

- `CloseDate` = **2026-09-05 유지** (Decision 6).
- `Amount` = 300,000,000 유지.
- `Last_Contact_Date__c` = 최초 2026-09-03T00:00:00(미래, backing activity 없음) → **2026-08-29 승인 후 2026-08-28T00:00:00Z로 1회 직접 override** (`Days_Since_Last_Contact__c` -4 → 1). §19-1 참조.
- II 2건 / Signal 6건 텍스트·개수·CreatedDate **불변** (Decision 5 취지 + §12).
- QLI / OLI / OLI Revenue Schedule 3건 / SyncedQuoteId / Quote Discount / PBE **불변**.

### 5.3 Flow 파생 부수효과

골드가 `Negotiation` 진입 시 **org 전용 Active Flow `Negotiation_Followup_Flow`** (repo에 없음)가 발화하여 Task **`00Tbm00000FqxJVEAZ`** ("협상 후속 연락", Not Started, 마감 2026-08-30, Owner = Opp Owner=Manager Lee)를 자동 생성. 설계된 정상 동작. 결과로 골드 미완료 "협상 후속 연락" Task가 3건(08-28·08-29·08-30)이 됨 → `Open_Tasks_Count__c` 2→3, `Overdue_Tasks_Count__c` 0→1, `Next_Activity_*` 재계산. 데모상 "마감 임박·활동 활발" 서사와 부합하나, 동일 제목 Task 반복은 P2 polish 여지(§19-2).

---

## 6. 삼성카드 (`006bm00000VjTP7AAN`) Mutation 결과

### 6.1 적용된 변경 (PHASE 3–5)

| 필드 | before | after |
|---|---|---|
| `StageName` | `Proposal` (비활성) | **`Proposal/Quote`** |
| `Probability` | 75 | 75 (동일) |
| `ForecastCategoryName` | — | **Best Case** |
| `Amount` | 402,500,000 | **744,000,000** (synced Quote OLI에서 rollup) |
| `Target_Segment__c` | null | **`40-60 Male`** (repo Picklist 허용값) |
| `Client_Budget_Status__c` | Estimated | **Confirmed** (plan S8) |
| `Customer_Needs__c` / `Customer_KPI__c` / `Key_Requirements__c` | null | 채움 (유니폼 소매 광고, 40-60대 남성 결제고객, TV 중계 노출) |
| `Sponsorship_Interest_Level__c` | null | **`높음`** (org 활성 3값 중) |
| `Brand_Fan_Fit__c` | null | `보통` |
| `Decision_Maker_Accessible__c` | null | `가능` |
| `Expected_Timing__c` | null | `1~3개월 내` |
| `Target_Start_Season__c` | null | 2026 |
| `Deal_Note__c` | null | 채움 (1차 통화 할인 요청 7%, 2차 재협의, 표준가 8억) |
| `Pricebook2Id` | null | `01sbm00000I1DJVAA3` (Quote sync 위해 설정) |
| `SyncedQuoteId` | null | **`0Q0bm000003FG2jCAG`** |
| `Quote 0Q0bm000003FG2jCAG.Status` | Draft | **Presented** |
| OLI | 없음 | **1건 신규** `00kbm00000kH8ZlAAK` (Quote sync 자동생성) |

### 6.2 변경하지 않은 것

- `CloseDate` = 2026-10-11 유지.
- `Expected_Benefit_Short/Mid/Long_Term__c` **3개 전부 보존** (Decision 2 — 승우님 작성분).
- QLI `0QLbm000003qeqrGAA` (unit 800M, disc 7, total 744M, HasRevenueSchedule=false) 불변.
- Quote GrandTotal 744M / Discount 7 불변.

### 6.3 Quote Sync 검증

- `Pricebook2Id` 설정 → `SyncedQuoteId` 설정 순서로 실행. Salesforce가 QLI에서 OLI를 **자동 생성**: `유니폼 소매 패치 광고` qty 1, **UnitPrice 800M / TotalPrice 744M / ListPrice 800M** — 이 org의 OpportunityLineItem에는 Discount 필드가 없어(§19-4 drift) **7% 할인이 "정가 800M vs 총액 744M" 차이로 보존됨**. `HasRevenueSchedule=false` (삼성 QLI에는 revenue schedule 없음).
- Opp `Amount` 744M로 rollup, `HasOpportunityLineItem=true`.
- `NegotiationContext` (삼성): `hasQuote=true, status=Presented, lineItemDiscountUpdatable=true, maxDiscountPercent=7.00` — 삼성 QLI는 revenue schedule이 없어 할인 조정 가능(골드와 대비되는 정상 상태).

---

## 7. 다이아몬드 (`006bm00000VonmrAAB`) Mutation 결과

### 7.1 적용된 변경 (PHASE 6) — 최소·의도적 sparse

| 필드 | before | after |
|---|---|---|
| `SDO_Sales_Primary_Contact__c` | null | **`003bm00001jQU4rAAG`** (김하나, d'Alba Contact 재사용) |
| `Sponsorship_Interest_Level__c` | null | **`보통`** (§7 지정) |
| `Brand_Fan_Fit__c` | null | **`높음`** (§7 지정) |
| `Decision_Maker_Accessible__c` | null | `부분 가능 (실무자 경유)` |
| `Expected_Timing__c` | null | `3~6개월 내` |
| `Target_Start_Season__c` | null | 2028 |
| `Target_Segment__c` | null | `10-30 Female` (repo Picklist 허용값) |
| 완료 Call Task | 없음 | **1건 신규** `00Tbm00000FqxkvEAB` ("다이아몬드 다년 업셀 초기 논의 통화", Completed, TaskSubtype=Call, 2026-08-27, WhoId=김하나) |

### 7.2 의도적으로 **null / Unknown 유지** (Decision 2, §7)

- `Customer_Needs__c` = null · `Customer_KPI__c` = null · `Key_Requirements__c` = null
- `Client_Budget__c` = null · `Client_Budget_Status__c` = **Unknown**
- `Partner_Tier__c` = `Platinum` 유지 · Quote `0Q0bm000003F6rNCAS` 유지 · `Expected_Benefit_*` 3개 유지
- Stage `Qualification` 유지 · `CloseDate` 2027-02-28 유지 · `Amount` 1.5B 유지

→ "Qualification 단계 = 정보 미확인" 데모에 적합. `stageProgress` 체크리스트가 의도적으로 미완성 상태로 보임.

### 7.3 Flow 검증

완료 Call Task 1건 insert → `CA_Update_Opportunity_Last_Contact_From_Call` 발화: `Last_Contact_Date__c` = 2026-08-27, `Last_Contact_Type__c` = `Call`, `Days_Since_Last_Contact__c` = 2 (formula, 오늘 기준 — **실제 값**), `LastActivityDate` = 2026-08-27. `Open_Tasks_Count__c` = 0 (완료 Task라서).

---

## 8. Discovery 데모 결과 (`006bm00000VjUD5AAN`)

### 8.1 접근

Decision 3 / §8 = "기존 재사용 가능 Opp 먼저 확인 → 없으면 소형 신규 생성". **기존 clean Opp `006bm00000VjUD5AAN` "우아한형제들(배달의민족) - 2026 시즌 파트너십"** (Owner=Manager Lee, CreatedBy=Aaron Choi, Stage=Discovery, Task/Event/Quote 0건)을 **재사용**. 신규 Opp·Closed 레코드 생성 0건.

### 8.2 적용된 변경 (PHASE 7)

| 필드 | after |
|---|---|
| `StageName` | Discovery 유지 (Prob 35, Best Case) |
| `Customer_Needs__c` / `Customer_KPI__c` / `Key_Requirements__c` | 채움 (배달앱 20-30대 남성 대상 라이브 중계 연계 노출 + 앱 프로모션 트래픽) |
| `Target_Segment__c` | `10-30 Male` |
| `Client_Budget__c` / `Client_Budget_Status__c` | 400,000,000 / `Estimated` |
| `Target_Start_Season__c` / `Expected_Timing__c` | 2026 / `1~3개월 내` |
| `Sponsorship_Interest_Level__c` / `Brand_Fan_Fit__c` / `Decision_Maker_Accessible__c` | `높음` / `높음` / `가능` |
| `SDO_Sales_Primary_Contact__c` | `003bm00001kWSfnAAG` (서서연) |
| `NextStep` / `Deal_Note__c` | 채움 |
| 완료 Meeting Event | **1건 신규** `00Ubm000006vZyTEAU` ("우아한형제들 니즈 파악 미팅", Meeting_Type__c=`Online`, Key_Discussion 채움, WhoId=서서연, 2026-08-27 10:00–11:00) |
| 예정 Task | **1건 신규** `00Tbm00000Fqxo9EAB` ("제안서 초안 작성", Not Started, High, 2026-09-03) |

### 8.3 참고

- `Amount` = 409,000,000 (재사용 Opp에 원래 있던 값, 미변경). `Client_Budget__c` 400M과 약 2% 차이 — "고객 제시 예산 4억, 우리 딜 가치 4.09억"로 해석되는 수용 가능한 변동(plan §6.x 일관성 원칙과 동일).
- Event `Meeting_Type__c='Online'` → `CA_Update_Opportunity_Last_Contact_From_Meeting` 발화: `Last_Contact_Date__c`=2026-08-27T02:00Z, `Last_Contact_Type__c`=`Online Meeting`.

---

## 9. Flow 파생 필드 검증 (§12)

**원칙 준수**: 파생 필드(`Last_Contact_*`, `Next_Activity_*`, `Open/Overdue Count`, `Probability`, `Forecast`, `LastStageChangeDate`, `LastActivityDate`)를 **직접 UPDATE하지 않았다.** source Activity/Stage를 바꾸고 Flow가 계산하게 한 뒤 재조회로 확인.

| Opp | 트리거한 source 변경 | 발화한 Flow | 파생 결과 |
|---|---|---|---|
| 골드 | StageName → Negotiation | `Negotiation_Followup_Flow` (org-only) + `CA_Update_Opportunity_Next_Activity` | Task `00Tbm00000FqxJVEAZ` 자동생성 · Open 2→3 · Overdue 0→1 · Next_Activity 2026-08-28 "협상 후속 연락" |
| 골드 | — | `CA_Update_Opportunity_Last_Contact_From_*` | **미발화** (신규 완료 Call/Meeting/Email 없음). `Last_Contact_Date__c` 미래값은 Flow로 해결 불가 → **2026-08-29 승인 후 1회 직접 override** (§19-1) |
| 삼성 | 예정 Task insert | `CA_Update_Opportunity_Next_Activity` | Open 0→1 · Next_Activity 2026-09-08 "삼성카드 제안서 피드백 미팅 준비" |
| 삼성 | Quote sync | (standard) | Amount 402.5M→744M · HasOpportunityLineItem true |
| 다이아 | 완료 Call insert | `CA_Update_Opportunity_Last_Contact_From_Call` | Last_Contact 2026-08-27 Call · Days_Since 2 · LastActivityDate 2026-08-27 |
| Discovery | 완료 Event insert | `CA_Update_Opportunity_Last_Contact_From_Meeting` | Last_Contact 2026-08-27 02:00 "Online Meeting" |
| Discovery | 예정 Task insert | `CA_Update_Opportunity_Next_Activity` | Open→1 · Next_Activity 2026-09-03 "제안서 초안 작성" |

**Flow가 기대대로 동작하지 않아 "성공한 척" 값을 맞춘 사례 없음.** 골드 `Last_Contact` 이상은 원인(backing activity 없음 + Flow는 더 이른 날짜로 덮어쓰지 않음)을 먼저 규명·STOP·보고했고, 이후 **사용자 승인을 받아** 1회 직접 override로 해결(§19-1).

### 9.1 신규 발견 — `Negotiation_Followup_Flow` (metadata drift)

- org에 **Active** RecordAfterSave AutoLaunchedFlow. Version 1, `301bm00002hwAoyAAE`.
- 조건: Opportunity `StageName = Negotiation` 로 **변경될 때** (`doesRequireRecordChangedToMeetCriteria=true`).
- 동작: Task "협상 후속 연락" (Not Started / Normal / ActivityDate=내일 / WhatId=$Record.Id / OwnerId=$Record.OwnerId) 생성. dedup 로직 없음.
- **repo `salesforce/main/default/flows/` 에 없음** → 4번째 schema/metadata drift(§19-4). 팀은 "Opp가 Negotiation 진입할 때마다 후속 Task가 자동 생성됨"을 인지해야 함.

---

## 10. Quote / OLI / Sync 검증 (§10, §14)

| 항목 | 골드 | 삼성 |
|---|---|---|
| Quote Id | `0Q0bm000003BT3NCAW` (불변) | `0Q0bm000003FG2jCAG` (불변) |
| Quote Status | In Review → **Presented** | Draft → **Presented** |
| Quote GrandTotal / Discount | 300M / 0 (불변) | 744M / 7 (불변) |
| SyncedQuoteId | `0Q0bm000003BT3NCAW` (불변) | null → **`0Q0bm000003FG2jCAG`** |
| QLI | `0QLbm000003lDWNGA2` unit 300M, **HasRevenueSchedule=true** (불변) | `0QLbm000003qeqrGAA` unit 800M disc 7, HasRevenueSchedule=false (불변) |
| OLI | `00kbm00000k0x5fAAA` unit 300M, **HasRevenueSchedule=true** (불변) | **`00kbm00000kH8ZlAAK` 신규** — unit 800M / total 744M / list 800M (할인은 정가-총액 차이로 표현) |
| OLI Revenue Schedule | 3건 (2027-01/02/03, 각 100M) **불변** | 없음 |
| `NegotiationContext` lineItemDiscountUpdatable | **false** (revenue schedule lock, 불변) | true (revenue schedule 없음) |
| `NegotiationContext` lock reason | "이 라인 아이템에는 매출 일정(Revenue Schedule)이 설정되어 있어 할인율을 변경할 수 없습니다…" (불변) | — |
| DML during context read | **0** | 0 |

골드 revenue-scheduled QLI 할인 잠금(=QA #9 수정의 핵심)은 stage/Quote status 변경 후에도 **완전히 보존**됨.

---

## 11. Interaction Intelligence / Signal 상태 (§6, §11, §12)

| Opp | II 개수 | Signal 개수 | 상태 |
|---|---|---|---|
| 골드 | **2** (불변) | **6** (불변) | 텍스트·카테고리·방향·CreatedDate 전부 baseline과 동일. `DealContext` breakdown = `BUDGET: 1 (Negative 1) · FIT: 1 · INTEREST: 1 · RISK: 1 (Negative 1) · TIMING: 2` (불변). |
| 삼성 | 0 | 0 | **의도적 미생성** — 아래 참조 |
| 다이아 | 0 | 0 | 의도적 sparse |
| Discovery | 0 | 0 | **의도적 미생성** — 아래 참조 |

### 삼성 / Discovery II를 만들지 않은 이유

- production II 파이프라인 = Flow **`CA_Generate_Meeting_Interaction_Intelligence`** (Active). entry criteria: **`Event.Meeting_Type__c = 'Offline'`** + 내용 필드 1개 이상. Scheduled Path로 비동기 실행되어 Prompt Template(`CA_Offline_Meeting_Intelligence_UI`)을 호출.
- 삼성 Event(`삼성카드 2차 통화 - 조건 재협의`)는 `Meeting_Type__c`가 null → 대상 아님. Discovery Event는 `Meeting_Type__c='Online'` → 대상 아님.
- 태스크 §6 = "II를 직접 insert하면 production LLM Flow를 우회하므로 강제하지 않는다. Activity만 만들고 II는 라이브 Flow/E2E 데모에서 생성." → 준수.
- **팀 액션**: 삼성/Discovery에 II 데모가 필요하면 해당 Opp에 `Meeting_Type__c='Offline'` + 내용 필드가 있는 Event를 저장(또는 기존 Event를 Offline으로 수정 후 EndDateTime 갱신)하여 라이브 Flow를 태운다.

---

## 12. QA Fixture 보존 검증 (§3, §12, §14)

| 자산 | 기대 | 결과 |
|---|---|---|
| 골드 II 레코드 2건 | 개수·본문·CreatedDate 불변 | ✅ 불변 (in-place 편집도 안 함) |
| 골드 Signal 6건 | 카테고리/방향/Confidence/Evidence 불변 | ✅ 불변 |
| 골드 revenue-scheduled QLI `0QLbm000003lDWNGA2` | HasRevenueSchedule=true, 할인 잠금 유지 | ✅ `lineItemDiscountUpdatable=false`, lock reason 문구 동일 |
| 골드 OLI Schedule 3건 | 불변 | ✅ 3건, 각 100M, Type=Revenue |
| 골드 SyncedQuoteId | 불변 | ✅ `0Q0bm000003BT3NCAW` |
| 골드 대화 히스토리 시간순 | 오래된 것→최근 것 정렬 유지 | ✅ 7건, 08-27→08-30 오름차순 |
| "Platinum" 표기 불일치 (II 본문 "Platinum Sponsorship Discussion" vs Partner_Tier=Gold) | 이번 태스크에서 **편집 금지** (P1 polish) | ✅ 손대지 않음 |
| 삼성/다이아 = 기존 QA 미사용 | 안전 | ✅ NegotiationContextTest 등은 자체 테스트 데이터 사용, SeeAllData 의존분도 골드 fixture만 참조 |

---

## 13. Apex 회귀 결과 (§14)

`sf apex run test` (worktree `ca-dev-lwc-demo-data`, org `prod`), mutation **완료 후** 실행:

```
NegotiationRevenueScheduleTest
NegotiationContextTest
NegotiationTermsUpdaterTest
NegotiationOpportunityLookupTest
ConversationHistoryAgentActionTest
ActivityIntelligenceAgentActionTest
ActivityIntelligenceControllerTest
DealContextTest
→ outcome: Passed | passing: 88 | failing: 0 | testsRan: 88
```

baseline(88/88)과 동일. **0 regression.**

### 13.1 골드 read-only context 재검증 (DML 0)

- `NegotiationContext`: opp=골드, quote `0Q0bm000003BT3NCAW`, status `Presented`, QLI `0QLbm000003lDWNGA2`, `quoteDiscount=null`, `maxDiscountPercent=6.00`, `lineItemDiscountUpdatable=false`, lock reason 정상, **DML 0**.
- `DealContext`: `stageName=Negotiation`, `daysUntilClose=7`, `closeDateIsPast=false`, `quoteCount=1`, `hasSyncedQuote=true`, `syncedQuoteStatus=Presented`, `latestQuoteStatus=Presented`, `interactionCount=2`, `signalCount=6`, `negativeSignalCount=2`, `riskCategoryCount=1`, `openTaskCount=3`, `overdueTaskCount=1`, breakdown 불변, **DML 0**.
  - `daysSinceLastContactField` — override 전 -4(미래값), override 후 재확인 시 **1** (`Last_Contact_Date__c`=2026-08-28, 오늘 08-29). §19-1.
  - `DealContext`에는 여전히 healthScore / riskLevel / winProbability / isStalled / recommendedAction 필드 없음 (판단값 미생성 원칙 유지).

---

## 14. Agent Read-Only QA 결과 (§15)

Agent Builder **live 대화 QA는 이번 태스크에서 실행하지 않음** (비대화형 세션, publish/activate 금지, Proposal write-path 테스트 금지). 대신 Agent가 호출하는 **Apex action을 read-only로 직접 실행**하여 4개 Opp 전부 검증. **DML 0.**

| Opp | `find_opportunity` (NegotiationOpportunityLookup) | `get_interaction_intelligence` | `get_conversation_history` |
|---|---|---|---|
| 골드 | "골드 파트너십" → unique, `006bm00000VXKvlAAH`, "…(d'Alba(달바), **Negotiation**)" | resolved=true, found=true, count=2 (Platinum Discussion + 예산 검토, Signals 포함) | resolved=true, count=**7**, 08-27→08-30, 시간순 정상 |
| 삼성 | "삼성카드" → unique, `006bm00000VjTP7AAN`, "…(삼성카드, **Proposal/Quote**)" | resolved=true, found=false ("저장된 Interaction Intelligence가 없습니다") | resolved=true, count=4, 08-20→09-08 (Call→Email→Meeting→예정 Task) |
| 다이아 | "다이아몬드" → unique, `006bm00000VonmrAAB`, "…(d'Alba(달바), **Qualification**)" | resolved=true, found=false | resolved=true, count=1 (완료 Call만) — sparse 의도대로 |
| Discovery | "우아한형제들" → unique, `006bm00000VjUD5AAN`, "…(**Discovery**)" | resolved=true, found=false | resolved=true, count=2 (Online Meeting + 예정 Task) |

- 4개 Opp 모두 이름 기반 조회에서 **유일 매칭** → Opportunity Agent의 deterministic binding 경로(`find_opportunity` → `resolved_opportunity_id` → gated action) 정상.
- `opportunityResolved=true` 항상 — "조회 실패"와 "데이터 없음"을 구분하는 안전 문구도 정상 동작.
- Proposal write-path(`list_sponsorship_packages` / `save_proposal`) **테스트 안 함** (§15, §16).

---

## 15. 최종 데모 데이터 매트릭스

| 축 | 골드 (Negotiation) | 삼성 (Proposal/Quote) | 다이아 (Qualification) | Discovery (우아한형제들) |
|---|---|---|---|---|
| StageName / Prob / Forecast | Negotiation / 90 / Commit | Proposal/Quote / 75 / Best Case | Qualification / 20 / Pipeline | Discovery / 35 / Best Case |
| Amount / CloseDate | 300M / **2026-09-05 (마감 임박)** | 744M / 2026-10-11 | 1.5B / 2027-02-28 | 409M / 2026-10-16 |
| Partner_Tier | Gold | (null) | Platinum (보존) | (null) |
| Needs/KPI/요구사항 | ✅ 채움 | ✅ 채움 | ⛔ **의도적 null** | ✅ 채움 |
| Client_Budget / Status | (null) / (null) | 700M / Confirmed | ⛔ **null / Unknown** | 400M / Estimated |
| Qual picklist (Interest/Fit/DM) | 높음 / 높음 / 가능 | 높음 / 보통 / 가능 | 보통 / 높음 / 부분 가능 | 높음 / 높음 / 가능 |
| Primary Contact | 김하나 (보존) | 최지호 (보존) | 김하나 (신규 지정) | 서서연 (신규 지정) |
| Quote | `…BT3NCAW` **Presented**, synced | `…FG2jCAG` **Presented**, synced (신규) | `…F6rNCAS` Draft (보존, 미동기) | 없음 |
| OLI / Revenue Schedule | 1 / **있음 (할인 잠금)** | 1 (신규) / 없음 | 없음 | 없음 |
| Expected_Benefit ×3 | (null) | ✅ 보존 (승우님 작성분) | ✅ 보존 (승우님 작성분) | (null) |
| II / Signal | **2 / 6 (보존)** | 0 (라이브 Flow 대기) | 0 (sparse) | 0 (라이브 Flow 대기) |
| 완료 활동 | Task 2 + Offline Meeting 2 | Call 1 + Email 1 + Meeting 1 | **Call 1 (신규)** | **Online Meeting 1 (신규)** |
| 예정 활동 | "협상 후속 연락" ×3 (1건 Flow 자동) | "삼성카드 제안서 피드백 미팅 준비" ×1 (신규) | 0 | "제안서 초안 작성" ×1 (신규) |
| Last Contact | **2026-08-28 Call** (승인 후 1회 override, 최초 2026-09-03 미래값) | 2026-08-20 Call (기존) | 2026-08-27 Call | 2026-08-27 Online Meeting |
| stageProgress 체크리스트 | 완성도 높음 | 4/4 근접 | **의도적 미완성** | 6/6 |
| 데모 포인트 | Deal Intelligence / 마감 임박 / 협상 조건 잠금 | 제안·견적 / Quote sync / 할인 한도 | AI가 "정보 부족" 지적 | 니즈 파악 → 제안 준비 |

---

## 16. 생성된 레코드 ID

| Id | 객체 | Opp | 내용 | 생성 주체 |
|---|---|---|---|---|
| `00Tbm00000FquCrEAJ` | Task | 삼성 `006bm00000VjTP7AAN` | "삼성카드 제안서 피드백 미팅 준비" · Not Started · 2026-09-08 | 이 태스크 (PHASE 5) |
| `00Tbm00000FqxkvEAB` | Task | 다이아 `006bm00000VonmrAAB` | "다이아몬드 다년 업셀 초기 논의 통화" · Completed · Call · 2026-08-27 · WhoId 김하나 | 이 태스크 (PHASE 6) |
| `00Tbm00000Fqxo9EAB` | Task | Discovery `006bm00000VjUD5AAN` | "제안서 초안 작성" · Not Started · High · 2026-09-03 | 이 태스크 (PHASE 7) |
| `00Ubm000006vZyTEAU` | Event | Discovery `006bm00000VjUD5AAN` | "우아한형제들 니즈 파악 미팅" · Online · 2026-08-27 10:00–11:00 · WhoId 서서연 | 이 태스크 (PHASE 7) |
| `00Tbm00000FqxJVEAZ` | Task | 골드 `006bm00000VXKvlAAH` | "협상 후속 연락" · Not Started · Normal · 2026-08-30 | **`Negotiation_Followup_Flow` 자동** (골드 Negotiation 진입 부수효과) |
| `00kbm00000kH8ZlAAK` | OpportunityLineItem | 삼성 `006bm00000VjTP7AAN` | "유니폼 소매 패치 광고" · qty 1 · unit 800M · total 744M · PBE `01ubm000007icfjAAA` | **Quote sync 자동** |

신규 Opportunity / Account / Contact / Quote / QuoteLineItem / OLI Schedule / Interaction_Intelligence / Interaction_Signal **생성 0건**.

---

## 17. 수정된 레코드 ID

| Id | 객체 | 수정 필드 |
|---|---|---|
| `006bm00000VXKvlAAH` | Opportunity (골드) | StageName, Partner_Tier__c, Customer_Needs__c, Customer_KPI__c, Key_Requirements__c, Deal_Note__c, NextStep, **`Last_Contact_Date__c`(2026-08-29 승인 후 1회 override: 2026-09-03 → 2026-08-28)** (+ 자동: Probability, ForecastCategory, LastStageChangeDate, Open/Overdue Tasks Count, Next_Activity_*, Days_Since_Last_Contact__c formula -4 → 1) |
| `0Q0bm000003BT3NCAW` | Quote (골드) | Status (In Review → Presented) |
| `006bm00000VjTP7AAN` | Opportunity (삼성) | StageName, Target_Segment__c, Client_Budget_Status__c, Customer_Needs__c, Customer_KPI__c, Key_Requirements__c, Sponsorship_Interest_Level__c, Brand_Fan_Fit__c, Decision_Maker_Accessible__c, Expected_Timing__c, Target_Start_Season__c, Deal_Note__c, Pricebook2Id, SyncedQuoteId (+ 자동: Amount, HasOpportunityLineItem, ForecastCategory, Open Tasks Count, Next_Activity_*) |
| `0Q0bm000003FG2jCAG` | Quote (삼성) | Status (Draft → Presented) |
| `006bm00000VonmrAAB` | Opportunity (다이아) | SDO_Sales_Primary_Contact__c, Sponsorship_Interest_Level__c, Brand_Fan_Fit__c, Decision_Maker_Accessible__c, Expected_Timing__c, Target_Start_Season__c, Target_Segment__c (+ 자동: Last_Contact_*, LastActivityDate) |
| `006bm00000VjUD5AAN` | Opportunity (Discovery) | Customer_Needs__c, Customer_KPI__c, Key_Requirements__c, Target_Segment__c, Client_Budget__c, Client_Budget_Status__c, Target_Start_Season__c, Expected_Timing__c, Sponsorship_Interest_Level__c, Brand_Fan_Fit__c, Decision_Maker_Accessible__c, SDO_Sales_Primary_Contact__c, NextStep, Deal_Note__c (+ 자동: Last_Contact_*, Next_Activity_*, Open Tasks Count, LastActivityDate) |

---

## 18. Rollback Plan (§17)

> 참고용. mutation은 이후 작업(PR #90 등)에서 정상 데모 baseline으로 굳어졌으므로 실제 롤백은 권장하지 않는다. 기준점 스냅샷(`demo_data_snapshot_before/`)과 `rollback.apex`는 이 브랜치의 이전 커밋 히스토리에 있다.

**실행 순서** (의존성 때문에 순서 중요):

1. **삼성 un-sync + OLI 삭제 + 필드 원복**
   - `Opportunity 006bm00000VjTP7AAN.SyncedQuoteId = null` (update)
   - `delete OpportunityLineItem 00kbm00000kH8ZlAAK`
   - `Opportunity 006bm00000VjTP7AAN`: `Pricebook2Id=null`, `Amount=402500000`, `StageName='Proposal'`, `Target_Segment__c=null`, `Client_Budget_Status__c='Estimated'`, Needs/KPI/요구사항/Interest/Fit/DM/Timing/Season/Deal_Note = null
   - `Quote 0Q0bm000003FG2jCAG.Status = 'Draft'`
2. **신규 Activity 삭제**: `delete Task ('00Tbm00000FquCrEAJ','00Tbm00000FqxkvEAB','00Tbm00000Fqxo9EAB','00Tbm00000FqxJVEAZ')`, `delete Event 00Ubm000006vZyTEAU`
3. **골드 원복**: `Opportunity 006bm00000VXKvlAAH`: `StageName='Discovery'`, `Partner_Tier__c=null`, Needs/KPI/요구사항/Deal_Note = null, `NextStep='콜라보레이션 패키지 견적서 구성 및 발송'`; `Quote 0Q0bm000003BT3NCAW.Status='In Review'`
4. **다이아 원복**: `Opportunity 006bm00000VonmrAAB`: SDO_Sales_Primary_Contact/Interest/Fit/DM/Timing/Season/Segment = null
5. **Discovery 원복 (best-effort)**: `Opportunity 006bm00000VjUD5AAN` 위 §17 필드 = null. ⚠️ 이 Opp는 승인된 3개가 아니라 재사용분이라 개별 before-row가 없음 — 재사용 전 값이 있었다면 Owner(Manager Lee)/Creator(Aaron Choi)와 대조 필요.

**주의**: `StageName='Proposal'`(비활성)은 API로는 set 가능하나 UI에서 재선택 불가. 롤백 후 Flow 파생 필드(`Probability`, `Last_Contact_*`, `Open/Overdue Count` 등)는 Flow가 재계산하며 일부는 stale하게 남을 수 있으니 `demo_data_snapshot_before/`와 대조할 것.

**주의**: `Negotiation_Followup_Flow`는 골드가 다시 Negotiation으로 갈 때마다 Task를 또 만든다. 롤백 시 골드를 Discovery로 내리므로 재발화 없음.

---

## 19. 남은 이슈 / Deferred 항목

### 19-1. ✅ 골드 `Last_Contact_Date__c` 미래값 — 해결 (2026-08-29 승인 후 1회 override)

- 현상(최초): 골드 `Last_Contact_Date__c`가 오늘(08-29)보다 **미래인 2026-09-03**, `Last_Contact_Type__c='Call'`, `Days_Since_Last_Contact__c ≈ -4`. 이 날짜를 뒷받침하는 **완료 Activity가 없음** (실제 활동은 08-26~08-30만 존재).
- 원인: 이전에 누군가 필드를 직접 세팅했거나 잘못된 날짜의 Activity가 있었고 이후 삭제됨. `CA_Update_Opportunity_Last_Contact_From_*` Flow는 **"현재 값보다 더 최근"일 때만** 덮어쓰므로(`Is_Newer_Than_Current`), 08-27~08-29 완료 Call/Meeting을 새로 넣어도 09-03을 못 이긴다.
- 처리: 태스크 §3 지침("직접 field override는 최후 수단이며, 필요하면 먼저 STOP하고 이유 보고")에 따라 **먼저 STOP·보고 → 사용자 승인 후** `Last_Contact_Date__c`를 `2026-08-28T00:00:00Z`로 **1회 직접 override** (해당 필드만; 다른 business data·코드·metadata·Flow·Agent 미변경).
- 결과: `Last_Contact_Date__c` 2026-09-03 → **2026-08-28**, `Days_Since_Last_Contact__c` -4 → **1** (formula, 오늘 08-29 기준). `Last_Contact_Type__c`는 `Call` 그대로. 골드 Task 개수 5건 변화 없음(부수 레코드 생성 없음). backing activity 완료 Task `00Tbm00000FlSD7EAN` "협상 후속 연락" 2026-08-28와 정합.

### 19-2. 🟡 골드 "협상 후속 연락" Task 3건 중복 + org-only Flow

- `Negotiation_Followup_Flow`가 골드 Negotiation 진입 시 Task 1건 자동생성 → 동일 제목 미완료 Task 3건(08-28/08-29/08-30).
- 정상 동작이므로 이번 태스크에서 삭제·수정하지 않음(승인 범위 밖). P2 polish: 데모 전 팀이 (a) 자동생성 Task를 지우거나 (b) 제목/내용을 다르게 갈아끼우거나 (c) 그대로 "활발한 협상"으로 활용.
- Flow 자체는 repo에 없는 drift → §19-4.

### 19-3. 🟡 삼성 / Discovery Interaction Intelligence 미생성 (deferred)

- 사유: §11. production Flow는 `Meeting_Type__c='Offline'` Event만 처리. 태스크 §6이 직접 insert를 금지.
- 팀 액션: II 데모가 필요하면 해당 Opp에 Offline Meeting Event를 저장(또는 기존 Event를 Offline으로 바꾸고 EndDateTime 갱신)하여 라이브 Flow를 태운다.

### 19-4. 🟡 확인된 schema / metadata drift (repo ↔ org)

| drift | repo | org (실측) | 이번 태스크 대응 |
|---|---|---|---|
| `Sponsorship_Interest_Level__c` | Picklist 6값 | **활성 3값** (`높음`/`보통`/`낮음`) | org 값만 사용 (`높음`/`보통`). 첫 시도에서 `높음 (적극 검토 중)` → `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST` (트랜잭션 원자적 롤백, 잔여 없음), `높음`으로 재시도 성공. |
| `Target_Segment__c` | restricted Picklist | **Text(255)** | repo Picklist 허용값(`40-60 Male`, `10-30 Female`, `10-30 Male`)만 사용 → org가 나중에 Picklist로 복원돼도 valid. |
| `OpportunityLineItem.Discount` | (표준 필드 가정) | **필드 없음** (이 org에서 비활성) | OLI 스냅샷·sync에서 Discount 제외. 삼성 7% 할인은 sync가 "정가 800M vs 총액 744M"로 보존. |
| `Negotiation_Followup_Flow` | **없음** | Active AutoLaunchedFlow (`301bm00002hwAoyAAE`) | §9.1, §19-2. |
| `Event.Type` | (표준) | 없음/미사용 | 스냅샷 쿼리에서 제외, `Meeting_Type__c`/`Key_Discussion__c` 사용. |

이 drift들은 이번 태스크 범위(business data)가 아니므로 **수정하지 않음**. 별도 정리 필요 시 `05_DECISIONS.md` 또는 스키마 정합 태스크에서 다룰 것.

### 19-5. 🟢 경미

- Discovery `Amount`(409M) vs `Client_Budget__c`(400M) 약 2% 차이 — 수용 가능(§8.3).
- 골드 자동생성 Task Owner = Manager Lee vs 골드의 기존 Task Owner = Eunyeong Doh (bulk-load 유저) — cosmetic.
- 골드 II 본문의 "Platinum" 표기 (Partner_Tier=Gold와 불일치) — 태스크 §3에서 이번 편집 금지로 지정된 P1 polish. 손대지 않음.

---

## 20. Data Mutation Report — 무엇이 바뀌었나

| 카테고리 | 건수 | 상세 |
|---|---|---|
| Opportunity 필드 수정 | 4 레코드 | 골드·삼성·다이아·Discovery (§17) |
| 골드 `Last_Contact_Date__c` 직접 override (추가, 승인 후) | 1 레코드 · 1 필드 | 2026-09-03 → 2026-08-28 (§19-1) |
| Quote Status 수정 | 2 레코드 | 골드 In Review→Presented, 삼성 Draft→Presented |
| Opportunity ↔ Quote sync 신규 | 1 | 삼성 SyncedQuoteId 설정 (+ Pricebook2Id) |
| Task 신규 (직접) | 3 | 삼성 예정 1, 다이아 완료 Call 1, Discovery 예정 1 |
| Event 신규 (직접) | 1 | Discovery 완료 Online Meeting 1 |
| Task 신규 (Flow 자동) | 1 | 골드 "협상 후속 연락" |
| OpportunityLineItem 신규 (sync 자동) | 1 | 삼성 유니폼 소매 패치 광고 |
| **business data DML 총계** | **직접 update 7(초기 6 + Last_Contact override 1) · 직접 insert 4 · 자동 insert 2** | |
| Interaction_Intelligence / Signal 수정·생성 | **0** | 골드 fixture 완전 보존 |
| 신규 Opportunity / Account / Contact / Quote / QLI | **0** | |
| Closed Won / Closed Lost 생성·수정 | **0** | Decision 3 |
| 코드 / Apex / LWC / Flow / field / FlexiPage / permission / .agent 변경 | **0** | |
| metadata deploy / Agent publish / activate | **0** | |

전 mutation은 org(`prod`)에서만 수행. Salesforce 필드값 변경이며, 실제 기업 재무·계약·마케팅 사실을 주장하지 않는 CloudAlpacas 내부 CRM 시나리오용 dummy.

---

## 21. Git 상태

```
branch : feature/opportunity-demo-data  (PR #88)
main 반영 파일 : P2_RESULT_REPORT/Opportunity_Demo_Data_Implementation_Report.md  (이 문서 1개)
코드/메타데이터 변경 : 0
다른 워크트리/브랜치 : 미변경
```

---

## 22. 최종 판정

### **Verdict: A — demo data implementation complete, regression green**

> 최초 판정 B → 유일 blocker(§19-1)를 2026-08-29 사용자 승인 후 1회 override로 해결 → **A**.

**근거**
- ✅ 승인된 6개 결정 전부 그대로 적용 (재해석 없음). 추가 override 1건도 사용자 명시 승인 하에 수행.
- ✅ PHASE 0–7 전부 per-phase 검증 통과.
- ✅ Apex 회귀 88/88 (0 fail), baseline과 동일.
- ✅ 골드 QA fixture (II 2 / Signal 6 / revenue-schedule 할인 잠금 / SyncedQuoteId / 대화 시간순) 100% 보존.
- ✅ Agent read-only action 4개 Opp 모두 정상 resolve, DML 0.
- ✅ 4개 stage(Qualification/Discovery/Proposal-Quote/Negotiation) 데모 데이터가 stage별로 일관.
- ✅ 골드 `Last_Contact_Date__c` 미래값 해결 (2026-09-03 → 2026-08-28, `Days_Since` -4 → 1) — §19-1.

**남은 follow-up (블로커 아님, 설계상 정상)**
- 삼성/Discovery II는 라이브 Flow 대기 (§19-3) — production LLM Flow를 우회하지 않기 위한 의도적 deferral.
- org-only `Negotiation_Followup_Flow` drift 및 자동 Task (§19-2, §19-4) — 정상 동작, 문서화 완료.

**C(롤백 필요) 아님**: 모든 변경이 일관되고 회귀 green이며 QA fixture 무손상. 롤백은 준비만 해둠(§18).

---

## §20 대응 — Final Safety Report (명시적 YES/NO)

| 항목 | 답 |
|---|---|
| 승인된 6개 결정을 재해석 없이 그대로 적용했는가 | **YES** |
| 신규 브랜치를 만들었는가 | **NO** (기존 `feature/opportunity-demo-data` 사용) |
| #86 / #87 / 다른 워크트리·브랜치를 건드렸는가 | **NO** |
| business data mutation을 Salesforce org에서만 했는가 | **YES** (`prod`) |
| 코드 / Apex / LWC / Flow / field / FlexiPage / permission set / .agent 파일을 수정했는가 | **NO** |
| metadata deploy / Agent publish / activate 를 했는가 | **NO** |
| RecordType / Sales_Path / Path 메타데이터를 수정했는가 | **NO** (Decision 4) |
| Closed Won / Closed Lost 레코드를 생성·수정했는가 | **NO** (Decision 3) |
| 신규 Opportunity를 생성했는가 | **NO** (기존 clean Opp 재사용) |
| 다이아몬드 Quote / Expected_Benefit 값을 삭제·덮어썼는가 | **NO** (Decision 2, 보존) |
| 골드 Quote Id / QLI / OLI / Revenue Schedule / SyncedQuoteId / Discount / PBE 를 바꿨는가 | **NO** (Status만, Decision 5) |
| 골드 CloseDate 를 바꿨는가 | **NO** (2026-09-05 유지, Decision 6) |
| 골드 Interaction Intelligence / Signal 을 편집·생성했는가 | **NO** (완전 보존) |
| Flow 파생 필드를 직접 UPDATE 했는가 | **NO** (source Activity/Stage 변경 → Flow 계산) |
| 골드 `Last_Contact_Date__c` 를 직접 override 했는가 | **YES — 단, 2026-08-29 사용자 명시 승인 하에 해당 필드만 1회** (2026-09-03 → 2026-08-28). 다른 business data·코드·metadata·Flow·Agent 미변경. §19-1 |
| Flow가 기대대로 안 될 때 값을 맞춰 "성공한 척" 했는가 | **NO** (골드 Last Contact 이상은 먼저 STOP·보고 → 승인 후 override) |
| Interaction Intelligence 를 production LLM Flow 우회하여 직접 insert 했는가 | **NO** (삼성/Discovery II deferred) |
| Apex 회귀를 mutation 후 실행하고 0 fail 확인했는가 | **YES** (88/88; Last_Contact override 후에는 사용자 지시대로 재실행 안 함 — 단일 필드 값 변경이라 Apex 로직 무관) |
| 승인 범위를 넘는 문제 발견 시 임의 수정 없이 STOP·보고했는가 | **YES** (골드 Last Contact = §19-1, 승인 후에만 처리) |
| Agent publish/activate 또는 Proposal write-path 테스트를 했는가 | **NO** |
| PR 을 생성했는가 | **NO** |
| 이번 커밋에 문서·스냅샷 외 파일이 있는가 | **NO** |

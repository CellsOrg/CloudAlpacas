# P2 Campaign · Quote 고도화 — 미기록 구현 정리

> 승우(Product/Quote/Campaign) 파트에서 2026-08-20 이후 Production Org에 실제로 반영했지만, `03_SYSTEM.md`/`05_DECISIONS.md` 등 공식 문서(Source of Truth)에는 아직 기록되지 않은 항목을 정리한 문서입니다. `CLAUDE.md` §7("프로젝트 전체에 영향을 주는 변경은 반드시 Decision으로 기록한다")을 뒤늦게라도 충족하기 위한 체크포인트입니다.

| 항목 | 내용 |
| --- | --- |
| 작성자 | 승우(Rafael) |
| 기준일 | 2026-08-26 |
| 대상 Org | CloudAlpacas Production |
| 문서 목적 | Org에는 있지만 문서화되지 않은 구현을 팀이 검토·Decision화할 수 있도록 근거 자료로 남김 |
| 전제 | 이 문서는 그 자체로 공식 Decision이 아닙니다. 팀 논의 후 `05_DECISIONS.md`/`03_SYSTEM.md` 반영 여부를 결정합니다. |

---

## 1. 왜 이 문서가 필요한가

`05_DECISIONS.md` Decision 003·006·018은 "Standard First, 필요한 만큼만 Custom Object를 만든다"는 원칙과 "Object 구조 변경은 반드시 Decision으로 기록한다"는 원칙을 명시하고 있습니다. 그런데 2026-08-20 이후 진행한 Campaign 고도화 작업 중 일부는 이 원칙에 따라 팀 승인을 먼저 받지 않고 Production에 직접 반영됐습니다 — 급한 검증이 필요해 순서가 뒤바뀐 것이며, 지금이라도 근거를 남기고 팀 검토를 받기 위해 이 문서를 작성합니다.

아래 각 항목은 **목적 → 구현된 상태 → 쓰이는 용도** 순서로 정리했습니다.

---

## 2. Campaign_Deliverable__c (신규 Custom Object)

### 목적
Sponsorship Collaboration Campaign이 "체결"이 아니라 "실행" 단계에 들어갔을 때, 약속한 실행 과업(전광판 시안 승인, LED 설치, Brand Day 부스 준비 등)이 실제로 얼마나 진행됐는지를 추적하기 위해 만들었습니다. 표준 Campaign Object에는 "이번 협업에서 하기로 한 개별 작업 목록"을 표현할 필드가 없습니다.

### 구현된 상태
| 구분 | 상태 |
| --- | --- |
| Object/관계 | Master-Detail(Master = Campaign) — `Campaign__c` |
| 필드 7개 전부 (`Status__c`, `Weight__c`, `Campaign__c`, `Due_Date__c`, `Completed_Date__c`, `Evidence_URL__c`, `Notes__c`) | **정상 — SOQL/describe/UI 모두 조회 가능(2026-08-25 해결)** |
| ~~비정상~~ (해결됨) | ~~`Due_Date__c`/`Completed_Date__c`/`Evidence_URL__c`/`Notes__c` 4개 필드가 배포 후 5일간 SOQL/describe에서 조회 실패했던 문제~~ — **승우가 4개 필드를 직접 삭제 후 동일 설정(Label/Type/Help Text 한글化 포함)으로 재생성해서 해결**. Salesforce Support 케이스 없이 재생성만으로 스키마 레지스트리 문제가 풀림. |
| 실데이터 | `d'Alba Sponsorship Campaign`에 4건(Completed 2건/In Progress 1건/Not Started 1건, 가중치 합 100%) — **Due Date/Completed Date/Notes까지 전부 입력 완료(2026-08-25)** |
| 소스 반영 | **미완료** — 임시 스크래치패드 SFDX 프로젝트에서 배포되어 `force-app`(이 저장소 기준 `salesforce/`)에 소스로 남아있지 않음 |

### 쓰이는 용도
- Report `Sponsorship Deliverable Status - d'Alba` (Status별 Weight 합계)의 데이터 소스
- Dashboard `PRM Sponsorship Campaign Performance`의 "Total Deliverables" Metric 위젯(100%로 표시 중)

### 팀 검토가 필요한 이유
Decision 018-D는 "Campaign = Collaboration Record Type, 별도 Object 없음"만 확정했습니다. 이 Object는 그 위에 얹은 **추가 확장**이며, Decision 003(Standard First)에 비춰볼 때 "Report/Dashboard만으로는 정말 부족했는가"를 팀이 검토해야 합니다. 유지하기로 하면 정식 Decision으로 기록하고, 되돌리기로 하면 Report 기반 대안으로 전환합니다.

---

## 3. Campaign Member Status 5단계 확장 (Targeted → Reached → Engaged → Attended → Converted)

### 목적
기본 2단계(Targeted/Responded)로는 스폰서십 실행 중 팬 반응이 어느 단계까지 왔는지("타겟팅만 됐는지, 실제 참여까지 했는지") 구분할 수 없어서 5단계로 확장했습니다.

### 구현된 상태
- `d'Alba Sponsorship Campaign`(장기)에 먼저 적용(2026-08-20)
- `d'Alba Short-Term Sponsorship Campaign`(단기)은 예전 2단계(Sent/Responded)로 남아있던 것을 이번 세션(2026-08-24)에 동일한 5단계로 통일 — 기존 Status 삭제, 기존 Member 6건 재매핑 완료
- 두 Campaign 모두 현재 동일한 Status 세트를 사용 중임을 확인

### 쓰이는 용도
- Report `Sponsorship Member Funnel`의 그룹핑 기준(현재 전체 Sponsorship Campaign 대상으로 확장됨)

---

## 4. Campaign Hierarchy (Parent Campaign 도입)

### 목적
한 스폰서(d'Alba)가 단기·장기 두 협업을 동시에 진행하는 경우, 이를 상위 Campaign 아래로 묶어 스폰서 단위로 합산 조회하기 위해 도입했습니다. 표준 Campaign의 `ParentId` 필드는 원래 있지만 실제로 쓴 적이 없었습니다.

### 구현된 상태
- `d'Alba Sponsorship Partnership`(Parent) 신규 생성
- `d'Alba Sponsorship Campaign`(장기, 30억)·`d'Alba Short-Term Sponsorship Campaign`(단기, 3억)을 하위로 연결
- 각 Campaign의 `ExpectedRevenue`에 실제 연결된 Opportunity Amount 값 입력(가공 없음)

### 쓰이는 용도
- Report `Sponsorship Collaboration ROI`의 그룹핑 기준
- Dashboard 위젯 "스폰서십 협업별 예상 매출"

---

## 5. Campaign 표준 재무 필드 노출 (Budgeted Cost / Actual Cost / Expected Revenue)

### 목적
Salesforce Campaign에 원래 내장된 표준 ROI 계산 기능(확정 매출 대비 실집행 비용)을 스폰서십에도 활용하기 위해 `Sponsorship Collaboration Layout`에 세 필드를 노출했습니다.

### 구현된 상태
- Layout에 "Sponsorship Financials" 섹션 신규 추가·배포 완료
- `ExpectedRevenue`: 실제 값(위 §4 참고)
- `BudgetedCost`/`ActualCost`: **실제 재무 데이터가 아니라 승우가 만든 시나리오 값**입니다(장기 1.5억/6천만, 단기 3천만/0 — Deliverable 진행률(40% 완료) 비례로 산정). 실제 집행 비용이 확정되면 반드시 교체해야 합니다.

### 쓰이는 용도
- Salesforce 표준 Campaign ROI 계산(현재는 두 딜 다 Closed Won 전이라 ROI가 -100%로 표시됨 — 정상 동작, Won 금액 기준 계산이기 때문)

---

## 6. B2B Sponsorship Report 5종 신규 생성

| Report | 목적 | 상태 |
| --- | --- | --- |
| `Sponsorship Collaboration ROI` | 협업(Parent Campaign)별 예상 매출/ROI | 실행 검증 완료, Dashboard 위젯 연결됨 |
| `Sponsorship Pipeline by Stage` | Opportunity Stage별 딜 건수·합계 금액 | 실행 검증 완료 |
| `Sponsorship Open Package Count` | 진행 중인 딜 개수 | 실행 검증 완료(현재 2건) |
| `Sponsorship Average Quote Amount` | 평균 Quote 금액 | 실행 검증 완료(현재 16.5억) |
| `Sponsorship Collaboration Status` | Collaboration Status별 건수 | 실행 검증 완료(현재 3건, 전부 Planned) |

### 쓰이는 용도
전부 `PRM Sponsorship Campaign Performance` Dashboard(기존 대시보드, 혜준·승우 공동 사용)에 위젯으로 통합하는 방향으로 진행 중입니다.

### 팀 검토가 필요한 이유
Decision 018-J는 Fan Insight에 대해서만 "Report/Dashboard, Object 없음"을 확정했습니다. B2B Sponsorship Pipeline/ROI Dashboard 자체는 Decision 019 §7에서 방향(현재 Opportunity 수, Pipeline Amount 등)만 언급됐을 뿐 "구체적인 KPI 공식/Field는 확정하지 않는다(TBD)"로 명시돼 있습니다. 위 5개 Report는 그 TBD를 실제로 채운 첫 구현이므로, 팀이 이 방향이 맞는지 확인해주시면 좋겠습니다.

---

## 7. Product Schedule 활성화 (Quantity/Revenue Schedule)

### 목적
전광판 광고처럼 한 번에 끝나지 않고 기간에 걸쳐(예: 3개월 노출) 집행되는 스폰서십을 월별로 나눠 관리하기 위해 활성화했습니다.

### 구현된 상태
- Org 설정(Setup > Quantity and Revenue Schedules) 활성화 완료
- `전광판 광고 + Brand Day 패키지` 상품에 Revenue Schedule Type = Divide, 3개월 분할 설정
- `d'Alba Short-Term Sponsorship` 딜의 실제 OpportunityLineItem에 3개월 스케줄(1억×3=3억) 생성·합계 검증 완료

### 쓰이는 용도
현재는 검증용 데이터 1건뿐이며, 향후 다른 기간제 스폰서십 상품에도 동일하게 적용 가능합니다.

---

## 8. Company Information 정비

### 목적
Quote PDF에 표시되는 발신 회사 정보(Cloud Alpacas 주소·연락처)가 비어있어 실제 발송용으로 쓸 수 없는 상태였습니다.

### 구현된 상태
- Organization Name: `Cloud Alpacas`
- Street/City: `6th floor, 27, Changgyeonggung-ro 5da-gil, Jung-gu` / `Seoul`
- Phone/Fax: `010-2026-0904` / `04545`
- Postal Code는 아직 미입력(값을 받는 대로 추가 필요)

### 쓰이는 용도
Quote Template PDF 발신자 정보 전체

---

## 9. 필드 Help Text 정리 (2026-08-25 반영)

Product2/Quote/Campaign의 표준 필드 중, 값의 뜻이 한눈에 안 들어오는 필드에 한글 Help Text를 추가했습니다(Setup → 필드 편집 화면의 ⓘ 아이콘에 노출). `Name`/`StartDate`/`EndDate`처럼 뜻이 자명한 필드는 일부러 넣지 않았습니다.

| 오브젝트 | 필드 | Help Text |
| --- | --- | --- |
| Product2 | `Family` | 이 상품이 어떤 계열인지 구분하는 값입니다. Sponsorship Package는 항상 'Sponsorship'으로 둡니다. |
| Product2 | `RevenueScheduleType` | 이 상품의 매출을 기간에 걸쳐 나눠 인식할지 정합니다. 'Divide'로 설정하면 전체 금액을 개월 수만큼 균등하게 나눠 월별 매출로 잡습니다(예: 3개월 전광판 노출). |
| Product2 | `RevenueInstallmentPeriod` | 매출을 나눌 주기입니다. 스폰서십 상품은 보통 'Monthly'(월별)로 관리합니다. |
| Quote | `Status` | 이 견적서가 지금 어느 단계인지 나타냅니다. 새로 작성하면 Draft이고, 검토·승인을 거쳐 상대방에게 전달(Presented)한 뒤 최종적으로 Accepted 또는 Rejected로 마무리됩니다. |
| Quote | `ExpirationDate` | 이 견적의 유효기한입니다. 이 날짜가 지나면 동일한 조건으로 계약을 보장할 수 없습니다. |
| Campaign | `Type` | 이 Campaign의 목적을 구분하는 값입니다. 스폰서십 협업은 항상 'Sponsorship'을 사용합니다. |
| Campaign | `Status` | 이 협업이 지금 어느 단계인지 나타냅니다. Planned(계획 수립) → In Progress(실행 중) → Completed(정상 종료) 또는 Aborted(중단) 순서로 관리합니다. |
| Campaign | `IsActive` | 지금 실제로 실행 중인 협업인지 표시합니다. 계약은 됐지만 아직 실행 전(Planned)이면 체크를 해제한 상태로 둡니다. |
| Campaign | `ParentId` | 이 협업이 속한 상위 스폰서 관계입니다. 같은 스폰서 기업과 여러 번(단기·장기 등) 협업할 때, 상위 Campaign 아래로 묶어서 합산 관리합니다. |
| Campaign | `BudgetedCost` | 이 협업을 실행하기 위해 미리 잡아둔 예산입니다. |
| Campaign | `ActualCost` | 이 협업을 실행하면서 실제로 집행한 비용입니다. Budgeted Cost와 비교해서 예산 대비 집행률을 확인할 수 있습니다. |
| Campaign | `ExpectedRevenue` | 이 협업으로 예상되는 매출(스폰서십 계약 금액)입니다. 연결된 Opportunity의 Amount를 기준으로 입력합니다. |
| Campaign_Deliverable__c | `Due_Date__c`/`Completed_Date__c`/`Evidence_URL__c`/`Notes__c` | §2 참고 — 필드 재생성과 함께 Help Text도 함께 반영됨 |

---

## 10. Picklist 단계별 의미 (Quote Status / Campaign Status / Campaign Member Status)

Salesforce는 필드 전체에는 Help Text를 붙일 수 있지만, **Picklist 값 하나하나에는 시스템상 Help Text를 붙일 수 없습니다.** 그래서 아래 내용은 Org에 입력한 것이 아니라, 팀원이 각 단계의 의미를 헷갈리지 않도록 이 문서에 정리해둔 참고 자료입니다 — 값 이름만 나열하지 않고 "이 상태가 실제로 뭘 뜻하는지"를 적었습니다.

### 10.1 Quote Status (Standard Quote 기본값, 8단계)

| 값 | 의미 |
| --- | --- |
| Draft | 견적서를 작성하는 중입니다. 아직 상대방에게 전달되지 않은 내부 초안 상태입니다. |
| Needs Review | 작성은 끝났지만, 발송 전에 내부 검토가 필요하다고 표시된 상태입니다. |
| In Review | 내부 검토가 실제로 진행되고 있는 상태입니다. |
| Approved | 내부 검토·승인이 끝나 상대방에게 발송할 준비가 된 상태입니다. |
| Presented | 승인된 견적서를 실제로 스폰서(상대 회사)에게 전달한 상태입니다. |
| Accepted | 상대방이 이 견적 내용을 최종적으로 수락한 상태입니다. |
| Rejected | **내부 승인 절차에서** 반려되어, 상대방에게 전달되지 못하고 끝난 상태입니다. |
| Denied | **상대방에게 전달한 뒤** 상대방이 거절한 상태입니다. |

> ⚠️ `Rejected`와 `Denied`는 Standard Quote 기본 제공 값이라 그대로 두었지만, 이름만으로는 구분이 잘 안 됩니다. 위 구분("내부 반려" vs "상대방 거절")은 제가 제안하는 해석이며, **팀이 실제로 이렇게 나눠 쓸지 합의가 필요합니다** — 현재 실제 Quote 2건은 모두 Draft라 아직 이 두 값이 실사용된 적은 없습니다.

### 10.2 Campaign Status (Sponsorship Collaboration, 4단계)

| 값 | 의미 |
| --- | --- |
| Planned | 협업이 확정(계약 체결)됐지만, 아직 실제 실행(광고 노출, 이벤트 진행 등)을 시작하지 않은 단계입니다. |
| In Progress | 실제로 실행 중인 단계입니다 — 전광판 광고가 노출되고 있거나 Brand Day 행사가 진행되는 등. |
| Completed | 계획했던 실행이 정상적으로 끝난 단계입니다. |
| Aborted | 실행 도중 또는 그 전에 중단된 단계입니다 — 계약 해지, 상호 합의에 의한 중단 등. |

### 10.3 Campaign Member Status (팬 반응 5단계 퍼널)

| 값 | 의미 |
| --- | --- |
| Targeted | 이번 협업의 타겟 Fan으로 선정된 상태입니다. 아직 실제 접촉은 이뤄지지 않았습니다. |
| Reached | 실제로 접촉(발송, 노출 등)이 이뤄진 상태입니다. 아직 Fan의 반응은 확인되지 않았습니다. |
| Engaged | Fan이 실제로 반응(클릭, 참여 의사 표현 등)을 보인 상태입니다. 여기서부터 `HasResponded = Yes`로 집계됩니다. |
| Attended | 오프라인 행사(Brand Day 부스 등)에 실제로 참여한 상태입니다. |
| Converted | 이 협업을 통해 목표했던 최종 행동(구매, 가입 등)까지 이어진 상태입니다. |

---

## 11. Dashboard 최종 구성 (2026-08-25)

`PRM Sponsorship Campaign Performance` Dashboard에 §6의 Report 5종을 전부 위젯으로 반영하고, 기존 2개(Total Deliverables, Member Funnel)와 합쳐 총 7개 위젯 구성을 완료했습니다.

| 위젯 | 원본 Report | 타입 |
| --- | --- | --- |
| 진행 중인 스폰서십 패키지 | Sponsorship Open Package Count | Metric |
| 평균 견적 금액 | Sponsorship Average Quote Amount | Metric |
| 스폰서십 협업별 예상 매출 | Sponsorship Collaboration ROI | Bar Chart |
| 스폰서십 진행 현황 (구 "Collaboration 진행 현황") | Sponsorship Collaboration Status | Table |
| 스폰서십 파이프라인 | Sponsorship Pipeline by Stage | Table |
| 실행 과업 진행률 (구 Total Deliverables) | Sponsorship Deliverable Status | Metric |
| 팬 반응 퍼널 (구 Member Funnel) | Sponsorship Member Funnel | Table |

**이름 변경 배경**: "Collaboration 진행 현황"을 "스폰서십 진행 현황"으로 바꿨습니다 — `05_DECISIONS.md` Decision 019가 이미 "B2B Story의 중심을 Collaboration에서 Sponsorship Sales/Pipeline으로 전환"하기로 확정해뒀는데, 위젯 이름에는 이게 반영되지 않고 있었습니다. Dashboard 이름 자체도 `스폰서십 통합 현황판`으로 바꾸는 걸 제안드립니다(현재 "PRM Sponsorship Campaign Performance"는 영문이고, 지금은 실행 성과뿐 아니라 파이프라인·재무·진행상태·반응까지 다 포함하는 통합 현황판이 됐기 때문입니다) — 대시보드 이름 자체를 바꿀지는 팀 확인 후 진행하는 걸 권장합니다.

### 발견 및 수정한 버그 — Report 형식(Tabular) 문제

`Sponsorship Open Package Count`/`Sponsorship Average Quote Amount` 두 Report를 Dashboard 위젯으로 추가하려 하면 **"We can't get data for this widget right now"** 오류가 났습니다. 원인은 데이터가 아니라 Report 형식이었습니다 — Salesforce는 그룹핑이 하나도 없는 Report를 "Summary" 형식으로 저장해도 내부적으로 "Tabular"로 되돌리는데, Dashboard 위젯(특히 Metric 타입)은 Tabular Report를 지원하지 않습니다. **의미 있는 그룹(Stage)을 하나씩 추가해서 진짜 Summary 형식으로 고정**해 해결했습니다 — Metric 위젯은 어차피 전체 합계(Grand Total)만 쓰기 때문에, 그룹이 추가돼도 화면에 보이는 숫자는 그대로입니다.

---

## 12. Net Profit Custom Summary Formula 추가

### 배경
"구단 재정 상태 개선"이라는 Business Goal(CLAUDE.md §2, Decision 019)에 맞춰, 스폰서십 협업이 실제로 얼마나 순이익을 내는지 확인할 방법이 필요했습니다. Salesforce 표준 Campaign ROI(%)는 이미 있었지만, 원(KRW) 단위의 순이익 금액을 보여주는 지표는 없었습니다.

### 구현
`Sponsorship Collaboration ROI` Report에 Custom Summary Formula를 추가했습니다.
- **Column Name**: `Net Profit`
- **Formula**: `EXP_REVENUE:SUM - ACTUAL_COST:SUM` (Expected Revenue 합계 − Actual Cost 합계)
- **Format**: Currency, Display: All Summary Levels

### 검증
전체 합계 기준 `예상 매출 33억 − 실집행 비용 6천만 = 순이익 32억 4천만`으로 정확히 계산되는 것을 API로 재조회해 확인했습니다.

### 쓰이는 용도
`스폰서십 협업별 예상 매출` Dashboard 위젯의 Report에 그대로 반영되어, Parent Campaign(스폰서)별 실제 순이익을 원 단위로 바로 확인할 수 있습니다.

---

## 13. Campaign.ExpectedRevenue 자동 동기화 (Flow 3종 신설)

### 배경
`Campaign.ExpectedRevenue`는 원래 승우가 연결된 Opportunity의 Amount 값을 **손으로 복사해 넣은 것**이었습니다(§5 참고). `03_SYSTEM.md` Decision 014가 B2C 쪽에 이미 경고해둔 것과 똑같은 함정입니다 — "원천 데이터를 다른 곳에 복제하면 나중에 어긋난다." Opportunity Amount가 바뀌면 Campaign 쪽은 자동으로 안 바뀌므로, 두 값이 서로 다른 숫자를 보여줄 위험이 있었습니다.

### 왜 Roll-Up Summary가 아니라 Flow인가
Opportunity → Campaign 연결(Primary Campaign Source)은 표준 **Lookup** 관계입니다. Roll-Up Summary는 **Master-Detail** 관계에서만 가능해서 못 씁니다 — 이건 `05_DECISIONS.md` Decision 018-K(Account 집계 필드 On Hold)가 Account-Opportunity 관계에서 이미 겪은 것과 동일한 제약입니다. Flow가 Salesforce에서 이 경우 쓰는 표준적인 대안입니다(Decision 003 "Standard First"의 연장).

### 구현 — Flow 3개 (Subflow 패턴)

같은 계산 로직(Campaign에 연결된 Opportunity 금액 합산)을 여러 트리거(생성/수정/삭제)가 공유해야 해서, 로직 중복으로 인한 정합성 어긋남을 막기 위해 **Subflow로 분리**했습니다.

| Flow | Label | API Name | 역할 |
| --- | --- | --- | --- |
| Subflow | `Campaign 예상 매출 계산` | `Recalculate_Campaign_Expected_Revenue` | 계산 로직 본체 — Campaign Id와 "제외할 Opportunity Id"(선택)를 입력받아 합산 후 Campaign.ExpectedRevenue 갱신 |
| Flow 1 | `Campaign 예상 매출 동기화` | `Campaign_Expected_Revenue_Sync` | Opportunity 생성/수정 시 Subflow 호출(제외 Id 없음) |
| Flow 2 | `Campaign 예상 매출 동기화 (Opportunity 삭제 시)` | `Campaign_Expected_Revenue_Sync_On_Delete` | Opportunity 삭제 시 Subflow 호출(삭제되는 자기 자신 Id를 제외 Id로 전달) |

> Salesforce Record-Triggered Flow는 "생성/수정"과 "삭제"를 하나의 Flow에서 동시에 트리거할 수 없어서 Flow가 2개로 나뉩니다. 삭제 시 제외 로직은 "제외할 Opportunity Id가 비어있으면 아무것도 제외되지 않는다"는 성질을 이용해, 조건 분기 없이 하나의 Subflow로 생성/수정/삭제를 전부 처리하도록 설계했습니다.

### 검증 (2026-08-25, 실제 테스트)

| 시나리오 | 결과 |
| --- | --- |
| 테스트 Opportunity 생성(연결 Campaign에 2,000,000 추가) | ✅ Campaign.ExpectedRevenue: 300,000,000 → 302,000,000 |
| 그 Opportunity 삭제 | ✅ Campaign.ExpectedRevenue: 302,000,000 → 300,000,000 (수동 개입 없이 자동 복구) |

### 알려진 한계
- Opportunity의 Campaign(Primary Campaign Source)이 **변경**되는 경우(A Campaign → B Campaign으로 재연결)는 Flow 1이 "새 Campaign(B)"의 합계는 갱신하지만, **"예전 Campaign(A)"의 합계는 갱신하지 않습니다** — A는 여전히 예전 Opportunity가 포함된 금액으로 남습니다. 이 케이스가 실제로 발생할 가능성이 있으면 추가 보완이 필요합니다.

---

## 14. 이번 작업 중 발견한 플랫폼 제약사항

### Product Schedule이 걸린 Line Item은 단가 변경 불가
Revenue Schedule이 설정된 OpportunityLineItem/QuoteLineItem은 **단가(Sales Price/Unit Price)를 직접 수정할 수 없습니다**(`Invalid unit price change on Quote Line Item; cannot modify unit price when the item is revenue scheduled`). 스케줄이 이미 그 가격을 기준으로 월별 분할돼 있어서, 가격을 바꾸려면 기존 스케줄을 먼저 삭제해야 합니다. `d'Alba Short-Term Sponsorship`의 전광판 광고 상품이 여기 해당됩니다 — 향후 이 딜의 금액을 조정할 일이 생기면 스케줄부터 지워야 한다는 걸 팀이 알고 있어야 합니다.

### Quote Sync 중에는 Opportunity Line Item을 직접 고치면 안 됨 (기존 경고 재확인)
Quote가 Syncing 중일 때 OpportunityLineItem 쪽 필드(예: UnitPrice)를 직접 수정하면, Sync 엔진이 QuoteLineItem 값 기준으로 **조용히 되돌립니다**(에러 없이 원래 값으로 리셋됨). 이건 2026-08-21 Daily Report에 이미 기록된 "동시 추가 시 금액 2배" 이슈와 같은 뿌리의 문제입니다 — Syncing 중에는 반드시 Quote Line Item 쪽만 고쳐야 합니다.

---

## 15. Campaign Record Type 확장 (2종 → 4종)

### 배경
기존에는 Campaign Record Type이 `Fan_Campaign`(팬 대상 일반 마케팅)과 `Sponsorship_Collaboration`(계약 체결 후 실행) 2종뿐이었습니다. 실제 B2B 세일즈 흐름을 보면 계약 체결 **전** 단계(잠재 스폰서사 담당자 발굴)와 계약 만료 임박 시 **갱신 제안** 단계도 Campaign으로 관리할 필요가 있는데, 이 두 시나리오를 담을 Record Type이 없었습니다.

### 구현된 상태
| Record Type (신규) | Label | 대상(Target) | 용도 |
| --- | --- | --- | --- |
| `Sponsorship_Prospecting` | Sponsorship Prospecting | 잠재 스폰서사 담당자(Lead) | 계약 체결 전, 리드 모집 단계 |
| `Sponsorship_Renewal` | Sponsorship Renewal | 기존 스폰서사 담당자(Contact) | 계약 만료 임박 시 갱신 제안 |

- Metadata API로 RecordType 2종 배포 완료. 다만 **Profile의 Record Type 가시성/Layout 배정은 Metadata API로 자동 반영되지 않아서**, System Administrator Profile → Object Settings → Campaigns 화면에서 수동으로 Enable 처리하고 Layout을 기존 `Sponsorship Collaboration Layout`으로 지정(2026-08-26 완료, describe API로 `"available": true` 확인).
- 전체 Campaign Record Type 4종: `Fan_Campaign`, `Sponsorship_Prospecting`, `Sponsorship_Collaboration`, `Sponsorship_Renewal`.
- Member Status 퍼널을 새로 만든 실제 Prospecting 캠페인 1건("2026 Q4 스폰서십 데이 - 잠재 스폰서사 발굴")에 세팅: 후보 선정(기본값)→메일 발송→콜드콜 완료→참석 확정(Responded)→리마인드 완료→행사 참석(Responded).

### 쓰이는 용도
Campaign 생성 시 스폰서 관계의 생애주기 단계(발굴→실행→갱신)를 Record Type으로 구분해서 관리.

### 팀 검토가 필요한 이유
Decision 018-D("Campaign vs Collaboration → Campaign Record Type으로 구현")를 그대로 따른 확장이지만, Record Type 종류 자체가 늘어난 건 아직 문서화되지 않은 변경입니다. 새 Decision(예: Decision 020)으로 기록 후 혜준님 확인을 권장합니다.

---

## 16. Campaign List View 4종 신규 (Record Type별)

### 배경
Record Type이 4종으로 늘어나면서, Campaign 탭에서 유형별로 빠르게 필터링해서 볼 수 있는 List View가 필요했습니다.

### 구현된 상태
| List View (API Name) | 라벨(한글) | 필터 |
| --- | --- | --- |
| `Fan_Campaign_List` | 팬 캠페인 목록 | RecordType = Fan_Campaign |
| `Sponsorship_Prospecting_List` | 스폰서십 발굴 캠페인 목록 | RecordType = Sponsorship_Prospecting |
| `Sponsorship_Collaboration_List` | 스폰서십 협업 캠페인 목록 | RecordType = Sponsorship_Collaboration |
| `Sponsorship_Renewal_List` | 스폰서십 갱신 캠페인 목록 | RecordType = Sponsorship_Renewal |

> ⚠️ `ExpectedRevenue`는 이 org의 통화 설정 관련 이슈로 List View 컬럼 토큰(`CAMPAIGN.EXPECTED_REVENUE`)이 인식되지 않아 제외했습니다 — Collaboration/Renewal 목록은 대신 예산(BudgetedCost)/실집행비(ActualCost)를 표시합니다.

---

## 17. Campaign Hierarchy 확장 — 스폰서 관계 5곳

### 배경
기존 Hierarchy는 d'Alba 한 곳뿐이었습니다. §15의 새 Record Type들이 생기면서, "이 스폰서 관계의 전체 생애주기(발굴/실행/갱신) 누적 성과"를 Campaign Hierarchy Rollup(표준 기능, `HierarchyAmountWonOpportunities` 등)으로 보기 위해 확장했습니다.

### 구현된 상태
| 회사 | 최상위 루트 Campaign | 하위 연결 |
| --- | --- | --- |
| d'Alba | d'Alba Sponsorship Partnership | 협업 2개 + 갱신 1개 |
| 그린빈 커피 | 그린빈 커피 스폰서십 협업 캠페인 | 갱신 1개 |
| 루나 뷰티 | 루나 뷰티 시즌 스폰서십 캠페인 | 갱신 1개 |
| 파인베이스 스포츠 | 파인베이스 스포츠 스폰서십 갱신 협상 캠페인 | (하위 없음, 자기 자신이 루트) |
| 오르빗 통신 | 오르빗 통신 스폰서십 갱신 제안 캠페인 | (하위 없음, 자기 자신이 루트) |

Sponsorship_Prospecting 캠페인(5건)은 의도적으로 Hierarchy에서 제외했습니다 — 하나의 Prospecting 캠페인이 여러 회사를 동시에 타겟하는 대량 아웃바운드라서, 특정 회사 하나의 Hierarchy Tree에 묶는 게 구조적으로 맞지 않기 때문입니다.

### 검증
`d'Alba Sponsorship Partnership`의 `HierarchyExpectedRevenue`가 300,000,000으로 정상 롤업되는 것을 API로 확인(연결된 Opportunity 1건 기준). 별도 배치 작업 없이 실시간 계산되는 표준 기능임을 확인.

### 알려진 제약
`HierarchyAmountAllOpportunities`/`HierarchyAmountWonOpportunities`는 `Opportunity.CampaignId`(Primary Campaign Source)가 채워져 있어야 집계됩니다. 확인 결과 전체 Opportunity 103건 중 **1건만** 이 필드가 채워져 있어서, 지금은 d'Alba 외에는 실질적인 Rollup 값이 0으로 나옵니다 — 영업 프로세스에 "Opportunity 생성 시 Primary Campaign Source 입력"을 정착시키는 게 팀 차원에서 필요합니다.

---

## 18. Partner Tier(Gold/Platinum/Diamond) 및 Sponsorship Package 재설계

### 배경
동료분(Opportunity Qualification 담당)이 `Partner_Tier__c`(Gold/Platinum/Diamond, Opportunity 필드, 종합 판단 기반·자동산정 없음)를 이미 배포하셨고, 이걸 Product/Quote 쪽과 어떻게 연결할지 논의가 있었습니다. 최종적으로 **"Product에서 Tier를 자동 계산하지 않는다"**는 원칙을 유지하면서, Tier별 제안 패키지를 참고용 Product로 준비하는 방향으로 정리했습니다.

### 핵심 설계 원칙 (동료분 피드백 반영)
- **Gold — Visibility**: 반복 노출이 목적, 단일 채널
- **Platinum — Engagement**: 노출을 넘어 팬과의 실제 접점이 목적, 복수 채널
- **Diamond — Strategic Partnership**: 상품 총량이 아니라 **"공식 파트너" 지위 자체가 핵심 가치** — 노출성 상품(유니폼 메인 패치 등)은 의도적으로 배제하고, 지위/독점 자산만 구성

### 신규 Product 7종
| 분류 | Product | 비고 |
| --- | --- | --- |
| 개별 상품 5종 | 업종 독점 스폰서십 권리, 유니폼 메인(가슴) 패치 광고, 홈경기 중계 방송 배너 노출권, 개막전/올스타전 스페셜 게임 타이틀 스폰서십, 공식 파트너 지위 인증권 | 기존 카탈로그(13종)에 없던 "독점/지위/방송" 자산 갭을 채움 |
| 티어 패키지 3종 | Gold 스타터 패키지, Platinum 통합 마케팅 패키지, Diamond 전략 파트너십 패키지 | 개별 구매 대비 10% 할인 적용, 담당자가 그대로 제안하거나 개별 조정 가능 |

전체 Sponsorship Product 카탈로그: 13종 → **21종**(개별 18 + 사전 번들 3, 신규 5개 개별 상품 중 4개는 단품·1개는 최종적으로 Diamond 패키지 구성품으로만 편입)

### 가격 조정 이력 (총 3차례, 2026-08-26)
실제 KBO/MLB 스폰서십 시세를 조사해서 3단계에 걸쳐 조정했습니다.

1. **1차**: 명명권이 유니폼 패치보다 저렴한 등 상대적 순위 오류 수정 + 독점/지위 자산군을 카탈로그 최상위로 재배치
2. **2차**: "적자 구단 → 프리미엄 구단으로 성장" 스토리 반영, 전체 1.5배 상향
3. **3차**: 한국 프로야구 기준 벤치마크(키움 히어로즈 팀명 스폰서십 연 100억원+, 수원삼성 유니폼 메인 스폰서 연 190.8억원) 조사 결과, 이 수치들은 **계열사/모기업 관계형 스폰서십**이라 순수 제3자 시장가와는 성격이 다르다는 점을 반영해 전체 1.3배 추가 상향(계열사 벤치마크의 절반 이하 수준으로 유지 — "제3자 스폰서 현실선")

### 최종 가격표 (2026-08-26 기준)
| Product | 코드 | 최종가 | 기본 계약 단위 |
| --- | --- | --- | --- |
| Diamond 전략 파트너십 패키지 | SPN-PKG-DIAMOND | 52.2억 | 최소 3년 이상 |
| 구장 내 특별 구역 명명권 | SPN-NAMING-ZONE | 24억 | 최소 3년 이상 |
| 유니폼 메인(가슴) 패치 광고 | SPN-UNIFORM-MAIN | 20억 | 1년(시즌), 권장 2~3년 |
| 공식 파트너 지위 인증권 | SPN-OFFICIAL-PARTNER-STATUS | 18억 | 1년(갱신형), 권장 2년+ |
| 업종 독점 스폰서십 권리 | SPN-CATEGORY-EXCLUSIVE | 16억 | 1년(갱신형), 권장 2년+ |
| Platinum 통합 마케팅 패키지 | SPN-PKG-PLATINUM | 12.42억 | 1년 |
| 전광판 광고 + Brand Day 패키지 | SPN-LED-BRANDDAY | 11억 | 1년(Brand Day 1회 포함) |
| 백네트 후면 LED 전광판 광고 | SPN-LED-BACKNET | 10억 | 1년(정규시즌) |
| 유니폼 소매 패치 광고 | SPN-UNIFORM-SLEEVE | 8억 | 1년(시즌) |
| 외야 보조 전광판 광고 | SPN-LED-OUTFIELD | 5억 | 1년(정규시즌) |
| 개막전/올스타전 타이틀 스폰서십 | SPN-MARQUEE-TITLE | 4.3억 | 경기 1회 |
| 홈경기 중계 방송 배너 노출권 | SPN-BROADCAST-BANNER | 4억 | 1시즌 홈경기 전체 |
| 헬멧 로고 광고 | SPN-HELMET-LOGO | 3억 | 1년(정규시즌) |
| Gold 스타터 패키지 | SPN-PKG-GOLD | 2.61억 | 1년 |
| 외야 펜스 광고 | SPN-FENCE-OUTFIELD | 2.3억 | 1년(정규시즌) |
| 덕아웃/포수석 후면 광고보드 | SPN-BOARD-DUGOUT | 2억 | 1년(정규시즌) |
| Brand Day 단독 패키지 | SPN-BRANDDAY-SOLO | 1.6억 | 경기 1회 |
| 경품 증정 프로모션 데이 | SPN-PROMO-GIVEAWAY | 1.2억 | 경기 1회 |
| 공식 SNS 브랜디드 콘텐츠 | SPN-SNS-CONTENT | 1억 | 연 12회(월 1건) |
| 콜라보 굿즈 공동기획 | SPN-COLLAB-GOODS | 0.8억 | 시즌당 1회 |
| 공식 앱/홈페이지 배너 광고 | SPN-APP-BANNER | 0.6억 | 1년(상시 노출) |

### 티어별 패키지 구성
| 패키지 | 구성 상품 | 가격 |
| --- | --- | --- |
| Gold | 외야 펜스 광고 + 공식 앱/홈페이지 배너 광고 | 2.61억 |
| Platinum | 백네트 후면 LED 전광판 광고 + 공식 SNS 브랜디드 콘텐츠 + 경품 증정 프로모션 데이 + Brand Day 단독 패키지 | 12.42억 |
| Diamond | 공식 파트너 지위 인증권 + 업종 독점 스폰서십 권리 + 구장 내 특별 구역 명명권 | 52.2억 |

### 팀 검토가 필요한 이유
- "기본 계약 단위"(연/경기/다년)는 아직 Product2에 필드로 저장돼 있지 않고 이 문서에만 정리돼 있습니다 — Quote 작성 시 참고할 수 있게 필드화할지 팀 결정이 필요합니다.
- 가격 전체가 3차례에 걸쳐 크게 상향됐습니다(최초 0.2~5억 → 최종 0.6~52.2억) — 팀 최종 검토를 권장합니다.
- Diamond 패키지가 유니폼 메인 패치·SNS 콘텐츠를 제외한 이유(재고 1개뿐인 물리 자산은 반복 판매 가능한 등급 상품에 부적합)는 §18 본문 논의를 참고해주세요.

---

## 19. 기존 문서와의 관계

`P2_RESULT_REPORT/승우(Product, Quote, Campaign 구현).md`(2026-08-20 작성, 이미 커밋됨)는 이 문서의 내용을 반영하기 전 시점의 상태를 기록하고 있습니다 — 특히 Company Information과 Quote Status 필드는 그 문서 작성 시점에는 없었고 이번에 보완됐습니다. 두 문서를 통합할지, 이 문서를 보완 기록으로 별도 유지할지는 팀이 정합니다.

---

## 20. 다음 세션 To-Do

| 우선순위 | 작업 | 상태 |
| --- | --- | --- |
| ~~P1~~ | ~~Campaign_Deliverable__c의 4개 필드 조회 불가 문제 — Salesforce Support 케이스 오픈~~ | ✅ **완료(2026-08-25)** — 필드 삭제 후 재생성으로 해결, Support 케이스 불필요했음 |
| ~~P1~~ | ~~4개 필드에 실제 값(Due Date/Completed Date/Notes) 입력~~ | ✅ **완료(2026-08-25)** |
| P1 | `CampaignMember.Is_Converted__c`(전환율 계산용 Formula 필드) — 배포 성공(Tooling API 확인됨)했지만 재배포 이후에도 SOQL/Describe에서 계속 조회 불가. Campaign_Deliverable__c와 동일한 스키마 전파 지연 버그로 추정 — Setup UI에서 직접 삭제 후 재생성하는 방식으로 해결 시도 필요(§2 사례 참고) | **미해결** |
| P1 | Campaign_Deliverable__c / PRM_Revenue_Target__c(혜준 담당 추정) 유지 여부를 팀 Decision으로 확정 | 진행 전 |
| P1 | Budgeted Cost/Actual Cost 실제 값으로 교체 | 진행 전 |
| ~~P2~~ | ~~위 5개 Report를 `PRM Sponsorship Campaign Performance` Dashboard에 위젯으로 확정 반영~~ | ✅ **완료(2026-08-25)** — §11 참고, Report 형식(Tabular) 버그도 함께 해결 |
| ~~P2~~ | ~~Campaign.ExpectedRevenue를 Opportunity Amount와 자동 동기화~~ | ✅ **완료(2026-08-25)** — §13 참고, Flow 3종(Subflow + 생성/수정 + 삭제) 신설·테스트 완료 |
| ~~P2~~ | ~~Campaign Record Type을 Prospecting/Renewal로 확장하고 List View·Hierarchy 정비~~ | ✅ **완료(2026-08-26)** — §15~17 참고 |
| P2 | Campaign Record Type 확장(§15)을 정식 Decision(예: Decision 020)으로 기록하고 혜준님 확인 | 진행 전 |
| P2 | Sponsorship Product 21종 신설·3차 가격 조정(§18) 팀 최종 승인 | 진행 전 |
| P2 | "기본 계약 단위" 정보를 Product2 필드로 구조화할지 결정(§18) | 진행 전 |
| P2 | `Postal Code` 등 Company Information 나머지 값 보완 | 진행 전 |
| P2 | Quote Status의 `Rejected`/`Denied` 두 값을 §10.1 제안대로("내부 반려" vs "상대방 거절") 실제로 나눠 쓸지 팀 합의 | 진행 전 |
| P2 | Dashboard 이름을 `스폰서십 통합 현황판`으로 바꿀지 팀 확인(§11) | 진행 전 |
| P3 | §13에서 발견한 한계 — Opportunity의 Campaign이 재연결(A→B)될 때 예전 Campaign(A) 합계가 갱신 안 되는 문제 보완 | 진행 전 |
| P3 | Opportunity.CampaignId(Primary Campaign Source) 입력을 영업 프로세스에 정착 — Campaign Hierarchy Rollup이 d'Alba 외 회사에서도 실질적으로 작동하려면 필요(§17) | 진행 전 |
| P3 | 새로 만든 Sponsorship Prospecting 캠페인 4건(2026 Q4 스폰서십 데이 외)에 Campaign Member Status 퍼널 세팅 — 첫 캠페인 1건만 완료됨(§15) | 진행 전 |

---

## 21. GitHub 반영 제안

권장 경로:

```text
P2_RESULT_REPORT/B2B_CAMPAIGN_QUOTE_UNDOCUMENTED_IMPLEMENTATION.md
```

권장 Commit Message:

```text
docs: log Campaign record type expansion and sponsorship product repricing
```

권장 브랜치: `feature/campaign-quote-undocumented-log` → PR to `dev`(`02_TEAM_GUIDE.md` §4 Phase 2 브랜치 전략).

이 문서는 실제 Org 상태를 기준으로 작성했습니다. 팀 검토 후 Decision이 나면, 해당 Decision 번호를 이 문서 각 섹션에 역참조로 추가하고 `05_DECISIONS.md`/`03_SYSTEM.md`에도 반영해야 합니다.

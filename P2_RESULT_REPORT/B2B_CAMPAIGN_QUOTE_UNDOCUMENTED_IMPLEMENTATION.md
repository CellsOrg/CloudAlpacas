# P2 Campaign · Quote 고도화 — 미기록 구현 정리

> 승우(Product/Quote/Campaign) 파트에서 2026-08-20 이후 Production Org에 실제로 반영했지만, `03_SYSTEM.md`/`05_DECISIONS.md` 등 공식 문서(Source of Truth)에는 아직 기록되지 않은 항목을 정리한 문서입니다. `CLAUDE.md` §7("프로젝트 전체에 영향을 주는 변경은 반드시 Decision으로 기록한다")을 뒤늦게라도 충족하기 위한 체크포인트입니다.

| 항목 | 내용 |
| --- | --- |
| 작성자 | 승우(Rafael) |
| 기준일 | 2026-08-25 |
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
| 필드 7개 중 3개 (`Status__c`, `Weight__c`, `Campaign__c`) | **정상 — SOQL/UI 모두 조회 가능** |
| 필드 7개 중 4개 (`Due_Date__c`, `Completed_Date__c`, `Evidence_URL__c`, `Notes__c`) | **비정상 — 2026-08-20 배포 이후 5일이 지난 지금(2026-08-25)도 SOQL/describe에서 계속 "존재하지 않는 필드"로 조회 실패.** Tooling API로는 메타데이터 존재가 확인되나, 쿼리 엔진/Lightning 렌더링에는 반영되지 않음. 재배포로 해결되는 문제가 아니며 **Salesforce Support 케이스가 필요**합니다. |
| 실데이터 | `d'Alba Sponsorship Campaign`에 4건(Completed 2건/In Progress 1건/Not Started 1건, 가중치 합 100%) |
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

## 9. 기존 문서와의 관계

`P2_RESULT_REPORT/승우(Product, Quote, Campaign 구현).md`(2026-08-20 작성, 이미 커밋됨)는 이 문서의 내용을 반영하기 전 시점의 상태를 기록하고 있습니다 — 특히 Company Information과 Quote Status 필드는 그 문서 작성 시점에는 없었고 이번에 보완됐습니다. 두 문서를 통합할지, 이 문서를 보완 기록으로 별도 유지할지는 팀이 정합니다.

---

## 10. 다음 세션 To-Do

| 우선순위 | 작업 |
| --- | --- |
| P1 | Campaign_Deliverable__c의 4개 필드 조회 불가 문제 — Salesforce Support 케이스 오픈 |
| P1 | Campaign_Deliverable__c / PRM_Revenue_Target__c(혜준 담당 추정) 유지 여부를 팀 Decision으로 확정 |
| P1 | Budgeted Cost/Actual Cost 실제 값으로 교체 |
| P2 | 위 5개 Report를 `PRM Sponsorship Campaign Performance` Dashboard에 위젯으로 확정 반영(Dashboard REST API가 막혀 있어 UI 작업 필요) |
| P2 | `Postal Code` 등 Company Information 나머지 값 보완 |

---

## 11. GitHub 반영 제안

권장 경로:

```text
P2_RESULT_REPORT/B2B_CAMPAIGN_QUOTE_UNDOCUMENTED_IMPLEMENTATION.md
```

권장 Commit Message:

```text
docs: log undocumented Campaign/Quote P2 builds since 2026-08-20
```

권장 브랜치: `feature/campaign-quote-undocumented-log` → PR to `dev`(`02_TEAM_GUIDE.md` §4 Phase 2 브랜치 전략).

이 문서는 실제 Org 상태를 기준으로 작성했습니다. 팀 검토 후 Decision이 나면, 해당 Decision 번호를 이 문서 각 섹션에 역참조로 추가하고 `05_DECISIONS.md`/`03_SYSTEM.md`에도 반영해야 합니다.

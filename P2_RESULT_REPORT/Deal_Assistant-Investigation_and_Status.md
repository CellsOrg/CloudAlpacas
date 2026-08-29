# Deal Assistant — 조사 결과 + 독립 구현 현황

> 브랜치: `feature/opportunity-deal-assistant` (origin/main = `ec12eff` 기준, PR #86과 sibling)
> 작성: 2026-08-29 / 상태: **DealContext read 계층 + test 독립 완료. Agent integration은 #86 merge 이후.**

---

## 1. Deal Assistant란 무엇인가 (조사 결론)

현재 main `Opportunity_Agent.agent`가 명시적으로 "not available yet"로 미뤄둔 능력:

> "whether the deal is healthy or at risk, why it is stalled, the likelihood of closing,
> what the rep should do next, sales strategy" — **Deal Intelligence**

Deal Assistant = 이 **내부 데이터 기반 Opportunity-level 판단** 계층.
(외부 기업 공시/재무 = **Company Intelligence / DART API**는 별개, 은영님 담당 —
`Negotiation_Assistant-AgentSpec.md §146` 참고.)

**Deal Assistant는 다른 subagent의 업무를 수행하지 않는다.** Activity를 만들지 않고,
Quote/Negotiation term을 바꾸지 않고, Proposal을 생성하지 않고, 원문 activity를 다시
분석하지 않는다. 이미 **Flow가 유지하는 Opportunity 지표**와 **II가 생성한 신뢰 가능한
interaction signal**을 READ해서 Opportunity 전체 상태를 종합한다.

---

## 2. 권장 Architecture: **B — sibling analytical subagent**

```
Opportunity Agent
├── activity_management   (Activity / Interaction Intelligence / Conversation History)
├── negotiation
├── proposal              (PR #86, groundwork)
└── deal                  ← Deal Assistant (sibling, READ-ONLY 판단 계층)
```

| 비교축 | A: meta-agent (Deal이 다른 subagent 총괄) | B: sibling subagent |
|---|---|---|
| Agentforce 지원 | subagent가 subagent를 호출하는 패턴은 현재 `.agent` DSL에 없음. router transition은 단방향 | ✅ 기존 5개 subagent와 동일 패턴 |
| 현재 `.agent` 적합성 | 라우터 재설계 필요 | ✅ subagent 블록 추가만 |
| deterministic chaining | Deal→Activity→Deal 왕복에서 state 오염·재귀 위험 | ✅ `find_opportunity` → `resolved_opportunity_id` → `get_deal_context` 단선 |
| circular routing | ⚠️ Deal↔Negotiation↔Deal 루프 가능 | ✅ 없음 |
| duplicated reasoning | Deal이 II/Negotiation 결과를 재해석 → 이중 판단 | READ만 하므로 최소 |
| testability | agent 통합 없이 검증 불가 | ✅ `DealContext` Apex 단독 test 가능 (실제로 완료) |
| Proposal #86 결합도 | 높음 (총괄하려면 Proposal 완성 필요) | ✅ 낮음 — Proposal signal은 optional |

→ **B 채택.** meta-agent는 Agentforce 구조상 무리이고, 판단 계층은 "총괄"이 아니라
"여러 source를 READ해서 synthesis"이므로 sibling이 자연스럽다.

---

## 3. Assistant Responsibility Matrix

| Capability | Activity | Interaction Intelligence | Conversation History | Negotiation | Proposal (#86) | **Deal Assistant** | 겹침 |
|---|---|---|---|---|---|---|---|
| activity 조회 | ✅ query_activities | | | | | ❌ | — |
| activity 생성/수정 | ✅ (confirm 후) | | | | | ❌ (Activity Assistant로 라우팅) | — |
| interaction 요약 | | ✅ get_interaction_intelligence | | | | ❌ | — |
| conversation chronology | | | ✅ get_conversation_history | | | ❌ | — |
| quote 조회 (상세) | | | | ✅ get_negotiation_context | | ❌ 존재/상태/개수만 | 부분 (상태만, 목적 다름) |
| discount approval limit | | | | ✅ | | ❌ | — |
| negotiation term 변경 | | | | ✅ (confirm 후) | | ❌ | — |
| proposal context | | | | | ✅ (#86, read) | ❌ | — |
| sponsorship package | | | | | ⏸ (#86 보류) | ❌ | — |
| Quote 생성 | | | | ❌ | ⏸ (#86 보류) | ❌ | — |
| **stage / amount / close date** | | | | 일부 | | ✅ **snapshot** | 최소 |
| **deal age / days open / days to close** | | | | | | ✅ **derived** | 없음 (신규) |
| **days since last stage change** | | | | | | ✅ **derived** | 없음 (신규) |
| **contact cadence (last contact, days since)** | 간접 (activity) | | 간접 | | | ✅ **Flow 필드 read** | 없음 |
| **open / overdue task count** | 간접 (query) | | | | | ✅ **Flow 필드 read** | 없음 |
| **interaction signal 집계** | | 개별 표시 | | | | ✅ **카운트 집계** | 최소 (개별 vs 집계) |
| **quote/proposal presence 종합** | | | | | | ✅ **read** | 없음 |
| deal risk / health / stalled reason / win likelihood | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ **LLM 판단 계층 (Apex는 fact만 제공)** | — |
| next best action / recommended sales action | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ **LLM 판단 계층** | — |

**결론**: Deal Assistant는 기존 기능을 복제하지 않는다. 신규 가치는 (a) 시간 기반 파생 지표,
(b) Flow가 이미 계산해둔 cadence/task 지표의 opportunity-level 노출, (c) interaction signal
집계, (d) 이 위에서의 LLM synthesis.

---

## 4. Source-of-Truth Map

`A` = Salesforce 저장 사실 · `B` = threshold-free 파생(공식 명시) · `C` = LLM 판단(Apex에 없음)

| Signal | Object.Field | A/B/C | Read source | Deterministic | 현재 권한 |
|---|---|---|---|---|---|
| stage | Opportunity.StageName | A | SOQL | — | 표준(있음) |
| closed / won | Opportunity.IsClosed / IsWon | A | SOQL | — | 표준 |
| amount | Opportunity.Amount | A | SOQL | — | ⚠️ FLS 확인 필요 |
| probability | Opportunity.Probability | A (stage-linked/manual, **AI 아님**) | SOQL | — | ⚠️ FLS 확인 필요 |
| forecast category | Opportunity.ForecastCategoryName | A (stage-derived) | SOQL | — | 표준 |
| close date | Opportunity.CloseDate | A | SOQL | — | 표준 |
| created date | Opportunity.CreatedDate | A | SOQL | — | 표준 |
| last stage change | Opportunity.LastStageChangeDate | A (platform, nullable) | SOQL | — | 표준 |
| last activity date | Opportunity.LastActivityDate | A (platform rollup) | SOQL | — | 표준 |
| next step | Opportunity.NextStep | A (rep free text) | SOQL | — | 표준 |
| last contact date/type | Opportunity.Last_Contact_Date__c / Last_Contact_Type__c | A (Flow: CA_Update_Opportunity_Last_Contact_From_*) | SOQL | — | Date 있음 / **Type 없음** |
| days since last contact | Opportunity.Days_Since_Last_Contact__c | B (플랫폼 formula `FLOOR(NOW()-Last_Contact_Date__c)`; null/음수 가능) | SOQL | ✅ (플랫폼) | **없음** |
| next activity | Opportunity.Next_Activity_Date__c / Next_Activity_Subject__c | A (Flow: CA_Update_Opportunity_Next_Activity) | SOQL | — | **없음** |
| open / overdue task count | Opportunity.Open_Tasks_Count__c / Overdue_Tasks_Count__c | A (같은 Flow) | SOQL | — | Open 있음 / **Overdue 없음** |
| decision maker access | Opportunity.Decision_Maker_Accessible__c | A (rep 입력 picklist) | SOQL | — | 있음 |
| brand/fan fit | Opportunity.Brand_Fan_Fit__c | A | SOQL | — | 있음 |
| interest level | Opportunity.Sponsorship_Interest_Level__c | A | SOQL | — | 있음 |
| expected timing | Opportunity.Expected_Timing__c | A | SOQL | — | **없음** |
| client budget status | Opportunity.Client_Budget_Status__c | A | SOQL | — | 있음 (R+E) |
| partner tier | Opportunity.Partner_Tier__c | A (rep 참고 신호) | SOQL | — | 있음 |
| deal note | Opportunity.Deal_Note__c | A (rep free text) | SOQL | — | **없음** |
| reason lost | Opportunity.SDO_Sales_Reason_Lost__c | A (Closed Lost에만 의미) | SOQL | — | **없음** |
| primary contact | Opportunity.SDO_Sales_Primary_Contact__r.Name | A | SOQL | — | 있음 (lookup R) |
| quote presence / count | Quote (OpportunityId) | A + B(count) | SOQL | ✅ | Quote R 있음 |
| synced quote status | Quote where Id = Opportunity.SyncedQuoteId | A | SOQL | — | Quote R 있음 |
| latest quote status | Quote ORDER BY CreatedDate DESC LIMIT 1 | A (라벨: "최근 생성", authoritative 아님) | SOQL | ✅ | Quote R 있음 |
| interaction count / latest date | Interaction_Intelligence__c (Opportunity__c) | A + B(count) | SOQL | ✅ | II R 있음 |
| latest concerns/objections | 최근 II.Concerns_Objections__c | A (verbatim 인용) | SOQL | — | 있음 |
| signal counts (총/Negative/Positive/RISK/COMPETITION/MOMENTUM-Neg) | Interaction_Signal__c (Category/Direction) | B (deterministic count, **점수 아님**) | SOQL | ✅ | II object R + Category/Direction은 required field라 암묵 read |
| **days open** | 파생 `today - CreatedDate` | B | 계산 | ✅ | — |
| **days until close** | 파생 `CloseDate - today` (음수 = 지남) | B | 계산 | ✅ | — |
| **close date is past** | 파생 `CloseDate < today && !IsClosed` | B (단순 날짜 비교, 위험 판단 아님) | 계산 | ✅ | — |
| **days since last stage change** | 파생 `today - LastStageChangeDate` (null 허용) | B (정체 여부 판단 아님) | 계산 | ✅ | — |
| **days since last activity** | 파생 `today - LastActivityDate` (null 허용) | B | 계산 | ✅ | — |
| **days since latest interaction** | 파생 `today - 최근 II.CreatedDate` (null 허용) | B | 계산 | ✅ | — |
| deal health / risk level / grade | — | **C (Apex에 없음)** | — | ❌ | — |
| win probability (AI/ML) | — | **C — 존재하지 않음. Apex 생성 금지** | — | ❌ | — |
| isStalled / stalledReason | — | **C + business policy 미정** | — | ❌ | — |
| recommended next action | — | **C (Apex에 없음)** | — | ❌ | — |

---

## 5. Deal Health / Risk / Win Probability — 조사 결과

org describe(Opportunity) 결과:
- `Opportunity.Probability` — `updateable=True`, `calculated=False`. **stage-linked 또는 수동 편집 필드.** 데모 데이터: Qualification 20 / Discovery 35 / Proposal 75 — stage와 대략 연동되나 사람이 바꿀 수 있음. **"AI win probability"라 부르면 안 되는 이유**: ML 모델도, Einstein 점수도 아니고, 그냥 저장된 percent 필드.
- **Einstein Opportunity Scoring 없음.** health/risk/engagement/propensity score 필드 **없음** (org 전체 field describe로 확인).
- 유일한 "예측성" 필드: `ED_Predicted_Close_Date__c` (calc=True formula, repo에 없는 org-only SDO 데모 필드) — 무관, 사용 안 함.

→ **DealContext는 임의의 `%`를 생성하지 않는다.** `Opportunity.Probability`를 "저장된 값,
AI 예측 아님" 라벨과 함께 그대로 전달만 한다. health/risk/win 점수는 반환하지 않는다
(`DealContextTest.testNoJudgementFieldsExist`가 이를 강제).

---

## 6. Stalled Deal — deterministic 정의 가능한가?

**불가능 (business policy 필요).** repo/docs/org metadata에서 deal 정체 임계값을 찾지 못함:
- `docs/`에 deal health/risk/stalled 규칙 **없음** (Fan의 "365일 = Churned"는 다른 도메인)
- `SDO_Slack_Send_Slack_Notifications_for_*` flow들은 범용 SDO 데모 스캐폴딩 — 우리 정책 아님
- `Interaction_Signal__c`에 `MOMENTUM`/`RISK`/`Stalled`(Signal_Type) 카테고리가 있으나,
  이는 **interaction 단위 관찰**이지 opportunity-level "정체" 판정 규칙이 아님

→ DealContext는 **정체 판단에 쓸 재료**(`daysSinceLastStageChange`, `daysSinceLastContactField`,
`overdueTaskCount`, `momentumNegativeCount`, `closeDateIsPast`)를 threshold 없이 raw로 제공.
"며칠이면 정체"는 **비즈니스 결정**으로 남긴다 (§9).

---

## 7. Interaction Intelligence 관계

`InteractionIntelligenceParser` + `CA_Generate_Meeting_Interaction_Intelligence` flow가
interaction 하나당 `Interaction_Intelligence__c` 1건 + `Interaction_Signal__c` N건을 생성:
- II 필드: Summary, Customer_Reaction, Key_Decision, Concerns_Objections, Follow_Up
- Signal: Category(INTEREST/BUDGET/DECISION/FIT/COMPETITION/TIMING/MOMENTUM/RISK) · Direction(Positive/Negative/Neutral) · Confidence · Evidence

**II는 interaction-level이고, opportunity-level rollup·risk score·next action을 만들지 않는다.**

→ 권장 데이터 흐름 (실제 코드와 일치 확인):
```
Raw Task/Event/Email
  → CA_Generate_Meeting_Interaction_Intelligence (LLM)
  → InteractionIntelligenceParser
  → Interaction_Intelligence__c + Interaction_Signal__c   (interaction-level, 신뢰 가능)
  → DealContext (집계: 카운트, 최근 concerns)              ← 여기
  → Deal Assistant .agent (LLM synthesis, 근거 노출)       ← #86 이후
```

Deal Assistant는 **원문 activity를 다시 분석하지 않는다.** II가 만든 signal을 source로 재사용한다.

---

## 8. Proposal / Negotiation 관계

Deal Assistant가 **하면 안 되는 것**: Proposal 생성, Quote 수정, Negotiation term 수정,
discount 추천/변경. (전부 다른 subagent 소관.)

Deal Assistant가 **READ해도 되는 것** (DealContext가 실제로 반환):
- Quote 존재 여부 / 개수 / synced quote status / 최근 quote status
- Interaction Intelligence 존재 여부 / 개수 / 최근 concerns

**#86 의존성**: DealContext는 `OpportunityProposalContext` / proposal Apex를 참조하지 않는다.
Proposal 관련 Opportunity 필드(`Target_Segment__c`, `Expected_Benefit_*`)도 이번엔 읽지 않음
(qualification/discovery 필드만). → **#86과 파일 충돌 0, 코드 의존 0.**

---

## 9. Quote Authority Problem

| 질문 | 조사 결과 |
|---|---|
| Opportunity에 Quote 여러 개면? | 데모는 각 1건이나 코드상 여러 개 가능 |
| `SyncedQuoteId` 의미 | Salesforce가 Opportunity의 amount/line에 대해 **자체적으로 authoritative로 취급**하는 Quote |
| authoritative Quote 규칙 있나? | repo/org에 명시 규칙 **없음** — `NegotiationContext`는 "가장 최근 CreatedDate", `stageProgress` LWC는 `SyncedQuoteId` 사용 (불일치) |
| Primary Quote 개념 | 표준/커스텀 모두 **없음** |

→ **DealContext의 처리**: authoritative 하나를 고르지 **않는다.** `quoteCount`(전체) +
`hasSyncedQuote`/`syncedQuoteStatus`(Salesforce 지정) + `latestQuoteStatus`(라벨: "최근 생성",
authoritative 아님)를 **모두 나열**만 한다. "이 딜의 기준 Quote는 무엇인가"는
**Proposal Existing Quote 정책(승우님 답변 대기)과 연결된 비즈니스 결정** — §16.

---

## 10. 구현한 것: `DealContext` (read-only Apex) + test

### Request
| field | type | required |
|---|---|---|
| `opportunityId` | Id | Yes |

### Result (요약 — 상세는 클래스 `@InvocableVariable` 참고)
- **A 저장 사실 (~30)**: opportunityName, accountName, stageName, isClosed, isWon, amount, probability, forecastCategory, closeDate, createdDate, lastStageChangeDate, lastActivityDate, nextStep, lastContactDate/Type, daysSinceLastContactField, nextActivityDate/Subject, openTaskCount, overdueTaskCount, decisionMakerAccessible, brandFanFit, interestLevel, expectedTiming, clientBudgetStatus, partnerTier, dealNote, reasonLost, hasPrimaryContact, primaryContactName, quoteCount, hasSyncedQuote, syncedQuoteStatus, latestQuoteStatus, latestQuoteCreatedDate, hasInteractionIntelligence, interactionCount, latestInteractionDate, latestConcernsObjections, signalCount, negativeSignalCount, positiveSignalCount, riskCategoryCount, competitionCategoryCount, momentumNegativeCount, signalCategoryBreakdown
- **B 파생 (6)**: daysOpen, daysUntilClose, closeDateIsPast, daysSinceLastStageChange, daysSinceLastActivity, daysSinceLatestInteraction — 전부 `Date.today()` 기준 `daysBetween`, threshold 없음
- **없음**: healthScore, riskLevel/riskScore, winProbability, isStalled/stalledReason, recommendedAction/nextBestAction, grade

### Security
`with sharing` · 모든 SOQL 4개 `WITH USER_MODE` · **DML 0** (`testBulkRequests`가 강제)
· bulkified (요청 100건에 SOQL ≤ 5)

### Tests — `DealContextTest`, 12 methods, **DealContext 100% coverage**
exact opp / bare opp(계약·활동·II 없음) / 존재하지 않는 opp(found=false) / 파생 날짜 계산
/ close date past / multiple quotes(synced vs latest) / interaction signal 집계 /
LastActivityDate 롤업 / days since stage change / bulk 100건(DML 0, SOQL 소수) /
apostrophe 이름 / **judgement 필드 부재 guardrail**

### 회귀
기존 regression 76건 + DealContextTest 12건 → **88/88 PASS** (Activity Intelligence /
Conversation History / Negotiation / Opportunity resolver 무영향).

---

## 11. Security / Permissions — 필요 diff (이번 branch에서 적용 안 함)

`CA_Opportunity_Agent_Access`에 **additive read-only** 필요 (shared file이라 §12·§17에 따라
이번 branch 미수정 — #86 merge 후 최신 main 위에서 병합):

```
# classAccesses
+ DealContext

# fieldPermissions (전부 readable=true, editable=false)
+ Opportunity.Last_Contact_Type__c
+ Opportunity.Days_Since_Last_Contact__c
+ Opportunity.Next_Activity_Date__c
+ Opportunity.Next_Activity_Subject__c
+ Opportunity.Overdue_Tasks_Count__c
+ Opportunity.Expected_Timing__c
+ Opportunity.Deal_Note__c
+ Opportunity.SDO_Sales_Reason_Lost__c
+ Opportunity.Amount        (표준 — 프로필 baseline에 없으면 추가)
+ Opportunity.Probability   (표준 — 프로필 baseline에 없으면 추가)
```

- **새 object permission 0** (Opportunity/Quote/II/Signal read는 이미 있음)
- **broad permission 0** (Modify All / View All / ViewAllData / ModifyAllData 없음)
- `Interaction_Signal__c.Signal_Category__c` / `Direction__c`는 required field라 object read만으로 읽힘
- `WITH USER_MODE` SOQL은 FLS 없는 필드에서 예외를 던지므로, 위 FLS 없이는 비-admin
  실행 시 실패 (admin은 무관) — 그래서 `testRunsUnderAgentAccessUser`는 FLS 병합 후 추가 예정

---

## 12. #86-independent 완료 / #86 이후 / 비즈니스 결정

### 지금 안전하게 완료
- `DealContext.cls` + `DealContextTest.cls` (100% cov), origin/main 위 독립 구현
- 회귀 88/88
- architecture 결정(B), source-of-truth map, responsibility matrix

### #86 merge 이후
- `Opportunity_Agent.agent`에 `deal` subagent 추가 (`find_opportunity` → `resolved_opportunity_id`
  → `get_deal_context` 결정적 바인딩, router `go_to_deal`, LLM synthesis instruction —
  FACT / INTERPRETATION / SUGGESTED ACTION 3단 분리)
- `CA_Opportunity_Agent_Access` §11 FLS 병합
- `testRunsUnderAgentAccessUser` 추가
- staged agent version publish (activate 안 함)

### 비즈니스 결정 필요 (사람)
1. **"정체(stalled)" 임계값** — daysSinceLastStageChange / daysSinceLastContact / overdueTaskCount 몇이면 flag? (§6)
2. **authoritative Quote 규칙** — SyncedQuoteId 우선? 최근? Proposal Existing Quote 정책(#86, 승우님)과 함께 결정 (§9)
3. **Deal Assistant가 next action을 "추천"할 때 범위** — 순수 제안(텍스트)만인지, Activity Assistant로 라우팅해 Task 생성까지 유도인지
4. **Deal Intelligence를 CLAUDE.md §5 Agentforce 예외로 명문화**할지 (현재 Decision 017/022에 명시 없음 — 022는 f762840에만 있고 main 미반영)

---

## 13. 하지 않은 것

- `Opportunity_Agent.agent` 수정 ❌
- `CA_Opportunity_Agent_Access` 수정 ❌ (필요 diff만 §11에 기록)
- agent publish / activate ❌
- PR #86 / proposal branch / 다른 worktree / stash 수정 ❌
- business data 생성/수정/삭제 ❌
- 임의 deal score / win probability / risk threshold ❌
- Data 360 / Einstein 활성화 ❌

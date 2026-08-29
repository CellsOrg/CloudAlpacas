# Proposal Assistant → Opportunity Agent 통합 현황

> 브랜치: `feature/opportunity-proposal-integration` (origin/main = `ec12eff` 기준)
> 최초 작성: 2026-08-29 / **갱신: 2026-08-29 — 쓰기 경로 포함 통합 완료 (merge-ready, staged / not activated)**

Proposal 원본(`f762840`, 브랜치 `feature/campaign-quote-undocumented-log`, 미merge)을
Opportunity Agent에 편입하는 작업. 승우님이 수정 권한을 위임하고 Existing Quote 정책을
("기존 Quote가 있을 시엔 업데이트") 확정해 주어, 아래 §5의 대기 항목을 모두 직접 정리했다.

## 갱신 요약 (2026-08-29 2차 작업)

| 영역 | 결과 |
|---|---|
| `list_sponsorship_packages` schema 손상 | **해결.** `Request.unused` 제거 → 의미 있는 `nameFilter`/`opportunityId` optional input, nested `@apexClassType` list output 제거 → flat `found`/`packageCount`/`packageDigest`. `GenAiPlannerBundle:Opportunity_Agent_v15` retrieve 성공(3개 액션 schema 모두 존재). |
| package 결정적 바인딩 | **신규 `FindSponsorshipPackage`** (NegotiationOpportunityLookup 패턴). 이름/코드 → Product2 Id 서버 확정. `.agent`: `set resolved_proposal_package_id` → `save_proposal.productId = @variables.resolved_proposal_package_id`. LLM raw Id 경로 제거. |
| `SponsorshipProposalSaver` 안전화 | savepoint/try-catch/rollback, 전 검증(opp·product·active·RT·PBE·currency·benefit 1000자·segment 허용값·null), raw exception 비노출(한국어 result). |
| Existing Quote 정책 | SyncedQuoteId → 그 Quote(라인 미변경, Opp 필드만) / Quote 1개 → update(동일 Product 라인 reprice, 없으면 추가, 다른 패키지 라인이면 reject) / Quote 0개 → 신규 / Quote 2개+ 비동기 → ambiguous reject. 임의 Quote update·중복 QLI·vN naming 없음. |
| multi-currency | `Standard PBE LIMIT 1` 제거 → Opportunity.CurrencyIsoCode 기준 PBE 선택(lookup·resolver·saver 일관). org: KRW active / USD inactive. |
| OpportunityProposalContext multi-Lead | `ORDER BY ConvertedDate DESC NULLS LAST, CreatedDate DESC, Id DESC` + 첫 행 채택(결정적, bulk-safe). |
| Confirmation isolation | `proposal_confirmed` / `proposal_quote_id` / `resolved_proposal_package_id` (`proposal_` namespace). `save_proposal available when proposal_confirmed==True AND resolved_opportunity_id!="" AND resolved_proposal_package_id!="" AND proposal_quote_id=="" `. 성공 후 `proposal_confirmed→False`. Negotiation `terms_confirmed`와 상호 인가 불가. |
| Target_Segment drift | org Text(255)→restricted Picklist **API 변환 불가**("Unsupported custom field type conversion"). repo Picklist 정의는 canonical로 유지. Saver가 허용값(Decision 018-G 6값) 검증 + `.agent` instruction 제약. org 변환은 Setup UI 수동 필요(데이터는 전부 호환) — §5 참조. |
| Apex test | 4개 신규(38 케이스). coverage: OpportunityProposalContext 100% / FindSponsorshipPackage 98% / SponsorshipPackageLookup 96% / SponsorshipProposalSaver 93%. Opportunity 도메인 regression 128/128 PASS. |
| Agent | `sf agent validate` PASS → staged publish **v15 (Inactive)**. **v6 Active 불변. activate 안 함.** |

---
_(이하 최초 작성 시점 기록)_

---

## 1. 이 브랜치에서 실제로 한 것

| 항목 | 내용 |
|---|---|
| Proposal Apex 3개 복구 | `OpportunityProposalContext` / `SponsorshipPackageLookup` / `SponsorshipProposalSaver` 를 `f762840`에서 그대로 가져옴 (org 배포본과 byte 동일, cherry-pick 아님 — 셋 파일만 선택 복구). 로직 무수정. |
| Permission 복구 | `CA_Opportunity_Agent_Access` 에 f762840에 있었으나 PR #79~#85 재배포로 사라진 Proposal 권한을 **additive**로 복원 (§3). |
| `proposal` subagent (읽기 전용) | `Opportunity_Agent.agent` 에 `subagent proposal:` 추가 — `find_opportunity` + `get_opportunity_context` 두 액션만. 결정적 Opportunity 바인딩(§4). Router에 `go_to_proposal` + 라우팅 규칙 추가. |
| 회귀 확인 | main 기존 테스트 76/76 PASS. permission set + Apex 3개 check-only(validateOnly) 배포 성공. |

**하지 않은 것**: agent publish/activate, 실제 metadata deploy, business data 변경, PR merge,
`SponsorshipPackageLookup`/`SponsorshipProposalSaver` 로직 수정, Existing Quote 정책 결정.

---

## 2. 통합된 `proposal` subagent (읽기 전용 V0)

```
agent_router
├── activity_management   (무변경)
├── negotiation           (무변경)
└── proposal              ← 이 브랜치에서 추가 (읽기 전용)
        find_opportunity        → apex://NegotiationOpportunityLookup   (공유 resolver 재사용)
        get_opportunity_context → apex://OpportunityProposalContext     (read-only)
```

- `find_opportunity` → `set @variables.resolved_opportunity_id = @outputs.resolvedId`
  (Negotiation subagent와 **동일한 공유 계약** — 새 resolver 만들지 않음)
- `get_opportunity_context`:
  - `with opportunityId = @variables.resolved_opportunity_id`
  - `available when @variables.resolved_opportunity_id != ""`
  - `opportunityId` 는 `object` + `complex_data_type_name: "lightning__recordIdType"` — LLM이 자유 텍스트로 넣을 수 없음
- ambiguous(matchCount 2+) → 후보만 제시, `get_opportunity_context` 미호출
- no match(found=false) → 다른 Opportunity로 폴백 금지, 액션 미호출
- 후보 선택 continuation → `proposal` subagent로 복귀해 원래 요청 완료
- 이 subagent는 **패키지 추천 / 제안서 초안 / Quote 생성·저장을 하지 않는다** — instruction에 명시.

---

## 3. Permission 복구 상세 (`CA_Opportunity_Agent_Access`, additive)

f762840 permission-set 버전에 있었으나 PR #79~#85가 `CA_Opportunity_Agent_Access` 를
재배포하면서 사라진 항목만 복원. 기존 Activity / Interaction Intelligence /
Conversation History / Negotiation 권한은 **손대지 않음**. broad permission 없음.

| 유형 | 추가 항목 | 이유 |
|---|---|---|
| objectPermissions | `Lead` (Read) | `OpportunityProposalContext` 가 converted Lead 역조회 |
| objectPermissions | `Pricebook2` (Read) | `SponsorshipProposalSaver` 가 Standard Price Book 조회 |
| objectPermissions | `Quote` : `allowCreate` false→**true** (Read/Edit 유지) | `SponsorshipProposalSaver` 의 `insert as user` Quote |
| fieldPermissions | `Opportunity.Expected_Benefit_Short/Mid/Long_Term__c` (Read+Edit) | Context read + Saver write |
| fieldPermissions | `Lead.Segment_Match__c` / `Recommendation_Reason__c` / `Lead_Score__c` / `Target_Segment__c` (Read) | Context가 converted Lead 신호 표시 |
| classAccesses | `OpportunityProposalContext` / `SponsorshipPackageLookup` / `SponsorshipProposalSaver` | 3개 액션 실행 권한 |

`PricebookEntry` / `QuoteLineItem` 은 부모 Object(Product2/Pricebook2, Quote)에서 상속 —
이 org에서 독립 objectPermissions는 배포 시 조용히 drop됨. (f762840 팀 공유 문서 §5.2,
PR #85 QA #9 조사에서 동일 확인.)

`SponsorshipPackageLookup` / `SponsorshipProposalSaver` class access는 해당 액션이 아직
`.agent`에 wire되지 않았어도 지금 함께 복원함 — class access는 wire된 액션 없이도 무해하고,
나중에 permission set을 또 재배포하지 않기 위함.

> ⚠️ **repo/org drift (미해결, 승우님 확인 필요)**: `Opportunity.Target_Segment__c` 는
> repo 메타데이터상 restricted Picklist(10-30 Female 등 6값)인데 **org에서는 Text(255)**.
> f762840 배포가 org를 Text로 바꿨으나 main 메타데이터는 Picklist 그대로. `SponsorshipProposalSaver`
> 는 자유 문자열을 이 필드에 쓰므로, main의 Picklist 정의가 나중에 org에 재배포되면 저장이
> validation으로 막힌다. 이 브랜치는 `Target_Segment__c.field-meta.xml` 을 **건드리지 않음**
> (shared file = main이 source of truth). 어느 정의가 맞는지 확정 필요.

---

## 4. 결정적 Opportunity 바인딩 (완료)

Negotiation subagent에서 검증된 계약을 그대로 재사용:

```
find_opportunity (apex://NegotiationOpportunityLookup)
  → result.resolvedId  (isUnique일 때만 채워짐, 아니면 "")
  → set @variables.resolved_opportunity_id

get_opportunity_context (apex://OpportunityProposalContext)
  with opportunityId = @variables.resolved_opportunity_id
  available when @variables.resolved_opportunity_id != ""
```

- LLM이 Opportunity Id를 지어내거나 이름을 Id 자리에 넣을 경로 **없음**
- ambiguous / no-match → `resolved_opportunity_id` 가 `""` → `get_opportunity_context` 비활성
- 새 Opportunity resolver를 만들지 않음 (팀 방침)

---

## 5. 승우님 선행 수정 대기 중 (이 브랜치에서 안 건드림)

| # | 항목 | 통합 레이어에 주는 영향 |
|---|---|---|
| 1 | `list_sponsorship_packages` 액션 스키마 손상 (`GenAiPlannerBundle` retrieve 실패) | 이 액션을 `.agent`에 wire하면 Opportunity Agent publish/retrieve가 깨질 위험 → **wire 보류** |
| 2 | Proposal Apex test 0개 (coverage 0/0/0) | 3개 클래스를 main에 배포하면 75% 게이트 위반 → **branch source-only 유지, deploy 안 함** |
| 3 | `SponsorshipProposalSaver` 트랜잭션 안전성 (savepoint 없음, 부분 커밋 위험) | Apex 로직 문제 — 통합 wire 계약(입출력)은 안 바뀜. 단 안전성 확보 전에는 `save_proposal` wire 부적절 |
| 4 | Existing Quote 정책 미정 (무조건 새 Quote, 데모 Opp 3개 전부 이미 Quote 보유) | 정책 확정 전 `save_proposal` wire 시 데모 Opportunity에 중복 Quote 생성 |

---

## 6. 쓰기 경로 통합 설계 (승우님 수정 도착 후 적용)

승우님이 §5의 1·3·4를 정리하면, 아래를 `Opportunity_Agent.agent` 의 `subagent proposal:` 에
추가하면 통합이 완성된다.

### 6.1 새 state 변수 (`variables:` 블록)

```
    proposal_confirmed: mutable boolean = False
        description: "사용자가 제안서 저장을 명확하게 승인했는지 여부. save_proposal의 available when 게이트가 소비. 저장 성공 후 False로 초기화."
    proposal_quote_id: mutable string = ""
        description: "save_proposal이 생성한 Quote Id. 같은 대화 내 중복 저장 방지."
```

- 이름은 `proposal_` 프리픽스로 namespace — Negotiation의 `terms_confirmed` / `negotiation_quote_id` 와 **충돌 없음**
- Proposal 확인이 Negotiation mutation을 인가할 수 없고, 그 반대도 불가:
  - `update_negotiation_terms` 게이트는 `terms_confirmed == True` 만 봄
  - `save_proposal` 게이트는 `proposal_confirmed == True` 만 봄
  - 두 변수는 서로 다른 `@utils.setVariables` 액션(`confirm_negotiation_terms` vs `confirm_proposal`)만 True로 만듦

### 6.2 액션 정의 (`actions:` 블록에 추가)

```
        list_sponsorship_packages:
            description: "판매 가능한 Sponsorship Package(Product2)와 Standard Price Book 가격을 조회한다. 조회 전용."
            label: "List Sponsorship Packages"
            target: "apex://SponsorshipPackageLookup"
            include_in_progress_indicator: True
            progress_indicator_message: "Sponsorship Package 목록을 확인하는 중..."
            # inputs / outputs 는 승우님의 list_sponsorship_packages 스키마 수정 결과에 맞춰 확정
            # (현재 f762840 계약: inputs 없음 / outputs packages: list[object] @apexClassType ...$PackageInfo — 손상됨)

        save_proposal:
            description: "확인된 제안 내용을 Quote/QuoteLineItem으로 저장하고, 전달된 benefit/segment 값이 있으면 Opportunity를 갱신한다."
            label: "Save Proposal"
            target: "apex://SponsorshipProposalSaver"
            include_in_progress_indicator: True
            progress_indicator_message: "제안서를 저장하는 중..."
            inputs:
                opportunityId: object
                    complex_data_type_name: "lightning__recordIdType"
                productId: object
                    complex_data_type_name: "lightning__recordIdType"
                quoteName: string
                shortTermBenefit: string
                midTermBenefit: string
                longTermBenefit: string
                targetSegment: string
            outputs:
                quoteId: object
                    complex_data_type_name: "lightning__recordIdType"
                quoteName: string
                success: boolean
                    filter_from_agent: True
```

### 6.3 reasoning `actions:` 배선

```
            confirm_proposal: @utils.setVariables
                description: "사용자가 '이걸로 저장해줘' / '확정' 처럼 명확하게 저장을 승인했을 때만 호출. '좋아 보인다' 같은 애매한 반응으로는 호출 금지. 패키지 선택('첫 번째' / '1')은 확인이 아님."
                set @variables.proposal_confirmed = True

            save_proposal: @actions.save_proposal
                with opportunityId = @variables.resolved_opportunity_id   # 결정적 — LLM이 Id 못 넣음
                with productId = ...                                       # ← §6.4 참고 (미해결)
                with quoteName = ...
                with shortTermBenefit = ...
                with midTermBenefit = ...
                with longTermBenefit = ...
                with targetSegment = ...
                available when @variables.proposal_confirmed == True and @variables.resolved_opportunity_id != "" and @variables.proposal_quote_id == ""
                set @variables.proposal_confirmed = False
                set @variables.proposal_quote_id = @outputs.quoteId
```

- `proposal_confirmed` 는 저장 성공 후 `False` 로 리셋 (Negotiation `terms_confirmed` 패턴과 동일 — f762840 원본은 리셋 안 했음)
- `proposal_quote_id != ""` 게이트로 같은 대화 내 중복 저장 방지

### 6.4 productId 결정적 바인딩 — **미해결, 계약 변경 필요**

`opportunityId` 는 `resolved_opportunity_id` 에서 결정적으로 바인딩되지만, `productId` 는
현재 계약상 LLM이 `list_sponsorship_packages` 출력에서 골라 넣는다(`with productId = ...`).
`SponsorshipPackageLookup` 을 수정하지 않고 이것을 완전 결정적으로 만들 방법은 없다.

**필요한 계약 변경 (승우님 결정):** 아래 중 하나
- **(A) `find_sponsorship_package` resolver 액션 신설** — 패키지 이름/코드를 받아 Id를 서버에서
  확정해 반환 (`NegotiationOpportunityLookup` 과 동일 패턴). 그러면
  `set @variables.resolved_package_id` → `save_proposal` 의 `with productId = @variables.resolved_package_id`
  로 결정적 바인딩 가능. 새 Apex 클래스 1개.
- **(B) `list_sponsorship_packages` 가 "확정 선택 1건"을 반환하도록 변경** — 선택까지 액션이 처리.
- (C) 최소 방어: `SponsorshipProposalSaver` 가 `req.productId` 가 `Sponsorship_Package` RecordType +
  active Standard PBE 를 갖는지 검증 후에만 진행 (LLM 자유 입력은 유지되지만 잘못된 Id는 거부).

권장: **(A)**. Opportunity resolver와 대칭이고, 통합 레이어에 깔끔하게 맞는다.

---

## 7. 통합 완료 조건 (Integration Ready)

1. 승우님: `list_sponsorship_packages` 스키마 재생성 → `GenAiPlannerBundle` retrieve 성공
2. 승우님: Proposal Apex test 3개 (각 ≥75%)
3. 승우님: `SponsorshipProposalSaver` savepoint/rollback + 사전검증
4. 승우님/팀: Existing Quote 정책 확정 → Saver에 반영
5. productId 결정적 바인딩 방식 확정 (§6.4)
6. 이 브랜치: §6의 write-path 블록 추가 → `sf agent publish` (staged, activate 안 함)
7. compiled planner에서 게이트/바인딩 검증 (Negotiation과 동일 방식)
8. 비-admin 사용자 1명으로 end-to-end Live 검증

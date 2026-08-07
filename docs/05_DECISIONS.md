# 05_DECISIONS.md — 프로젝트 의사결정 기록 (ADR)

> 이 문서는 프로젝트 전체에 영향을 주는 결정(Object 구조, Workflow, Persona, MVP 범위 등)을
> 기록한다(CLAUDE.md §7). 문서 간 내용이 충돌할 때는 이 문서를 최종 기준으로 판단한다.

---

## ADR이 뭔가요?

**ADR(Architecture Decision Record)**은 "우리가 왜 이렇게 하기로 했는지"를 남겨두는 짧은 메모입니다.

비유하자면, 이사할 집을 고를 때 "왜 이 동네로 정했는지"를 적어두는 것과 같습니다. 나중에
"왜 그때 그 동네를 골랐지?"라고 물어보면 다시 기억을 더듬거나 같은 고민을 반복하게 되는데,
그때 이 메모만 보면 바로 답을 알 수 있습니다.

Cloud Alpacas 프로젝트에서도 마찬가지입니다. "왜 실제 팀 이름과 가상 구단 이름을 다르게
정했는지", "왜 문서를 이렇게 나눴는지" 같은 질문에 팀원 누구나 다시 물어보지 않고 이 문서만
보면 답을 찾을 수 있도록 기록합니다.

**형식**: 각 결정은 아래 네 가지를 순서대로 적습니다.

| 항목 | 뜻 |
|---|---|
| 배경 | 왜 이 결정이 필요했나 (어떤 문제/혼란이 있었나) |
| 결정 | 무엇으로 정했나 |
| 이유 | 왜 이 선택이 다른 선택보다 나았나 |
| 영향 | 이 결정 때문에 앞으로 무엇이 달라지나 |

---

## Decision 001 — 팀 정체성 정리: Cellsforce와 Cloud Alpacas

**상태**: 확정
**기록일**: 2026-08-06

### 배경

프로젝트를 처음 접하면 "우리 팀 이름이 Cloud Alpacas인가?", "한화 이글스 데이터를 그대로
쓰는 건가?"처럼 헷갈리기 쉽습니다. 실제 팀과 프로젝트 속 가상의 구단, 그리고 그 구단이
참고한 실제 모델(한화 이글스)까지 세 가지 이름이 등장하기 때문에, 이 관계를 처음부터
명확히 정리해둘 필요가 있었습니다.

### 결정

세 가지 이름의 관계를 다음과 같이 확정한다.

- **Cellsforce** — 이 프로젝트를 수행하는 우리 실제 팀 이름.
- **Cloud Alpacas** — 우리가 실제로 설계하고 만드는 대상. 한화 이글스를 모델링한
  **가상의 프로야구 구단**.
- **한화 이글스** — Cloud Alpacas를 구상할 때 참고한 **실제 모델(reference)**. 우리가
  직접 다루는 데이터나 설계 대상이 아니다.

즉, Cellsforce는 Cloud Alpacas라는 가상 구단의 **Fan Relationship Management(FRM) Team**
역할을 맡아 Salesforce Customer 360을 설계한다.

> **비유**: 드라마 제작진(Cellsforce)이 실존 인물(한화 이글스)에서 영감을 받아 가상의
> 등장인물(Cloud Alpacas)을 만드는 것과 같습니다. 드라마 속에서는 실존 인물의 이름이
> 아니라 등장인물의 이름을 씁니다.

### 이유

- 실제 구단의 비공개 정보를 다루지 않고도, 실제 프로 스포츠 구단과 유사한 현실감 있는
  Business 문제(팬 관리, 멤버십, 굿즈 등)를 자유롭게 설계할 수 있다.
- "가상의 구단"이라는 점을 명확히 해야, 이후 만드는 모든 데이터·화면·시나리오가 창작물임을
  팀 안팎에 혼동 없이 전달할 수 있다.

### 영향

- 모든 문서·화면·데이터에서 실제 구단을 지칭할 때는 **반드시 "Cloud Alpacas"**를 쓴다.
  "한화 이글스"라는 표현은 "Cloud Alpacas가 한화 이글스를 모델링했다"는 관계를 설명할 때만
  예외적으로 사용한다.
- 이후 작성하는 03_SYSTEM.md의 Salesforce Object, 04_DEMO.md의 Demo Story, 샘플 데이터
  등은 모두 Cloud Alpacas 기준으로 작성한다.

---

## Decision 002 — Workflow 분석을 별도 문서로 만들지 않고 01_PROJECT.md에 통합

**상태**: 확정
**기록일**: 2026-08-06

### 배경

프로젝트 초기에는 Domain Model(01_PROJECT.md)과 Workflow 분석(가칭 `02_WORKFLOW.md`)을
서로 다른 문서로 나누는 방안을 고려했었다. 그런데 실제로 작업해보니, Workflow 분석은
"Domain Model이 왜 이렇게 나왔는지"를 검증하는 과정이었고, Domain Model은 그 결과를 담는
그릇이었다 — 즉 두 문서가 사실상 같은 질문("이 세계에 어떤 명사가 필요한가")을 다른
방식으로(Story 관점 vs Workflow 관점) 다시 확인하는 구조였다.

### 결정

Workflow 분석을 별도 문서(`02_WORKFLOW.md`)로 만들지 않고, **01_PROJECT.md 안에서
Domain Model과 함께 다룬다.**

### 이유

- Domain Model과 Workflow는 서로 다른 문서가 아니라 **하나의 사고 흐름**이다: "실제 업무
  (Workflow)를 보고 → 어떤 명사(Entity)가 필요한지 확인하고 → Domain으로 묶는다."
  이 흐름을 문서 두 개로 쪼개면 오히려 앞뒤를 오가며 읽어야 해서 더 헷갈린다.
- CLAUDE.md §7 원칙("같은 내용을 여러 문서에 중복 작성하지 않는다")에 따라, Entity 목록이
  Workflow 분석과 Domain Model 두 곳에 중복 등장하는 것을 피할 수 있다.
- 문서 번호 체계(00~05)를 단순하게 유지할 수 있다 — 문서가 늘어날수록 "어디에 뭐가
  있는지" 찾기 어려워지는 것은 Baby Team에게 특히 부담이 된다.

### 영향

- `02_WORKFLOW.md`라는 파일은 만들지 않는다. 이번 문서 번호 `02`는 대신 `02_TEAM_GUIDE.md`
  (팀 운영 방식)에 배정한다 — CLAUDE.md §8 프로젝트 구조 참고.
- 앞으로 Workflow가 바뀌거나 새로운 Entity가 발견되면, 별도 문서를 새로 만들지 말고
  01_PROJECT.md를 갱신한다.

---

## Decision 003 — Standard First, Custom When Needed

**상태**: 확정
**기록일**: 2026-08-06

### 배경

01_PROJECT.md §6은 Ticket/Membership/Goods 같은 상품과 그 구매를 Salesforce에서 어떤
Object로 만들지에 대해 두 가지 갈림길을 놓고 있었다.

- **상품(§6.3)**: Custom Object로 자유롭게 설계할지, 아니면 Salesforce 표준 `Product2` +
  `Price Book`을 쓸지.
- **구매(§6.5)**: `Standard Order`(이미 확정된 거래)로 만들지, `Standard Opportunity`
  (진행 중인 딜)로 만들지.

이 프로젝트는 Salesforce가 처음인 Baby Team이 Customer 360을 배우는 프로젝트이기도
하다(CLAUDE.md §6) — "표준 기능을 얼마나 쓸지"는 상품/구매 Object 하나만의 문제가 아니라,
프로젝트 전체의 설계 방향을 정하는 질문이었다.

### 결정

**Salesforce 표준 Object를 우선 사용하고, Cloud Alpacas만의 핵심 비즈니스는 필요한
범위에서만 Custom Object로 확장한다.**

구체적으로:

- **판매 가능한 상품** (Ticket, Season Pass, Membership, Goods) → **표준 `Product2` +
  `Price Book`**
- **실제 구매** (Ticket Purchase, Goods Purchase, Membership Enrollment) → **표준
  `Order`**
- **Cloud Alpacas Customer 360의 핵심** (Fan Activity Pattern, Attendance Record,
  Recommendation, Fan Segment, Next Best Action 등) → **Custom Object**

> **비유**: 집을 지을 때 전기 배선·수도 배관처럼 어느 집에나 똑같이 필요한 부분은 표준
> 자재(기성품)를 쓰고, "이 집만의 특징"(우리 가족만을 위한 다락방 구조 등)은 직접
> 설계하는 것과 같습니다. 상품·구매는 어느 커머스 조직에나 필요한 표준 자재이고, 팬을
> 이해하고 다음 행동을 추천하는 부분(Customer 360)이 Cloud Alpacas만의 다락방입니다.

### 이유

- 표준 Object(Product2/Price Book/Order)는 이미 검증된 구조라, 우리가 직접 설계하며
  실수할 여지를 줄여준다 — Baby Team이 표준 패턴을 먼저 익히는 데도 도움이 된다.
  §6.3·§6.5는 원래 "서로 연결된 결정"으로 묶여 있었는데(01_PROJECT.md §6.5 마지막 문단),
  Product2를 쓰기로 하면 Order가 자연스럽게 이어진다.
- 반대로 Fan Segment, Recommendation처럼 이 프로젝트의 핵심 목표(Business Goal — 팬을
  이해하고 성장시키는 것)와 직접 맞닿은 부분은 표준 Object가 표현하지 못하는 개념이라
  Custom Object로 직접 설계해야 한다.
- 결과적으로 "표준으로 충분한 것"과 "우리만의 설계가 필요한 것"을 구분하는 기준이
  생긴다 — 이후 §6의 나머지 결정(Eligibility Rule, Marketing Consent 등)에도 같은
  기준(표준 우선, 필요할 때만 확장)을 적용할 수 있다.

### 영향

- 01_PROJECT.md §6.1 매핑 표의 "Ticket/Season Pass/Membership/Goods/Collaboration
  Item/Benefit"은 03_SYSTEM.md에서 Product2 기반으로, "Ticket Purchase/Goods
  Purchase/Membership Enrollment"는 Order 기반으로 구체화한다.
- Ticket Policy/Membership Tier처럼 "가격·조건을 정의하는" Entity는 Price Book Entry로
  흡수할 수 있는지를 03_SYSTEM.md에서 함께 검토한다.
- Fan Activity Pattern, Attendance Record, Recommendation, Fan Segment는 Custom
  Object로 확정되었으므로, 03_SYSTEM.md에서 바로 Object/Field 설계로 들어간다(별도
  Report/Dashboard 대안 비교는 더 이상 필요 없음).

---

## Decision 004 — 01_PROJECT.md §6 나머지 항목 확정 (Object 설계 착수 전 최종 결정)

**상태**: 확정
**기록일**: 2026-08-06

### 배경

01_PROJECT.md §6은 Decision 003(Product2/Order/Custom Object 구도) 외에도 6개의 개별
갈림길(§6.2, §6.4, §6.6~§6.9)을 팀의 판단에 맡겨두고 있었다. 03_SYSTEM.md에서 Object/Field
설계를 시작하기 전에, 이 항목들을 모두 확정한다. 모든 결정은 CLAUDE.md §5 MVP 원칙("이번
MVP 범위를 벗어나면 Future Scope로 기록한다")에 따라, **지금 필요한 만큼만 만들고 나머지는
Future Scope로 남기는 방향**을 일관되게 따른다.

### 결정

| 항목 | 01_PROJECT.md 참조 | 결정 | 근거 요약 |
|---|---|---|---|
| Fan | §6.2 | **Person Account** | Fan은 압도적 다수의 B2C 개인 고객이며, 직접 구매·이용의 주체다. Fan 한 명 = 레코드 한 개로 자연스럽게 표현된다. |
| Eligibility Rule | §6.4 | **Flow 로직으로만 관리 (Object 없음)** | 규칙 종류가 적고 자주 안 바뀐다. Flow의 Decision 요소로 조건을 직접 구현한다. |
| Ticket Transfer | §6.6 | **Ticket의 필드로만 처리 (Current Owner, Transfer Status)** | 핵심 비즈니스가 아니고, Demo에서 양도 이력을 추적하지 않는다. |
| Marketing Consent | §6.9 | **Person Account의 필드로 관리** (채널별 동의 여부 + 최종 변경 일시) | 감사(Audit) 목적의 이력 추적이 이번 범위에 없다. |
| Renewal | §6.7 중 Renewal | **별도 Object 없이 상태 변경으로 처리** (Membership Enrollment의 Status/Expiration Date) | 갱신은 "새 레코드"가 아니라 기존 가입 상태의 전이로 충분히 표현된다. |
| Partner Store | §6.8 | **별도로 관리하지 않음.** Partner(협업사)는 표준 **Account**를 쓰고, **Record Type**으로 Partner/Sponsor를 구분한다. | 이번 MVP의 협업 대상(예: 산리오)은 매장 단위 관리가 필요 없는 단일 조직이다. |

> Fan Activity Pattern, Attendance Record, Recommendation, Fan Segment는 Decision 003에서
> 이미 Custom Object로 확정되었으므로 이 표에는 포함하지 않는다.

### Future Scope (지금은 만들지 않지만, 나중에 필요해지면 확장하는 지점)

- **Eligibility Rule**: 운영 정책이 자주 바뀌거나 비개발자(Admin)가 직접 규칙을 관리해야
  하면 → Custom Object로 승격.
- **Ticket Transfer**: CS가 양도 이력 조회·다중 양도(A→B→C) 문제를 자주 처리해야 하면 →
  별도 Custom Object(이력 기록)로 승격.
- **Marketing Consent**: Marketing Cloud를 도입하거나 법적 감사 요구가 생기면 → Consent
  History Custom Object로 승격.
- **Renewal**: 갱신 임박 자동 알림, Renewal Campaign이 필요해지면 → 별도 Object 또는
  전용 Flow로 확장.
- **Partner Store**: GS25처럼 여러 매장을 가진 파트너와 협업하게 되면 → Parent Account
  구조 또는 별도 Partner Store 모델로 확장.

### 영향

- 03_SYSTEM.md는 이 표를 기준으로 바로 Object/Field 설계에 들어간다 — §6의 선택지 비교는
  더 이상 반복하지 않는다.
- 위 5개 Future Scope 항목은 03_SYSTEM.md 문서 말미에 "Future Scope" 섹션으로 옮겨
  정리한다(중복 방지, CLAUDE.md §7).

---

## Decision 005 — MVP Object 범위: Sponsorship/Partnership Domain 제외

**상태**: 확정
**기록일**: 2026-08-06

### 배경

01_PROJECT.md는 Cloud Alpacas의 6개 팀(마케팅·티켓·멤버십·굿즈·고객지원·스폰서십) 업무를
모두 분석해 Business Entity를 뽑았다. 하지만 00_STORY.md의 Demo Story는 김매니저가
이루키(신규 팬)를 충성 팬으로 성장시키는 여정만 다루며, 스폰서십/파트너십 업무와는 직접
관련이 없다. 03_SYSTEM.md에서 Object를 설계하기 전에, "업무 분석에 등장한 모든 Entity"와
"이번에 실제로 만드는 Object"가 같은 범위인지 확인이 필요했다.

### 결정

03_SYSTEM.md의 Object 설계는 **Fan / Marketing / Ticket / Membership / Goods / Service
Domain**에만 집중한다. **Sponsor, Partner, Proposal, Sponsor Contract, Settlement,
Sponsorship Package** 등 스폰서십·파트너십 관련 Object는 이번 MVP 설계·구현 범위에서
**제외**한다.

### 이유

- CLAUDE.md §2의 Business Goal("신규 팬을 이해하고... 충성 팬으로 성장시키고...")과
  00_STORY.md의 Demo Story 모두 팬 개인의 여정에 초점이 있다 — 스폰서십은 이 여정에
  등장하지 않는다.
- CLAUDE.md §5 MVP 원칙: "새로운 아이디어가 나오더라도 MVP 범위를 벗어나면 바로 구현하지
  않고 Future Scope로 기록한다." 스폰서십 Domain은 실제 업무상으로는 존재하지만, 이번
  Demo가 증명해야 하는 범위 밖이다.
- Object 수를 줄이면 Baby Team이 Org 구조를 이해하고 관리하기에도 더 수월하다.

### 영향

- 03_SYSTEM.md는 Sponsor/Partner 관련 Object를 만들지 않는다.
- 01_PROJECT.md §4의 Partnership Domain Entity(Sponsor, Partner, Partner Contact,
  Sponsorship Package, Proposal, Sponsor Contract, Settlement, Sponsor Performance,
  Collaboration Item, Partner Store)는 **Future Scope**로 남긴다 — 향후 산리오와 같은
  협업사·스폰서십 관리 기능이 필요해지면 이 Entity 목록을 그대로 재사용해 확장한다.
- Campaign, Benefit처럼 Marketing/Operations와 Partnership이 공유하던 Entity는
  Marketing/Operations 쪽 용도로만 이번에 설계한다.

---

## Decision 006 — 03_SYSTEM.md Object 개수 최소화 (경기장 구조 · Notification · Benefit · 배송)

**상태**: 확정
**기록일**: 2026-08-06

### 배경

Decision 003~005로 큰 틀(Person Account, Product2+Order, Custom Object 범위)은 정해졌지만,
Object/Field 설계에 착수하기 전 4개의 세부 항목이 더 남아 있었다 — 모두 "Object를 몇 개나
만들 것인가"에 영향을 주는 항목이라 먼저 확정한다.

### 결정

| 항목 | 결정 | 근거 요약 |
|---|---|---|
| 경기장 구조 (Ballpark/Section/Seat/Gate) | **별도 Object 없음.** 좌석 정보(Section, Row, Seat Number, Gate)는 티켓 관련 필드로만 관리 | Cloud Alpacas는 단일 홈구장 MVP. 구역별 선호 분석은 필드만으로 충분히 가능하다. |
| Notification | **Custom Object(Notification Log)로 기록** | Fan Timeline의 핵심 데이터. Flow가 레코드를 만들고, 그 레코드를 근거로 Slack 알림을 보낸다 — "언제 어떤 안내를 보냈는지"가 이력으로 남아야 한다. |
| Benefit / Benefit Redemption | **Benefit만 Custom Object로 관리.** 사용 여부는 Benefit의 Status 필드(Issued/Used/Expired)로 표현하고, 별도 Redemption Object는 만들지 않음 | Recommendation의 결과로 발급되는 개인화 혜택을 표현하는 데는 상태 필드만으로 충분하다. |
| Shipment / Return | **Future Scope로 제외.** Goods Purchase(Order)까지만 구현 | 이 프로젝트의 목적은 물류가 아니라 Customer 360이다. Demo Story에도 배송·반품 장면이 없다. |

### Future Scope

- **경기장 구조**: 다구장 운영이나 좌석 상태(예약됨/사용됨) 관리가 필요해지면 → Ballpark /
  Section / Seat Object로 확장.
- **Benefit Redemption**: 혜택 사용 이력을 별도로 분석하거나 정산해야 하면 → Benefit
  Redemption Object 추가.
- **Shipment / Return**: 배송 추적, 교환·반품 처리 프로세스가 필요해지면 → 두 Object를
  새로 추가.

### 영향

- 03_SYSTEM.md의 Object 목록은 위 4가지 결정을 그대로 반영한다.
- 좌석 정보 필드는 "언제 시점의 정보인가"에 따라 두 곳으로 나뉜다 — 좌석 배정(Section,
  Row, Seat Number)은 구매 시점 정보라 **OrderItem**에, 실제 입장 게이트(Gate)는 입장
  시점 정보라 **Admission**에 둔다. 이 구분은 03_SYSTEM.md에서 필드 단위로 설명한다.

---

## Decision 007 — 팀 역할 재정의: 직함을 "무엇을 만드는 사람인가"로 다시 표현

**상태**: 확정
**기록일**: 2026-08-07

### 배경

기존 직함(Salesforce Admin Lead, Platform Lead / QA Lead, Demo Lead / Business
Analyst)은 Salesforce를 처음 접하는 Baby Team에게 "이 사람이 정확히 무엇을 하는
사람인지" 바로 와닿지 않았다. 특히 Business Analyst 역할이 "Demo Lead"라는 이름
때문에 완성된 결과를 마지막에 검사하는 사람처럼 오해되기 쉬웠고, 승우와 혜준의
역할 경계(누가 화면을 만드는가)도 명확하지 않았다.

### 결정

팀원 직함과 책임 범위를 아래와 같이 재정의한다.

| 담당자 | 기존 직함 | 새 직함 |
|---|---|---|
| 승우 | Salesforce Admin Lead | **Salesforce Builder** |
| 혜준 | Platform Lead / QA Lead | **Salesforce Experience Lead / QA Lead** |
| 아론 | Demo Lead / Business Analyst | **Business Analyst / Demo Experience Lead** |

직함 변경과 함께 아래 책임도 재배분한다.

- **화면(Lightning Page/App) 구현**은 승우(Salesforce Builder)에서 **혜준(Salesforce
  Experience Lead)**으로 이동한다 — "데이터 구조를 만드는 것"과 "그 구조를 직원이 쓰기
  좋게 완성하는 것"은 서로 다른 책임이라는 점을 직함에 정확히 반영하기 위함이다. 승우는
  화면이 참조하는 Object/Field가 정확한 데이터를 갖도록 지원하는 역할로 남는다.
  혜준은 Salesforce Admin 자격증을 보유하고 있어 Platform(화면·권한) 영역과 운영(Admin:
  QA·UAT·배포) 영역을 함께 담당한다.
- **아론(Business Analyst)**의 역할은 "완성된 결과를 검증하는 사람"이 아니라 "Customer
  Journey와 Business Story를 함께 설계하고, Demo가 자연스럽게 전달되도록 만드는 사람"
  으로 명확히 표현한다. Object나 Field를 먼저 찾지 않고 Business Story를 먼저 만든 뒤
  그 Story에 필요한 Object를 함께 찾는 순서(CLAUDE.md §3 Business First)는 그대로
  유지된다 — 바뀐 것은 표현 방식이지 실제 작업 순서가 아니다.
- 은영님의 로마자 표기를 "Eunyoung"에서 **"Eunyeong"**으로 통일한다 — 온보딩 문서
  파일명도 `02_EUNYOUNG.md`에서 `02_EUNYEONG.md`로 변경한다.

### 이유

- CLAUDE.md §6은 Claude와 팀 모두에게 "어려운 용어를 먼저 사용하지 않는다"를 요구한다
  — 직함도 예외가 아니다. "이 사람이 자동차의 어느 부분을 만드는가"라는 비유
  (02_TEAM_GUIDE.md §1-1)로 설명하면 Salesforce 경험이 없어도 즉시 이해할 수 있다.
- 다섯 역할이 Sara(무엇을 만들지) → 아론(이야기가 자연스러운지) → 승우(데이터 구조) →
  혜준(직원이 쓰기 좋은 환경) → 은영(실제 동작)의 순서로 연결된다는 것
  (02_TEAM_GUIDE.md §1-2)을 직함에서도 드러내야 "내 일이 왜 필요한지"가 분명해진다.
- 실제 작업 범위(Responsibility)는 바뀌지 않았다 — Object/Field/Flow 구조는 여전히
  승우가, Business Story·Demo는 여전히 아론이 이끈다. 이번 결정은 **표현과 책임 경계를
  명확히 하는 리팩토링**이며, MVP 범위나 Object 설계를 바꾸지 않는다.

### 영향

- `02_TEAM_GUIDE.md`(SSOT)와 `docs/members/*.md` 전체가 이 표를 기준으로 갱신되었다.
- `02_TEAM_GUIDE.md` §2(Object/Flow/Screen 담당) 표의 화면 담당 행이 "혜준(구현·QA),
  승우(데이터 연동 지원)"으로 바뀌었다.
- 이후 팀원 역할이 다시 바뀌면 이 Decision처럼 배경/결정/이유/영향을 기록한 뒤
  `02_TEAM_GUIDE.md`를 먼저 고치고 `docs/members/*.md`를 맞춘다(CLAUDE.md §7).

---

## Decision 008 — 은영의 역할 명확화: "연동 담당"이 아니라 "커스텀 개발 전체" 담당

**상태**: 확정
**기록일**: 2026-08-07

### 배경

기존 은영의 역할 설명(Decision 007 이전부터)은 "Demo Fan App 개발과 Salesforce
연동"에만 초점이 맞춰져 있었다. 하지만 실제로 Developer Lead가 필요한 이유는
"Fan App만 만들기 위해서"가 아니라, **Salesforce 표준 기능(Flow, 표준 화면 등)만으로
해결이 안 되는 부분을 코드로 만들기 위해서**다 — LWC, Apex, 외부 시스템 연동
아키텍처가 전부 여기 포함된다. "연동"이라는 좁은 표현이 이 역할의 진짜 크기를
가리고 있었다.

### 결정

은영의 역할을 **Developer Lead**로 명확히 하고, 책임 범위를 아래와 같이 확장한다.

| 영역 | 내용 | 원칙 |
|---|---|---|
| Fan App | Demo MVP Fan App 개발(로그인, 티켓/굿즈 구매, QR 체크인 등) | 기존과 동일 |
| LWC | 표준 컴포넌트로 부족할 때 커스텀 Lightning Web Component 개발 | **표준 우선** — 화면 레이아웃 조립(Lightning Page)은 혜준(Salesforce Experience Lead)이 하고, 그 안에 들어가는 개별 커스텀 부품만 은영이 코드로 만든다 |
| Apex | Flow로 처리하기 어려운 복잡한 로직만 개발 | **Flow 우선**(Decision 003의 "Standard First, Custom When Needed"를 코드 레벨로 확장) — `03_SYSTEM.md` §4.6에 이미 후보로 기록된 항목(예: `Fan_Activity_Pattern__c` 재계산)이 실제 대상이다 |
| Salesforce API 연동 | Fan App → Salesforce 데이터 전달 | 기존과 동일 |
| Slack 연동 | Slack App/Webhook 설정과 메시지 Payload 형식 | 은영이 기술 아키텍처를 주도하고, Flow 안에서 이를 호출하는 것은 승우가 담당한다(`02_TEAM_GUIDE.md` §2 갱신) |
| Agentforce | Fan Summary, Next Best Action 설명 등 | **🔵 Future Scope** — CLAUDE.md §5에 따라 이번 MVP 범위 밖이다. 은영의 장기 역할에는 포함하되, 지금 만들지 않는다 |

**베이비 팀을 위한 한 줄 원칙**: "Salesforce 표준 기능을 먼저 쓰고, 표준으로 안 될
때만 개발한다." — Fan App을 제외한 모든 영역(LWC/Apex/Agentforce)에 이 원칙을
그대로 적용한다.

### 이유

- Decision 003이 Object 설계에 적용한 "표준 우선, 필요할 때만 확장" 원칙을 코드
  레벨(LWC/Apex)까지 일관되게 확장하면, Baby Team이 "언제 Apex를 써도 되는가"를
  매번 새로 고민하지 않고 같은 기준으로 판단할 수 있다.
- Agentforce를 완전히 빼지 않고 "은영의 스킬셋"으로는 남겨둔 이유는, MVP 이후
  Future Scope로 확장할 때 누가 이 작업을 맡을지 미리 명확히 해두기 위해서다 —
  다만 CLAUDE.md §5가 이미 MVP 범위 밖으로 명시했으므로, 지금 당장의 Responsibility로
  포함하지는 않는다.
- Slack 연동의 소유권을 "은영 주도, 승우 보조"로 재정리한 것은, Webhook/Payload
  설계가 Flow 로직보다 코드/API 성격이 강해 Developer Lead의 책임 범위와 더
  자연스럽게 맞기 때문이다.

### 영향

- `02_TEAM_GUIDE.md` §1의 Developer Lead 책임 영역 설명과 §2의 Slack 연동 담당
  행이 이 표를 기준으로 갱신되었다.
- `docs/members/02_EUNYEONG.md`가 이 표를 기준으로 갱신되었다 — Owned Flows(Apex
  후보 언급), Owned Screens(LWC와 혜준의 화면 조립 관계) 섹션이 함께 바뀌었다.
- Agentforce 관련 작업은 이후 팀이 MVP 범위를 공식적으로 넓히기로 결정할 때
  별도 Decision으로 다시 다룬다 — 이번 Decision은 "누가 맡을지"만 미리 정해둔
  것이지, MVP 범위 자체를 넓히는 결정이 아니다.

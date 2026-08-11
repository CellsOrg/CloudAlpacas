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

---

## Decision 009 — Fan 분류 체계 3축 분리, Owner 독립, Purchase Channel, Engagement 필드/로직 분리

**상태**: 확정
**기록일**: 2026-08-11

### 배경

Fan Profile 화면에 무엇을 보여줄지("최근 관람일, 총 관람 횟수, 구매 금액/빈도, 최근 활동,
Engagement, Fan Value, Current Segment") 정리하는 과정에서, 그동안 문서 곳곳에서
**"Segment"라는 단어가 서로 다른 세 가지 의미로 혼용**되어 왔다는 것이 드러났다.

- `00_STORY.md` §6 "Fan Segment"는 **팬의 현재 상태(Life Cycle)** — New Fan/Active
  Fan/At-Risk Fan 등 — 를 가리킨다.
- `01_PROJECT.md` §2.1(마케팅 Workflow)·§3.1의 "Fan Segment"는 원래 **캠페인 발송
  대상을 묶은 그룹**(마케팅 세분화)을 가리키는 다른 개념으로 제안됐다.
- `Fan_Segment_History__c`(03_SYSTEM.md)는 실제로는 위 둘 중 **Life Cycle 쪽으로만**
  구현됐다 — 마케팅 대상 그룹이라는 원래 의미는 Object로 만들어지지 않았다.
- Flow와 Demo Scene 곳곳의 "VIP 후보"(00_STORY.md §2, 03_SYSTEM.md §4.5,
  04_DEMO.md Scene 7)는 Membership Tier의 `VIP`(Product2.`Tier__c`) 값과도, 아직
  존재하지 않는 "이 팬이 얼마나 가치있는 고객인가"라는 판단과도 뒤섞여 쓰이고 있었다.
- Owner(담당 직원)가 Fan 분류와 같은 축인지 다른 축인지도 문서에 명시된 적이 없었다.

이 혼용을 그대로 두면 다가오는 Org 구현 단계에서 "Segment"라는 이름의 필드/Object를
무엇으로 만들지 팀마다 다르게 이해할 위험이 있다.

### 결정

**1. Fan 분류는 반드시 서로 독립된 3개의 축으로 관리한다.**

| 축 | 값 | 의미 |
|---|---|---|
| **Current Segment / Life Cycle** | New / Active / Dormant / At-Risk / Churned / Unreachable | 지금 이 팬이 활동 주기의 어디에 있는가(`00_STORY.md` §6과 동일 — 값 목록 변경 없음) |
| **Engagement Level** | 가입 → 관심 → 활동 → 충성 → 멤버십 → 핵심 | 이 팬이 우리와 얼마나 깊게 관계를 맺고 있는가 |
| **Fan Value** | 일반 / 우수 / VIP | 이 팬이 우리에게 얼마나 가치 있는 고객인가 |

앞으로 어떤 문서에서도 "Segment"라는 단어 하나로 이 세 가지를 혼용하지 않는다.
**VIP는 Fan Value 값이다** — Membership Tier(Product2.`Tier__c`)의 "VIP" 상품 등급과는
다른 개념이며, "VIP 후보"라는 기존 Flow/Demo 표현은 Fan Value가 VIP로 바뀔 가능성이
높은 후보를 가리키는 것이지, 자동으로 `Fan_Value__c`를 VIP로 확정하는 것이 아니다.

**2. Owner(담당 직원)는 Fan 분류와 완전히 별개의 축이다.**

Owner = 담당 직원, Fan Value = 고객 가치, Current Segment = 현재 고객 상태는 서로
독립적으로 조합될 수 있다 — 예를 들어 김매니저가 담당하는 VIP이면서 동시에 At-Risk인
Fan이 존재할 수 있다. 현재는 김매니저 1명뿐이므로 OWD/Sharing Rule/Role 기반 접근
제한은 구현하지 않는다. Owner(표준 `OwnerId`) 구조 자체는 유지하고, Staff가 늘어나면
접근 권한/Sharing 전략을 Future Scope에서 별도로 결정한다.

**3. Order의 Purchase Channel(온라인/구장 굿즈샵)을 관리한다.**

Fan Journey, Fan Profile, Dashboard, Recommendation에서 온라인 구매와 구장 현장 구매를
구분해 활용하기로 했으므로, `Purchase_Channel__c` 필드로 관리한다.

**4. Engagement Score/Level은 "필드 정의"와 "계산 로직"을 구분해 문서화한다.**

계산 공식(어떤 활동에 몇 점을 주고 어느 점수 구간이 어느 Level인지)은 아직 확정되지
않았다. 공식이 없다고 해서 이번 MVP에서 필요한 Fan 데이터 자체를 Marketing Cloud
도입 이후로 미루지 않는다 — 필드와 값 목록은 지금 정의하고, 계산 로직은 미확정(TBD)
상태로 명시해 둔다.

**5. Sales Cloud MVP를 우선 구현하며, 지금까지의 Object/Fan 360 설계를 뒤집지 않는다.**

Marketing Cloud Next / Data Cloud / Tableau 등은 CLAUDE.md §5에서 이미 Future Scope로
분류된 원칙을 재확인한다. 이 확장 경로(Sales Cloud Fan Data → Data Cloud → Segment
Builder → Marketing Cloud Next → Campaign/Journey/Personalization → 성과 분석)는
`03_SYSTEM.md` §5 Future Scope에 참조용으로 한 줄만 남기고, 현재 MVP Object를
Marketing Cloud 전용 구조로 미리 재설계하지 않는다. 실제 Org 구현 이후 고도화 여부를
다시 결정한다.

### 이유

- Fan Profile처럼 실제 화면을 설계하는 순간 "Segment 하나"로는 "이 팬이 지금 뭘 하고
  있는가"(Life Cycle), "얼마나 깊이 관여하는가"(Engagement), "얼마나 가치 있는가"(Value)를
  동시에 표현할 수 없다는 것이 드러났다 — 세 질문은 서로 다른 답을 가질 수 있다(예:
  Dormant지만 과거 누적 가치가 높아 여전히 VIP인 팬).
- VIP를 Membership Tier와 뒤섞으면 "VIP 멤버십 상품을 산 사람"과 "우리가 VIP로 판단한
  사람"이 항상 같다고 잘못 가정하게 된다 — 실제로는 다를 수 있다(VIP 멤버십을 아직 안
  샀어도 Fan Value가 VIP인 팬이 있을 수 있다).
- Owner와 Fan 분류를 분리해야, 나중에 Staff가 늘어나 담당자를 배정하더라도 "그 담당자가
  맡은 팬이 자동으로 특정 Segment/Value가 된다"는 잘못된 결합을 방지할 수 있다.
- CLAUDE.md §5 MVP 원칙("고도화 여부는 실제 Org 구현 이후 결정한다")과 §7 원칙(전체에
  영향을 주는 변경은 Decision으로 기록)을 그대로 따른 것이다 — 이 Decision은 새 기능을
  추가하는 것이 아니라, 이미 여러 문서에 흩어져 암묵적으로 쓰이던 개념을 하나의 기준으로
  정리한 것이다.

### 영향

- `00_STORY.md` §6: "Fan Segment" 표가 3축 중 **Current Segment(Life Cycle)** 만
  다룬다는 점을 명시한다. 표의 값 자체는 바뀌지 않는다.
- `01_PROJECT.md` §3.1·§4: "Fan Segment" Entity가 Life Cycle 쪽으로 구현되었고,
  마케팅 대상 그룹이라는 원래 개념은 별도 Entity 없이 필요해지면 §6.10의 List
  View/Report 대안으로 다룬다는 주석을 추가한다. 기존 분석 내용(왜 그렇게 추론했는지)은
  삭제하지 않는다.
- `03_SYSTEM.md` §2.1(Person Account): `Engagement_Level__c`, `Fan_Value__c` 필드를
  추가한다. `Current_Segment__c`와 함께 3축이 모두 Person Account에 캐시되고,
  원본 이력은 각각 별도 Object(`Fan_Segment_History__c` 등)가 담당하는 기존 원칙(§2.1
  캐시/이력 분리 설명)을 그대로 따른다.
- `03_SYSTEM.md` §2.4(Order): `Purchase_Channel__c` 필드를 추가한다.
- `03_SYSTEM.md` §5(Future Scope): Engagement Score 계산 공식 확정, OWD/Sharing Rule
  확장, Marketing Cloud Next 확장 파이프라인을 항목으로 추가한다.
- `04_DEMO.md` §4 화면 목록: Fan Profile이 보여주는 항목을 이 Decision의 3축 + 관람/구매
  요약 기준으로 구체화한다.
- `docs/data/DEMO_DATASETS.md`: Order 레코드에 `Purchase_Channel__c` 값을 채운다.

---

## Decision 010 — Org 구현 착수 전 최종 확정: 필드명(`Fan_Value_Tier__c`), `Engagement_Score__c` 신설, VIP 후보 흐름/이력 범위 재확인

**상태**: 확정
**기록일**: 2026-08-11

### 배경

Decision 009로 Fan 분류 3축의 **개념**은 정리됐지만, Org에서 실제로 Object/Field를
만들기 하루 전 시점에 두 가지가 더 필요했다.

- Decision 009는 Fan Value 축의 필드명을 `Fan_Value__c`로 임시 표기했다. 그런데 이
  필드가 담는 값은 "일반/우수/VIP"라는 **등급(Tier)**이지, "가치가 얼마인지"를 나타내는
  숫자(LTV 등)가 아니다 — `Fan_Value__c`라는 이름만 보면 나중에 숫자 필드로 오해하거나,
  누군가 별도로 LTV 숫자 필드를 또 만들어버릴 위험이 있었다.
- Fan Profile에 "Engagement" 하나만 표시하기로 했던 초기 논의와 달리, 실제로는
  **Engagement Level(범주 — 가입/관심/활동/충성/멤버십/핵심)**과 **Engagement Score
  (그 범주를 산출하는 근거 점수)**가 서로 다른 목적의 값이라는 것이 Fan Profile 요구사항
  ("Engagement Score, Engagement Level"을 나란히 요구)에서 드러났다. `Engagement_Level__c`
  하나로는 이 둘을 구분할 수 없었다.
- VIP 후보 감지 Flow의 "감지 → Recommendation → 담당자 확인 → (필요 시) Action"이라는
  4단계 흐름이 03_SYSTEM.md §4.5에 암묵적으로만 존재했고, "VIP 후보 감지 ≠ Fan Value
  자동 변경"이라는 등식이 문서에 명시적으로 박혀 있지 않았다.
- `Fan_Segment_History__c`가 Current Segment(Life Cycle) 전용인지, 3축 전체의 이력을
  다 받는 Object로 확장될 수도 있는지가 Decision 009에는 여지로 남아 있었다.

### 결정

**1. Fan Value 축의 필드명을 `Fan_Value_Tier__c`로 확정한다.** (Decision 009의
`Fan_Value__c`를 대체 — 값은 그대로 일반/우수/VIP)

**2. `Engagement_Score__c`(Number) 필드를 신설한다.** `Engagement_Level__c`(범주값)와는
별개의 필드다 — Score는 Level을 산출하는 근거 점수라는 관계다. **필드 자체는 이번 MVP에
포함해 확정하지만, 점수 계산 공식과 자동 계산 방식(Flow/Apex 등)은 이번에 확정하지
않는다(TBD)** — "관람 30점 + 구매 40점 + 활동 30점" 같은 임의의 배점을 지금 만들어
확정하지 않는다.

**3. `Engagement_Level__c`의 값 레이블을 "가입 팬/관심 팬/활동 팬/충성 팬/멤버십
팬/핵심 팬"으로 통일한다.** Current Segment가 "New Fan/Active Fan/..."처럼 "Fan"을
붙이는 표기 스타일과 일치시킨 것이며, Decision 009가 정의한 6단계(가입→관심→활동→충성→
멤버십→핵심) 자체는 바뀌지 않는다.

**4. VIP 후보 감지 Flow의 4단계 흐름을 명문화한다.**
`Fan_Activity_Pattern__c`(행동 데이터) 기준 VIP 조건 충족 감지 → `Recommendation__c`
생성 → 담당자(김매니저)에게 Slack 알림 → **담당자 확인** → 필요 시 담당자가 직접
`Fan_Value_Tier__c`를 VIP로 변경(수동). **"VIP 후보 감지" ≠ "Fan Value = VIP 자동
변경"**이며, 이 Flow는 어떤 경우에도 `Fan_Value_Tier__c`를 자동으로 쓰지 않는다.

**5. `Fan_Segment_History__c`는 Current Segment(Life Cycle) 변경 이력 전용임을
재확인한다.** Engagement Level/Fan Value 변경 이력까지 이 Object 하나로 통합하지
않는다 — 두 축이 이력 추적이 필요할 만큼 중요해지면 각각 별도 이력 Object를 새로
만든다(Future Scope, Decision 009와 동일한 "Object는 필요한 만큼만" 원칙).

**6. 아래 항목은 Decision 009에서 이미 정한 대로 변경 없이 재확인만 한다** — 이번
결정으로 다시 논의하거나 확장하지 않는다.
- `Purchase_Channel__c`(Order, 값: 온라인/구장 굿즈샵)는 Marketing Cloud 때문이 아니라
  현재 Sales Cloud MVP의 Fan Journey/Fan Profile/Dashboard/Recommendation에서 바로
  쓰이므로 **MVP 확정 항목**이다 — Future Scope로 재분류하지 않는다.
- Owner(표준 `OwnerId`)는 Fan 분류 3축과 완전히 별개이며, 김매니저 1명뿐인 현재는
  OWD/Sharing Rule/Role Hierarchy/Queue를 추가 구현하지 않는다. OWD를 Private으로
  바꾸거나 VIP 담당자별 Sharing Rule을 새로 만들지 않는다.
- Marketing Cloud Next/Data Cloud 확장 파이프라인은 참조용 한 줄(Sales Cloud Fan Data
  → Data Cloud → Segment Builder → Marketing Cloud Next → Campaign/Journey/
  Personalization → 성과 분석)로만 Future Scope에 남기고, 현재 MVP Object를 Marketing
  Cloud 전용 구조로 미리 재설계하지 않는다.

### 이유

- `Fan_Value_Tier__c`로 이름을 바꾼 이유는 필드명만 보고도 "이건 등급 Picklist"임을
  알 수 있게 하기 위해서다 — Baby Team이 내일 Org에서 Object를 만들 때, 필드명이
  값의 성격(등급 vs 숫자)을 스스로 설명해야 매번 이 문서를 다시 찾아보지 않아도 된다.
- `Engagement_Score__c`를 `Engagement_Level__c`와 분리한 이유는 Fan Profile 요구사항이
  둘을 나란히 요구했고, 실제로도 "지금 몇 단계인가"(Level)와 "그 판단의 근거 수치가
  얼마인가"(Score)는 화면에서 다른 자리에 다른 목적으로 쓰이기 때문이다 — 다만 계산
  공식을 지금 정하면 나중에 실제 운영 데이터로 검증하기도 전에 잘못된 배점이 굳어질
  위험이 있어, 필드만 만들고 공식은 TBD로 남긴다(CLAUDE.md §5 MVP 원칙 — 고도화는
  실제 Org 구현 이후 결정).
- VIP 후보 흐름을 4단계로 명문화한 이유는, "감지"와 "확정"을 같은 것으로 오해하면
  Flow가 사람의 판단 없이 VIP 등급을 함부로 확정해버리는 것으로 잘못 구현될 위험이
  있기 때문이다 — 담당자의 최종 확인이라는 단계를 문서에 고정해두면 Flow 설계자(승우)와
  QA(혜준) 모두 같은 기준으로 검증할 수 있다.
- 나머지 항목(Purchase Channel, Owner/OWD, Marketing Cloud Next)을 "재확인"으로 명시한
  이유는, Decision 009에서 이미 내린 결정을 다시 논쟁거리로 되돌리지 않기 위해서다 —
  이 Decision의 목적은 새로 정하는 것이 아니라 Org 구현 직전에 흔들리지 않을 단일
  기준을 남기는 것이다(CLAUDE.md §7).

### 영향

- `03_SYSTEM.md` §2.1(Person Account): `Fan_Value__c` → `Fan_Value_Tier__c`로 필드명을
  바꾸고, `Engagement_Score__c`(Number, 계산 공식/자동화 TBD) 필드를 추가한다.
  `Engagement_Level__c`의 값 레이블을 "가입 팬/관심 팬/활동 팬/충성 팬/멤버십 팬/핵심
  팬"으로 갱신한다. Owner가 3축과 별개라는 설명, 이력 Object가 Current Segment 전용이라는
  설명을 보강한다.
- `03_SYSTEM.md` §4.5(VIP 후보 감지 Flow): 4단계 흐름과 "감지 ≠ 자동 변경" 문구를
  명시한다.
- `03_SYSTEM.md` §5(Future Scope): `Engagement_Score__c` 계산 공식/자동 계산 방식을
  구분해 항목을 추가하고, OWD 관련 표현에 Role Hierarchy/Queue를 포함한다.
- `04_DEMO.md` §4 Fan Profile 화면 설명에 Engagement Score, Membership 가입 여부를
  추가하고 필드명을 `Fan_Value_Tier__c`로 갱신한다.
- `docs/data/DEMO_DATASETS.md`, `docs/data/SAMPLE_DATA.md`: `Fan_Value__c` 표기를
  `Fan_Value_Tier__c`로 갱신하고, `Engagement_Score__c`를 TBD로 표기한다(임의의 예시
  점수를 확정 공식처럼 기록하지 않는다).

---

## Decision 011 — Season Object 도입, Game__c/Fan_Activity_Pattern__c 재설계 (Master-Detail + Roll-Up)

**상태**: 확정
**기록일**: 2026-08-11

### 배경

시즌별로 팬의 관람 참여도를 정량적으로 비교하고("이 팬이 2025시즌보다 2026시즌에 더
자주 왔는가"), 관람률(%)을 계산해야 한다는 필요가 제기됐다. 기존
`Fan_Activity_Pattern__c.Period__c`(Text)는 "2026 시즌"처럼 자유 텍스트로만 기간을
표현해서, 시즌 전체 경기 수·진행 경기 수 같은 집계 기준이 될 수 없었다. Game도
"예정/진행/취소" 상태나 홈/원정 구분이 없어, 취소된 경기까지 관람률 분모에 들어가는
문제가 있었다.

### 결정

**1. `Season__c`를 신규 Custom Object로 만든다.**

| Field (API Name) | 타입 | 설명 |
|---|---|---|
| Name | Text | 예: "2026 시즌" |
| `Total_Games__c` | Number | 시즌 전체 경기 수(취소 포함, 수동 입력) |
| `Played_Games__c` | Roll-Up Summary (COUNT, `Game__c.Status__c = Played`) | 실제 진행 경기 수 — 관람률 계산의 분모 |

**2. `Game__c` → `Season__c`는 Master-Detail(Master = Season)로 연결한다.** `Home_Away__c`
(Picklist: Home/Away), `Status__c`(Picklist: Scheduled/Played/Cancelled) 필드를
추가한다. 관람률 계산 시 `Status__c = Cancelled`인 경기는 분모에서 제외한다.

이 관계 타입은 별도로 논의하지 않고 **기존에 이미 승인된 결정의 기술적 연장**으로
확정한다 — `Played_Games__c`를 Roll-Up으로 자동 집계하기로 이미 정했고(아래 §3),
Admission__c↔Attendance_Record__c도 같은 이유로 Master-Detail을 확정했다(Decision
012). Lookup으로 하면 `Played_Games__c`를 누군가 수동으로 세야 하는데, 이는 "경기
취소/진행 여부를 자동 반영한다"는 이번 결정의 취지에 어긋난다.

**3. `Fan_Activity_Pattern__c`를 Fan + Season 기준으로 재설계한다.** `Period__c`(Text)를
삭제하고 `Season__c`(Lookup)를 추가한다 — 한 Fan은 시즌별로 하나의 Activity Pattern을
가진다("Fan A + 2025", "Fan A + 2026"처럼). `Attendance_Rate__c`(Formula, Percent)를
추가한다 — 별도 저장 없이 `Games_Attended__c ÷ Season__r.Played_Games__c × 100`으로
계산한다.

> 예: 시즌 예정 경기 144경기 / 취소 2경기 / 실제 진행 142경기 / 팬 관람 36경기 →
> 관람률 25.35%

**4. MVP는 시즌 단위 집계로 구현한다.** 월별/분기별 Pattern은 Future Scope로 둔다.

**5. `Fan_Activity_Pattern__c`에 `Fan__c` + `Season__c` 조합 기준 Duplicate Rule을
추가한다** — 한 팬은 한 시즌에 Activity Pattern을 1건만 가질 수 있도록 Block한다
(Matching Rule: 두 필드 모두 Exact).

### 이유

- Season을 Object로 만들지 않으면 "시즌 전체 경기 수"와 "실제 진행 경기 수"를 어딘가
  수동으로 관리해야 하고, 경기 취소가 생길 때마다 관람률 계산이 틀어진다 — Object로
  집계 기준 자체를 자동화하는 것이 Baby Team의 운영 부담을 줄인다.
- `Period__c`(Text)를 유지하면 "2026 시즌"과 "2026시즌"처럼 표기가 흔들려도 시스템이
  감지하지 못한다. `Season__c`(Lookup)로 바꾸면 오타로 인한 중복/누락을 Duplicate
  Rule로 원천 차단할 수 있다.
- Master-Detail을 Lookup 대신 선택한 이유는 Decision 012와 동일한 원칙(Roll-Up
  자동화가 필요한 관계는 Master-Detail로 만든다)을 일관되게 적용하기 위함이다.

### 영향

- `03_SYSTEM.md` §1.2: Custom Object 목록에 `Season__c` 추가.
- `03_SYSTEM.md` §2: `Season__c` 필드 상세 섹션 신설, `Game__c`에 `Season__c`/
  `Home_Away__c`/`Status__c` 추가, `Fan_Activity_Pattern__c`의 `Period__c` 삭제 →
  `Season__c`/`Attendance_Rate__c` 추가.
- `03_SYSTEM.md` §3(ERD): `Season__c`↔`Game__c`, `Season__c`↔`Fan_Activity_Pattern__c`
  관계를 추가한다.
- `01_PROJECT.md` §4(Business Entity 목록), §6.1(전체 매핑 표): Season Entity를
  추가한다(이번 Workflow 분석 이후 새로 확정된 Entity로 표시).
- `docs/data/DEMO_DATASETS.md`, `docs/data/SAMPLE_DATA.md`: Season 레코드와
  `Fan_Activity_Pattern__c`의 `Period__c` 값을 `Season__c` 참조로 갱신해야 한다(다음
  데이터 작업 시 반영).

---

## Decision 012 — Admission__c ↔ Attendance_Record__c를 Master-Detail로 전환, 집계는 Roll-Up Summary로 처리

**상태**: 확정
**기록일**: 2026-08-11

### 배경

`Attendance_Record__c.Total_Admissions__c`/`First_Admission_Date__c`/
`Last_Admission_Date__c`가 실제로 "누가 언제 갱신하는지"가 문서에 명확히 정의된 적이
없었다 — 사실상 수동 또는 별도 집계 Flow에 의존한다고 암묵적으로 가정하고 있었다.
팬 수가 늘어나면 이런 수동/Flow 집계는 누락되거나 느려질 위험이 있다.

### 결정

`Admission__c.Attendance_Record__c`를 **Master-Detail**(Detail = `Admission__c`,
Master = `Attendance_Record__c`)로 추가한다. `Total_Admissions__c`(COUNT),
`First_Admission_Date__c`(MIN, `Admission_Time__c`), `Last_Admission_Date__c`(MAX,
`Admission_Time__c`)를 **Roll-Up Summary**로 전환한다 — 이 3개 필드를 갱신하던
별도의 집계 Flow는 더 이상 만들지 않는다.

단, Master-Detail 관계는 **부모(`Attendance_Record__c`)가 먼저 존재해야 자식
(`Admission__c`)을 만들 수 있다**는 제약이 있다. 이를 위해 Welcome Campaign
Flow(Person Account 생성 트리거)에 `Attendance_Record__c` 1건 생성 단계를 추가한다
— 별도 Flow로 분리하지 않고 같은 트리거(Account 생성)에 통합한다(Flow를 2개 두면
실행 순서까지 신경 써야 해서 오히려 복잡해진다).

`Attendance_Record__c`에는 기존과 동일하게 `Fan__c` 기준 팬당 1건 Duplicate Rule을
유지한다(Matching Rule: `Fan__c` Exact, Action on Create = Block).

### 이유

- Roll-Up Summary는 Master-Detail 관계에서만 만들 수 있다 — Lookup을 유지하면서
  "자동 집계"를 얻을 방법이 없다.
- Master-Detail 자식은 부모의 Sharing 설정을 그대로 상속한다 — 별도 공유 규칙을
  추가로 설계할 필요가 없어진다.
- Attendance_Record__c 생성을 Welcome Campaign Flow에 통합한 이유는, Account
  생성이라는 같은 트리거에 Flow를 여러 개 걸어두면 실행 순서 보장이 새로운 문제로
  등장하기 때문이다 — 이미 있는 Flow에 단계 하나를 추가하는 편이 더 단순하다.

### 영향

- `03_SYSTEM.md` §2(Admission__c, Attendance_Record__c): `Attendance_Record__c`
  Master-Detail 필드 추가, 집계 3필드를 Roll-Up Summary로 변경.
- `03_SYSTEM.md` §3(ERD): `Admission__c` → `Attendance_Record__c` Master-Detail
  관계를 명시적으로 추가한다.
- `03_SYSTEM.md` §4.4(Welcome Campaign Flow): `Attendance_Record__c` 1건 생성 단계를
  다이어그램에 추가한다.
- `03_SYSTEM.md` §4.2(Trigger → Action 매핑): "First Visit Guide" 트리거를
  `Attendance_Record__c` 존재 여부 확인 대신 `Total_Admissions__c`(Roll-Up) = 1로
  판별하도록 갱신한다.
- `03_SYSTEM.md`에 Duplicate Rule 섹션을 신설해 이 규칙을 명문화한다(기존에는 문서에
  규칙 자체가 없었다).

---

## Decision 013 — Order에 Payment_Status__c/Refund 필드 추가, Membership_End_Date__c를 Coverage_Start/End_Date__c로 통합

**상태**: 확정
**기록일**: 2026-08-11

### 배경

Cloud Alpacas는 티켓·시즌권·멤버십·굿즈 4종을 판매하는데, 구매 이후 상태 변화(취소·
환불)를 기록할 곳이 없었다. 또한 `Membership_End_Date__c`는 이름 그대로 Membership
전용으로 만들어졌지만, 실제로는 Season Pass(시즌권)도 같은 성격의 "적용 기간"이
필요해서 이름이 좁았다.

### 결정

**1. `Order`에 결제/환불 상태 필드를 추가한다.**

| Field (API Name) | 타입 | 설명 |
|---|---|---|
| `Payment_Status__c` | Picklist (Paid/Cancelled/Refunded) | 표준 `Status`(Draft/Activated)와는 **다른 축** — 결제/환불 상태를 표현한다. |
| `Refund_Date__c` | Date | 환불 처리일. |
| `Refund_Reason__c` | Picklist (단순변심/상품불량/경기취소/일정변경) | 환불 사유. |

**2. `Membership_End_Date__c`를 삭제하고, `Coverage_Start_Date__c`/
`Coverage_End_Date__c`(Date)로 대체한다.** 멤버십과 시즌권이 공통으로 쓰는 "적용
기간" 필드로 통합한다.

**3. MVP는 Order 전체 단위 환불만 지원한다.** 부분 환불(OrderItem 단위 환불)은
Future Scope로 남긴다.

**4. 환불 문의는 기존 `Case.Related_Order__c`로 Order와 연결한다** — 이미 존재하는
필드이므로 새 필드를 추가하지 않는다.

**5. `Fan_Activity_Pattern__c.Total_Spend__c` 계산 시 `Payment_Status__c` =
Refunded/Cancelled인 Order는 집계에서 제외한다.** 다만 이 집계를 **누가/언제**(Flow
또는 Apex) 계산하는지는 이번에 확정하지 않는다(TBD) — `03_SYSTEM.md` §4.6에 이미
있는 "아직 정의되지 않은 Trigger" 목록과 같은 방식으로 미정 상태를 문서화한다.

### 이유

- `Payment_Status__c`를 표준 `Status`와 분리한 이유는 Decision 009·010에서 이미
  적용한 원칙("서로 다른 개념을 같은 필드/이름으로 섞지 않는다")과 같다 — Order가
  Draft/Activated인지와, 결제가 Paid/Refunded인지는 독립된 질문이다.
  `Order.Status`(Draft에서만 Product 추가 가능)와 `Payment_Status__c`(결제 이후의
  상태)는 시점부터 다르다.
- 부분 환불을 지금 지원하지 않는 이유는, 한 Order에 OrderItem이 여러 개(예: 티켓
  2장) 있을 때 그중 1개만 환불하는 케이스까지 지원하려면 필드를 OrderItem에 둬야
  하는데, 이는 지금 팀 규모와 Demo 범위에서 필요한 복잡도를 넘어선다(CLAUDE.md §5
  MVP 원칙).
- `Coverage_Start/End_Date__c`로 이름을 바꾼 이유는, 필드명만 보고도 "멤버십과
  시즌권이 공통으로 쓴다"는 걸 알 수 있게 하기 위해서다 — Decision 010이
  `Fan_Value_Tier__c`에 적용한 것과 같은 원칙(필드명이 스스로 용도를 설명해야 한다).

### 영향

- `03_SYSTEM.md` §2(Order): `Membership_End_Date__c` 삭제, `Coverage_Start_Date__c`/
  `Coverage_End_Date__c`/`Payment_Status__c`/`Refund_Date__c`/`Refund_Reason__c` 추가.
- `03_SYSTEM.md` §2(Fan_Activity_Pattern__c): `Total_Spend__c` 설명에 "Refunded/
  Cancelled Order 제외" 규칙을 추가한다.
- `03_SYSTEM.md` §4.6: `Total_Spend__c` 계산 주체(Flow/Apex 미정)를 기존 표에
  항목으로 추가한다.
- `03_SYSTEM.md` §5(Future Scope): 부분 환불(OrderItem 단위)을 Future Scope
  항목으로 추가한다.

---

## Decision 014 — Fan Profile은 원천 데이터를 Account에 중복 저장하지 않고 Related List로 참조

**상태**: 확정
**기록일**: 2026-08-11

### 배경

Fan Profile 화면에 "최근 관람일, 총 관람 횟수, 총 구매금액, 구매 빈도, 최근 활동일"을
보여줘야 하는데, 이 값들을 Account(Person Account)의 새 필드로 또 만들 것인지, 아니면
이미 있는 원천 Object(`Attendance_Record__c`, `Fan_Activity_Pattern__c`, `Order`,
`Engagement_Signal__c`)를 화면에서 그대로 참조할 것인지 결정이 필요했다.

### 결정

Fan Profile이 보여주는 아래 항목은 **Account 필드로 복제하지 않고, 원천 Object를
Related List/Lightning Component로 그대로 참조**한다.

| 표시 항목 | 원천 Object | 원천 필드 |
|---|---|---|
| 최근 관람일 / 총 관람 횟수 | `Attendance_Record__c` | `Last_Admission_Date__c` / `Total_Admissions__c` |
| 총 구매금액 | `Fan_Activity_Pattern__c` | `Total_Spend__c` |
| 구매 빈도 | `Order` | (Fan 기준 Order 건수) |
| 최근 활동일 | `Engagement_Signal__c` | `Signal_Date__c`(최신 1건) |

반면 `Current_Segment__c`/`Engagement_Level__c`/`Engagement_Score__c`/
`Fan_Value_Tier__c`는 원천 복제가 아니라 **Fan 자체의 상태값**이므로 지금처럼
Account에 직접 저장한다(Decision 009·010과 변경 없음).

### 이유

- 위 4개 항목은 각각 이미 자기 Object(Attendance Record, Fan Activity Pattern,
  Order, Engagement Signal)에 원본이 존재한다 — Account에 또 필드를 만들면 원본이
  바뀔 때마다 두 곳을 동기화해야 하는 불필요한 자동화가 늘어난다.
- 반대로 Current Segment/Engagement Level/Fan Value는 여러 원천을 종합한 "판단
  결과"이지 특정 Object의 단순 복제값이 아니다 — 이 값들은 원본이 따로 없으므로
  Account에 두는 것이 캐시가 아니라 원래 자리다(§2.1의 "왜 캐시와 이력을 나누나"
  설명과 같은 원칙).

### 영향

- `03_SYSTEM.md`에 "Fan Profile 설계 원칙" 섹션을 신설해 위 표를 그대로 반영한다.
- `04_DEMO.md` §4 Fan Profile 화면 설명이 이 원칙(원천 참조 vs Account 직접 저장)을
  따르는지 이후 확인이 필요하다(이번 갱신 범위 밖).

# 00_STORY.md — Cloud Alpacas Customer 360 Story

> 이 문서는 "왜 이 프로젝트가 존재하는가"를 설명한다.
> Business Goal, Pain Point, Persona, Story(Customer Journey)까지만 다루며,
> Domain/Entity/Salesforce Object 설계는 다루지 않는다(→ `01_PROJECT.md`, `03_SYSTEM.md`).

---

## 1. Business Goal

> **신규 팬을 이해하고, 적절한 시점에 개인화된 액션을 통해 충성 팬으로 성장시키고,
> 장기적으로 시즌권 구매까지 이어지는 Fan Lifetime Value를 높인다.**

모든 설계와 구현은 이 목표를 달성하기 위한 수단이다.

이 목표는 **Phase 1(B2C Fan 360 MVP)**의 목표다. Phase 1이 끝났다고 사라지는 것이 아니라 Phase 2에서도 계속 유지된다 — Phase 2는 이 목표를 대체하지 않고, 그 위에 새로운 목표를 더한다(CLAUDE.md §5).

### [P2] Phase 2 Business Goal

> **Phase 1에서 쌓은 Fan 360 데이터를 활용해, Cloud Alpacas 팬층과 궁합이 좋은 기업을 발굴하고, 단기 Collaboration으로 가능성을 검증한 뒤, 장기 Partnership/Sponsorship으로 발전시켜 구단의 수익 기반을 다변화한다.**

Cloud Alpacas는 팬이 늘고 있지만 구단 재정 운영상 적자 상황이다 — 팬을 키우는 것만으로는 구단의 지속 가능성 문제가 풀리지 않는다. Phase 2는 Phase 1이 만든 Fan 360 데이터를 "팬을 더 이해하는 데"뿐 아니라 "구단의 수익 구조를 넓히는 데"에도 쓰기 시작하는 단계다.

---

## 2. Pain Point — Salesforce 도입 전 Cloud Alpacas의 문제

**1. 팬 정보를 한눈에 볼 수 없다.**
티켓, 굿즈, 멤버십, 앱, 문의 데이터가 모두 다른 시스템에 흩어져 있다.
→ 팬은 보이지 않고 데이터만 보인다.

**2. 팬을 이해하지 못한다.**
이루키가 '문선수'를 좋아하는지, 직관을 자주 오는지, 굿즈를 샀는지 연결해서 볼 수 없다.
→ 360° Fan View가 없다.

**3. 팬을 세분화하지 못한다.**
누가 Ticket Only Fan인지, Membership Candidate인지, VIP 후보인지 자동으로 알 수 없다.
결국 모든 팬에게 같은 이벤트, 같은 쿠폰, 같은 메시지를 보낸다.

**4. 적절한 타이밍을 놓친다.**
VIP가 될 가능성이 높은 팬도 엑셀을 정리한 후에야 발견한다.
→ "한 달 전에 알았으면 멤버십을 가입했을 텐데…"

**5. 무엇을 해야 할지 우선순위를 알 수 없다.**
신규 팬이 1,000명 생겨도 누구에게 굿즈를 추천해야 하는지, 멤버십을 제안해야 하는지,
시즌권을 권해야 하는지 판단할 수 없다.
→ 데이터는 많지만 Action이 없다.

### [P2] Phase 2 Pain Point — 이 매니저가 겪는 문제

**1. 팬은 늘고 있는데 왜 적자인가?**
티켓·멤버십·굿즈 매출만으로는 구단 재정 적자를 해결하지 못한다. 팬 성장과 구단 재정 사이의 간극을 메울 새로운 수익원이 필요하다.

**2. 어떤 기업을 스폰서/제휴 후보로 찾아야 할지 알 수 없다.**
"유명한 회사"에 무작정 제안서를 보내는 것과, 실제로 우리 팬층과 맞는 기업을 찾는 것은 다르다. 지금은 이 판단 근거가 없다.

**3. 우리 팬이 실제로 무엇에 관심 있는지 모른 채 영업하게 된다.**
팬이 어떤 상품·브랜드·선수·콘텐츠에 반응하는지 정리된 데이터 없이, 감이나 인맥에 의존해 제휴를 제안하게 된다.

**4. 후보 기업과 팬층의 궁합(Fit)을 검증할 방법이 없다.**
"이 브랜드의 고객층이 우리 팬층과 정말 겹치는가?"를 확인할 근거 없이 제안이 오가면, 계약이 성사돼도 실제 반응이 기대에 못 미칠 위험이 크다.

**5. 처음부터 장기 계약을 제안하기엔 리스크가 크다.**
검증되지 않은 상대와 장기 Sponsorship 계약부터 시작하면, 맞지 않았을 때 되돌리기 어렵다.

**6. Collaboration 성과를 다음 판단에 활용할 방법이 없다.**
설령 단기 협업을 하더라도, 그 결과(팬 반응·참여율 등)를 근거로 "이 파트너와 계속 갈지"를 판단할 체계가 없다.

---

## 3. FRM Team

> "우리는 고객이 아니라 팬을 관리한다."

Cellsforce는 Cloud Alpacas의 **Fan Relationship Management(FRM) Team**이 되어 이 문제를 해결한다.

**Mission**
팬 데이터를 기반으로 팬의 현재 상태를 이해하고, 가장 적절한 다음 행동(Next Best Action)을
실행하여 Fan Lifetime Value를 높인다.

**KPI**
- 신규 팬 활성화율
- 첫 경기 관람 전환율
- 재방문율
- 첫 굿즈 구매율
- 멤버십 가입률
- 시즌권 구매 전환율
- Fan Lifetime Value

> **[P2] Phase 2에서는 이 Mission이 확장된다.** Cellsforce는 팬을 이해하는 것에서 나아가, 그 이해를 구단의 B2B Collaboration/Sponsorship 의사결정에도 활용한다 — 담당 Persona는 §4의 **이 매니저**를 참고한다.

---

## 4. Persona

### 김매니저 — Cloud Alpacas FRM Manager
Salesforce Customer 360을 사용하는 사용자(User).
**Mission**: 팬 데이터를 분석하여 팬을 이해하고, 가장 적절한 Next Best Action을 실행하여
신규 팬을 충성 팬으로 성장시킨다.

### 이루키 — 27세, 직장인 (신규 팬)
- 야구를 거의 본 적이 없다.
- SNS에서 우연히 문선수의 영상을 보고 처음 Cloud Alpacas에 관심을 갖게 된다.
- 친구와 함께 첫 직관을 경험한다.
- 응원 문화와 경기장의 분위기에 빠져 점점 클라우드 팬이 되어간다.

### [P2] 이 매니저(가칭) — Cloud Alpacas Partnership/Sponsorship Manager

Cloud Alpacas의 스폰서 및 제휴 담당자. 팬은 늘고 있지만 구단 재정 운영상 적자인 상황에서, 새로운 스폰서·제휴사를 발굴해 구단의 수익 기반을 넓히는 책임을 맡고 있다.

**Mission**: Fan 360 데이터를 근거로 Cloud Alpacas 팬층과 궁합이 좋은 기업을 찾아내고, 단기 Collaboration으로 가능성을 검증한 뒤 장기 Partnership/Sponsorship으로 발전시킨다.

**주요 고민**
- 팬은 늘고 있는데 왜 구단은 여전히 적자인가?
- "유명한 회사"가 아니라, 우리 팬층과 실제로 Fit이 높은 기업을 어떻게 찾는가?
- 우리 팬이 실제로 어떤 상품·브랜드·선수·콘텐츠에 반응하는지 어떻게 알 수 있는가?
- 후보 기업의 고객층과 우리 팬층이 정말 겹치는지 어떻게 검증하는가?
- 검증되지 않은 상대와 곧바로 장기 계약을 맺는 리스크를 어떻게 줄이는가?
- 작은 Collaboration의 성과를 장기 Partnership/Sponsorship 판단에 어떻게 활용하는가?

> 이 매니저의 여정은 이루키 같은 Phase 1 팬의 데이터와 이어져 있다 — 이루키 같은 팬들의 데이터가 쌓일수록, 이 매니저가 활용할 수 있는 근거도 함께 쌓인다. (이름은 아직 가칭이며, 세부 프로필은 이후 확정한다 — TBD)

---

## 5. Phase 1 Story — 이루키의 Customer Journey

```
SNS → 회원가입 → 첫 티켓 구매 → 첫 직관 → 첫 굿즈 구매 → 재방문 → 멤버십 가입 → 충성팬
```

김매니저는 Customer 360을 통해 이루키가 이 여정의 어디쯤 있는지 확인하고,
가장 적절한 시점에 개인화된 Action을 실행한다.

---

## 6. Current Segment (Life Cycle) — 팬의 현재 상태 정의

> Fan을 분류하는 축은 3개다 — **Current Segment(Life Cycle)**, **Engagement Level**,
> **Fan Value**(05_DECISIONS.md Decision 009). 이 표는 그중 **Current Segment(Life
> Cycle)** — "지금 이 팬이 활동 주기의 어디에 있는가" — 만 다룬다. "Segment"라는 단어를
> Engagement Level이나 Fan Value(VIP 포함)와 혼용하지 않는다. 나머지 두 축의 필드
> 정의는 `03_SYSTEM.md` §2.1에서 다룬다.

| Segment(Life Cycle) | 정의 | 주요 Action |
|---|---|---|
| New Fan (미활성) | 가입만 하고 아직 행동 없음 | 첫 티켓 구매 유도 |
| Active Fan | 최근 90일 활동 | 개인화 추천 |
| At-Risk Fan | 활동 감소 | 이탈 방지 |
| Dormant Fan | 181~365일 활동 없음 | 복귀 캠페인 |
| Churned Fan | 365일 이상 활동 없음 | 저빈도 재활성화 |
| Unreachable Fan | 수신 불가 | 동의/연락처 관리 |

---

## 7. FRM Team의 Next Best Action (Phase 1)

| 이루키의 상태 | FRM Team Action |
|---|---|
| 회원가입만 함 | Welcome Campaign |
| 티켓 구매 안 함 | First Ticket Campaign |
| 첫 직관 완료 | First Visit Guide |
| Ticket Only Fan | First Merchandise Campaign |
| 굿즈 구매 완료 | Favorite Player Campaign |
| 재방문 시작 | Membership Campaign |
| 충성 팬 | Season Ticket Recommendation *(향후)* |
| At-Risk Fan | Win-back Campaign *(향후)* |

---

## 8. [P2] Phase 2 Story — B2B Collaboration/Sponsorship Journey

### 8.1 왜 구단이 B2B로 확장해야 하는가

Phase 1은 이루키 같은 신규 팬을 충성 팬으로 성장시키는 데 집중했다. 하지만 팬이 늘어난다고 구단의 재정 문제가 저절로 풀리지는 않는다 — Cloud Alpacas는 팬이 증가하는 중에도 구단 재정 운영상 적자 상태다. 티켓·멤버십·굿즈 매출만으로 감당하기 어려운 이 간극을, 새로운 스폰서·제휴사 확보라는 수익원으로 메워야 한다. Phase 2가 B2B Collaboration/Sponsorship을 다루는 이유다.

### 8.2 왜 Fan 360 데이터가 필요한가

기존 방식이라면 스폰서/제휴 영업은 "유명한 회사에 제안서를 보내는" 방식에 가깝다 — 실제로 그 기업의 고객층이 Cloud Alpacas 팬층과 맞는지 확인할 근거가 없다. Phase 1에서 쌓은 Fan 360 데이터(관심사, 구매 이력, 관람 패턴, Engagement 수준 등)는 이 "맞는지 안 맞는지"를 판단할 수 있는 근거다. B2B 영업이 감이 아니라 데이터에서 출발해야 하는 이유가 여기에 있다.

### 8.3 이 매니저의 여정 — Fan Insight에서 Partnership까지

```
Fan 360 Data 분석 → 팬층 특성 발견 → 궁합 좋은 기업 가설 → 후보 발굴 → Business Fit 검토
→ Lead 등록 → 접촉/제안 → 단기 Collaboration → 성과 검증 → 장기 Partnership/Sponsorship
```

**1. Fan 360 Data 분석 → 팬층 특성 발견**

이 매니저는 Fan 360에 쌓인 관심사·구매·관람·Engagement 데이터를 살펴보다가, 특정 팬층이 뚜렷한 특성을 갖는다는 것을 발견한다.

> 예시: "특정 연령·성별 팬 비중이 늘고 있고, 이 그룹은 특정 선수 관련 굿즈 구매율과 SNS 반응률이 유독 높다." — 실제 팬층 정의와 수치는 아직 확정되지 않았다(TBD). CLAUDE.md에서 예시로 든 "10~30대 여성 팬층" 시나리오도 같은 성격의 가설이며, 아직 데이터로 확정된 사실이 아니다.

**2. 팬층 특성 → 궁합 좋은 기업 가설**

이 특성을 근거로 "이런 팬층과 잘 맞는 기업/브랜드는 어떤 곳일까?"라는 가설을 세운다. 이 단계에서 "구단이 먼저 제안할 후보"가 감이 아니라 데이터 기반 가설이 된다. 실제 산업군·기업명은 아직 확정되지 않았다(TBD).

**3. 가설 → 후보 발굴 → Business Fit 검토**

가설에 맞는 실제 기업 후보를 찾고, 그 기업의 고객층이 정말 Cloud Alpacas 팬층과 겹치는지 검토한다. "유명한 회사"가 기준이 아니라 "우리 팬과 Fit이 높은 회사"가 기준이다.

**4. Business Fit 검토 → 잠재 후보 관리 → 영업 기회로 발전**

Fit이 확인된 후보는 아직 계약 상대가 아니라 "가능성 있는 상대"다. 이 매니저는 이런 후보를 별도의 영업 대상(Lead)으로 관리하며 접촉·제안을 이어간다.

**5. 왜 바로 장기 Sponsorship이 아니라 단기 Collaboration부터인가**

검증되지 않은 상대와 곧바로 장기 계약을 맺는 것은 리스크가 크다 — Fit 가설이 틀렸을 경우 되돌리기 어렵다. 그래서 이 매니저는 먼저 작은 단위의 Collaboration(예: 한정 상품, 짧은 캠페인)을 제안해 가설을 실제로 검증한다.

**6. Collaboration 성과 → 다음 의사결정**

Collaboration이 진행되면 팬의 실제 반응(참여, 구매, 관심)이 쌓인다. 이 매니저는 이 성과를 Fan 360 데이터와 함께 다시 살펴보며 "이 파트너와 계속 갈지"를 판단한다.

**7. 장기 Partnership/Sponsorship으로 발전**

Collaboration 성과가 좋으면, 이 매니저는 이를 근거로 장기 Partnership/Sponsorship을 제안한다 — 이번에는 가설이 아니라 실제 검증된 데이터를 근거로 한 결정이다.

> 이 흐름에서 반드시 필요한 것은 **"Fan 360 데이터 → 팬층 특성 → 기업 가설"이라는 중간 단계**다. "팬 데이터가 있으니 스폰서를 찾는다"가 아니라, "팬 데이터가 특정 팬층의 특성을 보여주고, 그 특성이 기업 궁합의 가설로 이어진다"는 논리적 연결이 이 Story의 핵심이다.

---

## 9. [P2] Phase 2 — B2B Next Best Action / Decision Flow

§7이 "이루키(팬)의 상태 → FRM Team Action"을 정의했다면, 이 표는 "이 매니저가 발견한 신호 → 판단/Action"을 정의한다.

| 발견한 신호 | 이 매니저의 Action |
|---|---|
| 특정 팬층(관심사·구매·관람 패턴)이 뚜렷하게 드러남 | 궁합 좋은 기업/브랜드 가설 수립 |
| 가설에 맞는 기업 후보 발견 | Business Fit 검토 |
| Fit이 확인됨 | 잠재 제휴사로 등록, 접촉·제안 |
| 제안이 받아들여짐 | 단기 Collaboration 시작 |
| Collaboration 진행 중 | 팬 반응/성과 데이터 수집 |
| Collaboration 성과가 좋음 | 장기 Partnership/Sponsorship 제안 |
| Collaboration 성과가 기대에 못 미침 | 재검토 또는 관계 종료 *(판단 기준 TBD)* |

> 이 표의 각 단계를 Salesforce에서 어떤 Object/Field/Flow로 자동화할지는 이 문서(00_STORY.md)의 범위가 아니다 — `01_PROJECT.md`, `03_SYSTEM.md`, `05_DECISIONS.md`에서 다룬다.
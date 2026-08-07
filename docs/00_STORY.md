# 00_STORY.md — Cloud Alpacas Customer 360 Story

> 이 문서는 "왜 이 프로젝트가 존재하는가"를 설명한다.
> Business Goal, Pain Point, Persona, Story(Customer Journey)까지만 다루며,
> Domain/Entity/Salesforce Object 설계는 다루지 않는다(→ `01_PROJECT.md`, `03_SYSTEM.md`).

---

## 1. Business Goal

> **신규 팬을 이해하고, 적절한 시점에 개인화된 액션을 통해 충성 팬으로 성장시키고,
> 장기적으로 시즌권 구매까지 이어지는 Fan Lifetime Value를 높인다.**

모든 설계와 구현은 이 목표를 달성하기 위한 수단이다.

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

---

## 5. Story — 이루키의 Customer Journey

```
SNS → 회원가입 → 첫 티켓 구매 → 첫 직관 → 첫 굿즈 구매 → 재방문 → 멤버십 가입 → 충성팬
```

김매니저는 Customer 360을 통해 이루키가 이 여정의 어디쯤 있는지 확인하고,
가장 적절한 시점에 개인화된 Action을 실행한다.

---

## 6. Fan Segment — 팬의 상태 정의

> Segment는 곧 팬의 Customer Status다.

| Segment | 정의 | 주요 Action |
|---|---|---|
| New Fan (미활성) | 가입만 하고 아직 행동 없음 | 첫 티켓 구매 유도 |
| Active Fan | 최근 90일 활동 | 개인화 추천 |
| At-Risk Fan | 활동 감소 | 이탈 방지 |
| Dormant Fan | 181~365일 활동 없음 | 복귀 캠페인 |
| Churned Fan | 365일 이상 활동 없음 | 저빈도 재활성화 |
| Unreachable Fan | 수신 불가 | 동의/연락처 관리 |

---

## 7. FRM Team의 Next Best Action

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
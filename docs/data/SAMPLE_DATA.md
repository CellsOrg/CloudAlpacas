# SAMPLE_DATA.md — Cloud Alpacas 참고/마스터 데이터

> 이 문서는 Demo 시나리오와 무관하게 **Salesforce Org에 항상 존재해야 하는 기준 데이터**
> (선수, 상품, 경기 일정, 배경이 되는 다른 Fan들)를 담는다. 이루키 한 사람의 여정을
> 시간순으로 따라가는 시나리오 데이터는 `DEMO_DATASETS.md`를 참고한다(CLAUDE.md §7
> 중복 방지 — 같은 값을 두 문서에 쓰지 않는다).
>
> 담당: 아론(Demo Lead / Business Analyst), 검증: 혜준(`02_TEAM_GUIDE.md` §2).
> Object/Field 정의 근거는 `03_SYSTEM.md`를 따른다.

---

## 1. Player (Contact, RecordType = Player)

| Name | Position__c | Uniform_Number__c | 비고 |
|---|---|---|---|
| 문태양 (문선수) | 투수 | 21 | 00_STORY.md 이루키의 최애 선수 |
| 강도윤 | 내야수 | 7 | |
| 서준혁 | 외야수 | 30 | |
| 이하늘 | 포수 | 2 | |

> **왜 4명뿐인가?** Demo에 필요한 최소 인원이다 — 문태양(최애 선수 시나리오)과, 팀
> 로스터가 비어 보이지 않을 정도의 배경 선수 3명. 더 필요해지면 이 표에 추가한다.

---

## 2. Product2

### 2.1 Ticket (RecordType = Ticket)

| Name | 가격(PricebookEntry) | 비고 |
|---|---|---|
| 티켓 - 1루 응원석 | 15,000원 | |
| 티켓 - 3루 응원석 | 15,000원 | |
| 티켓 - 외야석 | 10,000원 | |
| 티켓 - 프리미엄석 | 35,000원 | |

### 2.2 Season Pass (RecordType = Season Pass)

| Name | 가격 |
|---|---|
| 시즌권 - 스탠다드 | 500,000원 |
| 시즌권 - VIP | 1,200,000원 |

### 2.3 Membership (RecordType = Membership, `Tier__c`)

| Name | Tier__c | 가격(연) |
|---|---|---|
| 멤버십 - Standard | Standard | 30,000원 |
| 멤버십 - Premium | Premium | 80,000원 |
| 멤버십 - VIP | VIP | 200,000원 |

### 2.4 Goods (RecordType = Goods, `Category__c`, `Related_Player__c`)

| Name | Category__c | Related_Player__c | 가격 |
|---|---|---|---|
| 문태양 유니폼(홈) | Uniform | 문태양 | 89,000원 |
| 문태양 유니폼(어웨이) | Uniform | 문태양 | 89,000원 |
| 구단 응원타올 | Cheering Item | (없음) | 12,000원 |
| 구단 모자 | Accessory | (없음) | 25,000원 |

---

## 3. Game (`Game__c`)

> Cloud Alpacas의 상대팀은 한화 이글스가 아니라 **이 프로젝트를 위해 만든 가상의
> 팀명**을 쓴다(05_DECISIONS.md Decision 001 — Cloud Alpacas 세계관은 처음부터 끝까지
> 가상이어야 자연스럽다).

| Game_Date__c | Opponent__c | Result__c |
|---|---|---|
| 2026-04-04 | 블루웨일스 | Win |
| 2026-04-18 | 선더버즈 | Loss |
| 2026-05-02 | 레드폭스 | Win |
| 2026-05-16 | 블루웨일스 | Win |
| 2026-05-30 | 스톰이글스(가상) | Draw |

> DEMO_DATASETS.md의 이루키 여정은 이 경기들 중 일부를 사용한다 — 실제 어느 경기를
> 썼는지는 `DEMO_DATASETS.md`에서 확인한다.

---

## 4. 배경 Fan (이루키 외 다른 팬)

Fan 360 Dashboard의 목록 화면이 이루키 한 명만 있으면 어색하다 — 대시보드/세그먼트
화면이 "여러 팬 중 하나"라는 맥락을 보여줄 수 있도록 배경 인물을 최소한으로 둔다.

| Name | Current_Segment__c | 비고 |
|---|---|---|
| 박서연 | Active Fan | 재방문 팬 예시 |
| 김도현 | Dormant Fan | 장기 무활동 팬 예시 |
| 최민재 | New Fan | 최근 가입 팬 예시 |

> 이 3명의 상세 이력(Admission, Order 등)은 최소한으로만 채운다 — Demo의 주인공은
> 이루키다. 대시보드 화면에서 "여러 Segment가 섞여 있다"는 것만 보여주면 충분하다.

---

## 5. Future Scope

- Player/Goods/Game 수가 부족하다고 느껴지면(예: 화면이 너무 비어 보임) 이 문서에
  추가한다 — 다만 Demo에 실제로 등장하지 않는 데이터는 과도하게 늘리지 않는다.

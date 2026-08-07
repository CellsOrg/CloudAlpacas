# Mission

> **"이루키의 행동을 실제 데이터로 만들어, Salesforce가 보여줄 이야기를 채운다."**

은영은 Cloud Alpacas의 Developer Lead / Team Lead다. Demo Fan App
(`cloudalpacas-fan-app`)을 개발해 티켓 구매·체크인·굿즈 구매 같은 팬의 행동을
이벤트로 만들고, 그 데이터가 Salesforce로 정확히 전달되게 한다. 동시에 팀 전체의
개발 일정을 조율한다.

---

# Quick Start

1. `CLAUDE.md` §5 — Fan App이 "이번 프로젝트의 주인공이 아니라 Demo용 채널"이라는
   점을 먼저 이해한다.
2. `00_STORY.md` §5 — 이루키의 Customer Journey(SNS→가입→티켓→직관→굿즈→재방문→
   멤버십)가 곧 Fan App이 만들어야 할 이벤트 목록이다.
3. `03_SYSTEM.md` §2 — Fan App이 만든 이벤트가 어떤 Object(Order, Admission,
   Engagement Signal 등)로 들어가는지 확인한다.
4. `02_TEAM_GUIDE.md` §2 — Repository 구조(별도 저장소)와 담당 범위를 확인한다.

---

# Role

Developer Lead / Team Lead. Demo Fan App 개발과 Salesforce 연동, 팀 개발 일정 조율을
담당한다.

---

# Responsibility

- `cloudalpacas-fan-app` 저장소 개발 (회원가입, 티켓 구매, 체크인, 굿즈 구매 등 이벤트
  생성)
- Fan App 이벤트를 Salesforce Object(Order, `Admission__c`, `Engagement_Signal__c`
  등)로 정확히 전달(API 또는 Dummy Data 연동)
- 팀 전체 개발 일정 조율(Phase 1/2 마감 기준 — `02_TEAM_GUIDE.md` §8)

---

# Deliverables

- `cloudalpacas-fan-app` 저장소(Demo용 이벤트 생성기)
- Fan App ↔ Salesforce 연동 가이드(API 또는 Dummy Data 주입 방식)

---

# Owned Objects

Object를 직접 구축하지는 않지만(승우 담당), 아래 Object에 **데이터를 채우는 연동**을
책임진다.

- `Admission__c` (체크인 이벤트)
- `Engagement_Signal__c` (SNS 반응 이벤트)
- Order/OrderItem (티켓·굿즈 구매 이벤트)

---

# Owned Flows

해당 없음 — Flow 구축은 승우 담당이다. 다만 Flow의 Trigger가 되는 **원본 이벤트
데이터**를 Fan App에서 만들어낸다는 점에서 간접적으로 연결된다.

---

# Owned Screens

해당 없음 — Fan App은 화면이 있지만 Customer 360 화면이 아니라 Demo용 영상 소재다
(04_DEMO.md §1).

---

# Weekly Guide

### Week 1 — Foundation

- **이번 주 목표**: `cloudalpacas-fan-app` 저장소를 만들고, 이루키의 Customer
  Journey에 맞는 이벤트 목록을 정리한다.
- **왜 이 작업을 하는가**: Salesforce Object 설계(승우)와 Fan App 이벤트 설계가
  서로 맞아야 나중에 연동이 매끄럽다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: Fan App 저장소 초기 세팅, 이벤트
  목록 초안.
- **누구와 협업해야 하는가**: 승우(Object/Field 이름 맞추기).
- **먼저 읽어야 하는 문서**: `00_STORY.md` §5, `03_SYSTEM.md` §2.
- **추천 구현 순서**: 이벤트 목록 정리 → 저장소 초기 세팅 → 화면 없이 이벤트 생성
  로직부터.

### Week 2 — MVP Completion

- **이번 주 목표**: Fan App에서 만든 이벤트가 Salesforce에 정확히 들어가는 것까지
  완성한다(목표: 2026-08-14).
- **왜 이 작업을 하는가**: Demo Scene(04_DEMO.md)이 실제 데이터를 기반으로 재현되어야
  한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 8개 Scene에 필요한 이벤트가 모두
  Fan App → Salesforce로 연결된 상태.
- **누구와 협업해야 하는가**: 승우(연동 테스트), 아론(Demo Scene 순서 확인).
- **먼저 읽어야 하는 문서**: `04_DEMO.md` §3(Scene 상세).
- **추천 구현 순서**: 이벤트 생성 로직 완성 → 승우와 연동 테스트 → 영상 촬영용
  화면(있다면) 정리.

### Week 3 — Future Scope

- **이번 주 목표**: 확장 시나리오(Sponsorship 등)에 필요한 이벤트가 있는지 검토한다.
- **왜 이 작업을 하는가**: MVP 이후 방향을 팀과 맞춘다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 필요 시 이벤트 확장 초안.
- **누구와 협업해야 하는가**: Sara.
- **먼저 읽어야 하는 문서**: `05_DECISIONS.md` Decision 005.
- **추천 구현 순서**: Sara·아론의 시나리오 논의에 참여 후 필요한 이벤트만 추가.

### Week 4 — Polish

- **이번 주 목표**: 혜준의 QA 피드백을 반영해 이벤트 데이터 품질을 다듬는다.
- **왜 이 작업을 하는가**: 잘못된 데이터(예: 시간 역전)가 Demo에서 어색하게 보이지
  않도록 한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: QA를 통과한 이벤트 데이터.
- **누구와 협업해야 하는가**: 혜준.
- **먼저 읽어야 하는 문서**: 없음(QA 이슈 기반).
- **추천 구현 순서**: QA 이슈 확인 → 이벤트 생성 로직 수정 → 재검증.

### Week 5 — Presentation

- **이번 주 목표**: Fan App 영상 소재를 최종 촬영·편집하고 Demo 리허설에 참여한다.
- **왜 이 작업을 하는가**: 04_DEMO.md의 각 Scene 영상 파트가 매끄럽게 이어져야 한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: Scene별 영상 소재 완성.
- **누구와 협업해야 하는가**: 아론(Demo 리허설 주도).
- **먼저 읽어야 하는 문서**: `04_DEMO.md`.
- **추천 구현 순서**: 영상 촬영 → 편집 → 리허설에서 라이브 클릭과 이어 재생 테스트.

---

# Related Documents

- `00_STORY.md` §5 — Fan App이 재현해야 할 Customer Journey.
- `03_SYSTEM.md` §2 — 이벤트가 들어갈 Object/Field.
- `04_DEMO.md` — Fan App 영상 파트가 필요한 Scene 목록.

---

# GitHub Projects

Task와 진행 상황은 GitHub Projects에서 관리한다.

---

# Learning Path

1. Business 이해: `00_STORY.md`의 Customer Journey를 이벤트 목록으로 바꿔본다.
2. Customer 360 이해: 내가 만든 이벤트가 Fan Timeline에서 어떻게 보이는지
   `03_SYSTEM.md` §3(ERD)로 확인한다.
3. Salesforce 구현: Salesforce API 연동 기초(Object에 레코드를 만드는 방법)를
   승우와 함께 익힌다.

---

# 🤝 협업 포인트

- **승우**: Object/Field API 이름을 맞추고, 연동 테스트를 함께 진행한다.
- **Sara**: Fan App이 재현하는 이야기가 Demo Story와 어긋나지 않는지 확인한다.
- **혜준**: 생성된 이벤트 데이터의 정합성(날짜 순서 등)을 함께 검증한다.
- **아론**: Demo Scene에 맞는 영상 소재 요구사항을 전달받는다.

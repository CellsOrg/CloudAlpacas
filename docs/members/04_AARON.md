# Mission

> **"이루키의 이야기가 청중에게 설득력 있게 전달되도록 만든다."**

아론은 Cloud Alpacas의 Demo Lead / Business Analyst다. Demo Story와 발표 시나리오를
설계하고, Demo에 필요한 Sample/Dummy Data를 기획한다. Salesforce가 만든 결과물이
"그래서 팬에게 어떤 의미인지"를 발표로 옮기는 역할이다.

---

# Quick Start

1. `00_STORY.md` — Persona(김매니저·이루키)와 Pain Point를 가장 먼저, 가장 깊게
   이해해야 하는 문서.
2. `04_DEMO.md` — 직접 작성·운영하는 핵심 문서. Scene 구조와 화면 목록을 숙지한다.
3. `03_SYSTEM.md` §2 — Sample Data를 기획하려면 각 Object에 어떤 Field가 있는지
   알아야 한다.
4. `02_TEAM_GUIDE.md` §2 — Sample/Dummy Data 담당임을 확인한다.

---

# Role

Demo Lead / Business Analyst. Demo Story·발표 시나리오 설계와 Sample/Dummy Data
기획을 담당한다.

---

# Responsibility

- `04_DEMO.md`의 Scene 구조와 발표 시나리오(멘트 포함) 작성·유지
- `docs/data/SAMPLE_DATA.md`, `docs/data/DEMO_DATASETS.md`의 실제 더미 데이터 기획
- Recommendation·Notification Log의 문구(어떤 메시지를 보낼지) 기획
- 발표 리허설 주도

---

# Deliverables

- `04_DEMO.md` (Scene별 시나리오)
- `docs/data/SAMPLE_DATA.md`, `docs/data/DEMO_DATASETS.md`
- 발표 대본(리허설을 거쳐 다듬어진 최종 멘트)

---

# Owned Objects

Object를 직접 구축하지는 않지만(승우 담당), 아래는 **콘텐츠·데이터 기획**을 책임진다.

- `Recommendation__c` — 추천 문구·로직 기획(승우와 협업)
- `Notification_Log__c` — 발송 콘텐츠 기획
- Sample Data 전체 (`docs/data/`)

---

# Owned Flows

해당 없음 — Flow 구축은 승우 담당이다. 다만 Flow가 실행됐을 때 나오는 **결과 문구**
(Recommendation 사유, Notification 내용, Slack 메시지)는 아론이 기획한다.

---

# Owned Screens

Recommendation Panel의 **문구·콘텐츠** — 화면 UX는 Sara, 구현은 승우, 문구는 아론.

---

# Weekly Guide

### Week 1 — Foundation

- **이번 주 목표**: Demo Story의 뼈대(Scene 구조)를 Sara·전체 팀과 함께 확정한다.
- **왜 이 작업을 하는가**: Demo 구조가 먼저 정해져야, 어떤 Sample Data가 필요한지
  알 수 있다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: `04_DEMO.md` 초안.
- **누구와 협업해야 하는가**: Sara(Business 관점 정합성 확인).
- **먼저 읽어야 하는 문서**: `00_STORY.md`.
- **추천 구현 순서**: Customer Journey 확인 → Scene 목록 작성 → 화면 목록과 매칭.

### Week 2 — MVP Completion

- **이번 주 목표**: Sample Data를 실제로 만들고, Demo Scene을 리허설 가능한 상태로
  만든다(목표: 2026-08-14).
- **왜 이 작업을 하는가**: `02_TEAM_GUIDE.md` Phase 1 마감 — Demo가 실제 데이터로
  동작해야 한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: `docs/data/`의 실제 값 완성,
  Core Scene 4개 리허설 1회 이상 완료.
- **누구와 협업해야 하는가**: 승우(데이터 적재), 은영(Fan App 이벤트와 맞추기),
  혜준(데이터 검증).
- **먼저 읽어야 하는 문서**: `04_DEMO.md` §5(Sample Data 요구사항).
- **추천 구현 순서**: 필요 데이터 목록 확정 → 실제 값 작성 → 적재 → 리허설.

### Week 3 — Future Scope

- **이번 주 목표**: 확장 시나리오(예: 산리오 협업)를 Business 관점에서 함께
  구체화한다.
- **왜 이 작업을 하는가**: `05_DECISIONS.md` Decision 005로 미뤄둔 부분을 다음
  단계로 이어가야 한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 확장 시나리오 스토리 초안.
- **누구와 협업해야 하는가**: Sara.
- **먼저 읽어야 하는 문서**: `05_DECISIONS.md` Decision 005.
- **추천 구현 순서**: 시나리오 브레인스토밍 → Sara와 Entity 영향 검토.

### Week 4 — Polish

- **이번 주 목표**: 발표 멘트를 다듬고, QA 결과에 맞춰 Demo Scene을 조정한다.
- **왜 이 작업을 하는가**: 리허설에서 나온 어색한 지점을 매끄럽게 고쳐야 한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 다듬어진 발표 대본.
- **누구와 협업해야 하는가**: 혜준(QA 이슈 반영), Sara(화면 UI 변경 사항 반영).
- **먼저 읽어야 하는 문서**: 없음(리허설 피드백 기반).
- **추천 구현 순서**: 리허설 → 피드백 수집 → 대본·Scene 수정.

### Week 5 — Presentation

- **이번 주 목표**: 최종 Demo와 PPT/포트폴리오를 완성하고 발표를 주도한다.
- **왜 이 작업을 하는가**: 프로젝트의 최종 결과물을 전달하는 마지막 단계다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 발표 가능한 최종 Demo, 발표
  자료.
- **누구와 협업해야 하는가**: 전체 팀(최종 리허설).
- **먼저 읽어야 하는 문서**: `04_DEMO.md`.
- **추천 구현 순서**: 최종 리허설 → 시간 조정(5분/10분) → 발표.

---

# Related Documents

- `00_STORY.md` — Demo Story의 원본 서사.
- `04_DEMO.md` — 직접 작성·운영하는 핵심 문서.
- `docs/data/` — Sample/Dummy Data.

---

# GitHub Projects

Task와 진행 상황은 GitHub Projects에서 관리한다.

---

# Learning Path

1. Business 이해: `00_STORY.md`의 Pain Point와 Persona를 발표할 수 있을 정도로
   깊게 이해한다.
2. Customer 360 이해: `03_SYSTEM.md` §3(ERD)으로 데이터가 어떻게 연결되는지 알아야
   Sample Data를 앞뒤가 맞게 기획할 수 있다.
3. Salesforce 구현: Demo에서 클릭할 화면의 실제 동작을 승우와 함께 미리 손에 익힌다.

---

# 🤝 협업 포인트

- **Sara**: Demo Story가 Business Goal과 어긋나지 않는지 함께 확인한다.
- **승우**: Sample Data를 언제, 어떤 형식으로 전달하면 되는지 조율한다.
- **은영**: Fan App 영상 소재와 Salesforce 라이브 파트가 자연스럽게 이어지는지
  확인한다.
- **혜준**: 리허설 중 발견된 이슈를 공유받아 시나리오에 반영한다.

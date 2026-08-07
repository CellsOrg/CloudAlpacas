# Mission

> **"Demo 당일, 화면이 예상대로 정확하게 동작한다는 것을 보장한다."**

혜준은 Cloud Alpacas의 Platform Lead / QA Lead다. Salesforce Org 환경(Sandbox,
배포)을 관리하고, 데이터와 화면이 설계대로 정확하게 동작하는지 검증한다.

---

# Quick Start

1. `CLAUDE.md` §5 — MVP 범위를 정확히 알아야 "무엇을 테스트해야 하는지" 판단할 수
   있다.
2. `03_SYSTEM.md` — 검증 대상이 되는 Object/Field/Flow의 설계 원본.
3. `04_DEMO.md` — Demo Scene마다 어떤 데이터·화면이 정확해야 하는지 확인한다.
4. `02_TEAM_GUIDE.md` §6 — GitHub Projects에서 QA 이슈를 어떻게 다루는지 확인한다.

---

# Role

Platform Lead / QA Lead. Org 환경 관리와 테스트·QA를 담당한다.

---

# Responsibility

- Sandbox 환경 준비 및 관리, Phase 1→2 브랜치 전략에 맞춘 배포 지원
  (`02_TEAM_GUIDE.md` §4)
- `03_SYSTEM.md`에 정의된 Object/Field/Flow가 설계대로 동작하는지 검증
- 분석성 Object(`Attendance_Record__c`, `Fan_Activity_Pattern__c`)의 데이터 정합성
  확인 — 예: 관람 횟수가 실제 Admission 건수와 맞는지
- Demo 리허설에서 발생하는 오류 발견 및 재현 시나리오 정리

---

# Deliverables

- QA 이슈 목록(GitHub Projects에서 관리, Label로 구분)
- Demo 백업 환경(녹화 영상 재생 포함) 점검 결과

---

# Owned Objects

Object를 직접 구축하지는 않지만(승우 담당), 아래 Object의 **데이터 정합성 검증**을
책임진다.

- `Attendance_Record__c`, `Fan_Activity_Pattern__c` — 집계 값이 원본 데이터
  (Admission, Order)와 일치하는지 확인

---

# Owned Flows

해당 없음 — Flow 구축은 승우 담당이다. 다만 Flow 실행 결과(Recommendation, Notification
Log, Slack 알림)가 트리거 조건과 맞게 생성되는지 검증한다.

---

# Owned Screens

Fan 360 Dashboard 등 4개 화면 — **QA 담당** (UX 설계는 Sara, 구현은 승우)

---

# Weekly Guide

### Week 1 — Foundation

- **이번 주 목표**: Sandbox 환경을 준비한다.
- **왜 이 작업을 하는가**: 승우가 Object를 구축하기 시작하기 전에 안전하게 테스트할
  수 있는 환경이 있어야 한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 팀이 함께 쓸 수 있는 Sandbox.
- **누구와 협업해야 하는가**: 승우.
- **먼저 읽어야 하는 문서**: `02_TEAM_GUIDE.md` §4(브랜치 전략).
- **추천 구현 순서**: Sandbox 생성 → 접근 권한 설정 → 팀에 공유.

### Week 2 — MVP Completion

- **이번 주 목표**: 구축된 Object/Flow/화면을 실제 시나리오로 검증한다(목표:
  2026-08-14).
- **왜 이 작업을 하는가**: Demo 당일 오류가 나오면 안 된다 — 미리 발견해야 한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: `04_DEMO.md`의 8개 Scene을 한 번씩
  직접 재현해본 QA 결과.
- **누구와 협업해야 하는가**: 승우(이슈 수정), 아론(Sample Data 요구사항 확인).
- **먼저 읽어야 하는 문서**: `04_DEMO.md` §3, §5(Sample Data 요구사항).
- **추천 구현 순서**: Scene 순서대로 재현 → 이슈 기록(GitHub Projects) → 승우에게
  전달.

### Week 3 — Future Scope

- **이번 주 목표**: 확장 시나리오가 기존 Org에 영향을 주지 않는지 검토한다.
- **왜 이 작업을 하는가**: 새 Object 추가가 기존 Flow/화면을 깨뜨리지 않아야 한다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 확장 시 리스크 검토 의견.
- **누구와 협업해야 하는가**: 승우.
- **먼저 읽어야 하는 문서**: `05_DECISIONS.md` Decision 005.
- **추천 구현 순서**: 확장 설계 검토 → 리스크 포인트 정리.

### Week 4 — Polish

- **이번 주 목표**: 발견된 QA 이슈를 모두 해결하고 Dashboard/UI를 최종 점검한다.
- **왜 이 작업을 하는가**: 발표 직전 마지막 안정화 주간이다.
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 열린 QA 이슈가 없는 상태.
- **누구와 협업해야 하는가**: 승우, Sara(UI 조정 요청).
- **먼저 읽어야 하는 문서**: 없음(QA 이슈 기반).
- **추천 구현 순서**: 이슈 재검증 → 회귀 테스트(이전에 고친 부분이 다시 깨지지
  않았는지).

### Week 5 — Presentation

- **이번 주 목표**: Demo 백업 환경(녹화 영상 포함)을 최종 점검한다.
- **왜 이 작업을 하는가**: 네트워크·환경 문제에 대비해야 한다(04_DEMO.md §1).
- **이번 주가 끝났을 때 완성되어 있어야 하는 것**: 라이브가 실패해도 즉시 녹화
  영상으로 전환 가능한 상태.
- **누구와 협업해야 하는가**: 은영(영상 소재), 아론(리허설).
- **먼저 읽어야 하는 문서**: `04_DEMO.md` §1.
- **추천 구현 순서**: 리허설 참여 → 백업 전환 테스트 → 최종 점검 체크리스트 확인.

---

# Related Documents

- `03_SYSTEM.md` — 검증 대상 설계 원본.
- `04_DEMO.md` §3, §5 — Scene별 검증 기준과 필요 데이터.
- `02_TEAM_GUIDE.md` §6 — GitHub Projects 이슈 관리 방식.

---

# GitHub Projects

Task와 진행 상황은 GitHub Projects에서 관리한다.

---

# Learning Path

1. Business 이해: `00_STORY.md`의 Pain Point를 알아야 "무엇이 해결됐는지" 검증
   기준을 세울 수 있다.
2. Customer 360 이해: `03_SYSTEM.md` §3(ERD)로 Object 간 관계를 파악해야 어떤
   데이터가 어디에 영향을 주는지 안다.
3. Salesforce 구현: Sandbox 관리와 기본 QA(Flow 디버그, 데이터 확인) 방법을
   승우와 함께 익힌다.

---

# 🤝 협업 포인트

- **승우**: 발견한 QA 이슈를 구체적인 재현 시나리오와 함께 전달한다.
- **Sara**: 화면 UX가 실제 사용성과 맞는지 QA 관점에서 피드백을 준다.
- **은영**: Fan App이 만든 데이터가 시간 순서 등에서 자연스러운지 확인한다.
- **아론**: Demo Scene 순서와 필요한 Sample Data를 미리 공유받는다.

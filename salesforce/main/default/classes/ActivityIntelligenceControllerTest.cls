@isTest
private class ActivityIntelligenceControllerTest {

    @testSetup
    static void setupData() {
        Opportunity oppA = new Opportunity(Name = 'Test Opp A', StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        Opportunity oppB = new Opportunity(Name = 'Test Opp B (other)', StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        insert new List<Opportunity>{ oppA, oppB };

        Task callTask = new Task(WhatId = oppA.Id, Subject = '고객 전화 통화', Status = 'Completed', ActivityDate = Date.today().addDays(-2), Description = '예산 관련 1차 통화');
        Event meetingEvent = new Event(WhatId = oppA.Id, Subject = '오프라인 미팅', StartDateTime = Datetime.now().addDays(-1), EndDateTime = Datetime.now().addDays(-1).addHours(1),
            Meeting_Type__c = 'Offline', Key_Discussion__c = 'Platinum 패키지 논의', Concerns_Objections__c = '예산 미확정', Follow_up__c = '제안서 재전달');
        Task danglingTask = new Task(WhatId = oppA.Id, Subject = '삭제될 임시 Task', Status = 'Completed', ActivityDate = Date.today());
        Task otherOppTask = new Task(WhatId = oppB.Id, Subject = 'Opp B 전화 통화', Status = 'Completed', ActivityDate = Date.today());
        // Intelligence가 전혀 없는 일반 Task(Timeline에는 나와야 하고, getIntelligence에는 영향 없음)
        Task generalTask = new Task(WhatId = oppA.Id, Subject = '내부 준비 작업', Status = 'Not Started', ActivityDate = Date.today().addDays(1));
        insert new List<Task>{ callTask, danglingTask, otherOppTask, generalTask };
        insert meetingEvent;

        EmailMessage email = new EmailMessage(Subject = '제안서 전달', Status = '3', RelatedToId = oppA.Id, MessageDate = Datetime.now().addDays(-3));
        insert email;

        Interaction_Intelligence__c iiCall = new Interaction_Intelligence__c(
            Opportunity__c = oppA.Id, Source_Type__c = 'Call', Source_Record_Id__c = callTask.Id,
            Summary__c = '전화로 예산 논의', Customer_Reaction__c = 'Positive',
            Key_Decision__c = '다음 주 재통화', Concerns_Objections__c = null, Follow_Up__c = '견적서 발송'
        );
        Interaction_Intelligence__c iiMeeting = new Interaction_Intelligence__c(
            Opportunity__c = oppA.Id, Source_Type__c = 'Offline Meeting', Source_Record_Id__c = meetingEvent.Id,
            Summary__c = '오프라인 미팅에서 Platinum 패키지 논의', Customer_Reaction__c = 'Very Positive',
            Key_Decision__c = '예산회의 후 확정', Concerns_Objections__c = '예산 승인 필요', Follow_Up__c = null
        );
        Interaction_Intelligence__c iiEmail = new Interaction_Intelligence__c(
            Opportunity__c = oppA.Id, Source_Type__c = 'Email', Source_Record_Id__c = email.Id,
            Summary__c = '제안서 전달 이메일', Customer_Reaction__c = 'Neutral',
            Key_Decision__c = null, Concerns_Objections__c = null, Follow_Up__c = null
        );
        Interaction_Intelligence__c iiDangling = new Interaction_Intelligence__c(
            Opportunity__c = oppA.Id, Source_Type__c = 'Call', Source_Record_Id__c = danglingTask.Id,
            Summary__c = '원본이 곧 삭제될 레코드', Customer_Reaction__c = 'Not Determined'
        );
        Interaction_Intelligence__c iiOther = new Interaction_Intelligence__c(
            Opportunity__c = oppB.Id, Source_Type__c = 'Call', Source_Record_Id__c = otherOppTask.Id,
            Summary__c = '다른 Opportunity 소속 — 조회에 포함되면 안 됨', Customer_Reaction__c = 'Neutral'
        );
        insert new List<Interaction_Intelligence__c>{ iiCall, iiMeeting, iiEmail, iiDangling, iiOther };

        insert new List<Interaction_Signal__c>{
            new Interaction_Signal__c(Interaction_Intelligence__c = iiCall.Id, Signal_Category__c = 'INTEREST', Signal_Type__c = 'Gold Package Interest', Direction__c = 'Positive', Confidence__c = 'High', Evidence__c = '고객이 관심을 보임'),
            new Interaction_Signal__c(Interaction_Intelligence__c = iiCall.Id, Signal_Category__c = 'TIMING', Signal_Type__c = 'Decision Meeting Scheduled', Direction__c = 'Neutral', Confidence__c = 'High', Evidence__c = '다음 주 회의 예정')
        };

        // 원본 Activity가 실제로 삭제된(dangling) 상태를 재현
        delete danglingTask;

        // target persona(Manager Lee 유형) — Standard User + CA_Opportunity_Agent_Access.
        // permission set 인식이 트랜잭션 경계를 넘어야 runAs에서 반영되므로 @testSetup에서 만든다.
        // setup object(User/PermissionSetAssignment) DML은 MIXED_DML 회피를 위해 runAs로 격리.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CA_Opportunity_Agent_Access' LIMIT 1];
            Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User u = new User(
                FirstName = 'AM', LastName = 'QA Manager', Alias = 'amqamgr',
                Email = 'am.qa.manager@example.com.invalid',
                Username = 'am.qa.manager.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = std.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert u;
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
    }

    @isTest
    static void testReturnsOnlyMatchingOpportunity() {
        Opportunity oppA = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp A' LIMIT 1];

        Test.startTest();
        List<ActivityIntelligenceController.IntelligenceItem> items = ActivityIntelligenceController.getIntelligence(oppA.Id);
        Test.stopTest();

        System.assertEquals(4, items.size(), 'Opp A에 연결된 4건만 반환되어야 한다(Opp B 1건은 제외)');
        for (ActivityIntelligenceController.IntelligenceItem item : items) {
            System.assert(item.summary != '다른 Opportunity 소속 — 조회에 포함되면 안 됨', 'Opp B 레코드가 섞여 들어오면 안 된다');
        }
    }

    @isTest
    static void testJoinsTaskAndEventAndEmailOrigin() {
        Opportunity oppA = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp A' LIMIT 1];

        Test.startTest();
        List<ActivityIntelligenceController.IntelligenceItem> items = ActivityIntelligenceController.getIntelligence(oppA.Id);
        Test.stopTest();

        Map<String, ActivityIntelligenceController.IntelligenceItem> bySummary = new Map<String, ActivityIntelligenceController.IntelligenceItem>();
        for (ActivityIntelligenceController.IntelligenceItem item : items) {
            bySummary.put(item.summary, item);
        }

        ActivityIntelligenceController.IntelligenceItem callItem = bySummary.get('전화로 예산 논의');
        System.assertEquals(true, callItem.originFound, 'Call 원본(Task)이 조인되어야 한다');
        System.assertEquals('고객 전화 통화', callItem.originSubject);
        System.assertEquals('Completed', callItem.originDetail);

        ActivityIntelligenceController.IntelligenceItem meetingItem = bySummary.get('오프라인 미팅에서 Platinum 패키지 논의');
        System.assertEquals(true, meetingItem.originFound, 'Offline Meeting 원본(Event)이 조인되어야 한다');
        System.assertEquals('오프라인 미팅', meetingItem.originSubject);

        ActivityIntelligenceController.IntelligenceItem emailItem = bySummary.get('제안서 전달 이메일');
        System.assertEquals(true, emailItem.originFound, 'Email 원본(EmailMessage)이 조인되어야 한다');
        System.assertEquals('제안서 전달', emailItem.originSubject);
    }

    @isTest
    static void testDanglingSourceRecordGracefullyDegrades() {
        Opportunity oppA = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp A' LIMIT 1];

        Test.startTest();
        List<ActivityIntelligenceController.IntelligenceItem> items = ActivityIntelligenceController.getIntelligence(oppA.Id);
        Test.stopTest();

        ActivityIntelligenceController.IntelligenceItem danglingItem;
        for (ActivityIntelligenceController.IntelligenceItem item : items) {
            if (item.summary == '원본이 곧 삭제될 레코드') {
                danglingItem = item;
            }
        }
        System.assertNotEquals(null, danglingItem, 'Intelligence 레코드 자체는 원본 삭제와 무관하게 계속 반환되어야 한다');
        System.assertEquals(false, danglingItem.originFound, '삭제된 원본은 originFound=false여야 한다');
        System.assertEquals(null, danglingItem.originSubject);
    }

    @isTest
    static void testSortOrderNewestFirstWithFallbackToCreatedDate() {
        Opportunity oppA = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp A' LIMIT 1];

        Test.startTest();
        List<ActivityIntelligenceController.IntelligenceItem> items = ActivityIntelligenceController.getIntelligence(oppA.Id);
        Test.stopTest();

        // 원본 삭제된 레코드는 CreatedDate(테스트 실행 시각)로 fallback되어 가장 최근으로 정렬되어야 한다
        System.assertEquals('원본이 곧 삭제될 레코드', items[0].summary, '원본이 없는 레코드는 CreatedDate 기준으로 가장 최신이어야 한다');

        // 나머지는 원본 발생 일시 기준 최신순(미팅 -1일 > 통화 -2일 > 이메일 -3일)
        List<String> remainingOrder = new List<String>();
        for (Integer i = 1; i < items.size(); i++) {
            remainingOrder.add(items[i].summary);
        }
        System.assertEquals(new List<String>{ '오프라인 미팅에서 Platinum 패키지 논의', '전화로 예산 논의', '제안서 전달 이메일' }, remainingOrder);
    }

    @isTest
    static void testSignalsGroupedAndEmptyWhenNone() {
        Opportunity oppA = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp A' LIMIT 1];

        Test.startTest();
        List<ActivityIntelligenceController.IntelligenceItem> items = ActivityIntelligenceController.getIntelligence(oppA.Id);
        Test.stopTest();

        ActivityIntelligenceController.IntelligenceItem callItem;
        ActivityIntelligenceController.IntelligenceItem meetingItem;
        for (ActivityIntelligenceController.IntelligenceItem item : items) {
            if (item.summary == '전화로 예산 논의') callItem = item;
            if (item.summary == '오프라인 미팅에서 Platinum 패키지 논의') meetingItem = item;
        }

        System.assertEquals(2, callItem.signals.size(), 'Call 레코드에 연결된 Signal 2건이 모두 조회되어야 한다');
        System.assertNotEquals(null, meetingItem.signals, 'Signal이 없어도 null이 아닌 빈 리스트를 반환해야 한다');
        System.assertEquals(0, meetingItem.signals.size());
    }

    @isTest
    static void testEmptyAndNullOpportunityIdReturnEmptyList() {
        Opportunity oppEmpty = new Opportunity(Name = 'No Intelligence Opp', StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        insert oppEmpty;

        Test.startTest();
        List<ActivityIntelligenceController.IntelligenceItem> emptyResult = ActivityIntelligenceController.getIntelligence(oppEmpty.Id);
        List<ActivityIntelligenceController.IntelligenceItem> nullResult = ActivityIntelligenceController.getIntelligence(null);
        Test.stopTest();

        System.assertEquals(0, emptyResult.size(), 'Intelligence가 없는 Opportunity는 빈 리스트를 반환해야 한다');
        System.assertEquals(0, nullResult.size(), 'null Id는 예외 없이 빈 리스트를 반환해야 한다');
    }

    // ===================== getActivityTimeline =====================

    @isTest
    static void testActivityTimelineIncludesAllActivityTypesWithLeftJoin() {
        Opportunity oppA = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp A' LIMIT 1];

        Test.startTest();
        List<ActivityIntelligenceController.TimelineItem> rows = ActivityIntelligenceController.getActivityTimeline(oppA.Id);
        Test.stopTest();

        // Task 3건(call/dangling은 삭제됨/general) + Event 1건 + EmailMessage 1건
        // dangling Task는 삭제되었으므로 timeline row 없음 → Task 2 + Event 1 + Email 1 = 4
        Map<String, ActivityIntelligenceController.TimelineItem> bySubject = new Map<String, ActivityIntelligenceController.TimelineItem>();
        for (ActivityIntelligenceController.TimelineItem r : rows) {
            bySubject.put(r.subject, r);
        }
        System.assertEquals(4, rows.size(), '삭제된 dangling Task를 제외한 Activity 4건이 timeline에 나와야 한다');

        ActivityIntelligenceController.TimelineItem callRow = bySubject.get('고객 전화 통화');
        System.assertNotEquals(null, callRow, 'Call Task가 timeline에 있어야 한다');
        System.assertEquals('Task', callRow.sourceObject);
        System.assertEquals(true, callRow.hasIntelligence, 'Call Task는 연결된 Intelligence가 있어야 한다');
        System.assertEquals('전화로 예산 논의', callRow.summary);
        System.assertEquals(2, callRow.signals.size(), 'Call Intelligence의 Signal 2건이 조회되어야 한다');
        System.assertEquals('Activity Notes', callRow.contentType);

        ActivityIntelligenceController.TimelineItem generalRow = bySubject.get('내부 준비 작업');
        System.assertNotEquals(null, generalRow, 'Intelligence 없는 일반 Task도 timeline에 나와야 한다');
        System.assertEquals(false, generalRow.hasIntelligence, '일반 Task는 hasIntelligence=false');
        System.assertEquals('Task', generalRow.activityType);
        System.assertNotEquals(null, generalRow.signals, 'Intelligence가 없어도 signals는 빈 리스트여야 한다');
        System.assertEquals(0, generalRow.signals.size());

        ActivityIntelligenceController.TimelineItem eventRow = bySubject.get('오프라인 미팅');
        System.assertEquals('Event', eventRow.sourceObject);
        System.assertEquals('Offline Meeting', eventRow.activityType);
        System.assertEquals(true, eventRow.hasIntelligence);
        System.assertEquals('Meeting Notes', eventRow.contentType);

        ActivityIntelligenceController.TimelineItem emailRow = bySubject.get('제안서 전달');
        System.assertEquals('EmailMessage', emailRow.sourceObject);
        System.assertEquals('Email', emailRow.activityType);
        System.assertEquals(true, emailRow.hasIntelligence);
        System.assertEquals('Email Content', emailRow.contentType);
    }

    @isTest
    static void testActivityTimelineOpportunityIsolationAndSort() {
        Opportunity oppA = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp A' LIMIT 1];

        Test.startTest();
        List<ActivityIntelligenceController.TimelineItem> rows = ActivityIntelligenceController.getActivityTimeline(oppA.Id);
        Test.stopTest();

        for (ActivityIntelligenceController.TimelineItem r : rows) {
            System.assertNotEquals('Opp B 전화 통화', r.subject, '다른 Opportunity의 Activity가 섞이면 안 된다');
        }
        // 최신순(내림차순) 정렬 확인
        for (Integer i = 1; i < rows.size(); i++) {
            Datetime prev = rows[i - 1].timestamp;
            Datetime curr = rows[i].timestamp;
            if (prev != null && curr != null) {
                System.assert(prev >= curr, 'timeline은 timestamp 내림차순이어야 한다');
            }
        }
    }

    @isTest
    static void testActivityTimelineNullAndEmpty() {
        Opportunity oppEmpty = new Opportunity(Name = 'Timeline Empty Opp', StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        insert oppEmpty;

        Test.startTest();
        System.assertEquals(0, ActivityIntelligenceController.getActivityTimeline(null).size());
        System.assertEquals(0, ActivityIntelligenceController.getActivityTimeline(oppEmpty.Id).size());
        Test.stopTest();
    }

    @isTest
    static void testActivityTimelineBulkGovernorSafe() {
        Opportunity opp = new Opportunity(Name = 'Bulk Timeline Opp', StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        insert opp;
        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 200; i++) {
            tasks.add(new Task(WhatId = opp.Id, Subject = 'Bulk Task ' + i, Status = 'Completed', ActivityDate = Date.today().addDays(-i)));
        }
        insert tasks;

        Test.startTest();
        Integer qBefore = Limits.getQueries();
        List<ActivityIntelligenceController.TimelineItem> rows = ActivityIntelligenceController.getActivityTimeline(opp.Id);
        Integer qUsed = Limits.getQueries() - qBefore;
        Test.stopTest();

        System.assertEquals(200, rows.size(), '200건 Activity를 모두 반환해야 한다');
        System.assert(qUsed <= 6, 'N+1 없이 오브젝트당 상수 개의 벌크 쿼리만 사용해야 한다. 실제=' + qUsed);
    }

    // ===================== getActivityContent =====================

    @isTest
    static void testGetActivityContentTaskNotes() {
        Task t = [SELECT Id FROM Task WHERE Subject = '고객 전화 통화' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceController.ActivityContent c = ActivityIntelligenceController.getActivityContent(t.Id);
        Test.stopTest();

        System.assertEquals('Task', c.sourceObject);
        System.assertEquals('Activity Notes', c.contentType);
        System.assertEquals('예산 관련 1차 통화', c.body);
        System.assertEquals(true, c.hasContent);
    }

    @isTest
    static void testGetActivityContentEventMeetingNotes() {
        Event ev = [SELECT Id FROM Event WHERE Subject = '오프라인 미팅' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceController.ActivityContent c = ActivityIntelligenceController.getActivityContent(ev.Id);
        Test.stopTest();

        System.assertEquals('Event', c.sourceObject);
        System.assertEquals('Meeting Notes', c.contentType);
        System.assertEquals('Offline Meeting', c.activityType);
        System.assertEquals(true, c.hasContent);
        System.assertNotEquals(null, c.meetingNotes);
        System.assert(c.meetingNotes.size() >= 3, '비어있지 않은 담당자 노트 필드가 나와야 한다');
        Map<String, String> notes = new Map<String, String>();
        for (ActivityIntelligenceController.NoteField nf : c.meetingNotes) {
            notes.put(nf.label, nf.value);
        }
        System.assertEquals('Platinum 패키지 논의', notes.get('Key Discussion'));
        System.assertEquals('예산 미확정', notes.get('Concerns / Objections'));
    }

    @isTest
    static void testGetActivityContentEmail() {
        EmailMessage em = [SELECT Id FROM EmailMessage WHERE Subject = '제안서 전달' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceController.ActivityContent c = ActivityIntelligenceController.getActivityContent(em.Id);
        Test.stopTest();

        System.assertEquals('EmailMessage', c.sourceObject);
        System.assertEquals('Email Content', c.contentType);
        System.assertEquals('Email', c.activityType);
    }

    @isTest
    static void testGetActivityContentNull() {
        Test.startTest();
        ActivityIntelligenceController.ActivityContent c = ActivityIntelligenceController.getActivityContent(null);
        Test.stopTest();
        System.assertEquals(false, c.hasContent);
    }

    // ===================== FLS: target persona (Manager Lee 유형) =====================

    @isTest
    static void testOpportunityAgentAccessGrantsEventNoteFls() {
        // Option A 승인 범위: CA_Opportunity_Agent_Access가 Event 담당자 노트 5개 필드를
        // read-only(editable=false)로 부여하는지 결정적으로 검증한다.
        // (System.runAs는 permission-set 기반 FLS를 테스트 컨텍스트에서 신뢰성 있게 반영하지 못하므로
        //  실제 WITH USER_MODE 런타임 동작은 별도 org QA로 확인한다.)
        Set<String> fields = new Set<String>{
            'Event.Key_Discussion__c', 'Event.Key_Decision__c', 'Event.Concerns_Objections__c',
            'Event.Follow_up__c', 'Event.Customer_Reaction__c'
        };
        Map<String, FieldPermissions> byField = new Map<String, FieldPermissions>();
        for (FieldPermissions fp : [
            SELECT Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE Parent.Name = 'CA_Opportunity_Agent_Access' AND Field IN :fields
        ]) {
            byField.put(fp.Field, fp);
        }
        for (String f : fields) {
            System.assertNotEquals(null, byField.get(f), f + ' FLS 항목이 permission set에 존재해야 한다');
            System.assertEquals(true, byField.get(f).PermissionsRead, f + ' 는 readable 이어야 한다');
            System.assertEquals(false, byField.get(f).PermissionsEdit, f + ' 는 editable=false 여야 한다');
        }
    }

    @isTest
    static void testGetActivityContentNoExceptionForAgentAccessUser() {
        // Standard User + CA_Opportunity_Agent_Access 사용자(Manager Lee 유형)로 실행해도
        // getActivityContent / getActivitytimeline이 예외 없이 동작해야 한다(동적 FLS SELECT).
        User u = [SELECT Id FROM User WHERE Alias = 'amqamgr' LIMIT 1];
        Event ev = [SELECT Id FROM Event WHERE Subject = '오프라인 미팅' LIMIT 1];
        Opportunity oppA = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp A' LIMIT 1];

        Test.startTest();
        System.runAs(u) {
            ActivityIntelligenceController.ActivityContent c = ActivityIntelligenceController.getActivityContent(ev.Id);
            System.assertNotEquals(null, c, '예외 없이 content를 반환해야 한다');
            List<ActivityIntelligenceController.TimelineItem> rows = ActivityIntelligenceController.getActivityTimeline(oppA.Id);
            System.assertNotEquals(null, rows, '예외 없이 timeline을 반환해야 한다');
        }
        Test.stopTest();
    }
}

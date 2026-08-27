@isTest
private class ActivityIntelligenceControllerTest {

    @testSetup
    static void setupData() {
        Opportunity oppA = new Opportunity(Name = 'Test Opp A', StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        Opportunity oppB = new Opportunity(Name = 'Test Opp B (other)', StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        insert new List<Opportunity>{ oppA, oppB };

        Task callTask = new Task(WhatId = oppA.Id, Subject = '고객 전화 통화', Status = 'Completed', ActivityDate = Date.today().addDays(-2));
        Event meetingEvent = new Event(WhatId = oppA.Id, Subject = '오프라인 미팅', StartDateTime = Datetime.now().addDays(-1), EndDateTime = Datetime.now().addDays(-1).addHours(1));
        Task danglingTask = new Task(WhatId = oppA.Id, Subject = '삭제될 임시 Task', Status = 'Completed', ActivityDate = Date.today());
        Task otherOppTask = new Task(WhatId = oppB.Id, Subject = 'Opp B 전화 통화', Status = 'Completed', ActivityDate = Date.today());
        insert new List<Task>{ callTask, danglingTask, otherOppTask };
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
}

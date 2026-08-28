@isTest
private class ActivityIntelligenceAgentActionTest {

    @testSetup
    static void setupData() {
        Opportunity oppRich = new Opportunity(Name = 'II Rich Opp', StageName = 'Negotiation/Review', CloseDate = Date.today().addDays(30));
        Opportunity oppEmpty = new Opportunity(Name = 'II Empty Opp', StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        insert new List<Opportunity>{ oppRich, oppEmpty };

        // Origin activities: one Call (Task), one Offline Meeting (Event).
        Task callTask = new Task(
            WhatId = oppRich.Id, Subject = '예산 확인 통화', Status = 'Completed',
            ActivityDate = Date.today().addDays(-5)
        );
        Event meetingEvent = new Event(
            WhatId = oppRich.Id, Subject = 'Platinum 패키지 대면 미팅',
            StartDateTime = Datetime.now().addDays(-1), EndDateTime = Datetime.now().addDays(-1).addHours(1),
            Meeting_Type__c = 'Offline'
        );
        insert new List<Task>{ callTask };
        insert meetingEvent;

        // Older intelligence -> the Call (5 days ago). Optional fields deliberately null.
        Interaction_Intelligence__c iiCall = new Interaction_Intelligence__c(
            Opportunity__c = oppRich.Id, Source_Type__c = 'Call', Source_Record_Id__c = callTask.Id,
            Summary__c = '예산 범위를 처음 확인함', Customer_Reaction__c = 'Neutral',
            Key_Decision__c = null, Concerns_Objections__c = null, Follow_Up__c = null
        );
        // Newer intelligence -> the Meeting (yesterday). Fully populated + signals.
        Interaction_Intelligence__c iiMeeting = new Interaction_Intelligence__c(
            Opportunity__c = oppRich.Id, Source_Type__c = 'Offline Meeting', Source_Record_Id__c = meetingEvent.Id,
            Summary__c = 'Platinum 패키지 조건을 상세 논의', Customer_Reaction__c = 'Very Positive',
            Key_Decision__c = '내부 예산 회의 후 확정', Concerns_Objections__c = '연간 금액이 예산 상단',
            Follow_Up__c = '수정 제안서 발송'
        );
        insert new List<Interaction_Intelligence__c>{ iiCall, iiMeeting };

        insert new List<Interaction_Signal__c>{
            new Interaction_Signal__c(
                Interaction_Intelligence__c = iiMeeting.Id, Signal_Category__c = 'INTEREST',
                Signal_Type__c = 'Platinum Interest', Direction__c = 'Positive', Confidence__c = 'High',
                Evidence__c = '먼저 Platinum 조건을 물어봄'
            ),
            new Interaction_Signal__c(
                Interaction_Intelligence__c = iiMeeting.Id, Signal_Category__c = 'BUDGET',
                Signal_Type__c = 'Budget Ceiling', Direction__c = 'Negative', Confidence__c = 'Medium',
                Evidence__c = '연간 금액이 부담된다고 언급'
            )
        };
    }

    private static ActivityIntelligenceAgentAction.Response run(String opportunityId) {
        ActivityIntelligenceAgentAction.Request req = new ActivityIntelligenceAgentAction.Request();
        req.opportunityId = opportunityId;
        return ActivityIntelligenceAgentAction.getInteractionIntelligence(
            new List<ActivityIntelligenceAgentAction.Request>{ req }
        )[0];
    }

    @isTest
    static void testNoIntelligenceStored() {
        Opportunity empty = [SELECT Id FROM Opportunity WHERE Name = 'II Empty Opp' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run(String.valueOf(empty.Id));
        Test.stopTest();

        System.assertEquals(false, r.found, 'II가 없으면 found=false여야 한다');
        System.assertEquals(0, r.interactionCount, 'interactionCount=0이어야 한다');
        System.assertEquals(
            '이 Opportunity에는 저장된 Interaction Intelligence가 없습니다.',
            r.intelligenceDigest,
            'II 없음 메시지를 명확히 반환해야 한다'
        );
    }

    @isTest
    static void testSingleAndMultipleIntelligenceCount() {
        Opportunity rich = [SELECT Id FROM Opportunity WHERE Name = 'II Rich Opp' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run(String.valueOf(rich.Id));
        Test.stopTest();

        System.assertEquals(true, r.found, 'II가 있으면 found=true여야 한다');
        System.assertEquals(2, r.interactionCount, '이 Opportunity의 II는 2건이어야 한다');
        System.assert(r.intelligenceDigest.contains('[1]'), '다이제스트에 첫 항목 번호가 있어야 한다');
        System.assert(r.intelligenceDigest.contains('[2]'), '다이제스트에 둘째 항목 번호가 있어야 한다');
    }

    @isTest
    static void testChronologicalOrderNewestFirst() {
        Opportunity rich = [SELECT Id FROM Opportunity WHERE Name = 'II Rich Opp' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run(String.valueOf(rich.Id));
        Test.stopTest();

        Integer posMeeting = r.intelligenceDigest.indexOf('Platinum 패키지 조건을 상세 논의');
        Integer posCall = r.intelligenceDigest.indexOf('예산 범위를 처음 확인함');
        System.assert(posMeeting >= 0 && posCall >= 0, '두 요약이 모두 다이제스트에 있어야 한다');
        System.assert(posMeeting < posCall, '더 최근 상호작용(미팅)이 통화보다 먼저 나와야 한다');
        System.assert(
            r.intelligenceDigest.indexOf('[1] Offline Meeting') >= 0,
            '가장 최근 상호작용이 [1] 위치에 있어야 한다'
        );
    }

    @isTest
    static void testActivityOriginSubjectAndDateResolved() {
        Opportunity rich = [SELECT Id FROM Opportunity WHERE Name = 'II Rich Opp' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run(String.valueOf(rich.Id));
        Test.stopTest();

        System.assert(
            r.intelligenceDigest.contains('Platinum 패키지 대면 미팅'),
            '원본 Event의 Subject가 조인되어 표시되어야 한다'
        );
        System.assert(
            r.intelligenceDigest.contains('예산 확인 통화'),
            '원본 Task의 Subject가 조인되어 표시되어야 한다'
        );
    }

    @isTest
    static void testSignalsFormattedCategoryDirectionConfidenceEvidence() {
        Opportunity rich = [SELECT Id FROM Opportunity WHERE Name = 'II Rich Opp' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run(String.valueOf(rich.Id));
        Test.stopTest();

        System.assert(
            r.intelligenceDigest.contains('INTEREST · Positive · High — 먼저 Platinum 조건을 물어봄'),
            'Signal이 "Category · Direction · Confidence — Evidence" 형식으로 나와야 한다'
        );
        System.assert(
            r.intelligenceDigest.contains('BUDGET · Negative · Medium — 연간 금액이 부담된다고 언급'),
            '둘째 Signal도 같은 형식으로 나와야 한다'
        );
    }

    @isTest
    static void testNullOptionalFieldsRenderPlaceholder() {
        Opportunity rich = [SELECT Id FROM Opportunity WHERE Name = 'II Rich Opp' LIMIT 1];

        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run(String.valueOf(rich.Id));
        Test.stopTest();

        // The Call intelligence left keyDecision / concerns / followUp null.
        System.assert(r.intelligenceDigest.contains('핵심 결정: (기록 없음)'), 'null 필드는 (기록 없음)으로 표시되어야 한다');
        System.assert(r.intelligenceDigest.contains('후속 조치: (기록 없음)'), 'null follow-up도 placeholder로 표시되어야 한다');
        // The Call intelligence has no signals.
        System.assert(r.intelligenceDigest.contains('Signals: (없음)'), 'Signal 없는 항목은 (없음)으로 표시되어야 한다');
    }

    @isTest
    static void testInvalidOpportunityIdFormat() {
        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run('not-an-id');
        Test.stopTest();

        System.assertEquals(false, r.found, '잘못된 형식의 Id는 found=false여야 한다');
        System.assertEquals(0, r.interactionCount, 'interactionCount=0이어야 한다');
        System.assert(
            r.intelligenceDigest.contains('Opportunity를 특정할 수 없습니다'),
            '형식 오류를 사용자에게 안내해야 한다'
        );
    }

    @isTest
    static void testNonOpportunityIdRejected() {
        Account acc = new Account(Name = 'Wrong SObject Acct');
        insert acc;

        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run(String.valueOf(acc.Id));
        Test.stopTest();

        System.assertEquals(false, r.found, 'Opportunity가 아닌 Id는 거부되어 found=false여야 한다');
        System.assert(
            r.intelligenceDigest.contains('Opportunity를 특정할 수 없습니다'),
            'Opportunity가 아닌 Id도 형식 안내 메시지로 처리되어야 한다'
        );
    }

    @isTest
    static void testNullAndBlankOpportunityId() {
        Test.startTest();
        ActivityIntelligenceAgentAction.Response nullResp = run(null);
        ActivityIntelligenceAgentAction.Response blankResp = run('   ');
        Test.stopTest();

        System.assertEquals(false, nullResp.found, 'null Id는 found=false여야 한다');
        System.assertEquals(false, blankResp.found, 'blank Id는 found=false여야 한다');
    }

    @isTest
    static void testNonExistentOpportunityIdReturnsNoIntelligence() {
        // Well-formed 15-char Opportunity key (006 prefix) but no such record.
        Test.startTest();
        ActivityIntelligenceAgentAction.Response r = run('006000000000000');
        Test.stopTest();

        System.assertEquals(false, r.found, '존재하지 않는 Opportunity는 found=false여야 한다');
        System.assertEquals(
            '이 Opportunity에는 저장된 Interaction Intelligence가 없습니다.',
            r.intelligenceDigest,
            '존재하지 않는 Opportunity도 조회 실패 없이 "없음"으로 처리되어야 한다'
        );
    }

    @isTest
    static void testBulkRequestsReturnAlignedResponses() {
        Opportunity rich = [SELECT Id FROM Opportunity WHERE Name = 'II Rich Opp' LIMIT 1];
        Opportunity empty = [SELECT Id FROM Opportunity WHERE Name = 'II Empty Opp' LIMIT 1];

        ActivityIntelligenceAgentAction.Request r1 = new ActivityIntelligenceAgentAction.Request();
        r1.opportunityId = String.valueOf(rich.Id);
        ActivityIntelligenceAgentAction.Request r2 = new ActivityIntelligenceAgentAction.Request();
        r2.opportunityId = String.valueOf(empty.Id);

        Test.startTest();
        List<ActivityIntelligenceAgentAction.Response> out =
            ActivityIntelligenceAgentAction.getInteractionIntelligence(
                new List<ActivityIntelligenceAgentAction.Request>{ r1, r2 }
            );
        Test.stopTest();

        System.assertEquals(2, out.size(), '요청 수만큼 응답이 나와야 한다');
        System.assertEquals(true, out[0].found, '첫 응답은 II Rich Opp에 정렬되어야 한다');
        System.assertEquals(false, out[1].found, '둘째 응답은 II Empty Opp에 정렬되어야 한다');
    }

    @isTest
    static void testRunsUnderAgentAccessUserWithoutException() {
        Opportunity rich = [SELECT Id FROM Opportunity WHERE Name = 'II Rich Opp' LIMIT 1];

        User agentUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CA_Opportunity_Agent_Access' LIMIT 1];
            Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            agentUser = new User(
                FirstName = 'AA', LastName = 'V2 QA', Alias = 'aav2qa',
                Email = 'aa.v2.qa@example.com.invalid',
                Username = 'aa.v2.qa.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = std.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert agentUser;
            insert new PermissionSetAssignment(AssigneeId = agentUser.Id, PermissionSetId = ps.Id);
        }

        Test.startTest();
        System.runAs(agentUser) {
            ActivityIntelligenceAgentAction.Response r = run(String.valueOf(rich.Id));
            System.assertEquals(true, r.found, 'Agent Access 사용자도 저장된 II를 읽을 수 있어야 한다');
            System.assert(r.interactionCount >= 1, 'USER_MODE 하에서도 II가 조회되어야 한다');
        }
        Test.stopTest();
    }
}

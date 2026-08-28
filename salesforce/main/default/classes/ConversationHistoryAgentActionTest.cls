@isTest
private class ConversationHistoryAgentActionTest {

    @testSetup
    static void setupData() {
        Account acct = new Account(Name = 'ConvHist Corp');
        insert acct;

        Opportunity full = new Opportunity(
            Name = 'ConvHist Full Opp', AccountId = acct.Id,
            StageName = 'Negotiation/Review', CloseDate = Date.today().addDays(30)
        );
        Opportunity empty = new Opportunity(
            Name = 'ConvHist Empty Opp', AccountId = acct.Id,
            StageName = 'Qualification', CloseDate = Date.today().addDays(30)
        );
        Opportunity single = new Opportunity(
            Name = 'ConvHist Single Opp', AccountId = acct.Id,
            StageName = 'Qualification', CloseDate = Date.today().addDays(30)
        );
        insert new List<Opportunity>{ full, empty, single };

        // --- Full Opp: 3 activities across time, only the meeting has stored II ---
        Task earlyCall = new Task(
            WhatId = full.Id, Subject = '1차 예산 탐색 통화', Status = 'Completed',
            TaskSubtype = 'Call', ActivityDate = Date.today().addDays(-12)
        );
        Event midMeeting = new Event(
            WhatId = full.Id, Subject = 'Platinum 패키지 대면 미팅',
            StartDateTime = Datetime.now().addDays(-6), EndDateTime = Datetime.now().addDays(-6).addHours(1),
            Meeting_Type__c = 'Offline'
        );
        Task lateFollowUp = new Task(
            WhatId = full.Id, Subject = '수정 제안서 발송 준비', Status = 'Not Started',
            ActivityDate = Date.today().addDays(-1)
        );
        insert new List<Task>{ earlyCall, lateFollowUp };
        insert midMeeting;

        Interaction_Intelligence__c iiMeeting = new Interaction_Intelligence__c(
            Opportunity__c = full.Id, Source_Type__c = 'Offline Meeting', Source_Record_Id__c = midMeeting.Id,
            Summary__c = 'Platinum 패키지 조건을 상세 논의', Customer_Reaction__c = 'Very Positive',
            Key_Decision__c = '내부 예산 회의 후 확정', Concerns_Objections__c = '연간 금액이 예산 상단',
            Follow_Up__c = '수정 제안서 발송'
        );
        insert iiMeeting;
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

        // --- Single Opp: exactly one activity, no II ---
        insert new Task(
            WhatId = single.Id, Subject = '킥오프 통화', Status = 'Completed',
            TaskSubtype = 'Call', ActivityDate = Date.today().addDays(-3)
        );
    }

    private static ConversationHistoryAgentAction.Response run(String opportunityId) {
        return run(opportunityId, null);
    }

    private static ConversationHistoryAgentAction.Response run(String opportunityId, Integer maxItems) {
        ConversationHistoryAgentAction.Request req = new ConversationHistoryAgentAction.Request();
        req.opportunityId = opportunityId;
        req.maxItems = maxItems;
        return ConversationHistoryAgentAction.getConversationHistory(
            new List<ConversationHistoryAgentAction.Request>{ req }
        )[0];
    }

    private static Id oppId(String name) {
        return [SELECT Id FROM Opportunity WHERE Name = :name LIMIT 1].Id;
    }

    @isTest
    static void testFullHistoryChronologicalOldestFirst() {
        Test.startTest();
        ConversationHistoryAgentAction.Response r = run(String.valueOf(oppId('ConvHist Full Opp')));
        Test.stopTest();

        System.assertEquals(true, r.opportunityResolved, '유효 Opportunity면 opportunityResolved=true');
        System.assertEquals(true, r.hasHistory, '활동이 있으면 hasHistory=true');
        System.assertEquals(3, r.interactionCount, '통화 + 미팅 + 후속 Task = 3건');

        Integer posCall = r.historyDigest.indexOf('1차 예산 탐색 통화');
        Integer posMeeting = r.historyDigest.indexOf('Platinum 패키지 대면 미팅');
        Integer posFollowUp = r.historyDigest.indexOf('수정 제안서 발송 준비');
        System.assert(posCall >= 0 && posMeeting >= 0 && posFollowUp >= 0, '세 활동이 모두 다이제스트에 있어야 한다');
        System.assert(posCall < posMeeting && posMeeting < posFollowUp, '오래된 것 → 최근 것 순서여야 한다');
        System.assert(r.historyDigest.indexOf('[1] ') >= 0 && r.historyDigest.indexOf('[3] ') >= 0, '항목 번호가 매겨져야 한다');
    }

    @isTest
    static void testFirstAndLastInteractionDates() {
        Test.startTest();
        ConversationHistoryAgentAction.Response r = run(String.valueOf(oppId('ConvHist Full Opp')));
        Test.stopTest();

        String expectedFirst = Datetime.newInstance(Date.today().addDays(-12), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
        String expectedLast = Datetime.newInstance(Date.today().addDays(-1), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
        System.assertEquals(expectedFirst, r.firstInteractionDate, 'firstInteractionDate가 가장 오래된 활동(1차 통화)과 일치해야 한다');
        System.assertEquals(expectedLast, r.lastInteractionDate, 'lastInteractionDate가 가장 최근 활동(후속 Task)과 일치해야 한다');
    }

    @isTest
    static void testIntelligenceAndSignalsRenderedWhenPresent() {
        Test.startTest();
        ConversationHistoryAgentAction.Response r = run(String.valueOf(oppId('ConvHist Full Opp')));
        Test.stopTest();

        System.assert(r.historyDigest.contains('AI 분석: 있음'), '미팅 항목은 저장된 AI 분석이 있어야 한다');
        System.assert(r.historyDigest.contains('요약: Platinum 패키지 조건을 상세 논의'), '저장된 요약이 그대로 나와야 한다');
        System.assert(r.historyDigest.contains('고객 반응: Very Positive'), '저장된 고객 반응이 그대로 나와야 한다');
        System.assert(r.historyDigest.contains('우려/이견: 연간 금액이 예산 상단'), '저장된 우려사항이 그대로 나와야 한다');
        System.assert(
            r.historyDigest.contains('INTEREST · Positive · High — 먼저 Platinum 조건을 물어봄'),
            'Signal이 "Category · Direction · Confidence — Evidence" 형식이어야 한다'
        );
        System.assert(
            r.historyDigest.contains('BUDGET · Negative · Medium — 연간 금액이 부담된다고 언급'),
            '둘째 Signal도 같은 형식이어야 한다'
        );
    }

    @isTest
    static void testActivityWithoutIntelligenceIsNotHallucinated() {
        Test.startTest();
        ConversationHistoryAgentAction.Response r = run(String.valueOf(oppId('ConvHist Full Opp')));
        Test.stopTest();

        // The two plain Tasks have no II.
        System.assert(r.historyDigest.contains('AI 분석: 없음'), 'II 없는 활동은 "AI 분석: 없음"으로 표시되어야 한다');
        System.assert(
            r.historyDigest.contains('요약·반응·신호를 추측하지 마세요'),
            'II 없는 활동에는 추측 금지 안내가 붙어야 한다'
        );
    }

    @isTest
    static void testNoHistory() {
        Test.startTest();
        ConversationHistoryAgentAction.Response r = run(String.valueOf(oppId('ConvHist Empty Opp')));
        Test.stopTest();

        System.assertEquals(true, r.opportunityResolved, '유효 Opportunity면 opportunityResolved=true');
        System.assertEquals(false, r.hasHistory, '활동이 없으면 hasHistory=false');
        System.assertEquals(0, r.interactionCount, 'interactionCount=0');
        System.assertEquals(
            '이 Opportunity에는 기록된 고객 상호작용(통화·미팅·이메일·Task)이 없습니다.',
            r.historyDigest,
            '히스토리 없음 메시지가 명확해야 한다'
        );
        System.assertEquals(null, r.firstInteractionDate, '히스토리 없으면 firstInteractionDate는 비어 있어야 한다');
    }

    @isTest
    static void testSingleHistoryItem() {
        Test.startTest();
        ConversationHistoryAgentAction.Response r = run(String.valueOf(oppId('ConvHist Single Opp')));
        Test.stopTest();

        System.assertEquals(true, r.hasHistory, '1건이어도 hasHistory=true');
        System.assertEquals(1, r.interactionCount, 'interactionCount=1');
        System.assert(r.historyDigest.contains('[1] '), '단일 항목도 번호가 매겨진다');
        System.assert(r.historyDigest.contains('킥오프 통화'), '해당 활동 제목이 나와야 한다');
        System.assertEquals(r.firstInteractionDate, r.lastInteractionDate, '1건이면 first=last');
    }

    @isTest
    static void testMaxItemsReturnsMostRecentWindowChronologically() {
        Test.startTest();
        ConversationHistoryAgentAction.Response r = run(String.valueOf(oppId('ConvHist Full Opp')), 2);
        Test.stopTest();

        System.assertEquals(3, r.interactionCount, 'interactionCount는 전체 기준(3)이어야 한다');
        System.assert(r.historyDigest.contains('가장 최근 2건만'), '잘림 안내가 헤더에 있어야 한다');
        // 가장 오래된 통화는 window(최근 2건)에서 제외
        System.assert(!r.historyDigest.contains('1차 예산 탐색 통화'), '가장 오래된 활동은 최근 2건 window에서 빠져야 한다');
        // 남은 2건은 여전히 시간순
        Integer posMeeting = r.historyDigest.indexOf('Platinum 패키지 대면 미팅');
        Integer posFollowUp = r.historyDigest.indexOf('수정 제안서 발송 준비');
        System.assert(posMeeting >= 0 && posFollowUp >= 0 && posMeeting < posFollowUp, 'window 내에서도 오래된 것 먼저');
    }

    @isTest
    static void testResolutionFailureIsNotEmptyHistory() {
        Test.startTest();
        ConversationHistoryAgentAction.Response badFormat = run('not-an-id');
        ConversationHistoryAgentAction.Response nullId = run(null);
        Test.stopTest();

        for (ConversationHistoryAgentAction.Response r : new List<ConversationHistoryAgentAction.Response>{ badFormat, nullId }) {
            System.assertEquals(false, r.opportunityResolved, '잘못된 Id는 opportunityResolved=false');
            System.assertEquals(false, r.hasHistory, '해결 실패는 hasHistory=false');
            System.assert(r.historyDigest.contains('Opportunity를 특정하지 못했습니다'), '해결 실패 메시지여야 한다');
            System.assert(r.historyDigest.contains('없다는 뜻이 아닙니다'), '"히스토리 없다는 뜻이 아님" 안내가 붙어야 한다');
            System.assertNotEquals(
                '이 Opportunity에는 기록된 고객 상호작용(통화·미팅·이메일·Task)이 없습니다.',
                r.historyDigest,
                '해결 실패와 "히스토리 없음"은 서로 다른 메시지여야 한다'
            );
        }
    }

    @isTest
    static void testNonExistentButWellFormedOpportunityIdIsNoHistoryNotFailure() {
        // 006 prefix, 15 chars, valid Opportunity Id shape but no such record.
        Test.startTest();
        ConversationHistoryAgentAction.Response r = run('006000000000000');
        Test.stopTest();

        System.assertEquals(true, r.opportunityResolved, '형식이 유효한 Opportunity Id면 opportunityResolved=true');
        System.assertEquals(false, r.hasHistory, '존재하지 않는 Opportunity는 hasHistory=false');
        System.assertEquals(
            '이 Opportunity에는 기록된 고객 상호작용(통화·미팅·이메일·Task)이 없습니다.',
            r.historyDigest,
            '존재하지 않아도 조회 실패 없이 "히스토리 없음"으로 처리'
        );
    }

    @isTest
    static void testNonOpportunityIdRejected() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'ConvHist Corp' LIMIT 1];

        Test.startTest();
        ConversationHistoryAgentAction.Response r = run(String.valueOf(acc.Id));
        Test.stopTest();

        System.assertEquals(false, r.opportunityResolved, 'Account Id는 Opportunity가 아니므로 opportunityResolved=false');
        System.assert(r.historyDigest.contains('Opportunity를 특정하지 못했습니다'), '해결 실패 메시지여야 한다');
    }

    @isTest
    static void testBulkRequestsAligned() {
        ConversationHistoryAgentAction.Request a = new ConversationHistoryAgentAction.Request();
        a.opportunityId = String.valueOf(oppId('ConvHist Full Opp'));
        ConversationHistoryAgentAction.Request b = new ConversationHistoryAgentAction.Request();
        b.opportunityId = String.valueOf(oppId('ConvHist Empty Opp'));

        Test.startTest();
        List<ConversationHistoryAgentAction.Response> out =
            ConversationHistoryAgentAction.getConversationHistory(
                new List<ConversationHistoryAgentAction.Request>{ a, b }
            );
        Test.stopTest();

        System.assertEquals(2, out.size(), '요청 수만큼 응답');
        System.assertEquals(true, out[0].hasHistory, '첫 응답 = Full Opp');
        System.assertEquals(false, out[1].hasHistory, '둘째 응답 = Empty Opp');
    }

    @isTest
    static void testRunsUnderAgentAccessUserWithoutException() {
        // The action runs `with sharing` + WITH USER_MODE via
        // ActivityIntelligenceController.getActivityTimeline(). Under Standard User + the
        // Agent permission set it must complete gracefully — resolve the Opportunity, no
        // exception — and never report a valid Opportunity as a resolution failure.
        // Which timeline rows a given assignee sees depends on their sharing access to
        // the Opportunity (the correct USER_MODE contract), so this test does not pin an
        // exact row count for records owned by another user.
        Id fullOppId = oppId('ConvHist Full Opp');

        User agentUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CA_Opportunity_Agent_Access' LIMIT 1];
            Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            agentUser = new User(
                FirstName = 'CH', LastName = 'QA', Alias = 'chqa',
                Email = 'ch.qa@example.com.invalid',
                Username = 'ch.qa.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = std.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert agentUser;
            insert new PermissionSetAssignment(AssigneeId = agentUser.Id, PermissionSetId = ps.Id);
        }

        Test.startTest();
        System.runAs(agentUser) {
            ConversationHistoryAgentAction.Response r = run(String.valueOf(fullOppId));
            System.assertEquals(true, r.opportunityResolved,
                'Agent Access 사용자에게도 유효 Opportunity는 조회 실패가 아니라 정상 해결이어야 한다');
            System.assertNotEquals(null, r.historyDigest, 'digest는 항상 채워져야 한다 (예외 없이 완료)');
        }
        Test.stopTest();
    }
}

@isTest
private class DealContextTest {

    private static final String FULL_NAME = 'Deal Full O\'Alba';
    private static final String BARE_NAME = 'Deal Bare';

    @testSetup
    static void setupData() {
        Id stdPbId = Test.getStandardPricebookId();

        Account acct = new Account(Name = 'Deal Ctx Corp');
        insert acct;
        Contact primary = new Contact(
            FirstName = '지훈', LastName = '박', AccountId = acct.Id, Title = '파트너십 총괄'
        );
        insert primary;

        Product2 prod = new Product2(Name = 'Deal Ctx Package', IsActive = true);
        insert prod;
        insert new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = prod.Id, UnitPrice = 100000000, IsActive = true
        );

        // "Deal Full" — every readable field populated directly (no child Tasks, so the
        // CA_Update_Opportunity_Next_Activity Flow does not overwrite the count fields).
        Opportunity full = new Opportunity(
            Name = 'Deal Full O\'Alba',
            AccountId = acct.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30),
            Amount = 300000000,
            Probability = 35,
            Pricebook2Id = stdPbId,
            NextStep = '의사결정권자 미팅 잡기',
            Last_Contact_Date__c = Datetime.now().addDays(-10),
            Last_Contact_Type__c = 'Offline Meeting',
            Next_Activity_Date__c = Date.today().addDays(3),
            Next_Activity_Subject__c = '수정 제안서 검토',
            Open_Tasks_Count__c = 2,
            Overdue_Tasks_Count__c = 1,
            Decision_Maker_Accessible__c = '가능',
            Brand_Fan_Fit__c = '높음',
            Sponsorship_Interest_Level__c = '높음',
            Expected_Timing__c = '1~3개월 내',
            Client_Budget_Status__c = 'Confirmed',
            Partner_Tier__c = 'Gold',
            Deal_Note__c = '경쟁사 제안 검토 중, 예산은 확보됨',
            SDO_Sales_Primary_Contact__c = primary.Id
        );
        Opportunity bare = new Opportunity(
            Name = 'Deal Bare',
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(-5)
        );
        insert new List<Opportunity>{ full, bare };

        // Two Quotes on "Deal Full": an older synced one, a newer draft one.
        // Test.setCreatedDate pins the ordering so "latest" is deterministic.
        Quote qOld = new Quote(Name = 'Deal Full Quote v1', OpportunityId = full.Id, Pricebook2Id = stdPbId, Status = 'Presented');
        insert qOld;
        Quote qNew = new Quote(Name = 'Deal Full Quote v2', OpportunityId = full.Id, Pricebook2Id = stdPbId, Status = 'Draft');
        insert qNew;
        Test.setCreatedDate(qOld.Id, Datetime.now().addDays(-7));
        Test.setCreatedDate(qNew.Id, Datetime.now().addDays(-1));
        full.SyncedQuoteId = qOld.Id;
        update full;

        // Interaction_Intelligence__c has a validation rule tying Source_Record_Id__c's key
        // prefix to Source_Type__c (Call→Task, Meeting→Event). These activities carry no
        // WhatId, so the Opportunity task-rollup Flow does not touch the count fields set above.
        Event mtg = new Event(
            Subject = 'ctx meeting', StartDateTime = Datetime.now().addDays(-2),
            EndDateTime = Datetime.now().addDays(-2).addHours(1)
        );
        Task callTask = new Task(Subject = 'ctx call', Status = 'Completed', ActivityDate = Date.today().addDays(-1));
        insert new List<SObject>{ mtg, callTask };

        Interaction_Intelligence__c iiOld = new Interaction_Intelligence__c(
            Opportunity__c = full.Id, Source_Type__c = 'Offline Meeting', Source_Record_Id__c = mtg.Id,
            Summary__c = '초기 미팅', Customer_Reaction__c = 'Positive', Concerns_Objections__c = '초기 우려 없음'
        );
        Interaction_Intelligence__c iiNew = new Interaction_Intelligence__c(
            Opportunity__c = full.Id, Source_Type__c = 'Call', Source_Record_Id__c = callTask.Id,
            Summary__c = '후속 통화', Customer_Reaction__c = 'Neutral', Concerns_Objections__c = '연간 비용 부담, 경쟁사 비교 중'
        );
        insert new List<Interaction_Intelligence__c>{ iiOld, iiNew };
        Test.setCreatedDate(iiOld.Id, Datetime.now().addDays(-5));
        Test.setCreatedDate(iiNew.Id, Datetime.now().addDays(-1));

        insert new List<Interaction_Signal__c>{
            new Interaction_Signal__c(Interaction_Intelligence__c = iiOld.Id, Signal_Category__c = 'INTEREST', Signal_Type__c = 'High Interest', Direction__c = 'Positive', Confidence__c = 'High', Evidence__c = '고객이 관심을 보임'),
            new Interaction_Signal__c(Interaction_Intelligence__c = iiNew.Id, Signal_Category__c = 'RISK', Signal_Type__c = 'Stalled', Direction__c = 'Negative', Confidence__c = 'Medium', Evidence__c = '내부 검토 지연'),
            new Interaction_Signal__c(Interaction_Intelligence__c = iiNew.Id, Signal_Category__c = 'COMPETITION', Signal_Type__c = 'Competitor Mentioned', Direction__c = 'Negative', Confidence__c = 'High', Evidence__c = '경쟁사 제안 언급'),
            new Interaction_Signal__c(Interaction_Intelligence__c = iiNew.Id, Signal_Category__c = 'MOMENTUM', Signal_Type__c = 'Timing Risk', Direction__c = 'Negative', Confidence__c = 'Medium', Evidence__c = '응답 속도 느려짐'),
            new Interaction_Signal__c(Interaction_Intelligence__c = iiNew.Id, Signal_Category__c = 'BUDGET', Signal_Type__c = 'Budget Concern', Direction__c = 'Neutral', Confidence__c = 'Low', Evidence__c = '연간 비용 부담 언급')
        };
    }

    private static DealContext.Result run(Id oppId) {
        DealContext.Request req = new DealContext.Request();
        req.opportunityId = oppId;
        return DealContext.execute(new List<DealContext.Request>{ req })[0];
    }

    private static Id oppId(String name) {
        return [SELECT Id FROM Opportunity WHERE Name = :name LIMIT 1].Id;
    }

    @isTest
    static void testStoredFactsPassThrough() {
        Test.startTest();
        DealContext.Result r = run(oppId(FULL_NAME));
        Test.stopTest();

        System.assertEquals(true, r.found);
        System.assertEquals(FULL_NAME, r.opportunityName, 'apostrophe 이름도 그대로 반환');
        System.assertEquals('Deal Ctx Corp', r.accountName);
        System.assertEquals('Discovery', r.stageName);
        System.assertEquals(false, r.isClosed);
        System.assertEquals(false, r.isWon);
        System.assertEquals(300000000, r.amount);
        System.assertEquals(35, r.probability, 'Opportunity.Probability 그대로 — AI 예측 아님');
        System.assertEquals('의사결정권자 미팅 잡기', r.nextStep);
        System.assertEquals('Offline Meeting', r.lastContactType);
        System.assertEquals(2, r.openTaskCount);
        System.assertEquals(1, r.overdueTaskCount);
        System.assertEquals(Date.today().addDays(3), r.nextActivityDate);
        System.assertEquals('수정 제안서 검토', r.nextActivitySubject);
        System.assertEquals('가능', r.decisionMakerAccessible);
        System.assertEquals('높음', r.brandFanFit);
        System.assertEquals('높음', r.interestLevel);
        System.assertEquals('1~3개월 내', r.expectedTiming);
        System.assertEquals('Confirmed', r.clientBudgetStatus);
        System.assertEquals('Gold', r.partnerTier);
        System.assertEquals('경쟁사 제안 검토 중, 예산은 확보됨', r.dealNote);
        System.assertEquals(true, r.hasPrimaryContact);
        System.assert(r.primaryContactName != null && r.primaryContactName.contains('지훈'),
            'primary contact 이름: ' + r.primaryContactName);
    }

    @isTest
    static void testDerivedDateMath() {
        Test.startTest();
        DealContext.Result r = run(oppId(FULL_NAME));
        Test.stopTest();

        System.assertEquals(0, r.daysOpen, '테스트 컨텍스트에서 CreatedDate는 now → daysOpen 0');
        System.assertEquals(30, r.daysUntilClose, 'CloseDate = today + 30');
        System.assertEquals(false, r.closeDateIsPast, '미래 CloseDate는 past 아님');
        System.assert(r.daysSinceLastContactField != null && r.daysSinceLastContactField >= 9,
            'Days_Since_Last_Contact__c formula: ' + r.daysSinceLastContactField);
        System.assertEquals(1, r.daysSinceLatestInteraction, '가장 최근 II를 어제로 고정 → 1일');
    }

    @isTest
    static void testCloseDatePast() {
        Test.startTest();
        DealContext.Result r = run(oppId(BARE_NAME));
        Test.stopTest();

        System.assertEquals(-5, r.daysUntilClose, 'CloseDate = today - 5');
        System.assertEquals(true, r.closeDateIsPast, '지난 CloseDate + open deal → true');
    }

    @isTest
    static void testBareOpportunity() {
        Test.startTest();
        DealContext.Result r = run(oppId(BARE_NAME));
        Test.stopTest();

        System.assertEquals(true, r.found);
        System.assertEquals(BARE_NAME, r.opportunityName);
        System.assertEquals(null, r.accountName, 'Account 없음');
        System.assertEquals(false, r.hasPrimaryContact);
        System.assertEquals(null, r.primaryContactName);
        System.assertEquals(0, r.quoteCount, 'Quote 없음');
        System.assertEquals(false, r.hasSyncedQuote);
        System.assertEquals(null, r.latestQuoteStatus);
        System.assertEquals(false, r.hasInteractionIntelligence);
        System.assertEquals(0, r.interactionCount);
        System.assertEquals(null, r.latestInteractionDate);
        System.assertEquals(0, r.signalCount);
        System.assertEquals(0, r.negativeSignalCount);
        System.assertEquals(0, r.riskCategoryCount);
        System.assertEquals(null, r.daysSinceLastActivity, 'activity 없음');
        System.assertEquals(null, r.daysSinceLatestInteraction);
        System.assertEquals(null, r.nextActivityDate);
    }

    @isTest
    static void testUnknownOpportunityReturnsNotFound() {
        Opportunity ghost = new Opportunity(Name = 'Ghost', StageName = 'Qualification', CloseDate = Date.today());
        insert ghost;
        Id ghostId = ghost.Id;
        delete ghost;

        Test.startTest();
        DealContext.Result r = run(ghostId);
        Test.stopTest();

        System.assertEquals(false, r.found, '존재하지 않는 Opportunity → found = false');
        System.assertEquals(null, r.opportunityName);
        System.assertEquals(null, r.daysOpen);
    }

    @isTest
    static void testMultipleQuotesLatestVsSynced() {
        Test.startTest();
        DealContext.Result r = run(oppId(FULL_NAME));
        Test.stopTest();

        System.assertEquals(2, r.quoteCount, 'Quote 2건');
        System.assertEquals(true, r.hasSyncedQuote);
        System.assertEquals('Presented', r.syncedQuoteStatus, 'synced Quote는 v1 (Presented)');
        System.assertEquals('Draft', r.latestQuoteStatus, '가장 최근 생성 Quote는 v2 (Draft)');
        System.assertNotEquals(null, r.latestQuoteCreatedDate);
    }

    @isTest
    static void testInteractionSignalAggregate() {
        Test.startTest();
        DealContext.Result r = run(oppId(FULL_NAME));
        Test.stopTest();

        System.assertEquals(true, r.hasInteractionIntelligence);
        System.assertEquals(2, r.interactionCount);
        System.assertEquals('연간 비용 부담, 경쟁사 비교 중', r.latestConcernsObjections,
            '가장 최근 II의 Concerns_Objections__c 그대로');
        System.assertEquals(5, r.signalCount);
        System.assertEquals(3, r.negativeSignalCount, 'RISK/COMPETITION/MOMENTUM Negative');
        System.assertEquals(1, r.positiveSignalCount, 'INTEREST Positive');
        System.assertEquals(1, r.riskCategoryCount);
        System.assertEquals(1, r.competitionCategoryCount);
        System.assertEquals(1, r.momentumNegativeCount);
        System.assert(r.signalCategoryBreakdown != null
            && r.signalCategoryBreakdown.contains('RISK: 1 (Negative 1)')
            && r.signalCategoryBreakdown.contains('INTEREST: 1'),
            'breakdown: ' + r.signalCategoryBreakdown);
    }

    @isTest
    static void testNoJudgementFieldsExist() {
        // Guardrail: the Result must not carry a score / risk level / stalled flag /
        // recommended action. If someone adds one, this test forces a conscious decision.
        String serialized = JSON.serialize(run(oppId(FULL_NAME)));
        for (String banned : new List<String>{
            'healthScore', 'dealScore', 'riskScore', 'riskLevel', 'winProbability',
            'isStalled', 'stalledReason', 'recommendedAction', 'nextBestAction', 'grade'
        }) {
            System.assert(!serialized.contains('"' + banned + '"'),
                'DealContext.Result must not expose a judgement field: ' + banned);
        }
    }

    @isTest
    static void testBulkRequests() {
        Id fullId = oppId(FULL_NAME);
        Id bareId = oppId(BARE_NAME);

        List<DealContext.Request> reqs = new List<DealContext.Request>();
        for (Integer i = 0; i < 100; i++) {
            DealContext.Request rq = new DealContext.Request();
            rq.opportunityId = Math.mod(i, 2) == 0 ? fullId : bareId;
            reqs.add(rq);
        }

        Test.startTest();
        Integer soqlBefore = Limits.getQueries();
        Integer dmlBefore = Limits.getDmlStatements();
        List<DealContext.Result> out = DealContext.execute(reqs);
        Integer soqlUsed = Limits.getQueries() - soqlBefore;
        Integer dmlUsed = Limits.getDmlStatements() - dmlBefore;
        Test.stopTest();

        System.assertEquals(100, out.size());
        System.assertEquals(0, dmlUsed, 'DealContext는 DML을 하지 않는다');
        System.assert(soqlUsed <= 5, '요청 수와 무관하게 SOQL 소수: ' + soqlUsed);
        System.assertEquals(FULL_NAME, out[0].opportunityName);
        System.assertEquals(BARE_NAME, out[1].opportunityName);
    }

    @isTest
    static void testDaysSinceLastActivityFromLinkedTask() {
        // A completed Task linked to a fresh Opportunity rolls up into LastActivityDate.
        Opportunity o = new Opportunity(
            Name = 'Deal With Activity', StageName = 'Discovery', CloseDate = Date.today().addDays(20)
        );
        insert o;
        insert new Task(
            WhatId = o.Id, Subject = '고객 통화', Status = 'Completed',
            ActivityDate = Date.today().addDays(-7)
        );

        Test.startTest();
        DealContext.Result r = run(o.Id);
        Test.stopTest();

        System.assertEquals(Date.today().addDays(-7), r.lastActivityDate, 'LastActivityDate 롤업 확인');
        System.assertEquals(7, r.daysSinceLastActivity, 'today - LastActivityDate');
    }

    @isTest
    static void testDaysSinceLastStageChange() {
        Opportunity bare = [SELECT Id FROM Opportunity WHERE Name = :BARE_NAME LIMIT 1];
        bare.StageName = 'Discovery';
        update bare;

        Test.startTest();
        DealContext.Result r = run(bare.Id);
        Test.stopTest();

        // In test context the stage change happens "now" → 0 days (or null if the
        // platform did not stamp it). A positive value would be wrong.
        System.assert(r.daysSinceLastStageChange == null || r.daysSinceLastStageChange == 0,
            'daysSinceLastStageChange: ' + r.daysSinceLastStageChange);
    }

    // A Standard User + CA_Opportunity_Agent_Access (the real agent execution context)
    // must be able to run every DealContext SOQL — all `WITH USER_MODE` — without an
    // FLS/CRUD exception. The Opportunity, Quote, Interaction Intelligence and Signal are
    // all OWNED by the agent user so record-level sharing is not the variable; this
    // isolates the field/object permission grants in the permission set.
    @isTest
    static void testRunsUnderAgentAccessUser() {
        Id stdPbId = Test.getStandardPricebookId();
        User agentUser;
        Id ownedOppId;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CA_Opportunity_Agent_Access' LIMIT 1];
            Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            agentUser = new User(
                FirstName = 'DC', LastName = 'QA', Alias = 'dcqa',
                Email = 'dc.qa@example.com.invalid',
                Username = 'dc.qa.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = std.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert agentUser;
            insert new PermissionSetAssignment(AssigneeId = agentUser.Id, PermissionSetId = ps.Id);

            Account a = new Account(Name = 'DC Agent QA Corp', OwnerId = agentUser.Id);
            insert a;
            // Discovery (not Negotiation) so the org's Negotiation_Followup_Flow does not
            // fire and create a Task that would recalculate the next-activity / task-count
            // fields set directly below.
            Opportunity owned = new Opportunity(
                Name = 'DC Agent QA Deal',
                AccountId = a.Id,
                StageName = 'Discovery',
                CloseDate = Date.today().addDays(5),
                Amount = 200000000,
                Probability = 35,
                OwnerId = agentUser.Id,
                NextStep = '최종 조건 합의',
                Last_Contact_Date__c = Datetime.now().addDays(-12),
                Last_Contact_Type__c = 'Call',
                Next_Activity_Date__c = Date.today().addDays(2),
                Next_Activity_Subject__c = '계약서 검토',
                Open_Tasks_Count__c = 3,
                Overdue_Tasks_Count__c = 2,
                Expected_Timing__c = '즉시 추진 가능',
                Deal_Note__c = '예산 승인 대기 중',
                Partner_Tier__c = 'Gold'
            );
            insert owned;
            ownedOppId = owned.Id;

            Quote q = new Quote(Name = 'DC QA Quote', OpportunityId = owned.Id, Pricebook2Id = stdPbId, Status = 'Presented');
            insert q;

            // Interaction_Intelligence__c validation ties Source_Record_Id__c's key prefix
            // to Source_Type__c: Call → Task (00T).
            Task callTask = new Task(Subject = 'dc qa call', Status = 'Completed', ActivityDate = Date.today().addDays(-1));
            insert callTask;
            Interaction_Intelligence__c ii = new Interaction_Intelligence__c(
                Opportunity__c = owned.Id,
                Source_Type__c = 'Call',
                Source_Record_Id__c = callTask.Id,
                Summary__c = '조건 재협의',
                Concerns_Objections__c = '내부 예산 승인 지연'
            );
            insert ii;
            insert new Interaction_Signal__c(
                Interaction_Intelligence__c = ii.Id, Signal_Category__c = 'BUDGET',
                Signal_Type__c = 'Budget Concern', Direction__c = 'Negative',
                Confidence__c = 'High', Evidence__c = '예산 승인 지연 언급'
            );
        }

        Test.startTest();
        System.runAs(agentUser) {
            DealContext.Result r = run(ownedOppId);

            System.assertEquals(true, r.found, 'Agent Access 사용자도 본인 딜의 DealContext를 읽을 수 있어야 한다');
            System.assertEquals('DC Agent QA Deal', r.opportunityName);
            System.assertEquals('Discovery', r.stageName);
            System.assertEquals(200000000, r.amount, '표준 Amount FLS');
            System.assertEquals(35, r.probability, '표준 Probability FLS');
            System.assertEquals('Call', r.lastContactType, 'Last_Contact_Type__c FLS (permission set으로 부여)');
            System.assertEquals('계약서 검토', r.nextActivitySubject, 'Next_Activity_Subject__c FLS');
            System.assertEquals(2, r.overdueTaskCount, 'Overdue_Tasks_Count__c FLS');
            System.assertEquals('예산 승인 대기 중', r.dealNote, 'Deal_Note__c FLS');
            System.assertEquals('즉시 추진 가능', r.expectedTiming, 'Expected_Timing__c FLS');
            System.assertNotEquals(null, r.daysSinceLastContactField, 'Days_Since_Last_Contact__c (formula) FLS — 예외 없이 읽혀야 한다');
            System.assertEquals(1, r.quoteCount, 'Quote WITH USER_MODE 조회');
            System.assertEquals(true, r.hasInteractionIntelligence, 'II WITH USER_MODE 조회');
            System.assertEquals(1, r.signalCount, 'Signal WITH USER_MODE 조회');
            System.assertEquals(1, r.negativeSignalCount);
        }
        Test.stopTest();
    }
}

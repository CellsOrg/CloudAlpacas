@isTest
private class NegotiationContextTest {

    @testSetup
    static void setupData() {
        Id stdPbId = Test.getStandardPricebookId();

        Account acct = new Account(Name = 'Nego Ctx Corp');
        insert acct;
        Contact primary = new Contact(
            FirstName = '수민', LastName = '김', AccountId = acct.Id,
            Title = '마케팅 이사', Email = 'sumin.kim@example.com.invalid', Phone = '010-0000-0000'
        );
        insert primary;

        Product2 prod = new Product2(Name = '전광판 광고 패키지', IsActive = true, Tier__c = 'Premium');
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = prod.Id, UnitPrice = 300000000, IsActive = true,
            Max_Discount_Percent__c = 6, Max_Discounted_Price__c = 282000000
        );
        insert pbe;

        Opportunity withQuote = new Opportunity(
            Name = 'Nego With Quote', AccountId = acct.Id, StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30), Pricebook2Id = stdPbId,
            Client_Budget__c = 280000000, Client_Budget_Status__c = 'Confirmed',
            Customer_Needs__c = '20-30대 팬 노출 극대화', Key_Requirements__c = '홈경기 전 경기 노출',
            Customer_KPI__c = '브랜드 인지도 15%p 상승', Target_Start_Season__c = 2026,
            Partner_Tier__c = 'Gold', SDO_Sales_Primary_Contact__c = primary.Id
        );
        Opportunity noQuote = new Opportunity(
            Name = 'Nego No Quote', AccountId = acct.Id, StageName = 'Proposal/Quote',
            CloseDate = Date.today().addDays(30)
        );
        insert new List<Opportunity>{ withQuote, noQuote };

        Quote q = new Quote(
            Name = 'Nego Quote', OpportunityId = withQuote.Id, Pricebook2Id = stdPbId,
            Status = 'In Review', ExpirationDate = Date.today().addDays(15)
        );
        insert q;
        insert new QuoteLineItem(
            QuoteId = q.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 300000000, Discount = 3
        );

        Task callTask = new Task(
            WhatId = withQuote.Id, Subject = '예산 재확인 통화', Status = 'Completed',
            TaskSubtype = 'Call', ActivityDate = Date.today().addDays(-3), Description = '예산 상한 확인'
        );
        Event mtg = new Event(
            WhatId = withQuote.Id, Subject = '가격 협상 미팅',
            StartDateTime = Datetime.now().addDays(-1), EndDateTime = Datetime.now().addDays(-1).addHours(1),
            Description = '할인율 논의'
        );
        insert new List<SObject>{ callTask, mtg };

        insert new Interaction_Intelligence__c(
            Opportunity__c = withQuote.Id, Source_Type__c = 'Offline Meeting', Source_Record_Id__c = mtg.Id,
            Summary__c = '가격 협상 미팅', Customer_Reaction__c = 'Neutral',
            Key_Decision__c = '내부 검토 후 회신', Concerns_Objections__c = '연간 금액 부담',
            Follow_Up__c = '수정 견적 발송'
        );
    }

    private static NegotiationContext.Result run(Id oppId) {
        NegotiationContext.Request req = new NegotiationContext.Request();
        req.opportunityId = oppId;
        return NegotiationContext.execute(new List<NegotiationContext.Request>{ req })[0];
    }

    private static Id oppId(String name) {
        return [SELECT Id FROM Opportunity WHERE Name = :name LIMIT 1].Id;
    }

    @isTest
    static void testReturnsQuoteAndPolicyLimits() {
        Test.startTest();
        NegotiationContext.Result r = run(oppId('Nego With Quote'));
        Test.stopTest();

        System.assertEquals('Nego With Quote', r.opportunityName);
        System.assertEquals(true, r.hasQuote, 'Quote가 있으면 hasQuote=true');
        System.assertNotEquals(null, r.quoteId, 'quoteId가 채워져야 한다');
        System.assertEquals('In Review', r.quoteStatus);
        System.assertNotEquals(null, r.quoteLineItemId, 'primary QuoteLineItem Id가 채워져야 한다');
        System.assertEquals(3, r.quoteDiscount, '현재 라인아이템 할인율이 반환되어야 한다');
        System.assertEquals(6, r.maxDiscountPercent, '저장된 최대 할인율(정책 한도)이 반환되어야 한다');
        System.assertEquals(282000000, r.maxDiscountedPrice, '저장된 최소 판매가(정책 한도)가 반환되어야 한다');
        System.assertEquals('Premium', r.productTier);
        System.assert(r.lineItemsSummary.contains('전광판 광고 패키지'), '라인아이템 요약에 상품명이 있어야 한다');
        System.assertEquals(true, r.lineItemDiscountUpdatable,
            '매출 일정이 없는 라인아이템은 할인율 변경이 가능하다고 보고되어야 한다');
        System.assertEquals(null, r.lineItemDiscountLockReason, '할인율 잠금 사유가 없어야 한다');
    }

    @isTest
    static void testReturnsBudgetAndRequirements() {
        Test.startTest();
        NegotiationContext.Result r = run(oppId('Nego With Quote'));
        Test.stopTest();

        System.assertEquals(280000000, r.clientBudget);
        System.assertEquals('Confirmed', r.clientBudgetStatus);
        System.assertEquals('20-30대 팬 노출 극대화', r.customerNeeds);
        System.assertEquals('홈경기 전 경기 노출', r.keyRequirements);
        System.assertEquals('브랜드 인지도 15%p 상승', r.customerKPI);
        System.assertEquals('Gold', r.partnerTier);
    }

    @isTest
    static void testReturnsPrimaryContact() {
        Test.startTest();
        NegotiationContext.Result r = run(oppId('Nego With Quote'));
        Test.stopTest();

        System.assertEquals(true, r.hasPrimaryContact);
        System.assert(String.isNotBlank(r.primaryContactName)
            && r.primaryContactName.contains('수민') && r.primaryContactName.contains('김'),
            'primary contact 이름이 채워져야 한다: ' + r.primaryContactName);
        System.assertEquals('마케팅 이사', r.primaryContactTitle);
    }

    @isTest
    static void testReturnsInteractionAndActivityHistory() {
        Test.startTest();
        NegotiationContext.Result r = run(oppId('Nego With Quote'));
        Test.stopTest();

        System.assertEquals(true, r.hasInteractionIntelligence);
        System.assert(r.interactionHistorySummary.contains('연간 금액 부담'), '우려사항이 요약에 포함되어야 한다');
        System.assertEquals(true, r.hasActivityHistory);
        System.assert(r.activityHistorySummary.contains('예산 재확인 통화'), 'Task 이력이 요약에 포함되어야 한다');
        System.assert(r.activityHistorySummary.contains('가격 협상 미팅'), 'Event 이력이 요약에 포함되어야 한다');
    }

    @isTest
    static void testNoQuote() {
        Test.startTest();
        NegotiationContext.Result r = run(oppId('Nego No Quote'));
        Test.stopTest();

        System.assertEquals('Nego No Quote', r.opportunityName);
        System.assertEquals(false, r.hasQuote, 'Quote가 없으면 hasQuote=false');
        System.assertEquals(null, r.quoteId, 'quoteId는 비어 있어야 한다');
        System.assertEquals(null, r.quoteLineItemId, 'quoteLineItemId도 비어 있어야 한다');
    }

    @isTest
    static void testUnknownOpportunityReturnsEmptyResult() {
        // A real, deleted Opportunity Id: valid Id shape, no live record.
        Opportunity ghost = new Opportunity(
            Name = 'Ghost Opp', StageName = 'Qualification', CloseDate = Date.today().addDays(5)
        );
        insert ghost;
        Id ghostId = ghost.Id;
        delete ghost;

        Test.startTest();
        NegotiationContext.Result r = run(ghostId);
        Test.stopTest();

        System.assertEquals(null, r.opportunityName, '존재하지 않는 Opportunity면 이름이 비어 있어야 한다');
        System.assertEquals(false, r.hasQuote);
    }

    @isTest
    static void testBulkRequests() {
        Id withQ = oppId('Nego With Quote');
        Id noQ = oppId('Nego No Quote');

        NegotiationContext.Request r1 = new NegotiationContext.Request();
        r1.opportunityId = withQ;
        NegotiationContext.Request r2 = new NegotiationContext.Request();
        r2.opportunityId = noQ;

        Test.startTest();
        List<NegotiationContext.Result> out =
            NegotiationContext.execute(new List<NegotiationContext.Request>{ r1, r2 });
        Test.stopTest();

        System.assertEquals(2, out.size());
        System.assertEquals(true, out[0].hasQuote);
        System.assertEquals(false, out[1].hasQuote);
    }

    @isTest
    static void testRunsUnderAgentAccessUser() {
        // An Opportunity + Quote + line item OWNED by the agent user, so record-level
        // sharing is not the variable — this isolates FLS / object-permission access
        // under Standard User + CA_Opportunity_Agent_Access.
        Id stdPbId = Test.getStandardPricebookId();
        User agentUser;
        Opportunity ownedOpp;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CA_Opportunity_Agent_Access' LIMIT 1];
            Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            agentUser = new User(
                FirstName = 'NC', LastName = 'QA', Alias = 'ncqa',
                Email = 'nc.qa@example.com.invalid',
                Username = 'nc.qa.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = std.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert agentUser;
            insert new PermissionSetAssignment(AssigneeId = agentUser.Id, PermissionSetId = ps.Id);

            Product2 p = [SELECT Id FROM Product2 WHERE Name = '전광판 광고 패키지' LIMIT 1];
            PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :p.Id AND Pricebook2Id = :stdPbId LIMIT 1];
            ownedOpp = new Opportunity(
                Name = 'Nego Owned Opp', StageName = 'Negotiation/Review',
                CloseDate = Date.today().addDays(30), Pricebook2Id = stdPbId,
                Partner_Tier__c = 'Gold', OwnerId = agentUser.Id
            );
            insert ownedOpp;
            Quote oq = new Quote(Name = 'Owned Quote', OpportunityId = ownedOpp.Id, Pricebook2Id = stdPbId, Status = 'In Review');
            insert oq;
            insert new QuoteLineItem(QuoteId = oq.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = pbe.UnitPrice, Discount = 2);
        }

        Test.startTest();
        System.runAs(agentUser) {
            NegotiationContext.Result r = run(ownedOpp.Id);
            System.assertEquals('Nego Owned Opp', r.opportunityName, 'Agent Access 사용자도 본인 딜의 컨텍스트를 읽을 수 있어야 한다');
            System.assertEquals(true, r.hasQuote, 'USER_MODE 하에서도 Quote가 조회되어야 한다');
            System.assertNotEquals(null, r.quoteLineItemId, 'USER_MODE 하에서도 QuoteLineItem이 조회되어야 한다');
            System.assertEquals('Gold', r.partnerTier, 'Partner_Tier__c FLS가 permission set으로 부여되어 읽혀야 한다');
        }
        Test.stopTest();
    }
}

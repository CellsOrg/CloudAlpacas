@isTest
private class NegotiationContextControllerTest {

    @testSetup
    static void setupData() {
        Id stdPbId = Test.getStandardPricebookId();

        Account acct = new Account(Name = 'Nego Ctrl Corp');
        insert acct;
        Contact primary = new Contact(
            FirstName = '지훈', LastName = '박', AccountId = acct.Id,
            Title = '제휴 팀장', Email = 'jihoon.park@example.com.invalid', Phone = '010-1111-2222'
        );
        insert primary;

        Product2 prod = new Product2(Name = '펜스 광고 패키지', IsActive = true, Tier__c = 'Premium');
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = prod.Id, UnitPrice = 500000000, IsActive = true,
            Max_Discount_Percent__c = 8, Max_Discounted_Price__c = 460000000
        );
        insert pbe;

        // 'Negotiation/Review' (inactive legacy stage) keeps Negotiation_Followup_Flow from
        // firing during @testSetup while still being a normal open Opportunity for the read.
        Opportunity withQuote = new Opportunity(
            Name = 'Ctrl With Quote', AccountId = acct.Id, StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30), Pricebook2Id = stdPbId,
            Client_Budget__c = 480000000, Client_Budget_Status__c = 'Confirmed',
            Customer_Needs__c = '핵심 타깃 노출', Key_Requirements__c = '홈경기 노출',
            Customer_KPI__c = '인지도 상승', Target_Start_Season__c = 2026,
            Partner_Tier__c = 'Gold', SDO_Sales_Primary_Contact__c = primary.Id
        );
        Opportunity noQuote = new Opportunity(
            Name = 'Ctrl No Quote', AccountId = acct.Id, StageName = 'Proposal/Quote',
            CloseDate = Date.today().addDays(30)
        );
        insert new List<Opportunity>{ withQuote, noQuote };

        Quote q = new Quote(
            Name = 'Ctrl Quote', OpportunityId = withQuote.Id, Pricebook2Id = stdPbId,
            Status = 'Presented', ExpirationDate = Date.today().addDays(15)
        );
        insert q;
        insert new QuoteLineItem(
            QuoteId = q.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 500000000, Discount = 4
        );

        Task callTask = new Task(
            WhatId = withQuote.Id, Subject = '예산 재확인 통화', Status = 'Completed',
            TaskSubtype = 'Call', ActivityDate = Date.today().addDays(-2), Description = '상한 확인'
        );
        insert callTask;

        insert new Interaction_Intelligence__c(
            Opportunity__c = withQuote.Id, Source_Type__c = 'Call', Source_Record_Id__c = callTask.Id,
            Summary__c = '예산 재확인 통화', Customer_Reaction__c = 'Neutral',
            Key_Decision__c = '내부 검토 후 회신', Concerns_Objections__c = '연간 금액 부담',
            Follow_Up__c = '수정 견적 발송'
        );
    }

    private static Id oppId(String name) {
        return [SELECT Id FROM Opportunity WHERE Name = :name LIMIT 1].Id;
    }

    @isTest
    static void testMapsQuoteBudgetAndPolicy() {
        Test.startTest();
        NegotiationContextController.NegotiationContextView v =
            NegotiationContextController.getContext(oppId('Ctrl With Quote'));
        Test.stopTest();

        System.assertNotEquals(null, v, 'View가 반환되어야 한다');
        System.assertEquals('Ctrl With Quote', v.opportunityName);
        System.assertEquals(480000000, v.clientBudget);
        System.assertEquals('Confirmed', v.clientBudgetStatus);

        System.assertEquals(true, v.hasQuote);
        System.assertEquals('Ctrl Quote', v.quoteName);
        System.assertEquals('Presented', v.quoteStatus);

        System.assertEquals(4, v.quoteDiscount, '현재 라인아이템 할인율이 그대로 전달되어야 한다');
        System.assertEquals(8, v.maxDiscountPercent, '승인 없이 가능한 최대 할인율(정책 한도)이 전달되어야 한다');
        System.assertEquals(460000000, v.maxDiscountedPrice, '최소 판매가 하한선이 전달되어야 한다');
        System.assertEquals(true, v.lineItemDiscountUpdatable,
            '매출 일정이 없으면 할인율 변경 제한이 없다고 보고되어야 한다');
        System.assertEquals(null, v.lineItemDiscountLockReason);
    }

    @isTest
    static void testMapsInteractionIntelligence() {
        Test.startTest();
        NegotiationContextController.NegotiationContextView v =
            NegotiationContextController.getContext(oppId('Ctrl With Quote'));
        Test.stopTest();

        System.assertEquals(true, v.hasInteractionIntelligence);
        System.assert(
            v.interactionHistorySummary != null && v.interactionHistorySummary.contains('연간 금액 부담'),
            '최근 상호작용 우려사항이 요약에 포함되어야 한다: ' + v.interactionHistorySummary
        );
    }

    @isTest
    static void testNoQuoteLeavesQuoteFieldsEmpty() {
        Test.startTest();
        NegotiationContextController.NegotiationContextView v =
            NegotiationContextController.getContext(oppId('Ctrl No Quote'));
        Test.stopTest();

        System.assertNotEquals(null, v);
        System.assertEquals('Ctrl No Quote', v.opportunityName);
        System.assertEquals(false, v.hasQuote);
        System.assertEquals(null, v.quoteName);
        System.assertEquals(null, v.quoteStatus);
        System.assertEquals(null, v.quoteGrandTotal);
        System.assertEquals(null, v.quoteDiscount);
        System.assertEquals(null, v.maxDiscountPercent);
        System.assertEquals(false, v.hasInteractionIntelligence);
    }

    @isTest
    static void testNullOpportunityIdReturnsNull() {
        Test.startTest();
        System.assertEquals(null, NegotiationContextController.getContext(null),
            'opportunityId가 null이면 null을 반환해야 한다');
        Test.stopTest();
    }

    @isTest
    static void testUnknownOpportunityReturnsNull() {
        Opportunity ghost = new Opportunity(
            Name = 'Ctrl Ghost', StageName = 'Qualification', CloseDate = Date.today().addDays(5)
        );
        insert ghost;
        Id ghostId = ghost.Id;
        delete ghost;

        Test.startTest();
        NegotiationContextController.NegotiationContextView v =
            NegotiationContextController.getContext(ghostId);
        Test.stopTest();

        System.assertEquals(null, v, '존재하지 않는 Opportunity면 null을 반환해야 한다');
    }

    @isTest
    static void testRunsUnderAgentAccessUser() {
        Id stdPbId = Test.getStandardPricebookId();
        User agentUser;
        Opportunity ownedOpp;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CA_Opportunity_Agent_Access' LIMIT 1];
            Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            agentUser = new User(
                FirstName = 'NCC', LastName = 'QA', Alias = 'nccqa',
                Email = 'ncc.qa@example.com.invalid',
                Username = 'ncc.qa.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = std.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert agentUser;
            insert new PermissionSetAssignment(AssigneeId = agentUser.Id, PermissionSetId = ps.Id);

            Product2 p = [SELECT Id FROM Product2 WHERE Name = '펜스 광고 패키지' LIMIT 1];
            PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :p.Id AND Pricebook2Id = :stdPbId LIMIT 1];
            ownedOpp = new Opportunity(
                Name = 'Ctrl Owned Opp', StageName = 'Negotiation/Review',
                CloseDate = Date.today().addDays(30), Pricebook2Id = stdPbId,
                Partner_Tier__c = 'Gold', Client_Budget__c = 400000000, OwnerId = agentUser.Id
            );
            insert ownedOpp;
            Quote oq = new Quote(Name = 'Ctrl Owned Quote', OpportunityId = ownedOpp.Id, Pricebook2Id = stdPbId, Status = 'Presented');
            insert oq;
            insert new QuoteLineItem(QuoteId = oq.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = pbe.UnitPrice, Discount = 2);
        }

        Test.startTest();
        System.runAs(agentUser) {
            NegotiationContextController.NegotiationContextView v =
                NegotiationContextController.getContext(ownedOpp.Id);
            System.assertNotEquals(null, v, 'Agent Access 사용자도 본인 딜의 협상 컨텍스트를 읽을 수 있어야 한다');
            System.assertEquals('Ctrl Owned Opp', v.opportunityName);
            System.assertEquals(true, v.hasQuote, 'USER_MODE 하에서도 Quote가 조회되어야 한다');
            System.assertEquals(8, v.maxDiscountPercent, 'PricebookEntry 할인 정책 필드가 permission set FLS로 읽혀야 한다');
        }
        Test.stopTest();
    }
}

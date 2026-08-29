@isTest
private class NegotiationTermsUpdaterTest {

    @testSetup
    static void setupData() {
        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(Name = 'Test Sponsorship Package', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = prod.Id, UnitPrice = 100000000, IsActive = true
        );
        insert pbe;

        Opportunity oppA = new Opportunity(
            Name = 'Terms Opp A', StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30), Pricebook2Id = stdPbId
        );
        Opportunity oppB = new Opportunity(
            Name = 'Terms Opp B', StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30), Pricebook2Id = stdPbId
        );
        insert new List<Opportunity>{ oppA, oppB };

        Quote qA = new Quote(Name = 'Quote A', OpportunityId = oppA.Id, Pricebook2Id = stdPbId, Status = 'Draft');
        Quote qB = new Quote(Name = 'Quote B', OpportunityId = oppB.Id, Pricebook2Id = stdPbId, Status = 'Draft');
        insert new List<Quote>{ qA, qB };

        insert new List<QuoteLineItem>{
            new QuoteLineItem(QuoteId = qA.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100000000),
            new QuoteLineItem(QuoteId = qB.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100000000)
        };
    }

    private static Quote quoteFor(String oppName) {
        return [SELECT Id, (SELECT Id FROM QuoteLineItems) FROM Quote WHERE Opportunity.Name = :oppName LIMIT 1];
    }

    private static NegotiationTermsUpdater.Result run(NegotiationTermsUpdater.Request req) {
        return NegotiationTermsUpdater.execute(new List<NegotiationTermsUpdater.Request>{ req })[0];
    }

    @isTest
    static void testStatusOnlyUpdate() {
        Quote q = quoteFor('Terms Opp A');
        NegotiationTermsUpdater.Request req = new NegotiationTermsUpdater.Request();
        req.quoteId = q.Id;
        req.status = 'In Review';

        Test.startTest();
        NegotiationTermsUpdater.Result r = run(req);
        Test.stopTest();

        System.assertEquals(true, r.success, '상태만 바꾸는 갱신은 성공해야 한다');
        System.assertEquals('In Review', r.updatedStatus, '반환된 상태가 새 값이어야 한다');
        System.assertEquals('In Review', [SELECT Status FROM Quote WHERE Id = :q.Id].Status, 'DB의 Quote 상태가 갱신되어야 한다');
    }

    @isTest
    static void testDiscountUpdateOnLineItem() {
        // Normal path: a line item WITHOUT a revenue schedule — the pre-flight
        // HasRevenueSchedule guard must not block it.
        Quote q = quoteFor('Terms Opp A');
        NegotiationTermsUpdater.Request req = new NegotiationTermsUpdater.Request();
        req.quoteId = q.Id;
        req.quoteLineItemId = q.QuoteLineItems[0].Id;
        req.discount = 8;

        Test.startTest();
        NegotiationTermsUpdater.Result r = run(req);
        Test.stopTest();

        System.assertEquals(true, r.success, '할인율 갱신은 성공해야 한다');
        System.assertEquals(8, r.updatedDiscount, '반환된 할인율이 새 값이어야 한다');
        System.assertEquals(8, [SELECT Discount FROM QuoteLineItem WHERE Id = :q.QuoteLineItems[0].Id].Discount,
            'DB의 QuoteLineItem 할인율이 갱신되어야 한다');
    }

    @isTest
    static void testDiscountWithoutLineItemIdThrows() {
        Quote q = quoteFor('Terms Opp A');
        NegotiationTermsUpdater.Request req = new NegotiationTermsUpdater.Request();
        req.quoteId = q.Id;
        req.discount = 5; // no quoteLineItemId

        Test.startTest();
        Boolean threw = false;
        try {
            run(req);
        } catch (NegotiationTermsUpdater.NegotiationTermsUpdaterException e) {
            threw = true;
            System.assert(e.getMessage().contains('quoteLineItemId'), '메시지에 quoteLineItemId 언급이 있어야 한다');
        }
        Test.stopTest();

        System.assert(threw, 'quoteLineItemId 없이 discount만 주면 예외가 발생해야 한다');
    }

    @isTest
    static void testNothingToUpdateThrows() {
        Quote q = quoteFor('Terms Opp A');
        NegotiationTermsUpdater.Request req = new NegotiationTermsUpdater.Request();
        req.quoteId = q.Id; // no values at all

        Test.startTest();
        Boolean threw = false;
        try {
            run(req);
        } catch (NegotiationTermsUpdater.NegotiationTermsUpdaterException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, '갱신할 값이 하나도 없으면 예외가 발생해야 한다');
    }

    @isTest
    static void testUpdateTargetsOnlyTheGivenQuote() {
        Quote qA = quoteFor('Terms Opp A');
        Quote qB = quoteFor('Terms Opp B');

        NegotiationTermsUpdater.Request req = new NegotiationTermsUpdater.Request();
        req.quoteId = qA.Id;
        req.status = 'Approved';

        Test.startTest();
        run(req);
        Test.stopTest();

        System.assertEquals('Approved', [SELECT Status FROM Quote WHERE Id = :qA.Id].Status, '대상 Quote만 갱신');
        System.assertEquals('Draft', [SELECT Status FROM Quote WHERE Id = :qB.Id].Status, '다른 Quote는 그대로여야 한다');
    }

    @isTest
    static void testExpirationAndDescriptionUpdate() {
        Quote q = quoteFor('Terms Opp A');
        Date newExp = Date.today().addDays(20);
        NegotiationTermsUpdater.Request req = new NegotiationTermsUpdater.Request();
        req.quoteId = q.Id;
        req.expirationDate = newExp;
        req.description = '2년 계약 조건으로 재협의';

        Test.startTest();
        NegotiationTermsUpdater.Result r = run(req);
        Test.stopTest();

        System.assertEquals(true, r.success);
        Quote after = [SELECT ExpirationDate, Description FROM Quote WHERE Id = :q.Id];
        System.assertEquals(newExp, after.ExpirationDate, '유효기한이 갱신되어야 한다');
        System.assertEquals('2년 계약 조건으로 재협의', after.Description, '조건 메모가 갱신되어야 한다');
    }

    @isTest
    static void testBulkRequests() {
        Quote qA = quoteFor('Terms Opp A');
        Quote qB = quoteFor('Terms Opp B');

        NegotiationTermsUpdater.Request r1 = new NegotiationTermsUpdater.Request();
        r1.quoteId = qA.Id;
        r1.status = 'Presented';
        NegotiationTermsUpdater.Request r2 = new NegotiationTermsUpdater.Request();
        r2.quoteId = qB.Id;
        r2.status = 'Needs Review';

        Test.startTest();
        List<NegotiationTermsUpdater.Result> out =
            NegotiationTermsUpdater.execute(new List<NegotiationTermsUpdater.Request>{ r1, r2 });
        Test.stopTest();

        System.assertEquals(2, out.size(), '요청 수만큼 결과');
        System.assertEquals('Presented', [SELECT Status FROM Quote WHERE Id = :qA.Id].Status);
        System.assertEquals('Needs Review', [SELECT Status FROM Quote WHERE Id = :qB.Id].Status);
    }

    @isTest
    static void testRunsUnderAgentAccessUser() {
        // Opportunity + Quote + line item owned by the agent user, so this isolates
        // object-permission access (QuoteLineItem edit) under Standard User +
        // CA_Opportunity_Agent_Access rather than record-level sharing.
        Id stdPbId = Test.getStandardPricebookId();
        User agentUser;
        Quote ownedQuote;
        QuoteLineItem ownedQli;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CA_Opportunity_Agent_Access' LIMIT 1];
            Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            agentUser = new User(
                FirstName = 'NT', LastName = 'QA', Alias = 'ntqa',
                Email = 'nt.qa@example.com.invalid',
                Username = 'nt.qa.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = std.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert agentUser;
            insert new PermissionSetAssignment(AssigneeId = agentUser.Id, PermissionSetId = ps.Id);

            PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
            Opportunity ownedOpp = new Opportunity(
                Name = 'Terms Owned Opp', StageName = 'Negotiation/Review',
                CloseDate = Date.today().addDays(30), Pricebook2Id = stdPbId, OwnerId = agentUser.Id
            );
            insert ownedOpp;
            ownedQuote = new Quote(Name = 'Owned Quote', OpportunityId = ownedOpp.Id, Pricebook2Id = stdPbId, Status = 'Draft');
            insert ownedQuote;
            ownedQli = new QuoteLineItem(QuoteId = ownedQuote.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = pbe.UnitPrice);
            insert ownedQli;
        }

        Test.startTest();
        System.runAs(agentUser) {
            NegotiationTermsUpdater.Request req = new NegotiationTermsUpdater.Request();
            req.quoteId = ownedQuote.Id;
            req.quoteLineItemId = ownedQli.Id;
            req.discount = 4;
            req.status = 'In Review';
            NegotiationTermsUpdater.Result r = run(req);
            System.assertEquals(true, r.success, 'Agent Access 사용자도 Quote / QuoteLineItem 갱신이 가능해야 한다');
            System.assertEquals(4, r.updatedDiscount, 'QuoteLineItem 할인율 갱신이 USER_MODE에서 성공해야 한다');
            System.assertEquals('In Review', r.updatedStatus);
        }
        Test.stopTest();
    }
}

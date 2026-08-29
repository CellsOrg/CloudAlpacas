@isTest
private class SponsorshipProposalSaverTest {

    private static final String SEG_OK = '40-60 Male';

    @testSetup
    static void setup() {
        Id stdPb = Test.getStandardPricebookId();
        Id rt = [SELECT Id FROM RecordType
                 WHERE SobjectType = 'Product2' AND DeveloperName = 'Sponsorship_Package' LIMIT 1].Id;

        Product2 pkgA = new Product2(Name = 'SAVER 패키지 A', ProductCode = 'SAVER-A', IsActive = true, RecordTypeId = rt);
        Product2 pkgB = new Product2(Name = 'SAVER 패키지 B', ProductCode = 'SAVER-B', IsActive = true, RecordTypeId = rt);
        Product2 pkgInactive = new Product2(Name = 'SAVER 비활성', ProductCode = 'SAVER-OFF', IsActive = false, RecordTypeId = rt);
        Product2 nonPkg = new Product2(Name = 'SAVER 일반상품', ProductCode = 'SAVER-GEN', IsActive = true);
        Product2 pkgNoPbe = new Product2(Name = 'SAVER PBE없음', ProductCode = 'SAVER-NOPBE', IsActive = true, RecordTypeId = rt);
        insert new List<Product2>{ pkgA, pkgB, pkgInactive, nonPkg, pkgNoPbe };

        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = pkgA.Id, UnitPrice = 500000000, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = pkgB.Id, UnitPrice = 300000000, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = pkgInactive.Id, UnitPrice = 1, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = nonPkg.Id, UnitPrice = 1, IsActive = true)
        };

        Account acct = new Account(Name = 'Saver Corp');
        insert acct;

        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'SAVER NoQuote', AccountId = acct.Id, StageName = 'Proposal/Quote', CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'SAVER OneEmptyQuote', AccountId = acct.Id, StageName = 'Proposal/Quote', CloseDate = Date.today().addDays(30), Pricebook2Id = stdPb),
            new Opportunity(Name = 'SAVER MatchingLine', AccountId = acct.Id, StageName = 'Proposal/Quote', CloseDate = Date.today().addDays(30), Pricebook2Id = stdPb),
            new Opportunity(Name = 'SAVER DifferentLine', AccountId = acct.Id, StageName = 'Proposal/Quote', CloseDate = Date.today().addDays(30), Pricebook2Id = stdPb),
            new Opportunity(Name = 'SAVER Synced', AccountId = acct.Id, StageName = 'Negotiation', CloseDate = Date.today().addDays(30), Pricebook2Id = stdPb),
            new Opportunity(Name = 'SAVER MultiQuote', AccountId = acct.Id, StageName = 'Proposal/Quote', CloseDate = Date.today().addDays(30), Pricebook2Id = stdPb)
        };
        insert opps;

        Map<String, Id> oppId = new Map<String, Id>();
        for (Opportunity o : opps) oppId.put(o.Name, o.Id);
        Map<String, Id> pbeId = new Map<String, Id>();
        for (PricebookEntry e : [SELECT Id, Product2.ProductCode FROM PricebookEntry WHERE Product2.ProductCode LIKE 'SAVER-%']) {
            pbeId.put(e.Product2.ProductCode, e.Id);
        }

        // OneEmptyQuote — a Quote with no lines.
        Quote emptyQ = new Quote(Name = 'SAVER Empty Q', OpportunityId = oppId.get('SAVER OneEmptyQuote'), Pricebook2Id = stdPb, Status = 'Draft');
        insert emptyQ;

        // MatchingLine — a Quote that already has pkgA at a stale price.
        Quote matchQ = new Quote(Name = 'SAVER Match Q', OpportunityId = oppId.get('SAVER MatchingLine'), Pricebook2Id = stdPb, Status = 'Draft');
        insert matchQ;
        insert new QuoteLineItem(QuoteId = matchQ.Id, PricebookEntryId = pbeId.get('SAVER-A'), Quantity = 1, UnitPrice = 111111111, Discount = 5);

        // DifferentLine — a Quote that already has pkgB (we will ask to save pkgA).
        Quote diffQ = new Quote(Name = 'SAVER Diff Q', OpportunityId = oppId.get('SAVER DifferentLine'), Pricebook2Id = stdPb, Status = 'Draft');
        insert diffQ;
        insert new QuoteLineItem(QuoteId = diffQ.Id, PricebookEntryId = pbeId.get('SAVER-B'), Quantity = 1, UnitPrice = 300000000);

        // Synced — a Quote synced to the Opportunity.
        Quote syncQ = new Quote(Name = 'SAVER Sync Q', OpportunityId = oppId.get('SAVER Synced'), Pricebook2Id = stdPb, Status = 'Presented');
        insert syncQ;
        insert new QuoteLineItem(QuoteId = syncQ.Id, PricebookEntryId = pbeId.get('SAVER-B'), Quantity = 1, UnitPrice = 300000000);
        update new Opportunity(Id = oppId.get('SAVER Synced'), SyncedQuoteId = syncQ.Id);

        // MultiQuote — two Quotes, none synced.
        insert new List<Quote>{
            new Quote(Name = 'SAVER Multi Q1', OpportunityId = oppId.get('SAVER MultiQuote'), Pricebook2Id = stdPb, Status = 'Draft'),
            new Quote(Name = 'SAVER Multi Q2', OpportunityId = oppId.get('SAVER MultiQuote'), Pricebook2Id = stdPb, Status = 'Draft')
        };
    }

    private static Id oppId(String name) {
        return [SELECT Id FROM Opportunity WHERE Name = :name LIMIT 1].Id;
    }
    private static Id productId(String code) {
        return [SELECT Id FROM Product2 WHERE ProductCode = :code LIMIT 1].Id;
    }

    private static SponsorshipProposalSaver.Request req(String oppName, String productCode) {
        SponsorshipProposalSaver.Request r = new SponsorshipProposalSaver.Request();
        r.opportunityId = oppName == null ? null : oppId(oppName);
        r.productId = productCode == null ? null : productId(productCode);
        r.quoteName = 'Test Proposal Quote';
        return r;
    }
    private static SponsorshipProposalSaver.Result run(SponsorshipProposalSaver.Request r) {
        return SponsorshipProposalSaver.execute(new List<SponsorshipProposalSaver.Request>{ r })[0];
    }
    private static Integer quoteCount(Id oId) {
        return [SELECT COUNT() FROM Quote WHERE OpportunityId = :oId];
    }
    private static Integer qliCount(Id qId) {
        return [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :qId];
    }

    @isTest
    static void testNoQuoteCreatesNewQuoteAndLine() {
        Id oId = oppId('SAVER NoQuote');
        SponsorshipProposalSaver.Request r = req('SAVER NoQuote', 'SAVER-A');
        r.shortTermBenefit = 'AI가 작성한 단기 기대효과';

        Test.startTest();
        SponsorshipProposalSaver.Result res = run(r);
        Test.stopTest();

        System.assertEquals(true, res.success, res.message);
        System.assertEquals(true, res.quoteWasCreated);
        System.assertEquals(1, quoteCount(oId), '새 Quote 1개 생성');
        System.assertEquals(1, qliCount(res.quoteId), 'QLI 1개 생성');
        System.assertEquals(true, res.opportunityUpdated);
        Opportunity o = [SELECT Expected_Benefit_Short_Term__c FROM Opportunity WHERE Id = :oId];
        System.assertEquals('AI가 작성한 단기 기대효과', o.Expected_Benefit_Short_Term__c);
    }

    @isTest
    static void testExistingSingleEmptyQuoteIsUpdatedNotDuplicated() {
        Id oId = oppId('SAVER OneEmptyQuote');
        Integer before = quoteCount(oId);
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(req('SAVER OneEmptyQuote', 'SAVER-A'));
        Test.stopTest();

        System.assertEquals(true, res.success, res.message);
        System.assertEquals(true, res.quoteWasUpdated);
        System.assertEquals(false, res.quoteWasCreated);
        System.assertEquals(before, quoteCount(oId), '기존 Quote update — Quote 수 증가 없음');
        System.assertEquals(1, qliCount(res.quoteId), '비어있던 Quote에 라인 1개 추가');
    }

    @isTest
    static void testMatchingProductLineRepricedInPlace() {
        Id qId = [SELECT Id FROM Quote WHERE Name = 'SAVER Match Q'].Id;
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(req('SAVER MatchingLine', 'SAVER-A'));
        Test.stopTest();

        System.assertEquals(true, res.success, res.message);
        System.assertEquals(1, qliCount(qId), '동일 Product 라인 존재 → 중복 QLI 생성 안 됨');
        QuoteLineItem qli = [SELECT UnitPrice, Discount FROM QuoteLineItem WHERE QuoteId = :qId];
        System.assertEquals(500000000, qli.UnitPrice, '표준가로 리프라이스');
        System.assertEquals(5, qli.Discount, '기존 할인은 보존');
        System.assertEquals(true, res.lineItemChanged);
    }

    @isTest
    static void testDifferentProductLineIsRejected() {
        Id qId = [SELECT Id FROM Quote WHERE Name = 'SAVER Diff Q'].Id;
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(req('SAVER DifferentLine', 'SAVER-A'));
        Test.stopTest();

        System.assertEquals(false, res.success, '다른 패키지 라인이 있으면 자동 교체 거부');
        System.assert(res.message.contains('다른 패키지 라인'), res.message);
        System.assertEquals(1, qliCount(qId), '거부 시 기존 라인 그대로');
        QuoteLineItem qli = [SELECT Product2Id FROM QuoteLineItem WHERE QuoteId = :qId];
        System.assertEquals(productId('SAVER-B'), qli.Product2Id, '기존 라인 임의 변경 없음');
    }

    @isTest
    static void testSyncedQuoteUpdatesOpportunityOnlyNeverLineItems() {
        Id oId = oppId('SAVER Synced');
        Id syncQId = [SELECT SyncedQuoteId FROM Opportunity WHERE Id = :oId].SyncedQuoteId;
        Integer qliBefore = qliCount(syncQId);

        SponsorshipProposalSaver.Request r = req('SAVER Synced', 'SAVER-A');
        r.midTermBenefit = '동기화 Quote — 기대효과만 저장';

        Test.startTest();
        SponsorshipProposalSaver.Result res = run(r);
        Test.stopTest();

        System.assertEquals(true, res.success, res.message);
        System.assertEquals(syncQId, res.quoteId, 'Synced Quote가 결정적으로 target');
        System.assertEquals(qliBefore, qliCount(syncQId), 'Synced Quote의 라인은 절대 안 건드림');
        System.assertEquals(1, [SELECT COUNT() FROM Quote WHERE OpportunityId = :oId], '새 Quote 생성 안 함');
        System.assertEquals(syncQId, [SELECT SyncedQuoteId FROM Opportunity WHERE Id = :oId].SyncedQuoteId, 'SyncedQuoteId 불변');
        System.assert(res.lineItemNote != null && res.lineItemNote.contains('동기화'), res.lineItemNote);
        System.assertEquals('동기화 Quote — 기대효과만 저장',
            [SELECT Expected_Benefit_Mid_Term__c FROM Opportunity WHERE Id = :oId].Expected_Benefit_Mid_Term__c);
    }

    @isTest
    static void testSyncedQuoteWithNoDraftFieldsChangesNothing() {
        Id oId = oppId('SAVER Synced');
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(req('SAVER Synced', 'SAVER-A'));
        Test.stopTest();
        System.assertEquals(false, res.success, '동기화 Quote + 저장할 초안 없음 → 변경 없음');
    }

    @isTest
    static void testMultipleQuotesNoneSyncedIsAmbiguous() {
        Id oId = oppId('SAVER MultiQuote');
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(req('SAVER MultiQuote', 'SAVER-A'));
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals(true, res.ambiguous);
        System.assertEquals(2, quoteCount(oId), 'ambiguous — Quote 수 불변');
        for (Quote q : [SELECT Id FROM Quote WHERE OpportunityId = :oId]) {
            System.assertEquals(0, qliCount(q.Id), 'ambiguous — 어떤 Quote도 안 건드림');
        }
        System.assert(res.message.contains('Quote'), res.message);
    }

    @isTest
    static void testWrongProductTypeRejected() {
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(req('SAVER NoQuote', 'SAVER-GEN'));
        Test.stopTest();
        System.assertEquals(false, res.success);
        System.assert(res.message.contains('Sponsorship Package가 아니'), res.message);
        System.assertEquals(0, quoteCount(oppId('SAVER NoQuote')));
    }

    @isTest
    static void testInactiveProductRejected() {
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(req('SAVER NoQuote', 'SAVER-OFF'));
        Test.stopTest();
        System.assertEquals(false, res.success);
        System.assert(res.message.contains('비활성'), res.message);
    }

    @isTest
    static void testNoStandardPbeRejected() {
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(req('SAVER NoQuote', 'SAVER-NOPBE'));
        Test.stopTest();
        System.assertEquals(false, res.success);
        System.assert(res.message.contains('표준 가격'), res.message);
    }

    @isTest
    static void testBenefitTooLongRejected() {
        SponsorshipProposalSaver.Request r = req('SAVER NoQuote', 'SAVER-A');
        r.longTermBenefit = 'x'.repeat(1001);
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(r);
        Test.stopTest();
        System.assertEquals(false, res.success, '1000자 초과는 거부, silent truncate 금지');
        System.assert(res.message.contains('장기 기대효과'), res.message);
        System.assertEquals(0, quoteCount(oppId('SAVER NoQuote')), '검증 실패 시 아무것도 저장 안 됨');
    }

    @isTest
    static void testInvalidTargetSegmentRejected() {
        SponsorshipProposalSaver.Request r = req('SAVER NoQuote', 'SAVER-A');
        r.targetSegment = '아무세그먼트나';
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(r);
        Test.stopTest();
        System.assertEquals(false, res.success);
        System.assert(res.message.contains('Target Segment'), res.message);
    }

    @isTest
    static void testValidTargetSegmentAndBenefitsPersist() {
        Id oId = oppId('SAVER NoQuote');
        SponsorshipProposalSaver.Request r = req('SAVER NoQuote', 'SAVER-A');
        r.shortTermBenefit = '단기';
        r.midTermBenefit = '중기';
        r.longTermBenefit = '장기';
        r.targetSegment = SEG_OK;
        Test.startTest();
        SponsorshipProposalSaver.Result res = run(r);
        Test.stopTest();
        System.assertEquals(true, res.success, res.message);
        Opportunity o = [SELECT Expected_Benefit_Short_Term__c, Expected_Benefit_Mid_Term__c,
            Expected_Benefit_Long_Term__c, Target_Segment__c FROM Opportunity WHERE Id = :oId];
        System.assertEquals('단기', o.Expected_Benefit_Short_Term__c);
        System.assertEquals('중기', o.Expected_Benefit_Mid_Term__c);
        System.assertEquals('장기', o.Expected_Benefit_Long_Term__c);
        System.assertEquals(SEG_OK, o.Target_Segment__c);
    }

    @isTest
    static void testMissingIdsRejected() {
        Test.startTest();
        SponsorshipProposalSaver.Result noOpp = run(req(null, 'SAVER-A'));
        SponsorshipProposalSaver.Result noProd = run(req('SAVER NoQuote', null));
        Test.stopTest();
        System.assertEquals(false, noOpp.success);
        System.assertEquals(false, noProd.success);
        System.assert(noProd.message.contains('패키지'), noProd.message);
    }

    @isTest
    static void testFailedTransactionRollsBackEverything() {
        // Standard User + a permission set that grants Quote create/edit but NOT the
        // Opportunity Expected_Benefit FLS. CREATE inserts the Quote + line, then the
        // Opportunity draft update fails on FLS → the whole transaction must roll back.
        User u;
        Id oId = oppId('SAVER NoQuote');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = new PermissionSet(Name = 'PS_SaverRollbackTest', Label = 'PS Saver Rollback Test');
            insert ps;
            // Quote CRUD + Product/Pricebook read + Opportunity READ ONLY (no edit, no
            // benefit FLS). CREATE inserts the Quote + line, then the Opportunity draft
            // update fails on missing Opportunity edit / FLS.
            insert new List<ObjectPermissions>{
                new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Quote',
                    PermissionsRead = true, PermissionsCreate = true, PermissionsEdit = true),
                new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Product2', PermissionsRead = true),
                new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Pricebook2', PermissionsRead = true),
                new ObjectPermissions(ParentId = ps.Id, SobjectType = 'Opportunity', PermissionsRead = true)
            };
            Profile minAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
            u = new User(FirstName = 'Saver', LastName = 'Rollback', Alias = 'svrb',
                Email = 'saver.rb@example.com.invalid',
                Username = 'saver.rb.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = minAccess.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
            insert u;
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
            // Share the Opportunity to the restricted user so it is queryable/visible —
            // the block we are testing is the Opportunity FIELD update, not record access.
            // (No-op / throws harmlessly if the org-wide default already makes it visible.)
            try {
                insert new OpportunityShare(OpportunityId = oId, UserOrGroupId = u.Id,
                    OpportunityAccessLevel = 'Read', RowCause = Schema.OpportunityShare.RowCause.Manual);
            } catch (Exception ignored) { /* OWD already grants read */ }
        }

        // Build the request as the system user (the restricted user cannot query test data).
        SponsorshipProposalSaver.Request r = req('SAVER NoQuote', 'SAVER-A');
        r.shortTermBenefit = '롤백되어야 하는 초안';

        Test.startTest();
        System.runAs(u) {
            SponsorshipProposalSaver.Result res = run(r);
            System.assertEquals(false, res.success, 'Opportunity 갱신 권한 없음 → 저장 실패해야 한다');
            System.assert(res.message.contains('오류') || res.message.contains('권한'), res.message);
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Quote WHERE OpportunityId = :oId],
            '트랜잭션 실패 → 생성됐던 Quote까지 전부 rollback');
        System.assertEquals(null,
            [SELECT Expected_Benefit_Short_Term__c FROM Opportunity WHERE Id = :oId].Expected_Benefit_Short_Term__c,
            'Opportunity 초안도 저장되지 않아야 한다');
    }

    @isTest
    static void testBulkTwoRequests() {
        List<SponsorshipProposalSaver.Request> reqs = new List<SponsorshipProposalSaver.Request>{
            req('SAVER NoQuote', 'SAVER-A'),
            req('SAVER OneEmptyQuote', 'SAVER-B')
        };
        Test.startTest();
        List<SponsorshipProposalSaver.Result> rs = SponsorshipProposalSaver.execute(reqs);
        Test.stopTest();
        System.assertEquals(2, rs.size());
        System.assertEquals(true, rs[0].success, rs[0].message);
        System.assertEquals(true, rs[1].success, rs[1].message);
    }
}

@isTest
private class SponsorshipPackageResolverTest {

    @testSetup
    static void setup() {
        Id stdPb = Test.getStandardPricebookId();
        Id rt = [SELECT Id FROM RecordType
                 WHERE SobjectType = 'Product2' AND DeveloperName = 'Sponsorship_Package' LIMIT 1].Id;

        Product2 sleeve = new Product2(Name = 'RESOLVE 유니폼 소매 패치 광고', ProductCode = 'RESOLVE-SLEEVE',
            IsActive = true, RecordTypeId = rt);
        Product2 ledA = new Product2(Name = 'RESOLVE LED 전광판 A', ProductCode = 'RESOLVE-LED-A',
            IsActive = true, RecordTypeId = rt);
        Product2 ledB = new Product2(Name = 'RESOLVE LED 전광판 B', ProductCode = 'RESOLVE-LED-B',
            IsActive = true, RecordTypeId = rt);
        Product2 inactive = new Product2(Name = 'RESOLVE 비활성', ProductCode = 'RESOLVE-OFF',
            IsActive = false, RecordTypeId = rt);
        Product2 nonPkg = new Product2(Name = 'RESOLVE 일반상품 유니폼', ProductCode = 'RESOLVE-GEN',
            IsActive = true);
        Product2 noPbe = new Product2(Name = 'RESOLVE PBE 없음', ProductCode = 'RESOLVE-NOPBE',
            IsActive = true, RecordTypeId = rt);
        insert new List<Product2>{ sleeve, ledA, ledB, inactive, nonPkg, noPbe };

        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = sleeve.Id, UnitPrice = 800000000, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = ledA.Id, UnitPrice = 500000000, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = ledB.Id, UnitPrice = 300000000, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = inactive.Id, UnitPrice = 100, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = nonPkg.Id, UnitPrice = 100, IsActive = true)
        };

        Account acct = new Account(Name = 'Resolve Corp');
        insert acct;
        insert new Opportunity(Name = 'Resolve Opp', AccountId = acct.Id,
            StageName = 'Proposal/Quote', CloseDate = Date.today().addDays(30));
    }

    private static Id oppId() {
        return [SELECT Id FROM Opportunity WHERE Name = 'Resolve Opp'].Id;
    }

    private static FindSponsorshipPackage.Result run(String term, Id oppId) {
        FindSponsorshipPackage.Request req = new FindSponsorshipPackage.Request();
        req.searchTerm = term;
        req.opportunityId = oppId;
        return FindSponsorshipPackage.execute(
            new List<FindSponsorshipPackage.Request>{ req })[0];
    }

    @isTest
    static void testExactNameResolvesUniquely() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('RESOLVE 유니폼 소매 패치 광고', oppId());
        Test.stopTest();

        System.assertEquals(true, r.found);
        System.assertEquals(true, r.isUnique);
        System.assertEquals(1, r.matchCount);
        System.assertNotEquals('', r.resolvedId, 'isUnique면 resolvedId가 채워져야 한다');
        System.assertEquals('RESOLVE 유니폼 소매 패치 광고', r.singleMatchName);
        System.assertEquals(800000000, r.unitPrice);
    }

    @isTest
    static void testExactProductCodeResolvesUniquely() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('resolve-sleeve', oppId()); // case-insensitive
        Test.stopTest();
        System.assertEquals(true, r.isUnique);
        System.assertEquals('RESOLVE-SLEEVE', r.singleMatchCode);
    }

    @isTest
    static void testAmbiguousReturnsCandidatesAndResolvesNothing() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('RESOLVE LED 전광판', oppId());
        Test.stopTest();

        System.assertEquals(true, r.found);
        System.assertEquals(false, r.isUnique);
        System.assertEquals(2, r.matchCount);
        System.assertEquals('', r.resolvedId, '모호하면 resolvedId는 빈 문자열이어야 downstream gate가 막힌다');
        System.assert(r.matchesSummary.contains('RESOLVE LED 전광판 A'));
        System.assert(r.matchesSummary.contains('RESOLVE LED 전광판 B'));
    }

    @isTest
    static void testNoMatch() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('존재하지 않는 패키지 zzz', oppId());
        Test.stopTest();
        System.assertEquals(false, r.found);
        System.assertEquals('', r.resolvedId);
    }

    @isTest
    static void testInactivePackageNotResolved() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('RESOLVE 비활성', oppId());
        Test.stopTest();
        System.assertEquals(false, r.found, '비활성 패키지는 카탈로그에 없음');
    }

    @isTest
    static void testWrongRecordTypeNotResolved() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('RESOLVE-GEN', oppId());
        Test.stopTest();
        System.assertEquals(false, r.found, 'Sponsorship_Package 레코드타입이 아니면 제외');
    }

    @isTest
    static void testPackageWithNoStandardPbeNotResolved() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('RESOLVE-NOPBE', oppId());
        Test.stopTest();
        System.assertEquals(false, r.found, '표준 가격이 없는 패키지는 판매 불가로 제외');
    }

    @isTest
    static void testBlankTerm() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('   ', oppId());
        Test.stopTest();
        System.assertEquals(false, r.found);
        System.assertEquals('', r.resolvedId);
    }

    @isTest
    static void testMissingOpportunity() {
        Test.startTest();
        FindSponsorshipPackage.Result r = run('RESOLVE-SLEEVE', null);
        Test.stopTest();
        System.assertEquals(false, r.isUnique, 'Opportunity 없이는 통화 기준을 못 잡으므로 resolve 불가');
        System.assertEquals('', r.resolvedId);
    }
}

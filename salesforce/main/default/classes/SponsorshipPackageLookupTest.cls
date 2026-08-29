@isTest
private class SponsorshipPackageLookupTest {

    private static Id sponsorshipRtId() {
        return [SELECT Id FROM RecordType
                WHERE SobjectType = 'Product2' AND DeveloperName = 'Sponsorship_Package' LIMIT 1].Id;
    }

    @testSetup
    static void setup() {
        Id stdPb = Test.getStandardPricebookId();
        Id rt = [SELECT Id FROM RecordType
                 WHERE SobjectType = 'Product2' AND DeveloperName = 'Sponsorship_Package' LIMIT 1].Id;

        Product2 pkgActive = new Product2(Name = 'LOOKUP 전광판 광고', ProductCode = 'LOOKUP-LED',
            IsActive = true, RecordTypeId = rt);
        Product2 pkgInactive = new Product2(Name = 'LOOKUP 비활성 패키지', ProductCode = 'LOOKUP-OFF',
            IsActive = false, RecordTypeId = rt);
        Product2 nonPackage = new Product2(Name = 'LOOKUP 일반 상품', ProductCode = 'LOOKUP-GEN',
            IsActive = true);
        insert new List<Product2>{ pkgActive, pkgInactive, nonPackage };

        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = pkgActive.Id,
                UnitPrice = 500000000, IsActive = true),
            new PricebookEntry(Pricebook2Id = stdPb, Product2Id = nonPackage.Id,
                UnitPrice = 1000, IsActive = true)
        };

        Account acct = new Account(Name = 'Lookup Corp');
        insert acct;
        insert new Opportunity(Name = 'Lookup Opp', AccountId = acct.Id,
            StageName = 'Proposal/Quote', CloseDate = Date.today().addDays(30));
    }

    private static SponsorshipPackageLookup.Result run(String filter, Id oppId) {
        SponsorshipPackageLookup.Request req = new SponsorshipPackageLookup.Request();
        req.nameFilter = filter;
        req.opportunityId = oppId;
        return SponsorshipPackageLookup.execute(
            new List<SponsorshipPackageLookup.Request>{ req })[0];
    }

    @isTest
    static void testReturnsActiveSponsorshipPackagesOnly() {
        Test.startTest();
        SponsorshipPackageLookup.Result r = run(null, null);
        Test.stopTest();

        System.assertEquals(true, r.found);
        System.assert(r.packageDigest.contains('LOOKUP 전광판 광고'), '활성 Sponsorship Package는 포함');
        System.assert(!r.packageDigest.contains('LOOKUP 비활성 패키지'), '비활성 패키지는 제외');
        System.assert(!r.packageDigest.contains('LOOKUP 일반 상품'), 'Sponsorship Package가 아닌 상품은 제외');
    }

    @isTest
    static void testNameFilterNarrowsList() {
        Test.startTest();
        SponsorshipPackageLookup.Result hit = run('LOOKUP-LED', null);
        SponsorshipPackageLookup.Result miss = run('존재하지않는필터zzz', null);
        Test.stopTest();

        System.assertEquals(true, hit.found);
        System.assert(hit.packageDigest.contains('LOOKUP 전광판 광고'));
        System.assertEquals(false, miss.found, '일치하는 패키지가 없으면 found=false');
        System.assertEquals(0, miss.packageCount);
    }

    @isTest
    static void testCurrencyScopedByOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Lookup Opp'];
        Test.startTest();
        SponsorshipPackageLookup.Result r = run(null, opp.Id);
        Test.stopTest();
        // Opportunity + PBE share the org default currency, so the package still shows.
        System.assertEquals(true, r.found);
        System.assert(r.packageCount >= 1);
    }

    @isTest
    static void testBulkContract() {
        SponsorshipPackageLookup.Request a = new SponsorshipPackageLookup.Request();
        SponsorshipPackageLookup.Request b = new SponsorshipPackageLookup.Request();
        b.nameFilter = 'LOOKUP-LED';
        Test.startTest();
        List<SponsorshipPackageLookup.Result> rs = SponsorshipPackageLookup.execute(
            new List<SponsorshipPackageLookup.Request>{ a, b });
        Test.stopTest();
        System.assertEquals(2, rs.size());
        System.assert(rs[0].packageCount >= rs[1].packageCount, '필터 없는 쪽이 더 많거나 같아야 한다');
    }
}

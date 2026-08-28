@isTest
private class NegotiationOpportunityLookupTest {

    @testSetup
    static void setupData() {
        Account acme = new Account(Name = 'Acme Beverage Co');
        Account other = new Account(Name = 'Northwind Trading');
        insert new List<Account>{ acme, other };

        // Two Opportunities that share the "시즌 파트너십" substring -> multi-match case.
        Opportunity oppA = new Opportunity(
            Name = 'Acme - 2026 시즌 파트너십 제안',
            AccountId = acme.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30)
        );
        Opportunity oppB = new Opportunity(
            Name = 'Northwind - 2026 시즌 파트너십 업셀',
            AccountId = other.Id,
            StageName = 'Proposal/Quote',
            CloseDate = Date.today().addDays(45)
        );
        // A uniquely named Opportunity -> single-match case.
        Opportunity oppUnique = new Opportunity(
            Name = 'Zephyr Solo Deal 9981',
            AccountId = acme.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(20)
        );
        insert new List<Opportunity>{ oppA, oppB, oppUnique };
    }

    private static NegotiationOpportunityLookup.Result run(String term) {
        NegotiationOpportunityLookup.Request req = new NegotiationOpportunityLookup.Request();
        req.searchTerm = term;
        return NegotiationOpportunityLookup.execute(
            new List<NegotiationOpportunityLookup.Request>{ req }
        )[0];
    }

    @isTest
    static void testBlankSearchTermReturnsNotFound() {
        Test.startTest();
        NegotiationOpportunityLookup.Result r = run('   ');
        Test.stopTest();

        System.assertEquals(false, r.found, 'blank 검색어는 found=false여야 한다');
        System.assertEquals(false, r.isUnique, 'blank 검색어는 isUnique=false여야 한다');
        System.assertEquals(0, r.matchCount, 'blank 검색어는 matchCount=0이어야 한다');
    }

    @isTest
    static void testUniqueNameMatchSetsSingleMatch() {
        Test.startTest();
        NegotiationOpportunityLookup.Result r = run('Zephyr Solo Deal 9981');
        Test.stopTest();

        System.assertEquals(true, r.found, '유일한 이름은 found=true여야 한다');
        System.assertEquals(true, r.isUnique, '정확히 1건이면 isUnique=true여야 한다');
        System.assertEquals(1, r.matchCount, 'matchCount=1이어야 한다');
        System.assertNotEquals(null, r.singleMatchId, 'isUnique일 때 singleMatchId가 설정되어야 한다');
        System.assertEquals('Zephyr Solo Deal 9981', r.singleMatchName, 'singleMatchName이 일치해야 한다');
    }

    @isTest
    static void testMultipleMatchesAreNotUnique() {
        Test.startTest();
        NegotiationOpportunityLookup.Result r = run('시즌 파트너십');
        Test.stopTest();

        System.assertEquals(true, r.found, '2건 매칭도 found=true여야 한다');
        System.assertEquals(false, r.isUnique, '2건 이상이면 isUnique=false여야 한다');
        System.assertEquals(2, r.matchCount, '공유 substring은 2건 매칭이어야 한다');
        System.assertEquals(null, r.singleMatchId, '비유일 매칭에서는 singleMatchId가 비어 있어야 한다');
        System.assert(r.matchesSummary.contains('Acme'), 'matchesSummary에 첫 후보가 포함되어야 한다');
        System.assert(r.matchesSummary.contains('Northwind'), 'matchesSummary에 둘째 후보가 포함되어야 한다');
    }

    @isTest
    static void testNoMatchReturnsNotFound() {
        Test.startTest();
        NegotiationOpportunityLookup.Result r = run('존재하지않는딜명ZZZ');
        Test.stopTest();

        System.assertEquals(false, r.found, '매칭이 없으면 found=false여야 한다');
        System.assertEquals(0, r.matchCount, 'matchCount=0이어야 한다');
    }

    @isTest
    static void testAccountNameMatch() {
        Test.startTest();
        NegotiationOpportunityLookup.Result r = run('Northwind Trading');
        Test.stopTest();

        System.assertEquals(true, r.found, 'Account 이름으로도 매칭되어야 한다');
        System.assertEquals(1, r.matchCount, 'Northwind Account에 연결된 Opportunity는 1건이어야 한다');
    }

    @isTest
    static void testRecordIdIsResolvedDirectly() {
        Opportunity opp = [SELECT Id, Name FROM Opportunity WHERE Name = 'Zephyr Solo Deal 9981' LIMIT 1];

        Test.startTest();
        NegotiationOpportunityLookup.Result r = run(String.valueOf(opp.Id));
        Test.stopTest();

        System.assertEquals(true, r.found, 'Record Id 입력은 직접 조회되어야 한다');
        System.assertEquals(true, r.isUnique, 'Record Id 조회는 항상 유일해야 한다');
        System.assertEquals(opp.Id, r.singleMatchId, '조회된 Id가 입력 Id와 같아야 한다');
    }

    @isTest
    static void testNonOpportunityIdFallsBackToSearch() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Beverage Co' LIMIT 1];

        Test.startTest();
        // A valid 18-char Salesforce Id, but for Account — must NOT be treated as an Opportunity Id.
        NegotiationOpportunityLookup.Result r = run(String.valueOf(acc.Id));
        Test.stopTest();

        System.assertEquals(false, r.found, 'Opportunity가 아닌 Id는 검색어로 처리되어 매칭 0건이어야 한다');
    }

    @isTest
    static void testMalformed18CharStringIsNotAnId() {
        Test.startTest();
        NegotiationOpportunityLookup.Result r = run('NOTAREALSFIDVALUE1');
        Test.stopTest();

        System.assertEquals(false, r.found, '잘못된 18자 문자열은 Id로 파싱되지 않고 검색되어 매칭 0건이어야 한다');
        System.assertEquals(0, r.matchCount, 'matchCount=0이어야 한다');
    }

    @isTest
    static void testApostropheInSearchTermStillMatches() {
        // Regression: searchTerm is bound as :likeTerm (injection-safe), so it must NOT
        // be escapeSingleQuotes'd — escaping injects a literal backslash and breaks LIKE
        // for names/accounts containing an apostrophe (e.g. "d'Alba").
        Account brand = new Account(Name = 'O\'Douls Brands');
        insert brand;
        Opportunity opp = new Opportunity(
            Name = 'O\'Douls - 2026 골드 스폰서십',
            AccountId = brand.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(15)
        );
        insert opp;

        Test.startTest();
        NegotiationOpportunityLookup.Result byName = run('O\'Douls - 2026 골드 스폰서십');
        NegotiationOpportunityLookup.Result byAccount = run('O\'Douls Brands');
        Test.stopTest();

        System.assertEquals(true, byName.found, '아포스트로피가 든 Opportunity 이름도 검색되어야 한다');
        System.assertEquals(true, byName.isUnique, '정확히 1건 매칭되어야 한다');
        System.assertEquals(opp.Id, byName.singleMatchId, '매칭된 Id가 일치해야 한다');
        System.assertEquals(true, byAccount.found, '아포스트로피가 든 Account 이름으로도 검색되어야 한다');
    }
}

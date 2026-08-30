@isTest
private class FindSimilarClosedDealsTest {

    private static Opportunity mk(String name, String stage, Boolean won, Decimal amt, String seg, String tier, Id acct) {
        return new Opportunity(
            Name = name, StageName = stage, CloseDate = Date.today().addDays(won ? -10 : 20),
            Amount = amt, Target_Segment__c = seg, Partner_Tier__c = tier, AccountId = acct
        );
    }

    @testSetup
    static void setup() {
        Account beautyA = new Account(Name = 'Beauty A', Industry = 'Cosmetics / Beauty');
        Account beautyB = new Account(Name = 'Beauty B', Industry = 'Cosmetics / Beauty');
        Account fin = new Account(Name = 'Fin Co', Industry = 'Financial Services');
        insert new List<Account>{ beautyA, beautyB, fin };

        insert new List<Opportunity>{
            mk('현재 뷰티 딜', 'Negotiation', false, 300000000, '10-30 Female', 'Gold', beautyA.Id),
            mk('과거 뷰티 계약 유사', 'Closed Won', true, 320000000, '10-30 Female', 'Gold', beautyB.Id),
            mk('과거 뷰티 계약 소형', 'Closed Won', true, 5000000, null, null, beautyB.Id),
            mk('과거 금융 계약', 'Closed Won', true, 300000000, null, null, fin.Id),
            mk('과거 뷰티 진행중', 'Proposal/Quote', false, 300000000, '10-30 Female', 'Gold', beautyB.Id)
        };
    }

    private static Id refOppId() {
        return [SELECT Id FROM Opportunity WHERE Name = '현재 뷰티 딜' LIMIT 1].Id;
    }

    @isTest
    static void ranksSimilarClosedWonAndExcludesCurrentAndOpen() {
        FindSimilarClosedDeals.Request req = new FindSimilarClosedDeals.Request();
        req.opportunityId = refOppId();

        Test.startTest();
        FindSimilarClosedDeals.Result r = FindSimilarClosedDeals.execute(
            new List<FindSimilarClosedDeals.Request>{ req }
        )[0];
        Integer dmlAfterAction = Limits.getDmlStatements(); // startTest reset the counter — this is the action's own DML
        Test.stopTest();

        System.assert(r.found, 'should find similar closed won deals');
        // '과거 뷰티 계약 유사' (industry+segment+tier+amount) must rank first
        System.assert(r.digest.indexOf('과거 뷰티 계약 유사') < r.digest.indexOf('과거 금융 계약'),
            'the full-match beauty deal ranks above the finance deal: ' + r.digest);
        System.assert(!r.digest.contains('현재 뷰티 딜'), 'current Opportunity is excluded');
        System.assert(!r.digest.contains('과거 뷰티 진행중'), 'open Opportunities are excluded');
        System.assert(r.digest.contains('AI 예측이 아닙니다'), 'framed as stored-data similarity, not prediction');
        System.assertEquals(0, dmlAfterAction, 'read-only — the action itself does no DML');
    }

    @isTest
    static void topNIsHonouredAndCapped() {
        FindSimilarClosedDeals.Request req = new FindSimilarClosedDeals.Request();
        req.opportunityId = refOppId();
        req.topN = 1;
        FindSimilarClosedDeals.Result r = FindSimilarClosedDeals.execute(
            new List<FindSimilarClosedDeals.Request>{ req }
        )[0];
        System.assertEquals(1, r.matchCount, 'topN=1 returns one deal');
    }

    @isTest
    static void categoryKeywordQueryWithoutOpportunity() {
        FindSimilarClosedDeals.Request req = new FindSimilarClosedDeals.Request();
        req.categoryKeyword = 'Cosmetics';
        FindSimilarClosedDeals.Result r = FindSimilarClosedDeals.execute(
            new List<FindSimilarClosedDeals.Request>{ req }
        )[0];
        System.assert(r.found, 'keyword matches Closed Won beauty accounts');
        System.assert(r.digest.contains('과거 뷰티 계약 유사'), r.digest);
        System.assert(!r.digest.contains('과거 금융 계약'), 'finance deal not matched by Cosmetics keyword');
    }

    @isTest
    static void noInputReturnsGuidance() {
        FindSimilarClosedDeals.Result r = FindSimilarClosedDeals.execute(
            new List<FindSimilarClosedDeals.Request>{ new FindSimilarClosedDeals.Request() }
        )[0];
        System.assert(!r.found);
        System.assert(r.digest.contains('키워드가 필요'), r.digest);
    }

    @isTest
    static void badOpportunityIdIsIgnoredGracefully() {
        FindSimilarClosedDeals.Request req = new FindSimilarClosedDeals.Request();
        req.opportunityId = 'not-an-id';
        req.categoryKeyword = 'Financial';
        FindSimilarClosedDeals.Result r = FindSimilarClosedDeals.execute(
            new List<FindSimilarClosedDeals.Request>{ req }
        )[0];
        System.assert(r.found, 'falls back to keyword search when the id is invalid');
    }
}

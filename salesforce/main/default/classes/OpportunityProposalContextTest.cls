@isTest
private class OpportunityProposalContextTest {

    @testSetup
    static void setup() {
        Account acct = new Account(Name = 'Proposal Ctx Corp');
        insert acct;

        Opportunity oppNoLead = new Opportunity(
            Name = 'Proposal Ctx - No Lead',
            AccountId = acct.Id,
            StageName = 'Proposal/Quote',
            CloseDate = Date.today().addDays(30),
            Target_Segment__c = '40-60 Male',
            Partner_Tier__c = 'Gold',
            Expected_Benefit_Short_Term__c = '기존 단기 초안'
        );
        Opportunity oppOneLead = new Opportunity(
            Name = 'Proposal Ctx - One Lead',
            AccountId = acct.Id,
            StageName = 'Proposal/Quote',
            CloseDate = Date.today().addDays(30)
        );
        Opportunity oppMultiLead = new Opportunity(
            Name = 'Proposal Ctx - Multi Lead',
            AccountId = acct.Id,
            StageName = 'Proposal/Quote',
            CloseDate = Date.today().addDays(30)
        );
        insert new List<Opportunity>{ oppNoLead, oppOneLead, oppMultiLead };

        String convertedStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;

        // One converted Lead into oppOneLead.
        Lead l1 = new Lead(LastName = 'One', Company = 'Lead Co 1',
            Target_Segment__c = '10-30 Female', Segment_Match__c = 71, Lead_Score__c = 60,
            Recommendation_Reason__c = 'single lead reason');
        insert l1;
        convertInto(l1.Id, oppOneLead.Id, acct.Id, convertedStatus);

        // Two converted Leads into oppMultiLead — the resolver must pick deterministically.
        Lead older = new Lead(LastName = 'Older', Company = 'Lead Co Old',
            Target_Segment__c = '10-30 Male', Segment_Match__c = 40, Lead_Score__c = 30,
            Recommendation_Reason__c = 'OLDER lead reason');
        Lead newer = new Lead(LastName = 'Newer', Company = 'Lead Co New',
            Target_Segment__c = '40-60 Female', Segment_Match__c = 90, Lead_Score__c = 88,
            Recommendation_Reason__c = 'NEWER lead reason');
        insert new List<Lead>{ older, newer };
        convertInto(older.Id, oppMultiLead.Id, acct.Id, convertedStatus);
        convertInto(newer.Id, oppMultiLead.Id, acct.Id, convertedStatus);
    }

    private static void convertInto(Id leadId, Id oppId, Id acctId, String status) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setConvertedStatus(status);
        lc.setAccountId(acctId);
        lc.setOpportunityId(oppId);
        Database.convertLead(lc);
    }

    private static OpportunityProposalContext.Result run(Id oppId) {
        OpportunityProposalContext.Request req = new OpportunityProposalContext.Request();
        req.opportunityId = oppId;
        return OpportunityProposalContext.execute(
            new List<OpportunityProposalContext.Request>{ req })[0];
    }

    @isTest
    static void testValidOpportunityNoLead() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Proposal Ctx - No Lead'];
        Test.startTest();
        OpportunityProposalContext.Result r = run(opp.Id);
        Test.stopTest();

        System.assertEquals('Proposal Ctx - No Lead', r.opportunityName);
        System.assertEquals('40-60 Male', r.targetSegment);
        System.assertEquals('Gold', r.partnerTier);
        System.assertEquals('기존 단기 초안', r.existingShortTermBenefit);
        System.assertEquals(false, r.hasConvertedLead, '전환 Lead 없음');
        System.assertEquals(null, r.leadRecommendationReason);
    }

    @isTest
    static void testInvalidOpportunity() {
        Test.startTest();
        OpportunityProposalContext.Result r = run(null);
        Test.stopTest();
        System.assertEquals(null, r.opportunityName, '없는 Opportunity면 결과가 비어야 한다');
        System.assertEquals(false, r.hasConvertedLead);
    }

    @isTest
    static void testSingleConvertedLead() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Proposal Ctx - One Lead'];
        Test.startTest();
        OpportunityProposalContext.Result r = run(opp.Id);
        Test.stopTest();

        System.assertEquals(true, r.hasConvertedLead);
        System.assertEquals('single lead reason', r.leadRecommendationReason);
        System.assertEquals(71, r.leadSegmentMatch);
        System.assertEquals(60, r.leadScore);
        System.assertEquals('10-30 Female', r.leadTargetSegment);
    }

    @isTest
    static void testMultipleConvertedLeadsAreDeterministic() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Proposal Ctx - Multi Lead'];

        Test.startTest();
        OpportunityProposalContext.Result r1 = run(opp.Id);
        OpportunityProposalContext.Result r2 = run(opp.Id);
        Test.stopTest();

        System.assertEquals(true, r1.hasConvertedLead);
        // Both calls must pick the same Lead, and it must be one of the two real ones.
        System.assertEquals(r1.leadRecommendationReason, r2.leadRecommendationReason,
            '같은 Opportunity는 항상 같은 Lead를 골라야 한다');
        System.assert(
            r1.leadRecommendationReason == 'NEWER lead reason' || r1.leadRecommendationReason == 'OLDER lead reason',
            '실제 전환된 Lead 중 하나여야 한다');
    }

    @isTest
    static void testBulk() {
        List<Opportunity> opps = [SELECT Id FROM Opportunity ORDER BY Name];
        List<OpportunityProposalContext.Request> reqs = new List<OpportunityProposalContext.Request>();
        for (Opportunity o : opps) {
            OpportunityProposalContext.Request req = new OpportunityProposalContext.Request();
            req.opportunityId = o.Id;
            reqs.add(req);
        }
        Test.startTest();
        List<OpportunityProposalContext.Result> rs = OpportunityProposalContext.execute(reqs);
        Test.stopTest();
        System.assertEquals(opps.size(), rs.size(), '요청 수만큼 결과가 나와야 한다');
    }
}

@IsTest
private class StageGuidanceControllerTest {
    @IsTest
    static void returnsStoredFactsWithoutMutatingBusinessData() {
        Account account = new Account(Name = 'TEST - OA Stage Guidance Account');
        insert account;
        Opportunity opportunity = new Opportunity(
            Name = 'TEST - OA Stage Guidance - Proposal',
            AccountId = account.Id,
            StageName = 'Proposal/Quote',
            CloseDate = Date.today().addDays(30),
            Amount = 300000000,
            Partner_Tier__c = 'Gold'
        );
        insert opportunity;

        Test.startTest();
        StageGuidanceController.GuidanceContext result = StageGuidanceController.getContext(opportunity.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Proposal/Quote', result.stageName);
        System.assertEquals(300000000, result.amount);
        System.assertEquals('Gold', result.partnerTier);
        System.assertEquals(0, result.quoteCount);

        Opportunity unchanged = [SELECT StageName, Amount FROM Opportunity WHERE Id = :opportunity.Id];
        System.assertEquals('Proposal/Quote', unchanged.StageName);
        System.assertEquals(300000000, unchanged.Amount);
    }

    @IsTest
    static void returnsNullForMissingOrNullOpportunity() {
        System.assertEquals(null, StageGuidanceController.getContext(null));
        System.assertEquals(null, StageGuidanceController.getContext('006000000000000AAA'));
    }

    @IsTest
    static void returnsReadOnlyRecommendationFromStructuredContext() {
        Account account = new Account(Name = 'TEST - Stage Guidance Recommendation Account');
        insert account;
        Opportunity opportunity = new Opportunity(
            Name = 'TEST - Stage Guidance Recommendation',
            AccountId = account.Id,
            StageName = 'Negotiation',
            CloseDate = Date.today().addDays(14),
            Amount = 200000000
        );
        insert opportunity;

        StageGuidanceController.recommendationForTest = '**현재 상황**\n테스트 recommendation';
        Test.startTest();
        StageGuidanceController.RecommendationResponse result =
            StageGuidanceController.getRecommendation(opportunity.Id);
        Test.stopTest();

        System.assertEquals('**현재 상황**\n테스트 recommendation', result.recommendation);
        System.assertEquals(null, result.errorMessage);
        Opportunity unchanged = [SELECT Amount, StageName FROM Opportunity WHERE Id = :opportunity.Id];
        System.assertEquals(200000000, unchanged.Amount);
        System.assertEquals('Negotiation', unchanged.StageName);
    }
}

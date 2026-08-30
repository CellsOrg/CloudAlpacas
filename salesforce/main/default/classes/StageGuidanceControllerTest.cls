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

    @IsTest
    static void returnsLatestProposalQuoteAndLineItemsAsReadOnlyContext() {
        Account account = new Account(Name = 'TEST - Stage Guidance Quote Context');
        insert account;
        Opportunity opportunity = new Opportunity(
            Name = 'TEST - Stage Guidance Quote Context', AccountId = account.Id,
            StageName = 'Proposal/Quote', CloseDate = Date.today().addDays(30),
            Key_Requirements__c = '전광판 노출 필수. 분기별 리포트 제공.'
        );
        insert opportunity;
        Product2 product = new Product2(
            Name = 'TEST - LED + Brand Day', ProductCode = 'TEST-LED-BD', IsActive = true
        );
        insert product;
        Id standardPricebookId = Test.getStandardPricebookId();
        insert new PricebookEntry(
            Pricebook2Id = standardPricebookId, Product2Id = product.Id,
            UnitPrice = 300000000, IsActive = true
        );
        Quote quote = new Quote(
            Name = 'TEST - Presented Quote', OpportunityId = opportunity.Id,
            Pricebook2Id = standardPricebookId, Status = 'Presented'
        );
        insert quote;
        PricebookEntry entry = [
            SELECT Id FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :product.Id
            LIMIT 1
        ];
        insert new QuoteLineItem(
            QuoteId = quote.Id, PricebookEntryId = entry.Id, Quantity = 1,
            UnitPrice = 300000000, Discount = 0
        );
        Task sourceTask = new Task(
            WhatId = opportunity.Id, Subject = 'TEST - Proposal Evidence',
            Status = 'Completed', ActivityDate = Date.today()
        );
        insert sourceTask;
        insert new Interaction_Intelligence__c(
            Opportunity__c = opportunity.Id, Source_Type__c = 'Call',
            Source_Record_Id__c = sourceTask.Id,
            Key_Decision__c = '다음 주 제안서 재전달',
            Follow_Up__c = '다음 주 제안서 재전달 예정',
            Concerns_Objections__c = '예산 확인 필요'
        );

        Test.startTest();
        StageGuidanceController.CurrentQuoteContext result =
            StageGuidanceController.getCurrentQuoteContext(opportunity.Id);
        Test.stopTest();

        System.assert(result.found);
        System.assertEquals('Presented', result.quoteStatus);
        System.assertEquals(300000000, result.quoteGrandTotal);
        System.assertEquals(1, result.lineItems.size());
        System.assertEquals('TEST - LED + Brand Day', result.lineItems[0].productName);
        System.assertEquals('TEST-LED-BD', result.lineItems[0].productCode);
        System.assertEquals(1, result.lineItems[0].quantity);
        System.assertEquals(300000000, result.lineItems[0].unitPrice);
        System.assertEquals(300000000, result.lineItems[0].totalPrice);

        StageGuidanceController.ProposalEvidence evidence =
            StageGuidanceController.getProposalEvidence(opportunity.Id);
        System.assertEquals(
            new List<String>{ '전광판 노출 필수', '분기별 리포트 제공' },
            evidence.requiredRequirements
        );
        System.assertEquals(1, evidence.interactionFacts.size());
        System.assertEquals('다음 주 제안서 재전달', evidence.interactionFacts[0].keyDecision);
        System.assertEquals('다음 주 제안서 재전달 예정', evidence.interactionFacts[0].followUp);
    }
}

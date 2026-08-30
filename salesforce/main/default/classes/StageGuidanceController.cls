/**
 * Read-only adapter for the Stage Guidance record-page card.
 *
 * DealContext remains the single query/aggregation source. This class only
 * exposes its stored facts to Lightning; it performs no DML and makes no
 * recommendation or risk decision.
 */
public with sharing class StageGuidanceController {
    @AuraEnabled(cacheable=true)
    public static GuidanceContext getContext(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }

        DealContext.Request request = new DealContext.Request();
        request.opportunityId = opportunityId;
        List<DealContext.Result> results = DealContext.execute(
            new List<DealContext.Request>{ request }
        );
        if (results == null || results.isEmpty() || !results[0].found) {
            return null;
        }
        return new GuidanceContext(results[0]);
    }

    @AuraEnabled
    public static RecommendationResponse getRecommendation(Id opportunityId) {
        RecommendationResponse response = new RecommendationResponse();
        if (opportunityId == null) {
            response.errorMessage = 'Opportunity를 찾을 수 없습니다.';
            return response;
        }

        DealContext.Result deal = first(DealContext.execute(new List<DealContext.Request>{ dealRequest(opportunityId) }));
        if (deal == null || !deal.found) {
            response.errorMessage = 'Opportunity를 읽을 수 없습니다.';
            return response;
        }
        Map<String, Object> context = new Map<String, Object>{
            'stage' => deal.stageName,
            'deal' => deal
        };
        if (deal.stageName == 'Proposal/Quote') {
            context.put('proposal', first(OpportunityProposalContext.execute(
                new List<OpportunityProposalContext.Request>{ proposalRequest(opportunityId) }
            )));
            // Keep the actual customer quote separate from the catalog menu. This is
            // read-only evidence only; it does not infer requirement fulfillment.
            context.put('currentQuote', getCurrentQuoteContext(opportunityId));
            context.put('proposalEvidence', getProposalEvidence(opportunityId));
            context.put('catalogue', first(SponsorshipPackageLookup.execute(
                new List<SponsorshipPackageLookup.Request>{ catalogueRequest(opportunityId) }
            )));
        } else if (deal.stageName == 'Negotiation') {
            context.put('negotiation', first(NegotiationContext.execute(
                new List<NegotiationContext.Request>{ negotiationRequest(opportunityId) }
            )));
            context.put('interactionIntelligence', getIntelligence(opportunityId));
        } else if (deal.stageName == 'Discovery') {
            context.put('interactionIntelligence', getIntelligence(opportunityId));
        }

        if (Test.isRunningTest() && recommendationForTest != null) {
            response.recommendation = recommendationForTest;
            return response;
        }

        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput input =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.isPreview = false;
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptBuilderPreview';
            input.inputParams = new Map<String, ConnectApi.WrappedValue>();
            ConnectApi.WrappedValue wrappedDigest = new ConnectApi.WrappedValue();
            wrappedDigest.value = JSON.serialize(context);
            input.inputParams.put('Input:ContextDigest', wrappedDigest);
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generation =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'CA_Stage_Guidance_Recommendation', input
                );
            if (generation == null || generation.generations == null || generation.generations.isEmpty()
                || String.isBlank(generation.generations[0].text)) {
                response.errorMessage = 'AI recommendation을 생성하지 못했습니다.';
            } else {
                response.recommendation = generation.generations[0].text;
            }
        } catch (Exception e) {
            response.errorMessage = 'AI recommendation을 생성하지 못했습니다.';
        }
        return response;
    }

    @TestVisible private static String recommendationForTest;

    private static DealContext.Request dealRequest(Id opportunityId) {
        DealContext.Request request = new DealContext.Request(); request.opportunityId = opportunityId; return request;
    }
    private static OpportunityProposalContext.Request proposalRequest(Id opportunityId) {
        OpportunityProposalContext.Request request = new OpportunityProposalContext.Request(); request.opportunityId = opportunityId; return request;
    }
    private static SponsorshipPackageLookup.Request catalogueRequest(Id opportunityId) {
        SponsorshipPackageLookup.Request request = new SponsorshipPackageLookup.Request(); request.opportunityId = opportunityId; return request;
    }
    private static NegotiationContext.Request negotiationRequest(Id opportunityId) {
        NegotiationContext.Request request = new NegotiationContext.Request(); request.opportunityId = opportunityId; return request;
    }
    private static ActivityIntelligenceAgentAction.Request intelligenceRequest(Id opportunityId) {
        ActivityIntelligenceAgentAction.Request request = new ActivityIntelligenceAgentAction.Request(); request.opportunityId = String.valueOf(opportunityId); return request;
    }
    private static ActivityIntelligenceAgentAction.Response getIntelligence(Id opportunityId) {
        return first(ActivityIntelligenceAgentAction.getInteractionIntelligence(
            new List<ActivityIntelligenceAgentAction.Request>{ intelligenceRequest(opportunityId) }
        ));
    }

    @TestVisible
    private static CurrentQuoteContext getCurrentQuoteContext(Id opportunityId) {
        CurrentQuoteContext result = new CurrentQuoteContext();
        result.selectionBasis = 'Latest Quote by CreatedDate';
        List<Quote> quotes = [
            SELECT Id, Name, Status, GrandTotal, CurrencyIsoCode,
                   (SELECT Quantity, UnitPrice, Discount, TotalPrice,
                           Product2.Name, Product2.ProductCode
                    FROM QuoteLineItems)
            FROM Quote
            WHERE OpportunityId = :opportunityId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            return result;
        }

        Quote quote = quotes[0];
        result.found = true;
        result.quoteId = quote.Id;
        result.quoteName = quote.Name;
        result.quoteStatus = quote.Status;
        result.quoteGrandTotal = quote.GrandTotal;
        result.currencyIsoCode = quote.CurrencyIsoCode;
        for (QuoteLineItem item : quote.QuoteLineItems) {
            CurrentQuoteLineItem line = new CurrentQuoteLineItem();
            line.productName = item.Product2 == null ? null : item.Product2.Name;
            line.productCode = item.Product2 == null ? null : item.Product2.ProductCode;
            line.quantity = item.Quantity;
            line.unitPrice = item.UnitPrice;
            line.discount = item.Discount;
            line.totalPrice = item.TotalPrice;
            result.lineItems.add(line);
        }
        return result;
    }

    @TestVisible
    private static ProposalEvidence getProposalEvidence(Id opportunityId) {
        ProposalEvidence result = new ProposalEvidence();
        Opportunity opportunity = [
            SELECT Key_Requirements__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH USER_MODE
            LIMIT 1
        ];
        if (String.isNotBlank(opportunity.Key_Requirements__c)) {
            for (String sentence : opportunity.Key_Requirements__c.split('\\.')) {
                String requirement = sentence == null ? null : sentence.trim();
                if (String.isNotBlank(requirement)) {
                    result.requiredRequirements.add(requirement);
                }
            }
        }
        for (Interaction_Intelligence__c record : [
            SELECT Key_Decision__c, Follow_Up__c, Concerns_Objections__c
            FROM Interaction_Intelligence__c
            WHERE Opportunity__c = :opportunityId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            ProposalInteractionFact fact = new ProposalInteractionFact();
            fact.keyDecision = record.Key_Decision__c;
            fact.followUp = record.Follow_Up__c;
            fact.concerns = record.Concerns_Objections__c;
            result.interactionFacts.add(fact);
        }
        return result;
    }
    private static DealContext.Result first(List<DealContext.Result> results) { return results == null || results.isEmpty() ? null : results[0]; }
    private static OpportunityProposalContext.Result first(List<OpportunityProposalContext.Result> results) { return results == null || results.isEmpty() ? null : results[0]; }
    private static SponsorshipPackageLookup.Result first(List<SponsorshipPackageLookup.Result> results) { return results == null || results.isEmpty() ? null : results[0]; }
    private static NegotiationContext.Result first(List<NegotiationContext.Result> results) { return results == null || results.isEmpty() ? null : results[0]; }
    private static ActivityIntelligenceAgentAction.Response first(List<ActivityIntelligenceAgentAction.Response> results) { return results == null || results.isEmpty() ? null : results[0]; }

    public class RecommendationResponse {
        @AuraEnabled public String recommendation;
        @AuraEnabled public String errorMessage;
    }

    public class CurrentQuoteContext {
        public Boolean found = false;
        public String selectionBasis;
        public Id quoteId;
        public String quoteName;
        public String quoteStatus;
        public Decimal quoteGrandTotal;
        public String currencyIsoCode;
        public List<CurrentQuoteLineItem> lineItems = new List<CurrentQuoteLineItem>();
    }

    public class CurrentQuoteLineItem {
        public String productName;
        public String productCode;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal discount;
        public Decimal totalPrice;
    }

    public class ProposalEvidence {
        public List<String> requiredRequirements = new List<String>();
        public List<ProposalInteractionFact> interactionFacts = new List<ProposalInteractionFact>();
    }

    public class ProposalInteractionFact {
        public String keyDecision;
        public String followUp;
        public String concerns;
    }

    public class GuidanceContext {
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String stageName;
        @AuraEnabled public Boolean isClosed;
        @AuraEnabled public Boolean isWon;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public String partnerTier;
        @AuraEnabled public String primaryContactName;
        @AuraEnabled public String decisionMakerAccessible;
        @AuraEnabled public String brandFanFit;
        @AuraEnabled public String interestLevel;
        @AuraEnabled public String expectedTiming;
        @AuraEnabled public String clientBudgetStatus;
        @AuraEnabled public String nextStep;
        @AuraEnabled public Date lastActivityDate;
        @AuraEnabled public Date nextActivityDate;
        @AuraEnabled public String nextActivitySubject;
        @AuraEnabled public Decimal openTaskCount;
        @AuraEnabled public Decimal overdueTaskCount;
        @AuraEnabled public String dealNote;
        @AuraEnabled public Integer quoteCount;
        @AuraEnabled public Boolean hasSyncedQuote;
        @AuraEnabled public String syncedQuoteStatus;
        @AuraEnabled public String latestQuoteStatus;
        @AuraEnabled public Boolean hasInteractionIntelligence;
        @AuraEnabled public Integer interactionCount;
        @AuraEnabled public String latestConcernsObjections;
        @AuraEnabled public String reasonLost;

        private GuidanceContext(DealContext.Result source) {
            opportunityName = source.opportunityName;
            accountName = source.accountName;
            stageName = source.stageName;
            isClosed = source.isClosed;
            isWon = source.isWon;
            amount = source.amount;
            closeDate = source.closeDate;
            partnerTier = source.partnerTier;
            primaryContactName = source.primaryContactName;
            decisionMakerAccessible = source.decisionMakerAccessible;
            brandFanFit = source.brandFanFit;
            interestLevel = source.interestLevel;
            expectedTiming = source.expectedTiming;
            clientBudgetStatus = source.clientBudgetStatus;
            nextStep = source.nextStep;
            lastActivityDate = source.lastActivityDate;
            nextActivityDate = source.nextActivityDate;
            nextActivitySubject = source.nextActivitySubject;
            openTaskCount = source.openTaskCount;
            overdueTaskCount = source.overdueTaskCount;
            dealNote = source.dealNote;
            quoteCount = source.quoteCount;
            hasSyncedQuote = source.hasSyncedQuote;
            syncedQuoteStatus = source.syncedQuoteStatus;
            latestQuoteStatus = source.latestQuoteStatus;
            hasInteractionIntelligence = source.hasInteractionIntelligence;
            interactionCount = source.interactionCount;
            latestConcernsObjections = source.latestConcernsObjections;
            reasonLost = source.reasonLost;
        }
    }
}

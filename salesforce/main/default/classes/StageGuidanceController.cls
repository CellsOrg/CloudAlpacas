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

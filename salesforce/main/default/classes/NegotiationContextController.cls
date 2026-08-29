/**
 * Read-only adapter that exposes NegotiationContext to Lightning (LWC).
 *
 * NegotiationContext is an @InvocableMethod whose @InvocableVariable fields do not
 * serialize to LWC, so this controller calls it unchanged and flattens the first
 * Result into an @AuraEnabled DTO. No new queries, no DML, no business rules — the
 * negotiationContextSummary card is a plain read-only view of what the Negotiation
 * Assistant already computes.
 */
public with sharing class NegotiationContextController {

    @AuraEnabled(cacheable=true)
    public static NegotiationContextView getContext(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        NegotiationContext.Request req = new NegotiationContext.Request();
        req.opportunityId = opportunityId;

        List<NegotiationContext.Result> results = NegotiationContext.execute(
            new List<NegotiationContext.Request>{ req }
        );
        if (results == null || results.isEmpty()) {
            return null;
        }
        NegotiationContext.Result first = results[0];
        // NegotiationContext returns a blank Result (not an empty list) when the
        // Opportunity is not found or not visible to the running user. Name is
        // always populated for a real, readable Opportunity, so a null name means
        // "no context" — surface that as null for the card's empty state.
        if (first.opportunityName == null) {
            return null;
        }
        return new NegotiationContextView(first);
    }

    /**
     * Flat projection of NegotiationContext.Result. Only the fields the
     * negotiationContextSummary card renders are carried over.
     */
    public class NegotiationContextView {
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Decimal clientBudget;
        @AuraEnabled public String clientBudgetStatus;

        @AuraEnabled public Boolean hasQuote;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteStatus;
        @AuraEnabled public Decimal quoteGrandTotal;
        @AuraEnabled public Date quoteExpirationDate;

        @AuraEnabled public Decimal quoteDiscount;
        @AuraEnabled public Decimal maxDiscountPercent;
        @AuraEnabled public Decimal maxDiscountedPrice;
        @AuraEnabled public Boolean lineItemDiscountUpdatable;
        @AuraEnabled public String lineItemDiscountLockReason;

        @AuraEnabled public Boolean hasInteractionIntelligence;
        @AuraEnabled public String interactionHistorySummary;

        public NegotiationContextView(NegotiationContext.Result r) {
            this.opportunityName = r.opportunityName;
            this.clientBudget = r.clientBudget;
            this.clientBudgetStatus = r.clientBudgetStatus;

            this.hasQuote = r.hasQuote;
            this.quoteName = r.quoteName;
            this.quoteStatus = r.quoteStatus;
            this.quoteGrandTotal = r.quoteGrandTotal;
            this.quoteExpirationDate = r.quoteExpirationDate;

            this.quoteDiscount = r.quoteDiscount;
            this.maxDiscountPercent = r.maxDiscountPercent;
            this.maxDiscountedPrice = r.maxDiscountedPrice;
            this.lineItemDiscountUpdatable = r.lineItemDiscountUpdatable;
            this.lineItemDiscountLockReason = r.lineItemDiscountLockReason;

            this.hasInteractionIntelligence = r.hasInteractionIntelligence;
            this.interactionHistorySummary = r.interactionHistorySummary;
        }
    }
}

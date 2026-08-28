public with sharing class NegotiationTermsUpdater {

    public class NegotiationTermsUpdaterException extends Exception {}

    @InvocableMethod(
        label='Update Negotiation Terms'
        description='Updates the negotiated Discount (on the primary QuoteLineItem), Expiration Date, Description (terms notes), and/or Status (on the Quote header). Only the fields provided are changed.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();

            Quote q = new Quote(Id = req.quoteId);
            Boolean hasQuoteUpdate = false;

            if (req.expirationDate != null) {
                q.ExpirationDate = req.expirationDate;
                hasQuoteUpdate = true;
            }
            if (String.isNotBlank(req.description)) {
                q.Description = req.description;
                hasQuoteUpdate = true;
            }
            if (String.isNotBlank(req.status)) {
                q.Status = req.status;
                hasQuoteUpdate = true;
            }

            Boolean hasLineItemUpdate = false;
            if (req.discount != null) {
                if (req.quoteLineItemId == null) {
                    throw new NegotiationTermsUpdaterException(
                        'quoteLineItemId is required to update discount on Quote ' + req.quoteId
                    );
                }
                hasLineItemUpdate = true;
            }

            if (!hasQuoteUpdate && !hasLineItemUpdate) {
                throw new NegotiationTermsUpdaterException(
                    'No negotiation term values were provided to update on Quote ' + req.quoteId
                );
            }

            if (hasQuoteUpdate) {
                update as user q;
            }

            if (hasLineItemUpdate) {
                QuoteLineItem qli = new QuoteLineItem(Id = req.quoteLineItemId, Discount = req.discount);
                update as user qli;
            }

            Quote updated = [
                SELECT Id, Status, ExpirationDate
                FROM Quote
                WHERE Id = :req.quoteId
                WITH USER_MODE
            ];

            r.success = true;
            r.updatedStatus = updated.Status;
            r.updatedExpirationDate = updated.ExpirationDate;

            if (hasLineItemUpdate) {
                QuoteLineItem updatedLineItem = [
                    SELECT Id, Discount
                    FROM QuoteLineItem
                    WHERE Id = :req.quoteLineItemId
                    WITH USER_MODE
                ];
                r.updatedDiscount = updatedLineItem.Discount;
            }

            results.add(r);
        }

        return results;
    }

    public class Request {
        @InvocableVariable(
            label='Quote Id'
            description='Id of the Quote to update with negotiated terms.'
            required=true
        )
        public Id quoteId;

        @InvocableVariable(
            label='Quote Line Item Id'
            description='Id of the primary QuoteLineItem to apply the negotiated discount to. Required only when discount is provided.'
            required=false
        )
        public Id quoteLineItemId;

        @InvocableVariable(
            label='Discount'
            description='Negotiated discount percentage to set on the primary QuoteLineItem, if changed.'
            required=false
        )
        public Decimal discount;

        @InvocableVariable(
            label='Expiration Date'
            description='Negotiated offer validity/expiration date, if changed.'
            required=false
        )
        public Date expirationDate;

        @InvocableVariable(
            label='Description'
            description='Negotiation terms/notes to record on the Quote, if changed.'
            required=false
        )
        public String description;

        @InvocableVariable(
            label='Status'
            description='New Quote status reflecting the negotiation/approval stage: one of Draft, Needs Review, In Review, Approved, Rejected, Presented, Accepted, Denied.'
            required=false
        )
        public String status;
    }

    public class Result {
        @InvocableVariable(label='Success' description='Whether the update completed successfully.')
        public Boolean success;

        @InvocableVariable(label='Updated Status' description='Quote.Status after the update.')
        public String updatedStatus;

        @InvocableVariable(label='Updated Discount' description='QuoteLineItem.Discount after the update, if discount was changed.')
        public Decimal updatedDiscount;

        @InvocableVariable(label='Updated Expiration Date' description='Quote.ExpirationDate after the update.')
        public Date updatedExpirationDate;
    }
}

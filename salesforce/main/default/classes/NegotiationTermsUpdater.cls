public with sharing class NegotiationTermsUpdater {

    public class NegotiationTermsUpdaterException extends Exception {}

    @InvocableMethod(
        label='Update Negotiation Terms'
        description='Updates the negotiated Discount (on the primary QuoteLineItem), Expiration Date, Description (terms notes), and/or Status (on the Quote header). Only the fields provided are changed.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        // Pre-flight: Salesforce blocks any Discount change on a revenue-scheduled
        // QuoteLineItem with FIELD_INTEGRITY_EXCEPTION ("cannot modify discount when the
        // item is revenue scheduled"). Detect it up front, before any DML, so the agent
        // can explain it in Korean rather than surfacing a raw platform failure.
        Set<Id> discountLineItemIds = new Set<Id>();
        for (Request req : requests) {
            if (req.discount != null && req.quoteLineItemId != null) {
                discountLineItemIds.add(req.quoteLineItemId);
            }
        }
        Map<Id, QuoteLineItem> lineItemsById = discountLineItemIds.isEmpty()
            ? new Map<Id, QuoteLineItem>()
            : new Map<Id, QuoteLineItem>([
                SELECT Id, HasRevenueSchedule
                FROM QuoteLineItem
                WHERE Id IN :discountLineItemIds
                WITH USER_MODE
            ]);

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
                QuoteLineItem targetLineItem = lineItemsById.get(req.quoteLineItemId);
                if (targetLineItem != null && targetLineItem.HasRevenueSchedule == true) {
                    throw new NegotiationTermsUpdaterException(
                        '이 견적 라인 아이템에는 매출 일정(Revenue Schedule)이 설정되어 있어 할인율(Discount)을 ' +
                        '변경할 수 없습니다. 할인율을 조정하려면 먼저 매출 일정을 재구성해야 하며, 이는 협상 도구의 ' +
                        '범위를 벗어납니다. 상태·유효기한·조건 메모 변경은 별도로 요청해 주세요.'
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

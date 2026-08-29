/**
 * Regression coverage for the revenue-scheduled QuoteLineItem case (QA #9).
 *
 * Salesforce blocks any Discount change on a QuoteLineItem whose HasRevenueSchedule = true
 * (FIELD_INTEGRITY_EXCEPTION: "cannot modify discount when the item is revenue scheduled").
 * That flag only arises from platform-managed Quote/Opportunity sync of a revenue-scheduled
 * product and CANNOT be produced from Apex in an isolated test (verified: not settable, no
 * QuoteLineItemSchedule sObject, sync does not mirror it, product config alone does not set
 * it on a QuoteLineItem). These tests therefore run best-effort against a real locked line
 * item when the org has one, and stay green (no-op) otherwise. They are read-only — the
 * NegotiationTermsUpdater guard throws BEFORE any DML, so nothing is mutated.
 *
 * The non-scheduled ("normal") paths are covered synthetically in NegotiationContextTest
 * and NegotiationTermsUpdaterTest.
 */
@isTest(SeeAllData=true)
private class NegotiationRevenueScheduleTest {

    private static QuoteLineItem lockedLineItem() {
        List<QuoteLineItem> locked = [
            SELECT Id, QuoteId, Discount, Quote.OpportunityId
            FROM QuoteLineItem
            WHERE HasRevenueSchedule = true
            LIMIT 1
        ];
        return locked.isEmpty() ? null : locked[0];
    }

    @isTest
    static void updateNegotiationTermsRejectsDiscountBeforeDml() {
        QuoteLineItem locked = lockedLineItem();
        if (locked == null) {
            return; // no revenue-scheduled line item in this org — nothing to assert
        }
        Decimal originalDiscount = locked.Discount;

        NegotiationTermsUpdater.Request req = new NegotiationTermsUpdater.Request();
        req.quoteId = locked.QuoteId;
        req.quoteLineItemId = locked.Id;
        req.discount = 10;

        Test.startTest();
        Boolean threw = false;
        String msg = null;
        try {
            NegotiationTermsUpdater.execute(new List<NegotiationTermsUpdater.Request>{ req });
        } catch (NegotiationTermsUpdater.NegotiationTermsUpdaterException e) {
            threw = true;
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assert(threw, '매출 일정이 걸린 라인아이템의 할인율 변경은 예외로 거부되어야 한다');
        System.assert(msg != null && msg.contains('매출 일정'),
            '거부 메시지는 매출 일정 때문임을 한국어로 설명해야 한다: ' + msg);
        System.assertEquals(originalDiscount,
            [SELECT Discount FROM QuoteLineItem WHERE Id = :locked.Id].Discount,
            '거부는 DML 이전에 일어나므로 할인율이 그대로여야 한다');
    }

    @isTest
    static void negotiationContextSurfacesDiscountLock() {
        QuoteLineItem locked = lockedLineItem();
        if (locked == null || locked.Quote.OpportunityId == null) {
            return;
        }

        NegotiationContext.Request req = new NegotiationContext.Request();
        req.opportunityId = locked.Quote.OpportunityId;

        Test.startTest();
        NegotiationContext.Result r =
            NegotiationContext.execute(new List<NegotiationContext.Request>{ req })[0];
        Test.stopTest();

        // Only assert when the primary line item NegotiationContext resolved is the locked one
        // (the Opportunity's most recent Quote may legitimately be a different one).
        if (r.quoteLineItemId == locked.Id) {
            System.assertEquals(false, r.lineItemDiscountUpdatable,
                '매출 일정이 걸린 라인아이템은 할인율 변경 불가로 보고되어야 한다');
            System.assert(String.isNotBlank(r.lineItemDiscountLockReason),
                '할인율 잠금 사유 문구가 채워져야 한다');
        }
    }
}

import { LightningElement, api, wire } from 'lwc';
import getContext from '@salesforce/apex/NegotiationContextController.getContext';

const DASH = '—';

/**
 * Read-only Negotiation-stage context card. Every value comes from
 * NegotiationContextController.getContext (which reuses NegotiationContext, the
 * Negotiation Assistant's own action). No thresholds, no coloring rules — the
 * budget/quote gap is shown as a plain signed number.
 */
export default class NegotiationContextSummary extends LightningElement {
    @api recordId;

    data;
    error;

    @wire(getContext, { opportunityId: '$recordId' })
    wiredContext({ data, error }) {
        if (data) {
            this.data = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.data = undefined;
        } else {
            // Apex returned null (Opportunity not found / no access).
            this.data = undefined;
            this.error = undefined;
        }
    }

    get hasData() {
        return !!this.data;
    }

    get hasError() {
        return !!this.error;
    }

    get noContext() {
        return !this.data && !this.error;
    }

    get errorMessage() {
        return (
            this.error &&
            (this.error.body?.message || this.error.message || '협상 컨텍스트를 불러오지 못했습니다.')
        );
    }

    // --- Quote / budget -----------------------------------------------------

    get quoteStatusDisplay() {
        return this.data?.quoteStatus || (this.data?.hasQuote ? DASH : '정보 없음');
    }

    get hasClientBudget() {
        return this.data?.clientBudget !== null && this.data?.clientBudget !== undefined;
    }

    get clientBudget() {
        return this.data?.clientBudget;
    }

    get clientBudgetStatusDisplay() {
        return this.data?.clientBudgetStatus || DASH;
    }

    get hasQuoteTotal() {
        return this.data?.quoteGrandTotal !== null && this.data?.quoteGrandTotal !== undefined;
    }

    get quoteTotal() {
        return this.data?.quoteGrandTotal;
    }

    get hasBudgetVsQuote() {
        return this.hasClientBudget && this.hasQuoteTotal;
    }

    // Plain signed number: quote total minus client budget.
    // Positive = quote is above the stated budget. No coloring, no verdict.
    get budgetVsQuote() {
        if (!this.hasBudgetVsQuote) {
            return null;
        }
        return this.data.quoteGrandTotal - this.data.clientBudget;
    }

    get quoteExpirationDate() {
        return this.data?.quoteExpirationDate;
    }

    get hasQuoteExpirationDate() {
        return !!this.data?.quoteExpirationDate;
    }

    // --- Discount ----------------------------------------------------------

    get currentDiscountDisplay() {
        const d = this.data?.quoteDiscount;
        return d === null || d === undefined ? DASH : `${d}%`;
    }

    get approvalDiscountLimitDisplay() {
        const d = this.data?.maxDiscountPercent;
        return d === null || d === undefined ? DASH : `${d}%`;
    }

    get hasMaxDiscountedPrice() {
        return (
            this.data?.maxDiscountedPrice !== null && this.data?.maxDiscountedPrice !== undefined
        );
    }

    get maxDiscountedPrice() {
        return this.data?.maxDiscountedPrice;
    }

    get discountRestricted() {
        return this.data?.lineItemDiscountUpdatable === false;
    }

    get discountRestrictionText() {
        if (this.discountRestricted) {
            return this.data?.lineItemDiscountLockReason || '매출 일정으로 할인율 변경이 제한됩니다.';
        }
        return '할인율 변경 제한 없음';
    }

    // --- Recent interaction concern --------------------------------------

    get hasRecentConcern() {
        return !!(this.data?.hasInteractionIntelligence && this.data?.interactionHistorySummary);
    }

    get recentConcernDisplay() {
        if (!this.hasRecentConcern) {
            return '기록된 상호작용 없음';
        }
        // interactionHistorySummary is newest-first, one entry per line.
        return this.data.interactionHistorySummary.split('\n')[0];
    }
}

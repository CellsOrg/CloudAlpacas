import { createElement } from 'lwc';
import NegotiationContextSummary from 'c/negotiationContextSummary';
import getContext from '@salesforce/apex/NegotiationContextController.getContext';

jest.mock(
    '@salesforce/apex/NegotiationContextController.getContext',
    () => {
        const {
            createApexTestWireAdapter
        } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const FULL_CONTEXT = {
    opportunityName: '삼성카드 - 2026 시즌 파트너십',
    clientBudget: 700000000,
    clientBudgetStatus: 'Confirmed',
    hasQuote: true,
    quoteName: 'Q-0001',
    quoteStatus: 'Presented',
    quoteGrandTotal: 770000000,
    quoteExpirationDate: '2026-09-30',
    quoteDiscount: 4,
    maxDiscountPercent: 8,
    maxDiscountedPrice: 644000000,
    lineItemDiscountUpdatable: true,
    lineItemDiscountLockReason: null,
    hasInteractionIntelligence: true,
    interactionHistorySummary:
        '2026-08-25 - 우려사항: 연간 금액 부담 / 고객반응: Neutral\n2026-08-10 - 우려사항: 노출 구좌 협의'
};

function flush() {
    return Promise.resolve();
}

function create() {
    const el = createElement('c-negotiation-context-summary', {
        is: NegotiationContextSummary
    });
    el.recordId = '006000000000001AAA';
    document.body.appendChild(el);
    return el;
}

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
});

describe('c-negotiation-context-summary', () => {
    it('renders every negotiation datapoint for a full context', async () => {
        const el = create();
        getContext.emit(FULL_CONTEXT);
        await flush();

        const text = el.shadowRoot.textContent;
        expect(text).toContain('Presented');
        expect(text).toContain('현재 할인율');
        expect(text).toContain('4%');
        expect(text).toContain('승인 없이 가능한 최대 할인율');
        expect(text).toContain('8%');
        expect(text).toContain('할인율 변경 제한 없음');
        expect(text).toContain('연간 금액 부담');
        // only the most recent interaction line is shown
        expect(text).not.toContain('노출 구좌 협의');
        expect(text).not.toContain('협상 컨텍스트 정보 없음');
    });

    it('shows "정보 없음" placeholders when values are missing / null', async () => {
        const el = create();
        getContext.emit({
            opportunityName: '하나은행 - 2026 시즌 파트너십',
            clientBudget: null,
            clientBudgetStatus: null,
            hasQuote: false,
            quoteName: null,
            quoteStatus: null,
            quoteGrandTotal: null,
            quoteExpirationDate: null,
            quoteDiscount: null,
            maxDiscountPercent: null,
            maxDiscountedPrice: null,
            lineItemDiscountUpdatable: true,
            lineItemDiscountLockReason: null,
            hasInteractionIntelligence: false,
            interactionHistorySummary: null
        });
        await flush();

        const text = el.shadowRoot.textContent;
        expect(text).toContain('정보 없음'); // budget / quote total
        expect(text).toContain('기록된 상호작용 없음');
        expect(text).toContain('—'); // budget vs quote diff cannot be computed
    });

    it('renders an error message when the wire fails', async () => {
        const el = create();
        getContext.error({ message: '접근 권한이 없습니다.' }, 403);
        await flush();

        const text = el.shadowRoot.textContent;
        expect(text).toContain('접근 권한이 없습니다.');
    });

    it('shows the revenue-schedule discount restriction reason', async () => {
        const el = create();
        getContext.emit({
            ...FULL_CONTEXT,
            lineItemDiscountUpdatable: false,
            lineItemDiscountLockReason:
                '이 라인 아이템에는 매출 일정(Revenue Schedule)이 설정되어 있어 할인율을 변경할 수 없습니다.'
        });
        await flush();

        const text = el.shadowRoot.textContent;
        expect(text).toContain('매출 일정(Revenue Schedule)');
        expect(text).not.toContain('할인율 변경 제한 없음');
    });

    it('handles no recent interaction concern', async () => {
        const el = create();
        getContext.emit({
            ...FULL_CONTEXT,
            hasInteractionIntelligence: false,
            interactionHistorySummary: null
        });
        await flush();

        expect(el.shadowRoot.textContent).toContain('기록된 상호작용 없음');
    });

    it('shows a neutral empty state when Apex returns null', async () => {
        const el = create();
        getContext.emit(null);
        await flush();

        expect(el.shadowRoot.textContent).toContain('협상 컨텍스트 정보 없음');
    });
});

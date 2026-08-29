import { createElement } from 'lwc';
import OpportunityAgentChatModal from 'c/opportunityAgentChatModal';

const flush = () => Promise.resolve();

const CONVERSATIONS = [
    {
        id: 'c-old',
        title: '골드 패키지 견적 구성',
        sessionId: 's-old',
        createdAt: new Date('2026-08-28T17:10:00').getTime(),
        updatedAt: new Date('2026-08-28T17:12:00').getTime(),
        messages: [
            { key: 'a', role: 'user', text: '그 조건으로 견적서를 만들어줘' },
            { key: 'b', role: 'agent', text: '견적서를 구성했습니다.' }
        ]
    },
    {
        id: 'c-new',
        title: '최근 고객 반응과 협상 상황',
        sessionId: 's-new',
        createdAt: new Date('2026-08-29T14:30:00').getTime(),
        updatedAt: new Date('2026-08-29T14:32:00').getTime(),
        messages: [
            { key: 'c', role: 'user', text: '예산에 대한 우려가 있었나?' },
            { key: 'd', role: 'agent', text: '네, 예산 관련 우려가 기록되어 있습니다.' }
        ]
    }
];

function mount(props = {}) {
    const el = createElement('c-opportunity-agent-chat-modal', { is: OpportunityAgentChatModal });
    el.opportunityName = "d'Alba - 2026 시즌 골드 파트너십";
    el.conversations = CONVERSATIONS;
    el.view = 'list';
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
});

describe('c-opportunity-agent-chat-modal — list view', () => {
    it('renders as a wide SLDS modal with a backdrop', () => {
        const el = mount();
        expect(el.shadowRoot.querySelector('section.slds-modal[role="dialog"]')).not.toBeNull();
        expect(el.shadowRoot.querySelector('.slds-backdrop')).not.toBeNull();
        expect(el.shadowRoot.querySelector('[aria-modal="true"]')).not.toBeNull();
    });

    it('shows the current Opportunity name and a "새 대화" action', () => {
        const el = mount();
        expect(el.shadowRoot.textContent).toContain("d'Alba - 2026 시즌 골드 파트너십");
        const newBtn = [...el.shadowRoot.querySelectorAll('lightning-button')].find((b) => b.label === '새 대화');
        expect(newBtn).toBeDefined();
    });

    it('groups conversations by date', () => {
        const el = mount();
        const groupLabels = [...el.shadowRoot.querySelectorAll('.oac-daygroup__label')].map((n) => n.textContent);
        expect(groupLabels.some((l) => l.includes('8월 28일'))).toBe(true);
        expect(groupLabels.some((l) => l.includes('8월 29일'))).toBe(true);
    });

    it('each conversation card shows title, last-message preview and time (no message count)', () => {
        const el = mount();
        const cards = el.shadowRoot.querySelectorAll('.oac-convo-card');
        expect(cards.length).toBe(2);
        const text = cards[0].textContent + cards[1].textContent;
        expect(text).toContain('골드 패키지 견적 구성');
        expect(text).toContain('마지막 대화:');
        expect(text).not.toContain('메시지 2개');
        expect(text).not.toContain('메시지 1개');
    });

    it('hides empty "새 대화" rows from the history list without deleting them', () => {
        const el = mount({
            conversations: [
                ...CONVERSATIONS,
                { id: 'c-blank', title: '', sessionId: null, createdAt: Date.now(), updatedAt: Date.now(), messages: [] }
            ]
        });
        expect(el.shadowRoot.querySelectorAll('.oac-convo-card').length).toBe(2);
    });

    it('search filters conversations by title and message text', async () => {
        const el = mount({ searchTerm: '예산' });
        await flush();
        const cards = el.shadowRoot.querySelectorAll('.oac-convo-card');
        expect(cards.length).toBe(1);
        expect(cards[0].textContent).toContain('최근 고객 반응');
    });

    it('typing in the search field emits a search event', () => {
        const el = mount();
        const handler = jest.fn();
        el.addEventListener('search', handler);
        const search = el.shadowRoot.querySelector('lightning-input');
        search.value = '할인';
        search.dispatchEvent(new CustomEvent('change'));
        expect(handler.mock.calls[0][0].detail.value).toBe('할인');
    });

    it('emits openconversation with the id when a card is clicked', async () => {
        const el = mount();
        const handler = jest.fn();
        el.addEventListener('openconversation', handler);
        el.shadowRoot.querySelector('.oac-convo-card').click();
        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail.id).toBeDefined();
    });

    it('emits newconversation from "새 대화"', () => {
        const el = mount();
        const handler = jest.fn();
        el.addEventListener('newconversation', handler);
        [...el.shadowRoot.querySelectorAll('lightning-button')].find((b) => b.label === '새 대화').click();
        expect(handler).toHaveBeenCalled();
    });
});

describe('c-opportunity-agent-chat-modal — detail view', () => {
    const detailProps = { view: 'detail', activeConversation: CONVERSATIONS[0] };

    it('renders messages chronologically as user / agent bubbles', () => {
        const el = mount(detailProps);
        const rows = [...el.shadowRoot.querySelectorAll('.oac-msg')];
        expect(rows.map((r) => r.classList.contains('oac-msg_user'))).toEqual([true, false]);
        expect(rows.map((r) => r.classList.contains('oac-msg_agent'))).toEqual([false, true]);
        // the agent bubble carries an "Opportunity Agent" label; the user bubble has none
        const roleLabels = [...el.shadowRoot.querySelectorAll('.oac-msg__role')].map((n) => n.textContent);
        expect(roleLabels).toEqual(['Opportunity Agent']);
        const bubbles = [...el.shadowRoot.querySelectorAll('.oac-msg__bubble lightning-formatted-text')].map((n) => n.value);
        expect(bubbles).toEqual(['그 조건으로 견적서를 만들어줘', '견적서를 구성했습니다.']);
    });

    it('has a follow-up composer with the shared placeholder and a back control', () => {
        const el = mount(detailProps);
        expect(el.shadowRoot.querySelector('lightning-textarea').placeholder).toBe('무엇이든 요청하세요!');
        const back = [...el.shadowRoot.querySelectorAll('lightning-button-icon')].find(
            (b) => b.alternativeText === '이전 대화 목록'
        );
        expect(back).toBeDefined();
    });

    it('emits send with the follow-up text', () => {
        const el = mount(detailProps);
        const handler = jest.fn();
        el.addEventListener('send', handler);
        const ta = el.shadowRoot.querySelector('lightning-textarea');
        ta.value = '그중 가장 최근 건은?';
        ta.dispatchEvent(new CustomEvent('change'));
        el.shadowRoot.querySelector('.oac-send').click();
        expect(handler.mock.calls[0][0].detail.text).toBe('그중 가장 최근 건은?');
    });

    it('emits back to return to the list', () => {
        const el = mount(detailProps);
        const handler = jest.fn();
        el.addEventListener('back', handler);
        [...el.shadowRoot.querySelectorAll('lightning-button-icon')]
            .find((b) => b.alternativeText === '이전 대화 목록')
            .click();
        expect(handler).toHaveBeenCalled();
    });

    it('shows a thinking indicator while busy', () => {
        const el = mount({ ...detailProps, busy: true });
        expect(el.shadowRoot.querySelector('lightning-spinner')).not.toBeNull();
    });

    it('closes on the X button and on Escape', () => {
        const el = mount(detailProps);
        const handler = jest.fn();
        el.addEventListener('close', handler);
        [...el.shadowRoot.querySelectorAll('lightning-button-icon')].find((b) => b.alternativeText === '닫기').click();
        expect(handler).toHaveBeenCalledTimes(1);

        el.shadowRoot.querySelector('section.slds-modal').dispatchEvent(
            new KeyboardEvent('keydown', { key: 'Escape' })
        );
        expect(handler).toHaveBeenCalledTimes(2);
    });
});

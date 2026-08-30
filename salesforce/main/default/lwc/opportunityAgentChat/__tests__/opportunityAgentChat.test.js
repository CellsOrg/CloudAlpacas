import { createElement } from 'lwc';
import OpportunityAgentChat from 'c/opportunityAgentChat';
import { getRecord } from 'lightning/uiRecordApi';
import sendMessage from '@salesforce/apex/OpportunityAgentChatController.sendMessage';
import endConversation from '@salesforce/apex/OpportunityAgentChatController.endConversation';

jest.mock(
    '@salesforce/apex/OpportunityAgentChatController.sendMessage',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/OpportunityAgentChatController.endConversation',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock('@salesforce/user/Id', () => ({ default: '005TEST' }), { virtual: true });

const GOLD = '006bm00000VXKvlAAH';
const SAMSUNG = '006bm00000VjTP7AAN';
const flush = () => Promise.resolve();

function mount(recordId = GOLD) {
    const el = createElement('c-opportunity-agent-chat', { is: OpportunityAgentChat });
    el.recordId = recordId;
    document.body.appendChild(el);
    getRecord.emit({ fields: { Name: { value: 'd\'Alba - 2026 시즌 골드 파트너십' } } });
    return el;
}

const composerInput = (el) => el.shadowRoot.querySelector('.oac-composer__input');
const askButton = (el) => el.shadowRoot.querySelector('.oac-send');
const historyButton = (el) => el.shadowRoot.querySelector('.oac-history');
const modal = (el) => el.shadowRoot.querySelector('c-opportunity-agent-chat-modal');

function typeCompact(el, text) {
    const inp = composerInput(el);
    inp.value = text;
    inp.dispatchEvent(new CustomEvent('input'));
}

afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
    window.localStorage.clear();
});

describe('c-opportunity-agent-chat — compact card', () => {
    it('renders the compact composer as a Navy/Orange wordmark with no intro copy or transcript', () => {
        const el = mount();
        const wordmark = el.shadowRoot.querySelector('.oac-wordmark');
        expect(wordmark.textContent.replace(/\s+/g, ' ').trim()).toBe('Opportunity Agent');
        expect(wordmark.querySelector('.oac-wordmark__primary').textContent).toBe('Opportunity');
        expect(wordmark.querySelector('.oac-wordmark__accent').textContent).toBe('Agent');
        expect(composerInput(el).placeholder).toBe('무엇이든 요청하세요!');
        // official Cloud Alpacas mascot static resource, not an inline drawing
        const mascot = el.shadowRoot.querySelector('.oac-mascot img');
        expect(mascot).not.toBeNull();
        expect(mascot.getAttribute('src')).toContain('CA_Alpaca_Mascot');
        expect(el.shadowRoot.querySelector('.oac-mascot svg')).toBeNull();
        // the two-line intro blurb is gone
        expect(el.shadowRoot.textContent).not.toContain('무엇이든 도와드립니다');
        expect(el.shadowRoot.textContent).not.toContain('활동 · 제안 · 협상 · 딜 요약을 지원');
        // no large transcript / message list in the compact card
        expect(el.shadowRoot.querySelectorAll('.oac-msg').length).toBe(0);
        expect(el.shadowRoot.querySelector('.transcript')).toBeNull();
    });

    it('has an explicit "이전 대화 기록 보기" action and no modal until opened', () => {
        const el = mount();
        expect(historyButton(el).textContent).toContain('이전 대화 기록 보기');
        expect(modal(el)).toBeNull();
    });

    it('sending a question opens the wide modal in detail view with the user message', async () => {
        let resolveTurn;
        sendMessage.mockImplementation(() => new Promise((r) => (resolveTurn = r)));
        const el = mount();

        typeCompact(el, '이 딜 상태 어때?');
        askButton(el).click();
        await flush();

        const m = modal(el);
        expect(m).not.toBeNull();
        expect(m.view).toBe('detail');
        expect(m.busy).toBe(true);
        expect(sendMessage).toHaveBeenCalledWith({
            opportunityId: GOLD,
            sessionId: null,
            message: '이 딜 상태 어때?'
        });
        expect(m.activeConversation.messages.map((x) => x.text)).toEqual(['이 딜 상태 어때?']);

        resolveTurn({ sessionId: 'sess-1', reply: '협상 단계입니다.', sessionRestarted: false });
        await flush();
        await flush();
        expect(m.busy).toBe(false);
        expect(m.activeConversation.messages.map((x) => x.role)).toEqual(['user', 'agent']);
        expect(m.activeConversation.sessionId).toBe('sess-1');
    });

    it('"이전 대화 기록 보기" opens the modal in list view scoped to this record', async () => {
        window.localStorage.setItem(
            'caOppAgentHist:005TEST:' + GOLD,
            JSON.stringify({
                conversations: [
                    { id: 'c1', title: '골드 견적', sessionId: 's', createdAt: 1, updatedAt: 2, messages: [{ role: 'user', text: '견적' }] }
                ]
            })
        );
        const el = mount();
        historyButton(el).click();
        await flush();

        const m = modal(el);
        expect(m.view).toBe('list');
        expect(m.conversations).toHaveLength(1);
        expect(m.opportunityName).toContain('골드');
    });
});

describe('c-opportunity-agent-chat — history & persistence', () => {
    async function seedTwoConversations(el) {
        sendMessage
            .mockResolvedValueOnce({ sessionId: 's1', reply: 'A1', sessionRestarted: false })
            .mockResolvedValueOnce({ sessionId: 's2', reply: 'A2', sessionRestarted: false });
        typeCompact(el, '첫 번째 질문입니다');
        askButton(el).click();
        await flush();
        await flush();
        await flush();
        // new question from compact -> new conversation
        typeCompact(el, '두 번째 질문입니다');
        askButton(el).click();
        await flush();
        await flush();
        await flush();
    }

    it('keeps multiple conversations for the same Opportunity', async () => {
        const el = mount();
        await seedTwoConversations(el);

        el.shadowRoot.querySelector('c-opportunity-agent-chat-modal').dispatchEvent(new CustomEvent('back'));
        await flush();
        const m = modal(el);
        expect(m.view).toBe('list');
        expect(m.conversations.length).toBe(2);
        const titles = m.conversations.map((c) => c.title);
        expect(titles).toContain('첫 번째 질문입니다');
        expect(titles).toContain('두 번째 질문입니다');
    });

    it('"+ 새 대화" preserves older conversations and ends the previous session', async () => {
        const el = mount();
        await seedTwoConversations(el);
        endConversation.mockResolvedValue(undefined);

        modal(el).dispatchEvent(new CustomEvent('newconversation'));
        await flush();

        expect(endConversation).toHaveBeenCalledWith({ sessionId: 's2' });
        // 2 old + 1 fresh empty
        expect(modal(el).conversations.length).toBe(3);
        expect(modal(el).activeConversation.messages.length).toBe(0);
    });

    it('persists to localStorage and restores multiple conversations after reload', async () => {
        const el = mount();
        await seedTwoConversations(el);
        const stored = JSON.parse(window.localStorage.getItem('caOppAgentHist:005TEST:' + GOLD));
        expect(stored.conversations.length).toBe(2);

        document.body.removeChild(el);
        const el2 = mount();
        el2.shadowRoot.querySelector('.oac-history').click(); // open history
        await flush();
        expect(el2.shadowRoot.querySelector('c-opportunity-agent-chat-modal').conversations.length).toBe(2);
    });

    it('never persists a token / cookie / trace', async () => {
        const el = mount();
        sendMessage.mockResolvedValue({ sessionId: 'sess-abc', reply: 'ok', sessionRestarted: false });
        typeCompact(el, 'hello');
        askButton(el).click();
        await flush();
        await flush();
        await flush();

        const raw = window.localStorage.getItem('caOppAgentHist:005TEST:' + GOLD);
        expect(raw).not.toMatch(/access_token|Bearer|Cookie|sid=|eyJ/i);
        const parsed = JSON.parse(raw);
        const keys = Object.keys(parsed.conversations[0]);
        expect(keys.sort()).toEqual(['createdAt', 'id', 'messages', 'sessionId', 'title', 'updatedAt']);
    });

    it('isolates history by Opportunity recordId', async () => {
        const elGold = mount(GOLD);
        sendMessage.mockResolvedValue({ sessionId: 's', reply: 'r', sessionRestarted: false });
        typeCompact(elGold, '골드 질문');
        askButton(elGold).click();
        await flush();
        await flush();
        await flush();
        document.body.removeChild(elGold);

        const elSamsung = mount(SAMSUNG);
        elSamsung.shadowRoot.querySelector('.oac-history').click();
        await flush();
        expect(elSamsung.shadowRoot.querySelector('c-opportunity-agent-chat-modal').conversations.length).toBe(0);
    });
});

describe('c-opportunity-agent-chat — detail follow-up', () => {
    it('follow-up from the modal reuses the conversation sessionId', async () => {
        sendMessage
            .mockResolvedValueOnce({ sessionId: 'sess-1', reply: 'A1', sessionRestarted: false })
            .mockResolvedValueOnce({ sessionId: 'sess-1', reply: 'A2', sessionRestarted: false });
        const el = mount();
        typeCompact(el, '이 딜 상태 어때?');
        askButton(el).click();
        await flush();
        await flush();
        await flush();

        modal(el).dispatchEvent(new CustomEvent('send', { detail: { text: '그중 가장 걱정되는 건?' } }));
        await flush();
        await flush();
        await flush();

        expect(sendMessage).toHaveBeenLastCalledWith({
            opportunityId: GOLD,
            sessionId: 'sess-1',
            message: '그중 가장 걱정되는 건?'
        });
        const roles = modal(el).activeConversation.messages.map((m) => m.role);
        expect(roles).toEqual(['user', 'agent', 'user', 'agent']);
    });

    it('surfaces a restart notice when the server session expired', async () => {
        sendMessage.mockResolvedValue({ sessionId: 'sess-new', reply: '이어서 답변', sessionRestarted: true });
        const el = mount();
        typeCompact(el, '계속');
        askButton(el).click();
        await flush();
        await flush();
        await flush();

        const texts = modal(el).activeConversation.messages.map((m) => m.text);
        expect(texts.some((t) => t.includes('새 세션에서 이어갑니다'))).toBe(true);
    });

    it('renders a transport error inline without an agent bubble', async () => {
        sendMessage.mockRejectedValue({ body: { message: '접근 권한이 없습니다.' } });
        const el = mount();
        typeCompact(el, 'x');
        askButton(el).click();
        await flush();
        await flush();
        await flush();

        const msgs = modal(el).activeConversation.messages;
        expect(msgs.map((m) => m.role)).toEqual(['user', 'error']);
        expect(msgs[1].text).toContain('접근 권한이 없습니다.');
    });

    it('rejects an empty question (send marked disabled, no call)', async () => {
        const el = mount();
        typeCompact(el, '   ');
        await flush();
        expect(askButton(el).getAttribute('aria-disabled')).toBe('true');
        expect(askButton(el).classList.contains('oac-send_off')).toBe(true);
        askButton(el).click();
        await flush();
        expect(sendMessage).not.toHaveBeenCalled();
    });
});

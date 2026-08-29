import { createElement } from 'lwc';
import OpportunityAgentChat from 'c/opportunityAgentChat';
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

const RECORD_ID = '006bm00000VXKvlAAH';

function mount() {
    const el = createElement('c-opportunity-agent-chat', { is: OpportunityAgentChat });
    el.recordId = RECORD_ID;
    document.body.appendChild(el);
    return el;
}

function setTextarea(el, text) {
    const ta = el.shadowRoot.querySelector('lightning-textarea');
    ta.value = text;
    ta.dispatchEvent(new CustomEvent('change'));
    return ta;
}

const flush = () => Promise.resolve();

afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
    window.sessionStorage.clear();
});

describe('c-opportunity-agent-chat', () => {
    it('renders an empty state before any message', () => {
        const el = mount();
        expect(el.shadowRoot.querySelector('lightning-card').title).toBe('Opportunity Agent');
        expect(el.shadowRoot.textContent).toContain('이 딜 상태 어때?');
    });

    it('sends the first turn with the current recordId and renders both messages', async () => {
        sendMessage.mockResolvedValue({ sessionId: 'sess-1', reply: '딜은 협상 단계입니다.', sessionRestarted: false });
        const el = mount();

        setTextarea(el, '이 딜 상태 어때?');
        el.shadowRoot.querySelector('lightning-button').click();
        await flush();
        await flush();

        expect(sendMessage).toHaveBeenCalledWith({
            opportunityId: RECORD_ID,
            sessionId: null,
            message: '이 딜 상태 어때?'
        });
        const texts = [...el.shadowRoot.querySelectorAll('.msg lightning-formatted-text')].map((n) => n.value);
        expect(texts).toEqual(['이 딜 상태 어때?', '딜은 협상 단계입니다.']);
    });

    it('keeps multi-turn order and reuses the session id', async () => {
        sendMessage
            .mockResolvedValueOnce({ sessionId: 'sess-1', reply: 'A1', sessionRestarted: false })
            .mockResolvedValueOnce({ sessionId: 'sess-1', reply: 'A2', sessionRestarted: false });
        const el = mount();

        setTextarea(el, 'Q1');
        el.shadowRoot.querySelector('lightning-button').click();
        await flush();
        await flush();

        setTextarea(el, 'Q2');
        el.shadowRoot.querySelector('lightning-button').click();
        await flush();
        await flush();

        expect(sendMessage).toHaveBeenLastCalledWith({
            opportunityId: RECORD_ID,
            sessionId: 'sess-1',
            message: 'Q2'
        });
        const texts = [...el.shadowRoot.querySelectorAll('.msg lightning-formatted-text')].map((n) => n.value);
        expect(texts).toEqual(['Q1', 'A1', 'Q2', 'A2']);
    });

    it('shows a thinking indicator while awaiting the agent', async () => {
        let resolve;
        sendMessage.mockImplementation(() => new Promise((r) => (resolve = r)));
        const el = mount();

        setTextarea(el, '느린 질문');
        el.shadowRoot.querySelector('lightning-button').click();
        await flush();

        expect(el.shadowRoot.querySelector('lightning-spinner')).not.toBeNull();

        resolve({ sessionId: 's', reply: '완료', sessionRestarted: false });
        await flush();
        await flush();
        expect(el.shadowRoot.querySelector('lightning-spinner')).toBeNull();
    });

    it('renders a transport error and does not add an agent bubble', async () => {
        sendMessage.mockRejectedValue({ body: { message: '접근 권한이 없습니다.' } });
        const el = mount();

        setTextarea(el, 'x');
        el.shadowRoot.querySelector('lightning-button').click();
        await flush();
        await flush();

        expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain('접근 권한이 없습니다.');
        const texts = [...el.shadowRoot.querySelectorAll('.msg lightning-formatted-text')].map((n) => n.value);
        expect(texts).toEqual(['x']);
    });

    it('rejects an empty message (send button disabled, no call)', async () => {
        const el = mount();
        setTextarea(el, '   ');
        const btn = el.shadowRoot.querySelector('lightning-button');
        expect(btn.disabled).toBe(true);
        btn.click();
        await flush();
        expect(sendMessage).not.toHaveBeenCalled();
    });

    it('reset clears the transcript and ends the server session', async () => {
        sendMessage.mockResolvedValue({ sessionId: 'sess-1', reply: 'hi', sessionRestarted: false });
        endConversation.mockResolvedValue(undefined);
        const el = mount();

        setTextarea(el, 'hello');
        el.shadowRoot.querySelector('lightning-button').click();
        await flush();
        await flush();

        el.shadowRoot.querySelectorAll('lightning-button-icon')[0].click();
        await flush();

        expect(endConversation).toHaveBeenCalledWith({ sessionId: 'sess-1' });
        expect(el.shadowRoot.querySelectorAll('.msg lightning-formatted-text').length).toBe(0);
    });

    it('restores a prior conversation from sessionStorage on reconnect', async () => {
        window.sessionStorage.setItem(
            'caOppAgentChat:005TEST:006bm00000VXKvlAAH',
            JSON.stringify({
                sessionId: 'sess-prev',
                messages: [
                    { role: 'user', text: '이전 질문' },
                    { role: 'agent', text: '이전 답변' }
                ]
            })
        );
        const el = mount();
        await flush();

        const texts = [...el.shadowRoot.querySelectorAll('.msg lightning-formatted-text')].map((n) => n.value);
        expect(texts).toEqual(['이전 질문', '이전 답변']);
    });

    it('surfaces a notice when the server restarted an expired session', async () => {
        sendMessage.mockResolvedValue({ sessionId: 'sess-new', reply: '이어서 답변', sessionRestarted: true });
        const el = mount();

        setTextarea(el, '계속');
        el.shadowRoot.querySelector('lightning-button').click();
        await flush();
        await flush();

        const texts = [...el.shadowRoot.querySelectorAll('.msg lightning-formatted-text')].map((n) => n.value);
        expect(texts.some((t) => t.includes('새 세션에서 이어갑니다'))).toBe(true);
        expect(texts).toContain('이어서 답변');
    });
});

import { LightningElement, api } from 'lwc';
import sendMessage from '@salesforce/apex/OpportunityAgentChatController.sendMessage';
import endConversation from '@salesforce/apex/OpportunityAgentChatController.endConversation';
import USER_ID from '@salesforce/user/Id';

const STORE_PREFIX = 'caOppAgentChat';
const MAX_STORED_MESSAGES = 40;

export default class OpportunityAgentChat extends LightningElement {
    @api recordId;

    messages = [];
    sessionId;
    draft = '';
    status = 'idle'; // idle | thinking | error
    errorText;
    _seq = 0;
    _restored = false;

    // --- lifecycle -----------------------------------------------------

    connectedCallback() {
        this.restore();
    }

    // --- derived state ------------------------------------------------

    get storeKey() {
        return `${STORE_PREFIX}:${USER_ID || 'anon'}:${this.recordId || 'none'}`;
    }

    get isThinking() {
        return this.status === 'thinking';
    }

    get hasError() {
        return this.status === 'error';
    }

    get hasMessages() {
        return this.messages.length > 0;
    }

    get statusLabel() {
        if (this.status === 'thinking') return '응답 생성 중…';
        if (this.status === 'error') return '오류';
        return this.sessionId ? '연결됨' : '준비됨';
    }

    get sendDisabled() {
        return this.status === 'thinking' || this.draft.trim().length === 0;
    }

    get inputDisabled() {
        return this.status === 'thinking';
    }

    get renderedMessages() {
        return this.messages.map((m) => ({
            ...m,
            cssClass:
                m.role === 'user'
                    ? 'msg msg_user slds-var-p-around_x-small slds-var-m-bottom_x-small'
                    : 'msg msg_agent slds-var-p-around_x-small slds-var-m-bottom_x-small'
        }));
    }

    // --- events ------------------------------------------------------

    handleInput(event) {
        this.draft = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.handleSend();
        }
    }

    async handleSend() {
        const text = this.draft.trim();
        if (!text || this.status === 'thinking') {
            return;
        }
        this.pushMessage('user', text);
        this.draft = '';
        this.status = 'thinking';
        this.errorText = undefined;

        try {
            const turn = await sendMessage({
                opportunityId: this.recordId,
                sessionId: this.sessionId || null,
                message: text
            });
            this.sessionId = turn.sessionId;
            if (turn.sessionRestarted) {
                this.pushMessage('agent', '(이전 대화 세션이 만료되어 새 세션에서 이어갑니다.)');
            }
            this.pushMessage('agent', turn.reply);
            this.status = 'idle';
        } catch (e) {
            this.status = 'error';
            this.errorText =
                (e && e.body && e.body.message) ||
                (e && e.message) ||
                'Agent 응답을 가져오지 못했습니다.';
        }
        this.persist();
        this.scrollToLatest();
    }

    async handleReset() {
        const old = this.sessionId;
        this.messages = [];
        this.sessionId = undefined;
        this.status = 'idle';
        this.errorText = undefined;
        this.draft = '';
        this.persist();
        if (old) {
            try {
                await endConversation({ sessionId: old });
            } catch (e) {
                // best effort
            }
        }
    }

    // --- helpers ---------------------------------------------------

    pushMessage(role, text) {
        this._seq += 1;
        this.messages = [
            ...this.messages,
            { key: `m${this._seq}`, role, text: text || '' }
        ];
        this.scrollToLatest();
    }

    scrollToLatest() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        Promise.resolve().then(() => {
            const box = this.template.querySelector('.transcript');
            if (box) {
                box.scrollTop = box.scrollHeight;
            }
        });
    }

    persist() {
        try {
            const payload = JSON.stringify({
                sessionId: this.sessionId || null,
                messages: this.messages.slice(-MAX_STORED_MESSAGES)
            });
            window.sessionStorage.setItem(this.storeKey, payload);
        } catch (e) {
            // storage unavailable / quota — non-fatal, conversation stays in memory
        }
    }

    restore() {
        if (this._restored) {
            return;
        }
        this._restored = true;
        try {
            const raw = window.sessionStorage.getItem(this.storeKey);
            if (!raw) {
                return;
            }
            const saved = JSON.parse(raw);
            if (saved && Array.isArray(saved.messages)) {
                this.messages = saved.messages.map((m, i) => ({
                    key: `r${i}`,
                    role: m.role === 'user' ? 'user' : 'agent',
                    text: m.text || ''
                }));
                this._seq = this.messages.length;
                this.sessionId = saved.sessionId || undefined;
            }
        } catch (e) {
            // ignore corrupt storage
        }
    }
}

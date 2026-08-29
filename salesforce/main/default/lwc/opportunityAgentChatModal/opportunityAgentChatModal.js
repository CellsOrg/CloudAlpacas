import { LightningElement, api } from 'lwc';

const DAY_FMT = { month: 'long', day: 'numeric' };
const TIME_FMT = { hour: '2-digit', minute: '2-digit', hour12: false };
const PREVIEW_MAX = 60;

/**
 * Wide Opportunity Agent workspace (SLDS modal over the Opportunity page).
 * Presentational only — all transport, history and state live in the parent
 * c-opportunity-agent-chat. Emits: close, back, openconversation, newconversation,
 * search, send.
 */
export default class OpportunityAgentChatModal extends LightningElement {
    @api opportunityName;
    @api view = 'list'; // 'list' | 'detail'
    @api conversations = [];
    @api activeConversation;
    @api searchTerm = '';
    @api busy = false;

    followUpDraft = '';
    _focused = false;

    renderedCallback() {
        if (this._focused) {
            return;
        }
        this._focused = true;
        try {
            const target =
                this.template.querySelector('.oac-initial-focus') ||
                this.template.querySelector('lightning-textarea, button, [tabindex]');
            if (target && typeof target.focus === 'function') {
                target.focus();
            }
        } catch (e) {
            // focus is a convenience, never fatal
        }
    }

    // --- view flags ------------------------------------------------

    get isListView() {
        return this.view !== 'detail';
    }

    get isDetailView() {
        return this.view === 'detail';
    }

    get headingId() {
        return 'oac-modal-heading';
    }

    // --- list view ------------------------------------------------

    get filteredConversations() {
        const term = (this.searchTerm || '').trim().toLowerCase();
        const list = this.conversations || [];
        if (!term) {
            return list;
        }
        return list.filter((c) => {
            if ((c.title || '').toLowerCase().includes(term)) {
                return true;
            }
            return (c.messages || []).some((m) => (m.text || '').toLowerCase().includes(term));
        });
    }

    get hasConversations() {
        return this.filteredConversations.length > 0;
    }

    get groupedConversations() {
        const groups = [];
        const byLabel = new Map();
        for (const c of this.filteredConversations) {
            const label = this.formatDay(c.updatedAt);
            if (!byLabel.has(label)) {
                const group = { key: label, label, items: [] };
                byLabel.set(label, group);
                groups.push(group);
            }
            byLabel.get(label).items.push(this.toCard(c));
        }
        return groups;
    }

    toCard(c) {
        const visible = (c.messages || []).filter((m) => m.role === 'user' || m.role === 'agent');
        const last = visible.length ? visible[visible.length - 1] : null;
        let preview = last ? last.text.replace(/\s+/g, ' ').trim() : '아직 메시지가 없습니다.';
        if (preview.length > PREVIEW_MAX) {
            preview = `${preview.slice(0, PREVIEW_MAX)}…`;
        }
        return {
            id: c.id,
            title: c.title || '새 대화',
            preview: last ? `마지막 대화: "${preview}"` : preview,
            time: this.formatTime(c.updatedAt),
            count: `메시지 ${visible.length}개`
        };
    }

    // --- detail view --------------------------------------------

    get detailTitle() {
        return (this.activeConversation && this.activeConversation.title) || '새 대화';
    }

    get detailDate() {
        return this.activeConversation ? this.formatDateFull(this.activeConversation.createdAt) : '';
    }

    get detailMessages() {
        const msgs = (this.activeConversation && this.activeConversation.messages) || [];
        return msgs.map((m) => ({
            key: m.key,
            text: m.text,
            isUser: m.role === 'user',
            isAgent: m.role === 'agent',
            isMeta: m.role === 'system' || m.role === 'error',
            roleLabel: m.role === 'user' ? '나' : 'Opportunity Agent',
            rowClass:
                m.role === 'user'
                    ? 'oac-msg oac-msg_user slds-var-m-bottom_small'
                    : m.role === 'agent'
                    ? 'oac-msg oac-msg_agent slds-var-m-bottom_small'
                    : 'oac-msg oac-msg_meta slds-var-m-bottom_small slds-text-color_weak',
            metaClass: m.role === 'error' ? 'slds-text-color_error' : 'slds-text-color_weak'
        }));
    }

    get hasDetailMessages() {
        return this.detailMessages.length > 0;
    }

    get followUpDisabled() {
        return this.busy || this.followUpDraft.trim().length === 0;
    }

    // --- events -------------------------------------------------

    close() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    back() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    newConversation() {
        this.followUpDraft = '';
        this.dispatchEvent(new CustomEvent('newconversation'));
    }

    openConversation(event) {
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('openconversation', { detail: { id } }));
    }

    handleSearch(event) {
        this.dispatchEvent(new CustomEvent('search', { detail: { value: event.target.value } }));
    }

    handleFollowUpInput(event) {
        this.followUpDraft = event.target.value;
    }

    handleFollowUpKey(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.sendFollowUp();
        }
    }

    sendFollowUp() {
        const text = this.followUpDraft.trim();
        if (!text || this.busy) {
            return;
        }
        this.followUpDraft = '';
        this.dispatchEvent(new CustomEvent('send', { detail: { text } }));
    }

    handleKeyDown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.close();
        }
    }

    handleBackdrop() {
        this.close();
    }

    stop(event) {
        event.stopPropagation();
    }

    // --- date helpers ------------------------------------------

    formatDay(ts) {
        try {
            return new Date(Number(ts)).toLocaleDateString('ko-KR', DAY_FMT);
        } catch (e) {
            return '';
        }
    }

    formatTime(ts) {
        try {
            return new Date(Number(ts)).toLocaleTimeString('ko-KR', TIME_FMT);
        } catch (e) {
            return '';
        }
    }

    formatDateFull(ts) {
        try {
            const d = new Date(Number(ts));
            return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(
                d.getDate()
            ).padStart(2, '0')}`;
        } catch (e) {
            return '';
        }
    }
}

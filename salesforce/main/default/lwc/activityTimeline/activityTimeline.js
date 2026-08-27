import { LightningElement, api, wire } from 'lwc';
import getActivityTimeline from '@salesforce/apex/ActivityIntelligenceController.getActivityTimeline';
import getActivityContent from '@salesforce/apex/ActivityIntelligenceController.getActivityContent';

const REACTION_BADGE_CLASS = {
    'Very Positive': 'slds-badge slds-theme_success',
    Positive: 'slds-badge slds-theme_success',
    Neutral: 'slds-badge slds-theme_warning',
    Negative: 'slds-badge slds-theme_error',
    'Very Negative': 'slds-badge slds-theme_error',
    'Not Determined': 'slds-badge slds-badge_inverse'
};

const DIRECTION_BADGE_CLASS = {
    Positive: 'slds-badge slds-theme_success',
    Neutral: 'slds-badge slds-theme_warning',
    Negative: 'slds-badge slds-theme_error'
};

const TYPE_ICON = {
    Call: 'standard:call',
    Email: 'standard:email',
    'Online Meeting': 'standard:event',
    'Offline Meeting': 'standard:event',
    Meeting: 'standard:event',
    Task: 'standard:task'
};

const MAX_COLLAPSED_SIGNALS = 4;

export default class ActivityTimeline extends LightningElement {
    @api recordId;

    items = [];
    error;
    expandedId;
    contentById = {};
    loadingContentId;

    @wire(getActivityTimeline, { opportunityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.items = data.map((row) => this.toDisplay(row));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.items = [];
        }
    }

    toDisplay(row) {
        const collapsedSignals = (row.signals || []).slice(0, MAX_COLLAPSED_SIGNALS).map((s) => this.toSignal(s));
        const extraSignals = Math.max(0, (row.signals || []).length - MAX_COLLAPSED_SIGNALS);
        return {
            key: row.activityId,
            activityId: row.activityId,
            activityType: row.activityType,
            sourceObject: row.sourceObject,
            iconName: TYPE_ICON[row.activityType] || 'standard:task',
            timestampDisplay: this.formatDateTime(row.timestamp, row.sourceObject === 'Task'),
            subject: row.subject || '(제목 없음)',
            contactName: row.contactName,
            hasContact: !!row.contactName,
            ownerName: row.ownerName,
            status: row.status,
            meetingType: row.meetingType,
            hasIntelligence: row.hasIntelligence,
            summary: row.summary,
            customerReaction: row.customerReaction,
            hasReaction: !!row.customerReaction,
            reactionBadgeClass: REACTION_BADGE_CLASS[row.customerReaction] || 'slds-badge slds-badge_inverse',
            keyDecision: row.keyDecision,
            hasKeyDecision: !!row.keyDecision,
            concernsObjections: row.concernsObjections,
            hasConcerns: !!row.concernsObjections,
            followUp: row.followUp,
            hasFollowUp: !!row.followUp,
            collapsedSignals,
            hasCollapsedSignals: collapsedSignals.length > 0,
            extraSignalLabel: extraSignals > 0 ? `+${extraSignals}` : '',
            hasExtraSignals: extraSignals > 0,
            allSignals: (row.signals || []).map((s) => this.toSignal(s)),
            contentType: row.contentType
        };
    }

    toSignal(s) {
        return {
            key: s.id,
            category: s.category,
            type: s.type,
            hasType: !!s.type,
            direction: s.direction,
            directionBadgeClass: DIRECTION_BADGE_CLASS[s.direction] || 'slds-badge',
            confidence: s.confidence,
            evidence: s.evidence,
            hasEvidence: !!s.evidence
        };
    }

    get rows() {
        return this.items.map((item) => {
            const isExpanded = item.activityId === this.expandedId;
            const content = this.contentById[item.activityId];
            return {
                ...item,
                isExpanded,
                itemClass: isExpanded
                    ? 'activity-timeline__item activity-timeline__item_expanded slds-p-around_small'
                    : 'activity-timeline__item slds-p-around_small',
                toggleIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                toggleLabel: isExpanded ? '접기' : '상세보기',
                showDetail: isExpanded,
                loadingContent: isExpanded && this.loadingContentId === item.activityId,
                content: isExpanded ? content : undefined,
                hasContent: isExpanded && content && content.hasContent,
                noContent: isExpanded && content && !content.hasContent,
                contentMeetingNotes:
                    isExpanded && content && content.meetingNotes
                        ? content.meetingNotes.map((n, i) => ({ key: `${item.activityId}-note-${i}`, ...n }))
                        : [],
                contentEndDisplay:
                    isExpanded && content && content.endTimestamp
                        ? this.formatDateTime(content.endTimestamp, false)
                        : '',
                contentHasEmailMeta: isExpanded && content && (content.emailFrom || content.emailTo)
            };
        });
    }

    get hasItems() {
        return this.items && this.items.length > 0;
    }

    get hasError() {
        return !!this.error;
    }

    handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        if (this.expandedId === id) {
            this.expandedId = undefined;
            return;
        }
        this.expandedId = id;
        if (!this.contentById[id]) {
            this.loadContent(id);
        }
    }

    async loadContent(id) {
        this.loadingContentId = id;
        try {
            const result = await getActivityContent({ activityId: id });
            this.contentById = { ...this.contentById, [id]: result };
        } catch (e) {
            this.contentById = {
                ...this.contentById,
                [id]: { hasContent: false, contentType: 'Activity Notes', body: null }
            };
        } finally {
            this.loadingContentId = undefined;
        }
    }

    formatDateTime(value, dateOnly) {
        if (!value) {
            return '';
        }
        const d = new Date(value);
        if (dateOnly) {
            return d.toLocaleDateString('ko-KR', { year: 'numeric', month: '2-digit', day: '2-digit' });
        }
        return d.toLocaleString('ko-KR', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        });
    }
}

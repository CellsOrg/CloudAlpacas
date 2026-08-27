import { LightningElement, api, wire } from 'lwc';
import getIntelligence from '@salesforce/apex/ActivityIntelligenceController.getIntelligence';

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

export default class ActivityIntelligence extends LightningElement {
    @api recordId;

    items = [];
    error;

    @wire(getIntelligence, { opportunityId: '$recordId' })
    wiredIntelligence({ data, error }) {
        if (data) {
            this.items = data.map((item) => this.toDisplayItem(item));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.items = [];
        }
    }

    toDisplayItem(item) {
        return {
            key: item.id,
            sourceType: item.sourceType,
            summary: item.summary,
            customerReaction: item.customerReaction,
            reactionBadgeClass: REACTION_BADGE_CLASS[item.customerReaction] || 'slds-badge slds-badge_inverse',
            hasKeyDecision: !!item.keyDecision,
            keyDecision: item.keyDecision,
            hasConcerns: !!item.concernsObjections,
            concernsObjections: item.concernsObjections,
            hasFollowUp: !!item.followUp,
            followUp: item.followUp,
            originFound: item.originFound,
            originSubject: item.originSubject,
            originDateDisplay: this.formatDate(item.originFound ? item.originDatetime : item.createdDate),
            originDetail: item.originDetail,
            hasOriginDetail: !!item.originDetail,
            hasSignals: !!(item.signals && item.signals.length),
            signals: (item.signals || []).map((signal) => this.toSignalDisplay(signal))
        };
    }

    toSignalDisplay(signal) {
        return {
            key: signal.id,
            category: signal.category,
            type: signal.type,
            hasType: !!signal.type,
            direction: signal.direction,
            directionBadgeClass: DIRECTION_BADGE_CLASS[signal.direction] || 'slds-badge',
            confidence: signal.confidence,
            hasEvidence: !!signal.evidence,
            evidence: signal.evidence
        };
    }

    formatDate(value) {
        if (!value) {
            return '';
        }
        const parsed = new Date(value);
        return parsed.toLocaleDateString('ko-KR', { year: 'numeric', month: '2-digit', day: '2-digit' });
    }

    get hasError() {
        return !!this.error;
    }

    get hasItems() {
        return !!(this.items && this.items.length);
    }
}

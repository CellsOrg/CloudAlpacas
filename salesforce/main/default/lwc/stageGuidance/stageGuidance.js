import { LightningElement, api, wire } from 'lwc';
import getContext from '@salesforce/apex/StageGuidanceController.getContext';

const STAGES = {
    Qualification: { title: 'Qualification Brief', subtitle: '초기 검토 가이드' },
    Discovery: { title: 'Discovery Brief', subtitle: '발견 가이드' },
    'Proposal/Quote': { title: 'Recommended Proposal', subtitle: '제안 가이드' },
    Negotiation: { title: 'Negotiation Brief', subtitle: '협상 가이드' },
    'Closed Won': { title: 'Deal Summary', subtitle: '수주 요약' },
    'Closed Lost': { title: 'Deal Summary', subtitle: '실주 요약' }
};

export default class StageGuidance extends LightningElement {
    @api recordId;
    context;
    error;

    @wire(getContext, { opportunityId: '$recordId' })
    wiredContext({ data, error }) {
        this.context = data;
        this.error = error;
    }

    get hasContext() {
        return !!this.context;
    }

    get stageConfig() {
        return STAGES[this.context?.stageName] || { title: 'Stage Guidance', subtitle: '단계 가이드' };
    }

    get title() { return this.stageConfig.title; }
    get subtitle() { return this.stageConfig.subtitle; }
    get isKnownStage() { return !!STAGES[this.context?.stageName]; }

    get facts() {
        const c = this.context || {};
        const items = [];
        this.add(items, '고객', c.accountName);
        this.add(items, '금액', c.amount, 'currency');
        this.add(items, '종료 예정일', c.closeDate, 'date');
        this.add(items, 'Partner Tier', c.partnerTier);
        this.add(items, 'Primary Contact', c.primaryContactName);
        this.add(items, '예산 상태', c.clientBudgetStatus);
        this.add(items, '최근 Activity', c.lastActivityDate, 'date');
        this.add(items, '현재 Quote', this.quoteFact(c));
        if (c.stageName === 'Closed Lost') this.add(items, 'Loss reason', c.reasonLost);
        return items.slice(0, 5);
    }

    get needs() {
        const c = this.context || {};
        const needs = [];
        if (!c.primaryContactName) needs.push('Primary Contact 확인 필요');
        if (!c.clientBudgetStatus) needs.push('고객 예산 상태 확인 필요');
        if (!c.decisionMakerAccessible) needs.push('의사결정권자 접근 가능 여부 확인 필요');
        if (!c.interestLevel) needs.push('관심도 확인 필요');
        if ((c.stageName === 'Proposal/Quote' || c.stageName === 'Negotiation') && !c.quoteCount) needs.push('Quote 확인 필요');
        if (c.stageName === 'Closed Lost' && !c.reasonLost) needs.push('Loss reason 확인 필요');
        return needs.slice(0, 4);
    }

    get hasNeeds() { return this.needs.length > 0; }

    get action() {
        const c = this.context || {};
        if (c.nextActivitySubject) return `${c.nextActivitySubject}${c.nextActivityDate ? ` (${c.nextActivityDate})` : ''}`;
        if (c.nextStep) return c.nextStep;
        if (c.stageName === 'Closed Lost') return '저장된 Loss reason을 검토하고 관계 관리 후속 조치를 확인하세요.';
        if (c.stageName === 'Closed Won') return '저장된 Quote와 후속 활동을 확인하세요.';
        return '다음 활동과 확인이 필요한 정보를 Opportunity Agent와 검토하세요.';
    }

    get hasFacts() { return this.facts.length > 0; }
    get emptyMessage() { return this.isKnownStage ? '표시할 저장된 정보가 없습니다. 확인 필요 항목을 먼저 점검하세요.' : '지원하지 않는 Stage입니다. 저장된 Opportunity 정보를 확인하세요.'; }

    quoteFact(c) {
        if (!c.quoteCount) return null;
        const status = c.hasSyncedQuote ? c.syncedQuoteStatus : c.latestQuoteStatus;
        return `${c.quoteCount}건${status ? ` · ${status}` : ''}`;
    }

    add(items, label, value, type) {
        if (value !== null && value !== undefined && value !== '') {
            items.push({ label, value, type, isCurrency: type === 'currency', isDate: type === 'date' });
        }
    }
}

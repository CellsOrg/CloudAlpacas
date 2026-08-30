import { LightningElement, api, wire } from 'lwc';
import getContext from '@salesforce/apex/StageGuidanceController.getContext';
import getRecommendation from '@salesforce/apex/StageGuidanceController.getRecommendation';
import getNegotiationContext from '@salesforce/apex/NegotiationContextController.getContext';

const STAGES = {
    Qualification: { title: 'Qualification Brief' },
    Discovery: { title: 'Discovery Brief' },
    'Proposal/Quote': { title: 'Proposal Brief' },
    Negotiation: { title: 'Negotiation Brief' },
    'Closed Won': { title: 'Closed Won Brief' },
    'Closed Lost': { title: 'Closed Lost Brief' }
};

const SECTION_INFO = {
    'Qualification 판단': '현재 Opportunity 사실을 기준으로 한 Qualification 판단',
    '판단 근거': '판단에 사용한 저장된 Opportunity 및 활동 근거',
    '긍정 신호': '현재 기록에서 확인된 진행 가능성 신호',
    '위험 신호': '추가 확인 또는 관리가 필요한 위험 신호',
    '발견된 고객 니즈': '고객 기록에서 확인된 니즈와 제약',
    'AI 해석': '확인된 고객 니즈를 바탕으로 한 AI 해석',
    '추천 패키지': '현재 Quote 및 고객 요구사항을 바탕으로 한 제안 방향',
    '추천 구성': '현재 제안에 포함하거나 확인할 구성',
    '추천 견적': '현재 Quote 사실에 기반한 견적 검토 방향',
    '추천 이유': '추천의 근거와 확인할 사항',
    '추천 협상 방향': '현재 협상 사실을 기반으로 생성한 추천 전략',
    '유지 권장 항목': '협상에서 유지하는 것이 권장되는 현재 조건',
    '조정 검토 가능 항목': '근거 확인 후 조정을 검토할 수 있는 항목',
    '설득 전략 / 협상 시 주의': '협상 시 사용할 설득 방향과 주의할 점',
    '계약 결과': '저장된 계약 및 Quote 사실 요약',
    '성공 요인': '기록에서 확인된 수주 요인',
    '후속 관리': '계약 이후 확인하거나 진행할 후속 관리',
    'Deal 결과': '저장된 실주 결과 요약',
    '실패 요인': '기록에서 확인된 실주 요인',
    '향후 재접촉 조건': '재접촉 전에 확인할 조건과 시점'
};

const FULL_WIDTH_SECTIONS = new Set(['Qualification 판단', '위험 신호', '계약 결과', 'Deal 결과']);
const HIDDEN_SECTIONS = new Set(['확인 필요', '현재 제안', '고객 요구/제약']);

export default class StageGuidance extends LightningElement {
    @api recordId;
    context;
    error;
    recommendation;
    negotiationContext;
    loading = false;
    requestedFor;

    @wire(getContext, { opportunityId: '$recordId' })
    wiredContext({ data, error }) {
        this.context = data;
        this.error = error;
        if (data && data.stageName && this.requestedFor !== `${this.recordId}:${data.stageName}`) this.loadRecommendation();
    }

    @wire(getNegotiationContext, { opportunityId: '$negotiationRecordId' })
    wiredNegotiationContext({ data }) {
        this.negotiationContext = data;
    }

    get hasContext() {
        return !!this.context;
    }
    get hasRecommendation() { return !!this.recommendation; }
    get showFallbackFacts() { return !this.loading && !this.hasRecommendation; }
    get isNegotiation() { return this.context?.stageName === 'Negotiation'; }
    get negotiationRecordId() { return this.isNegotiation ? this.recordId : undefined; }
    get hasNegotiationContext() { return !!this.negotiationContext; }

    get recommendationSections() {
        const sections = [];
        let current;
        (this.recommendation || '').split('\n').forEach((raw) => {
            const line = raw.trim().replace(/^\*\*(.+?)\*\*\.?$/, '$1');
            if (!line) return;
            if (/^[^:]{1,40}:$/.test(line) || /^(현재 상황|추천|확인 필요|Recommended Next Action)$/.test(line)) {
                const title = line.replace(/:$/, '');
                if (HIDDEN_SECTIONS.has(title)) {
                    current = undefined;
                    return;
                }
                current = {
                    title,
                    lines: [],
                    key: `s-${sections.length}`,
                    className: `brief-section${FULL_WIDTH_SECTIONS.has(title) ? ' brief-section_emphasis' : ''}`,
                    infoText: SECTION_INFO[title],
                    infoLabel: `${title} 안내`
                };
                sections.push(current);
            } else {
                if (/(감사드립니다|추가 확인사항|알려주시기 바랍니다)/.test(line)) return;
                if (!current) return;
                current.lines.push({ text: this.normalizeBullet(line.replace(/^-\s*/, '')), key: `${current.key}-${current.lines.length}` });
            }
        });
        return sections;
    }

    get negotiationMetrics() {
        const c = this.negotiationContext || {};
        const hasBudget = c.clientBudget !== null && c.clientBudget !== undefined;
        const hasQuote = c.quoteGrandTotal !== null && c.quoteGrandTotal !== undefined;
        const currency = (key, label, value) => value === null || value === undefined
            ? { key, label, value: '정보 없음' }
            : { key, label, value, isCurrency: true };
        const text = (key, label, value) => ({ key, label, value: value || '—' });
        return [
            text('quote-status', 'Quote 상태', c.quoteStatus || (c.hasQuote ? '—' : '정보 없음')),
            currency('client-budget', '고객 예산', hasBudget ? c.clientBudget : null),
            currency('quote-total', 'Quote 총액', hasQuote ? c.quoteGrandTotal : null),
            currency('budget-gap', '예산 대비 견적 차이', hasBudget && hasQuote ? c.quoteGrandTotal - c.clientBudget : null),
            text('current-discount', '현재 할인율', c.quoteDiscount === null || c.quoteDiscount === undefined ? '—' : `${c.quoteDiscount}%`),
            text('approval-limit', '승인 없이 가능한 최대 할인율', c.maxDiscountPercent === null || c.maxDiscountPercent === undefined ? '—' : `${c.maxDiscountPercent}%`),
            { key: 'expiration', label: 'Quote 유효기한', value: c.quoteExpirationDate || '—', isDate: !!c.quoteExpirationDate },
            text('discount-restriction', '할인율 변경 제한', c.lineItemDiscountUpdatable === false ? c.lineItemDiscountLockReason || '할인율 변경이 제한됩니다' : '할인율 변경 제한 없음'),
            text('recent-interaction', '최근 상호작용', c.hasInteractionIntelligence && c.interactionHistorySummary ? c.interactionHistorySummary.split('\n')[0] : '기록된 상호작용 없음')
        ];
    }

    normalizeBullet(value) {
        // Only strip a terminal full stop from short single-line guidance. IDs,
        // dates, decimals, and longer prose retain their original punctuation.
        if (value.length <= 120 && /[^0-9]\.$/.test(value)) return value.slice(0, -1);
        return value;
    }
    get errorMessage() { return this.error?.body?.message || 'AI recommendation을 생성하지 못했습니다.'; }
    async loadRecommendation() {
        this.loading = true;
        this.error = undefined;
        this.requestedFor = `${this.recordId}:${this.context.stageName}`;
        try {
            const result = await getRecommendation({ opportunityId: this.recordId });
            this.recommendation = result.recommendation;
            if (result.errorMessage) this.error = { body: { message: result.errorMessage } };
        } catch (error) { this.error = error; } finally { this.loading = false; }
    }
    retry() { this.requestedFor = undefined; this.loadRecommendation(); }
    get stageConfig() {
        return STAGES[this.context?.stageName] || { title: 'Stage Guidance', subtitle: '단계 가이드' };
    }

    get title() { return this.stageConfig.title; }
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

import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const OPPORTUNITY_FIELDS = [
    'Opportunity.StageName',
    'Opportunity.Sponsorship_Interest_Level__c',
    'Opportunity.Brand_Fan_Fit__c',
    'Opportunity.Target_Segment__c',
    'Opportunity.SDO_Sales_Primary_Contact__c',
    'Opportunity.Client_Budget_Status__c',
    'Opportunity.Target_Start_Season__c',
    'Opportunity.Decision_Maker_Accessible__c'
];

const hasValue = (value) => value !== null && value !== undefined && value !== '';

// Stage별 체크리스트 정의. 새 Stage(Discovery 등)를 추가할 땐 이 맵에 항목만
// 추가하면 되고, 아래 렌더링/진행률 계산 로직은 그대로 재사용됨.
// 정의되지 않은 Stage에서는 "체크리스트 준비 중" 상태로 표시됨.
const STAGE_CHECKLISTS = {
    Qualification: [
        {
            key: 'interestLevel',
            label: '잠재 스폰서의 관심 수준 확인',
            isComplete: (r) => hasValue(r.Sponsorship_Interest_Level__c)
        },
        {
            key: 'brandFanFit',
            label: '구단·팬과의 브랜드 적합성 평가',
            isComplete: (r) => hasValue(r.Brand_Fan_Fit__c)
        },
        {
            key: 'targetSegment',
            label: '스폰서의 주요 타깃 고객층 파악',
            isComplete: (r) => hasValue(r.Target_Segment__c)
        },
        {
            key: 'primaryContact',
            label: '실무 담당자 확보',
            isComplete: (r) => hasValue(r.SDO_Sales_Primary_Contact__c)
        },
        {
            key: 'clientBudget',
            label: '고객 측 스폰서십 예산 파악',
            // 금액(Client_Budget__c)이 아니라 Status로만 판단 — Unknown/blank만 미완료
            isComplete: (r) => r.Client_Budget_Status__c === 'Estimated' || r.Client_Budget_Status__c === 'Confirmed'
        },
        {
            key: 'targetStartSeason',
            label: '스폰서십 시작 희망 시즌 파악',
            isComplete: (r) => hasValue(r.Target_Start_Season__c)
        },
        {
            key: 'decisionMakerAccess',
            label: '의사결정권자 접근 가능 여부 파악',
            isComplete: (r) => hasValue(r.Decision_Maker_Accessible__c)
        },
        {
            key: 'customerContact',
            label: '고객과 실제 접촉 수행',
            // 완료된 Task/Event 존재 여부는 표준 UI API(getRelatedListCount)로 조회
            // 불가능함을 확인함(Activity History/Open Activities는
            // uiApiEnabledLayout=false). Activity Enhancement 단계에서 별도로
            // 다룰 예정 — V1에서는 항상 미완료로 표시하고 배지로 안내함.
            isComplete: () => false,
            pending: true
        }
    ]
};

export default class StageProgress extends LightningElement {
    @api recordId;

    record;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: OPPORTUNITY_FIELDS })
    wiredOpportunity({ data, error }) {
        if (data) {
            this.record = this.toFieldMap(data);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.record = undefined;
        }
    }

    toFieldMap(data) {
        const map = {};
        Object.keys(data.fields).forEach((apiName) => {
            map[apiName] = data.fields[apiName].value;
        });
        return map;
    }

    get stageLabel() {
        return this.record ? this.record.StageName : undefined;
    }

    get stageConfig() {
        return this.stageLabel ? STAGE_CHECKLISTS[this.stageLabel] : undefined;
    }

    get hasChecklist() {
        return !!this.stageConfig;
    }

    get isUnsupportedStage() {
        return !!this.record && !this.stageConfig;
    }

    get checklist() {
        if (!this.stageConfig || !this.record) {
            return [];
        }
        const record = this.record;
        return this.stageConfig.map((item) => {
            const complete = !item.pending && item.isComplete(record);
            return {
                ...item,
                complete,
                textClass: complete ? 'slds-text-body_regular' : 'slds-text-body_regular slds-text-color_weak'
            };
        });
    }

    get totalCount() {
        return this.checklist.length;
    }

    get completedCount() {
        return this.checklist.filter((item) => item.complete).length;
    }

    get remainingCount() {
        return this.totalCount - this.completedCount;
    }

    get hasRemaining() {
        return this.remainingCount > 0;
    }

    get progressPercentage() {
        return this.totalCount > 0 ? Math.round((this.completedCount / this.totalCount) * 100) : 0;
    }
}

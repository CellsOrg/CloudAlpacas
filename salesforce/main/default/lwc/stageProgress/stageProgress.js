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
    'Opportunity.Decision_Maker_Accessible__c',
    'Opportunity.Last_Contact_Date__c',
    'Opportunity.Customer_Needs__c',
    'Opportunity.Customer_KPI__c',
    'Opportunity.Key_Requirements__c'
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
            isComplete: (r) => hasValue(r.Client_Budget_Status__c) && r.Client_Budget_Status__c !== 'Unknown'
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
            // Last_Contact_Date__c는 Customer Contact(완료된 Call/Email/Meeting)에
            // 대해서만 Flow가 채움 — 일반 Task 완료는 반영되지 않음
            isComplete: (r) => hasValue(r.Last_Contact_Date__c)
        }
    ],
    Discovery: [
        {
            key: 'customerNeeds',
            label: 'Customer Needs 파악',
            isComplete: (r) => hasValue(r.Customer_Needs__c)
        },
        {
            key: 'targetSegment',
            label: 'Target Segment 파악',
            isComplete: (r) => hasValue(r.Target_Segment__c)
        },
        {
            key: 'customerKPI',
            label: 'Customer KPI 파악',
            isComplete: (r) => hasValue(r.Customer_KPI__c)
        },
        {
            key: 'budgetStatus',
            label: 'Budget 상태 파악',
            isComplete: (r) => hasValue(r.Client_Budget_Status__c) && r.Client_Budget_Status__c !== 'Unknown'
        },
        {
            key: 'keyRequirements',
            label: 'Key Requirements 파악',
            isComplete: (r) => hasValue(r.Key_Requirements__c)
        },
        {
            key: 'targetStartSeason',
            label: 'Target Start Season 파악',
            isComplete: (r) => hasValue(r.Target_Start_Season__c)
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
        // 8개 항목 균등 가중치라 12.5% 단위 소수가 나올 수 있음 — 소수 첫째 자리까지만 유지
        return this.totalCount > 0 ? Math.round((this.completedCount / this.totalCount) * 1000) / 10 : 0;
    }
}

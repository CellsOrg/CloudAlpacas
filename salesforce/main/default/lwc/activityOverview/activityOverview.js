import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const OPPORTUNITY_FIELDS = [
    'Opportunity.Next_Activity_Subject__c',
    'Opportunity.Next_Activity_Date__c',
    'Opportunity.Open_Tasks_Count__c',
    'Opportunity.Overdue_Tasks_Count__c',
    'Opportunity.Last_Contact_Date__c',
    'Opportunity.Last_Contact_Type__c',
    'Opportunity.Days_Since_Last_Contact__c'
];

export default class ActivityOverview extends LightningElement {
    @api recordId;

    record;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: OPPORTUNITY_FIELDS })
    wiredOpportunity({ data, error }) {
        if (data) {
            const map = {};
            Object.keys(data.fields).forEach((apiName) => {
                map[apiName] = data.fields[apiName].value;
            });
            this.record = map;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.record = undefined;
        }
    }

    get hasLastContact() {
        return !!(this.record && this.record.Last_Contact_Date__c);
    }

    get lastContactDateDisplay() {
        if (!this.hasLastContact) {
            return '';
        }
        return new Date(this.record.Last_Contact_Date__c).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric'
        });
    }

    get lastContactType() {
        return this.record ? this.record.Last_Contact_Type__c : undefined;
    }

    get daysSinceLastContact() {
        return this.record ? this.record.Days_Since_Last_Contact__c : undefined;
    }

    get hasNextActivity() {
        return !!(this.record && this.record.Next_Activity_Date__c);
    }

    get nextActivityDateDisplay() {
        if (!this.hasNextActivity) {
            return '';
        }
        // ActivityDate는 Date-only 값이라 UTC 파싱 시 하루 밀리는 것을 방지하기 위해 그대로 포맷
        const [year, month, day] = this.record.Next_Activity_Date__c.split('-');
        return `${year}-${month}-${day}`;
    }

    get nextActivitySubject() {
        return this.record ? this.record.Next_Activity_Subject__c : undefined;
    }

    get openTasksCount() {
        return this.record && this.record.Open_Tasks_Count__c != null ? this.record.Open_Tasks_Count__c : 0;
    }

    get overdueTasksCount() {
        return this.record && this.record.Overdue_Tasks_Count__c != null ? this.record.Overdue_Tasks_Count__c : 0;
    }

    get hasOverdue() {
        return this.overdueTasksCount > 0;
    }

    get overdueClass() {
        return this.hasOverdue
            ? 'slds-text-heading_small slds-text-color_error'
            : 'slds-text-heading_small';
    }
}

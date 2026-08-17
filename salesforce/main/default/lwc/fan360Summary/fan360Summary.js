import { LightningElement, api, wire } from 'lwc';
import getFan360 from '@salesforce/apex/Fan360Controller.getFan360';

export default class Fan360Summary extends LightningElement {
    _selectedFanId;

    @api
    get selectedFanId() {
        return this._selectedFanId;
    }
    set selectedFanId(value) {
        this._selectedFanId = value;
        // 팬이 선택 해제되면 즉시 이전 데이터 비우기 (버그 수정 포인트)
        if (!value) {
            this.fan = undefined;
            this.error = undefined;
        }
    }

    fan;
    error;

    @wire(getFan360, { fanId: '$_selectedFanId' })
    wiredFan({ error, data }) {
        // fanId가 없으면 Apex를 호출하지 않도록, 그리고 혹시 이전 응답이 늦게 와도 무시
        if (!this._selectedFanId) {
            this.fan = undefined;
            this.error = undefined;
            return;
        }
        if (data) {
            this.fan = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.fan = undefined;
        }
    }

    get hasData() {
        return this.fan != null && this._selectedFanId != null;
    }

    get isEmpty() {
        return !this._selectedFanId;
    }

    get segmentLabel() {
        return '멤버십 전환 완료 팬';
    }
}
import { LightningElement, wire } from 'lwc';
import getRepresentativeFan from '@salesforce/apex/Fan360Controller.getRepresentativeFan';

export default class RecommendationDashboard extends LightningElement {
    selectedFanId;      // 우측 fan360Summary에 넘길 팬 Id
    showDemoNotice = false;
    repFanId;           // 대표 팬(이루키) Id — 미리 조회해둠

    // 대표 팬(이루키) Id를 미리 확보 (버튼 클릭 시 바로 넘기기 위해)
    @wire(getRepresentativeFan)
    wiredRep({ data }) {
        if (data && data.fanId) {
            this.repFanId = data.fanId;
        }
    }

    // 좌측에서 "대표 팬 검토" 클릭
    handleFanSelect(event) {
        const isRep = event.detail.isRepresentative;
        if (isRep && this.repFanId) {
            // 이루키 실제 데이터 표시
            this.selectedFanId = this.repFanId;
            this.showDemoNotice = false;
        } else {
            // 데모용 세그먼트: 준비중 안내
            this.selectedFanId = undefined;
            this.showDemoNotice = true;
        }
    }
}
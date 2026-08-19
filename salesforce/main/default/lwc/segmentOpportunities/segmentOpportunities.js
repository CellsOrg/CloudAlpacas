import { LightningElement, wire } from 'lwc';
import getMembershipCompletedCount from '@salesforce/apex/SegmentMembershipCompleted.getCount';
import getNoVisitAfterSignupCount from '@salesforce/apex/SegmentNoVisitAfterSignup.getCount';
// 다음 단계에서 세그먼트별 독립 Apex Class를 하나씩 추가하며 import를 늘려간다:
// import getDecliningVisitsCount from '@salesforce/apex/SegmentDecliningVisits.getCount';
// import getNoGoodsLoyalCount from '@salesforce/apex/SegmentNoGoodsLoyal.getCount';

export default class SegmentOpportunities extends LightningElement {
    segmentsBase = [
        {
            id: 'seg-membership',
            title: '멤버십 전환 완료 팬',
            fallbackCount: '1명',
            trait1: '가입→직관→굿즈→멤버십',
            trait2: '성공 여정 완료',
            why: '이상적인 팬 여정을 완주한 대표 사례로, 유사 팬 육성 전략의 기준이 됩니다.',
            isRepresentative: true
        },
        {
            id: 'seg-no-visit',
            title: '가입 후 경기 미관람',
            fallbackCount: '3,842명',
            trait1: '가입 후 21일 이상 경과',
            trait2: '앱 방문은 있으나 티켓 미구매',
            why: '초기 미참여가 장기화되면 이탈로 이어질 가능성이 높습니다.',
            isRepresentative: false
        },
        {
            id: 'seg-decline',
            title: '최근 30일 관람 감소',
            fallbackCount: '1,204명',
            trait1: '관람 빈도 평균 40% 감소',
            trait2: '멤버십 만료 임박',
            why: '충성도가 높았던 팬의 이탈 신호로, 조기 개입 시 유지 가능성이 큽니다.',
            isRepresentative: false
        },
        {
            id: 'seg-no-goods',
            title: '굿즈 미구매 충성 팬',
            fallbackCount: '2,130명',
            trait1: '평균 관람 8회/시즌',
            trait2: '굿즈 구매 이력 0건',
            why: '관람 충성도는 높지만 매출 기여가 낮아, 굿즈 관심 파악이 필요합니다.',
            isRepresentative: false
        }
    ];

    realCounts = {};

    @wire(getMembershipCompletedCount)
    wiredMembershipCount({ data }) {
        if (data !== undefined && data !== null) {
            this.realCounts = { ...this.realCounts, 'seg-membership': data };
        }
    }

    @wire(getNoVisitAfterSignupCount)
    wiredNoVisitCount({ data }) {
        if (data !== undefined && data !== null) {
            this.realCounts = { ...this.realCounts, 'seg-no-visit': data };
        }
    }

    get segments() {
        return this.segmentsBase.map((seg) => {
            const realValue = this.realCounts[seg.id];
            const count = (realValue !== undefined && realValue !== null)
                ? realValue.toLocaleString('ko-KR') + '명'
                : seg.fallbackCount;
            return { ...seg, count };
        });
    }

    handleReview(event) {
        const segId = event.currentTarget.dataset.id;
        const seg = this.segmentsBase.find((s) => s.id === segId);
        this.dispatchEvent(
            new CustomEvent('fanselect', {
                detail: { isRepresentative: seg.isRepresentative }
            })
        );
    }
}

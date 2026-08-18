/**
 * CampaignController
 * 캠페인 탭 카드 데이터. 우리 팀 4개 캠페인만 이름으로 필터링해서 조회.
 * (org에 있는 Salesforce 데모/샘플 Campaign은 제외)
 */
public with sharing class CampaignController {

    // 우리 팀이 관리하는 캠페인 4개 (고정 목록)
    private static final Set<String> TEAM_CAMPAIGNS = new Set<String>{
        'Welcome Campaign',
        'First Ticket Campaign',
        'First Merchandise Campaign',
        'Favorite Player Campaign'
    };

    @AuraEnabled(cacheable=true)
    public static List<CampaignCard> getCampaigns() {
        List<CampaignCard> cards = new List<CampaignCard>();

        List<Campaign> camps = [
            SELECT Id, Name, Status, Description, NumberSent, StartDate
            FROM Campaign
            WHERE Name IN :TEAM_CAMPAIGNS
            ORDER BY StartDate
        ];

        if (!camps.isEmpty()) {
            for (Campaign c : camps) {
                CampaignCard card = new CampaignCard();
                card.name = c.Name;
                card.status = mapStatus(c.Status);
                card.target = c.Description != null ? c.Description : '대상 미지정';
                card.numberSent = c.NumberSent != null ? c.NumberSent.intValue() : 0;
                card.targetCount = 0;
                card.scheduledDate = c.StartDate != null ? c.StartDate.format() : '';
                card.progress = defaultProgress(card.status);
                card.clickRate = 0;
                card.isScheduled = (card.status == '예약됨');
                cards.add(card);
            }
        } else {
            cards = demoCards();
        }

        return cards;
    }

    private static String mapStatus(String s) {
        if (s == null) return '진행 중';
        if (s == 'Completed' || s == 'Aborted') return '종료';
        if (s == 'Planned') return '예약됨';
        return '진행 중';
    }

    private static Integer defaultProgress(String status) {
        if (status == '종료') return 100;
        if (status == '예약됨') return 0;
        return 50;
    }

    private static List<CampaignCard> demoCards() {
        List<CampaignCard> lst = new List<CampaignCard>();
        lst.add(makeCard('Welcome Campaign', '진행 중', 'New Fan', 43, 512, 48, false, 0, ''));
        lst.add(makeCard('First Ticket Campaign', '예약됨', '가입 후 미구매 팬', 0, 0, 0, true, 1580, '8/20'));
        lst.add(makeCard('First Merchandise Campaign', '예약됨', '굿즈 미구매 팬', 0, 0, 0, true, 2310, '8/12'));
        lst.add(makeCard('Favorite Player Campaign', '종료', '문태양 팬 세그먼트', 100, 890, 61, false, 0, ''));
        return lst;
    }

    private static CampaignCard makeCard(String name, String status, String target,
            Integer progress, Integer numberSent, Integer clickRate,
            Boolean isScheduled, Decimal targetCount, String scheduledDate) {
        CampaignCard c = new CampaignCard();
        c.name = name; c.status = status; c.target = target;
        c.progress = progress; c.numberSent = numberSent; c.clickRate = clickRate;
        c.isScheduled = isScheduled; c.targetCount = targetCount; c.scheduledDate = scheduledDate;
        return c;
    }

    public class CampaignCard {
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String target;
        @AuraEnabled public Integer progress;
        @AuraEnabled public Integer numberSent;
        @AuraEnabled public Integer clickRate;
        @AuraEnabled public Boolean isScheduled;
        @AuraEnabled public Decimal targetCount;
        @AuraEnabled public String scheduledDate;
    }
}

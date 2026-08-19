/**
 * SegmentNoVisitAfterSignup
 * 세그먼트: 가입 후 경기 미관람
 * 조건: 가입 후 21일 이상 경과 AND 앱 방문(Engagement_Signal__c, App Open) 1회 이상 있음
 *       AND 티켓 구매(Order, Ticket Purchase) 이력 0건
 */
public with sharing class SegmentNoVisitAfterSignup {

    @AuraEnabled(cacheable=true)
    public static Integer getCount() {
        DateTime cutoff = DateTime.now().addDays(-21);

        // 가입 21일 이상 경과한 팬
        Set<Id> eligibleBySignupAge = new Set<Id>();
        for (Account a : [SELECT Id FROM Account WHERE CreatedDate <= :cutoff]) {
            eligibleBySignupAge.add(a.Id);
        }

        // 앱 방문(App Open) 기록이 있는 팬
        Set<Id> appOpenedFans = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Fan__c f FROM Engagement_Signal__c
            WHERE Signal_Type__c = 'App Open' AND Fan__c != null
            GROUP BY Fan__c
        ]) {
            appOpenedFans.add((Id) ar.get('f'));
        }

        // 티켓 구매 이력이 있는 팬 (제외 대상)
        Set<Id> ticketPurchasedFans = new Set<Id>();
        for (AggregateResult ar : [
            SELECT AccountId a FROM Order
            WHERE Order_Type__c = 'Ticket Purchase' AND AccountId != null
            GROUP BY AccountId
        ]) {
            ticketPurchasedFans.add((Id) ar.get('a'));
        }

        Integer count = 0;
        for (Id fanId : eligibleBySignupAge) {
            if (appOpenedFans.contains(fanId) && !ticketPurchasedFans.contains(fanId)) {
                count++;
            }
        }
        return count;
    }
}

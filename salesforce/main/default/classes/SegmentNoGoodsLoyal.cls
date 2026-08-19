/**
 * SegmentNoGoodsLoyal
 * 세그먼트: 굿즈 미구매 충성 팬
 * 조건: 현재 시즌(가장 최근 시작된 Season__c) 기준으로, 지금까지 열린 경기 수 대비
 *       관람 비율이 40% 이상인 팬 AND 굿즈 구매(Order, Goods Purchase) 이력이 0건.
 */
public with sharing class SegmentNoGoodsLoyal {

    private static final Decimal THRESHOLD = 0.4;

    @AuraEnabled(cacheable=true)
    public static Integer getCount() {
        // 1. 현재 시즌 판단: Game_Date__c가 가장 늦은(=가장 최근에 시작된) 시즌
        List<Game__c> latestGames = [
            SELECT Season__c FROM Game__c WHERE Season__c != null ORDER BY Game_Date__c DESC LIMIT 1
        ];
        if (latestGames.isEmpty()) return 0;
        Id currentSeasonId = latestGames[0].Season__c;

        // 2. 그 시즌에서 오늘 이전에 열린 경기 수
        Date today = Date.today();
        List<Game__c> pastGamesThisSeason = [
            SELECT Id FROM Game__c WHERE Season__c = :currentSeasonId AND Game_Date__c <= :today
        ];
        Integer totalGamesSoFar = pastGamesThisSeason.size();
        if (totalGamesSoFar == 0) return 0; // 아직 시즌 경기가 없으면 비율 산출 불가

        Set<Id> pastGameIds = new Set<Id>();
        for (Game__c g : pastGamesThisSeason) pastGameIds.add(g.Id);

        // 3. 팬별 이번 시즌(지금까지) 관람 횟수
        Map<Id, Integer> attendanceCount = new Map<Id, Integer>();
        for (Admission__c ad : [
            SELECT Fan__c FROM Admission__c WHERE Game__c IN :pastGameIds AND Fan__c != null
        ]) {
            attendanceCount.put(ad.Fan__c, (attendanceCount.containsKey(ad.Fan__c) ? attendanceCount.get(ad.Fan__c) : 0) + 1);
        }

        // 4. 굿즈 구매 이력이 있는 팬 (제외 대상)
        Set<Id> goodsFans = new Set<Id>();
        for (AggregateResult ar : [
            SELECT AccountId a FROM Order
            WHERE Order_Type__c = 'Goods Purchase' AND AccountId != null
            GROUP BY AccountId
        ]) {
            goodsFans.add((Id) ar.get('a'));
        }

        // 5. 판정: 관람비율 >= 40% AND 굿즈 구매 없음
        Integer count = 0;
        for (Id fanId : attendanceCount.keySet()) {
            if (goodsFans.contains(fanId)) continue;

            Decimal ratio = Decimal.valueOf(attendanceCount.get(fanId)) / totalGamesSoFar;
            if (ratio >= THRESHOLD) {
                count++;
            }
        }
        return count;
    }
}

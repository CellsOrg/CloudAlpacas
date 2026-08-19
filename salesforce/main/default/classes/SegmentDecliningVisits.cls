/**
 * SegmentDecliningVisits
 * 세그먼트: 최근 30일 관람 감소
 * 조건: 멤버십 만료일이 오늘로부터 45~75일 남은 팬 중,
 *       최근 30일 관람 횟수가 "가입 이후 30일당 평균 관람 횟수"의 40% 이하인 사람.
 *       (평균 자체가 0이면 "감소"를 판단할 기준이 없으므로 제외)
 */
public with sharing class SegmentDecliningVisits {

    @AuraEnabled(cacheable=true)
    public static Integer getCount() {
        Date today = Date.today();

        // 1. 멤버십 만료가 45~75일 남은 팬 (대상 후보)
        Set<Id> eligibleFans = new Set<Id>();
        for (Order o : [
            SELECT AccountId
            FROM Order
            WHERE Order_Type__c = 'Membership Enrollment'
                AND Coverage_End_Date__c != null
                AND Coverage_End_Date__c >= :today.addDays(45)
                AND Coverage_End_Date__c <= :today.addDays(75)
                AND AccountId != null
        ]) {
            eligibleFans.add(o.AccountId);
        }
        if (eligibleFans.isEmpty()) return 0;

        // 2. 대상 팬들의 가입일
        Map<Id, Date> signupDate = new Map<Id, Date>();
        for (Account a : [SELECT Id, CreatedDate FROM Account WHERE Id IN :eligibleFans]) {
            signupDate.put(a.Id, a.CreatedDate.date());
        }

        // 3. 대상 팬들의 관람 기록 (가입 이후 전체)
        Map<Id, Integer> totalAdmissions = new Map<Id, Integer>();
        Map<Id, Integer> recent30Admissions = new Map<Id, Integer>();
        Date recentCutoff = today.addDays(-30);

        for (Admission__c ad : [
            SELECT Fan__c, Admission_Time__c
            FROM Admission__c
            WHERE Fan__c IN :eligibleFans AND Admission_Time__c != null
        ]) {
            Date admDate = ad.Admission_Time__c.date();
            if (!signupDate.containsKey(ad.Fan__c)) continue;
            if (admDate < signupDate.get(ad.Fan__c)) continue; // 가입 이전 기록은 제외

            totalAdmissions.put(ad.Fan__c, (totalAdmissions.containsKey(ad.Fan__c) ? totalAdmissions.get(ad.Fan__c) : 0) + 1);

            if (admDate >= recentCutoff) {
                recent30Admissions.put(ad.Fan__c, (recent30Admissions.containsKey(ad.Fan__c) ? recent30Admissions.get(ad.Fan__c) : 0) + 1);
            }
        }

        // 4. 판정: 최근30일 관람 <= (가입이후 30일당 평균 관람) * 0.4
        Integer count = 0;
        for (Id fanId : eligibleFans) {
            Integer total = totalAdmissions.containsKey(fanId) ? totalAdmissions.get(fanId) : 0;
            Integer recent30 = recent30Admissions.containsKey(fanId) ? recent30Admissions.get(fanId) : 0;

            Integer daysSinceSignup = signupDate.get(fanId).daysBetween(today);
            if (daysSinceSignup <= 0) continue; // 가입한 지 얼마 안 된 팬은 평균 산출 불가

            Decimal avgPer30 = (Decimal.valueOf(total) / daysSinceSignup) * 30;
            if (avgPer30 <= 0) continue; // 기준 평균이 0이면 "감소" 판단 불가

            if (recent30 <= avgPer30 * 0.4) {
                count++;
            }
        }
        return count;
    }
}

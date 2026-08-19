/**
 * SegmentMembershipCompleted
 * 세그먼트: 멤버십 전환 완료 팬
 * 조건: 가입일 이후 직관 1회+ AND 가입일 이후 굿즈구매 1회+ (순서무관),
 *       그 후 멤버십 구매까지 완료 (멤버십 구매일이 두 활동일보다 이전이 아니어야 함).
 *       가입 이전 활동은 제외.
 */
public with sharing class SegmentMembershipCompleted {

    @AuraEnabled(cacheable=true)
    public static Integer getCount() {
        Map<Id, DateTime> signupDate = new Map<Id, DateTime>();
        for (Account a : [SELECT Id, CreatedDate FROM Account]) {
            signupDate.put(a.Id, a.CreatedDate);
        }

        Map<Id, DateTime> firstAdmissionAfterSignup = new Map<Id, DateTime>();
        for (Admission__c ad : [
            SELECT Fan__c, Admission_Time__c FROM Admission__c
            WHERE Fan__c != null AND Admission_Time__c != null
            ORDER BY Admission_Time__c ASC
        ]) {
            if (!signupDate.containsKey(ad.Fan__c)) continue;
            if (ad.Admission_Time__c < signupDate.get(ad.Fan__c)) continue;
            if (!firstAdmissionAfterSignup.containsKey(ad.Fan__c)) {
                firstAdmissionAfterSignup.put(ad.Fan__c, ad.Admission_Time__c);
            }
        }

        Map<Id, DateTime> firstGoodsAfterSignup = new Map<Id, DateTime>();
        Map<Id, List<DateTime>> membershipDates = new Map<Id, List<DateTime>>();
        for (Order o : [
            SELECT AccountId, Order_Type__c, EffectiveDate
            FROM Order
            WHERE AccountId != null AND EffectiveDate != null
                AND Order_Type__c IN ('Goods Purchase', 'Membership Enrollment')
            ORDER BY EffectiveDate ASC
        ]) {
            DateTime effDt = DateTime.newInstance(o.EffectiveDate, Time.newInstance(0,0,0,0));
            if (!signupDate.containsKey(o.AccountId)) continue;

            if (o.Order_Type__c == 'Goods Purchase') {
                if (effDt < signupDate.get(o.AccountId)) continue;
                if (!firstGoodsAfterSignup.containsKey(o.AccountId)) {
                    firstGoodsAfterSignup.put(o.AccountId, effDt);
                }
            } else {
                if (!membershipDates.containsKey(o.AccountId)) {
                    membershipDates.put(o.AccountId, new List<DateTime>());
                }
                membershipDates.get(o.AccountId).add(effDt);
            }
        }

        Integer count = 0;
        for (Id fanId : firstAdmissionAfterSignup.keySet()) {
            if (!firstGoodsAfterSignup.containsKey(fanId)) continue;
            if (!membershipDates.containsKey(fanId)) continue;

            DateTime admDt = firstAdmissionAfterSignup.get(fanId);
            DateTime goodsDt = firstGoodsAfterSignup.get(fanId);

            for (DateTime memDt : membershipDates.get(fanId)) {
                if (admDt <= memDt && goodsDt <= memDt) {
                    count++;
                    break;
                }
            }
        }
        return count;
    }
}

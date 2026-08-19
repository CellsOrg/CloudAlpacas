@isTest
private class SegmentNoVisitAfterSignupTest {

    @isTest
    static void testMatchingFanCounted() {
        // 가입 30일 전 + 앱 방문 있음 + 티켓 구매 없음 → 카운트 되어야 함
        Account fan = new Account(LastName = '미관람팬');
        insert fan;
        Test.setCreatedDate(fan.Id, DateTime.now().addDays(-30));

        insert new Engagement_Signal__c(Fan__c = fan.Id, Signal_Type__c = 'App Open',
            Signal_Date__c = DateTime.now().addDays(-5));

        Test.startTest();
        Integer count = SegmentNoVisitAfterSignup.getCount();
        Test.stopTest();

        System.assertEquals(1, count, '조건을 만족하는 팬 1명이 카운트되어야 함');
    }

    @isTest
    static void testTicketPurchasedFanExcluded() {
        // 조건은 다 맞지만 티켓을 구매한 팬 → 제외되어야 함
        Account fan = new Account(LastName = '티켓구매팬');
        insert fan;
        Test.setCreatedDate(fan.Id, DateTime.now().addDays(-30));

        insert new Engagement_Signal__c(Fan__c = fan.Id, Signal_Type__c = 'App Open',
            Signal_Date__c = DateTime.now().addDays(-5));

        insert new Order(AccountId = fan.Id, Status = 'Activated', EffectiveDate = Date.today(),
            Order_Type__c = 'Ticket Purchase', Pricebook2Id = Test.getStandardPricebookId());

        Test.startTest();
        Integer count = SegmentNoVisitAfterSignup.getCount();
        Test.stopTest();

        System.assertEquals(0, count, '티켓 구매한 팬은 제외되어야 함');
    }

    @isTest
    static void testRecentSignupExcluded() {
        // 가입한 지 21일이 안 된 팬 → 제외되어야 함
        Account fan = new Account(LastName = '최근가입팬');
        insert fan; // 기본 CreatedDate = 지금

        insert new Engagement_Signal__c(Fan__c = fan.Id, Signal_Type__c = 'App Open',
            Signal_Date__c = DateTime.now());

        Test.startTest();
        Integer count = SegmentNoVisitAfterSignup.getCount();
        Test.stopTest();

        System.assertEquals(0, count, '가입 21일 미만 팬은 제외되어야 함');
    }

    @isTest
    static void testNoAppOpenExcluded() {
        // 앱 방문 기록이 없는 팬 → 제외되어야 함
        Account fan = new Account(LastName = '무방문팬');
        insert fan;
        Test.setCreatedDate(fan.Id, DateTime.now().addDays(-30));

        Test.startTest();
        Integer count = SegmentNoVisitAfterSignup.getCount();
        Test.stopTest();

        System.assertEquals(0, count, '앱 방문 기록이 없는 팬은 제외되어야 함');
    }
}

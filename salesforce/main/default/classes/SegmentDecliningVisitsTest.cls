@isTest
private class SegmentDecliningVisitsTest {

    // 공통 헬퍼: 관람 기록 여러 건 생성
    private static void insertAdmissions(Id fanId, List<DateTime> times) {
        Season__c season = new Season__c(Total_Games__c = 144);
        insert season;
        List<Admission__c> admissions = new List<Admission__c>();
        for (DateTime t : times) {
            Game__c game = new Game__c(Game_Date__c = t.date(), Season__c = season.Id);
            insert game;
            Attendance_Record__c ar = new Attendance_Record__c(Fan__c = fanId);
            insert ar;
            admissions.add(new Admission__c(Fan__c = fanId, Game__c = game.Id, Attendance_Record__c = ar.Id,
                Admission_Time__c = t));
        }
        insert admissions;
    }

    @isTest
    static void testDecliningFanCounted() {
        // 가입 100일 전, 총 10회 관람(초반에 몰림), 최근 30일 관람 0회 → 평균 대비 급감 → 카운트되어야 함
        Account fan = new Account(LastName = '감소팬');
        insert fan;
        Test.setCreatedDate(fan.Id, DateTime.now().addDays(-100));

        List<DateTime> times = new List<DateTime>();
        for (Integer i = 0; i < 10; i++) {
            times.add(DateTime.now().addDays(-90 + i)); // 가입 초반에 몰아서 10회 관람, 최근 30일엔 없음
        }
        insertAdmissions(fan.Id, times);

        insert new Order(AccountId = fan.Id, Status = 'Activated', EffectiveDate = Date.today(),
            Order_Type__c = 'Membership Enrollment', Pricebook2Id = Test.getStandardPricebookId(),
            Coverage_End_Date__c = Date.today().addDays(60));

        Test.startTest();
        Integer count = SegmentDecliningVisits.getCount();
        Test.stopTest();

        System.assertEquals(1, count, '관람 빈도가 급감한 팬은 카운트되어야 함');
    }

    @isTest
    static void testConsistentFanNotCounted() {
        // 가입 이후 꾸준히 관람 중인 팬 → 카운트되면 안 됨
        Account fan = new Account(LastName = '꾸준팬');
        insert fan;
        Test.setCreatedDate(fan.Id, DateTime.now().addDays(-100));

        List<DateTime> times = new List<DateTime>();
        for (Integer i = 0; i < 10; i++) {
            times.add(DateTime.now().addDays(-99 + (i * 10))); // 100일간 고르게 분포, 최근에도 있음
        }
        insertAdmissions(fan.Id, times);

        insert new Order(AccountId = fan.Id, Status = 'Activated', EffectiveDate = Date.today(),
            Order_Type__c = 'Membership Enrollment', Pricebook2Id = Test.getStandardPricebookId(),
            Coverage_End_Date__c = Date.today().addDays(60));

        Test.startTest();
        Integer count = SegmentDecliningVisits.getCount();
        Test.stopTest();

        System.assertEquals(0, count, '꾸준히 관람 중인 팬은 카운트되지 않아야 함');
    }

    @isTest
    static void testMembershipExpiryOutOfRangeExcluded() {
        // 관람 감소 패턴은 동일하지만, 멤버십 만료가 45~75일 범위 밖(예: 10일 남음)이면 제외
        Account fan = new Account(LastName = '범위밖팬');
        insert fan;
        Test.setCreatedDate(fan.Id, DateTime.now().addDays(-100));

        List<DateTime> times = new List<DateTime>();
        for (Integer i = 0; i < 10; i++) {
            times.add(DateTime.now().addDays(-90 + i));
        }
        insertAdmissions(fan.Id, times);

        insert new Order(AccountId = fan.Id, Status = 'Activated', EffectiveDate = Date.today(),
            Order_Type__c = 'Membership Enrollment', Pricebook2Id = Test.getStandardPricebookId(),
            Coverage_End_Date__c = Date.today().addDays(10)); // 범위 밖

        Test.startTest();
        Integer count = SegmentDecliningVisits.getCount();
        Test.stopTest();

        System.assertEquals(0, count, '만료 기간이 45~75일 범위 밖이면 제외되어야 함');
    }
}

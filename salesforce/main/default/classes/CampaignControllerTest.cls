@isTest
private class CampaignControllerTest {

    @isTest
    static void testDemoFallback() {
        // Campaign 0건 → 데모 카드 반환
        Test.startTest();
        List<CampaignController.CampaignCard> cards = CampaignController.getCampaigns();
        Test.stopTest();

        System.assertNotEquals(null, cards, '카드가 반환되어야 함');
        System.assert(cards.size() >= 1, '데모 카드가 최소 1개 이상이어야 함');
    }

    @isTest
    static void testRealData() {
        // 실제 Campaign 있으면 그걸 반환
        Campaign c = new Campaign(
            Name = 'Welcome Campaign',
            Status = 'In Progress',
            Description = 'New Fan',
            NumberSent = 512
        );
        insert c;

        Test.startTest();
        List<CampaignController.CampaignCard> cards = CampaignController.getCampaigns();
        Test.stopTest();

        System.assertEquals(1, cards.size(), '실제 캠페인 1건이 반환되어야 함');
        System.assertEquals('Welcome Campaign', cards[0].name, '이름이 일치해야 함');
    }
}

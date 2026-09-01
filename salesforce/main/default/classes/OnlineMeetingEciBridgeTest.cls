@IsTest
private class OnlineMeetingEciBridgeTest {
    @testSetup
    static void setupData() {
        Account account = new Account(Name = 'ECI Bridge Test Account');
        insert account;
        Opportunity opportunity = new Opportunity(
            Name = 'ECI Bridge Test Opportunity',
            AccountId = account.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30)
        );
        insert opportunity;
        insert new Event(
            Subject = 'ECI canonical online meeting',
            WhatId = opportunity.Id,
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addMinutes(30),
            Meeting_Type__c = 'Online',
            External_ID__c = 'google-meet-key-001'
        );
    }

    @IsTest
    static void resolvesOnlyExactOnlineEventOnSameOpportunity() {
        Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'ECI Bridge Test Opportunity' LIMIT 1];
        VideoCall videoCall = new VideoCall(
            RelatedRecordId = opportunity.Id,
            VendorMeetingUuid = 'google-meet-key-001'
        );

        Test.startTest();
        OnlineMeetingEciBridge.Response result = OnlineMeetingEciBridge.resolveFor(
            videoCall, '고객이 예산 검토 일정을 설명했습니다.', false
        );
        Test.stopTest();

        System.assertEquals(true, result.isProcessable);
        System.assertEquals('MATCHED', result.statusCode);
        System.assertEquals(opportunity.Id, result.opportunityId);
        System.assertNotEquals(null, result.eventId);
    }

    @IsTest
    static void rejectsUnsafeOrIncompleteInputs() {
        Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'ECI Bridge Test Opportunity' LIMIT 1];
        VideoCall matchingCall = new VideoCall(
            RelatedRecordId = opportunity.Id,
            VendorMeetingUuid = 'google-meet-key-001'
        );

        System.assertEquals(
            'TRANSCRIPT_EMPTY',
            OnlineMeetingEciBridge.resolveFor(matchingCall, null, false).statusCode
        );
        System.assertEquals(
            'TRANSCRIPT_TRUNCATED',
            OnlineMeetingEciBridge.resolveFor(matchingCall, 'text', true).statusCode
        );
        System.assertEquals(
            'RELATED_RECORD_MISSING',
            OnlineMeetingEciBridge.resolveFor(new VideoCall(VendorMeetingUuid = 'google-meet-key-001'), 'text', false).statusCode
        );
        System.assertEquals(
            'CANONICAL_EVENT_NOT_FOUND',
            OnlineMeetingEciBridge.resolveFor(
                new VideoCall(RelatedRecordId = opportunity.Id, VendorMeetingUuid = 'unknown-key'), 'text', false
            ).statusCode
        );
    }

    @IsTest
    static void rejectsEventWhenOpportunityOrTypeDoesNotMatch() {
        Account account = new Account(Name = 'Other ECI Bridge Account');
        insert account;
        Opportunity otherOpportunity = new Opportunity(
            Name = 'Other ECI Bridge Opportunity',
            AccountId = account.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30)
        );
        insert otherOpportunity;
        insert new Event(
            Subject = 'Wrong opportunity meeting',
            WhatId = otherOpportunity.Id,
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addMinutes(30),
            Meeting_Type__c = 'Online',
            External_ID__c = 'google-meet-key-other'
        );

        Opportunity expectedOpportunity = [SELECT Id FROM Opportunity WHERE Name = 'ECI Bridge Test Opportunity' LIMIT 1];
        OnlineMeetingEciBridge.Response result = OnlineMeetingEciBridge.resolveFor(
            new VideoCall(RelatedRecordId = expectedOpportunity.Id, VendorMeetingUuid = 'google-meet-key-other'),
            'text',
            false
        );

        System.assertEquals(false, result.isProcessable);
        System.assertEquals('OPPORTUNITY_MISMATCH', result.statusCode);
    }
}

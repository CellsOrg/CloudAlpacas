@IsTest
private class OnlineMeetingActivityFlowTest {
    @IsTest
    static void routesOnlineMeetingToEventAndKeepsFollowUpAsTask() {
        Account account = new Account(Name = 'Activity Flow Test Account');
        insert account;
        Opportunity opportunity = new Opportunity(
            Name = 'Activity Flow Test Opportunity',
            AccountId = account.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30)
        );
        insert opportunity;

        Map<String, Object> onlineInputs = new Map<String, Object>{
            'activityType' => 'Task',
            'whatId' => String.valueOf(opportunity.Id),
            'subject' => 'Google Meet discovery',
            'startDateTime' => System.now().addDays(1),
            'endDateTime' => System.now().addDays(1).addMinutes(30),
            'meetingType' => 'Online',
            'meetingKey' => 'agent-created-online-key'
        };
        Test.startTest();
        Flow.Interview.CA_Create_Opportunity_Activity onlineInterview =
            new Flow.Interview.CA_Create_Opportunity_Activity(onlineInputs);
        onlineInterview.start();
        Test.stopTest();

        System.assertEquals('Event', (String) onlineInterview.getVariableValue('recordType'));
        Event onlineEvent = [
            SELECT WhatId, Meeting_Type__c, External_ID__c
            FROM Event
            WHERE Id = :((String) onlineInterview.getVariableValue('recordId'))
        ];
        System.assertEquals(opportunity.Id, onlineEvent.WhatId);
        System.assertEquals('Online', onlineEvent.Meeting_Type__c);
        System.assertEquals('agent-created-online-key', onlineEvent.External_ID__c);

        Map<String, Object> followUpInputs = new Map<String, Object>{
            'activityType' => 'Task',
            'whatId' => String.valueOf(opportunity.Id),
            'subject' => '제안서 수정',
            'activityDate' => Date.today().addDays(1),
            'status' => 'Not Started'
        };
        Flow.Interview.CA_Create_Opportunity_Activity followUpInterview =
            new Flow.Interview.CA_Create_Opportunity_Activity(followUpInputs);
        followUpInterview.start();

        System.assertEquals('Task', (String) followUpInterview.getVariableValue('recordType'));
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Task WHERE Id = :((String) followUpInterview.getVariableValue('recordId'))]
        );
    }
}

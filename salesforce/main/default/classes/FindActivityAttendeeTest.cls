@isTest
private class FindActivityAttendeeTest {

    @testSetup
    static void setup() {
        Account a = new Account(Name = 'Attendee Test Co');
        insert a;
        insert new List<Contact>{
            new Contact(LastName = '김하나', AccountId = a.Id, Title = 'Partnership Manager'),
            new Contact(LastName = '박두나', AccountId = a.Id)
        };
        Opportunity o = new Opportunity(
            Name = 'Attendee Test Opp', AccountId = a.Id, StageName = 'Negotiation',
            CloseDate = Date.today().addDays(15)
        );
        insert o;
    }

    private static Id oppId() {
        return [SELECT Id FROM Opportunity WHERE Name = 'Attendee Test Opp' LIMIT 1].Id;
    }

    private static FindActivityAttendee.Result run(String name, String opp) {
        FindActivityAttendee.Request req = new FindActivityAttendee.Request();
        req.personName = name;
        req.opportunityId = opp;
        return FindActivityAttendee.execute(new List<FindActivityAttendee.Request>{ req })[0];
    }

    @isTest
    static void resolvesUniqueAccountContactAndStripsHonorific() {
        Test.startTest();
        FindActivityAttendee.Result r = run('김하나님', oppId());
        Integer dml = Limits.getDmlStatements();
        Test.stopTest();

        System.assert(r.found && r.isUnique, r.message);
        System.assertEquals('Contact', r.resolvedType);
        System.assertEquals([SELECT Id FROM Contact WHERE LastName = '김하나' LIMIT 1].Id, (Id) r.resolvedId);
        System.assert(!r.message.contains('Salesforce ID'), 'never asks for a Salesforce Id: ' + r.message);
        System.assertEquals(0, dml, 'read-only');
    }

    @isTest
    static void notFoundGivesGuidanceNotIdRequest() {
        FindActivityAttendee.Result r = run('존재하지않는사람', oppId());
        System.assert(!r.found);
        System.assert(r.message.contains('찾지 못했습니다'), r.message);
        System.assert(!r.message.contains('정확한 Salesforce ID'), 'no id demand: ' + r.message);
        System.assertEquals('', r.resolvedId);
    }

    @isTest
    static void multipleContactsReturnCandidateList() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Attendee Test Co' LIMIT 1];
        insert new Contact(LastName = '하나', AccountId = a.Id); // matches "%하나%" like 김하나
        FindActivityAttendee.Result r = run('하나', oppId());
        System.assert(r.found && !r.isUnique, r.message);
        System.assert(r.matchCount >= 2, 'count=' + r.matchCount);
        System.assert(String.isNotBlank(r.matchesSummary));
        System.assertEquals('', r.resolvedId, 'no resolvedId when ambiguous');
    }

    @isTest
    static void blankNameAsksForName() {
        FindActivityAttendee.Result r = run('  ', oppId());
        System.assert(!r.found);
        System.assert(r.message.contains('이름을 알려주세요'), r.message);
    }

    @isTest
    static void fallsBackToActiveUserWhenNoAccountContact() {
        User u = [SELECT Id, Name FROM User WHERE IsActive = true AND Name != null ORDER BY CreatedDate LIMIT 1];
        String frag = u.Name.length() > 4 ? u.Name.substring(0, 4) : u.Name;
        FindActivityAttendee.Result r = run(frag, oppId());
        System.assert(r.found, 'user fallback: ' + r.message);
        System.assertEquals('User', r.resolvedType);
    }
}

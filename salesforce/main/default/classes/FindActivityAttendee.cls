/**
 * Read-only. Resolves a person NAME the user gave as a meeting attendee / task
 * contact to a Salesforce Id:
 *   1. an OpportunityContactRole contact on the Opportunity, then
 *   2. a Contact on the Opportunity's Account (external customer / partner), then
 *   3. an active internal User.
 * Returns isUnique + resolvedId / resolvedType, a candidate list on multiple
 * matches, or a plain not-found message. Never asks the user for a record Id.
 * No DML.
 *
 * Backs the Opportunity Agent Activity Assistant action find_activity_attendee;
 * the resolved Id is bound into create_activity's whoId.
 */
public with sharing class FindActivityAttendee {

    private static final Integer MAX_RESULTS = 5;

    @InvocableMethod(
        label='Find Activity Attendee'
        description='Read-only. Resolves a person name (meeting attendee / task contact) to a Contact on the Opportunity or its Account, or an internal User. Returns isUnique / candidates / not-found. No DML.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request req : (requests == null ? new List<Request>() : requests)) {
            out.add(handle(req));
        }
        return out;
    }

    private static Result handle(Request req) {
        Result r = new Result();
        String name = normalize(req.personName);
        if (String.isBlank(name)) {
            r.message = '누구를 참석자/연락 대상으로 할지 이름을 알려주세요.';
            return r;
        }
        String likeTerm = '%' + name + '%';

        Id oppId = safeId(req.opportunityId, Opportunity.SObjectType);
        Id acctId;
        if (oppId != null) {
            List<Opportunity> opps = [SELECT AccountId FROM Opportunity WHERE Id = :oppId WITH USER_MODE LIMIT 1];
            if (!opps.isEmpty()) {
                acctId = opps[0].AccountId;
            }
        }

        // 1) Opportunity contact roles
        List<Contact> contacts = new List<Contact>();
        Set<Id> seen = new Set<Id>();
        if (oppId != null) {
            for (OpportunityContactRole ocr : [
                SELECT ContactId, Contact.Name, Contact.Title, Contact.Account.Name, Role
                FROM OpportunityContactRole
                WHERE OpportunityId = :oppId AND Contact.Name LIKE :likeTerm
                WITH USER_MODE
                LIMIT :MAX_RESULTS
            ]) {
                if (seen.add(ocr.ContactId)) {
                    contacts.add(ocr.Contact);
                }
            }
        }
        // 2) Account contacts
        if (contacts.isEmpty() && acctId != null) {
            for (Contact c : [
                SELECT Id, Name, Title, Account.Name
                FROM Contact
                WHERE AccountId = :acctId AND Name LIKE :likeTerm
                WITH USER_MODE
                LIMIT :MAX_RESULTS
            ]) {
                contacts.add(c);
            }
        }

        if (!contacts.isEmpty()) {
            r.found = true;
            r.matchCount = contacts.size();
            r.resolvedType = 'Contact';
            if (contacts.size() == 1) {
                r.isUnique = true;
                r.resolvedId = String.valueOf(contacts[0].Id);
                r.resolvedName = contacts[0].Name;
                r.message = contacts[0].Name
                    + (contacts[0].Title == null ? '' : ' (' + contacts[0].Title + ')')
                    + ' 연락처로 연결합니다.';
            } else {
                r.matchesSummary = summarizeContacts(contacts);
                r.message = '이름이 "' + name + '"인 연락처가 여러 명입니다. 누구를 말하는지 알려주세요.';
            }
            return r;
        }

        // 3) internal Users
        List<User> users = [
            SELECT Id, Name, Title FROM User
            WHERE IsActive = true AND Name LIKE :likeTerm
            WITH USER_MODE
            ORDER BY Name
            LIMIT :MAX_RESULTS
        ];
        if (!users.isEmpty()) {
            r.found = true;
            r.matchCount = users.size();
            r.resolvedType = 'User';
            if (users.size() == 1) {
                r.isUnique = true;
                r.resolvedId = String.valueOf(users[0].Id);
                r.resolvedName = users[0].Name;
                r.message = '내부 직원 ' + users[0].Name + ' 님으로 연결합니다.';
            } else {
                List<String> lines = new List<String>();
                for (User u : users) {
                    lines.add(u.Name + (u.Title == null ? '' : ' — ' + u.Title) + ' (내부 직원)');
                }
                r.matchesSummary = String.join(lines, '\n');
                r.message = '이름이 "' + name + '"인 내부 직원이 여러 명입니다. 누구인지 알려주세요.';
            }
            return r;
        }

        r.found = false;
        r.message = 'Salesforce에서 "' + name + '" 연락처(고객/파트너 담당자)나 내부 직원을 찾지 못했습니다. '
            + '이 딜의 Account에 등록된 Contact가 아닐 수 있습니다. 참석자 없이 일정을 만들거나, 연락처 정보를 알려주시면 안내하겠습니다.';
        return r;
    }

    private static String summarizeContacts(List<Contact> cs) {
        List<String> lines = new List<String>();
        for (Contact c : cs) {
            lines.add(c.Name
                + (c.Account != null && c.Account.Name != null ? ' — ' + c.Account.Name : '')
                + (c.Title != null ? ' / ' + c.Title : ''));
        }
        return String.join(lines, '\n');
    }

    private static String normalize(String s) {
        if (s == null) {
            return '';
        }
        String t = s.trim();
        // strip a trailing Korean honorific the user may have said
        for (String h : new List<String>{ '님', '씨', ' 님', ' 씨' }) {
            if (t.endsWith(h)) {
                t = t.substring(0, t.length() - h.length()).trim();
            }
        }
        return t;
    }

    private static Id safeId(String s, Schema.SObjectType expected) {
        if (String.isBlank(s)) {
            return null;
        }
        try {
            Id v = Id.valueOf(s.trim());
            return (v.getSObjectType() == expected) ? v : null;
        } catch (Exception e) {
            return null;
        }
    }

    public class Request {
        @InvocableVariable(label='Person Name' description='The attendee / contact name the user said, verbatim (honorific optional).' required=true)
        public String personName;
        @InvocableVariable(label='Opportunity Id' description='The current Opportunity Id — used to scope the Contact search to its Account and contact roles.')
        public String opportunityId;
    }

    public class Result {
        @InvocableVariable(label='Found' description='True when at least one Contact or User matched.')
        public Boolean found = false;
        @InvocableVariable(label='Is Unique' description='True only when exactly one person matched — only then is resolvedId safe to use.')
        public Boolean isUnique = false;
        @InvocableVariable(label='Match Count')
        public Integer matchCount = 0;
        @InvocableVariable(label='Resolved Id' description='Contact or User Id (string) when isUnique is true, otherwise empty. Bind into create_activity whoId.')
        public String resolvedId = '';
        @InvocableVariable(label='Resolved Type' description='"Contact" or "User" when isUnique is true, otherwise empty.')
        public String resolvedType = '';
        @InvocableVariable(label='Resolved Name')
        public String resolvedName = '';
        @InvocableVariable(label='Matches Summary' description='Name / company / title list for the user to disambiguate when more than one matched.')
        public String matchesSummary = '';
        @InvocableVariable(label='Message' description='Human-readable Korean result — safe to show the user. Never asks for a Salesforce Id.')
        public String message = '';
    }
}

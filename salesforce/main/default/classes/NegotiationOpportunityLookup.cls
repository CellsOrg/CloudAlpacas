public with sharing class NegotiationOpportunityLookup {

    private static final Integer MAX_RESULTS = 5;

    @InvocableMethod(
        label='Find Opportunity By Name'
        description='Resolves an Opportunity Record Id from whatever the user said - a deal name, an account name, or an existing Record Id. Searches by name/account name; if the input already looks like a Record Id, validates it directly instead of searching.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();

            if (String.isBlank(req.searchTerm)) {
                r.found = false;
                r.isUnique = false;
                r.matchCount = 0;
                results.add(r);
                continue;
            }

            String term = req.searchTerm.trim();
            List<Opportunity> matches = new List<Opportunity>();
            Id asId = tryParseOpportunityId(term);
            if (asId != null) {
                matches = [
                    SELECT Id, Name, StageName, Account.Name
                    FROM Opportunity
                    WHERE Id = :asId
                    WITH USER_MODE
                ];
            } else {
                // 1) Exact Opportunity Name match wins outright. A fully-typed deal
                //    name must resolve to that one deal even when a fuzzy LIKE would
                //    also catch sibling deals on the same account.
                matches = [
                    SELECT Id, Name, StageName, Account.Name
                    FROM Opportunity
                    WHERE Name = :term
                    WITH USER_MODE
                    LIMIT :MAX_RESULTS
                ];
                // 2) No exact Opportunity-name hit — fall back to a fuzzy name/account
                //    search. Account-name matches stay in this candidate bucket: one
                //    account can own several Opportunities, so an account match is a
                //    lead to disambiguate, never an outright pick. searchTerm is a
                //    bind variable (:likeTerm) — injection-safe, so do NOT
                //    escapeSingleQuotes it (that injects a literal backslash and
                //    breaks any search containing an apostrophe, e.g. "d'Alba").
                if (matches.isEmpty()) {
                    String likeTerm = '%' + term + '%';
                    matches = [
                        SELECT Id, Name, StageName, Account.Name
                        FROM Opportunity
                        WHERE (Name LIKE :likeTerm OR Account.Name LIKE :likeTerm)
                        WITH USER_MODE
                        ORDER BY LastModifiedDate DESC
                        LIMIT :MAX_RESULTS
                    ];
                }
            }

            r.matchCount = matches.size();
            r.found = !matches.isEmpty();
            r.isUnique = matches.size() == 1;

            List<String> lines = new List<String>();
            for (Opportunity opp : matches) {
                lines.add(opp.Name + ' (' + opp.Account.Name + ', ' + opp.StageName + ')');
            }
            r.matchesSummary = String.join(lines, '\n');

            if (r.isUnique) {
                r.singleMatchId = matches[0].Id;
                r.singleMatchName = matches[0].Name;
                r.resolvedId = String.valueOf(matches[0].Id);
            }

            results.add(r);
        }

        return results;
    }

    /**
     * Returns a valid Opportunity Id if the given text is a well-formed (15 or 18 char)
     * Salesforce Id for the Opportunity object, otherwise null. Lets this action
     * transparently handle both "the user typed a deal name" and "the caller already
     * has a Record Id" without a separate action.
     */
    private static Id tryParseOpportunityId(String text) {
        if (text == null || (text.length() != 15 && text.length() != 18)) {
            return null;
        }
        try {
            Id candidate = Id.valueOf(text);
            if (candidate.getSObjectType() != Opportunity.SObjectType) {
                return null;
            }
            return candidate;
        } catch (Exception e) {
            return null;
        }
    }

    public class Request {
        @InvocableVariable(
            label='Search Term'
            description='Opportunity name or account name (or part of it) as the user said it, e.g. "삼성카드" or "삼성카드 - 2026 시즌 파트너십 제안".'
            required=true
        )
        public String searchTerm;
    }

    public class Result {
        @InvocableVariable(label='Found' description='Whether at least one matching Opportunity was found.')
        public Boolean found = false;

        @InvocableVariable(label='Is Unique' description='True when exactly one Opportunity matched (safe to use singleMatchId directly).')
        public Boolean isUnique = false;

        @InvocableVariable(label='Match Count' description='Number of matching Opportunities found (capped at 5).')
        public Decimal matchCount;

        @InvocableVariable(label='Single Match Id' description='Id of the matched Opportunity, only set when isUnique is true.')
        public Id singleMatchId;

        @InvocableVariable(label='Resolved Id' description='The matched Opportunity Id as a string when isUnique is true, otherwise an empty string (never null). Bind THIS into a conversation variable — a non-unique or no-match result then leaves the variable empty so downstream actions gated on it stay disabled.')
        public String resolvedId = '';

        @InvocableVariable(label='Single Match Name' description='Name of the matched Opportunity, only set when isUnique is true.')
        public String singleMatchName;

        @InvocableVariable(label='Matches Summary' description='Formatted list of all matches (name, account, stage) for the user to pick from when not unique.')
        public String matchesSummary;
    }
}

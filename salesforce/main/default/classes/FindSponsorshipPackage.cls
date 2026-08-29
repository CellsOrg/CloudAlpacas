/**
 * Resolves a Sponsorship Package Product2 Id deterministically from what the rep called
 * it — a package name or a product code — for one Opportunity's currency. Mirrors
 * NegotiationOpportunityLookup: an exact match wins outright; otherwise every candidate
 * is returned for the rep to disambiguate and resolvedId stays empty so the downstream
 * save action stays gated. The Proposal Assistant binds resolvedId into
 * resolved_proposal_package_id — the LLM never types a raw Product2 Id.
 *
 * A package only counts as resolvable when it is active, has the Sponsorship_Package
 * record type, and has an active Standard Price Book entry in the Opportunity's currency.
 */
public with sharing class FindSponsorshipPackage {

    private static final Integer MAX_RESULTS = 5;
    private static final String SPONSORSHIP_PACKAGE_RT = 'Sponsorship_Package';

    @InvocableMethod(
        label='Find Sponsorship Package'
        description='Resolves a Sponsorship Package Product2 Id from the package name or product code the rep chose, scoped to an Opportunity\'s currency. Exact name/code match resolves uniquely; multiple matches return the candidate list and resolve nothing.'
    )
    public static List<Result> execute(List<Request> requests) {
        Set<Id> oppIds = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.opportunityId != null) oppIds.add(req.opportunityId);
        }
        Map<Id, Opportunity> oppById = oppIds.isEmpty()
            ? new Map<Id, Opportunity>()
            : new Map<Id, Opportunity>([
                SELECT Id, CurrencyIsoCode FROM Opportunity WHERE Id IN :oppIds WITH USER_MODE
            ]);

        // Active Sponsorship Package products + their active Standard Price Book entries,
        // keyed product + currency. Direct PricebookEntry query filtered by the standard
        // book Id (a Pricebook2.IsStandard child-subquery filter does not reliably return
        // test-created entries).
        Map<Id, Product2> pkgById = new Map<Id, Product2>([
            SELECT Id, Name, ProductCode
            FROM Product2
            WHERE RecordType.DeveloperName = :SPONSORSHIP_PACKAGE_RT AND IsActive = true
            WITH USER_MODE
            ORDER BY Name
        ]);
        Id standardPbId = (Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true WITH USER_MODE LIMIT 1].Id);
        Map<String, PricebookEntry> pbeByProductCurrency = new Map<String, PricebookEntry>();
        if (!pkgById.isEmpty()) {
            for (PricebookEntry pbe : [
                SELECT Product2Id, UnitPrice, CurrencyIsoCode
                FROM PricebookEntry
                WHERE Product2Id IN :pkgById.keySet()
                  AND Pricebook2Id = :standardPbId
                  AND IsActive = true
                WITH USER_MODE
            ]) {
                pbeByProductCurrency.put(pbe.Product2Id + '|' + pbe.CurrencyIsoCode, pbe);
            }
        }

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(resolveOne(req, oppById, pkgById, pbeByProductCurrency));
        }
        return results;
    }

    private static Result resolveOne(
        Request req,
        Map<Id, Opportunity> oppById,
        Map<Id, Product2> pkgById,
        Map<String, PricebookEntry> pbeByProductCurrency
    ) {
        Result r = new Result();

        if (req == null || String.isBlank(req.searchTerm)) {
            r.message = '패키지 이름이나 상품 코드를 입력해 주세요.';
            return r;
        }
        if (req.opportunityId == null || !oppById.containsKey(req.opportunityId)) {
            r.message = 'Opportunity를 먼저 확인해야 패키지를 통화 기준으로 조회할 수 있습니다.';
            return r;
        }
        String oppCurrency = (String) oppById.get(req.opportunityId).get('CurrencyIsoCode');
        String term = req.searchTerm.trim();
        String termLower = term.toLowerCase();

        List<PackageMatch> exact = new List<PackageMatch>();
        List<PackageMatch> fuzzy = new List<PackageMatch>();

        for (Product2 p : pkgById.values()) {
            PricebookEntry pbe = pbeByProductCurrency.get(p.Id + '|' + oppCurrency);
            Decimal unitPrice = (pbe == null) ? null : pbe.UnitPrice;
            if (unitPrice == null) {
                continue; // not sellable in this Opportunity's currency
            }
            Boolean nameExact = p.Name != null && p.Name.equalsIgnoreCase(term);
            Boolean codeExact = p.ProductCode != null && p.ProductCode.equalsIgnoreCase(term);
            Boolean nameFuzzy = p.Name != null && p.Name.toLowerCase().contains(termLower);
            Boolean codeFuzzy = p.ProductCode != null && p.ProductCode.toLowerCase().contains(termLower);

            if (nameExact || codeExact) {
                exact.add(new PackageMatch(p, unitPrice, oppCurrency));
            } else if (nameFuzzy || codeFuzzy) {
                fuzzy.add(new PackageMatch(p, unitPrice, oppCurrency));
            }
        }

        List<PackageMatch> matches = !exact.isEmpty() ? exact : fuzzy;
        if (matches.size() > MAX_RESULTS) {
            matches = new List<PackageMatch>(matches);
            while (matches.size() > MAX_RESULTS) matches.remove(matches.size() - 1);
        }

        r.matchCount = matches.size();
        r.found = !matches.isEmpty();
        r.isUnique = matches.size() == 1;

        List<String> lines = new List<String>();
        for (PackageMatch m : matches) {
            String codeText = String.isBlank(m.pkg.ProductCode) ? '' : ' [' + m.pkg.ProductCode + ']';
            lines.add('• ' + m.pkg.Name + codeText + ' — ' + m.currencyIsoCode + ' ' + m.unitPrice.format());
        }
        r.matchesSummary = String.join(lines, '\n');

        if (r.isUnique) {
            PackageMatch only = matches[0];
            r.resolvedId = String.valueOf(only.pkg.Id);
            r.singleMatchName = only.pkg.Name;
            r.singleMatchCode = only.pkg.ProductCode;
            r.unitPrice = only.unitPrice;
            r.currencyIsoCode = only.currencyIsoCode;
            r.message = '패키지 "' + only.pkg.Name + '"를 선택했습니다 (' + only.currencyIsoCode + ' ' + only.unitPrice.format() + ').';
        } else if (!r.found) {
            r.message = '"' + term + '"과(와) 일치하는 활성 Sponsorship Package를 찾지 못했습니다. 패키지 이름이나 코드를 다시 확인해 주세요.';
        } else {
            r.message = '"' + term + '"에 여러 패키지가 일치합니다. 어떤 패키지인지 정확히 지정해 주세요:\n' + r.matchesSummary;
        }
        return r;
    }

    private class PackageMatch {
        Product2 pkg;
        Decimal unitPrice;
        String currencyIsoCode;
        PackageMatch(Product2 pkg, Decimal unitPrice, String currencyIsoCode) {
            this.pkg = pkg;
            this.unitPrice = unitPrice;
            this.currencyIsoCode = currencyIsoCode;
        }
    }

    public class Request {
        @InvocableVariable(
            label='Search Term'
            description='The Sponsorship Package name or product code as the rep chose it from the list, e.g. "유니폼 소매 패치 광고" or "SPN-UNIFORM-SLEEVE".'
            required=true
        )
        public String searchTerm;

        @InvocableVariable(
            label='Opportunity Id'
            description='The Opportunity the proposal is for — decides the currency the package price is checked against. Bound server-side from the resolved Opportunity.'
            required=true
        )
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable(label='Found' description='Whether at least one sellable Sponsorship Package matched.')
        public Boolean found = false;

        @InvocableVariable(label='Is Unique' description='True when exactly one package matched — only then is a package resolved.')
        public Boolean isUnique = false;

        @InvocableVariable(label='Match Count' description='Number of matching packages (capped at 5).')
        public Decimal matchCount = 0;

        @InvocableVariable(label='Resolved Id' description='The matched Product2 Id as a string when isUnique is true, otherwise an empty string (never null). Bind THIS into resolved_proposal_package_id.')
        public String resolvedId = '';

        @InvocableVariable(label='Single Match Name' description='Name of the matched package, only when isUnique is true.')
        public String singleMatchName;

        @InvocableVariable(label='Single Match Code' description='Product code of the matched package, only when isUnique is true.')
        public String singleMatchCode;

        @InvocableVariable(label='Unit Price' description='Standard unit price of the matched package in the Opportunity currency, only when isUnique is true.')
        public Decimal unitPrice;

        @InvocableVariable(label='Currency Iso Code' description='Currency of the matched package price, only when isUnique is true.')
        public String currencyIsoCode;

        @InvocableVariable(label='Matches Summary' description='Formatted list of every matching package (name, code, price) for the rep to disambiguate when more than one matched.')
        public String matchesSummary;

        @InvocableVariable(label='Message' description='Human-readable Korean result — the pick, the ambiguity, or the miss. Safe to show the rep.')
        public String message;
    }
}

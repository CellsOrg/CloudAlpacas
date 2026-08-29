/**
 * Read-only. Returns the active Sponsorship Package catalogue for one Opportunity's
 * currency as a single human-readable digest string (name · code · standard unit price ·
 * currency), for the Proposal Assistant to show the rep. It is a MENU only — the rep then
 * names the package they want and FindSponsorshipPackage resolves it to a Product2 Id
 * deterministically. This action never returns a raw Product2 Id for the LLM to pass on.
 *
 * Contract is deliberately flat (found / packageCount / packageDigest) — no nested
 * @apexClassType list output, so the GenAiPlannerBundle retrieves cleanly.
 */
public with sharing class SponsorshipPackageLookup {

    @InvocableMethod(
        label='List Sponsorship Packages'
        description='Read-only. Returns the active Sponsorship Package catalogue (name, product code, standard unit price, currency) for an Opportunity as a formatted digest for the rep to choose from. Does not recommend a package.'
    )
    public static List<Result> execute(List<Request> requests) {
        // Bulk-collect the Opportunities we need a currency for.
        Set<Id> oppIds = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.opportunityId != null) {
                oppIds.add(req.opportunityId);
            }
        }
        Map<Id, Opportunity> oppById = oppIds.isEmpty()
            ? new Map<Id, Opportunity>()
            : new Map<Id, Opportunity>([
                SELECT Id, CurrencyIsoCode FROM Opportunity WHERE Id IN :oppIds WITH USER_MODE
            ]);

        // Active Sponsorship Package products, and their active Standard Price Book
        // entries keyed by product + currency. Direct PricebookEntry query (filtered by
        // the standard book Id) — a child subquery with a Pricebook2.IsStandard filter
        // does not reliably return test-created entries.
        Map<Id, Product2> pkgById = new Map<Id, Product2>([
            SELECT Id, Name, ProductCode
            FROM Product2
            WHERE RecordType.DeveloperName = 'Sponsorship_Package' AND IsActive = true
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
            Result r = new Result();

            String oppCurrency = null;
            if (req != null && req.opportunityId != null && oppById.containsKey(req.opportunityId)) {
                oppCurrency = (String) oppById.get(req.opportunityId).get('CurrencyIsoCode');
            }
            String filter = (req == null || String.isBlank(req.nameFilter))
                ? null
                : req.nameFilter.trim().toLowerCase();

            List<String> lines = new List<String>();
            for (Product2 p : pkgById.values()) {
                if (filter != null) {
                    Boolean nameHit = p.Name != null && p.Name.toLowerCase().contains(filter);
                    Boolean codeHit = p.ProductCode != null && p.ProductCode.toLowerCase().contains(filter);
                    if (!nameHit && !codeHit) {
                        continue;
                    }
                }
                PricebookEntry pbe = null;
                if (oppCurrency != null) {
                    pbe = pbeByProductCurrency.get(p.Id + '|' + oppCurrency);
                } else {
                    for (String key : pbeByProductCurrency.keySet()) {
                        if (key.startsWith(p.Id + '|')) { pbe = pbeByProductCurrency.get(key); break; }
                    }
                }
                if (pbe == null) {
                    // No standard price in the Opportunity's currency — not sellable here.
                    continue;
                }
                String priceText = pbe.CurrencyIsoCode + ' ' + pbe.UnitPrice.format();
                String codeText = String.isBlank(p.ProductCode) ? '' : ' [' + p.ProductCode + ']';
                lines.add('• ' + p.Name + codeText + ' — ' + priceText);
            }

            r.packageCount = lines.size();
            r.found = !lines.isEmpty();
            if (lines.isEmpty()) {
                r.packageDigest = oppCurrency == null
                    ? '판매 가능한 활성 Sponsorship Package가 없습니다.'
                    : oppCurrency + ' 통화로 판매 가능한 활성 Sponsorship Package가 없습니다.';
            } else {
                r.packageDigest = '활성 Sponsorship Package ' + lines.size() + '개:\n' + String.join(lines, '\n');
            }
            results.add(r);
        }
        return results;
    }

    public class Request {
        @InvocableVariable(
            label='Name Filter'
            description='Optional. When the rep is looking for a particular kind of package, part of the package name or product code to filter the list by (case-insensitive). Leave blank to return the whole catalogue.'
            required=false
        )
        public String nameFilter;

        @InvocableVariable(
            label='Opportunity Id'
            description='Optional. The Opportunity the proposal is for — when provided, prices are shown in that Opportunity\'s currency and packages with no standard price in that currency are omitted.'
            required=false
        )
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable(label='Found' description='True when at least one active Sponsorship Package is sellable for this request.')
        public Boolean found = false;

        @InvocableVariable(label='Package Count' description='Number of packages in the digest.')
        public Integer packageCount = 0;

        @InvocableVariable(label='Package Digest' description='Human-readable list of the active Sponsorship Packages — one per line, name · product code · standard unit price · currency. A menu for the rep to pick from; states plainly when none are available.')
        public String packageDigest;
    }
}

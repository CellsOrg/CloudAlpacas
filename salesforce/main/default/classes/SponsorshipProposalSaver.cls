/**
 * Saves a confirmed Sponsorship Proposal for one Opportunity.
 *
 * Existing-Quote policy (원개발자 확인: "기존 Quote가 있을 시엔 업데이트하는 방향으로 설계"):
 *   - Opportunity.SyncedQuoteId set  -> that Quote is the target. It is synced to the
 *     Opportunity (and may carry a revenue schedule), so line items are NOT touched here;
 *     only the Opportunity proposal-draft fields are saved. Line changes go through the
 *     Negotiation Assistant / manual editing.
 *   - Exactly one Quote, not synced  -> update that Quote: reprice the matching-package
 *     line in place, or add the line only when the Quote has no lines yet. A Quote that
 *     already carries a DIFFERENT package line is rejected (a package swap cannot be
 *     expressed safely from here).
 *   - No Quote                        -> create a new Quote + one QuoteLineItem.
 *   - Two or more Quotes, none synced -> ambiguous: nothing is changed; the candidates
 *     are returned for the rep to disambiguate.
 *
 * Every path is one transaction guarded by a savepoint: validate -> Quote/line mutation
 * -> Opportunity field update -> success, and any failure rolls the whole thing back and
 * returns a safe Korean message (never a raw Salesforce exception).
 */
public with sharing class SponsorshipProposalSaver {

    private static final Integer BENEFIT_MAX_LENGTH = 1000;
    private static final String SPONSORSHIP_PACKAGE_RT = 'Sponsorship_Package';

    // Decision 018-G canonical Target Segment values. Used when the org field does not
    // expose picklist values (it is currently Text(255) in this org — repo/org drift);
    // once the canonical restricted picklist is deployed, the live picklist wins.
    private static final Set<String> CANONICAL_TARGET_SEGMENTS = new Set<String>{
        '10-30 Female', '10-30 Male', '40-60 Female', '40-60 Male', 'Family', 'etc'
    };

    @InvocableMethod(
        label='Save Sponsorship Proposal'
        description='Saves a confirmed Sponsorship Proposal: updates the Opportunity\'s existing Quote for the selected package (or creates one when there is none), and writes the confirmed expected-benefit draft / target segment onto the Opportunity. One transaction, rolled back on any failure.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        // ---- bulk pre-load -------------------------------------------------------
        Set<Id> oppIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.opportunityId != null) oppIds.add(req.opportunityId);
            if (req != null && req.productId != null) productIds.add(req.productId);
        }

        Map<Id, Opportunity> oppById = new Map<Id, Opportunity>([
            SELECT Id, Name, CurrencyIsoCode, SyncedQuoteId, Pricebook2Id
            FROM Opportunity WHERE Id IN :oppIds WITH USER_MODE
        ]);

        Map<Id, Product2> productById = new Map<Id, Product2>([
            SELECT Id, Name, IsActive, RecordType.DeveloperName
            FROM Product2 WHERE Id IN :productIds WITH USER_MODE
        ]);

        // Standard, active PBEs for the requested products, keyed by product + currency.
        // Filter by the standard book Id (a Pricebook2.IsStandard filter does not reliably
        // match test-created entries).
        Id standardPbId = (Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true WITH USER_MODE LIMIT 1].Id);
        Map<String, PricebookEntry> pbeByProductCurrency = new Map<String, PricebookEntry>();
        if (!productIds.isEmpty()) {
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id, Pricebook2Id, UnitPrice, CurrencyIsoCode
                FROM PricebookEntry
                WHERE Product2Id IN :productIds
                  AND Pricebook2Id = :standardPbId
                  AND IsActive = true
                WITH USER_MODE
            ]) {
                pbeByProductCurrency.put(pbe.Product2Id + '|' + pbe.CurrencyIsoCode, pbe);
            }
        }

        Map<Id, List<Quote>> quotesByOppId = new Map<Id, List<Quote>>();
        for (Quote q : [
            SELECT Id, Name, OpportunityId, Status, Pricebook2Id
            FROM Quote WHERE OpportunityId IN :oppIds WITH USER_MODE
            ORDER BY CreatedDate ASC
        ]) {
            if (!quotesByOppId.containsKey(q.OpportunityId)) {
                quotesByOppId.put(q.OpportunityId, new List<Quote>());
            }
            quotesByOppId.get(q.OpportunityId).add(q);
        }

        Set<Id> allQuoteIds = new Set<Id>();
        for (List<Quote> qs : quotesByOppId.values()) {
            for (Quote q : qs) allQuoteIds.add(q.Id);
        }
        Map<Id, List<QuoteLineItem>> qlisByQuoteId = new Map<Id, List<QuoteLineItem>>();
        if (!allQuoteIds.isEmpty()) {
            for (QuoteLineItem qli : [
                SELECT Id, QuoteId, Product2Id, PricebookEntryId, UnitPrice, Quantity,
                       Discount, HasRevenueSchedule
                FROM QuoteLineItem WHERE QuoteId IN :allQuoteIds WITH USER_MODE
            ]) {
                if (!qlisByQuoteId.containsKey(qli.QuoteId)) {
                    qlisByQuoteId.put(qli.QuoteId, new List<QuoteLineItem>());
                }
                qlisByQuoteId.get(qli.QuoteId).add(qli);
            }
        }

        Set<String> allowedSegments = resolveAllowedSegments();

        // ---- per request --------------------------------------------------------
        for (Request req : requests) {
            results.add(processOne(req, oppById, productById, pbeByProductCurrency,
                                   quotesByOppId, qlisByQuoteId, allowedSegments));
        }
        return results;
    }

    private static Result processOne(
        Request req,
        Map<Id, Opportunity> oppById,
        Map<Id, Product2> productById,
        Map<String, PricebookEntry> pbeByProductCurrency,
        Map<Id, List<Quote>> quotesByOppId,
        Map<Id, List<QuoteLineItem>> qlisByQuoteId,
        Set<String> allowedSegments
    ) {
        Result r = new Result();

        // ---- validation (no DML) ----
        if (req == null || req.opportunityId == null) {
            return fail(r, 'Opportunity를 특정하지 못했습니다. 저장할 Opportunity를 먼저 확인해 주세요.');
        }
        Opportunity opp = oppById.get(req.opportunityId);
        if (opp == null) {
            return fail(r, '해당 Opportunity를 찾을 수 없습니다. Opportunity를 다시 확인해 주세요.');
        }
        if (req.productId == null) {
            return fail(r, '선택된 Sponsorship Package가 없습니다. 패키지를 먼저 선택해 주세요.');
        }
        Product2 product = productById.get(req.productId);
        if (product == null) {
            return fail(r, '선택된 Sponsorship Package를 찾을 수 없습니다. 패키지를 다시 선택해 주세요.');
        }
        if (product.IsActive != true) {
            return fail(r, '선택된 Sponsorship Package("' + product.Name + '")가 비활성 상태여서 제안에 사용할 수 없습니다.');
        }
        if (product.RecordType == null || product.RecordType.DeveloperName != SPONSORSHIP_PACKAGE_RT) {
            return fail(r, '선택된 상품("' + product.Name + '")은 Sponsorship Package가 아니어서 제안에 사용할 수 없습니다.');
        }
        String oppCurrency = (String) opp.get('CurrencyIsoCode');
        PricebookEntry pbe = pbeByProductCurrency.get(req.productId + '|' + oppCurrency);
        if (pbe == null) {
            return fail(r, '선택된 패키지("' + product.Name + '")에 이 Opportunity의 통화(' + oppCurrency
                + ')로 등록된 표준 가격이 없어 제안을 저장할 수 없습니다.');
        }

        String benefitError = validateBenefitLengths(req);
        if (benefitError != null) {
            return fail(r, benefitError);
        }
        if (String.isNotBlank(req.targetSegment) && !allowedSegments.contains(req.targetSegment)) {
            return fail(r, 'Target Segment 값("' + req.targetSegment + '")이 허용된 세그먼트가 아닙니다. 허용값: '
                + String.join(new List<String>(allowedSegments), ', '));
        }

        // ---- determine the Quote strategy ----
        List<Quote> quotes = quotesByOppId.containsKey(opp.Id)
            ? quotesByOppId.get(opp.Id) : new List<Quote>();

        Quote target = null;
        String mode;
        if (opp.SyncedQuoteId != null) {
            for (Quote q : quotes) {
                if (q.Id == opp.SyncedQuoteId) { target = q; break; }
            }
            mode = 'SYNCED';
        } else if (quotes.isEmpty()) {
            mode = 'CREATE';
        } else if (quotes.size() == 1) {
            target = quotes[0];
            mode = 'UPDATE';
        } else {
            mode = 'AMBIGUOUS';
        }

        Boolean hasOppFieldUpdate = String.isNotBlank(req.shortTermBenefit)
            || String.isNotBlank(req.midTermBenefit)
            || String.isNotBlank(req.longTermBenefit)
            || String.isNotBlank(req.targetSegment);

        if (mode == 'AMBIGUOUS') {
            List<String> lines = new List<String>();
            for (Quote q : quotes) {
                lines.add('- ' + q.Name + ' (' + q.Status + ', Id ' + q.Id + ')');
            }
            r.ambiguous = true;
            return fail(r, '이 Opportunity에는 Quote가 ' + quotes.size()
                + '개 있고 Opportunity에 동기화된 Quote도 지정되어 있지 않아, 어느 Quote를 업데이트할지 자동으로 정할 수 없습니다. '
                + '업데이트할 Quote를 지정해 주세요:\n' + String.join(lines, '\n'));
        }

        // ---- mutation (savepoint-guarded) ----
        Savepoint sp = Database.setSavepoint();
        try {
            Boolean lineChanged = false;

            if (mode == 'CREATE') {
                Id pricebookId = pbe.Pricebook2Id != null ? pbe.Pricebook2Id : resolveStandardPricebookId();
                Quote newQuote = new Quote(
                    Name = resolveQuoteName(req, opp),
                    OpportunityId = opp.Id,
                    Pricebook2Id = pricebookId,
                    CurrencyIsoCode = oppCurrency
                );
                insert as user newQuote;
                insert as user new QuoteLineItem(
                    QuoteId = newQuote.Id,
                    PricebookEntryId = pbe.Id,
                    Quantity = 1,
                    UnitPrice = pbe.UnitPrice
                );
                r.quoteId = newQuote.Id;
                r.quoteName = newQuote.Name;
                r.quoteWasCreated = true;
                lineChanged = true;

            } else if (mode == 'UPDATE') {
                r.quoteId = target.Id;
                r.quoteName = target.Name;
                List<QuoteLineItem> lines = qlisByQuoteId.containsKey(target.Id)
                    ? qlisByQuoteId.get(target.Id) : new List<QuoteLineItem>();

                QuoteLineItem matching = null;
                for (QuoteLineItem qli : lines) {
                    if (qli.Product2Id == req.productId) { matching = qli; break; }
                }

                if (matching != null) {
                    if (matching.HasRevenueSchedule) {
                        // Repricing a revenue-scheduled line would disturb the schedule.
                        r.lineItemNote = '선택한 패키지 라인에 매출 일정(Revenue Schedule)이 설정되어 있어 '
                            + '단가를 자동으로 조정하지 않았습니다. 라인 조건은 Negotiation Assistant에서 확인해 주세요.';
                    } else if (matching.UnitPrice != pbe.UnitPrice) {
                        update as user new QuoteLineItem(Id = matching.Id, UnitPrice = pbe.UnitPrice);
                        lineChanged = true;
                    }
                } else if (lines.isEmpty()) {
                    insert as user new QuoteLineItem(
                        QuoteId = target.Id,
                        PricebookEntryId = pbe.Id,
                        Quantity = 1,
                        UnitPrice = pbe.UnitPrice
                    );
                    lineChanged = true;
                } else {
                    // Quote already carries a different package — a swap is not safe here.
                    Database.rollback(sp);
                    return fail(r, '이 Opportunity의 Quote("' + target.Name + '")에는 이미 다른 패키지 라인이 있어, '
                        + '제안 패키지를 자동으로 교체할 수 없습니다. 기존 라인 정리는 Negotiation Assistant 또는 '
                        + '수동으로 진행한 뒤 다시 저장해 주세요.');
                }
                r.quoteWasUpdated = true;

            } else { // SYNCED
                if (target == null) {
                    // SyncedQuoteId points at a Quote the running user cannot see.
                    Database.rollback(sp);
                    return fail(r, '이 Opportunity에 동기화된 Quote를 조회할 수 없습니다. 접근 권한을 확인해 주세요.');
                }
                r.quoteId = target.Id;
                r.quoteName = target.Name;
                r.lineItemNote = '이 Opportunity의 Quote("' + target.Name + '")는 Opportunity와 동기화(Synced)되어 있어 '
                    + '제안 라인 아이템을 자동으로 변경하지 않았습니다. 견적 라인 조정은 Negotiation Assistant '
                    + '또는 수동으로 진행해 주세요.';
                if (!hasOppFieldUpdate) {
                    Database.rollback(sp);
                    return fail(r, r.lineItemNote + ' 저장할 기대효과·타겟 세그먼트 초안도 전달되지 않아 변경된 내용이 없습니다.');
                }
                r.quoteWasUpdated = true;
            }

            // ---- Opportunity proposal-draft fields ----
            if (hasOppFieldUpdate) {
                Opportunity oppUpdate = new Opportunity(Id = opp.Id);
                if (String.isNotBlank(req.shortTermBenefit)) oppUpdate.Expected_Benefit_Short_Term__c = req.shortTermBenefit;
                if (String.isNotBlank(req.midTermBenefit)) oppUpdate.Expected_Benefit_Mid_Term__c = req.midTermBenefit;
                if (String.isNotBlank(req.longTermBenefit)) oppUpdate.Expected_Benefit_Long_Term__c = req.longTermBenefit;
                if (String.isNotBlank(req.targetSegment)) oppUpdate.Target_Segment__c = req.targetSegment;
                update as user oppUpdate;
                r.opportunityUpdated = true;
            }

            r.lineItemChanged = lineChanged;
            r.success = true;
            r.message = buildSuccessMessage(r, product);
            return r;

        } catch (Exception e) {
            Database.rollback(sp);
            return fail(r, '제안서를 저장하는 중 오류가 발생해 아무것도 저장되지 않았습니다: ' + safeError(e));
        }
    }

    // ------------------------------------------------------------------------------
    private static String validateBenefitLengths(Request req) {
        if (String.isNotBlank(req.shortTermBenefit) && req.shortTermBenefit.length() > BENEFIT_MAX_LENGTH) {
            return '단기 기대효과 초안이 ' + BENEFIT_MAX_LENGTH + '자를 초과했습니다(현재 '
                + req.shortTermBenefit.length() + '자). 줄여서 다시 저장해 주세요.';
        }
        if (String.isNotBlank(req.midTermBenefit) && req.midTermBenefit.length() > BENEFIT_MAX_LENGTH) {
            return '중기 기대효과 초안이 ' + BENEFIT_MAX_LENGTH + '자를 초과했습니다(현재 '
                + req.midTermBenefit.length() + '자). 줄여서 다시 저장해 주세요.';
        }
        if (String.isNotBlank(req.longTermBenefit) && req.longTermBenefit.length() > BENEFIT_MAX_LENGTH) {
            return '장기 기대효과 초안이 ' + BENEFIT_MAX_LENGTH + '자를 초과했습니다(현재 '
                + req.longTermBenefit.length() + '자). 줄여서 다시 저장해 주세요.';
        }
        return null;
    }

    private static Set<String> resolveAllowedSegments() {
        Set<String> live = new Set<String>();
        for (Schema.PicklistEntry e : Opportunity.Target_Segment__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) live.add(e.getValue());
        }
        return live.isEmpty() ? CANONICAL_TARGET_SEGMENTS : live;
    }

    private static Id resolveStandardPricebookId() {
        return (Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true WITH USER_MODE LIMIT 1].Id);
    }

    private static String resolveQuoteName(Request req, Opportunity opp) {
        if (String.isNotBlank(req.quoteName)) {
            return req.quoteName.length() > 80 ? req.quoteName.substring(0, 80) : req.quoteName;
        }
        String base = opp.Name + ' - Sponsorship Proposal';
        return base.length() > 80 ? base.substring(0, 80) : base;
    }

    private static String buildSuccessMessage(Result r, Product2 product) {
        String head;
        if (r.quoteWasCreated) {
            head = '새 Quote("' + r.quoteName + '")를 만들고 "' + product.Name + '" 패키지 라인을 추가했습니다.';
        } else if (r.lineItemChanged) {
            head = '기존 Quote("' + r.quoteName + '")의 "' + product.Name + '" 패키지 라인을 갱신했습니다.';
        } else {
            head = '기존 Quote("' + r.quoteName + '")를 확인했습니다.';
        }
        if (r.opportunityUpdated) {
            head += ' 기대효과·타겟 세그먼트 초안을 Opportunity에 저장했습니다(AI가 작성한 제안 초안입니다).';
        }
        if (String.isNotBlank(r.lineItemNote)) {
            head += ' ' + r.lineItemNote;
        }
        return head;
    }

    private static Result fail(Result r, String message) {
        r.success = false;
        r.message = message;
        return r;
    }

    private static String safeError(Exception e) {
        if (e instanceof DmlException) {
            DmlException de = (DmlException) e;
            return de.getNumDml() > 0 ? de.getDmlMessage(0) : de.getMessage();
        }
        return e.getMessage();
    }

    // ------------------------------------------------------------------------------
    public class Request {
        @InvocableVariable(
            label='Opportunity Id'
            description='Opportunity the proposal is for. Bound server-side from the resolved Opportunity — not free text.'
            required=true
        )
        public Id opportunityId;

        @InvocableVariable(
            label='Product Id'
            description='Selected Sponsorship Package Product2 Id. Bound server-side from the resolved package — not free text.'
            required=true
        )
        public Id productId;

        @InvocableVariable(
            label='Quote Name'
            description='Optional. Name for a newly created Quote. Ignored when an existing Quote is updated. Defaults to "<Opportunity> - Sponsorship Proposal".'
            required=false
        )
        public String quoteName;

        @InvocableVariable(label='Short-Term Benefit' description='Confirmed short-term expected-benefit draft to write to Opportunity.Expected_Benefit_Short_Term__c (max 1000 chars). Leave blank to keep the current value.' required=false)
        public String shortTermBenefit;

        @InvocableVariable(label='Mid-Term Benefit' description='Confirmed mid-term expected-benefit draft to write to Opportunity.Expected_Benefit_Mid_Term__c (max 1000 chars). Leave blank to keep the current value.' required=false)
        public String midTermBenefit;

        @InvocableVariable(label='Long-Term Benefit' description='Confirmed long-term expected-benefit draft to write to Opportunity.Expected_Benefit_Long_Term__c (max 1000 chars). Leave blank to keep the current value.' required=false)
        public String longTermBenefit;

        @InvocableVariable(label='Target Segment' description='Confirmed Target Segment to write to Opportunity.Target_Segment__c. Must be one of the allowed Decision 018-G values. Leave blank to keep the current value.' required=false)
        public String targetSegment;
    }

    public class Result {
        @InvocableVariable(label='Success' description='True only when the proposal was saved (or, for a synced Quote, the Opportunity draft was saved).')
        public Boolean success = false;

        @InvocableVariable(label='Message' description='Human-readable Korean result — what was saved, or why nothing was. Safe to show the rep.')
        public String message;

        @InvocableVariable(label='Quote Id' description='Id of the created or updated Quote. Empty when nothing was saved.')
        public Id quoteId;

        @InvocableVariable(label='Quote Name' description='Name of the created or updated Quote.')
        public String quoteName;

        @InvocableVariable(label='Quote Was Created' description='True when a new Quote was created.')
        public Boolean quoteWasCreated = false;

        @InvocableVariable(label='Quote Was Updated' description='True when an existing Quote was the target.')
        public Boolean quoteWasUpdated = false;

        @InvocableVariable(label='Line Item Changed' description='True when a QuoteLineItem was added or repriced.')
        public Boolean lineItemChanged = false;

        @InvocableVariable(label='Opportunity Updated' description='True when expected-benefit / target-segment fields were written to the Opportunity.')
        public Boolean opportunityUpdated = false;

        @InvocableVariable(label='Ambiguous' description='True when the save was blocked because more than one Quote exists and none is synced.')
        public Boolean ambiguous = false;

        @InvocableVariable(label='Line Item Note' description='Set when line items were deliberately left unchanged (synced or revenue-scheduled Quote).')
        public String lineItemNote;
    }
}

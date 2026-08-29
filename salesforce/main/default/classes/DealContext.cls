/**
 * DealContext — read-only Opportunity-level snapshot for the (future) Deal Assistant subagent.
 *
 * Returns ONLY:
 *   A. Stored facts   — values a person or an existing Flow already wrote to Salesforce
 *   B. Derived facts  — threshold-free arithmetic on those stored facts (today - someDate, counts)
 *
 * It deliberately does NOT return:
 *   - a deal health score / risk score / grade
 *   - a win probability (beyond passing through Opportunity.Probability, clearly labelled)
 *   - an "isStalled" / "stalledReason" flag  (needs a business threshold that is not defined anywhere in the repo/org)
 *   - a recommended next action / next best action  (that is an LLM judgement, not an Apex fact)
 * Those interpretations belong to the Deal Assistant's reasoning layer, on top of this snapshot,
 * with the evidence visible.
 *
 * Deterministic-derived fields are computed relative to Date.today() / Datetime.now() at call time.
 *
 * Reuses the existing Flow-maintained Opportunity fields (CA_Update_Opportunity_Next_Activity /
 * CA_Update_Opportunity_Last_Contact_From_*) and the interaction signals produced by
 * InteractionIntelligenceParser — it does not re-derive them from raw activity text.
 */
public with sharing class DealContext {

    @InvocableMethod(
        label='Get Deal Context'
        description='Read-only Opportunity-level snapshot: stage / amount / close date / forecast category, the Flow-maintained contact-cadence and open/overdue task fields, qualification picklists, quote presence, and an aggregate of the stored interaction signals. Returns stored facts and threshold-free derived counts only — no health score, risk score, win probability, stalled flag, or recommended action.'
    )
    public static List<Result> execute(List<Request> requests) {
        Set<Id> oppIds = new Set<Id>();
        for (Request req : requests) {
            if (req.opportunityId != null) {
                oppIds.add(req.opportunityId);
            }
        }

        Map<Id, Opportunity> oppsById = new Map<Id, Opportunity>();
        if (!oppIds.isEmpty()) {
            oppsById = new Map<Id, Opportunity>([
                SELECT Id, Name, Account.Name, StageName, IsClosed, IsWon,
                       Amount, Probability, ForecastCategoryName, CloseDate, CreatedDate,
                       LastStageChangeDate, LastActivityDate, NextStep,
                       Last_Contact_Date__c, Last_Contact_Type__c, Days_Since_Last_Contact__c,
                       Next_Activity_Date__c, Next_Activity_Subject__c,
                       Open_Tasks_Count__c, Overdue_Tasks_Count__c,
                       Decision_Maker_Accessible__c, Brand_Fan_Fit__c, Sponsorship_Interest_Level__c,
                       Expected_Timing__c, Client_Budget_Status__c, Partner_Tier__c,
                       Deal_Note__c, SDO_Sales_Reason_Lost__c,
                       SyncedQuoteId,
                       SDO_Sales_Primary_Contact__c, SDO_Sales_Primary_Contact__r.Name
                FROM Opportunity
                WHERE Id IN :oppIds
                WITH USER_MODE
            ]);
        }

        // Quotes on these Opportunities (all of them — the caller decides what "latest" means).
        Map<Id, List<Quote>> quotesByOppId = new Map<Id, List<Quote>>();
        if (!oppIds.isEmpty()) {
            for (Quote q : [
                SELECT Id, OpportunityId, Status, CreatedDate
                FROM Quote
                WHERE OpportunityId IN :oppIds
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ]) {
                if (!quotesByOppId.containsKey(q.OpportunityId)) {
                    quotesByOppId.put(q.OpportunityId, new List<Quote>());
                }
                quotesByOppId.get(q.OpportunityId).add(q);
            }
        }

        // Interaction Intelligence (interaction-level records already produced by the II pipeline).
        Map<Id, List<Interaction_Intelligence__c>> intelByOppId = new Map<Id, List<Interaction_Intelligence__c>>();
        if (!oppIds.isEmpty()) {
            for (Interaction_Intelligence__c ii : [
                SELECT Id, Opportunity__c, CreatedDate, Concerns_Objections__c
                FROM Interaction_Intelligence__c
                WHERE Opportunity__c IN :oppIds
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ]) {
                if (!intelByOppId.containsKey(ii.Opportunity__c)) {
                    intelByOppId.put(ii.Opportunity__c, new List<Interaction_Intelligence__c>());
                }
                intelByOppId.get(ii.Opportunity__c).add(ii);
            }
        }

        // Stored interaction signals, aggregated per Opportunity (counts only — no interpretation).
        Map<Id, SignalTally> tallyByOppId = new Map<Id, SignalTally>();
        if (!oppIds.isEmpty()) {
            for (Interaction_Signal__c s : [
                SELECT Id, Signal_Category__c, Direction__c,
                       Interaction_Intelligence__r.Opportunity__c
                FROM Interaction_Signal__c
                WHERE Interaction_Intelligence__r.Opportunity__c IN :oppIds
                WITH USER_MODE
            ]) {
                Id oppId = s.Interaction_Intelligence__r.Opportunity__c;
                if (!tallyByOppId.containsKey(oppId)) {
                    tallyByOppId.put(oppId, new SignalTally());
                }
                tallyByOppId.get(oppId).add(s.Signal_Category__c, s.Direction__c);
            }
        }

        Date today = Date.today();

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            Opportunity opp = oppsById.get(req.opportunityId);
            if (opp == null) {
                r.found = false;
                results.add(r);
                continue;
            }
            r.found = true;

            // ---- A. Stored facts -------------------------------------------------
            r.opportunityName = opp.Name;
            r.accountName = opp.Account != null ? opp.Account.Name : null;
            r.stageName = opp.StageName;
            r.isClosed = opp.IsClosed;
            r.isWon = opp.IsWon;
            r.amount = opp.Amount;
            r.probability = opp.Probability;
            r.forecastCategory = opp.ForecastCategoryName;
            r.closeDate = opp.CloseDate;
            r.createdDate = opp.CreatedDate;
            r.lastStageChangeDate = opp.LastStageChangeDate;
            r.lastActivityDate = opp.LastActivityDate;
            r.nextStep = opp.NextStep;

            r.lastContactDate = opp.Last_Contact_Date__c;
            r.lastContactType = opp.Last_Contact_Type__c;
            r.daysSinceLastContactField = opp.Days_Since_Last_Contact__c;
            r.nextActivityDate = opp.Next_Activity_Date__c;
            r.nextActivitySubject = opp.Next_Activity_Subject__c;
            r.openTaskCount = opp.Open_Tasks_Count__c;
            r.overdueTaskCount = opp.Overdue_Tasks_Count__c;

            r.decisionMakerAccessible = opp.Decision_Maker_Accessible__c;
            r.brandFanFit = opp.Brand_Fan_Fit__c;
            r.interestLevel = opp.Sponsorship_Interest_Level__c;
            r.expectedTiming = opp.Expected_Timing__c;
            r.clientBudgetStatus = opp.Client_Budget_Status__c;
            r.partnerTier = opp.Partner_Tier__c;
            r.dealNote = opp.Deal_Note__c;
            r.reasonLost = opp.SDO_Sales_Reason_Lost__c;

            r.hasPrimaryContact = opp.SDO_Sales_Primary_Contact__c != null;
            r.primaryContactName = opp.SDO_Sales_Primary_Contact__r != null
                ? opp.SDO_Sales_Primary_Contact__r.Name : null;

            // ---- Quote state (A + B) ------------------------------------------
            List<Quote> quotes = quotesByOppId.get(opp.Id);
            r.quoteCount = quotes == null ? 0 : quotes.size();
            r.hasSyncedQuote = opp.SyncedQuoteId != null;
            if (quotes != null && !quotes.isEmpty()) {
                r.latestQuoteStatus = quotes[0].Status;         // ORDER BY CreatedDate DESC
                r.latestQuoteCreatedDate = quotes[0].CreatedDate;
                if (opp.SyncedQuoteId != null) {
                    for (Quote q : quotes) {
                        if (q.Id == opp.SyncedQuoteId) {
                            r.syncedQuoteStatus = q.Status;
                        }
                    }
                }
            }

            // ---- Interaction intelligence rollup (A + B) --------------------
            List<Interaction_Intelligence__c> intel = intelByOppId.get(opp.Id);
            r.hasInteractionIntelligence = intel != null && !intel.isEmpty();
            r.interactionCount = intel == null ? 0 : intel.size();
            if (intel != null && !intel.isEmpty()) {
                r.latestInteractionDate = intel[0].CreatedDate;     // ORDER BY CreatedDate DESC
                r.latestConcernsObjections = intel[0].Concerns_Objections__c;
            }

            SignalTally tally = tallyByOppId.get(opp.Id);
            if (tally != null) {
                r.signalCount = tally.total;
                r.negativeSignalCount = tally.negative;
                r.positiveSignalCount = tally.positive;
                r.riskCategoryCount = tally.byCategory.containsKey('RISK') ? tally.byCategory.get('RISK') : 0;
                r.competitionCategoryCount = tally.byCategory.containsKey('COMPETITION') ? tally.byCategory.get('COMPETITION') : 0;
                r.momentumNegativeCount = tally.momentumNegative;
                r.signalCategoryBreakdown = tally.render();
            } else {
                r.signalCount = 0;
                r.negativeSignalCount = 0;
                r.positiveSignalCount = 0;
                r.riskCategoryCount = 0;
                r.competitionCategoryCount = 0;
                r.momentumNegativeCount = 0;
            }

            // ---- B. Derived facts (threshold-free arithmetic) ---------------
            if (opp.CreatedDate != null) {
                r.daysOpen = opp.CreatedDate.date().daysBetween(today);
            }
            if (opp.CloseDate != null) {
                r.daysUntilClose = today.daysBetween(opp.CloseDate);
                r.closeDateIsPast = !opp.IsClosed && opp.CloseDate < today;
            }
            if (opp.LastStageChangeDate != null) {
                r.daysSinceLastStageChange = opp.LastStageChangeDate.date().daysBetween(today);
            }
            if (opp.LastActivityDate != null) {
                r.daysSinceLastActivity = opp.LastActivityDate.daysBetween(today);
            }
            if (r.latestInteractionDate != null) {
                r.daysSinceLatestInteraction = r.latestInteractionDate.date().daysBetween(today);
            }

            results.add(r);
        }
        return results;
    }

    /** Per-Opportunity signal counter. Counts only — no scoring, no interpretation. */
    private class SignalTally {
        Integer total = 0;
        Integer negative = 0;
        Integer positive = 0;
        Integer momentumNegative = 0;
        Map<String, Integer> byCategory = new Map<String, Integer>();
        Map<String, Integer> byCategoryNegative = new Map<String, Integer>();

        void add(String category, String direction) {
            total++;
            String cat = String.isBlank(category) ? '(uncategorised)' : category;
            byCategory.put(cat, (byCategory.containsKey(cat) ? byCategory.get(cat) : 0) + 1);
            if (direction == 'Negative') {
                negative++;
                byCategoryNegative.put(cat, (byCategoryNegative.containsKey(cat) ? byCategoryNegative.get(cat) : 0) + 1);
                if (cat == 'MOMENTUM') {
                    momentumNegative++;
                }
            } else if (direction == 'Positive') {
                positive++;
            }
        }

        String render() {
            List<String> parts = new List<String>();
            List<String> cats = new List<String>(byCategory.keySet());
            cats.sort();
            for (String c : cats) {
                Integer neg = byCategoryNegative.containsKey(c) ? byCategoryNegative.get(c) : 0;
                parts.add(c + ': ' + byCategory.get(c) + (neg > 0 ? ' (Negative ' + neg + ')' : ''));
            }
            return String.join(parts, ' · ');
        }
    }

    public class Request {
        @InvocableVariable(
            label='Opportunity Id'
            description='Id of the Opportunity to snapshot.'
            required=true
        )
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable(label='Found' description='Whether an Opportunity was found for the given Id.')
        public Boolean found = false;

        // ---- A. Stored facts ----
        @InvocableVariable(label='Opportunity Name' description='Opportunity.Name (stored fact).')
        public String opportunityName;
        @InvocableVariable(label='Account Name' description='Opportunity.Account.Name (stored fact).')
        public String accountName;
        @InvocableVariable(label='Stage Name' description='Opportunity.StageName (stored fact). Pipeline: Qualification → Discovery → Proposal/Quote → Negotiation → Closed Won/Lost.')
        public String stageName;
        @InvocableVariable(label='Is Closed' description='Opportunity.IsClosed (stored fact).')
        public Boolean isClosed;
        @InvocableVariable(label='Is Won' description='Opportunity.IsWon (stored fact).')
        public Boolean isWon;
        @InvocableVariable(label='Amount' description='Opportunity.Amount (stored fact).')
        public Decimal amount;
        @InvocableVariable(label='Probability' description='Opportunity.Probability (%). This is the stage-linked / manually-set field, NOT an AI or ML win prediction — never present it as an "AI win probability".')
        public Decimal probability;
        @InvocableVariable(label='Forecast Category' description='Opportunity.ForecastCategoryName (stored fact, stage-derived).')
        public String forecastCategory;
        @InvocableVariable(label='Close Date' description='Opportunity.CloseDate (stored fact).')
        public Date closeDate;
        @InvocableVariable(label='Created Date' description='Opportunity.CreatedDate (stored fact).')
        public Datetime createdDate;
        @InvocableVariable(label='Last Stage Change Date' description='Opportunity.LastStageChangeDate (stored fact, platform-maintained; null if the stage has never changed since creation).')
        public Datetime lastStageChangeDate;
        @InvocableVariable(label='Last Activity Date' description='Opportunity.LastActivityDate (stored fact, platform-maintained date of the most recent activity).')
        public Date lastActivityDate;
        @InvocableVariable(label='Next Step' description='Opportunity.NextStep (stored fact, rep-entered free text).')
        public String nextStep;

        @InvocableVariable(label='Last Contact Date' description='Opportunity.Last_Contact_Date__c — most recent completed Customer Contact (Call/Email/Online/Offline Meeting). Maintained by the CA_Update_Opportunity_Last_Contact_From_* Flows.')
        public Datetime lastContactDate;
        @InvocableVariable(label='Last Contact Type' description='Opportunity.Last_Contact_Type__c (Flow-maintained).')
        public String lastContactType;
        @InvocableVariable(label='Days Since Last Contact (field)' description='Opportunity.Days_Since_Last_Contact__c — the stored platform formula FLOOR(NOW() - Last_Contact_Date__c). Can be null (no contact yet) or negative (a contact dated in the future). Passed through as-is.')
        public Decimal daysSinceLastContactField;
        @InvocableVariable(label='Next Activity Date' description='Opportunity.Next_Activity_Date__c — due date of the nearest open Task. Maintained by CA_Update_Opportunity_Next_Activity Flow.')
        public Date nextActivityDate;
        @InvocableVariable(label='Next Activity Subject' description='Opportunity.Next_Activity_Subject__c (Flow-maintained).')
        public String nextActivitySubject;
        @InvocableVariable(label='Open Task Count' description='Opportunity.Open_Tasks_Count__c — number of incomplete Tasks. Maintained by CA_Update_Opportunity_Next_Activity Flow.')
        public Decimal openTaskCount;
        @InvocableVariable(label='Overdue Task Count' description='Opportunity.Overdue_Tasks_Count__c — number of past-due incomplete Tasks. Maintained by CA_Update_Opportunity_Next_Activity Flow.')
        public Decimal overdueTaskCount;

        @InvocableVariable(label='Decision Maker Accessible' description='Opportunity.Decision_Maker_Accessible__c (rep-entered qualification picklist: 가능 / 부분 가능 / 불가·미확인).')
        public String decisionMakerAccessible;
        @InvocableVariable(label='Brand / Fan Fit' description='Opportunity.Brand_Fan_Fit__c (rep-entered qualification picklist: 높음 / 보통 / 낮음).')
        public String brandFanFit;
        @InvocableVariable(label='Interest Level' description='Opportunity.Sponsorship_Interest_Level__c (rep-entered qualification picklist).')
        public String interestLevel;
        @InvocableVariable(label='Expected Timing' description='Opportunity.Expected_Timing__c (rep-entered qualification picklist).')
        public String expectedTiming;
        @InvocableVariable(label='Client Budget Status' description='Opportunity.Client_Budget_Status__c (stored fact).')
        public String clientBudgetStatus;
        @InvocableVariable(label='Partner Tier' description='Opportunity.Partner_Tier__c (rep-selected reference signal).')
        public String partnerTier;
        @InvocableVariable(label='Deal Note' description='Opportunity.Deal_Note__c (rep-entered free text).')
        public String dealNote;
        @InvocableVariable(label='Reason Lost' description='Opportunity.SDO_Sales_Reason_Lost__c (stored fact — only meaningful on Closed Lost).')
        public String reasonLost;

        @InvocableVariable(label='Has Primary Contact' description='Whether Opportunity.SDO_Sales_Primary_Contact__c is set.')
        public Boolean hasPrimaryContact;
        @InvocableVariable(label='Primary Contact Name' description='Opportunity.SDO_Sales_Primary_Contact__r.Name (stored fact).')
        public String primaryContactName;

        @InvocableVariable(label='Quote Count' description='Total number of Quotes on this Opportunity (stored fact). An Opportunity can have several Quotes; this snapshot does not pick an authoritative one.')
        public Integer quoteCount;
        @InvocableVariable(label='Has Synced Quote' description='Whether Opportunity.SyncedQuoteId is set (the Quote Salesforce itself treats as authoritative for the Opportunity amount/lines).')
        public Boolean hasSyncedQuote;
        @InvocableVariable(label='Synced Quote Status' description='Status of the synced Quote, when one is set.')
        public String syncedQuoteStatus;
        @InvocableVariable(label='Latest Quote Status' description='Status of the most recently created Quote (ORDER BY CreatedDate DESC). NOT necessarily the synced/authoritative one.')
        public String latestQuoteStatus;
        @InvocableVariable(label='Latest Quote Created Date' description='CreatedDate of the most recently created Quote.')
        public Datetime latestQuoteCreatedDate;

        @InvocableVariable(label='Has Interaction Intelligence' description='Whether any Interaction_Intelligence__c record exists for this Opportunity.')
        public Boolean hasInteractionIntelligence;
        @InvocableVariable(label='Interaction Count' description='Number of Interaction_Intelligence__c records (stored fact).')
        public Integer interactionCount;
        @InvocableVariable(label='Latest Interaction Date' description='CreatedDate of the most recent Interaction_Intelligence__c record.')
        public Datetime latestInteractionDate;
        @InvocableVariable(label='Latest Concerns / Objections' description='Concerns_Objections__c of the most recent Interaction_Intelligence__c record (stored fact — the analysis already written for that interaction, quoted verbatim).')
        public String latestConcernsObjections;

        @InvocableVariable(label='Signal Count' description='Total number of stored Interaction_Signal__c records across all interactions on this Opportunity.')
        public Integer signalCount;
        @InvocableVariable(label='Negative Signal Count' description='Count of stored signals with Direction__c = Negative (deterministic count, not a score).')
        public Integer negativeSignalCount;
        @InvocableVariable(label='Positive Signal Count' description='Count of stored signals with Direction__c = Positive.')
        public Integer positiveSignalCount;
        @InvocableVariable(label='Risk Category Signal Count' description='Count of stored signals with Signal_Category__c = RISK (any direction).')
        public Integer riskCategoryCount;
        @InvocableVariable(label='Competition Category Signal Count' description='Count of stored signals with Signal_Category__c = COMPETITION (any direction).')
        public Integer competitionCategoryCount;
        @InvocableVariable(label='Negative Momentum Signal Count' description='Count of stored signals with Signal_Category__c = MOMENTUM and Direction__c = Negative.')
        public Integer momentumNegativeCount;
        @InvocableVariable(label='Signal Category Breakdown' description='Compact per-category tally of the stored signals, e.g. "BUDGET: 2 · MOMENTUM: 1 (Negative 1) · RISK: 2 (Negative 2)". Counts only.')
        public String signalCategoryBreakdown;

        // ---- B. Derived facts ----
        @InvocableVariable(label='Days Open' description='Derived: Date.today() minus Opportunity.CreatedDate (calendar days). Threshold-free.')
        public Integer daysOpen;
        @InvocableVariable(label='Days Until Close' description='Derived: Opportunity.CloseDate minus Date.today() (calendar days; negative means the close date is already past). Threshold-free.')
        public Integer daysUntilClose;
        @InvocableVariable(label='Close Date Is Past' description='Derived: CloseDate < today AND the Opportunity is not closed. A plain date comparison, not a risk judgement.')
        public Boolean closeDateIsPast;
        @InvocableVariable(label='Days Since Last Stage Change' description='Derived: Date.today() minus Opportunity.LastStageChangeDate (calendar days). Null when LastStageChangeDate is null. Threshold-free — does not imply the deal is "stuck".')
        public Integer daysSinceLastStageChange;
        @InvocableVariable(label='Days Since Last Activity' description='Derived: Date.today() minus Opportunity.LastActivityDate (calendar days). Null when there is no activity. Threshold-free.')
        public Integer daysSinceLastActivity;
        @InvocableVariable(label='Days Since Latest Interaction' description='Derived: Date.today() minus the most recent Interaction_Intelligence__c CreatedDate (calendar days). Null when there is no interaction intelligence. Threshold-free.')
        public Integer daysSinceLatestInteraction;
    }
}

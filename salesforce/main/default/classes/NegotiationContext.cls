public with sharing class NegotiationContext {

    private static final Integer HISTORY_LIMIT = 5;

    @InvocableMethod(
        label='Get Negotiation Context'
        description='Returns Opportunity budget/requirements fields, the most recent Quote and its line item summary, and recent interaction and activity history for use in negotiation.'
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
            oppsById = new Map<Id, Opportunity>(
                [SELECT Id, Name, Client_Budget__c, Client_Budget_Status__c,
                        Customer_Needs__c, Key_Requirements__c, Customer_KPI__c,
                        Target_Start_Season__c, Partner_Tier__c,
                        SDO_Sales_Primary_Contact__r.Name, SDO_Sales_Primary_Contact__r.Title,
                        SDO_Sales_Primary_Contact__r.Email, SDO_Sales_Primary_Contact__r.Phone
                 FROM Opportunity
                 WHERE Id IN :oppIds
                 WITH USER_MODE]
            );
        }

        Map<Id, Quote> latestQuoteByOppId = new Map<Id, Quote>();
        if (!oppIds.isEmpty()) {
            for (Quote q : [
                SELECT Id, Name, OpportunityId, Status, Discount, ExpirationDate, GrandTotal
                FROM Quote
                WHERE OpportunityId IN :oppIds
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ]) {
                if (!latestQuoteByOppId.containsKey(q.OpportunityId)) {
                    latestQuoteByOppId.put(q.OpportunityId, q);
                }
            }
        }

        Map<Id, List<QuoteLineItem>> lineItemsByQuoteId = new Map<Id, List<QuoteLineItem>>();
        if (!latestQuoteByOppId.isEmpty()) {
            Set<Id> quoteIds = new Set<Id>();
            for (Quote q : latestQuoteByOppId.values()) {
                quoteIds.add(q.Id);
            }
            for (QuoteLineItem qli : [
                SELECT Id, QuoteId, Quantity, UnitPrice, Discount, Subtotal, TotalPrice,
                       HasRevenueSchedule,
                       Product2.Name, Product2.Tier__c,
                       PricebookEntry.Max_Discount_Percent__c, PricebookEntry.Max_Discounted_Price__c
                FROM QuoteLineItem
                WHERE QuoteId IN :quoteIds
                WITH USER_MODE
            ]) {
                if (!lineItemsByQuoteId.containsKey(qli.QuoteId)) {
                    lineItemsByQuoteId.put(qli.QuoteId, new List<QuoteLineItem>());
                }
                lineItemsByQuoteId.get(qli.QuoteId).add(qli);
            }
        }

        Map<Id, List<Interaction_Intelligence__c>> intelHistoryByOppId = new Map<Id, List<Interaction_Intelligence__c>>();
        if (!oppIds.isEmpty()) {
            for (Interaction_Intelligence__c intel : [
                SELECT Id, Opportunity__c, CreatedDate, Concerns_Objections__c, Customer_Reaction__c,
                       Key_Decision__c, Follow_Up__c
                FROM Interaction_Intelligence__c
                WHERE Opportunity__c IN :oppIds
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ]) {
                if (!intelHistoryByOppId.containsKey(intel.Opportunity__c)) {
                    intelHistoryByOppId.put(intel.Opportunity__c, new List<Interaction_Intelligence__c>());
                }
                List<Interaction_Intelligence__c> history = intelHistoryByOppId.get(intel.Opportunity__c);
                if (history.size() < HISTORY_LIMIT) {
                    history.add(intel);
                }
            }
        }

        Map<Id, List<Task>> tasksByOppId = new Map<Id, List<Task>>();
        if (!oppIds.isEmpty()) {
            for (Task t : [
                SELECT Id, WhatId, ActivityDate, Subject, TaskSubtype, Status, Description
                FROM Task
                WHERE WhatId IN :oppIds
                WITH USER_MODE
                ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC
            ]) {
                if (!tasksByOppId.containsKey(t.WhatId)) {
                    tasksByOppId.put(t.WhatId, new List<Task>());
                }
                List<Task> tasks = tasksByOppId.get(t.WhatId);
                if (tasks.size() < HISTORY_LIMIT) {
                    tasks.add(t);
                }
            }
        }

        Map<Id, List<Event>> eventsByOppId = new Map<Id, List<Event>>();
        if (!oppIds.isEmpty()) {
            for (Event e : [
                SELECT Id, WhatId, ActivityDate, Subject, Description
                FROM Event
                WHERE WhatId IN :oppIds
                WITH USER_MODE
                ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC
            ]) {
                if (!eventsByOppId.containsKey(e.WhatId)) {
                    eventsByOppId.put(e.WhatId, new List<Event>());
                }
                List<Event> events = eventsByOppId.get(e.WhatId);
                if (events.size() < HISTORY_LIMIT) {
                    events.add(e);
                }
            }
        }

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            Opportunity opp = oppsById.get(req.opportunityId);
            if (opp == null) {
                results.add(r);
                continue;
            }

            r.opportunityName = opp.Name;
            r.clientBudget = opp.Client_Budget__c;
            r.clientBudgetStatus = opp.Client_Budget_Status__c;
            r.customerNeeds = opp.Customer_Needs__c;
            r.keyRequirements = opp.Key_Requirements__c;
            r.customerKPI = opp.Customer_KPI__c;
            r.targetStartSeason = opp.Target_Start_Season__c;
            r.partnerTier = opp.Partner_Tier__c;

            if (opp.SDO_Sales_Primary_Contact__r != null) {
                r.hasPrimaryContact = true;
                r.primaryContactName = opp.SDO_Sales_Primary_Contact__r.Name;
                r.primaryContactTitle = opp.SDO_Sales_Primary_Contact__r.Title;
                r.primaryContactEmail = opp.SDO_Sales_Primary_Contact__r.Email;
                r.primaryContactPhone = opp.SDO_Sales_Primary_Contact__r.Phone;
            } else {
                r.hasPrimaryContact = false;
            }

            Quote q = latestQuoteByOppId.get(opp.Id);
            if (q != null) {
                r.hasQuote = true;
                r.quoteId = q.Id;
                r.quoteName = q.Name;
                r.quoteStatus = q.Status;
                r.quoteExpirationDate = q.ExpirationDate;
                r.quoteGrandTotal = q.GrandTotal;

                List<QuoteLineItem> lineItems = lineItemsByQuoteId.get(q.Id);
                List<String> lines = new List<String>();
                for (QuoteLineItem qli : lineItems) {
                    lines.add(
                        qli.Product2.Name + ': 수량 ' + qli.Quantity
                        + ', 단가 ' + qli.UnitPrice
                        + ', 할인 ' + qli.Discount + '%'
                        + ', 소계 ' + qli.Subtotal
                    );
                }
                r.lineItemsSummary = String.join(lines, '\n');

                if (!lineItems.isEmpty()) {
                    QuoteLineItem primary = lineItems[0];
                    r.quoteLineItemId = primary.Id;
                    r.quoteDiscount = primary.Discount;
                    r.productTier = primary.Product2.Tier__c;
                    r.maxDiscountPercent = primary.PricebookEntry.Max_Discount_Percent__c;
                    r.maxDiscountedPrice = primary.PricebookEntry.Max_Discounted_Price__c;

                    // A revenue-scheduled line item's Discount is locked by the platform.
                    // Surface it so the agent can tell the user before asking them to
                    // confirm a discount change that cannot succeed.
                    r.lineItemDiscountUpdatable = (primary.HasRevenueSchedule != true);
                    if (primary.HasRevenueSchedule == true) {
                        r.lineItemDiscountLockReason =
                            '이 라인 아이템에는 매출 일정(Revenue Schedule)이 설정되어 있어 할인율을 변경할 수 없습니다. '
                            + '상태·유효기한·조건 메모만 조정할 수 있습니다.';
                    }
                }
            } else {
                r.hasQuote = false;
            }

            List<Interaction_Intelligence__c> intelHistory = intelHistoryByOppId.get(opp.Id);
            if (intelHistory != null && !intelHistory.isEmpty()) {
                r.hasInteractionIntelligence = true;
                List<String> intelLines = new List<String>();
                for (Interaction_Intelligence__c intel : intelHistory) {
                    intelLines.add(
                        intel.CreatedDate.date().format() + ' - 우려사항: ' + emptyIfBlank(intel.Concerns_Objections__c)
                        + ' / 고객반응: ' + emptyIfBlank(intel.Customer_Reaction__c)
                        + ' / 핵심결정: ' + emptyIfBlank(intel.Key_Decision__c)
                        + ' / 후속조치: ' + emptyIfBlank(intel.Follow_Up__c)
                    );
                }
                r.interactionHistorySummary = String.join(intelLines, '\n');
            } else {
                r.hasInteractionIntelligence = false;
            }

            List<String> activityLines = new List<String>();
            List<Task> tasks = tasksByOppId.get(opp.Id);
            if (tasks != null) {
                for (Task t : tasks) {
                    activityLines.add(
                        (t.ActivityDate != null ? String.valueOf(t.ActivityDate) : '날짜 미정')
                        + ' [' + emptyIfBlank(t.TaskSubtype) + '] ' + emptyIfBlank(t.Subject)
                        + (String.isNotBlank(t.Description) ? ' - ' + t.Description : '')
                    );
                }
            }
            List<Event> events = eventsByOppId.get(opp.Id);
            if (events != null) {
                for (Event e : events) {
                    activityLines.add(
                        (e.ActivityDate != null ? String.valueOf(e.ActivityDate) : '날짜 미정')
                        + ' [미팅] ' + emptyIfBlank(e.Subject)
                        + (String.isNotBlank(e.Description) ? ' - ' + e.Description : '')
                    );
                }
            }
            r.hasActivityHistory = !activityLines.isEmpty();
            r.activityHistorySummary = String.join(activityLines, '\n');

            results.add(r);
        }
        return results;
    }

    private static String emptyIfBlank(String s) {
        return String.isBlank(s) ? '(기록 없음)' : s;
    }

    public class Request {
        @InvocableVariable(
            label='Opportunity Id'
            description='Id of the Opportunity to fetch negotiation context for.'
            required=true
        )
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable(label='Opportunity Name' description='Opportunity.Name')
        public String opportunityName;

        @InvocableVariable(label='Client Budget' description='Opportunity.Client_Budget__c')
        public Decimal clientBudget;

        @InvocableVariable(label='Client Budget Status' description='Opportunity.Client_Budget_Status__c')
        public String clientBudgetStatus;

        @InvocableVariable(label='Customer Needs' description='Opportunity.Customer_Needs__c - Discovery 단계에서 파악한 고객의 실제 요구사항.')
        public String customerNeeds;

        @InvocableVariable(label='Key Requirements' description='Opportunity.Key_Requirements__c - 제안에 반드시 반영해야 하는 요구사항/제약.')
        public String keyRequirements;

        @InvocableVariable(label='Customer KPI' description='Opportunity.Customer_KPI__c - 고객이 성공을 판단하는 기준.')
        public String customerKPI;

        @InvocableVariable(label='Target Start Season' description='Opportunity.Target_Start_Season__c - 스폰서십 시작 예정 시즌(연도).')
        public Decimal targetStartSeason;

        @InvocableVariable(label='Partner Tier' description='Opportunity.Partner_Tier__c - 담당자가 수동으로 선택한 등급(자동판정 로직 없음, 참고용 신호일 뿐).')
        public String partnerTier;

        @InvocableVariable(label='Has Primary Contact' description='Whether this Opportunity has a Primary Contact assigned.')
        public Boolean hasPrimaryContact = false;

        @InvocableVariable(label='Primary Contact Name' description='Opportunity.SDO_Sales_Primary_Contact__r.Name - 상대측 담당자 이름.')
        public String primaryContactName;

        @InvocableVariable(label='Primary Contact Title' description='Opportunity.SDO_Sales_Primary_Contact__r.Title - 상대측 담당자 직함.')
        public String primaryContactTitle;

        @InvocableVariable(label='Primary Contact Email' description='Opportunity.SDO_Sales_Primary_Contact__r.Email')
        public String primaryContactEmail;

        @InvocableVariable(label='Primary Contact Phone' description='Opportunity.SDO_Sales_Primary_Contact__r.Phone')
        public String primaryContactPhone;

        @InvocableVariable(label='Has Quote' description='Whether this Opportunity has an existing Quote to negotiate.')
        public Boolean hasQuote = false;

        @InvocableVariable(label='Quote Id' description='Id of the most recent Quote on this Opportunity.')
        public Id quoteId;

        @InvocableVariable(label='Quote Name' description='Name of the most recent Quote.')
        public String quoteName;

        @InvocableVariable(label='Quote Status' description='Quote.Status - approval/negotiation stage.')
        public String quoteStatus;

        @InvocableVariable(label='Quote Line Item Id' description='Id of the primary QuoteLineItem on this Quote. Quote.Discount is not directly writable once line items exist, so discount is negotiated at the line item level.')
        public Id quoteLineItemId;

        @InvocableVariable(label='Quote Discount' description='QuoteLineItem.Discount percentage currently applied on the primary line item.')
        public Decimal quoteDiscount;

        @InvocableVariable(label='Line Item Discount Updatable' description='주 QuoteLineItem의 할인율(Discount)을 바꿀 수 있는지 여부. false면 매출 일정(Revenue Schedule) 때문에 플랫폼이 할인율 변경을 막는다 — 이 경우 사용자에게 먼저 알리고 할인율 변경은 제안/확정하지 말 것. 상태·유효기한·조건 메모는 여전히 변경 가능.')
        public Boolean lineItemDiscountUpdatable = true;

        @InvocableVariable(label='Line Item Discount Lock Reason' description='lineItemDiscountUpdatable가 false일 때 사용자에게 그대로 전달할 한국어 설명. 값이 없으면 할인율 변경 제한이 없다는 뜻.')
        public String lineItemDiscountLockReason;

        @InvocableVariable(label='Product Tier' description='Product2.Tier__c of the primary line item (Standard/Premium/VIP) - 참고용 신호일 뿐, 등급별 할인 정책은 정의되어 있지 않음.')
        public String productTier;

        @InvocableVariable(label='Max Discount Percent' description='PricebookEntry.Max_Discount_Percent__c - 정가 대비 승인 없이 협상 가능한 최대 할인율(%). 이 값을 초과하는 할인은 별도 승인이 필요하다.')
        public Decimal maxDiscountPercent;

        @InvocableVariable(label='Max Discounted Price' description='PricebookEntry.Max_Discounted_Price__c - 승인 없이 내려갈 수 있는 최소 판매가(하한선). 이 밑으로 내려가려면 별도 승인이 필요하다.')
        public Decimal maxDiscountedPrice;

        @InvocableVariable(label='Quote Expiration Date' description='Quote.ExpirationDate')
        public Date quoteExpirationDate;

        @InvocableVariable(label='Quote Grand Total' description='Quote.GrandTotal')
        public Decimal quoteGrandTotal;

        @InvocableVariable(label='Line Items Summary' description='Formatted summary of the Quote line items (product, quantity, unit price, discount, subtotal).')
        public String lineItemsSummary;

        @InvocableVariable(label='Has Interaction Intelligence' description='Whether any recorded interaction/meeting intelligence entries exist for this Opportunity.')
        public Boolean hasInteractionIntelligence = false;

        @InvocableVariable(label='Interaction History Summary' description='최근 상호작용 기록(최대 5건, 최신순)을 날짜와 함께 정리한 문자열 - 우려사항/고객반응/핵심결정/후속조치.')
        public String interactionHistorySummary;

        @InvocableVariable(label='Has Activity History' description='Whether any Task/Event activity history exists for this Opportunity.')
        public Boolean hasActivityHistory = false;

        @InvocableVariable(label='Activity History Summary' description='최근 Task/Event 활동 이력(최대 5건씩, 최신순)을 날짜와 함께 정리한 문자열 - 통화/이메일/미팅 등.')
        public String activityHistorySummary;
    }
}

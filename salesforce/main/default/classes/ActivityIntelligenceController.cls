/**
 * ActivityIntelligenceController
 * Opportunity 하나에 연결된 Interaction_Intelligence__c(+ 하위 Interaction_Signal__c)를
 * 조회하고, Source_Record_Id__c(Text)가 가리키는 원본 Activity(Task/Event/EmailMessage)
 * 정보를 함께 붙여서 반환하는 읽기 전용 컨트롤러.
 *
 * Source_Record_Id__c는 진짜 Lookup이 아니라 18자리 Id를 담는 Text 필드이므로
 * Lightning Data Service의 관계 탐색으로는 원본을 조인할 수 없다 — 이 Apex가
 * Source_Type__c 기준으로 Id를 분류한 뒤 Task/Event/EmailMessage를 각각 벌크 조회해서
 * 조인해준다. 원본이 삭제되어 dangling Id가 된 경우에도 조회 자체는 실패하지 않고
 * originFound=false로 표시되어, Intelligence 레코드 자체는 항상 정상 반환된다.
 */
public with sharing class ActivityIntelligenceController {

    @AuraEnabled(cacheable=true)
    public static List<IntelligenceItem> getIntelligence(Id opportunityId) {
        List<IntelligenceItem> results = new List<IntelligenceItem>();
        if (opportunityId == null) {
            return results;
        }

        List<Interaction_Intelligence__c> intelligences = [
            SELECT Id, Source_Type__c, Source_Record_Id__c, Summary__c, Customer_Reaction__c,
                   Key_Decision__c, Concerns_Objections__c, Follow_Up__c, CreatedDate
            FROM Interaction_Intelligence__c
            WHERE Opportunity__c = :opportunityId
            WITH USER_MODE
        ];
        // 최종 정렬은 아래 IntelligenceItem.compareTo(원본 발생 일시 우선, 없으면 CreatedDate)로 처리하므로
        // 여기서는 SOQL ORDER BY를 쓰지 않는다(WITH USER_MODE + ORDER BY 조합에서 플랫폼 파서 오류가 발생함).
        if (intelligences.isEmpty()) {
            return results;
        }

        Map<Id, List<Interaction_Signal__c>> signalsByParent = groupSignalsByParent(intelligences);
        Map<String, OriginInfo> originById = fetchOrigins(intelligences);

        for (Interaction_Intelligence__c ii : intelligences) {
            IntelligenceItem item = new IntelligenceItem();
            item.id = ii.Id;
            item.sourceType = ii.Source_Type__c;
            item.summary = ii.Summary__c;
            item.customerReaction = ii.Customer_Reaction__c;
            item.keyDecision = ii.Key_Decision__c;
            item.concernsObjections = ii.Concerns_Objections__c;
            item.followUp = ii.Follow_Up__c;
            item.createdDate = ii.CreatedDate;

            OriginInfo origin = String.isBlank(ii.Source_Record_Id__c) ? null : originById.get(ii.Source_Record_Id__c);
            if (origin != null) {
                item.originFound = true;
                item.originSubject = origin.subject;
                item.originDatetime = origin.originDatetime;
                item.originDetail = origin.detail;
            } else {
                item.originFound = false;
            }
            item.effectiveSortDatetime = (item.originDatetime != null) ? item.originDatetime : item.createdDate;

            List<Interaction_Signal__c> signals = signalsByParent.get(ii.Id);
            item.signals = new List<SignalItem>();
            if (signals != null) {
                for (Interaction_Signal__c sig : signals) {
                    SignalItem si = new SignalItem();
                    si.id = sig.Id;
                    si.category = sig.Signal_Category__c;
                    si.type = sig.Signal_Type__c;
                    si.direction = sig.Direction__c;
                    si.confidence = sig.Confidence__c;
                    si.evidence = sig.Evidence__c;
                    item.signals.add(si);
                }
            }

            results.add(item);
        }

        results.sort();
        return results;
    }

    private static Map<Id, List<Interaction_Signal__c>> groupSignalsByParent(List<Interaction_Intelligence__c> intelligences) {
        Map<Id, List<Interaction_Signal__c>> signalsByParent = new Map<Id, List<Interaction_Signal__c>>();
        Set<Id> intelligenceIds = new Map<Id, Interaction_Intelligence__c>(intelligences).keySet();

        for (Interaction_Signal__c sig : [
            SELECT Id, Interaction_Intelligence__c, Signal_Category__c, Signal_Type__c, Direction__c, Confidence__c, Evidence__c
            FROM Interaction_Signal__c
            WHERE Interaction_Intelligence__c IN :intelligenceIds
            WITH USER_MODE
        ]) {
            if (!signalsByParent.containsKey(sig.Interaction_Intelligence__c)) {
                signalsByParent.put(sig.Interaction_Intelligence__c, new List<Interaction_Signal__c>());
            }
            signalsByParent.get(sig.Interaction_Intelligence__c).add(sig);
        }
        return signalsByParent;
    }

    /**
     * Source_Type__c 기준으로 Source_Record_Id__c를 Task/Event/EmailMessage로 분류해
     * 각각 한 번씩만 벌크 조회한다(SOQL in loop 없음). 형식이 잘못된 Id 문자열은
     * 개별적으로 건너뛰고(originFound=false로 귀결) 전체 조회를 실패시키지 않는다.
     */
    private static Map<String, OriginInfo> fetchOrigins(List<Interaction_Intelligence__c> intelligences) {
        Map<String, OriginInfo> originById = new Map<String, OriginInfo>();

        Set<Id> taskIds = new Set<Id>();
        Set<Id> eventIds = new Set<Id>();
        Set<Id> emailIds = new Set<Id>();

        for (Interaction_Intelligence__c ii : intelligences) {
            if (String.isBlank(ii.Source_Record_Id__c)) {
                continue;
            }
            Id sourceId;
            try {
                sourceId = Id.valueOf(ii.Source_Record_Id__c);
            } catch (Exception e) {
                // 형식이 잘못된 Id — 원본 없이 표시(graceful degradation). Interaction_Intelligence__c에
                // Source_Type__c-Source_Record_Id__c 접두사 일치를 강제하는 Validation Rule이 있어
                // 정상 입력 경로로는 도달하지 않지만, 방어적으로 남겨둔다.
                continue;
            }

            if (ii.Source_Type__c == 'Call') {
                taskIds.add(sourceId);
            } else if (ii.Source_Type__c == 'Email') {
                emailIds.add(sourceId);
            } else if (ii.Source_Type__c == 'Online Meeting' || ii.Source_Type__c == 'Offline Meeting') {
                eventIds.add(sourceId);
            }
        }

        if (!taskIds.isEmpty()) {
            for (Task t : [
                SELECT Id, Subject, ActivityDate, Status
                FROM Task
                WHERE Id IN :taskIds
                WITH USER_MODE
            ]) {
                OriginInfo info = new OriginInfo();
                info.subject = t.Subject;
                info.originDatetime = t.ActivityDate == null ? null : Datetime.newInstance(t.ActivityDate, Time.newInstance(0, 0, 0, 0));
                info.detail = t.Status;
                originById.put(String.valueOf(t.Id), info);
            }
        }

        if (!eventIds.isEmpty()) {
            for (Event ev : [
                SELECT Id, Subject, StartDateTime, Meeting_Type__c
                FROM Event
                WHERE Id IN :eventIds
                WITH USER_MODE
            ]) {
                OriginInfo info = new OriginInfo();
                info.subject = ev.Subject;
                info.originDatetime = ev.StartDateTime;
                info.detail = ev.Meeting_Type__c;
                originById.put(String.valueOf(ev.Id), info);
            }
        }

        if (!emailIds.isEmpty()) {
            for (EmailMessage em : [
                SELECT Id, Subject, MessageDate, CreatedDate
                FROM EmailMessage
                WHERE Id IN :emailIds
                WITH USER_MODE
            ]) {
                OriginInfo info = new OriginInfo();
                info.subject = em.Subject;
                info.originDatetime = em.MessageDate != null ? em.MessageDate : em.CreatedDate;
                info.detail = null;
                originById.put(String.valueOf(em.Id), info);
            }
        }

        return originById;
    }

    private class OriginInfo {
        String subject;
        Datetime originDatetime;
        String detail;
    }

    public class IntelligenceItem implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String sourceType;
        @AuraEnabled public String summary;
        @AuraEnabled public String customerReaction;
        @AuraEnabled public String keyDecision;
        @AuraEnabled public String concernsObjections;
        @AuraEnabled public String followUp;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Boolean originFound = false;
        @AuraEnabled public String originSubject;
        @AuraEnabled public Datetime originDatetime;
        @AuraEnabled public String originDetail;
        @AuraEnabled public List<SignalItem> signals;

        // 정렬 전용(원본 발생 일시 우선, 없으면 CreatedDate) — Aura로 노출하지 않음
        public Datetime effectiveSortDatetime;

        public Integer compareTo(Object compareTo) {
            IntelligenceItem other = (IntelligenceItem) compareTo;
            Datetime a = this.effectiveSortDatetime;
            Datetime b = other.effectiveSortDatetime;
            if (a == null && b == null) return 0;
            if (a == null) return 1;
            if (b == null) return -1;
            if (a > b) return -1;
            if (a < b) return 1;
            return 0;
        }
    }

    public class SignalItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String category;
        @AuraEnabled public String type;
        @AuraEnabled public String direction;
        @AuraEnabled public String confidence;
        @AuraEnabled public String evidence;
    }
}

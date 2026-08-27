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

    // ============================================================================
    //  Activity Timeline + Intelligence UI Integration V1  (activityTimeline LWC)
    //  기존 getIntelligence()는 그대로 두고(호환 유지), 아래 두 메서드를 추가한다.
    //  getActivityTimeline : Opportunity의 모든 Activity(Task/Event/EmailMessage)를
    //                        시간순으로 정규화하고 Interaction Intelligence를 LEFT JOIN.
    //  getActivityContent  : 특정 Activity 클릭 시 원본 상세/전문을 lazy load.
    //  Full Content는 timeline 초기 로드에 포함하지 않는다(성능).
    // ============================================================================

    /**
     * Opportunity에 연결된 Task/Event/EmailMessage 전부를 정규화한 Timeline row로 반환한다.
     * Interaction_Intelligence__c(+Signal)는 Source_Record_Id__c = Activity Id 기준으로 LEFT JOIN.
     * Intelligence가 없는 Activity(일반 Task 등)도 그대로 반환한다(hasIntelligence=false).
     * SOQL은 오브젝트당 1회 벌크(총 ≤ 5). N+1 없음. with sharing + USER_MODE.
     */
    @AuraEnabled(cacheable=true)
    public static List<TimelineItem> getActivityTimeline(Id opportunityId) {
        List<TimelineItem> rows = new List<TimelineItem>();
        if (opportunityId == null) {
            return rows;
        }

        // --- Intelligence + Signals (Source_Record_Id__c -> Intelligence) ---
        List<Interaction_Intelligence__c> intelligences = [
            SELECT Id, Source_Type__c, Source_Record_Id__c, Summary__c, Customer_Reaction__c,
                   Key_Decision__c, Concerns_Objections__c, Follow_Up__c, CreatedDate
            FROM Interaction_Intelligence__c
            WHERE Opportunity__c = :opportunityId
            WITH USER_MODE
        ];
        Map<Id, Interaction_Intelligence__c> iiByActivityId = new Map<Id, Interaction_Intelligence__c>();
        for (Interaction_Intelligence__c ii : intelligences) {
            if (String.isBlank(ii.Source_Record_Id__c)) {
                continue;
            }
            try {
                iiByActivityId.put(Id.valueOf(ii.Source_Record_Id__c), ii);
            } catch (Exception e) {
                // 형식이 잘못된 Id(Validation Rule로 정상 경로에서는 도달 불가) — 조용히 건너뜀
            }
        }
        Map<Id, List<Interaction_Signal__c>> signalsByParent =
            intelligences.isEmpty() ? new Map<Id, List<Interaction_Signal__c>>() : groupSignalsByParent(intelligences);

        // --- EmailMessages (현재 org 데이터 없음 — 향후 실 EmailMessage 대비 정규화 경로) ---
        // EmailMessage를 저장하면 Salesforce가 짝이 되는 shadow Task(TaskSubtype='Email')를 자동 생성한다.
        // 그 shadow Task Id는 EmailMessage.ActivityId이므로, 아래 Task 조회에서 제외해 중복 row를 막는다.
        Set<Id> emailShadowTaskIds = new Set<Id>();
        List<TimelineItem> emailRows = new List<TimelineItem>();
        if (Schema.SObjectType.EmailMessage.isAccessible() && Schema.SObjectType.EmailMessage.isQueryable()) {
            try {
                for (EmailMessage em : [
                    SELECT Id, Subject, MessageDate, CreatedDate, FromName, FromAddress, ActivityId
                    FROM EmailMessage
                    WHERE RelatedToId = :opportunityId
                    WITH USER_MODE
                ]) {
                    if (em.ActivityId != null) {
                        emailShadowTaskIds.add(em.ActivityId);
                    }
                    TimelineItem item = new TimelineItem();
                    item.activityId = em.Id;
                    item.sourceObject = 'EmailMessage';
                    item.activityType = 'Email';
                    item.timestamp = (em.MessageDate != null) ? em.MessageDate : em.CreatedDate;
                    item.subject = em.Subject;
                    item.contactName = String.isNotBlank(em.FromName) ? em.FromName : em.FromAddress;
                    item.contentType = 'Email Content';
                    applyIntelligence(item, iiByActivityId.get(em.Id), signalsByParent);
                    emailRows.add(item);
                }
            } catch (Exception e) {
                // EmailMessage 접근 제약 — Timeline 전체를 실패시키지 않는다
            }
        }

        // --- Tasks (EmailMessage shadow Task 제외) ---
        for (Task t : [
            SELECT Id, Subject, Status, Priority, ActivityDate, CreatedDate, TaskSubtype,
                   Meeting_Type__c, Who.Name, Owner.Name
            FROM Task
            WHERE WhatId = :opportunityId AND Id NOT IN :emailShadowTaskIds
            WITH USER_MODE
        ]) {
            TimelineItem item = new TimelineItem();
            item.activityId = t.Id;
            item.sourceObject = 'Task';
            item.activityType = taskActivityType(t.TaskSubtype);
            item.timestamp = (t.ActivityDate != null)
                ? Datetime.newInstance(t.ActivityDate, Time.newInstance(0, 0, 0, 0))
                : t.CreatedDate;
            item.subject = t.Subject;
            item.contactName = (t.Who != null) ? t.Who.Name : null;
            item.ownerName = (t.Owner != null) ? t.Owner.Name : null;
            item.status = t.Status;
            item.meetingType = t.Meeting_Type__c;
            item.contentType = 'Activity Notes';
            applyIntelligence(item, iiByActivityId.get(t.Id), signalsByParent);
            rows.add(item);
        }

        // --- Events ---
        for (Event ev : [
            SELECT Id, Subject, StartDateTime, EndDateTime, CreatedDate, Location,
                   Meeting_Type__c, Who.Name, Owner.Name
            FROM Event
            WHERE WhatId = :opportunityId
            WITH USER_MODE
        ]) {
            TimelineItem item = new TimelineItem();
            item.activityId = ev.Id;
            item.sourceObject = 'Event';
            item.activityType = eventActivityType(ev.Meeting_Type__c);
            item.timestamp = (ev.StartDateTime != null) ? ev.StartDateTime : ev.CreatedDate;
            item.subject = ev.Subject;
            item.contactName = (ev.Who != null) ? ev.Who.Name : null;
            item.ownerName = (ev.Owner != null) ? ev.Owner.Name : null;
            item.status = null;
            item.meetingType = ev.Meeting_Type__c;
            item.contentType = 'Meeting Notes';
            applyIntelligence(item, iiByActivityId.get(ev.Id), signalsByParent);
            rows.add(item);
        }

        rows.addAll(emailRows);
        rows.sort();
        return rows;
    }

    /**
     * 특정 Activity의 상세/전문을 반환한다(detail 패널 open 시 lazy load).
     * Task -> Task.Description ("Activity Notes")
     * Event -> Event.Description ("Meeting Notes") + 담당자 원본 구조화 노트(FLS 허용 필드만)
     * EmailMessage -> From/To/Cc + TextBody/HtmlBody ("Email Content")
     * 사용자가 읽을 수 없는 필드는 Security.stripInaccessible로 제거되어 null로 반환된다(예외 없음).
     */
    @AuraEnabled(cacheable=true)
    public static ActivityContent getActivityContent(Id activityId) {
        ActivityContent content = new ActivityContent();
        if (activityId == null) {
            return content;
        }
        String prefix = String.valueOf(activityId).substring(0, 3);

        if (prefix == Task.SObjectType.getDescribe().getKeyPrefix()) {
            List<Task> tasks = [
                SELECT Id, Subject, Description, Status, Priority, ActivityDate, TaskSubtype,
                       Meeting_Type__c, Who.Name, Owner.Name
                FROM Task WHERE Id = :activityId WITH USER_MODE LIMIT 1
            ];
            if (!tasks.isEmpty()) {
                Task t = tasks[0];
                content.activityType = taskActivityType(t.TaskSubtype);
                content.sourceObject = 'Task';
                content.subject = t.Subject;
                content.contactName = (t.Who != null) ? t.Who.Name : null;
                content.ownerName = (t.Owner != null) ? t.Owner.Name : null;
                content.status = t.Status;
                content.priority = t.Priority;
                content.timestamp = (t.ActivityDate != null)
                    ? Datetime.newInstance(t.ActivityDate, Time.newInstance(0, 0, 0, 0)) : null;
                content.meetingType = t.Meeting_Type__c;
                content.contentType = 'Activity Notes';
                content.body = t.Description;
                content.hasContent = String.isNotBlank(t.Description);
            }
        } else if (prefix == Event.SObjectType.getDescribe().getKeyPrefix()) {
            // 담당자 원본 노트 5개 필드는 permission set별 FLS가 갈리므로(예: Qualification Access는 미부여)
            // running user가 읽을 수 있는 필드만 동적으로 SELECT한다 — WITH USER_MODE에서 예외가 나지 않는다.
            Map<String, Schema.SObjectField> fMap = Schema.SObjectType.Event.fields.getMap();
            List<String> noteFields = new List<String>();
            for (String api : new List<String>{
                'Key_Discussion__c', 'Key_Decision__c', 'Concerns_Objections__c', 'Follow_up__c', 'Customer_Reaction__c'
            }) {
                Schema.SObjectField f = fMap.get(api.toLowerCase());
                if (f != null && f.getDescribe().isAccessible()) {
                    noteFields.add(api);
                }
            }
            String soql = 'SELECT Id, Subject, Description, StartDateTime, EndDateTime, Location, Meeting_Type__c, Who.Name, Owner.Name';
            if (!noteFields.isEmpty()) {
                soql += ', ' + String.join(noteFields, ', ');
            }
            soql += ' FROM Event WHERE Id = :activityId WITH USER_MODE LIMIT 1';
            List<Event> raw = Database.query(soql);
            if (!raw.isEmpty()) {
                Event ev = raw[0];
                content.activityType = eventActivityType(ev.Meeting_Type__c);
                content.sourceObject = 'Event';
                content.subject = ev.Subject;
                content.contactName = (ev.Who != null) ? ev.Who.Name : null;
                content.ownerName = (ev.Owner != null) ? ev.Owner.Name : null;
                content.status = null;
                content.timestamp = ev.StartDateTime;
                content.endTimestamp = ev.EndDateTime;
                content.location = ev.Location;
                content.meetingType = ev.Meeting_Type__c;
                content.contentType = 'Meeting Notes';
                content.body = ev.Description;
                content.meetingNotes = new List<NoteField>();
                Map<String, String> noteLabels = new Map<String, String>{
                    'Key_Discussion__c' => 'Key Discussion',
                    'Key_Decision__c' => 'Key Decision',
                    'Concerns_Objections__c' => 'Concerns / Objections',
                    'Follow_up__c' => 'Follow-up',
                    'Customer_Reaction__c' => 'Customer Reaction (Rep)'
                };
                for (String api : new List<String>{
                    'Key_Discussion__c', 'Key_Decision__c', 'Concerns_Objections__c', 'Follow_up__c', 'Customer_Reaction__c'
                }) {
                    if (noteFields.contains(api)) {
                        addNote(content.meetingNotes, noteLabels.get(api), (String) ev.get(api));
                    }
                }
                content.hasContent = String.isNotBlank(ev.Description) || !content.meetingNotes.isEmpty();
            }
        } else if (prefix == EmailMessage.SObjectType.getDescribe().getKeyPrefix()) {
            List<EmailMessage> emails = [
                SELECT Id, Subject, TextBody, HtmlBody, FromName, FromAddress, ToAddress, CcAddress,
                       MessageDate, Incoming
                FROM EmailMessage WHERE Id = :activityId WITH USER_MODE LIMIT 1
            ];
            if (!emails.isEmpty()) {
                EmailMessage em = emails[0];
                content.activityType = 'Email';
                content.sourceObject = 'EmailMessage';
                content.subject = em.Subject;
                content.contactName = String.isNotBlank(em.FromName) ? em.FromName : em.FromAddress;
                content.timestamp = em.MessageDate;
                content.contentType = 'Email Content';
                content.emailFrom = em.FromAddress;
                content.emailTo = em.ToAddress;
                content.emailCc = em.CcAddress;
                content.body = em.TextBody;
                content.htmlBody = em.HtmlBody;
                content.hasContent = String.isNotBlank(em.TextBody) || String.isNotBlank(em.HtmlBody);
            }
        }
        return content;
    }

    // --- helpers ---

    private static String taskActivityType(String taskSubtype) {
        if (taskSubtype == 'Call') return 'Call';
        if (taskSubtype == 'Email' || taskSubtype == 'ListEmail') return 'Email';
        return 'Task';
    }

    private static String eventActivityType(String meetingType) {
        if (meetingType == 'Online') return 'Online Meeting';
        if (meetingType == 'Offline') return 'Offline Meeting';
        return 'Meeting';
    }

    private static void applyIntelligence(TimelineItem item, Interaction_Intelligence__c ii,
            Map<Id, List<Interaction_Signal__c>> signalsByParent) {
        if (ii == null) {
            item.hasIntelligence = false;
            item.signals = new List<SignalItem>();
            return;
        }
        item.hasIntelligence = true;
        item.intelligenceId = ii.Id;
        item.summary = ii.Summary__c;
        item.customerReaction = ii.Customer_Reaction__c;
        item.keyDecision = ii.Key_Decision__c;
        item.concernsObjections = ii.Concerns_Objections__c;
        item.followUp = ii.Follow_Up__c;
        item.signals = new List<SignalItem>();
        List<Interaction_Signal__c> sigs = signalsByParent.get(ii.Id);
        if (sigs != null) {
            for (Interaction_Signal__c sig : sigs) {
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
    }

    private static void addNote(List<NoteField> notes, String label, String value) {
        if (String.isNotBlank(value)) {
            NoteField nf = new NoteField();
            nf.label = label;
            nf.value = value;
            notes.add(nf);
        }
    }

    public class TimelineItem implements Comparable {
        @AuraEnabled public Id activityId;
        @AuraEnabled public String activityType;
        @AuraEnabled public String sourceObject;
        @AuraEnabled public Datetime timestamp;
        @AuraEnabled public String subject;
        @AuraEnabled public String contactName;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String status;
        @AuraEnabled public String meetingType;
        @AuraEnabled public Boolean hasIntelligence = false;
        @AuraEnabled public Id intelligenceId;
        @AuraEnabled public String summary;
        @AuraEnabled public String customerReaction;
        @AuraEnabled public String keyDecision;
        @AuraEnabled public String concernsObjections;
        @AuraEnabled public String followUp;
        @AuraEnabled public List<SignalItem> signals;
        @AuraEnabled public String contentType;

        public Integer compareTo(Object other) {
            Datetime a = this.timestamp;
            Datetime b = ((TimelineItem) other).timestamp;
            if (a == null && b == null) return 0;
            if (a == null) return 1;
            if (b == null) return -1;
            if (a > b) return -1;
            if (a < b) return 1;
            return 0;
        }
    }

    public class ActivityContent {
        @AuraEnabled public String activityType;
        @AuraEnabled public String sourceObject;
        @AuraEnabled public String subject;
        @AuraEnabled public String contactName;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Datetime timestamp;
        @AuraEnabled public Datetime endTimestamp;
        @AuraEnabled public String location;
        @AuraEnabled public String meetingType;
        @AuraEnabled public String contentType;
        @AuraEnabled public Boolean hasContent = false;
        @AuraEnabled public String body;
        @AuraEnabled public String htmlBody;
        @AuraEnabled public String emailFrom;
        @AuraEnabled public String emailTo;
        @AuraEnabled public String emailCc;
        @AuraEnabled public List<NoteField> meetingNotes;
    }

    public class NoteField {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}

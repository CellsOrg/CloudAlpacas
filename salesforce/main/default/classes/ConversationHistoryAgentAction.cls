/**
 * ConversationHistoryAgentAction
 *
 * Agentforce(apex://)에서 호출하는 읽기 전용 action. Opportunity 하나에 대한
 * 고객 상호작용의 "전체 히스토리"를 시간순(오래된 것 → 최근 것)으로 정리한
 * 하나의 텍스트 다이제스트로 돌려준다.
 *
 * get_interaction_intelligence 와의 차이:
 *   - get_interaction_intelligence : 저장된 Interaction_Intelligence__c 가 있는 활동만,
 *                                    AI 분석(요약/반응/결정/우려/신호) 중심, 최신순.
 *   - get_conversation_history      : Task/Event/EmailMessage 전체(일반 통화·Task 포함),
 *                                    시간 흐름 중심, 각 활동에 저장된 AI 분석이 있으면 함께.
 *
 * 새 조회 로직을 만들지 않는다 — 이미 검증된
 * ActivityIntelligenceController.getActivityTimeline()(with sharing, WITH USER_MODE,
 * Task/Event/EmailMessage 정규화 + Interaction_Intelligence__c LEFT JOIN,
 * EmailMessage shadow Task 중복 제거)를 그대로 호출하고, 그 결과를 primitive
 * (String / Integer / Boolean)로 flatten만 한다. DML 없음, 새 SOQL 없음,
 * 저장되지 않은 사실을 생성/추론하지 않는다.
 */
public with sharing class ConversationHistoryAgentAction {

    // 다이제스트 안전 상한 — 실데이터는 Opportunity당 활동 한 자릿수지만, 향후 대량
    // 히스토리에서 토큰이 폭주하지 않도록 방어적으로 둔다. maxItems 미지정 시 적용.
    private static final Integer DEFAULT_CAP = 50;

    @InvocableMethod(
        label='Get Conversation History'
        description='Returns the full chronological record of customer interactions on an Opportunity — every Task, call, meeting and email, oldest first, each with its stored AI analysis (summary, customer reaction, key decision, concerns, follow-up, signals) when one exists. Read-only. Retrieves and organises stored facts only — never derives deal risk, win likelihood, stall reasons, next actions, or customer intent.'
    )
    public static List<Response> getConversationHistory(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(buildResponse(req));
        }
        return responses;
    }

    private static Response buildResponse(Request req) {
        Response res = new Response();

        Id opportunityId = parseOpportunityId(req == null ? null : req.opportunityId);
        if (opportunityId == null) {
            res.opportunityResolved = false;
            res.hasHistory = false;
            res.interactionCount = 0;
            res.historyDigest = 'Opportunity를 특정하지 못했습니다 — opportunityId가 유효한 Opportunity Id가 아닙니다. 이것은 조회 대상 확인 실패이며, 대화 히스토리가 없다는 뜻이 아닙니다. 어떤 Opportunity인지 다시 확인해야 합니다.';
            return res;
        }

        res.opportunityResolved = true;

        // 최신순으로 반환됨. 시간순 서사를 위해 오래된 것 → 최근 것으로 뒤집는다.
        List<ActivityIntelligenceController.TimelineItem> items =
            ActivityIntelligenceController.getActivityTimeline(opportunityId);
        if (items == null) {
            items = new List<ActivityIntelligenceController.TimelineItem>();
        }
        Integer totalCount = items.size();

        if (totalCount == 0) {
            res.hasHistory = false;
            res.interactionCount = 0;
            res.historyDigest = '이 Opportunity에는 기록된 고객 상호작용(통화·미팅·이메일·Task)이 없습니다.';
            return res;
        }

        // maxItems 지정 시 "가장 최근 N건"만 (items 는 최신순이므로 앞에서 N개).
        Integer cap = (req != null && req.maxItems != null && req.maxItems > 0)
            ? req.maxItems
            : DEFAULT_CAP;
        Boolean truncated = totalCount > cap;

        List<ActivityIntelligenceController.TimelineItem> window =
            new List<ActivityIntelligenceController.TimelineItem>();
        for (Integer i = 0; i < items.size() && i < cap; i++) {
            window.add(items[i]);
        }
        // 표시용으로 시간순(오래된 것 먼저) 정렬
        List<ActivityIntelligenceController.TimelineItem> chronological =
            new List<ActivityIntelligenceController.TimelineItem>();
        for (Integer i = window.size() - 1; i >= 0; i--) {
            chronological.add(window[i]);
        }

        res.hasHistory = true;
        res.interactionCount = totalCount;
        res.firstInteractionDate = formatDate(items[items.size() - 1].timestamp); // 전체 중 가장 오래된
        res.lastInteractionDate = formatDate(items[0].timestamp);                  // 전체 중 가장 최근
        res.historyDigest = formatDigest(chronological, totalCount, truncated, cap);
        return res;
    }

    private static String formatDigest(
        List<ActivityIntelligenceController.TimelineItem> chronological,
        Integer totalCount,
        Boolean truncated,
        Integer cap
    ) {
        List<String> out = new List<String>();

        String header = '고객 상호작용 ' + totalCount + '건 (오래된 것 → 최근 것)';
        if (truncated) {
            header += ' — 가장 최근 ' + cap + '건만 아래에 표시';
        }
        out.add(header);

        Integer idx = 1;
        for (ActivityIntelligenceController.TimelineItem item : chronological) {
            List<String> lines = new List<String>();

            String dateStr = formatDate(item.timestamp);
            String subject = String.isNotBlank(item.subject) ? item.subject : '(제목 없음)';
            String meta = buildMeta(item);
            lines.add(
                '[' + idx + '] ' + (dateStr == null ? '(날짜 미상)' : dateStr) +
                ' · ' + blankTo(item.activityType, '활동') +
                ' · "' + subject + '"' +
                (meta == null ? '' : ' (' + meta + ')')
            );

            if (item.hasIntelligence) {
                lines.add('    AI 분석: 있음');
                lines.add('      요약: ' + blankTo(item.summary, '(기록 없음)'));
                lines.add('      고객 반응: ' + blankTo(item.customerReaction, '(기록 없음)'));
                lines.add('      핵심 결정: ' + blankTo(item.keyDecision, '(기록 없음)'));
                lines.add('      우려/이견: ' + blankTo(item.concernsObjections, '(기록 없음)'));
                lines.add('      후속 조치: ' + blankTo(item.followUp, '(기록 없음)'));
                lines.add('      Signals: ' + formatSignals(item.signals));
            } else {
                lines.add('    AI 분석: 없음 (이 활동에는 저장된 Interaction Intelligence가 없습니다 — 요약·반응·신호를 추측하지 마세요)');
            }

            out.add(String.join(lines, '\n'));
            idx++;
        }

        return String.join(out, '\n\n');
    }

    private static String buildMeta(ActivityIntelligenceController.TimelineItem item) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(item.contactName)) {
            parts.add('상대: ' + item.contactName);
        }
        if (String.isNotBlank(item.ownerName)) {
            parts.add('담당: ' + item.ownerName);
        }
        if (String.isNotBlank(item.status)) {
            parts.add('상태: ' + item.status);
        }
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    private static String formatSignals(List<ActivityIntelligenceController.SignalItem> signals) {
        if (signals == null || signals.isEmpty()) {
            return '(없음)';
        }
        List<String> sigLines = new List<String>();
        for (ActivityIntelligenceController.SignalItem s : signals) {
            String head =
                blankTo(s.category, '(분류 미상)') + ' · ' +
                blankTo(s.direction, '방향 미상') + ' · ' +
                blankTo(s.confidence, '신뢰도 미상');
            String evidence = String.isNotBlank(s.evidence) ? ' — ' + s.evidence : '';
            sigLines.add('\n        - ' + head + evidence);
        }
        return String.join(sigLines, '');
    }

    private static String formatDate(Datetime dt) {
        return (dt == null) ? null : dt.format('yyyy-MM-dd');
    }

    private static String blankTo(String value, String fallback) {
        return String.isBlank(value) ? fallback : value;
    }

    /**
     * 문자열이 Opportunity의 15/18자리 Id일 때만 Id를 반환하고, 그 외에는 null.
     * 잘못된 형식이나 다른 SObject의 Id는 조용히 null 처리해 "확인 실패" 경로로 흘려보낸다.
     */
    private static Id parseOpportunityId(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.length() != 15 && trimmed.length() != 18) {
            return null;
        }
        try {
            Id candidate = Id.valueOf(trimmed);
            return (candidate.getSObjectType() == Opportunity.SObjectType) ? candidate : null;
        } catch (Exception e) {
            return null;
        }
    }

    public class Request {
        @InvocableVariable(
            label='Opportunity Id'
            description='Salesforce Id of the Opportunity whose conversation history should be returned.'
            required=true
        )
        public String opportunityId;

        @InvocableVariable(
            label='Max Items'
            description='Optional. When set, only the most recent N interactions are included in the digest (still presented oldest-first within that window). Leave empty for the full history.'
        )
        public Integer maxItems;
    }

    public class Response {
        @InvocableVariable(label='Opportunity Resolved' description='True when opportunityId was a valid Opportunity Id and the lookup ran. When false, the Opportunity could not be identified — this is a resolution failure, NOT an empty history; do not report it as "no history".')
        public Boolean opportunityResolved = false;

        @InvocableVariable(label='Has History' description='True when at least one customer interaction (Task/call/meeting/email) is recorded on this Opportunity. Only meaningful when opportunityResolved is true.')
        public Boolean hasHistory = false;

        @InvocableVariable(label='Interaction Count' description='Total number of recorded interactions on this Opportunity (before any maxItems limit).')
        public Integer interactionCount = 0;

        @InvocableVariable(label='First Interaction Date' description='Date (yyyy-MM-dd) of the earliest recorded interaction, or empty when there is none.')
        public String firstInteractionDate;

        @InvocableVariable(label='Last Interaction Date' description='Date (yyyy-MM-dd) of the most recent recorded interaction, or empty when there is none.')
        public String lastInteractionDate;

        @InvocableVariable(label='History Digest' description='Human-readable chronological digest (oldest first): for each interaction the date, type, subject, participants, and — when a stored Interaction Intelligence exists — its summary, customer reaction, key decision, concerns/objections, follow-up and signals. States plainly when an interaction has no stored analysis and when there is no history at all.')
        public String historyDigest;
    }
}

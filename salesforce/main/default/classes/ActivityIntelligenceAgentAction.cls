/**
 * ActivityIntelligenceAgentAction
 *
 * Agentforce(apex://)에서 호출하는 읽기 전용 action. Opportunity 하나에 이미 저장된
 * Interaction_Intelligence__c(+ 하위 Interaction_Signal__c, + 원본 Activity)를
 * Agent가 소비하기 쉬운 하나의 텍스트 다이제스트로 정리해 돌려준다.
 *
 * 새 로직을 만들지 않는다 — 이미 검증된
 * ActivityIntelligenceController.getIntelligence()(with sharing, WITH USER_MODE,
 * 원본 Activity 조인, 최신순 정렬)를 그대로 호출하고, 그 결과를 primitive
 * (String / Integer / Boolean)로 flatten만 한다. 이 클래스는 DML을 하지 않으며,
 * 새로운 Intelligence를 생성/추론하지 않는다.
 */
public with sharing class ActivityIntelligenceAgentAction {

    @InvocableMethod(
        label='Get Interaction Intelligence'
        description='Returns the interaction intelligence already stored for an Opportunity — per-interaction summary, customer reaction, key decision, concerns/objections, follow-up, and interaction signals — newest first. Read-only. Returns "no intelligence stored" when there is none; never infers analysis from raw activity text.'
    )
    public static List<Response> getInteractionIntelligence(List<Request> requests) {
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
            res.found = false;
            res.interactionCount = 0;
            res.intelligenceDigest = 'Opportunity를 특정할 수 없습니다 (opportunityId가 비어 있거나 형식이 올바르지 않음). 유효한 Opportunity Id로 다시 시도하세요.';
            return res;
        }

        List<ActivityIntelligenceController.IntelligenceItem> items =
            ActivityIntelligenceController.getIntelligence(opportunityId);

        res.interactionCount = (items == null) ? 0 : items.size();
        res.found = res.interactionCount > 0;
        res.intelligenceDigest = res.found
            ? formatDigest(items)
            : '이 Opportunity에는 저장된 Interaction Intelligence가 없습니다.';
        return res;
    }

    private static String formatDigest(List<ActivityIntelligenceController.IntelligenceItem> items) {
        List<String> blocks = new List<String>();
        Integer idx = 1;
        for (ActivityIntelligenceController.IntelligenceItem item : items) {
            String subject = String.isNotBlank(item.originSubject) ? item.originSubject : '(원본 활동 없음)';
            String whenStr = formatWhen(item);

            List<String> lines = new List<String>();
            lines.add(
                '[' + idx + '] ' + blankTo(item.sourceType, '(유형 미상)') + ' · ' + subject +
                (whenStr == null ? '' : ' · ' + whenStr)
            );
            lines.add('    요약: ' + blankTo(item.summary, '(기록 없음)'));
            lines.add('    고객 반응: ' + blankTo(item.customerReaction, '(기록 없음)'));
            lines.add('    핵심 결정: ' + blankTo(item.keyDecision, '(기록 없음)'));
            lines.add('    우려/이견: ' + blankTo(item.concernsObjections, '(기록 없음)'));
            lines.add('    후속 조치: ' + blankTo(item.followUp, '(기록 없음)'));
            lines.add('    Signals: ' + formatSignals(item.signals));

            blocks.add(String.join(lines, '\n'));
            idx++;
        }
        return String.join(blocks, '\n\n');
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
            sigLines.add('\n      - ' + head + evidence);
        }
        return String.join(sigLines, '');
    }

    private static String formatWhen(ActivityIntelligenceController.IntelligenceItem item) {
        Datetime dt = (item.originDatetime != null) ? item.originDatetime : item.createdDate;
        return (dt == null) ? null : dt.format('yyyy-MM-dd');
    }

    private static String blankTo(String value, String fallback) {
        return String.isBlank(value) ? fallback : value;
    }

    /**
     * 문자열이 Opportunity의 15/18자리 Id일 때만 Id를 반환하고, 그 외에는 null.
     * 잘못된 형식이나 다른 SObject의 Id는 조용히 null 처리해 "저장된 인텔리전스 없음"
     * 경로로 흘려보낸다(전체 실패 없음).
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
            description='Salesforce Id of the Opportunity whose stored interaction intelligence should be returned.'
            required=true
        )
        public String opportunityId;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True when at least one Interaction Intelligence record is stored for this Opportunity.')
        public Boolean found = false;

        @InvocableVariable(label='Interaction Count' description='Number of stored Interaction Intelligence records for this Opportunity.')
        public Integer interactionCount = 0;

        @InvocableVariable(label='Intelligence Digest' description='Human-readable digest of every stored interaction, newest first: source type, activity subject, date, summary, customer reaction, key decision, concerns/objections, follow-up, and signals (Category · Direction · Confidence — Evidence). States plainly when no intelligence is stored.')
        public String intelligenceDigest;
    }
}

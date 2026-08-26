/**
 * InteractionIntelligenceParser
 * CA_Offline_Meeting_Intelligence_UI Prompt Template의 promptResponse(JSON String)를
 * Flow에서 바로 사용할 수 있는 값으로 파싱/검증하는 순수 파서.
 *
 * 이 클래스는 AI를 호출하지 않고, 레코드를 조회하지 않고, DML을 수행하지 않는다.
 * 오직 문자열 하나를 받아 구조화된 값을 돌려주는 역할만 한다.
 *
 * Signal_Category__c / Direction__c / Confidence__c는 Interaction_Signal__c의
 * restricted picklist이므로, 셋 중 하나라도 허용값이 아니면 그 Signal 하나만
 * 건너뛴다(skippedSignalCount로 카운트). Signal 하나의 결함 때문에 Summary 등
 * 나머지 유효한 분석 결과 전체를 버리는 것이 더 나쁜 실패 방식이라고 판단했다.
 *
 * Customer_Reaction__c는 Interaction_Intelligence__c 본문 저장을 좌우하는 필드라서,
 * 허용값이 아니면 필드가 이미 가지고 있는 안전한 기본값인 'Not Determined'로
 * 대체한다(레코드 생성 자체가 막히는 것을 방지).
 */
public with sharing class InteractionIntelligenceParser {

    private static final Set<String> VALID_SIGNAL_CATEGORIES = new Set<String>{
        'INTEREST', 'BUDGET', 'DECISION', 'FIT', 'COMPETITION', 'TIMING', 'MOMENTUM', 'RISK'
    };
    private static final Set<String> VALID_DIRECTIONS = new Set<String>{
        'Positive', 'Negative', 'Neutral'
    };
    private static final Set<String> VALID_CONFIDENCE_LEVELS = new Set<String>{
        'High', 'Medium', 'Low'
    };
    private static final Set<String> VALID_CUSTOMER_REACTIONS = new Set<String>{
        'Very Positive', 'Positive', 'Neutral', 'Negative', 'Very Negative', 'Not Determined'
    };
    private static final String DEFAULT_CUSTOMER_REACTION = 'Not Determined';

    @InvocableMethod(
        label='Interaction Intelligence 응답 파싱'
        description='Prompt Template의 promptResponse(JSON String)를 Interaction Intelligence 필드와 Signal 목록으로 파싱합니다.'
    )
    public static List<Output> parse(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            results.add(parseOne(inp.promptResponse));
        }
        return results;
    }

    private static Output parseOne(String promptResponse) {
        Output out = new Output();

        if (String.isBlank(promptResponse)) {
            out.isSuccess = false;
            out.errorMessage = 'promptResponse가 비어 있습니다(null 또는 blank).';
            return out;
        }

        Map<String, Object> parsed;
        try {
            Object decoded = JSON.deserializeUntyped(promptResponse);
            if (!(decoded instanceof Map<String, Object>)) {
                out.isSuccess = false;
                out.errorMessage = 'JSON 최상위 구조가 객체(Map)가 아닙니다: ' + promptResponse.abbreviate(200);
                return out;
            }
            parsed = (Map<String, Object>) decoded;
        } catch (Exception e) {
            out.isSuccess = false;
            out.errorMessage = 'JSON 파싱 실패(' + e.getTypeName() + '): ' + e.getMessage()
                + ' / 원본(앞 200자): ' + promptResponse.abbreviate(200);
            return out;
        }

        out.summary = asString(parsed.get('Summary'));
        out.keyDecision = asString(parsed.get('Key_Decision'));
        out.concernsObjections = asString(parsed.get('Concerns_Objections'));
        out.followUp = asString(parsed.get('Follow_Up'));

        String reaction = asString(parsed.get('Customer_Reaction'));
        out.customerReaction = VALID_CUSTOMER_REACTIONS.contains(reaction) ? reaction : DEFAULT_CUSTOMER_REACTION;

        out.signals = new List<Interaction_Signal__c>();
        Object signalsRaw = parsed.get('Signals');
        if (signalsRaw instanceof List<Object>) {
            for (Object signalObj : (List<Object>) signalsRaw) {
                if (!(signalObj instanceof Map<String, Object>)) {
                    out.skippedSignalCount++;
                    continue;
                }
                Map<String, Object> signalMap = (Map<String, Object>) signalObj;

                String category = asString(signalMap.get('Category'));
                String direction = asString(signalMap.get('Direction'));
                String confidence = asString(signalMap.get('Confidence'));

                Boolean valid = VALID_SIGNAL_CATEGORIES.contains(category)
                    && VALID_DIRECTIONS.contains(direction)
                    && VALID_CONFIDENCE_LEVELS.contains(confidence);

                if (!valid) {
                    out.skippedSignalCount++;
                    continue;
                }

                // Interaction_Intelligence__c(Master-Detail 부모)는 파싱 시점에는 아직 모르므로
                // 여기서는 채우지 않는다. Flow가 상위 레코드 생성/조회 후 채워서 insert한다.
                out.signals.add(new Interaction_Signal__c(
                    Signal_Category__c = category,
                    Signal_Type__c = asString(signalMap.get('Type')),
                    Direction__c = direction,
                    Confidence__c = confidence,
                    Evidence__c = asString(signalMap.get('Evidence')).abbreviate(255)
                ));
            }
        }

        out.isSuccess = true;
        return out;
    }

    private static String asString(Object val) {
        return val == null ? '' : String.valueOf(val);
    }

    public class Input {
        @InvocableVariable(label='Prompt Response (JSON)' required=true)
        public String promptResponse;
    }

    public class Output {
        @InvocableVariable(label='파싱 성공 여부')
        public Boolean isSuccess = false;

        @InvocableVariable(label='오류 메시지')
        public String errorMessage = '';

        @InvocableVariable(label='Summary')
        public String summary = '';

        @InvocableVariable(label='Customer Reaction')
        public String customerReaction = '';

        @InvocableVariable(label='Key Decision')
        public String keyDecision = '';

        @InvocableVariable(label='Concerns / Objections')
        public String concernsObjections = '';

        @InvocableVariable(label='Follow Up')
        public String followUp = '';

        @InvocableVariable(label='건너뛴 Signal 개수')
        public Integer skippedSignalCount = 0;

        @InvocableVariable(label='Signals')
        public List<Interaction_Signal__c> signals = new List<Interaction_Signal__c>();
    }
}

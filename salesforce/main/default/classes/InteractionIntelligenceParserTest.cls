@isTest
private class InteractionIntelligenceParserTest {

    // Case A: 정상 JSON + Signal 여러 개
    @isTest
    static void testValidJsonMultipleSignals() {
        String json = '{'
            + '"Summary": "달바 측은 2~3억 스폰서십 예산을 검토 중이며 Gold 패키지에 관심을 보였다.",'
            + '"Customer_Reaction": "Positive",'
            + '"Key_Decision": "다음 주 예산회의 후 재검토",'
            + '"Concerns_Objections": "",'
            + '"Follow_Up": "예산회의 후 재연락",'
            + '"Signals": ['
            + '  {"Category":"INTEREST","Type":"High Interest","Direction":"Positive","Confidence":"High","Evidence":"Gold 패키지에 관심을 보임"},'
            + '  {"Category":"BUDGET","Type":"Budget Under Review","Direction":"Neutral","Confidence":"Medium","Evidence":"2~3억 예산 검토 중"}'
            + ']}';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        List<InteractionIntelligenceParser.Output> results = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), '입력 1건에 출력도 1건이어야 함');
        InteractionIntelligenceParser.Output out = results[0];
        System.assertEquals(true, out.isSuccess, '정상 JSON은 파싱에 성공해야 함');
        System.assertEquals('Positive', out.customerReaction, 'Customer Reaction이 그대로 반영되어야 함');
        System.assertEquals(2, out.signals.size(), 'Signal 2건이 모두 유효해야 함');
        System.assertEquals(0, out.skippedSignalCount, '유효한 Signal만 있으므로 스킵 건수는 0이어야 함');
        System.assertEquals('INTEREST', out.signals[0].Signal_Category__c, '첫 번째 Signal Category가 일치해야 함');
        System.assertEquals('BUDGET', out.signals[1].Signal_Category__c, '두 번째 Signal Category가 일치해야 함');
    }

    // Case B: 정상 JSON + Signals []
    @isTest
    static void testEmptySignalsArray() {
        String json = '{"Summary":"짧은 미팅","Customer_Reaction":"Neutral","Key_Decision":"","Concerns_Objections":"","Follow_Up":"","Signals":[]}';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(true, out.isSuccess, 'Signals가 빈 배열이어도 파싱은 성공해야 함');
        System.assertEquals(0, out.signals.size(), 'Signal이 0건이어야 함');
        System.assertEquals(0, out.skippedSignalCount, '스킵 건수도 0이어야 함');
    }

    // Case C: 일부 scalar 값이 빈 문자열
    @isTest
    static void testBlankScalarValues() {
        String json = '{"Summary":"요약만 있음","Customer_Reaction":"Not Determined","Key_Decision":"","Concerns_Objections":"","Follow_Up":"","Signals":[]}';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(true, out.isSuccess, '빈 문자열 scalar 값도 파싱 성공해야 함');
        System.assertEquals('', out.keyDecision, 'Key_Decision 빈 문자열이 그대로 유지되어야 함');
        System.assertEquals('', out.concernsObjections, 'Concerns_Objections 빈 문자열이 그대로 유지되어야 함');
        System.assertEquals('', out.followUp, 'Follow_Up 빈 문자열이 그대로 유지되어야 함');
    }

    // Case D: 일부 값 null (JSON의 null 리터럴 + 키 자체가 없는 경우)
    @isTest
    static void testNullScalarValues() {
        String json = '{"Summary":"요약","Customer_Reaction":null,"Key_Decision":null,"Follow_Up":""}';
        // Concerns_Objections와 Signals 키 자체가 없음 — 누락된 키도 안전 처리되어야 함

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(true, out.isSuccess, 'JSON null 값과 누락된 키가 있어도 파싱은 성공해야 함');
        System.assertEquals('', out.keyDecision, 'null 값은 빈 문자열로 정규화되어야 함');
        System.assertEquals('', out.concernsObjections, '키 자체가 없어도 빈 문자열로 처리되어야 함');
        System.assertEquals('Not Determined', out.customerReaction, 'null Customer_Reaction은 Not Determined로 대체되어야 함');
        System.assertEquals(0, out.signals.size(), 'Signals 키가 없으면 빈 목록이어야 함');
    }

    // Case E: malformed JSON
    @isTest
    static void testMalformedJson() {
        String json = '{"Summary": "닫히지 않은 문자열, "Customer_Reaction": Positive';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(false, out.isSuccess, 'malformed JSON은 파싱 실패로 처리되어야 함');
        System.assertNotEquals('', out.errorMessage, '실패 원인이 errorMessage에 남아 있어야 함(조용히 무시 금지)');
    }

    // blank promptResponse (null / 빈 문자열)도 동일하게 명확한 실패로 처리되어야 함
    @isTest
    static void testBlankPromptResponse() {
        Test.startTest();
        InteractionIntelligenceParser.Input inpNull = new InteractionIntelligenceParser.Input();
        inpNull.promptResponse = null;
        InteractionIntelligenceParser.Input inpEmpty = new InteractionIntelligenceParser.Input();
        inpEmpty.promptResponse = '';

        List<InteractionIntelligenceParser.Output> results = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inpNull, inpEmpty }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'null promptResponse는 실패로 처리되어야 함');
        System.assertEquals(false, results[1].isSuccess, '빈 문자열 promptResponse는 실패로 처리되어야 함');
    }

    // Case F: 허용되지 않은 Signal Category — 해당 Signal만 제외, 나머지는 유지
    @isTest
    static void testInvalidSignalCategorySkipped() {
        String json = '{'
            + '"Summary":"요약","Customer_Reaction":"Positive","Key_Decision":"","Concerns_Objections":"","Follow_Up":"",'
            + '"Signals": ['
            + '  {"Category":"FOLLOW_UP","Type":"잘못된 카테고리","Direction":"Positive","Confidence":"High","Evidence":"허용값 아님"},'
            + '  {"Category":"BUDGET","Type":"Budget Confirmed","Direction":"Positive","Confidence":"High","Evidence":"정상 Signal"}'
            + ']}';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(true, out.isSuccess, '일부 Signal이 유효하지 않아도 전체 파싱은 성공해야 함');
        System.assertEquals(1, out.signals.size(), '유효하지 않은 Category를 가진 Signal 1건은 제외되어야 함');
        System.assertEquals('BUDGET', out.signals[0].Signal_Category__c, '남은 Signal은 정상 Category를 가진 것이어야 함');
        System.assertEquals(1, out.skippedSignalCount, '스킵된 Signal 개수가 1이어야 함');
    }

    // Direction/Confidence가 허용값이 아닌 경우도 동일하게 해당 Signal만 제외되어야 함
    @isTest
    static void testInvalidDirectionAndConfidenceSkipped() {
        String json = '{'
            + '"Summary":"요약","Customer_Reaction":"Positive","Key_Decision":"","Concerns_Objections":"","Follow_Up":"",'
            + '"Signals": ['
            + '  {"Category":"INTEREST","Type":"오타","Direction":"positive","Confidence":"High","Evidence":"소문자 direction"},'
            + '  {"Category":"RISK","Type":"오타2","Direction":"Negative","Confidence":"med","Evidence":"잘못된 confidence"},'
            + '  {"Category":"FIT","Type":"정상","Direction":"Neutral","Confidence":"Low","Evidence":"정상 Signal"}'
            + ']}';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(1, out.signals.size(), 'Direction/Confidence 오류 Signal 2건은 제외되고 1건만 남아야 함');
        System.assertEquals('FIT', out.signals[0].Signal_Category__c, '남은 Signal은 모든 값이 정상인 것이어야 함');
        System.assertEquals(2, out.skippedSignalCount, '스킵된 Signal 개수가 2여야 함');
    }

    // Case G: Evidence에 한글/영문/특수문자가 섞인 경우
    @isTest
    static void testMixedLanguageEvidenceInSignal() {
        String evidence = '고객이 "3억 이상은 어렵다"고 말함 (budget concern) - 100% 확신 아님 & 추가 확인 필요!';
        String json = JSON.serialize(new Map<String, Object>{
            'Summary' => '한글/영문 혼합 요약 Summary text 100%',
            'Customer_Reaction' => 'Negative',
            'Key_Decision' => '',
            'Concerns_Objections' => evidence,
            'Follow_Up' => '',
            'Signals' => new List<Object>{
                new Map<String, Object>{
                    'Category' => 'BUDGET',
                    'Type' => 'Budget Concern',
                    'Direction' => 'Negative',
                    'Confidence' => 'High',
                    'Evidence' => evidence
                }
            }
        });

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(true, out.isSuccess, '한글/영문/특수문자 혼합 값도 정상 파싱되어야 함');
        System.assertEquals(1, out.signals.size(), 'Signal 1건이 정상 파싱되어야 함');
        System.assertEquals(evidence, out.signals[0].Evidence__c, 'Evidence 문자열이 손실 없이 그대로 보존되어야 함');
    }

    // 예상하지 못한 추가 필드가 있어도 전체 parsing이 깨지지 않아야 함
    @isTest
    static void testExtraUnexpectedFieldsIgnored() {
        String json = '{'
            + '"Summary":"요약","Customer_Reaction":"Positive","Key_Decision":"","Concerns_Objections":"","Follow_Up":"",'
            + '"Confidence_Overall":"High",'
            + '"Model_Version":"gpt-5-mini",'
            + '"Signals": [{"Category":"MOMENTUM","Type":"정상","Direction":"Positive","Confidence":"High","Evidence":"정상 Signal","ExtraKey":"무시되어야 함"}]'
            + '}';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(true, out.isSuccess, '계약에 없는 추가 필드가 있어도 파싱은 성공해야 함');
        System.assertEquals(1, out.signals.size(), '추가 필드와 무관하게 정상 Signal은 파싱되어야 함');
    }

    // 허용되지 않은 Customer_Reaction 값은 Not Determined로 대체되어야 함(레코드 저장 실패 방지)
    @isTest
    static void testInvalidCustomerReactionDefaultsToNotDetermined() {
        String json = '{"Summary":"요약","Customer_Reaction":"Somewhat Positive","Key_Decision":"","Concerns_Objections":"","Follow_Up":"","Signals":[]}';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals('Not Determined', out.customerReaction, '허용되지 않은 값은 Not Determined로 대체되어야 함');
    }

    // JSON 최상위 구조가 객체(Map)가 아니라 배열인 경우 — 명확한 실패로 처리되어야 함
    @isTest
    static void testTopLevelJsonIsArrayNotObject() {
        String json = '["Summary", "Customer_Reaction"]';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(false, out.isSuccess, '최상위가 객체가 아니면 실패로 처리되어야 함');
        System.assertNotEquals('', out.errorMessage, '실패 원인이 남아 있어야 함');
    }

    // Signals 배열 안에 객체가 아닌 값(문자열 등)이 섞여 있는 경우 — 그 항목만 스킵되어야 함
    @isTest
    static void testSignalsArrayContainsNonObjectElement() {
        String json = '{'
            + '"Summary":"요약","Customer_Reaction":"Positive","Key_Decision":"","Concerns_Objections":"","Follow_Up":"",'
            + '"Signals": ['
            + '  "이건 객체가 아니라 문자열입니다",'
            + '  {"Category":"TIMING","Type":"정상","Direction":"Positive","Confidence":"High","Evidence":"정상 Signal"}'
            + ']}';

        Test.startTest();
        InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
        inp.promptResponse = json;
        InteractionIntelligenceParser.Output out = InteractionIntelligenceParser.parse(
            new List<InteractionIntelligenceParser.Input>{ inp }
        )[0];
        Test.stopTest();

        System.assertEquals(true, out.isSuccess, '전체 파싱은 성공해야 함');
        System.assertEquals(1, out.signals.size(), '객체가 아닌 항목은 제외하고 정상 Signal만 남아야 함');
        System.assertEquals(1, out.skippedSignalCount, '객체가 아닌 항목 1건이 스킵되어야 함');
    }

    // 대량 호출(Flow bulk 상황)에서도 입력 개수만큼 출력이 나와야 함
    @isTest
    static void testBulkInvocation() {
        List<InteractionIntelligenceParser.Input> inputs = new List<InteractionIntelligenceParser.Input>();
        for (Integer i = 0; i < 50; i++) {
            InteractionIntelligenceParser.Input inp = new InteractionIntelligenceParser.Input();
            inp.promptResponse = '{"Summary":"요약 ' + i + '","Customer_Reaction":"Neutral","Signals":[]}';
            inputs.add(inp);
        }

        Test.startTest();
        List<InteractionIntelligenceParser.Output> results = InteractionIntelligenceParser.parse(inputs);
        Test.stopTest();

        System.assertEquals(50, results.size(), '입력 50건에 출력도 50건이어야 함(bulk 안전성)');
        for (InteractionIntelligenceParser.Output out : results) {
            System.assertEquals(true, out.isSuccess, 'bulk 상황에서도 각 건이 정상 파싱되어야 함');
        }
    }
}

/**
 * Invokes the online-meeting prompt with the canonical Event and the raw ECI
 * VideoCallTranscript. Flow's Prompt Template action cannot bind
 * VideoCallTranscript in this org, so the Connect API is the narrow bridge.
 */
public with sharing class OnlineMeetingTranscriptPrompt {
    private static final String TEMPLATE_NAME = 'CA_Online_Meeting_Transcript_Intelligence_V2';

    @TestVisible private static String testPromptResponse;
    @TestVisible private static Request lastRequest;

    public class Request {
        @InvocableVariable(required=true)
        public Id eventId;

        @InvocableVariable(required=true)
        public String transcriptContent;
    }

    public class Response {
        @InvocableVariable
        public String promptResponse;
    }

    @InvocableMethod(
        label='Generate Online Meeting Intelligence'
        description='Generates intelligence from a canonical Online Event and its raw ECI transcript.'
    )
    public static List<Response> generate(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request request : requests) {
            if (request == null || request.eventId == null || String.isBlank(request.transcriptContent)) {
                throw new OnlineMeetingTranscriptPromptException('Canonical Event and ECI transcript are required.');
            }
            lastRequest = request;
            Response response = new Response();
            response.promptResponse = Test.isRunningTest() && testPromptResponse != null
                ? testPromptResponse
                : generateResponse(request.eventId, request.transcriptContent);
            responses.add(response);
        }
        return responses;
    }

    private static String generateResponse(Id eventId, String transcriptContent) {
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>{
            'Input.Meeting' => recordInput(eventId),
            'Input:Transcript' => stringInput(transcriptContent)
        };
        ConnectApi.EinsteinPromptTemplateGenerationsInput generationInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        generationInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        generationInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        generationInput.isPreview = false;
        generationInput.inputParams = inputParams;

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE_NAME, generationInput);
        if (result == null || result.generations == null || result.generations.isEmpty()) {
            throw new OnlineMeetingTranscriptPromptException('Prompt generation returned no response.');
        }
        return result.generations[0].text;
    }

    private static ConnectApi.WrappedValue recordInput(Id recordId) {
        ConnectApi.WrappedValue input = new ConnectApi.WrappedValue();
        input.value = new Map<String, String>{ 'id' => String.valueOf(recordId) };
        return input;
    }

    private static ConnectApi.WrappedValue stringInput(String value) {
        ConnectApi.WrappedValue input = new ConnectApi.WrappedValue();
        input.value = value;
        return input;
    }

    public class OnlineMeetingTranscriptPromptException extends Exception {}
}

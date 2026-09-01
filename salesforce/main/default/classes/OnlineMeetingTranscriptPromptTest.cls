@IsTest
private class OnlineMeetingTranscriptPromptTest {
    @IsTest
    static void returnsTestGenerationWithoutWritingBusinessData() {
        OnlineMeetingTranscriptPrompt.testPromptResponse = '{"summary":"test"}';
        OnlineMeetingTranscriptPrompt.Request request = new OnlineMeetingTranscriptPrompt.Request();
        request.eventId = '00U000000000001EAA';
        request.transcriptContent = '원문 transcript test content';

        Test.startTest();
        List<OnlineMeetingTranscriptPrompt.Response> results =
            OnlineMeetingTranscriptPrompt.generate(new List<OnlineMeetingTranscriptPrompt.Request>{ request });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('{"summary":"test"}', results[0].promptResponse);
        System.assertEquals(request.eventId, OnlineMeetingTranscriptPrompt.lastRequest.eventId);
        System.assertEquals(request.transcriptContent, OnlineMeetingTranscriptPrompt.lastRequest.transcriptContent);
    }

    @IsTest
    static void rejectsMissingRequiredReferences() {
        try {
            OnlineMeetingTranscriptPrompt.generate(
                new List<OnlineMeetingTranscriptPrompt.Request>{ new OnlineMeetingTranscriptPrompt.Request() }
            );
            System.assert(false, 'Missing references must not call the prompt.');
        } catch (OnlineMeetingTranscriptPrompt.OnlineMeetingTranscriptPromptException expected) {
            System.assert(expected.getMessage().contains('required'));
        }
    }
}

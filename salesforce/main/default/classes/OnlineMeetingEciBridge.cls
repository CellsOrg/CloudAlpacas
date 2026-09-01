/**
 * Resolves an ECI VideoCall transcript to the one canonical Online Event.
 *
 * This class intentionally never writes VideoCall.EventId (a read-only standard
 * field), never creates an Event, and never uses subject/time/attendee matching.
 * A match requires the exact provider meeting key stored on both records.
 */
public with sharing class OnlineMeetingEciBridge {
    @InvocableMethod(
        label='Resolve Online Meeting ECI Bridge'
        description='Safely resolves a VideoCall transcript to an existing Online Event using the exact ECI meeting key. No DML.'
    )
    public static List<Response> resolve(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request request : requests) {
            responses.add(resolveOne(request));
        }
        return responses;
    }

    private static Response resolveOne(Request request) {
        if (request == null || request.videoCallId == null) {
            return fail('VIDEO_CALL_ID_MISSING', 'VideoCall Id가 없어 ECI bridge를 실행하지 않았습니다.');
        }

        List<VideoCall> calls = [
            SELECT Id, RelatedRecordId, VendorMeetingUuid
            FROM VideoCall
            WHERE Id = :request.videoCallId
            WITH USER_MODE
            LIMIT 1
        ];
        if (calls.isEmpty()) {
            return fail('VIDEO_CALL_NOT_FOUND', 'VideoCall을 찾지 못해 ECI bridge를 실행하지 않았습니다.');
        }
        return resolveFor(calls[0], request.transcriptContent, request.isTranscriptTruncated);
    }

    @TestVisible
    private static Response resolveFor(
        VideoCall call,
        String transcriptContent,
        Boolean isTranscriptTruncated
    ) {
        if (String.isBlank(transcriptContent)) {
            return fail('TRANSCRIPT_EMPTY', 'Transcript가 비어 있어 ECI bridge를 실행하지 않았습니다.');
        }
        if (isTranscriptTruncated == true) {
            return fail('TRANSCRIPT_TRUNCATED', '잘린 Transcript는 분석하지 않습니다.');
        }
        if (call == null || call.RelatedRecordId == null) {
            return fail('RELATED_RECORD_MISSING', 'VideoCall Related Record가 없어 ECI bridge를 실행하지 않았습니다.');
        }
        if (call.RelatedRecordId.getSObjectType() != Opportunity.SObjectType) {
            return fail('RELATED_RECORD_NOT_OPPORTUNITY', 'VideoCall Related Record가 Opportunity가 아니어서 ECI bridge를 실행하지 않았습니다.');
        }
        if (String.isBlank(call.VendorMeetingUuid)) {
            return fail('MEETING_KEY_MISSING', 'VideoCall Vendor Meeting UUID가 없어 ECI bridge를 실행하지 않았습니다.');
        }

        List<Event> events = [
            SELECT Id, WhatId, Meeting_Type__c, External_ID__c
            FROM Event
            WHERE External_ID__c = :call.VendorMeetingUuid
            WITH USER_MODE
            LIMIT 2
        ];
        if (events.isEmpty()) {
            return fail('CANONICAL_EVENT_NOT_FOUND', '일치하는 Online Event가 없어 ECI bridge를 안전하게 종료했습니다.');
        }
        if (events.size() != 1) {
            return fail('CANONICAL_EVENT_NOT_UNIQUE', '동일 meeting key의 Event가 둘 이상이라 ECI bridge를 안전하게 종료했습니다.');
        }

        Event eventRecord = events[0];
        if (eventRecord.Meeting_Type__c != 'Online') {
            return fail('CANONICAL_EVENT_NOT_ONLINE', '일치 Event의 Meeting Type이 Online이 아니어서 ECI bridge를 실행하지 않았습니다.');
        }
        if (eventRecord.WhatId != call.RelatedRecordId) {
            return fail('OPPORTUNITY_MISMATCH', 'VideoCall과 Event의 Opportunity가 달라 ECI bridge를 안전하게 종료했습니다.');
        }

        Response response = new Response();
        response.isProcessable = true;
        response.statusCode = 'MATCHED';
        response.statusMessage = 'Exact provider meeting key로 canonical Online Event를 확인했습니다.';
        response.eventId = eventRecord.Id;
        response.opportunityId = eventRecord.WhatId;
        return response;
    }

    private static Response fail(String statusCode, String statusMessage) {
        Response response = new Response();
        response.isProcessable = false;
        response.statusCode = statusCode;
        response.statusMessage = statusMessage;
        System.debug(LoggingLevel.WARN, 'OnlineMeetingEciBridge ' + statusCode + ': ' + statusMessage);
        return response;
    }

    public class Request {
        @InvocableVariable(label='Video Call Id' required=true)
        public Id videoCallId;

        @InvocableVariable(label='Transcript Content' required=true)
        public String transcriptContent;

        @InvocableVariable(label='Transcript Is Truncated' required=true)
        public Boolean isTranscriptTruncated;
    }

    public class Response {
        @InvocableVariable(label='Is Processable')
        public Boolean isProcessable = false;

        @InvocableVariable(label='Status Code')
        public String statusCode;

        @InvocableVariable(label='Status Message')
        public String statusMessage;

        @InvocableVariable(label='Canonical Event Id')
        public Id eventId;

        @InvocableVariable(label='Opportunity Id')
        public Id opportunityId;
    }
}

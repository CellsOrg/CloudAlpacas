@isTest
private class OpportunityAgentChatControllerTest {

    // Routes each callout by URL so one mock covers the whole conversation flow.
    private class AgentApiMock implements HttpCalloutMock {
        Integer sessionStatus = 200;
        Integer messageStatus = 200;
        Integer messageCalls = 0;
        Boolean expireFirstMessage = false;
        String messageBody =
            '{"messages":[{"type":"Inform","message":"현재 Opportunity에 대한 답변입니다.","planId":"p1"}]}';

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String url = req.getEndpoint();

            // Callouts go through the CA_Agent_API Named Credential — auth header is
            // injected by the platform, never built here.
            System.assert(url.startsWith('callout:CA_Agent_API/'), 'must call via the Named Credential: ' + url);
            System.assertEquals(null, req.getHeader('Authorization'), 'Apex never sets Authorization; the Named Credential does');

            if (url.endsWith('/sessions') && req.getMethod() == 'POST') {
                res.setStatusCode(sessionStatus);
                res.setBody(sessionStatus == 200
                    ? '{"sessionId":"sess-123"}'
                    : '{"status":' + sessionStatus + ',"message":"Bad Request"}');
                return res;
            }
            if (url.contains('/messages')) {
                messageCalls++;
                if (expireFirstMessage && messageCalls == 1) {
                    res.setStatusCode(404);
                    res.setBody('{"status":404,"message":"session not found"}');
                    return res;
                }
                res.setStatusCode(messageStatus);
                res.setBody(messageStatus == 200
                    ? messageBody
                    : '{"status":' + messageStatus + ',"message":"boom"}');
                return res;
            }
            if (req.getMethod() == 'DELETE') {
                res.setStatusCode(204);
                res.setBody('');
                return res;
            }
            res.setStatusCode(500);
            res.setBody('{"message":"unexpected"}');
            return res;
        }
    }

    @isTest
    static void firstTurnStartsSessionAndReturnsReply() {
        OpportunityAgentChatController.agentIdForTest = '0Xxbm000000000AAAA';
        AgentApiMock mock = new AgentApiMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        OpportunityAgentChatController.ChatTurn turn =
            OpportunityAgentChatController.sendMessage('006bm00000VXKvlAAH', null, '이 딜 상태 어때?');
        Test.stopTest();

        System.assertEquals('sess-123', turn.sessionId, 'session id from start call');
        System.assert(turn.reply.contains('현재 Opportunity에 대한 답변'), 'agent reply relayed: ' + turn.reply);
        System.assertEquals(false, turn.sessionRestarted);
        System.assertEquals(1, mock.messageCalls, 'exactly one message POST on the happy path');
    }

    @isTest
    static void followUpTurnReusesSessionWithoutRecordPrefix() {
        OpportunityAgentChatController.agentIdForTest = '0Xxbm000000000AAAA';
        Test.setMock(HttpCalloutMock.class, new AgentApiMock());

        Test.startTest();
        OpportunityAgentChatController.ChatTurn turn =
            OpportunityAgentChatController.sendMessage('006bm00000VXKvlAAH', 'sess-existing', '그중 가장 걱정되는 건?');
        Test.stopTest();

        System.assertEquals('sess-existing', turn.sessionId, 'existing session kept');
        System.assert(String.isNotBlank(turn.reply));
    }

    @isTest
    static void emptyMessageRejected() {
        Test.setMock(HttpCalloutMock.class, new AgentApiMock());
        Test.startTest();
        try {
            OpportunityAgentChatController.sendMessage('006bm00000VXKvlAAH', null, '   ');
            System.assert(false, '빈 메시지는 거부되어야 한다');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('메시지를 입력하세요'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void expiredSessionRestartsOnceTransparently() {
        OpportunityAgentChatController.agentIdForTest = '0Xxbm000000000AAAA';
        AgentApiMock mock = new AgentApiMock();
        mock.expireFirstMessage = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        OpportunityAgentChatController.ChatTurn turn =
            OpportunityAgentChatController.sendMessage('006bm00000VXKvlAAH', 'stale-session', '이 딜 상태 어때?');
        Test.stopTest();

        System.assertEquals(true, turn.sessionRestarted, 'restarted after 404');
        System.assertEquals('sess-123', turn.sessionId, 'new session id after restart');
        System.assertEquals(2, mock.messageCalls, 'one failed + one retried message POST');
        System.assert(turn.reply.contains('답변'));
    }

    @isTest
    static void apiErrorIsSanitized() {
        OpportunityAgentChatController.agentIdForTest = '0Xxbm000000000AAAA';
        AgentApiMock mock = new AgentApiMock();
        mock.messageStatus = 500;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        try {
            OpportunityAgentChatController.sendMessage('006bm00000VXKvlAAH', 'sess-x', 'hello');
            System.assert(false, 'should throw on 500');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('메시지를 보내지 못했습니다'), e.getMessage());
            System.assert(!e.getMessage().contains('eyJ'), 'no token leak');
        }
        Test.stopTest();
    }

    @isTest
    static void sessionStartFailureSurfacesFriendlyError() {
        OpportunityAgentChatController.agentIdForTest = '0Xxbm000000000AAAA';
        AgentApiMock mock = new AgentApiMock();
        mock.sessionStatus = 400;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        try {
            OpportunityAgentChatController.sendMessage('006bm00000VXKvlAAH', null, 'hi');
            System.assert(false, 'should throw');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('대화 세션을 시작하지 못했습니다'), e.getMessage());
        }
        Test.stopTest();
    }

    private class CalloutBoom implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Unable to fetch the OAuth token.');
        }
    }

    @isTest
    static void namedCredentialFailureSurfacesActionableHint() {
        OpportunityAgentChatController.agentIdForTest = '0Xxbm000000000AAAA';
        Test.setMock(HttpCalloutMock.class, new CalloutBoom());
        Test.startTest();
        try {
            OpportunityAgentChatController.sendMessage('006bm00000VXKvlAAH', null, 'hi');
            System.assert(false, 'should throw when the credential is mis-configured');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('CA_Agent_API'), e.getMessage());
            // the safe platform reason is passed through so admins can act on it
            System.assert(e.getMessage().contains('Unable to fetch the OAuth token'), e.getMessage());
            // but never a token / secret / Authorization header
            System.assert(!e.getMessage().containsIgnoreCase('bearer') && !e.getMessage().contains('eyJ'), 'no token leak');
        }
        Test.stopTest();
    }

    @isTest
    static void endConversationNeverThrows() {
        Test.setMock(HttpCalloutMock.class, new AgentApiMock());
        Test.startTest();
        OpportunityAgentChatController.endConversation('sess-123');
        OpportunityAgentChatController.endConversation(null);
        OpportunityAgentChatController.endConversation('');
        Test.stopTest();
        System.assert(true, 'endConversation is best-effort and silent');
    }

    @isTest
    static void extractReplyJoinsMultipleMessagesAndHandlesJunk() {
        String body = '{"messages":[{"message":"첫 번째"},{"message":""},{"message":"두 번째"},{"noText":true}]}';
        System.assertEquals('첫 번째\n\n두 번째', OpportunityAgentChatController.extractReply(body));
        System.assertEquals('Agent가 응답 텍스트를 반환하지 않았습니다.',
            OpportunityAgentChatController.extractReply('not json'));
    }

    @isTest
    static void runsUnderAgentAccessUser() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CA_Opportunity_Agent_Access' LIMIT 1];
            Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            u = new User(
                FirstName = 'OAC', LastName = 'QA', Alias = 'oacqa',
                Email = 'oac.qa@example.com.invalid',
                Username = 'oac.qa.' + System.now().getTime() + '@example.com.invalid',
                ProfileId = std.Id, TimeZoneSidKey = 'Asia/Seoul', LocaleSidKey = 'ko_KR',
                EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert u;
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }

        Test.startTest();
        System.runAs(u) {
            OpportunityAgentChatController.agentIdForTest = '0Xxbm000000000AAAA';
            Test.setMock(HttpCalloutMock.class, new AgentApiMock());
            OpportunityAgentChatController.ChatTurn turn =
                OpportunityAgentChatController.sendMessage('006bm00000VXKvlAAH', null, '테스트');
            System.assert(String.isNotBlank(turn.reply), 'agent-access user can reach the bridge');
        }
        Test.stopTest();
    }
}

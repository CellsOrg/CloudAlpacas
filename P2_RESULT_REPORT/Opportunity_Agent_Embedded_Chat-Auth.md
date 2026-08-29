# Embedded Opportunity Agent Chat — Final Authentication Architecture

The embedded chat (`opportunityAgentChat` LWC → `OpportunityAgentChatController` Apex
→ Agentforce **Agent API** → Opportunity Agent) authenticates with **Per-User OAuth**,
not Client Credentials.

## Working flow

```
Salesforce logged-in user
  → Per-User OAuth (one-time browser "Allow" per user)
  → Auth Provider      CA_Agent_API_PerUser      (Salesforce type; PKCE on)
  → External Credential CA_Agent_API_PerUser_Cred (OAuth 2.0, Browser Flow, Per User Principal)
  → Named Credential   CA_Agent_API_PerUser       (URL https://api.salesforce.com)
  → Apex callout:CA_Agent_API_PerUser/einstein/ai-agent/v1/...
  → Opportunity Agent (BotDefinition 0Xxbm000003LcADCA0, AgentforceEmployeeAgent, active v6)
```

`OpportunityAgentChatController.AGENT_API` = `callout:CA_Agent_API_PerUser/einstein/ai-agent/v1`,
used for `startSession` (POST `/agents/{id}/sessions`), `rawPostMessage`
(POST `/sessions/{id}/messages`), and `endConversation` (DELETE `/sessions/{id}`).

## Why not Client Credentials

`CA_Agent_API` (Client Credentials with Client Secret Flow) was tried and abandoned.
Two token-endpoint Setup issues were corrected first (the Identity Provider URL was
missing the `/services/oauth2/token` path; the `Scope` field had to be cleared —
Salesforce's client-credentials token endpoint rejects a `scope` parameter). Adding
`refresh_token` scope and "Issue JWT for named users" was also tried and did not help.
OAuth token acquisition eventually succeeded, but the Agent API still returned a
**bare HTTP 404 with no body and no `requestId`** for every
`api.salesforce.com/einstein/ai-agent/*` path (and for `/` and other SFAP paths) —
the gateway does not route an app-only client-credentials token to an internal
**Employee Agent**. The identical endpoint + Bot Id works with a user-context token,
so the transport moved to Per-User OAuth. Do **not** revert to Client Credentials.

## One-time Setup (already completed in the org — reference only)

1. **Auth Provider** `CA_Agent_API_PerUser` (type Salesforce): authorize endpoint
   `<MyDomain>/services/oauth2/authorize`, token endpoint `<MyDomain>/services/oauth2/token`,
   default scopes `api refresh_token chatbot_api sfap_api`, PKCE enabled. Backed by an
   External Client App with those OAuth scopes.
2. **External Credential** `CA_Agent_API_PerUser_Cred`: OAuth 2.0, Browser Flow,
   Authentication Provider = `CA_Agent_API_PerUser`, principal `CA_Agent_API_PerUser_Principal`
   with Identity Type = **Per User Principal**.
3. **Named Credential** `CA_Agent_API_PerUser`: URL `https://api.salesforce.com`,
   External Credential = `CA_Agent_API_PerUser_Cred`, Generate Authorization Header on,
   Callouts enabled.
4. **Permission Set** `CA_Opportunity_Agent_Access` (in this repo): grants
   `externalCredentialPrincipalAccesses` for
   `CA_Agent_API_PerUser_Cred-CA_Agent_API_PerUser_Principal` — without it the callout
   throws *"We couldn't access the credential(s)."*

The Auth Provider / External Credential / Named Credential are **not** deployed as
repo metadata: they carry a Consumer Key/Secret and are configured in Setup.

## Per-user requirement

Each user of the embedded chat must **authorize the external system once**
(Personal Settings → *Authentication Settings for External Systems* → `CA Agent API PerUser Cred`
→ Authenticate) and hold the `CA_Opportunity_Agent_Access` permission set.

## Verified

Server-side (as the authorized user, via `callout:CA_Agent_API_PerUser`):
session create → **200** + `sessionId` + `x-request-id`; a first turn asking for the
open Tasks with **no deal name in the text** → **200**, the agent resolved the current
Opportunity from the Record Id context prefix and returned its open Tasks; a follow-up
in the same session → **200**, context retained; session DELETE → **200**.
Browser E2E on the `d'Alba - 2026 시즌 골드 파트너십` record page confirmed the same,
including the wide modal, multi-turn, and conversation history.

Agent unchanged: no `.agent` edit, no publish, no activate/deactivate — **v6 stays active**.

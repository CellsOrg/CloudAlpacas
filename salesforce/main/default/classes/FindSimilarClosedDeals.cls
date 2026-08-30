/**
 * Read-only. Ranks past Closed Won Opportunities by a DETERMINISTIC, explainable
 * similarity to a reference Opportunity (shared Account Industry, Opportunity
 * Target Segment, Partner Tier, comparable Amount band), or filters Closed Won by
 * a category / company-type keyword. Returns a Korean digest of the Top N with a
 * plain match reason. No AI, no predictive score, no DML.
 *
 * Backs the Opportunity Agent's Deal Assistant action find_similar_closed_deals.
 */
public with sharing class FindSimilarClosedDeals {

    private static final Integer DEFAULT_TOP = 3;
    private static final Integer MAX_TOP = 10;
    private static final Integer SCAN_LIMIT = 200;

    @InvocableMethod(
        label='Find Similar Closed Deals'
        description='Read-only. Ranks past Closed Won Opportunities by deterministic similarity (shared Account industry, target segment, partner tier, amount band) to a reference Opportunity, or filters them by a category keyword. Returns a Korean digest. No DML.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request req : (requests == null ? new List<Request>() : requests)) {
            out.add(handle(req));
        }
        return out;
    }

    private static Result handle(Request req) {
        Result r = new Result();
        Integer topN = DEFAULT_TOP;
        if (req.topN != null && req.topN.intValue() > 0) {
            topN = Math.min(req.topN.intValue(), MAX_TOP);
        }
        String kw = (req.categoryKeyword == null) ? '' : req.categoryKeyword.trim();
        Id refId = safeId(req.opportunityId);

        Opportunity ref;
        if (refId != null) {
            List<Opportunity> refs = [
                SELECT Id, Name, Amount, Target_Segment__c, Partner_Tier__c, Account.Industry
                FROM Opportunity WHERE Id = :refId WITH USER_MODE LIMIT 1
            ];
            if (!refs.isEmpty()) {
                ref = refs[0];
            }
        }

        if (ref == null && String.isBlank(kw)) {
            r.digest = '유사도를 계산할 기준 Opportunity(현재 딜) 또는 업종/회사 유형 키워드가 필요합니다.';
            return r;
        }

        List<Opportunity> pool;
        if (String.isNotBlank(kw)) {
            String likeTerm = '%' + kw + '%';
            pool = [
                SELECT Id, Name, Amount, StageName, Target_Segment__c, Partner_Tier__c,
                       Account.Name, Account.Industry
                FROM Opportunity
                WHERE IsWon = true AND IsClosed = true
                  AND (Account.Industry LIKE :likeTerm OR Account.Name LIKE :likeTerm OR Name LIKE :likeTerm)
                WITH USER_MODE
                ORDER BY Amount DESC NULLS LAST
                LIMIT :SCAN_LIMIT
            ];
        } else {
            pool = [
                SELECT Id, Name, Amount, StageName, Target_Segment__c, Partner_Tier__c,
                       Account.Name, Account.Industry
                FROM Opportunity
                WHERE IsWon = true AND IsClosed = true
                WITH USER_MODE
                ORDER BY Amount DESC NULLS LAST
                LIMIT :SCAN_LIMIT
            ];
        }

        List<Scored> scored = new List<Scored>();
        for (Opportunity o : pool) {
            if (refId != null && o.Id == refId) {
                continue; // never the current Opportunity
            }
            List<String> reasons = new List<String>();
            Integer score = 0;
            if (ref != null) {
                if (eq(ref.Account.Industry, o.Account.Industry)) {
                    score += 3;
                    reasons.add('동일 업종(' + o.Account.Industry + ')');
                }
                if (eq(ref.Target_Segment__c, o.Target_Segment__c)) {
                    score += 2;
                    reasons.add('동일 타깃 세그먼트(' + o.Target_Segment__c + ')');
                }
                if (eq(ref.Partner_Tier__c, o.Partner_Tier__c)) {
                    score += 1;
                    reasons.add('동일 파트너 티어(' + o.Partner_Tier__c + ')');
                }
                if (ref.Amount != null && ref.Amount > 0 && o.Amount != null) {
                    Decimal ratio = o.Amount / ref.Amount;
                    if (ratio >= 0.5 && ratio <= 2) {
                        score += 1;
                        reasons.add('유사 금액대');
                    }
                }
            }
            if (String.isNotBlank(kw)) {
                score += 2;
                reasons.add('"' + kw + '" 키워드 일치');
            }
            if (ref != null && String.isBlank(kw) && score == 0) {
                continue; // no shared signal at all
            }
            Scored s = new Scored();
            s.opp = o;
            s.score = score;
            s.reason = reasons.isEmpty() ? '공통 속성 없음' : String.join(reasons, ', ');
            scored.add(s);
        }

        scored.sort();

        List<Scored> picks = new List<Scored>();
        for (Scored s : scored) {
            if (picks.size() >= topN) {
                break;
            }
            picks.add(s);
        }

        r.matchCount = picks.size();
        r.found = !picks.isEmpty();
        r.digest = buildDigest(ref, kw, picks);
        return r;
    }

    private static Boolean eq(String a, String b) {
        return a != null && b != null && a.equalsIgnoreCase(b);
    }

    private static Id safeId(String s) {
        if (String.isBlank(s)) {
            return null;
        }
        try {
            Id v = Id.valueOf(s.trim());
            return (v.getSObjectType() == Opportunity.SObjectType) ? v : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static String buildDigest(Opportunity ref, String kw, List<Scored> picks) {
        if (picks.isEmpty()) {
            return String.isNotBlank(kw)
                ? '"' + kw + '" 관련 과거 Closed Won 딜을 찾지 못했습니다.'
                : '저장된 Salesforce 데이터 기준으로 이 딜과 유사한 과거 Closed Won 딜을 찾지 못했습니다.';
        }
        List<String> lines = new List<String>();
        lines.add('저장된 Salesforce 데이터 기준 유사한 과거 Closed Won 딜 (유사도순):');
        Integer i = 1;
        for (Scored s : picks) {
            lines.add(
                i + '. ' + s.opp.Name
                + ' — 회사: ' + (s.opp.Account.Name == null ? '-' : s.opp.Account.Name)
                + ' | 금액: ' + (s.opp.Amount == null ? '-' : String.valueOf(s.opp.Amount.setScale(0)))
                + (s.opp.Account.Industry == null ? '' : ' | 업종: ' + s.opp.Account.Industry)
                + (s.opp.Partner_Tier__c == null ? '' : ' | 파트너 티어: ' + s.opp.Partner_Tier__c)
                + ' | 유사 근거: ' + s.reason
                + ' (유사도 점수 ' + s.score + ')'
            );
            i++;
        }
        lines.add('※ 위 순위는 저장된 CRM 필드(업종·타깃 세그먼트·파트너 티어·금액대) 기준의 결정적 유사도이며 AI 예측이 아닙니다.');
        return String.join(lines, '\n');
    }

    private class Scored implements Comparable {
        Opportunity opp;
        Integer score;
        String reason;
        public Integer compareTo(Object other) {
            Scored o = (Scored) other;
            if (this.score != o.score) {
                return o.score - this.score; // score desc
            }
            Decimal a1 = (opp.Amount == null) ? -1 : opp.Amount;
            Decimal a2 = (o.opp.Amount == null) ? -1 : o.opp.Amount;
            if (a1 != a2) {
                return (a2 > a1) ? 1 : -1; // amount desc
            }
            return opp.Name.compareTo(o.opp.Name); // name asc — deterministic tie-break
        }
    }

    public class Request {
        @InvocableVariable(label='Opportunity Id' description='Reference Opportunity for similarity ranking. Empty only for a pure category-keyword query.')
        public String opportunityId;

        @InvocableVariable(label='Category Keyword' description='Optional industry / company-type keyword (e.g. 화장품, 금융). Filters Closed Won by account industry / account name / opportunity name.')
        public String categoryKeyword;

        @InvocableVariable(label='Top N' description='How many results to return (default 3, max 10).')
        public Decimal topN;
    }

    public class Result {
        @InvocableVariable(label='Found' description='True when at least one similar past Closed Won deal was returned.')
        public Boolean found = false;

        @InvocableVariable(label='Match Count' description='Number of deals in the digest.')
        public Integer matchCount = 0;

        @InvocableVariable(label='Digest' description='Human-readable Korean list of similar past Closed Won deals with match reasons — safe to show the user verbatim. Stored-data similarity, not a prediction.')
        public String digest;
    }
}

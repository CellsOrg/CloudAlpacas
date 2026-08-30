public without sharing class PartnershipInquiryController {
    private static final Integer MAX_INQUIRY_LENGTH = 1000;
    private static final Integer MAX_UPLOAD_TOKEN_LENGTH = 80;
    private static final String WEBSITE_LEAD_SOURCE = 'Website';

    public class InquiryRequest {
        @AuraEnabled public String companyName;
        @AuraEnabled public String contactName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String inquiry;
        @AuraEnabled public String uploadToken;
    }

    @AuraEnabled
    public static Id submitInquiry(InquiryRequest request) {
        validateRequest(request);

        try {
            Lead inquiryLead = new Lead(
                Company = request.companyName.trim(),
                LastName = request.contactName.trim(),
                Email = request.email.trim(),
                Phone = request.phone.trim(),
                Description = request.inquiry.trim(),
                LeadSource = WEBSITE_LEAD_SOURCE
            );
            insert inquiryLead;
            linkUploadedFiles(inquiryLead.Id, request.uploadToken);
            return inquiryLead.Id;
        } catch (DmlException caughtError) {
            throw new AuraHandledException('문의 접수 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
        }
    }

    private static void validateRequest(InquiryRequest request) {
        if (request == null || String.isBlank(request.companyName) || String.isBlank(request.contactName)
            || String.isBlank(request.email) || String.isBlank(request.phone) || String.isBlank(request.inquiry)) {
            throw new AuraHandledException('필수 항목을 모두 입력해주세요.');
        }
        if (!Pattern.matches('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$', request.email.trim())) {
            throw new AuraHandledException('유효한 이메일 주소를 입력해주세요.');
        }
        if (request.inquiry.trim().length() > MAX_INQUIRY_LENGTH) {
            throw new AuraHandledException('문의 내용은 1,000자 이내로 입력해주세요.');
        }
        if (!String.isBlank(request.uploadToken) && request.uploadToken.length() > MAX_UPLOAD_TOKEN_LENGTH) {
            throw new AuraHandledException('첨부파일 식별자가 올바르지 않습니다.');
        }
    }

    private static void linkUploadedFiles(Id leadId, String uploadToken) {
        if (String.isBlank(uploadToken)) {
            return;
        }

        List<ContentVersion> uploadedVersions = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE PartnerInquiryToken_fileupload__c = :uploadToken
            AND IsLatest = true
        ];
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion versionRecord : uploadedVersions) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = versionRecord.ContentDocumentId,
                LinkedEntityId = leadId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
        if (!links.isEmpty()) {
            insert links;
        }
    }
}

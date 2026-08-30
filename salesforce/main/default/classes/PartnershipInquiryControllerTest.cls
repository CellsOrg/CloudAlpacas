@IsTest
private class PartnershipInquiryControllerTest {
    @IsTest
    static void createsWebsiteLeadAndLinksGuestUpload() {
        String uploadToken = 'partner-inquiry-test-token';
        ContentVersion uploadedFile = new ContentVersion(
            Title = 'partnership-overview',
            PathOnClient = 'partnership-overview.pdf',
            VersionData = Blob.valueOf('test document'),
            PartnerInquiryToken_fileupload__c = uploadToken
        );
        insert uploadedFile;

        Test.startTest();
        Id leadId = PartnershipInquiryController.submitInquiry(validRequest(uploadToken));
        Test.stopTest();

        Lead savedLead = [
            SELECT Company, LastName, Email, Phone, Description, LeadSource, Status
            FROM Lead WHERE Id = :leadId
        ];
        System.assertEquals('Cloud Alpacas Partner', savedLead.Company);
        System.assertEquals('홍길동', savedLead.LastName);
        System.assertEquals('contact@example.com', savedLead.Email);
        System.assertEquals('010-1234-5678', savedLead.Phone);
        System.assertEquals('제휴 가능 여부를 문의드립니다.', savedLead.Description);
        System.assertEquals('Website', savedLead.LeadSource);
        System.assertEquals('New', savedLead.Status);

        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
        ]);
    }

    @IsTest
    static void rejectsMissingRequiredValue() {
        PartnershipInquiryController.InquiryRequest request = validRequest(null);
        request.companyName = ' ';

        try {
            PartnershipInquiryController.submitInquiry(request);
            System.assert(false, 'Required-field validation must stop the insert.');
        } catch (AuraHandledException caughtError) {
            System.assertNotEquals(null, caughtError);
        }
        System.assertEquals(0, [SELECT COUNT() FROM Lead]);
    }

    @IsTest
    static void rejectsInvalidEmailAndLongInquiry() {
        PartnershipInquiryController.InquiryRequest invalidEmail = validRequest(null);
        invalidEmail.email = 'not-an-email';
        try {
            PartnershipInquiryController.submitInquiry(invalidEmail);
            System.assert(false, 'Invalid email must stop the insert.');
        } catch (AuraHandledException caughtError) {
            System.assertNotEquals(null, caughtError);
        }

        PartnershipInquiryController.InquiryRequest longInquiry = validRequest(null);
        longInquiry.inquiry = ''.leftPad(1001, '가');
        try {
            PartnershipInquiryController.submitInquiry(longInquiry);
            System.assert(false, 'Long inquiry must stop the insert.');
        } catch (AuraHandledException caughtError) {
            System.assertNotEquals(null, caughtError);
        }
        System.assertEquals(0, [SELECT COUNT() FROM Lead]);
    }

    private static PartnershipInquiryController.InquiryRequest validRequest(String uploadToken) {
        PartnershipInquiryController.InquiryRequest request = new PartnershipInquiryController.InquiryRequest();
        request.companyName = 'Cloud Alpacas Partner';
        request.contactName = '홍길동';
        request.email = 'contact@example.com';
        request.phone = '010-1234-5678';
        request.inquiry = '제휴 가능 여부를 문의드립니다.';
        request.uploadToken = uploadToken;
        return request;
    }
}

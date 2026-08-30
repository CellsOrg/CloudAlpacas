import { LightningElement, api } from 'lwc';
import submitInquiry from '@salesforce/apex/PartnershipInquiryController.submitInquiry';
import alpacaMascot from '@salesforce/resourceUrl/CA_Alpaca_Mascot';

const ACCEPTED_FILE_TYPES = ['.pdf', '.ppt', '.pptx', '.doc', '.docx', '.xls', '.xlsx', '.png', '.jpg', '.jpeg'];

export default class PartnershipInquiry extends LightningElement {
    @api homeUrl;
    @api aboutUrl;
    @api partnershipUrl;
    @api loginUrl;

    alpacaMascotUrl = alpacaMascot;
    acceptedFileTypes = ACCEPTED_FILE_TYPES;
    form = { companyName: '', contactName: '', email: '', phone: '', inquiry: '' };
    uploadToken = this.createUploadToken();
    uploadedFileName;
    errorMessage;
    isSubmitting = false;
    isSuccess = false;

    get inquiryLength() {
        return this.form.inquiry.length;
    }

    get submitLabel() {
        return this.isSubmitting ? '접수 중...' : '문의하기';
    }

    createUploadToken() {
        const values = new Uint32Array(4);
        window.crypto.getRandomValues(values);
        return Array.from(values, (value) => value.toString(16).padStart(8, '0')).join('');
    }

    handleFieldChange(event) {
        const fieldName = event.target.dataset.field;
        this.form = { ...this.form, [fieldName]: event.target.value };
        this.errorMessage = undefined;
    }

    handleUploadFinished(event) {
        const files = event.detail.files;
        this.uploadedFileName = files.length ? files[0].name : undefined;
        this.errorMessage = undefined;
    }

    async handleSubmit(event) {
        event.preventDefault();
        const fields = [...this.template.querySelectorAll('lightning-input, lightning-textarea')];
        const isValid = fields.every((field) => {
            field.reportValidity();
            return field.checkValidity();
        });
        if (!isValid) {
            return;
        }

        this.isSubmitting = true;
        this.errorMessage = undefined;
        try {
            await submitInquiry({ request: { ...this.form, uploadToken: this.uploadToken } });
            this.isSuccess = true;
        } catch (error) {
            this.errorMessage = error?.body?.message || '문의 접수 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
        } finally {
            this.isSubmitting = false;
        }
    }
}

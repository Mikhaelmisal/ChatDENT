const book = $input.first().json || {};
const text = book.whatsappText || 'Your appointment is confirmed.';
const phone = (book.lead && book.lead.phone) || (book.patient && book.patient.phone) || '';
return [{
  json: {
    evoBase: 'http://evolution-api:8080',
    evoKey: 'clinic_secret_key_123',
    evoInstance: 'clinic_default',
    number: String(phone).replace(/\D/g, ''),
    reply: text
  }
}];

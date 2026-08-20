const body = $input.first().json || {};
const clinic = body.clinicName || 'the clinic';
const url = body.googleReviewUrl || '';
const tpl = body.template || '';
const people = body.people || [];
if (!people.length) return [];
const isReview = people[0].reviewAskCount !== undefined;
return people.map(function (p) {
  const text = String(p.whatsappText || '').trim() || String(tpl)
    .replace(/\{name\}/g, p.name || '')
    .replace(/\{clinic\}/g, clinic)
    .replace(/\{reviewUrl\}/g, url);
  return {
    json: {
      evoBase: 'http://evolution-api:8080',
      evoKey: 'clinic_secret_key_123',
      evoInstance: 'clinic_default',
      number: String(p.phone || '').replace(/\D/g, ''),
      reply: text,
      phone: String(p.phone || '').replace(/\D/g, ''),
      name: p.name || '',
      type: isReview ? 'review_asked' : 'birthday_sent'
    }
  };
});

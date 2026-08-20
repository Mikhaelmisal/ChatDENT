const body = $input.first().json || {};
const people = body.people || [];
if (!people.length) return [];
const evo = body.evolution || {};
return people.map(function (p) {
  return {
    json: {
      evoBase: evo.baseUrl || 'http://evolution-api:8080',
      evoKey: 'clinic_secret_key_123',
      evoInstance: p.evoInstance || evo.instance || 'clinic_default',
      number: String(p.phone || '').replace(/\D/g, ''),
      reply: p.caption || '',
      mediaCaption: p.caption || '',
      flyerUrl: p.imageUrl || '',
      phone: String(p.phone || '').replace(/\D/g, ''),
      name: p.name || '',
      type: 'marketing_sent',
      sendMedia: !!p.imageUrl,
      leadId: p.id || ''
    }
  };
});

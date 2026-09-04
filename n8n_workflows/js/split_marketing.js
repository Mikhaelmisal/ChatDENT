function n8nEnv(name, fallback) {
  try {
    const v = $env[name];
    if (v != null && String(v).trim() !== '') return String(v).trim();
  } catch (e) {}
  return fallback == null ? '' : fallback;
}

const body = $input.first().json || {};
const people = body.people || [];
if (!people.length) return [];
const evo = body.evolution || {};
return people.map(function (p) {
  return {
    json: {
      evoBase: n8nEnv('N8N_EVO_BASE', 'http://evolution-api:8080'),
      evoKey: n8nEnv('EVOLUTION_API_KEY', ''),
      evoInstance:
        p.evoInstance ||
        evo.instance ||
        n8nEnv('WHATSAPP_SESSION_ID', 'clinic_default'),
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

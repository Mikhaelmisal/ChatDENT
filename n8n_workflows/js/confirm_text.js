function n8nEnv(name, fallback) {
  try {
    const v = $env[name];
    if (v != null && String(v).trim() !== '') return String(v).trim();
  } catch (e) {}
  return fallback == null ? '' : fallback;
}

const book = $input.first().json || {};
const text = book.whatsappText || 'Your appointment is confirmed.';
const phone = (book.lead && book.lead.phone) || (book.patient && book.patient.phone) || '';
return [{
  json: {
    evoBase: n8nEnv('N8N_EVO_BASE', 'http://evolution-api:8080'),
    evoKey: n8nEnv('EVOLUTION_API_KEY', ''),
    evoInstance: n8nEnv('WHATSAPP_SESSION_ID', 'clinic_default'),
    number: String(phone).replace(/\D/g, ''),
    reply: text
  }
}];

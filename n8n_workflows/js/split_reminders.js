function n8nEnv(name, fallback) {
  try {
    const v = $env[name];
    if (v != null && String(v).trim() !== '') return String(v).trim();
  } catch (e) {}
  return fallback == null ? '' : fallback;
}

const body = $input.first().json || {};
const reminders = body.reminders || [];
if (!reminders.length) return [];
const evo = body.evolution || {};
return reminders.map(function (r) {
  return {
    json: {
      evoBase: n8nEnv('N8N_EVO_BASE', 'http://evolution-api:8080'),
      evoKey: n8nEnv('EVOLUTION_API_KEY', ''),
      evoInstance:
        evo.instance || n8nEnv('WHATSAPP_SESSION_ID', 'clinic_default'),
      appointmentId: r.appointmentId,
      kind: r.kind || '24',
      number: String(r.phone || '').replace(/\D/g, ''),
      reply: r.whatsappText || 'Reminder: you have an appointment.'
    }
  };
});

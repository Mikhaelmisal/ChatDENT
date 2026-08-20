const body = $input.first().json || {};
const reminders = body.reminders || [];
if (!reminders.length) return [];
return reminders.map(function (r) {
  return {
    json: {
      evoBase: 'http://evolution-api:8080',
      evoKey: 'clinic_secret_key_123',
      evoInstance: 'clinic_default',
      appointmentId: r.appointmentId,
      kind: r.kind || '24',
      number: String(r.phone || '').replace(/\D/g, ''),
      reply: r.whatsappText || 'Reminder: you have an appointment.'
    }
  };
});

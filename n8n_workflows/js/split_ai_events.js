const prev = $('Parse AI result').first().json || {};
const events = prev.events || [];
if (!events.length) return [];
return events.map(function (ev) {
  return {
    json: {
      phone: prev.phone,
      name: ev.name || prev.name || '',
      type: ev.type,
      appointmentId: ev.appointmentId || '',
      interest: ev.interest || '',
      note: ev.note || ev.preferredTime || '',
      preferredTime: ev.preferredTime || ev.note || '',
      evoBase: prev.evoBase,
      evoKey: prev.evoKey,
      evoInstance: prev.evoInstance
    }
  };
});

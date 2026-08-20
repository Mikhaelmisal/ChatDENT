const prev = $input.first().json || {};
const events = prev.events || [];
if (!events.length) return [];
return events.map(function (ev) {
  return {
    json: {
      phone: prev.phone,
      name: prev.name,
      type: ev.type,
      appointmentId: ev.appointmentId || '',
      name: ev.name || prev.name,
      interest: ev.interest || ''
    }
  };
});

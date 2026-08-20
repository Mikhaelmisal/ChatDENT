const prev = $('Build AI prompt').first().json || {};
const raw = $input.first().json || {};
let content = '';
if (raw.choices && raw.choices[0] && raw.choices[0].message) {
  content = raw.choices[0].message.content || '';
}
let parsed = { reply: '', attachFlyer: false, events: [] };
try {
  parsed = JSON.parse(content);
} catch (e) {
  parsed.reply = content || 'Thank you. Our receptionist will help you shortly.';
}
const events = parsed.events || [];
if (parsed.markInterested) events.push({ type: 'interested' });
if (parsed.reschedule) events.push({ type: 'reschedule' });
if (parsed.reviewDone) events.push({ type: 'review_done' });
events.push({ type: 'assistant_replied' });

return [{
  json: {
    evoBase: prev.evoBase,
    evoKey: prev.evoKey,
    evoInstance: prev.evoInstance,
    phone: prev.phone,
    name: prev.name,
    number: prev.phone,
    reply: String(parsed.reply || 'Thank you. Our team will call you to confirm.'),
    attachFlyer: !!(parsed.attachFlyer && prev.sendFlyerAllowed && prev.flyerUrl),
    flyerUrl: prev.flyerUrl,
    events: events,
    event0: events[0] || null,
    event1: events[1] || null,
    event2: events[2] || null
  }
}];

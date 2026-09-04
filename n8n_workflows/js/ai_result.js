const prev = $('Build AI prompt').first().json || {};
const inbound = $('Parse inbound').first().json || {};
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

const inboundText = String(inbound.text || '').trim();
const inboundLower = inboundText.toLowerCase();

// Deterministic: patient replies DONE / reviewed after our review request.
const reviewDonePhrase =
  /^(done|reviewed|review done|yes done|i (left|gave|posted|submitted) (a )?review|left a review|gave review)\b/.test(
    inboundLower
  ) ||
  inboundLower === 'done' ||
  inboundLower.includes('left a review') ||
  inboundLower.includes('gave a review') ||
  inboundLower.includes('posted a review');
if (reviewDonePhrase && !events.some(function (e) { return e && e.type === 'review_done'; })) {
  events.push({ type: 'review_done' });
  if (!parsed.reply || !String(parsed.reply).trim()) {
    parsed.reply = 'Thank you so much for leaving a review — it means a lot to our team!';
  }
}

// If AI flagged reschedule but forgot note, keep a useful preference when the message isn't only "please reschedule".
const rescheduleEv = events.find(function (e) { return e && e.type === 'reschedule'; });
if (rescheduleEv) {
  const note = String(rescheduleEv.note || rescheduleEv.preferredTime || '').trim();
  if (!note && inboundText) {
    const onlyAsk =
      /^(hi|hello|hey)?[\s,]*(i (want to |would like to |need to )?)?(please )?reschedule( (my )?appointment)?[.!?]*$/i.test(
        inboundText
      ) ||
      /^(can (we|i) |please )?(change|move) (my )?(appointment|time|slot)[.!?]*$/i.test(inboundText);
    if (!onlyAsk) {
      rescheduleEv.note = inboundText.slice(0, 400);
    }
  }
}

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

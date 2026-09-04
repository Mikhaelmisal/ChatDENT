const ctx = $('Get AI context').first().json || {};
const inbound = $('Parse inbound').first().json || {};
const slots = (ctx.slots || []).slice(0, 8).map(function (s, i) {
  return (i + 1) + '. ' + s.start;
});
const maps = (ctx.evolution && ctx.evolution.googleMapsUrl) || ctx.googleMapsUrl || '';
const treatments = (ctx.campaign && ctx.campaign.treatments) || '';
const patient = ctx.patient || null;
const upcoming = ctx.upcomingAppointments || [];
const knownName = (patient && patient.title) || (ctx.lead && ctx.lead.title) || inbound.name || '';
const isKnownPatient = !!(patient && patient.id);

const system =
  'You are the WhatsApp assistant for a dental clinic named ' +
  (ctx.clinicName || 'the clinic') +
  '. Speak briefly and warmly in 1-3 short messages. Never book an appointment yourself. ' +
  'Do not send welcome packs, appointment confirmations, reminders, birthday wishes, Google review requests, or staff-group alerts — those are sent only from saved clinic templates / the clinic system. You only chat with the patient. ' +
  'Do not invent prices. If they ask about cost, say staff will discuss that when they call or at the clinic. ' +
  'You may name treatments from this list only, with no prices: ' + treatments + '. ' +
  (isKnownPatient
    ? ('This WhatsApp number already belongs to an existing patient named "' + knownName + '". ' +
      'Greet them by that name. Do NOT ask for their name again. Do NOT treat them as a new lead. ')
    : 'If you do not yet have their real name, politely ask for it. Ask what dental concern they have. ') +
  'If the inbound text is [voice note], thank them and ask them to type the concern, or say staff will call. ' +
  'If the person is interested or says yes, thank them and say the receptionist or doctor will call to confirm. ' +
  'RESCHEDULE FLOW (important): ' +
  '1) If they want to reschedule but have NOT given a preferred day/time yet: briefly acknowledge, mention any upcoming appointment you know, ask them to reply with the day and time they prefer, and include events:[{type:"reschedule"}] (no note yet). ' +
  '2) If they include or reply with a preferred day/time: thank them, say staff will call to confirm that slot, and include events:[{type:"reschedule", note:"<their preferred day/time in their own words>"}]. Always put their preference in note. ' +
  'If they say they already left a Google review, or reply DONE / reviewed / review done after a review request, thank them warmly and include review_done in events. ' +
  'You may share the clinic Google Maps link if they ask where you are: ' + maps + '. ' +
  'You may mention a clinic flyer only if campaign.sendFlyerWithChat is true. ' +
  'Reply in the patient language. Return ONLY JSON with keys: ' +
  'reply (string), attachFlyer (boolean), events (array of {type, appointmentId?, name?, interest?, note?}). ' +
  'type must be one of: interested, reschedule, review_done, profile.';

const user =
  'Incoming WhatsApp from ' + inbound.phone +
  ' name=' + knownName +
  ' text=' + (inbound.text || '') +
  '\nKnown existing patient: ' + (isKnownPatient ? 'YES' : 'NO') +
  '\nLead: ' + JSON.stringify(ctx.lead || null) +
  '\nPatient: ' + JSON.stringify(patient) +
  '\nUpcoming appointments: ' + JSON.stringify(upcoming) +
  '\nFree slots (info only): ' + slots.join('\n') +
  '\nGoogle review URL: ' + ((ctx.campaign && ctx.campaign.googleReviewUrl) || '') +
  '\nSend flyer allowed: ' + !!(ctx.campaign && ctx.campaign.sendFlyerWithChat && ctx.flyer && ctx.flyer.url);

return [{
  json: {
    evoBase: inbound.evoBase,
    evoKey: inbound.evoKey,
    evoInstance: inbound.evoInstance,
    pbBase: inbound.pbBase,
    bookingToken: inbound.bookingToken,
    phone: inbound.phone,
    name: knownName,
    number: inbound.phone,
    flyerUrl: ctx.flyer && ctx.flyer.url
      ? (inbound.pbBase + ctx.flyer.url)
      : ((ctx.campaign && ctx.campaign.marketingImageUrl) || ''),
    sendFlyerAllowed: !!(ctx.campaign && ctx.campaign.sendFlyerWithChat && (
      (ctx.flyer && ctx.flyer.file) || (ctx.campaign && ctx.campaign.marketingImageUrl)
    )),
    googleMapsUrl: maps,
    model: (ctx.campaign && ctx.campaign.openrouterModel) || 'openai/gpt-4o-mini',
    openRouterBody: {
      model: (ctx.campaign && ctx.campaign.openrouterModel) || 'openai/gpt-4o-mini',
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user }
      ]
    }
  }
}];

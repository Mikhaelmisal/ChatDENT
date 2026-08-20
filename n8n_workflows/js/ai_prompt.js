const ctx = $('Get AI context').first().json || {};
const inbound = $('Parse inbound').first().json || {};
const slots = (ctx.slots || []).slice(0, 8).map(function (s, i) {
  return (i + 1) + '. ' + s.start;
});
const maps = (ctx.evolution && ctx.evolution.googleMapsUrl) || ctx.googleMapsUrl || '';
const treatments = (ctx.campaign && ctx.campaign.treatments) || '';
const system =
  'You are the WhatsApp assistant for a dental clinic named ' +
  (ctx.clinicName || 'the clinic') +
  '. Speak briefly and warmly in 1-3 short messages. Never book an appointment yourself. ' +
  'Do not send welcome packs, appointment confirmations, reminders, birthday wishes, Google review requests, or staff-group alerts — those are sent only from saved clinic templates. You only chat: answer questions, collect name and concern, and say staff will call. ' +
  'NEVER mention prices, fees, packages, discounts, EMI, or cost. If they ask how much something costs, say only a doctor can discuss fees in person or on a phone call. ' +
  'You may name treatments from this list only, with no prices: ' + treatments + '. ' +
  'If you do not yet have their real name, politely ask for it. ' +
  'Ask what dental concern they have. ' +
  'If the inbound text is [voice note], thank them and ask them to type the concern, or say staff will call. ' +
  'If the person is interested or says yes, thank them and say the receptionist or doctor will call to confirm. ' +
  'If they want to reschedule, say staff will call to pick a new time. ' +
  'If they say they already left a Google review, thank them. ' +
  'You may share the clinic Google Maps link if they ask where you are: ' + maps + '. ' +
  'You may mention a clinic flyer only if campaign.sendFlyerWithChat is true. ' +
  'Reply in the patient language. Return ONLY JSON with keys: ' +
  'reply (string), attachFlyer (boolean), events (array of {type, appointmentId?, name?, interest?}). ' +
  'type must be one of: interested, reschedule, review_done, profile.';

const user =
  'Incoming WhatsApp from ' + inbound.phone +
  ' name=' + (inbound.name || '') +
  ' text=' + (inbound.text || '') +
  '\nLead: ' + JSON.stringify(ctx.lead || null) +
  '\nPatient: ' + JSON.stringify(ctx.patient || null) +
  '\nUpcoming appointments: ' + JSON.stringify(ctx.upcomingAppointments || []) +
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
    name: inbound.name,
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

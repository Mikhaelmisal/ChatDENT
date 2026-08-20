const inbound = $('Parse inbound').first().json || {};
const up = $input.first().json || {};
const groupJid =
  up.staffGroupJid || '120363426681576301@g.us';
const optOut = inbound.optOut === true || up.optOut === true;
const shouldReply = up.shouldReply !== false && !optOut;
const sendWelcome = shouldReply && up.isNewLead === true && !!(up.welcomeText || '').trim();
return [{
  json: Object.assign({}, inbound, {
    shouldReply: shouldReply,
    sendWelcome: sendWelcome,
    notifyGroup: up.notifyGroup === true,
    staffGroupJid: groupJid,
    groupText: up.groupText || '',
    welcomeText: up.welcomeText || '',
    optOutText: up.optOutText || '',
    number: inbound.phone,
    reply: up.groupText || '',
    isReturningPatient: up.isReturningPatient === true,
    isNewLead: up.isNewLead === true,
    optOut: optOut
  })
}];

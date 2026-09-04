const inbound = $('Parse inbound').first().json || {};
const res = $input.first().json || {};
if (res.notifyGroup !== true || !String(res.groupText || '').trim()) {
  return [];
}
return [{
  json: {
    evoBase: inbound.evoBase,
    evoKey: inbound.evoKey,
    evoInstance: inbound.evoInstance,
    number: res.staffGroupJid || '120363426681576301@g.us',
    reply: res.groupText
  }
}];

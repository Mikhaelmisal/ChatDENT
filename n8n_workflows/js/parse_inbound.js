const CONFIG = {
  bookingToken: 'rlwqer5f50usxidldnhdzyg7',
  pbBase: 'http://pocketbase:8090',
  evoBase: 'http://evolution-api:8080',
  evoKey: 'clinic_secret_key_123',
  evoInstance: 'clinic_default'
};

function pickText(msg) {
  if (!msg) return '';
  if (typeof msg === 'string') return msg;
  if (typeof msg.conversation === 'string') return msg.conversation;
  if (msg.extendedTextMessage && msg.extendedTextMessage.text) return msg.extendedTextMessage.text;
  if (msg.imageMessage && msg.imageMessage.caption) return msg.imageMessage.caption;
  if (msg.videoMessage && msg.videoMessage.caption) return msg.videoMessage.caption;
  if (msg.documentMessage && msg.documentMessage.caption) return msg.documentMessage.caption;
  if (msg.ephemeralMessage && msg.ephemeralMessage.message) return pickText(msg.ephemeralMessage.message);
  if (msg.viewOnceMessage && msg.viewOnceMessage.message) return pickText(msg.viewOnceMessage.message);
  if (msg.viewOnceMessageV2 && msg.viewOnceMessageV2.message) return pickText(msg.viewOnceMessageV2.message);
  if (msg.buttonsResponseMessage) {
    return msg.buttonsResponseMessage.selectedDisplayText || msg.buttonsResponseMessage.selectedButtonId || '';
  }
  if (msg.listResponseMessage) {
    const l = msg.listResponseMessage;
    return l.title || (l.singleSelectReply && l.singleSelectReply.selectedRowId) || '';
  }
  return '';
}

function hasVoice(msg) {
  if (!msg || typeof msg !== 'object') return false;
  return !!(msg.audioMessage || msg.pttMessage || msg.ptt || msg.voiceMessage);
}

function unwrap(raw) {
  if (!raw || typeof raw !== 'object') return {};
  if (raw.body && (raw.body.data || raw.body.key || raw.body.message)) return unwrap(raw.body);
  let inner = raw.data || raw;
  if (Array.isArray(inner)) {
    inner = inner.find(function (item) {
      return item && item.key && item.key.fromMe !== true;
    }) || inner[inner.length - 1] || {};
  }
  if (inner.data && (inner.key == null)) return unwrap(inner);
  return inner;
}

function realJid(key, inner, raw) {
  const k = key || {};
  const candidates = [
    k.remoteJidAlt,
    k.senderPn,
    k.participantAlt,
    k.remoteJid,
    inner.remoteJidAlt,
    inner.senderPn,
    inner.remoteJid,
    raw.sender,
    raw.senderPn
  ];
  let lidFallback = '';
  for (let i = 0; i < candidates.length; i++) {
    const v = String(candidates[i] || '');
    if (!v) continue;
    if (v.indexOf('@g.us') >= 0) return v;
    if (v.indexOf('@lid') >= 0) {
      if (!lidFallback) lidFallback = v;
      continue;
    }
    if (v.indexOf('@s.whatsapp.net') >= 0 || v.indexOf('@c.us') >= 0) return v;
    if (/^\d{10,15}$/.test(v.replace(/\D/g, '')) && v.indexOf('@') < 0) return v + '@s.whatsapp.net';
  }
  return lidFallback;
}

function isStopText(text) {
  const t = String(text || '').toLowerCase().replace(/[^\w\s]/g, ' ').replace(/\s+/g, ' ').trim();
  if (!t) return false;
  return (
    t === 'stop' ||
    t === 'unsubscribe' ||
    t === 'opt out' ||
    t === 'optout' ||
    t.indexOf('stop messages') >= 0 ||
    t.indexOf('do not message') >= 0 ||
    t.indexOf('dont message') >= 0 ||
    t.indexOf("don't message") >= 0 ||
    t.indexOf('stop promotions') >= 0
  );
}

const raw = $input.first().json || {};
const inner = unwrap(raw);
const key = inner.key || {};
const msg = inner.message || inner;
const chatJid = String(key.remoteJid || inner.remoteJid || '');
const jid = realJid(key, inner, raw);
const fromMe = key.fromMe === true;
const isGroup =
  chatJid.indexOf('@g.us') >= 0 ||
  chatJid.indexOf('@broadcast') >= 0 ||
  chatJid.indexOf('@newsletter') >= 0 ||
  String(jid).indexOf('@g.us') >= 0;
const isStatus = chatJid.indexOf('status@broadcast') >= 0;
const phone = jid.replace(/@.*$/, '').replace(/\D/g, '');
const name = String(inner.pushName || raw.pushName || '').trim();
const voice = hasVoice(msg);
let text = String(pickText(msg) || '').trim();
if (!text && voice) text = '[voice note]';
const optOut = !fromMe && isStopText(text);
let skipReason = '';
if (isGroup) skipReason = 'group';
else if (isStatus) skipReason = 'status';
else if (!phone) skipReason = 'noPhone';
const skip = skipReason !== '';
const staffReply = !skip && fromMe;
const choice = parseInt(text, 10);
const wantsBook = !skip && !fromMe && String(choice) === text && choice >= 1 && choice <= 12;

return [{
  json: Object.assign({}, CONFIG, {
    skip: skip,
    skipReason: skipReason,
    staffReply: staffReply,
    optOut: optOut,
    voice: voice,
    wantsBook: wantsBook,
    slotIndex: wantsBook ? choice - 1 : -1,
    phone: phone,
    name: name,
    text: text,
    jid: jid
  })
}];

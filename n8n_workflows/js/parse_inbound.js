function n8nEnv(name, fallback) {
  try {
    const v = $env[name];
    if (v != null && String(v).trim() !== '') return String(v).trim();
  } catch (e) {}
  return fallback == null ? '' : fallback;
}

const CONFIG = {
  bookingToken: n8nEnv('N8N_BOOKING_TOKEN', ''),
  pbBase: n8nEnv('N8N_PB_BASE', 'http://pocketbase:8090'),
  evoBase: n8nEnv('N8N_EVO_BASE', 'http://evolution-api:8080'),
  evoKey: n8nEnv('EVOLUTION_API_KEY', ''),
  evoInstance: n8nEnv('WHATSAPP_SESSION_ID', 'clinic_default')
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

/**
 * Meta Click-to-WhatsApp / Ads / automated business-chat entry.
 * Same as groups: do not AI-reply and do not post a new lead to the staff group.
 */
function collectContextBlobs(msg, inner, raw) {
  const out = [];
  const push = function (v) {
    if (v && typeof v === 'object') out.push(v);
  };
  push(inner.contextInfo);
  push(inner.adReferral);
  push(raw.contextInfo);
  push(raw.adReferral);
  push(msg && msg.messageContextInfo);
  if (msg && typeof msg === 'object') {
    const keys = Object.keys(msg);
    for (let i = 0; i < keys.length; i++) {
      const part = msg[keys[i]];
      if (!part || typeof part !== 'object') continue;
      push(part.contextInfo);
      push(part.externalAdReply);
      if (part.contextInfo && part.contextInfo.externalAdReply) {
        push(part.contextInfo.externalAdReply);
      }
    }
  }
  // Cloud API style
  push(inner.referral);
  push(msg && msg.referral);
  if (Array.isArray(inner.messages) && inner.messages[0]) {
    push(inner.messages[0].referral);
  }
  return out;
}

function isMetaAdAutomated(msg, inner, raw) {
  const blobs = collectContextBlobs(msg, inner, raw);
  for (let i = 0; i < blobs.length; i++) {
    const c = blobs[i];
    if (!c || typeof c !== 'object') continue;
    if (c.ctwaClid || c.ctwa_clid || c.ctwaPayload || c.ctwaSignals) return true;
    if (c.sourceId || c.source_id || c.sourceUrl || c.source_url) {
      const st = String(c.sourceType || c.source_type || c.source || '').toLowerCase();
      if (
        st &&
        (st.indexOf('ad') >= 0 ||
          st.indexOf('ctwa') >= 0 ||
          st.indexOf('fb') >= 0 ||
          st.indexOf('ig') >= 0 ||
          st.indexOf('meta') >= 0)
      ) {
        return true;
      }
    }
    const conv = String(
      c.conversionSource ||
        c.entryPointConversionSource ||
        c.entryPointConversionExternalSource ||
        c.conversion_source ||
        ''
    ).toLowerCase();
    if (
      conv.indexOf('ad') >= 0 ||
      conv.indexOf('ctwa') >= 0 ||
      conv.indexOf('fb_') >= 0 ||
      conv.indexOf('ig_') >= 0 ||
      conv === 'fb_ads' ||
      conv === 'ig_ads'
    ) {
      return true;
    }
    if (c.externalAdReply || c.external_ad_reply) return true;
    if (c.conversionData || c.conversion_data) return true;
    const app = String(c.entryPointConversionApp || '').toLowerCase();
    if (app === 'instagram' || app === 'facebook' || app === 'fb' || app === 'ig') {
      if (conv || c.ctwaClid || c.ctwa_clid || c.externalAdReply) return true;
    }
  }
  // Top-level Evolution / Cloud fields sometimes flattened onto data
  const flat = Object.assign({}, inner, raw, typeof msg === 'object' ? msg : {});
  if (flat.ctwaClid || flat.ctwa_clid) return true;
  if (String(flat.conversionSource || '').toLowerCase().indexOf('ad') >= 0) return true;
  if (String(flat.entryPointConversionSource || '').toLowerCase().indexOf('ctwa') >= 0) {
    return true;
  }
  return false;
}

function isProtocolNoise(msg, inner) {
  if (!msg || typeof msg !== 'object') return false;
  if (msg.protocolMessage || msg.senderKeyDistributionMessage || msg.reactionMessage) {
    return true;
  }
  const t = String(inner.messageType || inner.type || '').toLowerCase();
  return (
    t === 'protocolmessage' ||
    t === 'senderkeydistributionmessage' ||
    t === 'reactionmessage' ||
    t === 'e2enotification'
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
const isMetaAd = !fromMe && isMetaAdAutomated(msg, inner, raw);
const isNoise = isProtocolNoise(msg, inner);
const phoneRaw = jid.replace(/@.*$/, '').replace(/\D/g, '');
// Prefer real mobile numbers; drop WhatsApp @lid ids (too long / not dialable).
let phone = phoneRaw;
if (phone.length > 15) phone = '';
if (phone.indexOf('91') === 0 && phone.length >= 12) phone = phone.slice(-10);
if (phone.length > 10) phone = phone.slice(-10);
if (phone.length === 10) phone = '91' + phone;
const name = String(inner.pushName || raw.pushName || '').trim();
const voice = hasVoice(msg);
let text = String(pickText(msg) || '').trim();
if (!text && voice) text = '[voice note]';
const optOut = !fromMe && isStopText(text);
let skipReason = '';
if (isGroup) skipReason = 'group';
else if (isStatus) skipReason = 'status';
else if (isMetaAd) skipReason = 'metaAd';
else if (isNoise) skipReason = 'protocol';
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
    jid: jid,
    isMetaAd: isMetaAd
  })
}];

/// Shared helpers for leads_booking.pb.js (loaded via require).

var _b = {}

_b.settingValue = function (id, fallback) {
  try {
    const rec = $app.findRecordById("data", id)
    let data = rec.get("data")
    if (typeof data === "string") {
      try {
        data = JSON.parse(data)
      } catch (e2) {
        data = {}
      }
    }
    data = _b.asObj(data)
    if (data["value"] != null) return data["value"]
    if (data.value != null) return data.value
    return fallback
  } catch (e) {
    return fallback
  }
}

_b.headerToken = function (e) {
  try {
    const info = e.requestInfo()
    const h = info.headers || {}
    const keys = ["x_booking_token", "X-Booking-Token", "x-booking-token"]
    for (let i = 0; i < keys.length; i++) {
      if (h[keys[i]] != null && String(h[keys[i]]).trim() !== "") {
        return String(h[keys[i]]).trim()
      }
    }
  } catch (err) {}
  try {
    const v = e.request.header.get("X-Booking-Token")
    if (v) return String(v).trim()
  } catch (err) {}
  try {
    const v = e.request.header.get("x-booking-token")
    if (v) return String(v).trim()
  } catch (err) {}
  return ""
}

_b.assertToken = function (e) {
  const expected = String(_b.settingValue("n8n_book_token_", "") || "").trim()
  const got = _b.headerToken(e)
  if (!expected) {
    throw new BadRequestError("booking token not configured in PocketBase")
  }
  if (!got || got !== expected) {
    throw new UnauthorizedError("invalid booking token")
  }
}

_b.parseHours = function () {
  const raw = _b.settingValue("clinic_hours___", "")
  const fallbackWeek = {
    open: 600,
    close: 1140,
    breakStart: 840,
    breakEnd: 1020,
  }
  let parsed = null
  try {
    if (raw && typeof raw === "object") parsed = raw
    else if (raw) parsed = JSON.parse(raw)
  } catch (e) {}
  if (!parsed || !parsed.week) {
    parsed = {
      utcOffsetMinutes: 330,
      slotMinutes: 20,
      defaultOperatorId: "",
      closedDates: [],
      week: {
        "1": fallbackWeek,
        "2": fallbackWeek,
        "3": fallbackWeek,
        "4": fallbackWeek,
        "5": fallbackWeek,
        "6": fallbackWeek,
        "7": null,
      },
    }
  }
  return parsed
}

_b.parseEvo = function () {
  const fallback = {
    baseUrl: "",
    apiKey: "",
    instance: "clinic_default",
    clinicName: "the clinic",
    googleMapsUrl: "",
    clinicAddress: "",
    staffGroupJid: "120363426681576301@g.us",
    marketing1: "",
    marketing2: "",
    marketing3: "",
    marketing4: "",
    confirmTemplate:
      "Hi {name}, your appointment at {clinic} is on {date} at {time}. Reply if you need to reschedule.",
    remindTemplate:
      "Reminder: {name}, you have an appointment at {clinic} on {date} at {time}.",
  }
  try {
    const raw = _b.settingValue("evo_settings___", "")
    let parsed = {}
    if (raw && typeof raw === "object") parsed = raw
    else if (raw) parsed = JSON.parse(raw)
    return Object.assign({}, fallback, parsed)
  } catch (e) {
    return fallback
  }
}

_b.clinicInstance = function () {
  return _b.parseEvo().instance || "clinic_default"
}

_b.marketingInstances = function () {
  const e = _b.parseEvo()
  const seen = {}
  const list = []
  const add = function (s) {
    s = String(s || "").trim()
    if (!s || seen[s]) return
    seen[s] = true
    list.push(s)
  }
  add(_b.clinicInstance())
  add(e.marketing1)
  add(e.marketing2)
  add(e.marketing3)
  add(e.marketing4)
  return list.length ? list : ["clinic_default"]
}

_b.pickMarketingInstance = function (seed) {
  const list = _b.marketingInstances()
  let n = 0
  const s = String(seed || "")
  for (let i = 0; i < s.length; i++) n += s.charCodeAt(i)
  return list[n % list.length]
}

_b.nextMarketingInstance = function () {
  const list = _b.marketingInstances()
  const id = "wa_mkt_rr______"
  let n = 0
  try {
    const rec = $app.findRecordById("data", id)
    const data = _b.asObj(rec.get("data"))
    n = Number(data.n) || 0
  } catch (e) {}
  const inst = list[n % list.length]
  _b.upsertData(id, "settings", { id: id, n: n + 1 })
  return inst
}

_b.clinicLocalParts = function (ms, offsetMin) {
  const d = new Date(ms + offsetMin * 60000)
  return {
    year: d.getUTCFullYear(),
    month: d.getUTCMonth() + 1,
    day: d.getUTCDate(),
    weekday: d.getUTCDay() === 0 ? 7 : d.getUTCDay(),
  }
}

_b.clinicLocalToUtcMs = function (year, month, day, minutes, offsetMin) {
  const midnightUtc = Date.UTC(year, month - 1, day) - offsetMin * 60000
  return midnightUtc + minutes * 60000
}

_b.pad2 = function (n) {
  n = String(n)
  return n.length < 2 ? "0" + n : n
}

_b.ymd = function (year, month, day) {
  return year + "-" + _b.pad2(month) + "-" + _b.pad2(day)
}

_b.asObj = function (v) {
  if (!v) return {}
  // PocketBase sometimes returns JSON column values as raw byte arrays.
  if (typeof v === "object" && v.length != null && typeof v.length === "number") {
    try {
      if (v.length > 0 && typeof v[0] === "number") {
        let s = ""
        for (let i = 0; i < v.length; i++) s += String.fromCharCode(v[i])
        v = s
      }
    } catch (e) {}
  }
  if (typeof v === "string") {
    try {
      return JSON.parse(v) || {}
    } catch (e) {
      return {}
    }
  }
  try {
    return JSON.parse(JSON.stringify(v)) || {}
  } catch (e) {
    const out = {}
    try {
      for (const k in v) out[k] = v[k]
    } catch (e2) {}
    return out
  }
}

_b.listStore = function (store) {
  const recs = $app.findRecordsByFilter(
    "data",
    'store = "' + store + '"',
    "-id",
    5000,
    0,
  )
  const out = []
  for (let i = 0; i < recs.length; i++) {
    const rec = recs[i]
    if (!rec) continue
    const data = _b.asObj(rec.get("data"))
    data.id = rec.id
    out.push(data)
  }
  return out
}

_b.aptStartMs = function (a) {
  return (a.date || 0) * 60000
}

_b.aptEndMs = function (a) {
  return _b.aptStartMs(a) + (a.duration || 20) * 60000
}

_b.overlaps = function (a0, a1, b0, b1) {
  return a0 < b1 && b0 < a1
}

_b.operatorOf = function (a) {
  const ids = a.operatorsIDs || []
  return ids.length ? ids[0] : ""
}

_b.isFree = function (start, end, operatorId, busy) {
  for (let i = 0; i < busy.length; i++) {
    const b = busy[i]
    const same = !b.op || !operatorId || b.op === operatorId
    if (!same) continue
    if (_b.overlaps(start, end, b.start, b.end)) return false
  }
  return true
}

_b.busyFromAppointments = function () {
  const busy = []
  const apts = _b.listStore("appointments")
  for (let i = 0; i < apts.length; i++) {
    const a = apts[i]
    if (a.archived === true) continue
    busy.push({ start: _b.aptStartMs(a), end: _b.aptEndMs(a), op: _b.operatorOf(a) })
  }
  return busy
}

_b.WA_TPL = {
  welcome: "wa_welcome_____",
  confirm: "wa_confirm_____",
  remind: "wa_remind______",
  birthday: "wa_birthday____",
  review: "wa_review______",
  alertNew: "wa_alert_new___",
  alertBack: "wa_alert_back__",
  optOut: "wa_optout______",
}

_b.monthAbbr = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
_b.weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

_b.noteBody = function (id) {
  try {
    const raw = _b.settingValue("wa_templates___", "")
    let parsed = {}
    if (raw && typeof raw === "object") parsed = raw
    else if (raw) parsed = JSON.parse(raw)
    const v = parsed[id]
    if (v != null && String(v).trim()) return String(v).trim()
  } catch (e) {}
  try {
    const rec = $app.findRecordById("data", id)
    const data = _b.asObj(rec.get("data"))
    return String(data.note || "").trim()
  } catch (e) {
    return ""
  }
}

_b.clinicFields = function (whenMs) {
  const evo = _b.parseEvo()
  const hours = _b.parseHours()
  const offset = hours.utcOffsetMinutes || 330
  const campaign = _b.parseCampaign()
  let date = ""
  let time = ""
  let day = ""
  if (whenMs) {
    const d = new Date(Number(whenMs) + offset * 60000)
    date = _b.pad2(d.getUTCDate()) + "-" + _b.monthAbbr[d.getUTCMonth()] + "-" + d.getUTCFullYear()
    time = _b.pad2(d.getUTCHours()) + ":" + _b.pad2(d.getUTCMinutes())
    day = _b.weekdays[d.getUTCDay()]
  }
  return {
    name: "",
    clinic: evo.clinicName || "Smile Dental Care",
    phone: String(_b.settingValue("phone__________", "") || ""),
    address: evo.clinicAddress || "",
    maps: evo.googleMapsUrl || "",
    date: date,
    day: day,
    time: time,
    note: "",
    reviewUrl: campaign.googleReviewUrl || "",
  }
}

_b.fillMessage = function (tpl, fields) {
  let s = String(tpl || "")
  const keys = ["name", "clinic", "phone", "address", "maps", "date", "day", "time", "note", "reviewUrl"]
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i]
    let v = fields && fields[k] != null ? String(fields[k]) : ""
    // WhatsApp bold clinic name so branding stands out in every canned message.
    if (k === "clinic" && v && v.indexOf("*") < 0) v = "*" + v + "*"
    // Never inject Maps URLs — WhatsApp shows a Google preview card that
    // replaces the clinic banner. Use a flyer/image send instead.
    if (k === "maps") v = ""
    s = s.split("{" + k + "}").join(v)
  }
  // Avoid mojibake from fancy dashes / bullets on some gateways.
  s = s.replace(/[\u2014\u2013]/g, "-")
  s = s.replace(/[\u2018\u2019]/g, "'")
  s = s.replace(/[\u201c\u201d]/g, '"')
  s = s.replace(/\u2022/g, "-")
  s = s.replace(/\u00a0/g, " ")
  return s.trim()
}

_b.canMessagePatient = function (p) {
  if (!p) return false
  if (p.archived === true) return false
  if (p.whatsappHold === true) return false
  return true
}

_b.fillTemplate = function (tpl, name, clinic, whenMs) {
  const fields = _b.clinicFields(whenMs)
  fields.name = name || ""
  if (clinic) fields.clinic = clinic
  return _b.fillMessage(tpl, fields)
}

_b.templated = function (id, extra) {
  extra = extra || {}
  const fields = _b.clinicFields(extra.whenMs)
  const keys = ["name", "clinic", "phone", "address", "maps", "date", "day", "time", "note", "reviewUrl"]
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i]
    if (extra[k] != null && String(extra[k]) !== "") fields[k] = extra[k]
  }
  const body = _b.noteBody(id)
  if (body) return _b.fillMessage(body, fields)
  return ""
}

_b.withTemplate = function (id, extra, fallbackTpl) {
  const filled = _b.templated(id, extra)
  if (filled) return filled
  extra = extra || {}
  const fields = _b.clinicFields(extra.whenMs)
  const keys = ["name", "clinic", "phone", "address", "maps", "date", "day", "time", "note", "reviewUrl"]
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i]
    if (extra[k] != null && String(extra[k]) !== "") fields[k] = extra[k]
  }
  return _b.fillMessage(fallbackTpl || "", fields)
}

_b.newId = function () {
  const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
  let s = ""
  for (let i = 0; i < 15; i++) s += alphabet[Math.floor(Math.random() * alphabet.length)]
  return s
}

_b.upsertData = function (id, store, data) {
  let rec
  try {
    rec = $app.findRecordById("data", id)
  } catch (e) {
    const col = $app.findCollectionByNameOrId("data")
    rec = new Record(col)
    rec.id = id
  }
  rec.set("store", store)
  rec.set("data", data)
  $app.save(rec)
  return rec
}

_b.getSlots = function (hours, days, duration, operatorId) {
  const now = Date.now()
  const offset = hours.utcOffsetMinutes || 330
  const slotMin = hours.slotMinutes || 15
  const dur = duration || slotMin
  const op = operatorId || hours.defaultOperatorId || ""
  const busy = _b.busyFromAppointments()
  const startLocal = _b.clinicLocalParts(now, offset)
  const slots = []
  for (let d = 0; d < days && slots.length < 12; d++) {
    const dayMs = Date.UTC(startLocal.year, startLocal.month - 1, startLocal.day) + d * 86400000
    const day = new Date(dayMs)
    const y = day.getUTCFullYear()
    const m = day.getUTCMonth() + 1
    const dd = day.getUTCDate()
    const weekday = day.getUTCDay() === 0 ? 7 : day.getUTCDay()
    if ((hours.closedDates || []).indexOf(_b.ymd(y, m, dd)) >= 0) continue
    const dayHours = (hours.week || {})[String(weekday)]
    if (!dayHours) continue
    let cursor = dayHours.open
    while (cursor + dur <= dayHours.close && slots.length < 12) {
      const inBreak =
        dayHours.breakStart != null &&
        dayHours.breakEnd != null &&
        cursor < dayHours.breakEnd &&
        cursor + dur > dayHours.breakStart
      if (inBreak) {
        cursor = dayHours.breakEnd
        continue
      }
      const start = _b.clinicLocalToUtcMs(y, m, dd, cursor, offset)
      const end = start + dur * 60000
      if (start <= now) {
        cursor += slotMin
        continue
      }
      if (_b.isFree(start, end, op, busy)) {
        slots.push({
          id: op + "|" + start,
          start: new Date(start).toISOString(),
          end: new Date(end).toISOString(),
          operatorId: op,
        })
      }
      cursor += slotMin
    }
  }
  return slots
}

_b.digitsPhone = function (raw) {
  return String(raw || "").replace(/\D/g, "")
}

/** Short “I left a review” replies — must not ping the staff leads group. */
_b.isReviewDoneText = function (raw) {
  const t = String(raw || "").toLowerCase().trim()
  if (!t) return false
  if (
    /^(done|reviewed|review done|yes done|ok done|thank you|thanks|ok|okay)[.!]*$/.test(t)
  ) {
    return true
  }
  return (
    t.indexOf("left a review") >= 0 ||
    t.indexOf("gave a review") >= 0 ||
    t.indexOf("posted a review") >= 0 ||
    t.indexOf("submitted a review") >= 0 ||
    t === "i reviewed" ||
    t === "review submitted"
  )
}

_b.phoneTail10 = function (raw) {
  const d = _b.digitsPhone(raw)
  if (d.length >= 10) return d.slice(-10)
  return d
}

_b.persistPhone = function (raw) {
  let d = _b.digitsPhone(raw)
  // Ignore WhatsApp @lid numeric ids (not real phone numbers).
  if (d.length > 15) return ""
  if (d.indexOf("91") === 0 && d.length >= 12) d = d.slice(2, 12)
  if (d.length > 10) d = d.slice(-10)
  if (d.length === 10) return "91" + d
  return d
}

_b.matchPhone = function (stored, want) {
  const a = _b.persistPhone(stored)
  const b = _b.persistPhone(want)
  if (a && b && a === b) return true
  const ta = _b.phoneTail10(stored)
  const tb = _b.phoneTail10(want)
  if (ta.length === 10 && tb.length === 10 && ta === tb) return true
  // Patient phone may be concatenated (multiple numbers) or stored oddly.
  const storedDigits = _b.digitsPhone(stored)
  if (tb.length === 10 && storedDigits.indexOf(tb) >= 0) return true
  if (ta.length === 10 && _b.digitsPhone(want).indexOf(ta) >= 0) return true
  return false
}

_b.queryGet = function (e, key, fallback) {
  try {
    const q = e.requestInfo().query
    if (q && q[key] != null && q[key] !== "") return String(q[key])
  } catch (err) {}
  try {
    return e.request.url.query().get(key) || fallback
  } catch (err) {}
  return fallback
}

_b.parseCampaign = function () {
  const raw = _b.settingValue("wa_campaign____", "")
  let parsed = {}
  try {
    if (raw && typeof raw === "object") parsed = raw
    else if (raw) parsed = JSON.parse(raw)
  } catch (e) {}
  return {
    googleReviewUrl: parsed.googleReviewUrl || "",
    sendFlyerWithChat: parsed.sendFlyerWithChat !== false,
    flyerFile: parsed.flyerFile || "",
    openrouterModel: parsed.openrouterModel || "openai/gpt-4o-mini",
    birthdayTemplate:
      parsed.birthdayTemplate ||
      "Happy birthday {name}! The team at {clinic} wishes you a wonderful year.",
    reviewTemplate:
      parsed.reviewTemplate ||
      "Hi {name}, thank you for visiting {clinic}. Please leave a Google review: {reviewUrl}",
    marketingImageUrl: parsed.marketingImageUrl || "",
    treatments: parsed.treatments ||
      "cleaning, filling, root canal, extraction, braces, aligners, implant, crown, denture, gum treatment, kids dentistry, whitening, x-ray",
    quietStart: parsed.quietStart == null ? 1260 : Number(parsed.quietStart),
    quietEnd: parsed.quietEnd == null ? 540 : Number(parsed.quietEnd),
  }
}

_b.flyerInfo = function () {
  const campaign = _b.parseCampaign()
  let file = campaign.flyerFile
  try {
    const rec = $app.findRecordById("data", "wa_flyer_______")
    const imgs = rec.get("imgs") || []
    if (imgs && imgs.length) file = imgs[0]
  } catch (e) {}
  if (!file) return { file: "", url: "" }
  return {
    file: file,
    url: "/api/files/data/wa_flyer_______/" + file,
  }
}

_b.AI_COOLDOWN_MS = 3 * 60 * 1000
_b.STAFF_PAUSE_MS = 4 * 3600 * 1000

_b.isQuietHours = function () {
  const campaign = _b.parseCampaign()
  const start = Number(campaign.quietStart)
  const end = Number(campaign.quietEnd)
  if (!Number.isFinite(start) || !Number.isFinite(end)) return false
  if (start === end) return false
  const hours = _b.parseHours()
  const offset = hours.utcOffsetMinutes || 330
  const d = new Date(Date.now() + offset * 60000)
  const mins = d.getUTCHours() * 60 + d.getUTCMinutes()
  if (start > end) return mins >= start || mins < end
  return mins >= start && mins < end
}

_b.shouldReply = function (lead) {
  if (lead && lead.whatsappConsent === false) return false
  if (lead && lead.assistantPaused === true) {
    const last = Number(lead.lastHumanAt) || 0
    if (!last || Date.now() - last < _b.STAFF_PAUSE_MS) return false
  }
  if (_b.isQuietHours()) return false
  if (!lead || !lead.lastAssistantAt) return true
  const last = Number(lead.lastAssistantAt) || 0
  if (!last) return true
  return Date.now() - last >= _b.AI_COOLDOWN_MS
}

_b.groupAlertText = function (isReturning, phone, name, note) {
  const who = name ? name : "—"
  const line = String(note || "").replace(/\s+/g, " ").slice(0, 280)
  const extra = { phone: phone, name: who, note: line }
  const fallback =
    (isReturning ? "🔁 Returning patient\n" : "🆕 New WhatsApp lead\n") +
    "Phone: {phone}\nName: {name}\nNote: {note}\nPlease call from the clinic number. Do not reply in this group."
  return _b.withTemplate(
    isReturning ? _b.WA_TPL.alertBack : _b.WA_TPL.alertNew,
    extra,
    fallback,
  )
}

_b.rescheduleGroupText = function (phone, name, note) {
  const who = name ? name : "—"
  const preference = String(note || "").replace(/\s+/g, " ").trim().slice(0, 400)
  let text =
    "Want to reschedule\n\n" +
    "Name: " + who + "\n" +
    "Phone: " + (phone || "—") + "\n"
  if (preference) {
    text += "Preferred time: " + preference + "\n"
  } else {
    text += "Note: Patient asked to reschedule — assistant is asking for their preferred day/time.\n"
  }
  text += "Please call from the clinic number. Do not reply in this group."
  return text
}

_b.dueMarketing = function () {
  if (_b.isQuietHours()) return []
  const campaign = _b.parseCampaign()
  const defaultUrl = campaign.marketingImageUrl || ""
  const max = _b.marketingInstances().length
  const out = []
  const leads = _b.listStore("leads")
  for (let i = 0; i < leads.length; i++) {
    const l = leads[i]
    if (l.archived === true) continue
    if (l.marketingQueued !== true || l.marketingSent === true) continue
    if (l.whatsappConsent === false) continue
    if (!l.phone) continue
    const imageUrl = l.marketingImageUrl || defaultUrl
    const caption = l.marketingCaption || l.campaign || ""
    if (!imageUrl && !caption) continue
    out.push({
      id: l.id,
      name: l.title || "",
      phone: l.phone,
      imageUrl: imageUrl,
      caption: caption,
      evoInstance: _b.nextMarketingInstance(),
    })
    if (out.length >= max) break
  }
  return out
}

_b.findPatientByPhone = function (phone) {
  const patients = _b.listStore("patients")
  for (let i = 0; i < patients.length; i++) {
    if (patients[i].archived === true) continue
    if (_b.matchPhone(patients[i].phone, phone)) return patients[i]
  }
  return null
}

_b.findLeadByPhone = function (phone) {
  const leads = _b.listStore("leads")
  for (let i = 0; i < leads.length; i++) {
    if (leads[i].archived === true) continue
    if (_b.matchPhone(leads[i].phone, phone)) return leads[i]
  }
  return null
}

_b.clinicLocalNow = function () {
  const hours = _b.parseHours()
  const offset = hours.utcOffsetMinutes || 330
  const d = new Date(Date.now() + offset * 60000)
  return {
    year: d.getUTCFullYear(),
    month: d.getUTCMonth() + 1,
    day: d.getUTCDate(),
  }
}

_b.daysUntilBirthday = function (birth, nowP) {
  const n = Number(birth)
  if (!n || n < 10000) return null
  const month = Math.floor((n % 10000) / 100)
  const day = n % 100
  if (month < 1 || day < 1) return null
  const y = nowP.year
  const m = nowP.month
  const d = nowP.day
  let next = Date.UTC(y, month - 1, day)
  const today = Date.UTC(y, m - 1, d)
  if (today > next) next = Date.UTC(y + 1, month - 1, day)
  return Math.round((next - today) / 86400000)
}

_b.aiContext = function (phone) {
  const hours = _b.parseHours()
  const campaign = _b.parseCampaign()
  const flyer = _b.flyerInfo()
  const evo = _b.parseEvo()
  const lead = _b.findLeadByPhone(phone)
  const patient = _b.findPatientByPhone(phone)
  const slots = _b.getSlots(hours, 7, hours.slotMinutes, hours.defaultOperatorId || "")
  const upcoming = []
  if (patient) {
    const apts = _b.listStore("appointments")
    const now = Date.now()
    for (let i = 0; i < apts.length; i++) {
      const a = apts[i]
      if (a.archived === true || a.patientID !== patient.id) continue
      const start = _b.aptStartMs(a)
      if (start <= now) continue
      upcoming.push({
        id: a.id,
        start: new Date(start).toISOString(),
        duration: a.duration || 20,
        rescheduleRequested: a.rescheduleRequested === true,
      })
    }
  }
  return {
    staffConfirmOnly: true,
    lead: lead,
    patient: patient
      ? {
          id: patient.id,
          title: patient.title,
          phone: patient.phone,
          birthdayMsgYear: patient.birthdayMsgYear || 0,
          reviewDone: patient.reviewDone === true,
          reviewAskCount: patient.reviewAskCount || 0,
        }
      : null,
    slots: slots,
    upcomingAppointments: upcoming,
    campaign: campaign,
    flyer: flyer,
    clinicName: evo.clinicName || "the clinic",
    googleMapsUrl: evo.googleMapsUrl || "",
    evolution: { instance: evo.instance, googleMapsUrl: evo.googleMapsUrl || "" },
    shouldReply: _b.shouldReply(lead),
    instruction:
      "Never create a calendar booking. Never mention prices, fees, packages, discounts, or cost. Only a doctor may discuss fees in person or on a call. If they ask the price, say the doctor will explain on the call. If patient is set, this is an existing clinic patient — use their name and do not treat them as new. If they are interested or say yes, thank them and say staff will call. If they send a voice note, ask them to type the concern or say staff will call. Treatments you may name (no prices): " +
      (campaign.treatments || "") +
      ". If they want to reschedule, ask their preferred day/time then staff will confirm. If they left a Google review, thank them.",
  }
}

_b.applyAiEvent = function (body) {
  const phone = _b.persistPhone(body.phone)
  const type = String(body.type || "")
  if (type === "interested") {
    let lead = _b.findLeadByPhone(phone)
    const id = lead ? lead.id : _b.newId()
    const data = Object.assign({}, lead || {}, {
      id: id,
      title: body.name || (lead && lead.title) || "",
      phone: phone || (lead && lead.phone) || "",
      source: (lead && lead.source) || "whatsapp",
      stage: "interested",
    })
    _b.upsertData(id, "leads", data)
    return { ok: true, lead: data }
  }
  if (type === "profile") {
    const p = _b.findLeadByPhone(phone)
    if (!p) throw new BadRequestError("lead not found")
    if (body.name) p.title = body.name
    if (body.interest) p.interest = body.interest
    _b.upsertData(p.id, "leads", p)
    return { ok: true, lead: p }
  }
  if (type === "assistant_replied") {
    let lead = _b.findLeadByPhone(phone)
    if (!lead) throw new BadRequestError("lead not found")
    lead.lastAssistantAt = Date.now()
    _b.upsertData(lead.id, "leads", lead)
    return { ok: true }
  }
  if (type === "opt_out") {
    let lead = _b.findLeadByPhone(phone)
    if (!lead) throw new BadRequestError("lead not found")
    lead.whatsappConsent = false
    lead.assistantPaused = true
    lead.marketingQueued = false
    _b.upsertData(lead.id, "leads", lead)
    return { ok: true }
  }
  if (type === "pause") {
    let lead = _b.findLeadByPhone(phone)
    if (!lead) {
      const id = _b.newId()
      lead = { id: id, phone: phone, title: body.name || "", source: "whatsapp", assistantPaused: true, lastHumanAt: Date.now(), stage: "contacted" }
      _b.upsertData(id, "leads", lead)
      return { ok: true }
    }
    lead.assistantPaused = true
    lead.lastHumanAt = Date.now()
    _b.upsertData(lead.id, "leads", lead)
    return { ok: true }
  }
  if (type === "resume") {
    let lead = _b.findLeadByPhone(phone)
    if (!lead) throw new BadRequestError("lead not found")
    lead.assistantPaused = false
    _b.upsertData(lead.id, "leads", lead)
    return { ok: true }
  }
  if (type === "send_failed") {
    let lead = _b.findLeadByPhone(phone)
    if (!lead) throw new BadRequestError("lead not found")
    lead.sendError = String(body.error || "WhatsApp send failed")
    _b.upsertData(lead.id, "leads", lead)
    return { ok: true }
  }
  if (type === "marketing_sent") {
    const id = body.leadId
    if (!id) throw new BadRequestError("leadId required")
    const rec = $app.findRecordById("data", id)
    const data = _b.asObj(rec.get("data"))
    data.marketingSent = true
    data.marketingQueued = false
    data.id = rec.id
    rec.set("data", data)
    $app.save(rec)
    return { ok: true }
  }
  if (type === "birthday_sent") {
    const p = _b.findPatientByPhone(phone)
    if (!p) throw new BadRequestError("patient not found")
    p.birthdayMsgYear = _b.clinicLocalNow().year
    _b.upsertData(p.id, "patients", p)
    return { ok: true }
  }
  if (type === "review_asked") {
    const p = _b.findPatientByPhone(phone)
    if (!p) throw new BadRequestError("patient not found")
    p.reviewAskCount = (p.reviewAskCount || 0) + 1
    p.reviewAskLast = Math.round(Date.now() / 60000)
    _b.upsertData(p.id, "patients", p)
    return { ok: true, reviewAskCount: p.reviewAskCount }
  }
  if (type === "review_done") {
    const p = _b.findPatientByPhone(phone)
    if (!p) throw new BadRequestError("patient not found")
    p.reviewDone = true
    _b.upsertData(p.id, "patients", p)
    return { ok: true }
  }
  if (type === "reschedule") {
    let id = body.appointmentId
    const patient = _b.findPatientByPhone(phone)
    const note = String(
      body.note || body.preferredTime || body.interest || "",
    ).trim()
    if (!id) {
      if (!patient) throw new BadRequestError("appointmentId required")
      const apts = _b.listStore("appointments")
      const now = Date.now()
      let soonest = null
      let soonestMs = 0
      for (let i = 0; i < apts.length; i++) {
        const a = apts[i]
        if (a.archived === true || a.patientID !== patient.id) continue
        if (a.isDone === true || a.isNoShow === true) continue
        const start = _b.aptStartMs(a)
        if (start <= now) continue
        if (!soonest || start < soonestMs) {
          soonest = a
          soonestMs = start
        }
      }
      if (!soonest) throw new BadRequestError("no upcoming appointment")
      id = soonest.id
    }
    const rec = $app.findRecordById("data", id)
    const data = _b.asObj(rec.get("data"))
    data.rescheduleRequested = true
    if (note) data.rescheduleNote = note
    data.id = rec.id
    rec.set("data", data)
    $app.save(rec)

    let lead = _b.findLeadByPhone(phone)
    const leadId = lead ? lead.id : _b.newId()
    const leadData = Object.assign({}, lead || {}, {
      id: leadId,
      phone: phone || (lead && lead.phone) || "",
      title:
        (patient && patient.title) ||
        body.name ||
        (lead && lead.title) ||
        "",
      source: (lead && lead.source) || "whatsapp",
      stage: "reschedule",
      rescheduleNote: note || (lead && lead.rescheduleNote) || "",
      patientID: (patient && patient.id) || (lead && lead.patientID) || "",
    })
    _b.upsertData(leadId, "leads", leadData)

    const evo = _b.parseEvo()
    const who = leadData.title || "—"
    return {
      ok: true,
      appointmentId: id,
      notifyGroup: true,
      staffGroupJid: evo.staffGroupJid || "120363426681576301@g.us",
      groupText: _b.rescheduleGroupText(phone, who, note),
    }
  }
  throw new BadRequestError("unknown event type")
}

_b.dueBirthdays = function (withinDays) {
  if (_b.isQuietHours()) return []
  const nowP = _b.clinicLocalNow()
  const year = nowP.year
  const out = []
  const patients = _b.listStore("patients")
  for (let i = 0; i < patients.length; i++) {
    const p = patients[i]
    if (p.archived === true) continue
    if (!_b.canMessagePatient(p)) continue
    if (!p.phone) continue
    const days = _b.daysUntilBirthday(p.birth, nowP)
    if (days == null || days > withinDays) continue
    if (p.birthdayMsgYear === year) continue
    out.push({
      id: p.id,
      name: p.title || "",
      phone: p.phone,
      days: days,
    })
  }
  return out
}

_b.dueReviews = function () {
  // Reviews are sent only from ChatDENT patient details (Send review request).
  // n8n no longer auto-queues from appointment "done".
  return []
}

module.exports = _b

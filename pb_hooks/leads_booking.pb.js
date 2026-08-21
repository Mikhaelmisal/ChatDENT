/// n8n booking API routes for ChatDENT leads.
/// Helpers: require(`${__hooks}/leads_booking_lib.js`)

routerAdd("GET", "/api/leads/slots", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  try {
    b.assertToken(e)
    const days = parseInt(b.queryGet(e, "days", "7"), 10)
    const duration = parseInt(b.queryGet(e, "duration", "0"), 10)
    const operatorId = b.queryGet(e, "operatorId", "") || ""
    const hours = b.parseHours()
    return e.json(200, {
      slots: b.getSlots(hours, days || 7, duration || hours.slotMinutes, operatorId),
    })
  } catch (err) {
    const msg = err && err.message ? String(err.message) : String(err)
    const lower = msg.toLowerCase()
    if (lower.indexOf("invalid booking token") >= 0) throw err
    if (lower.indexOf("booking token not configured") >= 0) throw err
    throw new BadRequestError(msg)
  }
})

routerAdd("POST", "/api/leads/upsert", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const body = e.requestInfo().body || {}
  const phone = b.persistPhone(body.phone)
  if (!phone && !body.name) {
    throw new BadRequestError("name or phone required")
  }
  let lead = null
  const leads = b.listStore("leads")
  for (let i = 0; i < leads.length; i++) {
    const l = leads[i]
    if (l.archived === true) continue
    if (phone && String(l.phone || "") === phone) {
      lead = l
      break
    }
  }
  const id = lead ? lead.id : b.newId()
  const isNewLead = !lead
  const keepStage = lead && (lead.stage === "converted" || lead.stage === "scheduled" || lead.stage === "interested")
  const prevNotes = (lead && lead.notes) || ""
  const incoming = String(body.notes || "").trim()
  let notes = prevNotes
  if (incoming && prevNotes.indexOf(incoming) < 0) {
    notes = (prevNotes ? prevNotes + "\n" : "") + incoming
    if (notes.length > 2500) notes = notes.slice(-2500)
  }
  const data = Object.assign({}, lead || {}, {
    id: id,
    title: (lead && lead.title) || body.name || "",
    phone: phone || (lead && lead.phone) || "",
    email: body.email != null ? body.email : (lead && lead.email) || "",
    source: body.source || (lead && lead.source) || "manual",
    campaign: body.campaign || (lead && lead.campaign) || "",
    interest: body.interest || (lead && lead.interest) || "",
    notes: notes,
    stage: keepStage ? lead.stage : (body.stage || (lead && lead.stage) || "new"),
    whatsappConsent: body.optOut === true ? false : ((lead && lead.whatsappConsent === false) ? false : true),
    assistantPaused: body.optOut === true ? true : (lead && lead.assistantPaused) || false,
  })
  b.upsertData(id, "leads", data)
  const patient = b.findPatientByPhone(phone)
  const isReturningPatient = !!patient
  const notifyGroup = data.groupAlertSent !== true
  if (notifyGroup) {
    data.groupAlertSent = true
    b.upsertData(id, "leads", data)
  }
  const evo = b.parseEvo()
  const name = data.title || body.name || ""
  return e.json(200, {
    lead: data,
    isNewLead: isNewLead,
    isReturningPatient: isReturningPatient,
    optOut: body.optOut === true,
    shouldReply: b.shouldReply(data) && body.optOut !== true,
    notifyGroup: notifyGroup && body.optOut !== true,
    staffGroupJid: evo.staffGroupJid || "120363426681576301@g.us",
    groupText: b.groupAlertText(
      isReturningPatient,
      data.phone,
      name,
      incoming || data.notes || "",
    ),
    welcomeText: b.withTemplate(b.WA_TPL.welcome, { name: name },
      "Namaste {name},\n\nWelcome to {clinic}. Please reply with your full name and dental concern. A doctor or receptionist will call you to confirm.\n\n{phone}\n{address}\n{maps}"),
    optOutText: b.withTemplate(b.WA_TPL.optOut, { name: name },
      "Namaste {name},\n\nYou have been unsubscribed from {clinic} WhatsApp messages. For appointments call {phone}."),
  })
})

routerAdd("POST", "/api/leads/book", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const body = e.requestInfo().body || {}
  const slotId = String(body.slotId || "")
  const bar = slotId.indexOf("|")
  if (bar < 0) throw new BadRequestError("slotId required")
  const operatorId = slotId.slice(0, bar)
  const start = parseInt(slotId.slice(bar + 1), 10)
  if (!start) throw new BadRequestError("invalid slotId")
  const hours = b.parseHours()
  const duration = parseInt(body.duration || hours.slotMinutes, 10)
  const end = start + duration * 60000
  if (!b.isFree(start, end, operatorId, b.busyFromAppointments())) {
    throw new BadRequestError("slotTaken")
  }
  const phone = b.persistPhone(body.phone)
  let lead = null
  const leads = b.listStore("leads")
  for (let i = 0; i < leads.length; i++) {
    const l = leads[i]
    if (phone && String(l.phone || "") === phone) {
      lead = l
      break
    }
  }
  let patient = null
  if (lead && lead.patientID) {
    try {
      const rec = $app.findRecordById("data", lead.patientID)
      patient = rec.get("data") || {}
      patient.id = rec.id
    } catch (err) {}
  }
  if (!patient && phone) {
    const patients = b.listStore("patients")
    for (let i = 0; i < patients.length; i++) {
      const p = patients[i]
      if (String(p.phone || "") === phone) {
        patient = p
        break
      }
    }
  }
  if (!patient) {
    const pid = b.newId()
    patient = {
      id: pid,
      title: body.name || (lead && lead.title) || "Lead",
      phone: phone,
      email: body.email || "",
      notes: body.notes || "",
    }
    b.upsertData(pid, "patients", patient)
  }
  const aid = b.newId()
  const appointment = {
    id: aid,
    patientID: patient.id,
    date: Math.round(start / 60000),
    duration: duration,
    operatorsIDs: operatorId ? [operatorId] : [],
    preOpNotes: body.interest || "Booked from lead",
    reminder24Sent: false,
    reminder2Sent: false,
  }
  b.upsertData(aid, "appointments", appointment)

  const lid = lead ? lead.id : b.newId()
  const leadData = Object.assign({}, lead || {}, {
    id: lid,
    title: body.name || (lead && lead.title) || patient.title,
    phone: phone || (lead && lead.phone) || "",
    email: body.email || (lead && lead.email) || "",
    source: body.source || (lead && lead.source) || "manual",
    patientID: patient.id,
    appointmentID: aid,
    stage: "scheduled",
  })
  b.upsertData(lid, "leads", leadData)

  const evo = b.parseEvo()
  const text = b.withTemplate(
    b.WA_TPL.confirm,
    { name: leadData.title, whenMs: start },
    evo.confirmTemplate,
  )
  const wa = "https://wa.me/" + b.digitsPhone(leadData.phone) + "?text=" + encodeURIComponent(text)
  return e.json(200, {
    appointment: appointment,
    patient: patient,
    lead: leadData,
    whatsappText: text,
    whatsappUrl: wa,
    evolution: { baseUrl: evo.baseUrl, instance: evo.instance },
  })
})

routerAdd("GET", "/api/leads/reminders", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const hoursAhead = parseInt(b.queryGet(e, "hours", "24"), 10)
  const now = Date.now()
  const until = now + hoursAhead * 3600000
  const kind = hoursAhead <= 3 ? "2" : "24"
  const evo = b.parseEvo()
  const patientsById = {}
  const patients = b.listStore("patients")
  for (let i = 0; i < patients.length; i++) patientsById[patients[i].id] = patients[i]
  const out = []
  const apts = b.listStore("appointments")
  for (let ai = 0; ai < apts.length; ai++) {
    const a = apts[ai]
    if (a.archived === true || a.isDone === true) continue
    if (a.rescheduleRequested === true) continue
    const start = b.aptStartMs(a)
    if (start <= now || start > until) continue
    if (kind === "24" && a.reminder24Sent) continue
    if (kind === "2" && a.reminder2Sent) continue
    const p = patientsById[a.patientID] || {}
    if (!b.canMessagePatient(p)) continue
    const name = p.title || ""
    const text = b.withTemplate(
      b.WA_TPL.remind,
      { name: name, whenMs: start },
      evo.remindTemplate + " Reply RESCHEDULE if you need a different time and staff will call you.",
    )
    out.push({
      appointmentId: a.id,
      patientId: a.patientID,
      phone: p.phone || "",
      name: name,
      start: new Date(start).toISOString(),
      kind: kind,
      whatsappText: text,
      whatsappUrl: "https://wa.me/" + b.digitsPhone(p.phone) + "?text=" + encodeURIComponent(text),
    })
  }
  return e.json(200, { reminders: out, evolution: { baseUrl: evo.baseUrl, instance: evo.instance } })
})

routerAdd("POST", "/api/leads/mark-reminder", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const body = e.requestInfo().body || {}
  const id = body.appointmentId
  if (!id) throw new BadRequestError("appointmentId required")
  const rec = $app.findRecordById("data", id)
  const data = b.asObj(rec.get("data"))
  if (body.kind === "2") data.reminder2Sent = true
  else data.reminder24Sent = true
  data.id = rec.id
  rec.set("data", data)
  $app.save(rec)
  return e.json(200, { ok: true })
})

routerAdd("GET", "/api/leads/ai-context", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const phone = b.persistPhone(b.queryGet(e, "phone", ""))
  if (!phone) throw new BadRequestError("phone required")
  return e.json(200, b.aiContext(phone))
})

routerAdd("POST", "/api/leads/ai-event", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const body = e.requestInfo().body || {}
  return e.json(200, b.applyAiEvent(body))
})

routerAdd("GET", "/api/leads/due-birthdays", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const days = parseInt(b.queryGet(e, "days", "0"), 10)
  const campaign = b.parseCampaign()
  const evo = b.parseEvo()
  const people = b.dueBirthdays(Number.isFinite(days) ? days : 0)
  const filled = []
  for (let i = 0; i < people.length; i++) {
    const p = people[i]
    filled.push(Object.assign({}, p, {
      whatsappText: b.withTemplate(
        b.WA_TPL.birthday,
        { name: p.name },
        campaign.birthdayTemplate,
      ),
    }))
  }
  return e.json(200, {
    people: filled,
    template: campaign.birthdayTemplate,
    clinicName: evo.clinicName,
    evolution: { baseUrl: evo.baseUrl, instance: evo.instance },
  })
})

routerAdd("GET", "/api/leads/due-reviews", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const campaign = b.parseCampaign()
  const evo = b.parseEvo()
  const people = b.dueReviews()
  const filled = []
  for (let i = 0; i < people.length; i++) {
    const p = people[i]
    filled.push(Object.assign({}, p, {
      whatsappText: b.withTemplate(
        b.WA_TPL.review,
        { name: p.name, reviewUrl: campaign.googleReviewUrl },
        campaign.reviewTemplate,
      ),
    }))
  }
  return e.json(200, {
    people: filled,
    template: campaign.reviewTemplate,
    googleReviewUrl: campaign.googleReviewUrl,
    clinicName: evo.clinicName,
    evolution: { baseUrl: evo.baseUrl, instance: evo.instance },
  })
})

routerAdd("GET", "/api/leads/due-marketing", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const evo = b.parseEvo()
  return e.json(200, {
    people: b.dueMarketing(),
    evolution: {
      baseUrl: evo.baseUrl || "http://evolution-api:8080",
      instance: evo.instance || "clinic_default",
    },
  })
})

routerAdd("GET", "/api/leads/config", (e) => {
  const b = require(`${__hooks}/leads_booking_lib.js`)
  b.assertToken(e)
  const evo = b.parseEvo()
  return e.json(200, {
    hours: b.parseHours(),
    evolution: evo,
    campaign: b.parseCampaign(),
    flyer: b.flyerInfo(),
  })
})


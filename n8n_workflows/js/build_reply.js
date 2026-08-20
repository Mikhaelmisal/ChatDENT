const prev = $input.first().json;
const slotsRes = $('Get slots').first().json || {};
const slots = slotsRes.slots || [];
const leadRes = $('Upsert lead').first().json || {};
const lead = leadRes.lead || {};

function fmt(iso) {
  const d = new Date(iso);
  const ist = new Date(d.getTime() + 330 * 60000);
  const dd = String(ist.getUTCDate()).padStart(2, '0');
  const mm = String(ist.getUTCMonth() + 1).padStart(2, '0');
  const hh = String(ist.getUTCHours()).padStart(2, '0');
  const mi = String(ist.getUTCMinutes()).padStart(2, '0');
  return dd + '/' + mm + ' ' + hh + ':' + mi + ' IST';
}

if (prev.wantsBook) {
  const slot = slots[prev.slotIndex];
  if (!slot || !slot.id) {
    return [{
      json: Object.assign({}, prev, {
        shouldBook: false,
        reply: 'That number is not available. Reply with any message to see open times again.',
        number: prev.phone
      })
    }];
  }
  return [{
    json: Object.assign({}, prev, {
      shouldBook: true,
      slotId: slot.id,
      number: prev.phone,
      bookBody: {
        slotId: slot.id,
        name: prev.name || lead.title || 'WhatsApp',
        phone: prev.phone,
        source: 'whatsapp',
        notes: prev.text
      }
    })
  }];
}

if (!slots.length) {
  return [{
    json: Object.assign({}, prev, {
      shouldBook: false,
      number: prev.phone,
      reply: 'Hello' + (prev.name ? ' ' + prev.name : '') + ', we have no open slots in the next 7 days. Please message us again later.'
    })
  }];
}

const lines = slots.map(function (s, i) { return (i + 1) + '. ' + fmt(s.start); });
return [{
  json: Object.assign({}, prev, {
    shouldBook: false,
    number: prev.phone,
    reply: 'Hello' + (prev.name ? ' ' + prev.name : '') + '! Available times:\n' + lines.join('\n') + '\n\nReply with the number (1-' + slots.length + ') to book.'
  })
}];

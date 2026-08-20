const p = $input.first().json || {};
return [{
  json: Object.assign({}, p, {
    number: p.staffGroupJid || '120363426681576301@g.us',
    reply: p.groupText || ''
  })
}];

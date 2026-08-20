const p = $input.first().json || {};
return [{
  json: Object.assign({}, p, {
    number: p.phone,
    reply: p.optOutText || ''
  })
}];

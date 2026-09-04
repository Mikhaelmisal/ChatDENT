import json
from pathlib import Path

root = Path(__file__).resolve().parent
js = root / "js"
BOOKING_TOKEN = "={{ $env.N8N_BOOKING_TOKEN }}"
PB = "http://pocketbase:8090"
EVO_KEY = "={{ $json.evoKey || $env.EVOLUTION_API_KEY }}"


def code_node(name, nid, x, y, filename):
    return {
        "parameters": {"jsCode": (js / filename).read_text(encoding="utf-8")},
        "id": nid,
        "name": name,
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [x, y],
    }


def http_get(name, nid, x, y, url):
    return {
        "parameters": {
            "method": "GET",
            "url": url,
            "sendHeaders": True,
            "headerParameters": {
                "parameters": [{"name": "X-Booking-Token", "value": BOOKING_TOKEN}]
            },
            "options": {},
        },
        "id": nid,
        "name": name,
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [x, y],
    }


def http_post_json(name, nid, x, y, url, json_body_expr):
    return {
        "parameters": {
            "method": "POST",
            "url": url,
            "sendHeaders": True,
            "headerParameters": {
                "parameters": [
                    {"name": "X-Booking-Token", "value": BOOKING_TOKEN},
                    {"name": "Content-Type", "value": "application/json"},
                ]
            },
            "sendBody": True,
            "specifyBody": "json",
            "jsonBody": json_body_expr,
            "options": {},
        },
        "id": nid,
        "name": name,
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [x, y],
    }


def http_evo_send(name, nid, x, y):
    return {
        "parameters": {
            "method": "POST",
            "url": "={{ ($json.evoBase || 'http://evolution-api:8080') + '/message/sendText/' + ($json.evoInstance || 'clinic_default') }}",
            "sendHeaders": True,
            "headerParameters": {
                "parameters": [
                    {
                        "name": "apikey",
                        "value": EVO_KEY,
                    },
                    {"name": "Content-Type", "value": "application/json"},
                ]
            },
            "sendBody": True,
            "specifyBody": "json",
            "jsonBody": "={{ JSON.stringify({ number: $json.number, text: $json.reply }) }}",
            "options": {},
        },
        "id": nid,
        "name": name,
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [x, y],
    }


def http_evo_media(name, nid, x, y):
    return {
        "parameters": {
            "method": "POST",
            "url": "={{ ($json.evoBase || 'http://evolution-api:8080') + '/message/sendMedia/' + ($json.evoInstance || 'clinic_default') }}",
            "sendHeaders": True,
            "headerParameters": {
                "parameters": [
                    {
                        "name": "apikey",
                        "value": EVO_KEY,
                    },
                    {"name": "Content-Type", "value": "application/json"},
                ]
            },
            "sendBody": True,
            "specifyBody": "json",
            "jsonBody": "={{ JSON.stringify({ number: $json.number, mediatype: 'image', mimetype: 'image/jpeg', caption: $json.mediaCaption || '', media: $json.flyerUrl }) }}",
            "options": {},
        },
        "id": nid,
        "name": name,
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [x, y],
    }


def http_openrouter(name, nid, x, y):
    return {
        "parameters": {
            "method": "POST",
            "url": "https://openrouter.ai/api/v1/chat/completions",
            "sendHeaders": True,
            "headerParameters": {
                "parameters": [
                    {
                        "name": "Authorization",
                        "value": "=Bearer {{ $env.OPENROUTER_API_KEY }}",
                    },
                    {"name": "Content-Type", "value": "application/json"},
                    {"name": "HTTP-Referer", "value": "http://localhost:5678"},
                    {"name": "X-Title", "value": "ChatDENT"},
                ]
            },
            "sendBody": True,
            "specifyBody": "json",
            "jsonBody": "={{ JSON.stringify($json.openRouterBody) }}",
            "options": {},
        },
        "id": nid,
        "name": name,
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [x, y],
    }


def wait_seconds(name, nid, x, y, seconds):
    return {
        "parameters": {
            "resume": "timeInterval",
            "amount": seconds,
            "unit": "seconds",
        },
        "id": nid,
        "name": name,
        "type": "n8n-nodes-base.wait",
        "typeVersion": 1.1,
        "position": [x, y],
        "webhookId": nid,
    }


booking = {
    "name": "ChatDENT WhatsApp booking",
    "active": False,
    "settings": {"executionOrder": "v1", "timezone": "Asia/Kolkata"},
    "pinData": {},
    "versionId": "1",
    "tags": [],
    "meta": {"templateCredsSetupCompleted": True},
    "nodes": [
        {
            "parameters": {
                "content": "## Do not activate\n\nThis old auto-book workflow is replaced by **ChatDENT WhatsApp assistant**.\nWebhook path is chatdent-whatsapp-legacy so it cannot steal the live assistant webhook even if someone activates it.",
                "height": 440,
                "width": 380,
                "color": 6,
            },
            "id": "note-book-1",
            "name": "Setup",
            "type": "n8n-nodes-base.stickyNote",
            "typeVersion": 1,
            "position": [-420, 120],
        },
        {
            "parameters": {
                "httpMethod": "POST",
                "path": "chatdent-whatsapp-legacy",
                "responseMode": "onReceived",
                "options": {},
            },
            "id": "wh-1",
            "name": "Evolution webhook",
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 2,
            "position": [0, 300],
            "webhookId": "chatdent-whatsapp-legacy",
        },
        code_node("Parse inbound", "code-parse", 240, 300, "parse_inbound.js"),
        {
            "parameters": {
                "conditions": {
                    "boolean": [{"value1": "={{ $json.skip }}", "value2": True}]
                }
            },
            "id": "if-skip",
            "name": "Skip noise",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [480, 300],
        },
        {
            "parameters": {},
            "id": "noop-skip",
            "name": "Ignore",
            "type": "n8n-nodes-base.noOp",
            "typeVersion": 1,
            "position": [720, 140],
        },
        http_post_json(
            "Upsert lead",
            "http-upsert",
            720,
            420,
            PB + "/api/leads/upsert",
            "={{ JSON.stringify({ name: $json.name, phone: $json.phone, source: 'whatsapp', notes: $json.text, stage: 'contacted' }) }}",
        ),
        http_get("Get slots", "http-slots", 960, 420, PB + "/api/leads/slots?days=7"),
        code_node("Build reply or book", "code-reply", 1200, 420, "build_reply.js"),
        {
            "parameters": {
                "conditions": {
                    "boolean": [{"value1": "={{ $json.shouldBook }}", "value2": True}]
                }
            },
            "id": "if-book",
            "name": "Should book?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [1440, 420],
        },
        http_post_json(
            "Book slot",
            "http-book",
            1680,
            280,
            PB + "/api/leads/book",
            "={{ JSON.stringify($json.bookBody) }}",
        ),
        code_node("Confirm text", "code-confirm", 1920, 280, "confirm_text.js"),
        http_evo_send("Send confirm WhatsApp", "http-evo-confirm", 2160, 280),
        http_evo_send("Send slots WhatsApp", "http-evo-slots", 1680, 560),
    ],
    "connections": {
        "Evolution webhook": {"main": [[{"node": "Parse inbound", "type": "main", "index": 0}]]},
        "Parse inbound": {"main": [[{"node": "Skip noise", "type": "main", "index": 0}]]},
        "Skip noise": {
            "main": [
                [{"node": "Ignore", "type": "main", "index": 0}],
                [{"node": "Upsert lead", "type": "main", "index": 0}],
            ]
        },
        "Upsert lead": {"main": [[{"node": "Get slots", "type": "main", "index": 0}]]},
        "Get slots": {"main": [[{"node": "Build reply or book", "type": "main", "index": 0}]]},
        "Build reply or book": {"main": [[{"node": "Should book?", "type": "main", "index": 0}]]},
        "Should book?": {
            "main": [
                [{"node": "Book slot", "type": "main", "index": 0}],
                [{"node": "Send slots WhatsApp", "type": "main", "index": 0}],
            ]
        },
        "Book slot": {"main": [[{"node": "Confirm text", "type": "main", "index": 0}]]},
        "Confirm text": {"main": [[{"node": "Send confirm WhatsApp", "type": "main", "index": 0}]]},
    },
}

reminders = {
    "name": "ChatDENT appointment reminders",
    "active": False,
    "settings": {"executionOrder": "v1", "timezone": "Asia/Kolkata"},
    "pinData": {},
    "versionId": "1",
    "tags": [],
    "meta": {"templateCredsSetupCompleted": True},
    "nodes": [
        {
            "parameters": {
                "content": "## ChatDENT reminders\n\nEvery 15 minutes: 24h and 2h WhatsApp alerts.\nIf the patient replies RESCHEDULE, the assistant flags the visit so staff can call.\nDoes not create calendar bookings.",
                "height": 220,
                "width": 320,
                "color": 5,
            },
            "id": "note-rem-1",
            "name": "Setup",
            "type": "n8n-nodes-base.stickyNote",
            "typeVersion": 1,
            "position": [-360, 200],
        },
        {
            "parameters": {
                "rule": {"interval": [{"field": "minutes", "minutesInterval": 15}]}
            },
            "id": "sched-1",
            "name": "Every 15 minutes",
            "type": "n8n-nodes-base.scheduleTrigger",
            "typeVersion": 1.2,
            "position": [0, 300],
        },
        http_get(
            "Get 24h reminders",
            "http-rem-24",
            240,
            200,
            PB + "/api/leads/reminders?hours=24",
        ),
        http_get(
            "Get 2h reminders",
            "http-rem-2",
            240,
            440,
            PB + "/api/leads/reminders?hours=2",
        ),
        code_node("Split 24h", "code-split-24", 480, 200, "split_reminders.js"),
        code_node("Split 2h", "code-split-2", 480, 440, "split_reminders.js"),
        wait_seconds("Wait before reminder", "wait-rem", 640, 320, 12),
        http_evo_send("Send reminder WhatsApp", "http-evo-rem", 880, 320),
        http_post_json(
            "Mark reminder sent",
            "http-mark",
            1120,
            320,
            PB + "/api/leads/mark-reminder",
            # After Evolution send, $json is the API response — keep ids from the wait node.
            "={{ JSON.stringify({ appointmentId: $('Wait before reminder').item.json.appointmentId, kind: $('Wait before reminder').item.json.kind }) }}",
        ),
    ],
    "connections": {
        "Every 15 minutes": {
            "main": [
                [
                    {"node": "Get 24h reminders", "type": "main", "index": 0},
                    {"node": "Get 2h reminders", "type": "main", "index": 0},
                ]
            ]
        },
        "Get 24h reminders": {"main": [[{"node": "Split 24h", "type": "main", "index": 0}]]},
        "Get 2h reminders": {"main": [[{"node": "Split 2h", "type": "main", "index": 0}]]},
        "Split 24h": {"main": [[{"node": "Wait before reminder", "type": "main", "index": 0}]]},
        "Split 2h": {"main": [[{"node": "Wait before reminder", "type": "main", "index": 0}]]},
        "Wait before reminder": {
            "main": [[{"node": "Send reminder WhatsApp", "type": "main", "index": 0}]]
        },
        "Send reminder WhatsApp": {
            "main": [[{"node": "Mark reminder sent", "type": "main", "index": 0}]]
        },
    },
}

assistant = {
    "name": "ChatDENT WhatsApp assistant",
    "active": False,
    "settings": {"executionOrder": "v1", "timezone": "Asia/Kolkata"},
    "pinData": {},
    "versionId": "1",
    "tags": [],
    "meta": {"templateCredsSetupCompleted": True},
    "nodes": [
        {
            "parameters": {
                "content": "## ChatDENT WhatsApp assistant (OpenRouter)\n\n1. OPENROUTER_API_KEY in D:\\ChatDENT\\.env and N8N_BLOCK_ENV_ACCESS_IN_NODE=false in docker-compose, then: docker compose up -d n8n --force-recreate\n2. Import this workflow. Keep only this assistant active for the webhook.\n3. Evolution webhook: `http://n8n:5678/webhook/chatdent-whatsapp` event messages.upsert instance `clinic_default`.\n4. Activate this workflow.\n\nSkipped like groups: staff-group chats, status, protocol noise, and Meta Ads / Click-to-WhatsApp automated chat (no AI reply, no new-lead group alert).\n\nCanned WhatsApp (welcome, confirm, reminder, birthday, review, group alerts, opt-out) comes from **WhatsApp templates** in ChatDENT. The AI only chats after the first welcome. It never books and never quotes fees.",
                "height": 520,
                "width": 420,
                "color": 6,
            },
            "id": "note-ai-1",
            "name": "Setup",
            "type": "n8n-nodes-base.stickyNote",
            "typeVersion": 1,
            "position": [-460, 80],
        },
        {
            "parameters": {
                "httpMethod": "POST",
                "path": "chatdent-whatsapp",
                "responseMode": "onReceived",
                "options": {},
            },
            "id": "wh-ai-1",
            "name": "Evolution webhook",
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 2,
            "position": [0, 300],
            "webhookId": "chatdent-whatsapp",
        },
        code_node("Parse inbound", "code-parse-ai", 240, 300, "parse_inbound.js"),
        {
            "parameters": {
                "conditions": {
                    "boolean": [{"value1": "={{ $json.skip }}", "value2": True}]
                }
            },
            "id": "if-skip-ai",
            "name": "Skip noise",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [480, 300],
        },
        {
            "parameters": {},
            "id": "noop-skip-ai",
            "name": "Ignore",
            "type": "n8n-nodes-base.noOp",
            "typeVersion": 1,
            "position": [720, 140],
        },
        {
            "parameters": {
                "conditions": {
                    "boolean": [
                        {"value1": "={{ $json.staffReply }}", "value2": True}
                    ]
                }
            },
            "id": "if-staff",
            "name": "Staff replied?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [720, 300],
        },
        http_post_json(
            "Pause assistant",
            "http-pause",
            960,
            220,
            PB + "/api/leads/ai-event",
            "={{ JSON.stringify({ phone: $json.phone, name: $json.name, type: 'pause' }) }}",
        ),
        http_post_json(
            "Upsert lead",
            "http-upsert-ai",
            720,
            420,
            PB + "/api/leads/upsert",
            "={{ JSON.stringify({ name: $json.name, phone: $json.phone, source: 'whatsapp', notes: $json.text, stage: 'contacted', optOut: $json.optOut }) }}",
        ),
        code_node("Prepare after upsert", "code-after-up", 960, 420, "prepare_after_upsert.js"),
        {
            "parameters": {
                "conditions": {
                    "boolean": [
                        {"value1": "={{ $json.notifyGroup }}", "value2": True}
                    ]
                }
            },
            "id": "if-group",
            "name": "Notify staff group?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [1200, 200],
        },
        code_node("Set group target", "code-group-tgt", 1440, 80, "prepare_group_send.js"),
        wait_seconds("Wait before group", "wait-group", 1680, 80, 4),
        http_evo_send("Send staff group alert", "http-evo-group", 1920, 80),
        {
            "parameters": {
                "conditions": {
                    "boolean": [
                        {"value1": "={{ $json.optOut }}", "value2": True}
                    ]
                }
            },
            "id": "if-optout",
            "name": "Opted out?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [1200, 360],
        },
        code_node("Set opt-out target", "code-optout-tgt", 1440, 240, "prepare_optout_send.js"),
        wait_seconds("Wait before opt-out", "wait-optout", 1680, 240, 3),
        http_evo_send("Send opt-out template", "http-evo-optout", 1920, 240),
        {
            "parameters": {
                "conditions": {
                    "boolean": [
                        {"value1": "={{ $json.sendWelcome }}", "value2": True}
                    ]
                }
            },
            "id": "if-welcome",
            "name": "Send welcome?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [1440, 420],
        },
        code_node("Set welcome target", "code-welcome-tgt", 1680, 360, "prepare_welcome_send.js"),
        wait_seconds("Wait before welcome", "wait-welcome", 1920, 360, 4),
        http_evo_send("Send welcome template", "http-evo-welcome", 2160, 360),
        {
            "parameters": {
                "conditions": {
                    "boolean": [
                        {"value1": "={{ $json.shouldReply }}", "value2": True}
                    ]
                }
            },
            "id": "if-reply",
            "name": "Reply now?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [1680, 560],
        },
        {
            "parameters": {},
            "id": "noop-cool",
            "name": "Cooldown skip",
            "type": "n8n-nodes-base.noOp",
            "typeVersion": 1,
            "position": [1440, 620],
        },
        wait_seconds("Wait before AI", "wait-ai", 1440, 480, 5),
        http_get(
            "Get AI context",
            "http-ai-ctx",
            1680,
            480,
            "={{ $('Parse inbound').item.json.pbBase + '/api/leads/ai-context?phone=' + $('Parse inbound').item.json.phone }}",
        ),
        code_node("Build AI prompt", "code-ai-prompt", 1920, 480, "ai_prompt.js"),
        http_openrouter("OpenRouter", "http-openrouter", 2160, 480),
        wait_seconds("Wait before send", "wait-send", 2400, 480, 3),
        code_node("Parse AI result", "code-ai-result", 2640, 480, "ai_result.js"),
        http_evo_send("Send WhatsApp reply", "http-evo-ai", 2880, 480),
        {
            "parameters": {
                "conditions": {
                    "boolean": [
                        {"value1": "={{ $json.attachFlyer }}", "value2": True}
                    ]
                }
            },
            "id": "if-flyer",
            "name": "Attach flyer?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [3120, 480],
        },
        http_evo_media("Send flyer image", "http-evo-flyer", 3360, 320),
        code_node("Split AI events", "code-ai-events", 3600, 480, "split_ai_events.js"),
        http_post_json(
            "Record AI event",
            "http-ai-event",
            3840,
            480,
            PB + "/api/leads/ai-event",
            "={{ JSON.stringify({ phone: $json.phone, name: $json.name, type: $json.type, appointmentId: $json.appointmentId, interest: $json.interest, note: $json.note, preferredTime: $json.preferredTime, leadId: $json.leadId }) }}",
        ),
        code_node(
            "Prepare reschedule group",
            "code-resched-group",
            4080,
            480,
            "prepare_reschedule_group.js",
        ),
        wait_seconds("Wait before reschedule group", "wait-resched-group", 4320, 480, 3),
        http_evo_send(
            "Send reschedule group alert",
            "http-evo-resched-group",
            4560,
            480,
        ),
    ],
    "connections": {
        "Evolution webhook": {
            "main": [[{"node": "Parse inbound", "type": "main", "index": 0}]]
        },
        "Parse inbound": {
            "main": [[{"node": "Skip noise", "type": "main", "index": 0}]]
        },
        "Skip noise": {
            "main": [
                [{"node": "Ignore", "type": "main", "index": 0}],
                [{"node": "Staff replied?", "type": "main", "index": 0}],
            ]
        },
        "Staff replied?": {
            "main": [
                [{"node": "Pause assistant", "type": "main", "index": 0}],
                [{"node": "Upsert lead", "type": "main", "index": 0}],
            ]
        },
        "Upsert lead": {
            "main": [[{"node": "Prepare after upsert", "type": "main", "index": 0}]]
        },
        "Prepare after upsert": {
            "main": [
                [
                    {"node": "Notify staff group?", "type": "main", "index": 0},
                    {"node": "Opted out?", "type": "main", "index": 0},
                ]
            ]
        },
        "Notify staff group?": {
            "main": [
                [{"node": "Set group target", "type": "main", "index": 0}],
                [],
            ]
        },
        "Set group target": {
            "main": [[{"node": "Wait before group", "type": "main", "index": 0}]]
        },
        "Wait before group": {
            "main": [[{"node": "Send staff group alert", "type": "main", "index": 0}]]
        },
        "Opted out?": {
            "main": [
                [{"node": "Set opt-out target", "type": "main", "index": 0}],
                [{"node": "Send welcome?", "type": "main", "index": 0}],
            ]
        },
        "Set opt-out target": {
            "main": [[{"node": "Wait before opt-out", "type": "main", "index": 0}]]
        },
        "Wait before opt-out": {
            "main": [[{"node": "Send opt-out template", "type": "main", "index": 0}]]
        },
        "Send welcome?": {
            "main": [
                [{"node": "Set welcome target", "type": "main", "index": 0}],
                [{"node": "Reply now?", "type": "main", "index": 0}],
            ]
        },
        "Set welcome target": {
            "main": [[{"node": "Wait before welcome", "type": "main", "index": 0}]]
        },
        "Wait before welcome": {
            "main": [[{"node": "Send welcome template", "type": "main", "index": 0}]]
        },
        "Reply now?": {
            "main": [
                [{"node": "Wait before AI", "type": "main", "index": 0}],
                [{"node": "Cooldown skip", "type": "main", "index": 0}],
            ]
        },
        "Wait before AI": {
            "main": [[{"node": "Get AI context", "type": "main", "index": 0}]]
        },
        "Get AI context": {
            "main": [[{"node": "Build AI prompt", "type": "main", "index": 0}]]
        },
        "Build AI prompt": {
            "main": [[{"node": "OpenRouter", "type": "main", "index": 0}]]
        },
        "OpenRouter": {
            "main": [[{"node": "Parse AI result", "type": "main", "index": 0}]]
        },
        "Parse AI result": {
            "main": [[{"node": "Wait before send", "type": "main", "index": 0}]]
        },
        "Wait before send": {
            "main": [[{"node": "Send WhatsApp reply", "type": "main", "index": 0}]]
        },
        "Send WhatsApp reply": {
            "main": [
                [
                    {"node": "Attach flyer?", "type": "main", "index": 0},
                    {"node": "Split AI events", "type": "main", "index": 0},
                ]
            ]
        },
        "Attach flyer?": {
            "main": [
                [{"node": "Send flyer image", "type": "main", "index": 0}],
                [],
            ]
        },
        "Split AI events": {
            "main": [[{"node": "Record AI event", "type": "main", "index": 0}]]
        },
        "Record AI event": {
            "main": [[{"node": "Prepare reschedule group", "type": "main", "index": 0}]]
        },
        "Prepare reschedule group": {
            "main": [[{"node": "Wait before reschedule group", "type": "main", "index": 0}]]
        },
        "Wait before reschedule group": {
            "main": [[{"node": "Send reschedule group alert", "type": "main", "index": 0}]]
        },
    },
}

outreach = {
    "name": "ChatDENT birthdays and reviews",
    "active": False,
    "settings": {"executionOrder": "v1", "timezone": "Asia/Kolkata"},
    "pinData": {},
    "versionId": "1",
    "tags": [],
    "meta": {"templateCredsSetupCompleted": True},
    "nodes": [
        {
            "parameters": {
                "content": "## Birthdays\n\nClinic-local 09:00 (workflow timezone Asia/Kolkata): birthday WhatsApp once per clinic year.\nGoogle review requests are sent only from ChatDENT → patient details (treatment completed + Send review request).",
                "height": 280,
                "width": 360,
                "color": 4,
            },
            "id": "note-out-1",
            "name": "Setup",
            "type": "n8n-nodes-base.stickyNote",
            "typeVersion": 1,
            "position": [-380, 160],
        },
        {
            "parameters": {
                "rule": {
                    "interval": [
                        {
                            "field": "days",
                            "daysInterval": 1,
                            "triggerAtHour": 9,
                            "triggerAtMinute": 0,
                        }
                    ]
                }
            },
            "id": "sched-bday",
            "name": "Daily 9am",
            "type": "n8n-nodes-base.scheduleTrigger",
            "typeVersion": 1.2,
            "position": [0, 200],
        },
        http_get(
            "Get due birthdays",
            "http-bdays",
            240,
            200,
            PB + "/api/leads/due-birthdays?days=0",
        ),
        code_node("Split birthdays", "code-split-bday", 480, 200, "split_outreach.js"),
        wait_seconds("Wait before outreach", "wait-out", 640, 200, 15),
        http_evo_send("Send outreach WhatsApp", "http-evo-out", 880, 340),
        http_post_json(
            "Mark outreach sent",
            "http-mark-out",
            1120,
            340,
            PB + "/api/leads/ai-event",
            "={{ JSON.stringify({ phone: $('Wait before outreach').item.json.phone, name: $('Wait before outreach').item.json.name, type: $('Wait before outreach').item.json.type }) }}",
        ),
    ],
    "connections": {
        "Daily 9am": {
            "main": [[{"node": "Get due birthdays", "type": "main", "index": 0}]]
        },
        "Get due birthdays": {
            "main": [[{"node": "Split birthdays", "type": "main", "index": 0}]]
        },
        "Split birthdays": {
            "main": [[{"node": "Wait before outreach", "type": "main", "index": 0}]]
        },
        "Wait before outreach": {
            "main": [[{"node": "Send outreach WhatsApp", "type": "main", "index": 0}]]
        },
        "Send outreach WhatsApp": {
            "main": [[{"node": "Mark outreach sent", "type": "main", "index": 0}]]
        },
    },
}

marketing = {
    "name": "ChatDENT marketing blast",
    "active": False,
    "settings": {"executionOrder": "v1", "timezone": "Asia/Kolkata"},
    "pinData": {},
    "versionId": "1",
    "tags": [],
    "meta": {"templateCredsSetupCompleted": True},
    "nodes": [
        {
            "parameters": {
                "content": "## Marketing blast\n\nEvery 5 minutes: one queued lead per filled marketing instance (1-4), rotating 1 → 2 → 3 → 4. Waits 25s then sends.\nIf those fields are empty, uses the clinic instance.\nReplies still create a lead and post NEW/RETURNING to the staff group from the clinic number. Put the extra WhatsApp accounts in that group. Do not chat there.",
                "height": 280,
                "width": 380,
                "color": 3,
            },
            "id": "note-mkt-1",
            "name": "Setup",
            "type": "n8n-nodes-base.stickyNote",
            "typeVersion": 1,
            "position": [-400, 180],
        },
        {
            "parameters": {
                "rule": {"interval": [{"field": "minutes", "minutesInterval": 5}]}
            },
            "id": "sched-mkt",
            "name": "Every 5 minutes",
            "type": "n8n-nodes-base.scheduleTrigger",
            "typeVersion": 1.2,
            "position": [0, 300],
        },
        http_get(
            "Get due marketing",
            "http-mkt",
            240,
            300,
            PB + "/api/leads/due-marketing",
        ),
        code_node("Split marketing", "code-split-mkt", 480, 300, "split_marketing.js"),
        wait_seconds("Wait before blast", "wait-mkt", 720, 300, 25),
        {
            "parameters": {
                "conditions": {
                    "boolean": [
                        {"value1": "={{ $json.sendMedia }}", "value2": True}
                    ]
                }
            },
            "id": "if-mkt-img",
            "name": "Has image?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [960, 300],
        },
        http_evo_media("Send marketing image", "http-evo-mkt", 1200, 200),
        http_evo_send("Send marketing text", "http-evo-mkt-text", 1200, 400),
        http_post_json(
            "Mark marketing sent",
            "http-mark-mkt",
            1440,
            300,
            PB + "/api/leads/ai-event",
            "={{ JSON.stringify({ phone: $('Wait before blast').item.json.phone, name: $('Wait before blast').item.json.name, type: $('Wait before blast').item.json.type, leadId: $('Wait before blast').item.json.leadId }) }}",
        ),
    ],
    "connections": {
        "Every 5 minutes": {
            "main": [[{"node": "Get due marketing", "type": "main", "index": 0}]]
        },
        "Get due marketing": {
            "main": [[{"node": "Split marketing", "type": "main", "index": 0}]]
        },
        "Split marketing": {
            "main": [[{"node": "Wait before blast", "type": "main", "index": 0}]]
        },
        "Wait before blast": {
            "main": [[{"node": "Has image?", "type": "main", "index": 0}]]
        },
        "Has image?": {
            "main": [
                [{"node": "Send marketing image", "type": "main", "index": 0}],
                [{"node": "Send marketing text", "type": "main", "index": 0}],
            ]
        },
        "Send marketing image": {
            "main": [[{"node": "Mark marketing sent", "type": "main", "index": 0}]]
        },
        "Send marketing text": {
            "main": [[{"node": "Mark marketing sent", "type": "main", "index": 0}]]
        },
    },
}

(root / "chatdent-reminders.json").write_text(
    json.dumps(reminders, indent=2), encoding="utf-8"
)
(root / "chatdent-whatsapp-assistant.json").write_text(
    json.dumps(assistant, indent=2), encoding="utf-8"
)
(root / "chatdent-birthdays-reviews.json").write_text(
    json.dumps(outreach, indent=2), encoding="utf-8"
)
(root / "chatdent-marketing.json").write_text(
    json.dumps(marketing, indent=2), encoding="utf-8"
)
print("wrote workflows")

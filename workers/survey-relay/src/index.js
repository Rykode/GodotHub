const MAX_BODY_BYTES = 8192;
const MAX_TEXT_CHARS = 500;
const MAX_QUESTIONS = 5;
const IP_LIMIT_PER_HOUR = 10;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ID_RE = /^[A-Za-z0-9_.-]{1,64}$/;
const VERSION_RE = /^[0-9A-Za-z.+-]{1,32}$/;
const PLATFORMS = new Set(["windows", "macos", "linux"]);

function json(status, body, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...headers },
  });
}

function cleanText(value) {
  if (typeof value !== "string") return "";
  return value
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "")
    .replace(/\r\n?/g, "\n")
    .trim()
    .slice(0, MAX_TEXT_CHARS);
}

function isExpired(survey) {
  return typeof survey.expires === "string" && Date.parse(survey.expires) < Date.now();
}

async function loadSurvey(env, id) {
  const raw = await env.SURVEY_KV.get(`survey:${id}`);
  if (!raw) return null;
  try {
    const survey = JSON.parse(raw);
    if (survey.id !== id || !Array.isArray(survey.questions)) return null;
    survey.questions = survey.questions.slice(0, MAX_QUESTIONS);
    return survey;
  } catch {
    return null;
  }
}

async function sha256Hex(text) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function overIpLimit(env, request) {
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const hour = Math.floor(Date.now() / 3_600_000);
  const key = `ip:${await sha256Hex(`${env.IP_HASH_SALT}:${ip}`)}:${hour}`;
  const count = parseInt((await env.SURVEY_KV.get(key)) || "0", 10);
  if (count >= IP_LIMIT_PER_HOUR) return true;
  await env.SURVEY_KV.put(key, String(count + 1), { expirationTtl: 7200 });
  return false;
}

async function handleActive(env) {
  const id = await env.SURVEY_KV.get("active");
  if (!id) return new Response(null, { status: 204 });
  const survey = await loadSurvey(env, id);
  if (!survey || isExpired(survey)) return new Response(null, { status: 204 });
  return json(200, survey, { "cache-control": "public, max-age=300" });
}

function parseAnswers(survey, answers) {
  if (!answers || typeof answers !== "object" || Array.isArray(answers)) return null;
  const choices = [];
  const texts = [];
  for (const q of survey.questions) {
    const raw = answers[q.id];
    if (q.type === "choice") {
      if (raw === undefined) {
        if (q.required) return null;
        continue;
      }
      const index = (q.options || []).findIndex((o) => o.id === raw);
      if (index < 0) return null;
      choices.push({ question: q.text, option: q.options[index], index });
    } else if (q.type === "text") {
      const value = cleanText(raw);
      if (!value) {
        if (q.required) return null;
        continue;
      }
      texts.push({ question: q.text, value });
    } else {
      return null;
    }
  }
  return choices.length || texts.length ? { choices, texts } : null;
}

const CHOICE_COLORS = [0x3ba55d, 0xfaa61a, 0xed4245, 0x747f8d, 0x5865f2, 0x9b59b6, 0xe67e22, 0x95a5a6];
const CHOICE_EMOJI = ["🟢", "🟡", "🔴", "⚪", "🔵", "🟣", "🟠", "⚫"];
const PLATFORM_NAMES = { windows: "Windows", macos: "macOS", linux: "Linux" };

function buildEmbed(survey, parsed, data) {
  const description = parsed.choices
    .map(({ question, option, index }) => {
      const lines = [`**${question}**`, `## ${CHOICE_EMOJI[index % CHOICE_EMOJI.length]}  ${option.label}`];
      if (option.description) lines.push(`*${option.description}*`);
      return lines.join("\n");
    })
    .join("\n\n");

  const fields = parsed.texts.map(({ question, value }) => ({
    name: `💬 ${question}`.slice(0, 256),
    value: value.split("\n").map((l) => `> ${l}`).join("\n").slice(0, 1024),
    inline: false,
  }));
  fields.push(
    { name: "🏷️ Version", value: data.appVersion, inline: true },
    { name: "💻 Platform", value: PLATFORM_NAMES[data.platform] || data.platform, inline: true },
  );

  const first = parsed.choices[0];
  return {
    author: { name: "GodotHub Survey" },
    title: `📋 ${String(survey.title || survey.id)}`.slice(0, 256),
    ...(description ? { description: description.slice(0, 4096) } : {}),
    color: first ? CHOICE_COLORS[first.index % CHOICE_COLORS.length] : 0x5865f2,
    fields,
    footer: { text: `survey: ${survey.id}` },
    timestamp: new Date().toISOString(),
  };
}

async function handleResponse(request, env) {
  if (!(request.headers.get("content-type") || "").toLowerCase().startsWith("application/json")) {
    return json(415, { error: "unsupported_media_type" });
  }
  const raw = await request.text();
  if (raw.length > MAX_BODY_BYTES) return json(413, { error: "too_large" });

  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    return json(400, { error: "invalid_json" });
  }
  if (
    !data || typeof data !== "object" || Array.isArray(data) ||
    data.v !== 2 ||
    typeof data.surveyId !== "string" || !ID_RE.test(data.surveyId) ||
    typeof data.installId !== "string" || !UUID_RE.test(data.installId) ||
    typeof data.appVersion !== "string" || !VERSION_RE.test(data.appVersion) ||
    !PLATFORMS.has(data.platform)
  ) {
    return json(400, { error: "invalid_payload" });
  }

  const survey = await loadSurvey(env, data.surveyId);
  if (!survey || isExpired(survey)) return json(404, { error: "unknown_survey" });
  const parsed = parseAnswers(survey, data.answers);
  if (!parsed) return json(400, { error: "invalid_answers" });

  const voteKey = `vote:${survey.id}:${data.installId}`;
  if (await env.SURVEY_KV.get(voteKey)) return json(200, { ok: true, duplicate: true });
  if (await overIpLimit(env, request)) return json(429, { error: "rate_limited" });

  const res = await fetch(env.DISCORD_WEBHOOK_URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      username: "GodotHub Survey",
      allowed_mentions: { parse: [] },
      embeds: [buildEmbed(survey, parsed, data)],
    }),
  });
  if (!res.ok) return json(res.status === 429 ? 503 : 502, { error: "upstream_failed" });

  await env.SURVEY_KV.put(voteKey, "1", { expirationTtl: 60 * 60 * 24 * 365 });
  return json(200, { ok: true });
}

const ADMIN_FAIL_LIMIT_PER_HOUR = 10;

function str(value, max) {
  return typeof value === "string" && value.length <= max;
}

function validateSurvey(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) return null;
  if (typeof data.id !== "string" || !ID_RE.test(data.id)) return null;
  if (!str(data.title, 100) || !data.title.trim()) return null;
  if (data.intro !== undefined && !str(data.intro, 500)) return null;
  if (data.expires !== undefined && (!str(data.expires, 40) || Number.isNaN(Date.parse(data.expires)))) return null;
  if (!Array.isArray(data.questions) || data.questions.length < 1 || data.questions.length > MAX_QUESTIONS) return null;

  const seen = new Set();
  const questions = [];
  for (const q of data.questions) {
    if (!q || typeof q !== "object") return null;
    if (typeof q.id !== "string" || !ID_RE.test(q.id) || seen.has(q.id)) return null;
    seen.add(q.id);
    if (!str(q.text, 200) || !q.text.trim()) return null;
    if (q.type === "text") {
      questions.push({ id: q.id, type: "text", text: q.text, required: q.required === true });
    } else if (q.type === "choice") {
      if (!Array.isArray(q.options) || q.options.length < 2 || q.options.length > 8) return null;
      const optionIds = new Set();
      const options = [];
      for (const o of q.options) {
        if (!o || typeof o.id !== "string" || !ID_RE.test(o.id) || optionIds.has(o.id)) return null;
        optionIds.add(o.id);
        if (!str(o.label, 100) || !o.label.trim()) return null;
        if (o.description !== undefined && !str(o.description, 200)) return null;
        options.push({ id: o.id, label: o.label, ...(o.description ? { description: o.description } : {}) });
      }
      questions.push({ id: q.id, type: "choice", text: q.text, required: q.required === true, options });
    } else {
      return null;
    }
  }
  return {
    id: data.id,
    title: data.title,
    ...(data.intro ? { intro: data.intro } : {}),
    ...(data.expires ? { expires: data.expires } : {}),
    questions,
  };
}

async function timingSafeEqual(a, b) {
  const [ha, hb] = await Promise.all([sha256Hex(a), sha256Hex(b)]);
  let diff = 0;
  for (let i = 0; i < ha.length; i++) diff |= ha.charCodeAt(i) ^ hb.charCodeAt(i);
  return diff === 0;
}

async function checkAdmin(request, env) {
  if (!env.SURVEY_ADMIN_TOKEN) return json(404, { error: "not_found" });
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const hour = Math.floor(Date.now() / 3_600_000);
  const key = `adminfail:${await sha256Hex(`${env.IP_HASH_SALT}:${ip}`)}:${hour}`;
  const fails = parseInt((await env.SURVEY_KV.get(key)) || "0", 10);
  if (fails >= ADMIN_FAIL_LIMIT_PER_HOUR) return json(429, { error: "rate_limited" });

  const header = request.headers.get("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (token && (await timingSafeEqual(token, env.SURVEY_ADMIN_TOKEN))) return null;
  await env.SURVEY_KV.put(key, String(fails + 1), { expirationTtl: 7200 });
  return json(401, { error: "unauthorized" });
}

async function handleAdmin(request, env, path) {
  const denied = await checkAdmin(request, env);
  if (denied) return denied;
  const method = request.method;

  if (method === "GET" && path === "/admin/surveys") {
    const listed = await env.SURVEY_KV.list({ prefix: "survey:" });
    const surveys = [];
    for (const { name } of listed.keys) {
      const survey = await loadSurvey(env, name.slice("survey:".length));
      if (survey) surveys.push(survey);
    }
    return json(200, { active: await env.SURVEY_KV.get("active"), surveys });
  }

  if (method === "PUT" && path === "/admin/active") {
    let body;
    try {
      body = JSON.parse(await request.text());
    } catch {
      return json(400, { error: "invalid_json" });
    }
    if (body && body.id === null) {
      await env.SURVEY_KV.delete("active");
      return json(200, { ok: true, active: null });
    }
    if (!body || typeof body.id !== "string" || !(await loadSurvey(env, body.id))) {
      return json(404, { error: "unknown_survey" });
    }
    await env.SURVEY_KV.put("active", body.id);
    return json(200, { ok: true, active: body.id });
  }

  const match = path.match(/^\/admin\/surveys\/([A-Za-z0-9_.-]{1,64})$/);
  if (!match) return json(404, { error: "not_found" });
  const id = match[1];

  if (method === "PUT") {
    const raw = await request.text();
    if (raw.length > 32768) return json(413, { error: "too_large" });
    let data;
    try {
      data = JSON.parse(raw);
    } catch {
      return json(400, { error: "invalid_json" });
    }
    const survey = validateSurvey(data);
    if (!survey || survey.id !== id) return json(400, { error: "invalid_survey" });
    await env.SURVEY_KV.put(`survey:${id}`, JSON.stringify(survey));
    return json(200, { ok: true });
  }

  if (method === "DELETE") {
    await env.SURVEY_KV.delete(`survey:${id}`);
    if ((await env.SURVEY_KV.get("active")) === id) await env.SURVEY_KV.delete("active");
    return json(200, { ok: true });
  }

  return json(405, { error: "method_not_allowed" });
}

export default {
  async fetch(request, env) {
    if (!env.DISCORD_WEBHOOK_URL || !env.IP_HASH_SALT) return json(500, { error: "not_configured" });
    const path = new URL(request.url).pathname;
    if (path.startsWith("/admin/")) return handleAdmin(request, env, path);
    if (request.method === "GET" && path === "/active") return handleActive(env);
    if (request.method === "POST" && path === "/") return handleResponse(request, env);
    return json(405, { error: "method_not_allowed" });
  },
};

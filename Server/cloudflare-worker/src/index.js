/**
 * ツギイチ AI Proxy — Cloudflare Worker
 *
 * POST /generate-steps
 *   入力: { goalTitle, goalNote?, category?, constraints? }
 *   出力: { steps: [ { title, type, durationMin, dueSuggestion, notes } ] }
 *
 * 秘密鍵 OPENAI_API_KEY は wrangler secret で設定する（コードに埋め込まない）。
 * 認証トークン API_AUTH_TOKEN も wrangler secret で設定する。
 */

// ---------------------------------------------------------------------------
// Rate Limiter (IP-based, in-memory per isolate — 簡易版)
// ---------------------------------------------------------------------------

const rateLimitMap = new Map(); // key: IP, value: { count, resetAt }

/**
 * @param {string} ip
 * @param {number} limit - requests per window
 * @param {number} windowMs - window duration in ms
 * @returns {{ allowed: boolean, retryAfter: number | null }}
 */
function checkRateLimit(ip, limit, windowMs) {
  const now = Date.now();
  let entry = rateLimitMap.get(ip);

  if (!entry || now >= entry.resetAt) {
    entry = { count: 0, resetAt: now + windowMs };
    rateLimitMap.set(ip, entry);
  }

  entry.count += 1;

  if (entry.count > limit) {
    const retryAfter = Math.ceil((entry.resetAt - now) / 1000);
    return { allowed: false, retryAfter };
  }

  return { allowed: true, retryAfter: null };
}

// ---------------------------------------------------------------------------
// System prompts (per language)
// ---------------------------------------------------------------------------

const SYSTEM_PROMPTS = {
  ja: `あなたはタスク分解アシスタントです。
ユーザーが「やりたいこと（Goal）」を与えるので、それを具体的な次の一手（Step）に分解してください。

ルール:
- stepsは3〜8件にする
- 最初の1件は「今日15分でできる初手（クイックウィン）」にする
- 各stepのtypeは "調べる" | "予約する" | "用意する" | "行く" | "作る" | "連絡する" のいずれか
- durationMinは 15 | 30 | 60 | 120 のいずれか
- dueSuggestionは "today" | "this_week" | "none" のいずれか
- 不確実な内容は "調べる" に寄せる
- 断定しない（安全側の表現を使う）

必ず以下のJSON形式のみで返答してください。余計な説明文は一切含めないでください:
{
  "steps": [
    {
      "title": "...",
      "type": "調べる|予約する|用意する|行く|作る|連絡する",
      "durationMin": 15,
      "dueSuggestion": "today|this_week|none",
      "notes": "任意の補足"
    }
  ]
}`,
  en: `You are a task-decomposition assistant.
The user gives you a Goal (something they want to do). Break it down into concrete next Steps.

Rules:
- Return 3–8 steps
- The first step must be a "quick win" doable in 15 min today
- Each step type must be one of: "research" | "reserve" | "prepare" | "go" | "create" | "contact"
- durationMin must be one of: 15 | 30 | 60 | 120
- dueSuggestion must be one of: "today" | "this_week" | "none"
- Lean toward "research" for uncertain items
- Use cautious language (avoid definitive statements)

Respond ONLY with the following JSON format. Do NOT include any extra text:
{
  "steps": [
    {
      "title": "...",
      "type": "research|reserve|prepare|go|create|contact",
      "durationMin": 15,
      "dueSuggestion": "today|this_week|none",
      "notes": "optional notes"
    }
  ]
}`,
  "zh-Hans": `你是一个任务分解助手。
用户会给你一个目标（Goal），请将其分解为具体的下一步行动（Step）。

规则：
- 返回3至8个步骤
- 第一步必须是"今天15分钟内可完成的快速行动"
- 每步的type必须是以下之一："调查" | "预约" | "准备" | "前往" | "制作" | "联系"
- durationMin必须是以下之一：15 | 30 | 60 | 120
- dueSuggestion必须是以下之一："today" | "this_week" | "none"
- 不确定的内容归类为"调查"
- 使用谨慎的表达方式

请仅以以下JSON格式回复，不要包含任何额外文字：
{
  "steps": [
    {
      "title": "...",
      "type": "调查|预约|准备|前往|制作|联系",
      "durationMin": 15,
      "dueSuggestion": "today|this_week|none",
      "notes": "可选备注"
    }
  ]
}`,
  ko: `당신은 작업 분해 도우미입니다.
사용자가 목표(Goal)를 제시하면, 구체적인 다음 단계(Step)로 분해해 주세요.

규칙:
- 3~8개의 단계를 반환합니다
- 첫 번째 단계는 "오늘 15분 안에 할 수 있는 퀵윈"이어야 합니다
- 각 단계의 type은 다음 중 하나: "조사" | "예약" | "준비" | "이동" | "만들기" | "연락"
- durationMin은 다음 중 하나: 15 | 30 | 60 | 120
- dueSuggestion은 다음 중 하나: "today" | "this_week" | "none"
- 불확실한 내용은 "조사"로 분류합니다
- 단정적 표현을 피합니다

반드시 아래 JSON 형식으로만 응답하세요. 추가 설명은 포함하지 마세요:
{
  "steps": [
    {
      "title": "...",
      "type": "조사|예약|준비|이동|만들기|연락",
      "durationMin": 15,
      "dueSuggestion": "today|this_week|none",
      "notes": "선택적 메모"
    }
  ]
}`,
  es: `Eres un asistente de descomposición de tareas.
El usuario te da un Objetivo (Goal). Desglósalo en pasos concretos (Steps).

Reglas:
- Devuelve entre 3 y 8 pasos
- El primer paso debe ser una "victoria rápida" realizable en 15 min hoy
- El type de cada paso debe ser uno de: "investigar" | "reservar" | "preparar" | "ir" | "crear" | "contactar"
- durationMin debe ser uno de: 15 | 30 | 60 | 120
- dueSuggestion debe ser uno de: "today" | "this_week" | "none"
- Para elementos inciertos, usa "investigar"
- Usa lenguaje prudente

Responde SOLO con el siguiente formato JSON. NO incluyas texto adicional:
{
  "steps": [
    {
      "title": "...",
      "type": "investigar|reservar|preparar|ir|crear|contactar",
      "durationMin": 15,
      "dueSuggestion": "today|this_week|none",
      "notes": "notas opcionales"
    }
  ]
}`,
  fr: `Vous êtes un assistant de décomposition de tâches.
L'utilisateur vous donne un Objectif (Goal). Décomposez-le en étapes concrètes (Steps).

Règles :
- Retournez 3 à 8 étapes
- La première étape doit être une "victoire rapide" réalisable en 15 min aujourd'hui
- Le type de chaque étape doit être l'un de : "rechercher" | "réserver" | "préparer" | "aller" | "créer" | "contacter"
- durationMin doit être l'un de : 15 | 30 | 60 | 120
- dueSuggestion doit être l'un de : "today" | "this_week" | "none"
- Pour les éléments incertains, utilisez "rechercher"
- Utilisez un langage prudent

Répondez UNIQUEMENT avec le format JSON suivant. N'incluez AUCUN texte supplémentaire :
{
  "steps": [
    {
      "title": "...",
      "type": "rechercher|réserver|préparer|aller|créer|contacter",
      "durationMin": 15,
      "dueSuggestion": "today|this_week|none",
      "notes": "notes optionnelles"
    }
  ]
}`,
  de: `Sie sind ein Aufgabenzerlegungs-Assistent.
Der Benutzer gibt Ihnen ein Ziel (Goal). Zerlegen Sie es in konkrete nächste Schritte (Steps).

Regeln:
- Geben Sie 3–8 Schritte zurück
- Der erste Schritt muss ein "Quick Win" sein, der heute in 15 Min. machbar ist
- Der Typ jedes Schritts muss einer von sein: "recherchieren" | "reservieren" | "vorbereiten" | "hingehen" | "erstellen" | "kontaktieren"
- durationMin muss einer von sein: 15 | 30 | 60 | 120
- dueSuggestion muss einer von sein: "today" | "this_week" | "none"
- Bei unsicheren Inhalten "recherchieren" verwenden
- Vorsichtige Formulierungen verwenden

Antworten Sie NUR im folgenden JSON-Format. Fügen Sie KEINEN zusätzlichen Text hinzu:
{
  "steps": [
    {
      "title": "...",
      "type": "recherchieren|reservieren|vorbereiten|hingehen|erstellen|kontaktieren",
      "durationMin": 15,
      "dueSuggestion": "today|this_week|none",
      "notes": "optionale Anmerkungen"
    }
  ]
}`
};

/**
 * Resolve the system prompt for a given Accept-Language header value.
 * Falls back to Japanese (ja) when no supported language is matched.
 * @param {string | null} acceptLang
 * @returns {string}
 */
function resolveSystemPrompt(acceptLang) {
  if (!acceptLang) return SYSTEM_PROMPTS.ja;

  // Parse "en-US,en;q=0.9,ja;q=0.8" → ["en-US", "en", "ja"]
  const tags = acceptLang.split(",").map((t) => t.split(";")[0].trim().toLowerCase());

  for (const tag of tags) {
    // Exact match first (e.g., "zh-hans")
    if (SYSTEM_PROMPTS[tag]) return SYSTEM_PROMPTS[tag];
    // Prefix match (e.g., "en-US" → "en", "zh-Hans" → "zh-Hans")
    if (tag.startsWith("zh")) return SYSTEM_PROMPTS["zh-Hans"];
    const prefix = tag.split("-")[0];
    if (SYSTEM_PROMPTS[prefix]) return SYSTEM_PROMPTS[prefix];
  }

  return SYSTEM_PROMPTS.ja;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function jsonResponse(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

function errorResponse(message, status, extraHeaders = {}) {
  return jsonResponse({ error: message }, status, extraHeaders);
}

/**
 * Build the user prompt from the request body.
 * @param {{ goalTitle: string, goalNote?: string, category?: string, constraints?: string }} body
 * @returns {string}
 */
function buildUserPrompt(body) {
  let prompt = `Goal: ${body.goalTitle}`;
  if (body.goalNote) prompt += `\nNote: ${body.goalNote}`;
  if (body.category) prompt += `\nCategory: ${body.category}`;
  if (body.constraints) prompt += `\nConstraints: ${body.constraints}`;
  return prompt;
}

/**
 * Call the OpenAI Chat Completions API and return parsed JSON.
 * @param {string} userPrompt
 * @param {string} apiKey
 * @param {string} model
 * @returns {Promise<object>}
 */
async function callOpenAI(userPrompt, apiKey, model, systemPrompt) {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.7,
      max_tokens: 1500,
      response_format: { type: "json_object" },
    }),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`OpenAI API error ${res.status}: ${text}`);
  }

  const data = await res.json();
  const content = data.choices?.[0]?.message?.content;

  if (!content) {
    throw new Error("OpenAI returned empty content");
  }

  return JSON.parse(content);
}

/**
 * Validate and sanitize the AI response to match the expected schema.
 * @param {object} raw
 * @returns {{ steps: Array }}
 */
function validateResponse(raw) {
  if (!raw || !Array.isArray(raw.steps) || raw.steps.length === 0) {
    throw new Error("Invalid AI response: missing or empty steps array");
  }

  const validTypes = new Set(["調べる", "予約する", "用意する", "行く", "作る", "連絡する"]);
  const validDurations = new Set([15, 30, 60, 120]);
  const validDue = new Set(["today", "this_week", "none"]);

  const steps = raw.steps.slice(0, 8).map((s) => ({
    title: String(s.title || "").slice(0, 200),
    type: validTypes.has(s.type) ? s.type : "調べる",
    durationMin: validDurations.has(s.durationMin) ? s.durationMin : 30,
    dueSuggestion: validDue.has(s.dueSuggestion) ? s.dueSuggestion : "none",
    notes: s.notes ? String(s.notes).slice(0, 500) : null,
  }));

  if (steps.length < 3) {
    throw new Error("AI returned fewer than 3 steps");
  }

  return { steps };
}

// ---------------------------------------------------------------------------
// Request handler
// ---------------------------------------------------------------------------

export default {
  /**
   * @param {Request} request
   * @param {{ OPENAI_API_KEY: string, API_AUTH_TOKEN: string, OPENAI_MODEL: string, MAX_INPUT_LENGTH: string, RATE_LIMIT_PER_MINUTE: string }} env
   */
  async fetch(request, env) {
    // --- CORS preflight ---
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
          "Access-Control-Max-Age": "86400",
        },
      });
    }

    // --- Route: POST /generate-steps ---
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/generate-steps") {
      return errorResponse("Not Found. Use POST /generate-steps", 404);
    }

    // --- Bearer token authentication ---
    if (env.API_AUTH_TOKEN) {
      const authHeader = request.headers.get("Authorization") || "";
      const token = authHeader.startsWith("Bearer ")
        ? authHeader.slice(7)
        : "";
      if (token !== env.API_AUTH_TOKEN) {
        return errorResponse("Unauthorized", 401);
      }
    }

    // --- API key check ---
    if (!env.OPENAI_API_KEY) {
      return errorResponse("Server misconfigured: OPENAI_API_KEY not set", 500);
    }

    // --- Rate limit ---
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const rateLimit = parseInt(env.RATE_LIMIT_PER_MINUTE || "10", 10);
    const { allowed, retryAfter } = checkRateLimit(ip, rateLimit, 60_000);

    if (!allowed) {
      return errorResponse(
        "Rate limit exceeded. Try again later.",
        429,
        { "Retry-After": String(retryAfter) }
      );
    }

    // --- Parse body ---
    let body;
    try {
      body = await request.json();
    } catch {
      return errorResponse("Invalid JSON body", 400);
    }

    // --- Validate input ---
    if (!body.goalTitle || typeof body.goalTitle !== "string") {
      return errorResponse("goalTitle is required and must be a string", 400);
    }

    const maxLen = parseInt(env.MAX_INPUT_LENGTH || "2000", 10);
    const totalLen =
      (body.goalTitle || "").length +
      (body.goalNote || "").length +
      (body.category || "").length +
      (body.constraints || "").length;

    if (totalLen > maxLen) {
      return errorResponse(
        `Input too long (${totalLen} chars). Maximum is ${maxLen} chars.`,
        400
      );
    }

    // --- Call OpenAI via proxy ---
    try {
      const userPrompt = buildUserPrompt(body);
      const model = env.OPENAI_MODEL || "gpt-4o-mini";
      const acceptLang = request.headers.get("Accept-Language");
      const systemPrompt = resolveSystemPrompt(acceptLang);
      const raw = await callOpenAI(userPrompt, env.OPENAI_API_KEY, model, systemPrompt);
      const result = validateResponse(raw);

      return jsonResponse(result);
    } catch (err) {
      console.error("AI generation failed:", err.message);

      // Pass through OpenAI rate limit (check status code in error message)
      const statusMatch = err.message.match(/OpenAI API error (\d+)/);
      if (statusMatch && statusMatch[1] === "429") {
        return errorResponse("AI provider rate limited. Try again later.", 429, {
          "Retry-After": "30",
        });
      }

      return errorResponse("AI generation failed. Please try again.", 500);
    }
  },
};

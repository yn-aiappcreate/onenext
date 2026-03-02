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
// System prompt
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT = `あなたはタスク分解アシスタントです。
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
}`;

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
  if (body.goalNote) prompt += `\nメモ: ${body.goalNote}`;
  if (body.category) prompt += `\nカテゴリ: ${body.category}`;
  if (body.constraints) prompt += `\n制約: ${body.constraints}`;
  return prompt;
}

/**
 * Call the OpenAI Chat Completions API and return parsed JSON.
 * @param {string} userPrompt
 * @param {string} apiKey
 * @param {string} model
 * @returns {Promise<object>}
 */
async function callOpenAI(userPrompt, apiKey, model) {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
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
      const raw = await callOpenAI(userPrompt, env.OPENAI_API_KEY, model);
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

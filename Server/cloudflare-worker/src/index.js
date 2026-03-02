/**
 * ツギイチ AI Proxy — Cloudflare Worker (M12: Server-side verification hardening)
 *
 * POST /generate-steps
 *   入力: { goalTitle, goalNote?, category?, constraints? }
 *   出力: { steps: [...], remaining: number }
 *
 * Headers (iOS → Proxy):
 *   X-Client-Id:              端末固有ID（必須）
 *   X-Is-Pro:                 "true" | "false"（Pro申告、フォールバック用）
 *   X-Purchased-Credits:      number（端末側の購入パック残数）
 *   X-Signed-Transaction:     Apple StoreKit 2 JWS（サーバ検証用、M12）
 *
 * Pro verification (M12):
 *   X-Signed-Transaction ヘッダーがある場合、Apple署名のJWSを暗号検証し、
 *   有効なProサブスクリプションかどうかをサーバ側で判定する。
 *   ヘッダーが無い場合は X-Is-Pro にフォールバック（後方互換）。
 *
 * Credit limits (30-day rolling window, KV-persisted):
 *   Free: 10/30days,  daily cap 10/day,  burst 5/min
 *   Pro:  300/30days, daily cap 50/day,  burst 5/min
 *
 * 秘密鍵 OPENAI_API_KEY は wrangler secret で設定する（コードに埋め込まない）。
 * 認証トークン API_AUTH_TOKEN も wrangler secret で設定する。
 */

import { importX509, compactVerify } from "jose";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const ONE_MINUTE_MS = 60 * 1000;

const LIMITS = {
  free: { monthly: 10, daily: 10, perMinute: 5 },
  pro:  { monthly: 300, daily: 50, perMinute: 5 },
};

// ---------------------------------------------------------------------------
// Apple Root CA G3 — SHA-256 fingerprint (hex, lowercase)
// Certificate: https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
// Valid until: 2039-04-30
// ---------------------------------------------------------------------------
const APPLE_ROOT_CA_G3_FINGERPRINT =
  "63343abfb89a6a03ebb57e9b3f5fa7be7c4fbe29f2d6d0867aaf3386ee76e358";

// Cache: verified Pro status per clientId (in-memory, per isolate)
// Avoids re-verifying JWS on every request within the same isolate lifetime.
const proVerifiedCache = new Map(); // key: clientId, value: { isPro, expiresAt, verifiedAt }
const PRO_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// ---------------------------------------------------------------------------
// In-memory per-minute rate limiter (per clientId, resets each minute)
// ---------------------------------------------------------------------------

const perMinuteMap = new Map(); // key: clientId, value: { count, resetAt }

/**
 * @param {string} key
 * @param {number} limit
 * @returns {{ allowed: boolean, retryAfter: number | null }}
 */
function checkPerMinuteLimit(key, limit) {
  const now = Date.now();
  let entry = perMinuteMap.get(key);

  if (!entry || now >= entry.resetAt) {
    entry = { count: 0, resetAt: now + ONE_MINUTE_MS };
    perMinuteMap.set(key, entry);
  }

  entry.count += 1;

  if (entry.count > limit) {
    const retryAfter = Math.ceil((entry.resetAt - now) / 1000);
    return { allowed: false, retryAfter };
  }

  return { allowed: true, retryAfter: null };
}

// ---------------------------------------------------------------------------
// Apple JWS verification (M12: server-side Pro hardening)
// ---------------------------------------------------------------------------

/**
 * Compute SHA-256 hex fingerprint of raw DER bytes.
 * @param {ArrayBuffer} derBytes
 * @returns {Promise<string>}
 */
async function sha256Hex(derBytes) {
  const hash = await crypto.subtle.digest("SHA-256", derBytes);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Decode a standard base64 string to ArrayBuffer.
 * @param {string} b64
 * @returns {ArrayBuffer}
 */
function base64ToArrayBuffer(b64) {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * Decode a base64url string to string.
 * @param {string} b64url
 * @returns {string}
 */
function base64UrlDecodeStr(b64url) {
  const b64 = b64url.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  return atob(padded);
}

/**
 * Verify an Apple StoreKit 2 signed transaction (JWS/JWT).
 *
 * Steps:
 * 1. Parse the JWS header to extract `alg` and `x5c` certificate chain.
 * 2. Verify the root certificate in x5c matches Apple Root CA G3 (SHA-256 fingerprint).
 * 3. Import the leaf certificate's public key via `jose.importX509`.
 * 4. Verify the JWS signature using `jose.compactVerify`.
 * 5. Decode and return the transaction payload.
 *
 * @param {string} jwsString - The compact JWS string from StoreKit 2
 * @param {string} expectedBundleId - The app's bundle ID to validate against
 * @returns {Promise<{ verified: boolean, payload?: object, error?: string }>}
 */
async function verifyAppleTransaction(jwsString, expectedBundleId) {
  try {
    // 1. Parse header
    const parts = jwsString.split(".");
    if (parts.length !== 3) {
      return { verified: false, error: "Invalid JWS format" };
    }

    const headerJson = JSON.parse(base64UrlDecodeStr(parts[0]));
    const { alg, x5c } = headerJson;

    if (alg !== "ES256") {
      return { verified: false, error: `Unsupported algorithm: ${alg}` };
    }
    if (!Array.isArray(x5c) || x5c.length < 2) {
      return { verified: false, error: "Missing or invalid x5c certificate chain" };
    }

    // 2. Verify root certificate matches Apple Root CA G3
    const rootCertBase64 = x5c[x5c.length - 1];
    const rootCertDer = base64ToArrayBuffer(rootCertBase64);
    const rootFingerprint = await sha256Hex(rootCertDer);

    if (rootFingerprint !== APPLE_ROOT_CA_G3_FINGERPRINT) {
      return { verified: false, error: "Root certificate does not match Apple Root CA G3" };
    }

    // 3. Import leaf certificate public key
    const leafCertBase64 = x5c[0];
    const leafPem =
      "-----BEGIN CERTIFICATE-----\n" +
      leafCertBase64.match(/.{1,64}/g).join("\n") +
      "\n-----END CERTIFICATE-----";

    const publicKey = await importX509(leafPem, "ES256");

    // 4. Verify JWS signature
    const { payload: payloadBytes } = await compactVerify(jwsString, publicKey);

    // 5. Decode payload
    const payload = JSON.parse(new TextDecoder().decode(payloadBytes));

    // 6. Validate bundle ID
    if (expectedBundleId && payload.bundleId !== expectedBundleId) {
      return {
        verified: false,
        error: `Bundle ID mismatch: expected ${expectedBundleId}, got ${payload.bundleId}`,
      };
    }

    return { verified: true, payload };
  } catch (err) {
    return { verified: false, error: `JWS verification failed: ${err.message}` };
  }
}

/**
 * Check if the verified transaction payload represents an active Pro subscription.
 * @param {object} payload - Decoded Apple transaction payload
 * @param {string} proProductId - The expected Pro subscription product ID
 * @returns {{ isPro: boolean, expiresAt: number | null }}
 */
function checkProStatus(payload, proProductId) {
  if (!payload) return { isPro: false, expiresAt: null };

  // Check product ID matches
  if (payload.productId !== proProductId) {
    return { isPro: false, expiresAt: null };
  }

  // Check not revoked
  if (payload.revocationDate) {
    return { isPro: false, expiresAt: null };
  }

  // Check expiration (expiresDate is in milliseconds since epoch)
  const now = Date.now();
  const expiresAt = payload.expiresDate || 0;
  if (expiresAt > 0 && expiresAt <= now) {
    return { isPro: false, expiresAt };
  }

  return { isPro: true, expiresAt: expiresAt || null };
}

/**
 * Determine Pro status for a request.
 * Priority: X-Signed-Transaction (server-verified) > cached verification > X-Is-Pro (fallback)
 *
 * @param {Request} request
 * @param {string} clientId
 * @param {{ BUNDLE_ID?: string, PRO_PRODUCT_ID?: string }} env
 * @returns {Promise<{ isPro: boolean, verificationMethod: string }>}
 */
async function determineProStatus(request, clientId, env) {
  const signedTransaction = (request.headers.get("X-Signed-Transaction") || "").trim();
  const bundleId = env.BUNDLE_ID || "";
  const proProductId = env.PRO_PRODUCT_ID || "tsugiichi.pro.monthly";

  // 1. Try server-side JWS verification
  if (signedTransaction) {
    const { verified, payload, error } = await verifyAppleTransaction(
      signedTransaction,
      bundleId
    );

    if (verified && payload) {
      const status = checkProStatus(payload, proProductId);

      // Cache the result
      proVerifiedCache.set(clientId, {
        isPro: status.isPro,
        expiresAt: status.expiresAt,
        verifiedAt: Date.now(),
      });

      return {
        isPro: status.isPro,
        verificationMethod: status.isPro ? "apple_jws_verified" : "apple_jws_expired",
      };
    }

    // Verification failed — log but fall through to cache/fallback
    console.warn("Apple JWS verification failed:", error);
  }

  // 2. Check in-memory cache (valid for PRO_CACHE_TTL_MS)
  const cached = proVerifiedCache.get(clientId);
  if (cached && Date.now() - cached.verifiedAt < PRO_CACHE_TTL_MS) {
    // If cached expiry is known and has passed, invalidate
    if (cached.expiresAt && cached.expiresAt <= Date.now()) {
      proVerifiedCache.delete(clientId);
    } else {
      return {
        isPro: cached.isPro,
        verificationMethod: "cache",
      };
    }
  }

  // 3. Fallback to X-Is-Pro header (backward compatibility for older app versions)
  const isProHeader = request.headers.get("X-Is-Pro") === "true";
  return {
    isPro: isProHeader,
    verificationMethod: "header_fallback",
  };
}

// ---------------------------------------------------------------------------
// KV-based credit tracking (clientId-keyed)
// ---------------------------------------------------------------------------

/**
 * KV value schema (JSON):
 * {
 *   monthlyUsed: number,
 *   windowStart: number (epoch ms),
 *   dailyUsed: number,
 *   dailyStart: number (epoch ms),
 *   isPro: boolean,
 *   purchasedCredits: number
 * }
 */

/**
 * Load client record from KV. Returns defaults if not found.
 * @param {KVNamespace} kv
 * @param {string} clientId
 * @returns {Promise<object>}
 */
async function loadClientRecord(kv, clientId) {
  const raw = await kv.get(`client:${clientId}`);
  if (!raw) {
    return {
      monthlyUsed: 0,
      windowStart: Date.now(),
      dailyUsed: 0,
      dailyStart: Date.now(),
      isPro: false,
      purchasedCredits: 0,
    };
  }
  return JSON.parse(raw);
}

/**
 * Save client record to KV with 60-day TTL.
 * @param {KVNamespace} kv
 * @param {string} clientId
 * @param {object} record
 */
async function saveClientRecord(kv, clientId, record) {
  await kv.put(`client:${clientId}`, JSON.stringify(record), {
    expirationTtl: 60 * 24 * 60 * 60, // 60 days
  });
}

/**
 * Roll the 30-day window if expired.
 * @param {object} record
 * @returns {object} updated record
 */
function rollMonthlyWindow(record) {
  const now = Date.now();
  if (now - record.windowStart >= THIRTY_DAYS_MS) {
    record.monthlyUsed = 0;
    record.windowStart = now;
  }
  return record;
}

/**
 * Roll the daily window if expired.
 * @param {object} record
 * @returns {object} updated record
 */
function rollDailyWindow(record) {
  const now = Date.now();
  if (now - record.dailyStart >= ONE_DAY_MS) {
    record.dailyUsed = 0;
    record.dailyStart = now;
  }
  return record;
}

/**
 * Calculate remaining credits for a client.
 * @param {object} record
 * @param {boolean} isPro
 * @returns {number}
 */
function calcRemaining(record, isPro) {
  const limits = isPro ? LIMITS.pro : LIMITS.free;
  const monthlyRemaining = Math.max(0, limits.monthly - record.monthlyUsed);
  return monthlyRemaining + (record.purchasedCredits || 0);
}

/**
 * Try to consume one credit. Returns { ok, remaining, reason? }.
 * @param {object} record
 * @param {boolean} isPro
 * @returns {{ ok: boolean, remaining: number, reason?: string }}
 */
function consumeCredit(record, isPro) {
  const limits = isPro ? LIMITS.pro : LIMITS.free;

  // Roll windows
  rollMonthlyWindow(record);
  rollDailyWindow(record);

  // Check daily cap
  if (record.dailyUsed >= limits.daily) {
    return { ok: false, remaining: calcRemaining(record, isPro), reason: "daily_limit" };
  }

  // Try monthly quota first
  if (record.monthlyUsed < limits.monthly) {
    record.monthlyUsed += 1;
    record.dailyUsed += 1;
    return { ok: true, remaining: calcRemaining(record, isPro) };
  }

  // Try purchased credits
  if ((record.purchasedCredits || 0) > 0) {
    record.purchasedCredits -= 1;
    record.dailyUsed += 1;
    return { ok: true, remaining: calcRemaining(record, isPro) };
  }

  // No credits
  return { ok: false, remaining: 0, reason: "credits_exhausted" };
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
   * @param {{ OPENAI_API_KEY: string, API_AUTH_TOKEN: string, OPENAI_MODEL: string, MAX_INPUT_LENGTH: string, CREDITS_KV: KVNamespace, BUNDLE_ID: string, PRO_PRODUCT_ID: string }} env
   */
  async fetch(request, env) {
    // --- CORS preflight ---
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Id, X-Is-Pro, X-Purchased-Credits, X-Signed-Transaction",
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

    // --- Require X-Client-Id ---
    const clientId = (request.headers.get("X-Client-Id") || "").trim();
    if (!clientId) {
      return errorResponse("X-Client-Id header is required", 400);
    }

    // --- Determine Pro status (M12: server-side verification) ---
    const { isPro, verificationMethod } = await determineProStatus(request, clientId, env);

    const purchasedCreditsFromDevice = Math.max(
      0,
      parseInt(request.headers.get("X-Purchased-Credits") || "0", 10) || 0
    );

    // --- Per-minute burst limit (in-memory) ---
    const limits = isPro ? LIMITS.pro : LIMITS.free;
    const { allowed: minuteOk, retryAfter: minuteRetry } = checkPerMinuteLimit(
      clientId,
      limits.perMinute
    );
    if (!minuteOk) {
      return errorResponse(
        "Rate limit exceeded (per-minute). Try again later.",
        429,
        { "Retry-After": String(minuteRetry) }
      );
    }

    // --- IP-based fallback rate limit (anti-abuse) ---
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const ipBurstLimit = parseInt(env.RATE_LIMIT_PER_MINUTE || "10", 10);
    const { allowed: ipOk, retryAfter: ipRetry } = checkPerMinuteLimit(
      `ip:${ip}`,
      ipBurstLimit
    );
    if (!ipOk) {
      return errorResponse(
        "Rate limit exceeded. Try again later.",
        429,
        { "Retry-After": String(ipRetry) }
      );
    }

    // --- KV credit check ---
    let record;
    let creditResult;
    if (env.CREDITS_KV) {
      record = await loadClientRecord(env.CREDITS_KV, clientId);

      // Sync isPro (now server-verified when JWS present) and purchasedCredits
      record.isPro = isPro;
      record.verificationMethod = verificationMethod;
      // Only increase purchasedCredits from device (never decrease server-side)
      if (purchasedCreditsFromDevice > (record.purchasedCredits || 0)) {
        record.purchasedCredits = purchasedCreditsFromDevice;
      }

      creditResult = consumeCredit(record, isPro);

      if (!creditResult.ok) {
        // Save updated windows even on failure
        await saveClientRecord(env.CREDITS_KV, clientId, record);
        if (creditResult.reason === "daily_limit") {
          return errorResponse(
            "Daily usage limit reached. Try again tomorrow.",
            429,
            { "Retry-After": "3600" }
          );
        }
        return jsonResponse(
          { error: "Credits exhausted", remaining: 0 },
          403
        );
      }
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

      // Save consumed credit to KV
      const remaining = creditResult ? creditResult.remaining : null;
      if (env.CREDITS_KV && record) {
        await saveClientRecord(env.CREDITS_KV, clientId, record);
      }

      // Include remaining and verification method in response
      return jsonResponse({ ...result, remaining, verificationMethod });
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

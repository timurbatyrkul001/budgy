/**
 * Budgy Cloud Functions.
 *
 * `aiCall` — Anthropic Messages API'sine sunucu taraflı vekil.
 *
 * Neden burada: Anthropic anahtarı istemciye gömülürse IPA/APK'dan çıkarılıp
 * hesabımızla sınırsız istek atılabilir. Anahtar yalnız Secret Manager'da
 * durur (ANTHROPIC_API_KEY), kodda/repoda yazılı değildir; model ve token
 * tavanı sunucuda sabittir; her başarılı çağrı kullanıcı başına aylık
 * sayaca işlenir (bkz. usage.ts, limits.ts).
 *
 * İstemci sözleşmesi (callable data):
 *   {
 *     op:      'scan' | 'parse' | 'advice',
 *     content: [{ type:'text', text } | { type:'image', source:{type:'base64', media_type, data} }],
 *     tool:    { name, description, input_schema }
 *   }
 * Dönüş: { input: <tool_use.input>, used: number, limit: number }
 *
 * Hata kodları:
 *   unauthenticated     — giriş yapılmamış
 *   invalid-argument    — sözleşmeye uymayan istek
 *   resource-exhausted  — bu ayki hak bitti (details: {op, limit, used, resetsAt})
 *   unavailable         — Anthropic'e ulaşılamadı / aşırı yük / hız sınırı
 *   internal            — beklenmeyen hata
 */
import Anthropic from "@anthropic-ai/sdk";
import { createHash } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/https";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";

import {
  AiOp,
  IMAGE_MEDIA_TYPES,
  INPUT_LIMITS,
  MODEL,
  OP_CONFIG,
  isAiOp,
} from "./limits";
import { refundUsage, reserveUsage } from "./usage";

initializeApp();

/**
 * Anthropic API anahtarı. Değeri Secret Manager'da:
 *   firebase functions:secrets:set ANTHROPIC_API_KEY
 * Koda ya da .env dosyasına asla yazılmaz.
 */
const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

/** İstemci tarafındaki FirebaseFunctions.instanceFor(region:) ile aynı olmalı. */
export const REGION = "europe-west1";

/** İstemcinin gönderdiği araç tanımı; Anthropic'in `Tool` tipine eşlenir. */
interface ToolSpec {
  name: string;
  description: string;
  input_schema: Anthropic.Tool.InputSchema;
}

interface AiCallRequest {
  op: AiOp;
  content: Anthropic.ContentBlockParam[];
  tool: ToolSpec;
}

interface AiCallResponse {
  input: Record<string, unknown>;
  used: number;
  limit: number;
}

export const aiCall = onCall<unknown, Promise<AiCallResponse>>(
  {
    region: REGION,
    secrets: [anthropicApiKey],
    timeoutSeconds: 60,
    memory: "256MiB",
    // Maliyet emniyeti: ani bir kötüye kullanımda fonksiyon sınırsız
    // ölçeklenmesin. Gerçek trafik büyüyünce yükselt.
    maxInstances: 10,
    // App Check zorlaması konsoldan açılınca burayı true yap; şimdilik
    // kapalı, çünkü debug/simülatör derlemeleri token üretemeyebiliyor.
    enforceAppCheck: false,
  },
  async (request) => {
    // 1) Kimlik: yalnız giriş yapmış kullanıcı (anonim dahil).
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Giriş yapılmamış.");
    }

    // 2) Girdi doğrulama — model/max_tokens istemciden ASLA alınmaz.
    const req = parseRequest(request.data);
    const config = OP_CONFIG[req.op];
    const db = getFirestore();
    const now = new Date();

    // 3) Hakkı ayır (transaction; sınır dolduysa resource-exhausted).
    const used = await reserveUsage(db, uid, req.op, now);

    // 4) Anthropic çağrısı.
    const client = new Anthropic({
      apiKey: anthropicApiKey.value(),
      timeout: 45_000,
      maxRetries: 1,
    });

    try {
      const response = await client.messages.create({
        model: MODEL,
        max_tokens: config.maxTokens,
        tools: [req.tool],
        // Zorunlu araç: yapılandırılmış çıktı garantisi; Haiku 4.5 destekler.
        tool_choice: { type: "tool", name: req.tool.name },
        messages: [{ role: "user", content: req.content }],
        // Kötüye kullanım analizinde Anthropic tarafında kullanıcıyı ayırt
        // eder; ham uid göndermemek için tek yönlü özet.
        metadata: { user_id: createHash("sha256").update(uid).digest("hex") },
      });

      const toolUse = response.content.find(
        (b): b is Anthropic.ToolUseBlock => b.type === "tool_use",
      );
      if (!toolUse) {
        logger.warn("aiCall: tool_use bloğu yok", {
          op: req.op,
          stopReason: response.stop_reason,
        });
        throw new HttpsError("internal", "Model yapılandırılmış yanıt üretmedi.");
      }

      logger.info("aiCall ok", {
        op: req.op,
        used,
        limit: config.monthlyLimit,
        inputTokens: response.usage.input_tokens,
        outputTokens: response.usage.output_tokens,
      });

      return {
        input: toolUse.input as Record<string, unknown>,
        used,
        limit: config.monthlyLimit,
      };
    } catch (err) {
      // Başarısız çağrı hak yakmasın.
      await refundUsage(db, uid, req.op, now);
      throw mapError(err, req.op);
    }
  },
);

// ── girdi doğrulama ────────────────────────────────────────────────────

function parseRequest(data: unknown): AiCallRequest {
  if (!isRecord(data)) {
    throw new HttpsError("invalid-argument", "İstek gövdesi nesne olmalı.");
  }
  if (!isAiOp(data.op)) {
    throw new HttpsError("invalid-argument", "Geçersiz işlem türü (op).");
  }
  return {
    op: data.op,
    content: parseContent(data.content),
    tool: parseTool(data.tool),
  };
}

function parseContent(value: unknown): Anthropic.ContentBlockParam[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new HttpsError("invalid-argument", "content boş olamaz.");
  }
  if (value.length > INPUT_LIMITS.maxBlocks) {
    throw new HttpsError("invalid-argument", "content çok fazla blok içeriyor.");
  }
  return value.map((block): Anthropic.ContentBlockParam => {
    if (!isRecord(block)) {
      throw new HttpsError("invalid-argument", "content bloğu nesne olmalı.");
    }
    if (block.type === "text") {
      const text = block.text;
      if (typeof text !== "string" || text.length === 0) {
        throw new HttpsError("invalid-argument", "text bloğu boş.");
      }
      if (text.length > INPUT_LIMITS.maxTextChars) {
        throw new HttpsError("invalid-argument", "text bloğu çok uzun.");
      }
      return { type: "text", text };
    }
    if (block.type === "image") {
      const source = block.source;
      if (!isRecord(source) || source.type !== "base64") {
        throw new HttpsError("invalid-argument", "image yalnız base64 olabilir.");
      }
      const mediaType = source.media_type;
      if (!isImageMediaType(mediaType)) {
        throw new HttpsError("invalid-argument", "Desteklenmeyen görsel türü.");
      }
      const dataB64 = source.data;
      if (typeof dataB64 !== "string" || dataB64.length === 0) {
        throw new HttpsError("invalid-argument", "Görsel verisi boş.");
      }
      if (dataB64.length > INPUT_LIMITS.maxImageBase64Chars) {
        throw new HttpsError("invalid-argument", "Görsel çok büyük.");
      }
      return {
        type: "image",
        source: { type: "base64", media_type: mediaType, data: dataB64 },
      };
    }
    // Yalnız text/image geçer: document, tool_result vb. sunucuda anlamsız
    // ve maliyet kaçağı olurdu.
    throw new HttpsError("invalid-argument", "Desteklenmeyen içerik bloğu.");
  });
}

function parseTool(value: unknown): ToolSpec {
  if (!isRecord(value)) {
    throw new HttpsError("invalid-argument", "tool nesne olmalı.");
  }
  const { name, description, input_schema: schema } = value;
  if (typeof name !== "string" || !/^[a-zA-Z0-9_-]{1,64}$/.test(name)) {
    throw new HttpsError("invalid-argument", "Geçersiz araç adı.");
  }
  if (
    typeof description !== "string" ||
    description.length === 0 ||
    description.length > INPUT_LIMITS.maxToolDescriptionChars
  ) {
    throw new HttpsError("invalid-argument", "Geçersiz araç açıklaması.");
  }
  if (!isRecord(schema) || schema.type !== "object") {
    throw new HttpsError("invalid-argument", "input_schema 'object' tipinde olmalı.");
  }
  if (JSON.stringify(schema).length > INPUT_LIMITS.maxToolSchemaChars) {
    throw new HttpsError("invalid-argument", "input_schema çok büyük.");
  }
  return {
    name,
    description,
    input_schema: schema as Anthropic.Tool.InputSchema,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isImageMediaType(value: unknown): value is (typeof IMAGE_MEDIA_TYPES)[number] {
  return typeof value === "string" && (IMAGE_MEDIA_TYPES as readonly string[]).includes(value);
}

// ── hata eşleme ────────────────────────────────────────────────────────

/**
 * Anthropic/ağ hatalarını istemcinin ayırt edebileceği callable kodlarına
 * çevirir. Anahtar/istek hataları (401/400) istemciye "internal" olarak
 * döner — ayrıntı loglanır, kullanıcıya sızdırılmaz.
 */
function mapError(err: unknown, op: AiOp): HttpsError {
  if (err instanceof HttpsError) return err;

  if (err instanceof Anthropic.RateLimitError) {
    logger.warn("aiCall: Anthropic hız sınırı", { op });
    return new HttpsError("unavailable", "AI şu an meşgul, biraz sonra dene.");
  }
  if (err instanceof Anthropic.APIConnectionError) {
    logger.warn("aiCall: Anthropic'e bağlanılamadı", { op, message: err.message });
    return new HttpsError("unavailable", "AI servisine ulaşılamadı.");
  }
  if (err instanceof Anthropic.APIError) {
    const status = err.status ?? 0;
    logger.error("aiCall: Anthropic API hatası", { op, status, type: err.type });
    if (status >= 500 || status === 529) {
      return new HttpsError("unavailable", "AI servisi geçici olarak kapalı.");
    }
    return new HttpsError("internal", "AI isteği işlenemedi.");
  }

  logger.error("aiCall: beklenmeyen hata", { op, err: String(err) });
  return new HttpsError("internal", "Beklenmeyen hata.");
}

/**
 * AI maliyet kontrolünün TEK yönetim noktası.
 *
 * Model, çıktı tavanı ve aylık kullanım sınırları burada sabitlenir;
 * istemci bunların hiçbirini seçemez (seçebilseydi sayaçların anlamı
 * kalmazdı). Sınırları değiştirmek için yalnız bu dosyayı düzenleyip
 * fonksiyonu yeniden yayınlamak yeterli.
 *
 * Ölçülen birim maliyetler (claude-haiku-4-5, girdi $1/1M, çıktı $5/1M):
 *   scan   ≈ 0,19 ₺  (1600px fiş görseli ~2000 token + istem)
 *   parse  ≈ 0,08 ₺  (sesli/metin giriş)
 *   advice ≈ 0,08 ₺  (bütçe önerisi inceltme)
 * Yıllık abonelikten aya düşen net gelir ≈ 40 ₺. Aşağıdaki tavanlar
 * en kötü durumda kullanıcı başına ≈ 19 + 24 + 2,4 ≈ 45 ₺'de durur.
 */

/** İstemcinin gönderebildiği işlem türleri; sayaç alanı adıyla aynı. */
export const AI_OPS = ["scan", "parse", "advice"] as const;
export type AiOp = (typeof AI_OPS)[number];

export function isAiOp(value: unknown): value is AiOp {
  return typeof value === "string" && (AI_OPS as readonly string[]).includes(value);
}

/** Tüm işlemler için sabit model. Sunucu belirler, istemci değiştiremez. */
export const MODEL = "claude-haiku-4-5";

/** İşlem türü başına aylık sınır ve çıktı token tavanı. */
export const OP_CONFIG: Record<AiOp, { monthlyLimit: number; maxTokens: number }> = {
  // Fiş tarama: en pahalı işlem, en düşük tavan.
  scan: { monthlyLimit: 100, maxTokens: 1024 },
  // Serbest metin / sesli giriş → işlem listesi.
  parse: { monthlyLimit: 300, maxTokens: 1024 },
  // Bütçe önerisi inceltme.
  advice: { monthlyLimit: 30, maxTokens: 1024 },
};

/** Girdi doğrulama tavanları — istemci hatası ya da kötüye kullanım filtresi. */
export const INPUT_LIMITS = {
  /** Bir istekte en fazla kaç içerik bloğu (text/image). */
  maxBlocks: 4,
  /** Tek bir metin bloğunun karakter sınırı. */
  maxTextChars: 8_000,
  /** Base64 görsel verisi için üst sınır (~3 MB ham görsel). */
  maxImageBase64Chars: 4_000_000,
  /** Araç açıklaması karakter sınırı. */
  maxToolDescriptionChars: 500,
  /** Araç şeması JSON metni karakter sınırı. */
  maxToolSchemaChars: 20_000,
} as const;

/** Anthropic'in kabul ettiği görsel türleri. */
export const IMAGE_MEDIA_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"] as const;

/**
 * Kullanıcı başına aylık AI kullanım sayaçları.
 *
 * Belge yolu: users/{uid}/usage/{yyyy-MM}
 * Alanlar:    { scan: number, parse: number, advice: number, updatedAt }
 *
 * İstemci bu belgeyi yalnız OKUR (bkz. firestore.rules). Yazma sadece
 * buradan, Admin SDK ile yapılır.
 *
 * DİKKAT — atomiklik: oku-karşılaştır-artır her zaman TEK transaction
 * içinde. Bu projede daha önce `setDay` atomik olmadığı için bir tutar iki
 * kez sayıldı; aynı hata burada "sınırı iki paralel istekle aşmak" olarak
 * tekrar ederdi. Transaction, iki eşzamanlı isteğin aynı eski değeri okuyup
 * ikisinin de geçmesini engeller.
 */
import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";

import { AiOp, OP_CONFIG } from "./limits";

/** Sayaç belgesinin kimliği: UTC'ye göre "yyyy-MM". */
export function monthKey(now: Date = new Date()): string {
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${y}-${m}`;
}

/** Sayacın sıfırlanacağı an: bir sonraki ayın ilk günü 00:00 UTC. */
export function monthResetsAt(now: Date = new Date()): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
}

function usageRef(db: Firestore, uid: string, now: Date) {
  return db.collection("users").doc(uid).collection("usage").doc(monthKey(now));
}

/**
 * Hakkı transaction içinde ayırır: sayacı okur, sınırı aşıyorsa
 * `resource-exhausted` fırlatır, aşmıyorsa +1 yazar.
 *
 * Artırım Anthropic çağrısından ÖNCE yapılır (rezervasyon); çağrı
 * başarısız olursa [refundUsage] geri alır. Böylece "başarılı çağrı başına
 * +1" kuralı korunurken paralel isteklerle sınırın delinmesi de önlenir.
 *
 * Döner: bu istek dahil kullanılan sayı.
 */
export async function reserveUsage(
  db: Firestore,
  uid: string,
  op: AiOp,
  now: Date = new Date(),
): Promise<number> {
  const limit = OP_CONFIG[op].monthlyLimit;
  const ref = usageRef(db, uid, now);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = readCount(snap.data()?.[op]);

    if (used >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        `Aylık ${op} sınırı doldu (${limit}).`,
        {
          op,
          limit,
          used,
          resetsAt: monthResetsAt(now).toISOString(),
        },
      );
    }

    // set+merge: belge ilk kez bu ay oluşuyorsa diğer alanlar eksik kalabilir,
    // okuyan taraf eksik alanı 0 sayar.
    tx.set(
      ref,
      {
        [op]: used + 1,
        updatedAt: FieldValue.serverTimestamp(),
        // Ay içinde ilk yazımda oluşur; sonraki merge'ler dokunmaz.
        ...(snap.exists ? {} : { createdAt: Timestamp.fromDate(now) }),
      },
      { merge: true },
    );
    return used + 1;
  });
}

/**
 * Anthropic çağrısı başarısız olduğunda rezervasyonu geri alır.
 * Sayaç asla 0'ın altına inmez. Hata olursa yutulur — kullanıcının bir
 * hakkının fazladan gitmesi, isteğin ikinci kez patlamasından iyidir.
 */
export async function refundUsage(
  db: Firestore,
  uid: string,
  op: AiOp,
  now: Date = new Date(),
): Promise<void> {
  const ref = usageRef(db, uid, now);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const used = readCount(snap.data()?.[op]);
      if (used <= 0) return;
      tx.set(ref, { [op]: used - 1, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    });
  } catch {
    // bilinçli olarak sessiz
  }
}

function readCount(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0 ? Math.floor(value) : 0;
}

/**
 * Hesap silindiğinde arkada hiçbir şey kalmasın.
 *
 * SORUN: "Hesabımı sil" dendiğinde istemci `users/{uid}` altındaki yedi alt
 * koleksiyonu ve `settings`'i tek tek siliyor (bkz. `deleteAccountData`),
 * sonra `user.delete()` çağırıyor. Ama iki koleksiyonu SİLEMEZ:
 *
 *   users/{uid}/usage/*         — aylık AI sayaçları
 *   users/{uid}/entitlements/*  — abonelik hakkı
 *
 * Güvenlik kurallarında ikisi de `allow write: if false` — bilerek: sayacı
 * ya da Pro hakkını istemci değiştirebilseydi ikisi de anlamsız olurdu.
 * Sonuç: hesap gidiyor, bu belgeler uid'e bağlı öksüz olarak kalıyor.
 *
 * Apple "hesabı ve verisini sil" şartı koyuyor ve kendi yayın listemizde de
 * "users/{uid} altında hiçbir şey kalmamalı" yazıyor. Kalıyordu.
 *
 * ÇÖZÜM: Auth tarafında kullanıcı silinince tetiklenen bu fonksiyon,
 * `users/{uid}` ağacının TAMAMINI özyinelemeli siler. İstemcinin yaptığı
 * silmeyi değiştirmedik — bu onun üstüne bir güvenlik ağı:
 *   • istemci ağ koptuğu için yarıda kaldıysa,
 *   • ileride yeni bir alt koleksiyon eklenip buraya yazılmayı unuttuysak,
 *   • ya da hesap konsoldan silindiyse
 * veri yine de gider.
 *
 * NEDEN 1. NESİL (v1): Auth'un `onDelete` tetikleyicisi yalnız 1. nesilde
 * var. 2. nesilde kullanıcı silme olayı için bir karşılığı yok (oradaki
 * "blocking" fonksiyonlar oluşturma/giriş öncesi çalışıyor). Aynı kod
 * tabanında iki nesil yan yana durabiliyor; `aiCall` 2. nesil kalıyor.
 */
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import * as functionsV1 from "firebase-functions/v1";

import { REGION } from "./region";

export const onUserDeleted = functionsV1
  .region(REGION)
  .auth.user()
  .onDelete(async (user) => {
    const db = getFirestore();
    const root = db.doc(`users/${user.uid}`);
    try {
      // recursiveDelete alt koleksiyonları da gezer — tek tek saymaya
      // gerek yok, bu yüzden yarın yeni bir koleksiyon eklendiğinde burayı
      // güncellemeyi unutmak mümkün değil.
      await db.recursiveDelete(root);
      logger.info("hesap verisi silindi", { uid: user.uid });
    } catch (error) {
      // Yutmuyoruz: silinemeyen veri sessiz kalmamalı, raporda görünmeli.
      logger.error("hesap verisi silinemedi", { uid: user.uid, error });
      throw error;
    }
  });

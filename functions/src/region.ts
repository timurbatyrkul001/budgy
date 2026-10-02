/**
 * Fonksiyonların çalıştığı bölge.
 *
 * Kendi dosyasında, çünkü hem `index.ts` hem `account.ts` okuyor: ikisinden
 * birine koyunca dairesel içe aktarma oluşuyordu (index → account → index).
 * Bugün sırası tesadüfen doğru çalışsa da, dosyaların yeri değişince sessizce
 * `undefined` olabilirdi.
 *
 * İstemci tarafındaki karşılığı: `lib/core/ai/claude_client.dart` → `region`.
 * İkisi AYNI olmalı, yoksa çağrı 404 döner.
 */
export const REGION = "europe-west1";

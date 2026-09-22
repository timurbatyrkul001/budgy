/**
 * firestore.rules doğrulama testleri.
 *
 * Kurallar sıkılaştırıldığında uygulamanın GERÇEKTEN yaptığı yazmaların
 * hâlâ geçtiğini kanıtlar. Bir koleksiyonu kural dosyasında unutmak
 * (örn. reminders) özelliği sessizce tamamen kırar — bu testler o hatayı
 * canlıya çıkmadan yakalar.
 *
 * Çalıştırma:  npm run emu   (kök dizinden: bkz. README)
 */
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, updateDoc, getDoc, deleteDoc,
  collection, addDoc, Timestamp,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const ME = 'user-me';
const OTHER = 'user-other';

let testEnv;
let results = [];

async function check(name, promise) {
  try {
    await promise;
    results.push(['PASS', name]);
  } catch (e) {
    results.push(['FAIL', `${name} — ${e.message}`]);
  }
}

testEnv = await initializeTestEnvironment({
  projectId: 'budgy-rules-test',
  firestore: {
    rules: readFileSync('../firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

await testEnv.clearFirestore();

const me = testEnv.authenticatedContext(ME).firestore();
const other = testEnv.authenticatedContext(OTHER).firestore();
const anon = testEnv.unauthenticatedContext().firestore();

const envPath = (uid, id) => doc(me, `users/${uid}/envelopes/${id}`);

// ── izolasyon ────────────────────────────────────────────────────────
await check('başka kullanıcının zarfı okunamaz', assertFails(
  getDoc(doc(other, `users/${ME}/envelopes/e1`))));

await check('başka kullanıcının zarfına yazılamaz', assertFails(
  setDoc(doc(other, `users/${ME}/envelopes/e1`),
    { name: 'Hack', emoji: '💀', balance: 0, sortOrder: 0 })));

await check('oturumsuz erişim reddedilir', assertFails(
  getDoc(doc(anon, `users/${ME}/envelopes/e1`))));

// ── zarflar: uygulamanın gerçek yazmaları ────────────────────────────
await check('zarf oluşturma (addEnvelope)', assertSucceeds(
  setDoc(envPath(ME, 'e1'), {
    name: 'Yemek', emoji: '🍔', balance: 0, sortOrder: 0, currency: 'TRY',
  })));

await check('zarf güncelleme (updateEnvelope)', assertSucceeds(
  updateDoc(envPath(ME, 'e1'), { name: 'Market', emoji: '🛒' })));

await check('hedef temizleme (setTarget null)', assertSucceeds(
  updateDoc(envPath(ME, 'e1'), { targetAmount: null })));

await check('hedef atama (setTarget)', assertSucceeds(
  updateDoc(envPath(ME, 'e1'), { targetAmount: 1500 })));

await check('arşivleme (setArchived)', assertSucceeds(
  updateDoc(envPath(ME, 'e1'), { archived: true })));

await check('boş isimli zarf reddedilir', assertFails(
  setDoc(envPath(ME, 'bad'), {
    name: '', emoji: '🍔', balance: 0, sortOrder: 0,
  })));

await check('bakiyesi metin olan zarf reddedilir', assertFails(
  setDoc(envPath(ME, 'bad2'), {
    name: 'Yemek', emoji: '🍔', balance: 'çok', sortOrder: 0,
  })));

// ── işlemler ─────────────────────────────────────────────────────────
const txs = collection(me, `users/${ME}/transactions`);

await check('gider yazma (addExpense)', assertSucceeds(
  addDoc(txs, {
    type: 'expense', amount: 120, date: Timestamp.now(),
    envelopeId: 'e1', envelopeIds: ['e1'], currency: 'TRY',
  })));

await check('dağıtımlı gelir yazma (addIncome)', assertSucceeds(
  addDoc(txs, {
    type: 'income', amount: 1000, date: Timestamp.now(),
    allocations: { e1: 1000 }, envelopeIds: ['e1'],
  })));

await check('transfer yazma', assertSucceeds(
  addDoc(txs, {
    type: 'transfer', amount: 300, date: Timestamp.now(),
    envelopeIds: ['e1', 'e2'], currency: 'TRY',
  })));

await check('hedef fonu yazma (fundGoal)', assertSucceeds(
  addDoc(txs, {
    type: 'expense', amount: 250, date: Timestamp.now(),
    envelopeIds: [], free: true, allocated: false,
    currency: 'TRY', goalFund: true, goalId: 'g1',
  })));

await check('negatif tutar reddedilir', assertFails(
  addDoc(txs, { type: 'expense', amount: -5, date: Timestamp.now() })));

await check('sıfır tutar reddedilir', assertFails(
  addDoc(txs, { type: 'expense', amount: 0, date: Timestamp.now() })));

await check('bilinmeyen tür reddedilir', assertFails(
  addDoc(txs, { type: 'steal', amount: 10, date: Timestamp.now() })));

// allocated işaretleme (addIncome batch'i bunu yapıyor)
const freeTx = doc(me, `users/${ME}/transactions/free1`);
await setDoc(freeTx, {
  type: 'income', amount: 500, date: Timestamp.now(),
  envelopeIds: [], free: true, allocated: false,
});
await check('allocated işaretleme geçer', assertSucceeds(
  updateDoc(freeTx, { allocated: true })));

// İşlem düzenleme (updateTx) geldiğinden beri tutar değiştirilebilir —
// eskiden işlemler değiştirilemezdi. Koruma kalktı değil, yer değiştirdi:
// yeni değerler de oluşturma kurallarının aynısından geçiyor.
await check('işlem düzenleme geçer (updateTx)', assertSucceeds(
  updateDoc(freeTx, {
    type: 'income', amount: 750, date: Timestamp.now(),
  })));

await check('düzenlemede negatif tutar reddedilir', assertFails(
  updateDoc(freeTx, {
    type: 'income', amount: -5, date: Timestamp.now(),
  })));

await check('düzenlemede bilinmeyen tür reddedilir', assertFails(
  updateDoc(freeTx, {
    type: 'hack', amount: 10, date: Timestamp.now(),
  })));

await check('işlem silme geçer (deleteTx)', assertSucceeds(
  deleteDoc(freeTx)));

// ── cüzdan hesapları (accounts) ──────────────────────────────────────
// Bu blok kural dosyasında yokken çalışma günü kaydetmek, harcama ve
// gelir girmek sessizce başarısız oluyordu: batch atomik olduğu için
// cüzdan yazması reddedilince gün/işlem belgesi de geri alınıyordu.
await check('cüzdan bakiyesi yazma (_cashDelta)', assertSucceeds(
  setDoc(doc(me, `users/${ME}/accounts/cash`), { balance: 6995 })));

await check('cüzdan bakiyesi okuma (watchCashBalance)', assertSucceeds(
  getDoc(doc(me, `users/${ME}/accounts/cash`))));

// Kasa eksiye düşebilir — validAmount kullanılamaz.
await check('negatif bakiye geçer', assertSucceeds(
  setDoc(doc(me, `users/${ME}/accounts/cash`), { balance: -250 })));

await check('bakiyesi metin olan hesap reddedilir', assertFails(
  setDoc(doc(me, `users/${ME}/accounts/cash`), { balance: 'çok' })));

// "Hesabımı sil" (deleteAccountData) bu belgeleri de temizliyor.
await check('cüzdan silme geçer (deleteAccountData)', assertSucceeds(
  deleteDoc(doc(me, `users/${ME}/accounts/cash`))));

await check('başkasının cüzdanı okunamaz', assertFails(
  getDoc(doc(other, `users/${ME}/accounts/cash`))));

await check('başkasının cüzdanına yazılamaz', assertFails(
  setDoc(doc(other, `users/${ME}/accounts/cash`), { balance: 999999 })));

// ── diğer koleksiyonlar ──────────────────────────────────────────────
await check('çalışma günü yazma', assertSucceeds(
  setDoc(doc(me, `users/${ME}/workDays/2026-08-01`),
    { month: '2026-08', amount: 500 })));

await check('hatırlatıcı yazma (reminders kuralda var mı?)', assertSucceeds(
  addDoc(collection(me, `users/${ME}/reminders`),
    { name: 'Kira', amount: 15000, fromDay: 1, toDay: 5 })));

await check('ayarlar yazma', assertSucceeds(
  setDoc(doc(me, `users/${ME}/settings/main`),
    { currency: 'TRY', language: 'tr', onboardingDone: true })));

// ── tekrarlayan işlem kuralları (recurring) ──────────────────────────
// Kural yayınlanmadığı sürece uygulamada "tekrar" seçip kaydetmek hata
// verir; bu testler koleksiyonun kural dosyasında kalmasını garanti eder.
const recurring = collection(me, `users/${ME}/recurring`);

await check('tekrar kuralı yazma (addRecurringRule)', assertSucceeds(
  addDoc(recurring, {
    amount: 15000, type: 'expense', currency: 'TRY',
    freq: 'monthly', nextDate: Timestamp.now(), anchorDay: 5,
    envelopeId: 'e1', envelopeName: 'Kira', createdAt: Timestamp.now(),
  })));

await check('gelir tipinde tekrar kuralı yazma', assertSucceeds(
  addDoc(recurring, {
    amount: 44000, type: 'income', currency: 'TRY',
    freq: 'monthly', nextDate: Timestamp.now(), anchorDay: 1,
  })));

await check('geçersiz tipte tekrar kuralı reddedilir', assertFails(
  addDoc(recurring, {
    amount: 100, type: 'transfer', currency: 'TRY',
    freq: 'monthly', nextDate: Timestamp.now(),
  })));

await check('negatif tutarlı tekrar kuralı reddedilir', assertFails(
  addDoc(recurring, {
    amount: -50, type: 'expense', currency: 'TRY',
    freq: 'monthly', nextDate: Timestamp.now(),
  })));

await check('nextDate zaman damgası değilse reddedilir', assertFails(
  addDoc(recurring, {
    amount: 100, type: 'expense', currency: 'TRY',
    freq: 'monthly', nextDate: '2026-10-01',
  })));

const myRule = doc(me, `users/${ME}/recurring/r1`);
await setDoc(myRule, {
  amount: 200, type: 'expense', currency: 'TRY',
  freq: 'weekly', nextDate: Timestamp.now(),
});

await check('tekrar kuralı ilerletme (materializeRecurring)', assertSucceeds(
  updateDoc(myRule, { nextDate: Timestamp.now(), amount: 200,
    type: 'expense' })));

await check('tekrar kuralı silme', assertSucceeds(deleteDoc(myRule)));

await check('başkasının tekrar kuralı okunamaz', assertFails(
  getDoc(doc(other, `users/${ME}/recurring/r1`))));

await check('başkasının tekrar kuralına yazılamaz', assertFails(
  setDoc(doc(other, `users/${ME}/recurring/hack`), {
    amount: 1, type: 'expense', currency: 'TRY',
    freq: 'daily', nextDate: Timestamp.now(),
  })));

// ── kategori otomasyonu kuralları (rules) ────────────────────────────
const userRules = collection(me, `users/${ME}/rules`);

await check('otomasyon kuralı yazma (addUserRule)', assertSucceeds(
  addDoc(userRules, {
    keyword: 'migros', envelopeId: 'e1', createdAt: Timestamp.now(),
  })));

await check('boş anahtar kelime reddedilir', assertFails(
  addDoc(userRules, { keyword: '', envelopeId: 'e1' })));

await check('60 karakteri aşan anahtar kelime reddedilir', assertFails(
  addDoc(userRules, { keyword: 'x'.repeat(61), envelopeId: 'e1' })));

await check('envelopeId metin değilse reddedilir', assertFails(
  addDoc(userRules, { keyword: 'shell', envelopeId: 42 })));

const myKeyword = doc(me, `users/${ME}/rules/k1`);
await setDoc(myKeyword, { keyword: 'bim', envelopeId: 'e1' });

await check('otomasyon kuralı güncelleme', assertSucceeds(
  updateDoc(myKeyword, { keyword: 'bim market', envelopeId: 'e1' })));

await check('otomasyon kuralı silme', assertSucceeds(deleteDoc(myKeyword)));

await check('başkasının otomasyon kuralı okunamaz', assertFails(
  getDoc(doc(other, `users/${ME}/rules/k1`))));

await check('başkasının otomasyon kuralına yazılamaz', assertFails(
  setDoc(doc(other, `users/${ME}/rules/hack`),
    { keyword: 'hack', envelopeId: 'e1' })));

// Kapalı yerleşik kurallar settings/automation içinde tutuluyor.
await check('kapalı yerleşik kurallar yazma', assertSucceeds(
  setDoc(doc(me, `users/${ME}/settings/automation`),
    { disabled: ['groceries:a101', 'fuel:shell'] })));

await testEnv.cleanup();

// ── rapor ────────────────────────────────────────────────────────────
const failed = results.filter(([s]) => s === 'FAIL');
for (const [status, name] of results) {
  console.log(`${status === 'PASS' ? '  ✓' : '  ✗'} ${name}`);
}
console.log(`\n${results.length - failed.length}/${results.length} geçti`);
process.exit(failed.length === 0 ? 0 : 1);

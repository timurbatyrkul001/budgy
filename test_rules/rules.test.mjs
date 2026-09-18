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

await check('kayıtlı işlemin tutarı sonradan değiştirilemez', assertFails(
  updateDoc(freeTx, { amount: 99999 })));

await check('işlem silme geçer (deleteTx)', assertSucceeds(
  deleteDoc(freeTx)));

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

await testEnv.cleanup();

// ── rapor ────────────────────────────────────────────────────────────
const failed = results.filter(([s]) => s === 'FAIL');
for (const [status, name] of results) {
  console.log(`${status === 'PASS' ? '  ✓' : '  ✗'} ${name}`);
}
console.log(`\n${results.length - failed.length}/${results.length} geçti`);
process.exit(failed.length === 0 ? 0 : 1);

/// Budgy kategori kataloğu — hızlı girişteki "Kategori seç" sayfasının
/// hazır seçenekleri. Kategoriler zarftır (bütçe/istatistik/AI envelopeId
/// okur): katalogdan seçilen madde ilk kullanımda `preset: key` ile zarf
/// olarak yaratılır; ad [displayName] üzerinden dilden gelir.
///
/// Marka adı/logo yok — genel maddeler ve emoji.
class CatalogItem {
  const CatalogItem(this.key, this.emoji, this.en, this.tr, this.ru);

  final String key;
  final String emoji;
  final String en;
  final String tr;
  final String ru;

  String name(String localeCode) => switch (localeCode) {
        'tr' => tr,
        'ru' => ru,
        _ => en,
      };
}

class CatalogSection {
  const CatalogSection(this.key, this.en, this.tr, this.ru, this.items);

  final String key;
  final String en;
  final String tr;
  final String ru;
  final List<CatalogItem> items;

  String title(String localeCode) => switch (localeCode) {
        'tr' => tr,
        'ru' => ru,
        _ => en,
      };
}

/// Anahtarlar onboarding preset'leriyle (rent, gifts, education, travel,
/// clothes, other) kasıtlı olarak ortak — aynı anlamdaki zarf iki kez
/// oluşmasın.
const kCategoryCatalog = <CatalogSection>[
  CatalogSection('everyday', 'Everyday', 'Günlük', 'Каждый день', [
    CatalogItem('groceries', '🛒', 'Groceries', 'Market', 'Продукты'),
    CatalogItem('restaurants', '🍽️', 'Restaurants', 'Restoran', 'Рестораны'),
    CatalogItem('delivery', '🛵', 'Delivery', 'Paket servis', 'Доставка'),
    CatalogItem('coffee', '☕', 'Coffee', 'Kahve', 'Кофе'),
  ]),
  CatalogSection('transport', 'Transport', 'Ulaşım', 'Транспорт', [
    CatalogItem('publicTransport', '🚌', 'Public transport', 'Toplu taşıma',
        'Общественный транспорт'),
    CatalogItem('fuel', '⛽', 'Fuel', 'Yakıt', 'Топливо'),
    CatalogItem('taxi', '🚕', 'Taxi', 'Taksi', 'Такси'),
    CatalogItem('car', '🚗', 'Car', 'Araba', 'Автомобиль'),
  ]),
  CatalogSection('living', 'Home & bills', 'Ev & faturalar', 'Дом и счета', [
    CatalogItem('rent', '🏠', 'Rent', 'Kira', 'Аренда'),
    CatalogItem('utilities', '💡', 'Utilities', 'Faturalar', 'Коммуналка'),
    CatalogItem('internet', '📶', 'Internet & phone', 'İnternet & telefon',
        'Интернет и связь'),
    CatalogItem('home', '🛋️', 'Home', 'Ev eşyası', 'Для дома'),
  ]),
  CatalogSection('shopping', 'Shopping', 'Alışveriş', 'Покупки', [
    CatalogItem('clothes', '👕', 'Clothing', 'Giyim', 'Одежда'),
    CatalogItem('electronics', '💻', 'Electronics', 'Elektronik', 'Техника'),
    CatalogItem('online', '📦', 'Online shopping', 'Online alışveriş',
        'Онлайн-покупки'),
    CatalogItem('personalCare', '🧴', 'Personal care', 'Kişisel bakım',
        'Уход за собой'),
  ]),
  CatalogSection('lifestyle', 'Lifestyle', 'Yaşam', 'Досуг', [
    CatalogItem('entertainment', '🎬', 'Entertainment', 'Eğlence',
        'Развлечения'),
    CatalogItem('travel', '✈️', 'Travel', 'Seyahat', 'Путешествия'),
    CatalogItem('hobbies', '🎨', 'Hobbies', 'Hobiler', 'Хобби'),
    CatalogItem('sport', '🏋️', 'Sport', 'Spor', 'Спорт'),
  ]),
  CatalogSection('health', 'Health', 'Sağlık', 'Здоровье', [
    CatalogItem('pharmacy', '💊', 'Pharmacy', 'Eczane', 'Аптека'),
    CatalogItem('doctor', '🩺', 'Doctor', 'Doktor', 'Врач'),
  ]),
  CatalogSection('finance', 'Finance', 'Finans', 'Финансы', [
    CatalogItem('bankFees', '🏦', 'Bank fees', 'Banka ücretleri',
        'Комиссии банка'),
    CatalogItem('insurance', '🛡️', 'Insurance', 'Sigorta', 'Страховка'),
    CatalogItem('taxes', '🧾', 'Taxes', 'Vergiler', 'Налоги'),
    CatalogItem('loans', '💳', 'Loans', 'Krediler', 'Кредиты'),
  ]),
  CatalogSection('family', 'Family & other', 'Aile & diğer', 'Семья и прочее', [
    CatalogItem('gifts', '🎁', 'Gifts', 'Hediyeler', 'Подарки'),
    CatalogItem('donations', '🤝', 'Donations', 'Bağış', 'Пожертвования'),
    CatalogItem('education', '📚', 'Education', 'Eğitim', 'Образование'),
    CatalogItem('pets', '🐾', 'Pets', 'Evcil hayvan', 'Питомцы'),
    CatalogItem('kids', '🧸', 'Kids', 'Çocuk', 'Дети'),
    CatalogItem('other', '🗂️', 'Other', 'Diğer', 'Другое'),
  ]),
  CatalogSection('subscriptions', 'Subscriptions', 'Abonelikler', 'Подписки', [
    CatalogItem('streaming', '📺', 'Streaming', 'Dizi & film', 'Стриминг'),
    CatalogItem('music', '🎧', 'Music', 'Müzik', 'Музыка'),
    CatalogItem('cloud', '☁️', 'Cloud storage', 'Bulut depolama',
        'Облако'),
    CatalogItem('games', '🎮', 'Games', 'Oyun', 'Игры'),
    CatalogItem('software', '🧩', 'Software', 'Yazılım', 'Программы'),
    CatalogItem('otherSubs', '🔁', 'Other subscriptions', 'Diğer abonelikler',
        'Другие подписки'),
  ]),
];

/// Anahtar → katalog maddesi (yoksa null).
CatalogItem? catalogItem(String key) {
  for (final s in kCategoryCatalog) {
    for (final i in s.items) {
      if (i.key == key) return i;
    }
  }
  return null;
}

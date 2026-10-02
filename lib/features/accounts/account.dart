import 'package:cloud_firestore/cloud_firestore.dart';

/// Hesap türü — görünümü ve sıralamayı belirler, mantığı değil.
enum AccountKind {
  /// Banka kartı: Enpara, Azeri kart... Kart görselinde gösterilir.
  card,

  /// Nakit: cüzdandaki para.
  cash,

  /// Banka hesabı / IBAN, kartı olmayan.
  bank,
}

/// Paranın DURDUĞU yer. Kategoriden (`Envelope`) bilinçli olarak ayrı:
///
/// * hesap = para nereden çıktı  (Enpara ₺, Azeri kart ₼, Nakit ₺)
/// * kategori = ne için harcandı (market, kira, kahve)
///
/// Eskiden ikisi tek şeye biniyordu: döviz "cüzdanı" aslında `currency`
/// alanı dolu bir zarftı ve harcama analizinden dışlanıyordu — yani kumbara
/// gibi davranıyordu, kart gibi değil. Türkiye'de maaş alıp Azerbaycan
/// kartından manat harcayan birinin ikisini birlikte görebilmesi için bu
/// ayrım şart.
///
/// Firestore: `users/{uid}/accounts/{id}`. `cash` kimliği özeldir ve
/// geriye dönük uyumluluk için korunur — eski kod oraya doğrudan yazıyor.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.currency,
    required this.kind,
    required this.balance,
    this.emoji = '',
    this.colorIndex,
    this.last4,
    this.sortOrder = 0,
    this.archived = false,
    this.cardStyle,
    this.accentColor,
  });

  final String id;
  final String name;

  /// Hesabın kendi para birimi. İşlemler bu birimde kaydedilir.
  ///
  /// Nakit ([cashId]) için bu alan TANIM GEREĞİ kullanıcının ana para
  /// birimidir (`settings/main.currency`): cüzdandaki para hiçbir zaman
  /// çevrilmez. Belgede ne yazarsa yazsın (eski göç `'TRY'` yazıyordu, bu
  /// "ana birim" anlamında bir yer tutucuydu — bkz. `Tx.legacyMainCode`)
  /// okuyan taraf [withMainCurrency] ile ana birime çeker. Tenge seçmiş bir
  /// kullanıcının nakit harcaması ₺ sanılıp çapraz kurla ×13 yazılmasın.
  final String currency;

  final AccountKind kind;

  /// Kendi para biriminde bakiye.
  final double balance;

  final String emoji;

  /// Kart görselinin rengi (`Ex.spaceColors` indeksi); null ise türden türer.
  final int? colorIndex;

  /// Kartın son dört hanesi — yalnız görünüm için, doğrulamada kullanılmaz.
  final String? last4;

  final int sortOrder;
  final bool archived;

  /// Kartın görünüm varyantı (`flat` / `metal` / `ribbon` / `split`).
  ///
  /// Banka kataloğundaki varsayılan yalnız bir TAHMİN: "Ziraat kartı" diye
  /// tek bir tasarım yok (Bankkart, Combo, World, Başak...). Kullanıcı
  /// cebindeki karta en yakınını kendisi seçebilsin diye burada saklanıyor;
  /// null ise bankanın varsayılanı kullanılır.
  ///
  /// Tip olarak `String` tutuluyor, enum değil: model katalogdan bağımsız
  /// kalsın ve ileride yeni bir stil eklenince eski kayıtlar okunmaya devam
  /// etsin (tanınmayan değer → varsayılana düşer).
  final String? cardStyle;

  /// Kullanıcının seçtiği vurgu rengi (ARGB); null ise markanınki.
  final int? accentColor;

  /// Nakit hesabının sabit kimliği. Eski sürümlerde tek kasa buydu; yeni
  /// hesaplar yanına eklenir, bu belge asla silinmez.
  static const cashId = 'cash';

  bool get isCash => id == cashId;

  /// Nakit ise birimi [mainCurrency] olan kopya; kartlar olduğu gibi.
  ///
  /// Kural TEK yerde (burada) ve okuma anında uygulanır, belge
  /// değiştirilmez: ana birim sonradan değişse de nakit kendiliğinden
  /// onu izler, eski `accounts/cash` belgelerine göç gerekmez.
  Account withMainCurrency(String mainCurrency) =>
      isCash && currency != mainCurrency
          ? copyWith(currency: mainCurrency)
          : this;

  factory Account.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Account(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      // Eski `accounts/cash` belgesinde yalnız `balance` var; kalan alanlar
      // okunurken varsayılana düşer, yazma gerektirmez. Nakit için bu
      // varsayılan da belgedeki değer de son söz değil — bkz.
      // [withMainCurrency]; kartlar birimi her zaman kendileri taşır.
      currency: (d['currency'] as String?) ?? 'TRY',
      kind: AccountKind.values.firstWhere(
        (k) => k.name == d['kind'],
        orElse: () => doc.id == cashId ? AccountKind.cash : AccountKind.card,
      ),
      balance: (d['balance'] as num?)?.toDouble() ?? 0,
      emoji: (d['emoji'] as String?) ?? '',
      colorIndex: (d['colorIndex'] as num?)?.toInt(),
      last4: d['last4'] as String?,
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
      archived: d['archived'] == true,
      cardStyle: d['cardStyle'] as String?,
      accentColor: (d['accentColor'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'currency': currency,
        'kind': kind.name,
        'balance': balance,
        'emoji': emoji,
        if (colorIndex != null) 'colorIndex': colorIndex,
        if (last4 != null) 'last4': last4,
        'sortOrder': sortOrder,
        'archived': archived,
        if (cardStyle != null) 'cardStyle': cardStyle,
        if (accentColor != null) 'accentColor': accentColor,
      };

  Account copyWith({
    String? name,
    String? currency,
    AccountKind? kind,
    double? balance,
    String? emoji,
    int? colorIndex,
    String? last4,
    int? sortOrder,
    bool? archived,
    String? cardStyle,
    int? accentColor,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        kind: kind ?? this.kind,
        balance: balance ?? this.balance,
        emoji: emoji ?? this.emoji,
        colorIndex: colorIndex ?? this.colorIndex,
        last4: last4 ?? this.last4,
        sortOrder: sortOrder ?? this.sortOrder,
        archived: archived ?? this.archived,
        cardStyle: cardStyle ?? this.cardStyle,
        accentColor: accentColor ?? this.accentColor,
      );
}

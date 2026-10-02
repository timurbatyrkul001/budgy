# Budgy — разбор проекта для собеседования

Справочник по собственному коду: что используется, как устроено и что
отвечать, когда спросят. Всё написано по реальным файлам проекта —
пути и выдержки настоящие.

**Состояние на момент написания:** 2 октября 2026, коммит `27a6d8a`,
`flutter test` → 806 пройдено, 7 пропущено.

## Содержание

1. [Обзор, зависимости, бэкенд и авторизация](#часть-1)
2. [Состояние, архитектура, модели, хранение, навигация](#часть-2)
3. [Темы, анимации, локализация, тесты, платформа](#часть-3)
4. [Путь данных: от кнопки до экрана](#часть-4)
5. [Чего нет, но про это спросят](#часть-5)
6. [Шпаргалка: вопросы и ответы](#часть-6)

> **Как пользоваться.** Части 1–3 — справочные, читать по мере надобности.
> Часть 4 стоит прочитать целиком: она связывает всё вместе на одном
> сценарии. Части 5 и 6 — перед самим собеседованием.

---

<a id="часть-1"></a>

# 01 — Стек, бэкенд и авторизация

> Справочник по проекту Budgy (`/Users/timurbatyrkul/Projects/kopilka_app`).
> Всё ниже основано на реальном коде; каждое утверждение сопровождается путём к файлу.
> Пакет в `pubspec.yaml` называется `kopilka_app`, корневой виджет — `KopilkaApp`:
> «Kopilka» (копилка) — рабочее имя, «Budgy» — название продукта.

---

## 1. Обзор проекта

### 1.1 Что это за приложение

Budgy — Flutter-приложение для **конвертного бюджетирования** (envelope budgeting) людей,
которые зарабатывают ежедневно (курьеры, фрилансеры, мастера). Пользователь отмечает рабочие
дни и дневной заработок, деньги попадают в «кошелёк» (наличный счёт), затем распределяются по
конвертам (аренда, продукты, накопления…); каждый расход списывается из конкретного конверта.
Главный экран показывает нераспределённые деньги и недельную «тепловую ленту» заработков
(`README.md`, раздел «Why it's different»).

Технически это Flutter + Firebase: без собственного сервера, данные живут в Cloud Firestore
под `users/{uid}/...`, авторизация — Firebase Auth (анонимная по умолчанию, с привязкой
Google / Apple / email). Есть единственная Cloud Function `aiCall` — прокси к Anthropic API для
AI-функций (скан чека, разбор текста/голоса в транзакции, советы по бюджету). Три языка
(TR / RU / EN), валюты ₺ / $ / € / ₽, виджет iOS (WidgetKit), локальные уведомления,
Crashlytics и App Check. Комментарии в коде смешанные — по-турецки и по-русски.

### 1.2 Структура `lib/`

```
lib/
├── main.dart                 # точка входа: Firebase, Crashlytics, App Check, ProviderScope
├── app.dart                  # KopilkaApp: MaterialApp, тема, локаль, AuthGate
├── firebase_options.dart     # сгенерирован FlutterFire CLI, в .gitignore
├── core/                     # общее, не привязанное к фиче
│   ├── ai/                   # claude_client.dart, expense_parser.dart, budget_advisor.dart
│   ├── fx.dart, fx_freeze.dart        # курсы валют (единственный «сырой» HTTP в проекте)
│   ├── notifications.dart, widget_service.dart
│   ├── l10n.dart, redesign_l10n.dart  # строки на 3 языках
│   ├── theme.dart, tokens.dart, ex_style.dart, palette.dart
│   ├── formatters.dart, calc.dart, csv_export.dart, feedback.dart ...
└── features/                 # feature-first: каждая папка = экран(ы) + репозиторий + модели
    ├── accounts/   (8 файлов)  auth/ (9)   automation/ (1)  budget/ (4)
    ├── categories/ (1)  converter/ (3)  envelopes/ (10)  goals/ (1)
    ├── home/ (3)  insights/ (3)  onboarding/ (11)  pro/ (3)  profile/ (7)
    ├── recurring/ (2)  reminders/ (2)  root/ (1)  savings/ (2)
    ├── settings/ (9)  space/ (2)  stats/ (2)  transactions/ (9)  workdays/ (2)
```

Принцип — **feature-first**: код группируется по функциональности, а не по типу
(не `screens/`, `models/`, `services/`). Внутри фичи лежат вместе экран, репозиторий и
модель. Примеры:

- `lib/features/envelopes/` — `envelope.dart` (модель `Envelope`), `budget_repository.dart`
  (класс `BudgetRepository` + Riverpod-провайдеры), `home_screen.dart`, `add_envelope_sheet.dart`,
  `envelope_detail_screen.dart`.
- `lib/features/workdays/` — `work_days_repository.dart` (`WorkDaysRepository`) и
  `calendar_screen.dart`.
- `lib/features/auth/` — `auth_service.dart`, `auth_gate.dart` и экраны входа/регистрации.

Особенность: `BudgetRepository` в `envelopes/` фактически центральный репозиторий проекта
(1109 строк) — он отвечает и за конверты, и за транзакции, и за настройки, и за «Pro»; другие
фичи расширяют его через `extension` (например `extension AutomationRepo on BudgetRepository` в
`lib/features/settings/app_settings.dart:76`).

### 1.3 Точка входа — `lib/main.dart` по шагам

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
```
1. `ensureInitialized()` — обязателен перед любыми платформенными вызовами до `runApp`.
2. `Firebase.initializeApp` с опциями из `lib/firebase_options.dart` (сгенерирован FlutterFire
   CLI, проект `kopilka-b75f6`, см. `firebase.json` → `flutter.platforms`). Файл в
   `.gitignore` (строка 48), т.е. в публичном репозитории его нет.

```dart
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crashlytics.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
```
3. Crashlytics включается только в release (`!kDebugMode`). Два перехватчика: ошибки
   фреймворка (build/layout/paint) и неперехваченные async-ошибки вне фреймворка.

```dart
  await _activateAppCheck();
```
4. App Check (`_activateAppCheck`, там же в `main.dart`): в debug — `AndroidDebugProvider` /
   `AppleDebugProvider`, в release — `AndroidPlayIntegrityProvider` /
   `AppleAppAttestWithDeviceCheckFallbackProvider`. Всё обёрнуто в `try/catch`, ошибка
   уходит в Crashlytics как non-fatal — приложение не падает, если App Check не настроен.

```dart
  for (final lang in AppLanguage.values) {
    await initializeDateFormatting(lang.code);
  }
```
5. Загрузка локальных данных `intl` для трёх языков (`AppLanguage` из `lib/core/l10n.dart`).

```dart
  runApp(kPreviewHome
      ? previewHomeScope(child: const KopilkaApp())
      : const ProviderScope(child: KopilkaApp()));
}
```
6. `ProviderScope` — корень Riverpod. `kPreviewHome` — debug-режим с фейковыми данными
   (`lib/features/home/preview_home.dart`), для скриншотов.

Далее `lib/app.dart` → `KopilkaApp extends ConsumerWidget` строит `MaterialApp`: тема из
`buildTheme()` / `buildDarkTheme()` (`lib/core/theme.dart`), но `themeMode: ThemeMode.light`
жёстко — тёмная тема сейчас **не включается**, хотя код и настройка остались. Локаль берётся из
`languageProvider`, а `home:` обёрнут в `KeyedSubtree(key: ValueKey('$symbol|${lang.code}'))`:
при смене валюты или языка всё дерево пересобирается, чтобы каждый `formatMoney` подхватил
новый символ. Домашний экран — `AuthGate` (см. раздел 4.4).

---

## 2. Зависимости (`pubspec.yaml`)

SDK: `sdk: ^3.11.5`. Все утверждения «где используется» проверены grep'ом по `lib/`.

### 2.1 Firebase

| Пакет | Что это | Где используется | Пример вызова |
|---|---|---|---|
| `firebase_core ^4.10.0` | Инициализация Firebase-приложения | `lib/main.dart`, `lib/firebase_options.dart`, `lib/core/ai/claude_client.dart` | `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` |
| `firebase_auth ^6.7.0` | Аутентификация (анонимная, email, Google, Apple) | 11 файлов: `lib/features/auth/*.dart`, `lib/features/settings/settings_account_screen.dart`, `lib/core/ai/claude_client.dart` | `FirebaseAuth.instance.signInAnonymously()` (`auth_gate.dart:43`); `user.linkWithCredential(cred)` (`auth_service.dart:67`) |
| `cloud_firestore ^6.5.0` | NoSQL-база, realtime-стримы | 9 файлов: `budget_repository.dart`, `work_days_repository.dart`, `accounts_repository.dart`, `reminders_repository.dart`, `app_settings.dart`, модели `tx.dart`, `account.dart`, `envelope.dart` | `_db.collection('users').doc(_uid).collection('envelopes').orderBy('sortOrder').snapshots()` (`budget_repository.dart:357`) |
| `cloud_functions ^6.5.0` | Вызов Cloud Functions (callable) | Только `lib/core/ai/claude_client.dart` | `FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('aiCall')` (`claude_client.dart:89`) |
| `firebase_crashlytics ^5.2.7` | Отчёты о падениях | `lib/main.dart`, `lib/core/feedback.dart` | `FirebaseCrashlytics.instance.recordError(error, stack, reason: reason, fatal: false)` (`feedback.dart:41`) |
| `firebase_app_check ^0.4.8` | Защита бэкенда от чужих клиентов | Только `lib/main.dart` | `FirebaseAppCheck.instance.activate(providerAndroid: ..., providerApple: ...)` |

### 2.2 Состояние

| Пакет | Что это | Где используется | Пример вызова |
|---|---|---|---|
| `flutter_riverpod ^3.3.1` | Управление состоянием / DI | 81 файл — практически везде | `final envelopesProvider = StreamProvider<List<Envelope>>((ref) => ref.watch(budgetRepositoryProvider).watchEnvelopes());` (`budget_repository.dart:21`) |
| `riverpod_annotation ^4.0.2` | Аннотации `@riverpod` для кодогенерации | **НЕ используется**: 0 импортов в `lib/`, ни одного `.g.dart` файла. Все провайдеры объявлены вручную (`Provider`, `StreamProvider`, `NotifierProvider`). | — |

### 2.3 UI

| Пакет | Что это | Где используется | Пример вызова |
|---|---|---|---|
| `flutter_localizations` (sdk) | Локализация Material/Cupertino-виджетов | `lib/app.dart` | `localizationsDelegates: const [GlobalMaterialLocalizations.delegate, ...]` |
| `flutter_animate ^4.5.2` | Декларативные анимации цепочкой | `lib/core/motion.dart`, `lib/features/onboarding/onboarding_bubbles.dart` | `.animate().fadeIn(duration: kEnterDuration, curve: kEnterCurve)` (`motion.dart:30`) |
| `intl ^0.20.2` | Форматирование чисел/дат | 21 файл; ядро — `lib/core/formatters.dart` | `NumberFormat('#,##0.##', moneyLocale)` (`formatters.dart:32`); `DateFormat('d MMMM, EEEE', str.localeCode)` |

Собственная i18n без `.arb`: строки лежат в классах `Strings` (`lib/core/l10n.dart`) и
`redesign_l10n.dart`, читаются через `ref.read(strProvider)` / `rsProvider`.

### 2.4 Платформенные плагины

| Пакет | Что это | Где используется | Пример вызова |
|---|---|---|---|
| `flutter_local_notifications ^21.0.0` | Локальные (без сервера) уведомления | `lib/core/notifications.dart`, `lib/features/onboarding/onboarding_firstday.dart` | `_plugin.initialize(settings: InitializationSettings(iOS: DarwinInitializationSettings(), android: ...))` (`notifications.dart:19`) |
| `timezone ^0.11.0` | База часовых поясов для планирования | `lib/core/notifications.dart` | `tz.TZDateTime(tz.local, year, month, day, hour)` (`notifications.dart:43`) |
| `flutter_timezone ^5.1.0` | Узнать локальный часовой пояс устройства | `lib/core/notifications.dart` | `final localTz = await FlutterTimezone.getLocalTimezone(); tz.setLocalLocation(tz.getLocation(localTz.identifier));` |
| `home_widget ^0.7.0` | Мост к iOS/Android виджету на домашнем экране | `lib/core/widget_service.dart` (класс `BudgyWidget`) | `HomeWidget.setAppGroupId('group.co.ggtech.kopilkaApp'); HomeWidget.saveWidgetData<String>('today', ...)` |
| `image_picker ^1.1.2` | Камера / галерея | `lib/features/transactions/receipt_scan.dart` | `ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80)` |
| `speech_to_text ^7.4.0` | Распознавание речи (нативное) | `lib/features/transactions/ai_add_sheet.dart`, `lib/features/settings/voice_language_screen.dart` | `final _speech = SpeechToText(); await _speech.initialize(...); await _speech.listen(...)` |
| `share_plus ^10.1.4` | Системный share-sheet | `data_management_screen.dart` (CSV), `month_summary_card.dart` (PNG), `envelope_detail_screen.dart` | `Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')])` |
| `package_info_plus ^8.3.0` | Версия/билд приложения | `lib/features/settings/settings_hub.dart` | `final info = await PackageInfo.fromPlatform();` |
| `path_provider ^2.1.5` | Пути к системным директориям | `lib/features/insights/month_summary_card.dart` | `final dir = await getTemporaryDirectory();` |
| `google_sign_in ^7.2.0` | Нативный Google-вход | `lib/features/auth/auth_service.dart` | `await GoogleSignIn.instance.initialize(); final account = await GoogleSignIn.instance.authenticate();` |

Заметка: `lib/core/fx.dart` сознательно **не** использует `path_provider` для кеша курсов —
пишет в `$HOME/Library/Caches` на iOS и `Directory.systemTemp` на остальных платформах
(«eklenti gerektirmez» — не требует плагина, `fx.dart:62-83`).

### 2.5 dev_dependencies

| Пакет | Что это | Где используется |
|---|---|---|
| `flutter_test` (sdk) | Тестовый фреймворк | `test/` — 20 файлов тестов + `test/widget/`, `test/support/` |
| `flutter_lints ^6.0.0` | Набор lint-правил | `analysis_options.yaml` |
| `fake_cloud_firestore ^4.2.0` | In-memory Firestore для тестов | `test/budget_repository_test.dart`, `test/accounts_repository_test.dart`, `test/update_tx_test.dart` (`FakeFirebaseFirestore()`) |
| `riverpod_generator ^4.0.3`, `build_runner ^2.15.0` | Кодогенерация провайдеров | **Не используются** (см. `riverpod_annotation` выше). Мёртвые зависимости. |
| `flutter_launcher_icons ^0.14.4` | Генерация иконок | Конфиг в `flutter_launcher_icons.yaml` |
| `flutter_native_splash ^2.4.4` | Нативный splash | Конфиг в `pubspec.yaml`, секция `flutter_native_splash` (цвет `#FBFAF7`) |

Отдельно от Dart-зависимостей: `test_rules/` — Node-проект (`@firebase/rules-unit-testing`,
`firebase`) для тестов `firestore.rules` на эмуляторе, запускается `tool/test_rules.sh`.

### 2.6 Расхождения с README

- README обещает «biometric (Face ID) lock» и `local_auth` в таблице стека. В `pubspec.yaml`
  пакета `local_auth` **нет**, в `pubspec.lock` тоже, в `lib/` нет ни одного вызова
  `LocalAuthentication`. Остался только `NSFaceIDUsageDescription` в `ios/Runner/Info.plist:33`.
- README обещает «email/OTP, password reset». Экраны `otp_screen.dart`,
  `forget_password_screen.dart`, `new_password_screen.dart` существуют, но в них **ноль**
  обращений к `FirebaseAuth` (проверено grep'ом) — это UI-макеты без логики. Реально работают
  только `signInWithEmailAndPassword` (`sign_in_screen.dart:70`), `linkWithCredential(EmailAuthProvider.credential(...))`
  (`sign_up_screen.dart:95-99`) и `sendEmailVerification()` (`email_verify_screen.dart:53`).
- README: «light & dark». В `app.dart` `themeMode: ThemeMode.light` — тёмная тема отключена.

---

## 3. Сеть и бэкенд

### 3.1 Чек-лист «есть / нет»

| Вопрос | Ответ | Подтверждение |
|---|---|---|
| REST API со своим сервером | **нет** | Нет ни одного base URL, кроме курсов валют |
| `dio` | **нет** | Отсутствует в `pubspec.yaml` и `pubspec.lock` |
| `http` | **нет как прямая зависимость** | В `pubspec.lock:704` `http: dependency: transitive` (тянут Firebase-плагины); в `lib/` импорта `package:http` нет |
| Interceptors / Retrofit | **нет** | grep по `Interceptor`, `Retrofit` — пусто |
| Refresh token | **нет вручную** | Firebase Auth сам обновляет ID-токен; в коде нет `refreshToken` |
| Обработка ошибок сети | **есть, точечно** | `FirebaseFunctionsException` → свои исключения в `claude_client.dart:120`; `FirebaseAuthException` → `SocialAuthFailure` (`auth_service.dart:128`); `guardWrite` в `lib/core/feedback.dart` |
| «Сырой» HTTP | **есть, одно место** | `lib/core/fx.dart:41-60` — `dart:io HttpClient` |

**Почему нет REST-слоя.** Весь обмен данными идёт через Firebase SDK: Firestore общается с
сервером по своему протоколу (gRPC/WebChannel поверх HTTPS) и сам занимается кешем, офлайном,
realtime-подпиской и переподключением; аутентификационный токен прикрепляется автоматически.
Писать поверх этого Dio с интерсепторами не нужно — нет ни эндпоинтов, ни JSON-контрактов,
ни ручного управления токенами. Cloud Functions вызываются как `httpsCallable`, где
`cloud_functions` сам добавляет заголовки `Authorization` (Firebase ID token) и App Check.

**Единственный «настоящий» HTTP** — курсы валют в `lib/core/fx.dart`:

```dart
Future<Map<String, double>?> fetchFxRates(String base) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req =
        await client.getUrl(Uri.parse('https://open.er-api.com/v6/latest/$base'));
    final resp = await req.close();
    if (resp.statusCode != 200) return null;
    final body = await resp.transform(utf8.decoder).join();
    final rates = (jsonDecode(body) as Map<String, dynamic>)['rates'];
    ...
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
```

Это публичный API без ключа, поэтому автор обошёлся `dart:io HttpClient` вместо пакета.
Поверх — `FxCache` (память + JSON-файл, свежесть 6 часов) и `loadFxSnapshot`: при отсутствии
сети отдаётся старый снимок с меткой «обновлено X назад». В `fx_freeze.dart` курс «замораживается»
в транзакции (`Tx.baseAmount`, `Tx.fxRate`) и больше не меняется.

### 3.2 Какие сервисы Firebase подключены

| Сервис | Инициализация | Где используется |
|---|---|---|
| **Core** | `main.dart` → `Firebase.initializeApp` | — |
| **Authentication** | неявно, через `FirebaseAuth.instance` | `auth_gate.dart` (поток `authStateChanges()`), `auth_service.dart`, экраны `auth/*`, `settings_account_screen.dart` |
| **Cloud Firestore** | неявно, `FirebaseFirestore.instance` в `budgetRepositoryProvider` (`budget_repository.dart:13`) | все репозитории (см. 3.3) |
| **Cloud Functions** | `FirebaseFunctions.instanceFor(region: 'europe-west1')` | только `claude_client.dart` |
| **Crashlytics** | `main.dart` (`setCrashlyticsCollectionEnabled(!kDebugMode)` + два хука) | `lib/core/feedback.dart` → `guardWrite` |
| **App Check** | `main.dart` → `_activateAppCheck()` | Обеспечивает токен для Firestore/Functions. ВАЖНО: в `functions/src/index.ts:87` `enforceAppCheck: false` — на стороне функции проверка пока выключена |
| **Messaging (FCM)** | **нет** | `firebase_messaging` отсутствует; уведомления только локальные (`flutter_local_notifications`) |
| **Storage / Analytics / Remote Config** | **нет** | Отсутствуют в `pubspec.yaml` |

Нативная сторона: Android — плагины `com.google.gms.google-services` и
`com.google.firebase.crashlytics` в `android/app/build.gradle.kts:18-19`; iOS — файл
`ios/Runner/GoogleService-Info.plist` (в `.gitignore`).

### 3.3 Структура данных в Firestore

Все данные пользователя лежат под `users/{uid}`. Полный список подколлекций, собранный по
`collection('...')` в `lib/` и по `functions/src/usage.ts`:

```
users/{uid}
├── envelopes/{envelopeId}       name, emoji, balance, sortOrder, currency, archived,
│                                targetAmount, preset, goal, section, color, createdAt
│                                (Envelope.fromDoc — lib/features/envelopes/envelope.dart:63)
├── transactions/{txId}          type ('income'|'expense'|'transfer'), amount, date (Timestamp),
│                                note, allocations{}, envelopeId, envelopeName, fromName,
│                                currency, convert, goalFund, accountId, baseAmount,
│                                baseCurrency, fxRate, groupId, free, envelopeIds[]
│                                (Tx.fromDoc — lib/features/transactions/tx.dart:107)
├── accounts/{accountId}         balance, sortOrder, archived ... ; документ 'cash' — наличный кошелёк
│                                (budget_repository.dart:216-222, accounts_repository.dart:46)
├── workDays/{yyyy-MM-dd}        month, amount   (work_days_repository.dart:55)
├── reminders/{reminderId}       name, fromDay, toDay, amount   (reminders_repository.dart:181)
├── recurring/{ruleId}           type, amount, nextDate ...   (budget_repository.dart:986)
├── rules/{ruleId}               keyword, envelopeId, envelopeName, createdAt  (app_settings.dart:77)
├── settings/main                onboardingDone, language, currency, themeMode, профиль
│   settings/automation          отключённые встроенные правила категорий
├── entitlements/pro             { pro: true } — только чтение с клиента
└── usage/{yyyy-MM}              { scan, parse, advice, updatedAt } — пишет только Cloud Function
```

Ссылки на коллекции в `BudgetRepository` — геттеры (`lib/features/envelopes/budget_repository.dart:211-222`):

```dart
CollectionReference<Map<String, dynamic>> get _envelopes =>
    _db.collection('users').doc(_uid).collection('envelopes');

DocumentReference<Map<String, dynamic>> get _cash =>
    _db.collection('users').doc(_uid).collection('accounts').doc('cash');

DocumentReference<Map<String, dynamic>> get _settings =>
    _db.collection('users').doc(_uid).collection('settings').doc('main');
```

**Чтение — через стримы `snapshots()`**, обёрнутые в `StreamProvider`:

```dart
// budget_repository.dart:357
Stream<List<Envelope>> watchEnvelopes() => _envelopes
    .orderBy('sortOrder')
    .snapshots()
    .map((snap) => snap.docs.map(Envelope.fromDoc).toList());

// budget_repository.dart:363 — диапазон дат для статистики
Stream<List<Tx>> watchTxsBetween(DateTime start, DateTime end) {
  return _txs
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('date', isLessThan: Timestamp.fromDate(end))
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Tx.fromDoc).toList());
}

// budget_repository.dart:372 — журнал одного конверта, составной индекс
return _txs
    .where('envelopeIds', arrayContains: envelopeId)
    .orderBy('date', descending: true)
    .limit(limit)
    .snapshots()
```

Для последнего запроса нужен составной индекс `envelopeIds + date DESC` — он описан в
`firestore.indexes.json`. Комментарий в коде объясняет, почему сортировка на сервере:
с `limit` клиентская сортировка не гарантирует «последние N».

**Запись — атомарными батчами.** Любая операция, затрагивающая баланс, пишет транзакцию и
инкрементирует баланс конверта/кошелька в одном `WriteBatch`:

```dart
// budget_repository.dart:226 — кошелёк
void _cashDelta(WriteBatch batch, double delta) {
  if (delta == 0) return;
  batch.set(_cash, {'balance': FieldValue.increment(delta)},
      SetOptions(merge: true));
}

// budget_repository.dart:851 — расход
Future<String> addExpense({...}) async {
  final batch = _db.batch();
  final doc = _txs.doc();
  _writeExpense(batch, doc, ...);   // batch.set(doc, {...}) + списание: с карты (accountId),
                                    // иначе с кошелька (_cashDelta) для ₺, иначе с валютного конверта
  await batch.commit();
  return doc.id;
}
```

`FieldValue.increment` вместо «прочитал-прибавил-записал» убирает гонку между устройствами;
`FieldValue.serverTimestamp()` используется для `createdAt`. Удаление аккаунта
(`deleteAccountData`, строка 509) проходит по жёстко перечисленному списку коллекций
пакетами по 400 документов — в комментарии: «если забыть коллекцию, данные останутся после
"удалить аккаунт" — нарушение правил магазина».

**Контракт с Riverpod**: `budgetRepositoryProvider` зависит от `uidProvider` (`auth_gate.dart:16`);
при смене пользователя репозиторий и все производные стримы пересоздаются автоматически.

### 3.4 Cloud Functions — `functions/`

Node 22 + TypeScript, зависимости `@anthropic-ai/sdk`, `firebase-admin`, `firebase-functions`
(`functions/package.json`). Три файла в `functions/src/`:

- `index.ts` — единственная функция `aiCall` (`onCall`, регион `europe-west1`, 60 с,
  256 MiB, `maxInstances: 10`, `enforceAppCheck: false`).
- `limits.ts` — модель `claude-haiku-4-5`, месячные лимиты (`scan: 100, parse: 300, advice: 30`),
  `maxTokens: 1024`, ограничения входа (≤4 блока, ≤8000 символов текста, ≤4 МБ base64).
- `usage.ts` — счётчики `users/{uid}/usage/{yyyy-MM}` через `runTransaction`
  (`reserveUsage` до вызова, `refundUsage` при ошибке).

**Зачем прокси.** Комментарий в `index.ts:6-10`: если ключ Anthropic вшить в приложение, его
достанут из IPA/APK и будут слать запросы за счёт владельца. Поэтому:

```ts
const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");   // Secret Manager, не в коде

export const aiCall = onCall<unknown, Promise<AiCallResponse>>(
  { region: REGION, secrets: [anthropicApiKey], timeoutSeconds: 60, maxInstances: 10, enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");
    const req = parseRequest(request.data);          // model/max_tokens клиент задать НЕ может
    const used = await reserveUsage(db, uid, req.op, now);
    const client = new Anthropic({ apiKey: anthropicApiKey.value(), timeout: 45_000, maxRetries: 1 });
    try {
      const response = await client.messages.create({
        model: MODEL, max_tokens: config.maxTokens,
        tools: [req.tool], tool_choice: { type: "tool", name: req.tool.name },
        messages: [{ role: "user", content: req.content }],
        metadata: { user_id: createHash("sha256").update(uid).digest("hex") },
      });
      ...
      return { input: toolUse.input, used, limit: config.monthlyLimit };
    } catch (err) {
      await refundUsage(db, uid, req.op, now);
      throw mapError(err, req.op);
    }
  });
```

Ключевые решения: сервер фиксирует модель и лимиты токенов; принудительный `tool_choice` даёт
структурированный JSON вместо свободного текста; `uid` в метаданные уходит как SHA-256;
ошибки Anthropic 401/400 маппятся в `internal` без деталей (не утекают клиенту).

**Как вызывается из Flutter** — `lib/core/ai/claude_client.dart`:

```dart
static Future<Map<String, dynamic>> callTool({
  required AiOp op, required List<Map<String, Object?>> content,
  required String toolName, required String toolDescription,
  required Map<String, Object?> inputSchema,
}) async {
  if (!available) throw const AiUnavailable();
  final callable = FirebaseFunctions.instanceFor(region: region)
      .httpsCallable(functionName,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)));
  try {
    final result = await callable.call<Object?>({
      'op': op.name, 'content': content,
      'tool': {'name': toolName, 'description': toolDescription, 'input_schema': inputSchema},
    });
    final data = jsonDecode(jsonEncode(result.data));   // Map<Object?,Object?> → Map<String,dynamic>
    ...
  } on FirebaseFunctionsException catch (e) {
    throw _mapError(e, op);   // resource-exhausted → AiLimitReached, unauthenticated → AiUnavailable, иначе AiNetworkError
  }
}
```

Вызывающие: `lib/core/ai/expense_parser.dart:170` (tool `record_transactions` — чек/текст/голос
→ список транзакций) и `lib/core/ai/budget_advisor.dart:19`. Трюк `jsonDecode(jsonEncode(...))`
нужен, потому что platform channel отдаёт вложенные карты как `Map<Object?, Object?>`.

### 3.5 Firestore Security Rules — `firestore.rules`

Простыми словами: **каждый пользователь видит и меняет только своё дерево `users/{uid}`,
а два документа — `entitlements` и `usage` — клиент может только читать.**

```
function isOwner(uid) { return request.auth != null && request.auth.uid == uid; }
function validAmount(value) { return value is number && value > 0 && value < 1000000000; }

match /users/{uid} {
  allow read, write: if isOwner(uid);

  match /envelopes/{envelopeId} {
    allow read, delete: if isOwner(uid);
    allow create, update: if isOwner(uid)
      && data().name is string && data().name.size() > 0 && data().name.size() <= 60
      && data().balance is number ...
  }
  match /transactions/{txId} {
    allow create, update: if isOwner(uid)
      && data().type in ['income', 'expense', 'transfer']
      && validAmount(data().amount) && data().date is timestamp;
  }
  match /accounts/{accountId}  { ... data().balance is number }   // баланс может быть отрицательным
  match /workDays/{dayId}      { allow read, write: if isOwner(uid); }
  match /reminders/..., /settings/..., /recurring/..., /rules/...
  match /entitlements/{entId}  { allow read: if isOwner(uid); allow write: if false; }
  match /usage/{docId}         { allow read: if isOwner(uid); allow write: if false; }
}
```

Что это даёт:
1. **Изоляция** — `request.auth.uid == uid`: чужие данные недоступны даже с украденным API-ключом.
2. **Валидация схемы** — сумма положительная и конечная, тип из белого списка, дата —
   `timestamp`, имя конверта 1–60 символов. Это «последняя линия обороны» от битых балансов.
3. **Серверные документы** — `entitlements/pro` (Pro-статус) и `usage/*` (AI-счётчики) нельзя
   записать с клиента, иначе любой открыл бы себе Pro или обнулил лимиты. Пишутся только через
   Admin SDK (Cloud Function / консоль), который правила обходит.

Важный урок, записанный в комментарии к `accounts` (строки 55-59) и в `DENETIM.md` §0.1:
правило `match /users/{uid}` **не наследуется** подколлекциями — каждая должна иметь свой
блок. Когда блока `accounts` не было, все записи в кошелёк молча отклонялись, и батчи
откатывались целиком. Поэтому появились тесты правил (`test_rules/rules.test.mjs`, по `DENETIM.md` — 50/50 проходят,
запуск `tool/test_rules.sh` на эмуляторе).

---

## 4. Авторизация

### 4.1 `lib/features/auth/auth_service.dart` — разбор

Класс `AuthService` — только статические методы, без состояния. Общая идея из docstring
(строки 5-7): «в обоих путях, если есть анонимный аккаунт, к нему **привязываемся** (uid не
меняется, всё созданное в онбординге остаётся); если этот identity уже принадлежит другому
аккаунту — входим в него».

**`signInWithGoogle` (строки 19-32)**

```dart
static Future<UserCredential> signInWithGoogle() async {
  await _initGoogle();                                       // GoogleSignIn.instance.initialize(), один раз
  final account = await GoogleSignIn.instance.authenticate(); // нативный экран выбора аккаунта
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw FirebaseAuthException(code: 'invalid-credential', message: 'Google kimlik jetonu gelmedi.');
  }
  return _runCredential(GoogleAuthProvider.credential(idToken: idToken));
}
```

Используется нативный `google_sign_in` 7.x (`GoogleSignIn.instance.authenticate()` — новый API
7-й версии вместо `signIn()`), а не `FirebaseAuth.signInWithProvider`. Причина описана в
комментарии (строки 11-15): federated-поток Firebase открывал Safari со страницей
`kopilka-b75f6.firebaseapp.com`, и Google показывал пользователю этот домен вместо имени
приложения. Нативный поток показывает «Budgy». ID-токен Google оборачивается в
`AuthCredential` и передаётся дальше. `_googleInit` кешируется как `Future<void>?`, чтобы
`initialize()` вызвался ровно один раз (строки 35-37).

**`signInWithApple` (строки 42-57)**

```dart
static Future<UserCredential> signInWithApple() {
  final provider = AppleAuthProvider()..addScope('email');
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user != null && user.isAnonymous) {
    return user.linkWithProvider(provider).catchError((Object e) {
      if (e is FirebaseAuthException &&
          (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use')) {
        return auth.signInWithProvider(provider);
      }
      throw e;
    });
  }
  return auth.signInWithProvider(provider);
}
```

Apple — **ещё через federated-поток Firebase** (`linkWithProvider` / `signInWithProvider`),
а не через `sign_in_with_apple`: комментарий (строки 39-41) говорит, что нативный путь требует
Services ID + ключ в Apple Developer, и это отложено. Логика та же, что в `_runCredential`,
но на `catchError`, т.к. `signInWithProvider` принимает провайдер, а не credential.
Entitlement `com.apple.developer.applesignin` есть в `ios/Runner/Runner.entitlements` —
по правилу App Store 4.8 Sign in with Apple обязателен, если есть Google-вход.

**`_runCredential` (строки 61-81) — сердце привязки**

```dart
static Future<UserCredential> _runCredential(AuthCredential cred) async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  UserCredential result;
  if (user != null && user.isAnonymous) {
    try {
      result = await user.linkWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        result = await auth.signInWithCredential(cred);
      } else {
        rethrow;
      }
    }
  } else {
    result = await auth.signInWithCredential(cred);
  }
  await _adoptProviderName(result.user);
  return result;
}
```

**`linkWithCredential` vs `signInWithCredential`:**

| | `user.linkWithCredential(cred)` | `auth.signInWithCredential(cred)` |
|---|---|---|
| Что делает | Добавляет провайдер (Google/Apple/email) к **текущему** аккаунту | Создаёт сессию для аккаунта, которому принадлежит credential (или создаёт новый) |
| uid | **Не меняется** | Меняется на uid того аккаунта |
| Данные в `users/{uid}` | Остаются | Текущий анонимный аккаунт «брошен», открывается другое дерево |
| Ошибка | `credential-already-in-use` — этот Google уже привязан к другому Firebase-аккаунту | — |

**Сценарий «анонимный → Google, uid не меняется».** Пользователь открыл приложение →
`AuthGate` вызвал `signInAnonymously()` → получил uid `A` → прошёл онбординг, создал конверты
в `users/A/envelopes`. В настройках нажал «Войти через Google». `_runCredential` видит
`user.isAnonymous == true` и делает `linkWithCredential`: Firebase записывает Google как провайдер
аккаунта `A`. uid остаётся `A`, `budgetRepositoryProvider` (зависящий от `uidProvider`) не
пересоздаётся, все данные на месте. Теперь аккаунт `A` не анонимный, и на другом устройстве
Google-вход вернёт тот же `A` — данные синхронизируются.

Если же этот Google-аккаунт уже привязан к аккаунту `B` (например, человек переустановил
приложение и получил новый анонимный `A'`), `linkWithCredential` бросит
`credential-already-in-use`. Тогда код падает в `signInWithCredential` — вход в `B`, uid
меняется на `B`, данные пустого `A'` остаются сиротами в Firestore (их никто не удаляет — это
осознанный компромисс; см. раздел «слабые места»).

**`_adoptProviderName` (строки 87-100)**: при `link` Firebase не копирует `displayName`
провайдера в профиль пользователя — у анонимного он пустой. Метод один раз берёт имя из
`user.providerData` и пишет `updateDisplayName`, иначе главный экран здоровался бы «Merhaba !»
без имени. Ошибки глотаются — имя косметическое.

### 4.2 Анонимный вход

Вызовы `FirebaseAuth.instance.signInAnonymously()`:

1. `lib/features/auth/auth_gate.dart:40-45` — в `initState` `AuthGate`, если `currentUser == null`:
   ```dart
   @override
   void initState() {
     super.initState();
     if (FirebaseAuth.instance.currentUser == null) {
       FirebaseAuth.instance.signInAnonymously();
     }
   }
   ```
2. `lib/features/settings/settings_account_screen.dart:173` — сразу после `signOut()`.
3. `settings_account_screen.dart:215` — после удаления аккаунта (`deleteAccountData()` + `user.delete()`).

**Зачем так устроено** (комментарий `auth_gate.dart:29-30`: «Прозрачная авторизация: если
пользователя нет — входим анонимно. Экранов логина в MVP нет, данные сразу привязаны к uid»).
Пользователь начинает пользоваться приложением без регистрации — ноль трения на старте, но
при этом у него уже есть uid, под которым Firestore-правила разрешают писать. Регистрация
(email, Google, Apple) — опциональное действие «сохранить данные / синхронизировать», которое
делается через `linkWithCredential`, не ломая uid. Инвариант проекта: **в приложении всегда есть
`currentUser`**, поэтому после выхода тут же создаётся новый анонимный.

Email-регистрация тоже идёт через link — `lib/features/auth/sign_up_screen.dart:92-99`:
```dart
if (user != null && user.isAnonymous) {
  final cred = EmailAuthProvider.credential(email: _email.text.trim(), password: _password.text);
  await user.linkWithCredential(cred);
}
```

Cloud Function `aiCall` принимает анонимных пользователей (`index.ts:90` «anonim dahil»),
а `ClaudeClient.available` проверяет только `currentUser != null`.

### 4.3 `classifySocialAuthError` и `SocialAuthFailure`

Проблема: Google/Apple/Firebase бросают разные типы исключений с десятками кодов, которые
нельзя показывать пользователю как есть, а «отмена» вообще не ошибка.

```dart
enum SocialAuthFailure { canceled, differentMethod, notEnabled, network, unknown }

SocialAuthFailure classifySocialAuthError(Object error) {
  if (error is GoogleSignInException) {           // нативный Google бросает свой тип
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => SocialAuthFailure.canceled,
      GoogleSignInExceptionCode.interrupted ||
      GoogleSignInExceptionCode.providerConfigurationError => SocialAuthFailure.network,
      GoogleSignInExceptionCode.clientConfigurationError => SocialAuthFailure.notEnabled,
      _ => SocialAuthFailure.unknown,
    };
  }
  final code = switch (error) {
    FirebaseAuthException(:final code) => code,
    PlatformException(:final code) => code,
    _ => '',
  }.toLowerCase();
  if (code.contains('cancel') || code.contains('abort') || code == 'popup-closed-by-user') {
    return SocialAuthFailure.canceled;
  }
  return switch (code) {
    'account-exists-with-different-credential' || 'email-already-in-use' ||
    'credential-already-in-use' => SocialAuthFailure.differentMethod,
    'operation-not-allowed' || 'configuration-not-found' || ... => SocialAuthFailure.notEnabled,
    'network-request-failed' || 'too-many-requests' => SocialAuthFailure.network,
    _ => SocialAuthFailure.unknown,
  };
}
```

Решения: (1) три источника ошибок (`GoogleSignInException`, `FirebaseAuthException`,
`PlatformException`) сводятся к одному enum через Dart 3 pattern matching
(`FirebaseAuthException(:final code)`); (2) коды отмены различаются по платформам
(`web-context-canceled`, `canceled`, `ERROR_ABORTED_BY_USER`), поэтому ищется подстрока
`cancel`/`abort`; (3) `notEnabled` выделен отдельно — это ошибка конфигурации разработчика,
пользователь ничего сделать не может.

Как используется — `lib/features/auth/sign_in_screen.dart:39-60` и
`lib/features/onboarding/onboarding_save.dart:70-80`:
```dart
final failure = classifySocialAuthError(e);
if (failure == SocialAuthFailure.canceled) return;   // отмена — молча
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(switch (failure) {
  SocialAuthFailure.differentMethod => rs.saveErrDifferent,
  SocialAuthFailure.network => rs.saveErrOffline,
  _ => str.errorGeneric,
})));
```
Есть юнит-тест `test/auth_failure_test.dart`.

### 4.4 `lib/features/auth/auth_gate.dart` — что показать

```dart
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final uidProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) throw StateError('Пользователь не авторизован');
  return user.uid;
});
```

Дерево решений (две вложенные обёртки):

```
AuthGate (ConsumerStatefulWidget)
│  initState: currentUser == null → signInAnonymously()
│  ref.watch(authStateProvider).when(
│    loading → _Splash                       (текст «Budgy»)
│    data(null) → _Splash                    (анонимный вход ещё в полёте)
│    data(user) → _OnboardingGate
│    error → Scaffold('Ошибка входа: $e'))
│
└── _OnboardingGate (ConsumerWidget)
     done      = ref.watch(onboardingDoneProvider)    // settings/main.onboardingDone
     envelopes = ref.watch(envelopesProvider)
     migration = ref.watch(walletMigrationProvider)   // миграция кошелька, должна закончиться до UI
     любой isLoading → _Splash
     showOnboarding = done.value != true && envelopes.isEmpty
       → OnboardingFlow()  иначе  RootScreen()
```

Ключевые строки (`auth_gate.dart:72-84`):
```dart
final done = ref.watch(onboardingDoneProvider);
final envelopes = ref.watch(envelopesProvider);
final migration = ref.watch(walletMigrationProvider);
if (done.isLoading || envelopes.isLoading || migration.isLoading) {
  return const _Splash();
}
final showOnboarding = done.value != true && (envelopes.value?.isEmpty ?? true);
return showOnboarding ? const OnboardingFlow() : const RootScreen();
```

Почему двойное условие: флаг `onboardingDone` появился позже — старые пользователи с
конвертами, но без флага, не должны увидеть онбординг заново. Миграция кошелька ждётся до
показа главного экрана, чтобы баланс не мигал нулём (комментарий, строки 74-75). Есть
debug-режим `--dart-define=PREVIEW_ONBOARDING=true` для скриншотов онбординга.

Отдельных экранов логина в потоке запуска **нет** — `SignInScreen`/`SignUpScreen` открываются
только из настроек (`settings_account_screen.dart:82-103`) и из шага сохранения онбординга.

### 4.5 Нативная настройка iOS — `ios/Runner/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict><key>CFBundleURLSchemes</key><array>
    <string>app-1-838553523218-ios-b7040e7a957ee049f0f4cb</string>
  </array></dict>
  <dict><key>CFBundleURLSchemes</key><array>
    <string>com.googleusercontent.apps.838553523218-gt5mg417k7rp06kafnkuqnbumvknsmve</string>
  </array></dict>
</array>
<key>GIDClientID</key>
<string>838553523218-gt5mg417k7rp06kafnkuqnbumvknsmve.apps.googleusercontent.com</string>
```

| Ключ | Зачем | Что сломается без него |
|---|---|---|
| `GIDClientID` | OAuth client ID iOS-приложения; `google_sign_in` 7.x читает его из Info.plist (комментарий `auth_service.dart:17-18`: значение = `CLIENT_ID` из `GoogleService-Info.plist`) | `GoogleSignIn.instance.initialize()` бросит `clientConfigurationError` → `SocialAuthFailure.notEnabled`; Google-вход не запустится |
| URL-схема `com.googleusercontent.apps.<client-id>` | «Reversed client ID». После выбора аккаунта в системном UI/Safari iOS возвращает управление в приложение по этой схеме | Пользователь выберет аккаунт, а приложение не получит callback — вход зависнет / `canceled` |
| URL-схема `app-1-838553523218-ios-...` | Схема Firebase (`app-<appId>`) для federated-потоков `signInWithProvider` / `linkWithProvider` (сейчас — Apple) и reCAPTCHA/phone | Apple-вход через Firebase не вернётся в приложение после страницы `firebaseapp.com` |
| `Runner.entitlements` → `com.apple.developer.applesignin` | Capability «Sign in with Apple» | `AppleAuthProvider` упадёт, App Review отклонит сборку (правило 4.8) |

Также в `Info.plist` лежат описания разрешений: камера и галерея (скан чека, аватар),
микрофон и распознавание речи (голосовой ввод), Face ID (описание есть, но код биометрии —
нет, см. 2.6).

Android: `google-services.json` в `android/app/` (в `.gitignore`) + Gradle-плагин
`com.google.gms.google-services` 4.4.4 (`android/settings.gradle.kts:24`). Для Google-входа
на Android нужен SHA-1 сертификата в Firebase Console — в репозитории это не проверить.


---

<a id="часть-2"></a>

# 02. Управление состоянием, архитектура, модели, хранение, навигация

Все пути — относительно корня проекта `kopilka_app/`. Выдержки взяты из кода как есть (комментарии в коде на турецком/русском сохранены).

Версии (из `pubspec.lock`): Dart SDK `^3.11.5`, Flutter 3.41.9, `flutter_riverpod 3.3.1` (ядро `riverpod 3.2.1`), `cloud_firestore 6.8.0`, `firebase_auth 6.7.0`, `fake_cloud_firestore 4.2.0`.

---

## 1. Управление состоянием

### 1.1. Что используется

**Riverpod** (`flutter_riverpod: ^3.3.1` в `pubspec.yaml`). Это единственный менеджер состояния: ни Provider, ни BLoC, ни GetX в зависимостях нет.

`setState` тоже используется, но только для **локального UI-состояния** внутри `ConsumerStatefulWidget` (режим ввода, флаг «сохраняю», текст калькулятора). Пример — `lib/features/transactions/quick_entry_screen.dart`:

```dart
class _QuickEntryScreenState extends ConsumerState<QuickEntryScreen> {
  QuickMode _mode = QuickMode.expense;
  Envelope? _wallet; // null = nakit cüzdan
  late String _expr = widget.initialExpression;
  late DateTime _date = _today();
  Recurrence _recurrence = Recurrence.none;
  String _note = '';
  CategoryPick? _category;
  bool _multi = false;
  int _savedCount = 0;
  String? _lastTxId;
  bool _saving = false;
```

Правило, которое прослеживается по всему проекту: **данные (Firestore) — в провайдерах, эфемерное состояние экрана — в `State`**.

Корень дерева: `lib/main.dart` оборачивает приложение в `ProviderScope`:

```dart
runApp(kPreviewHome
    ? previewHomeScope(child: const KopilkaApp())
    : const ProviderScope(child: KopilkaApp()));
```

### 1.2. Версия Riverpod и синтаксис

- **Riverpod 3.x**, «новый» API: `Notifier` / `NotifierProvider`. Старого `StateNotifier`/`StateNotifierProvider` в коде **нет** (проверено grep-ом по `lib/`).
- **Кодогенерация не используется.** В `pubspec.yaml` объявлены `riverpod_annotation: ^4.0.2` и `riverpod_generator: ^4.0.3` (dev), но в `lib/` нет ни одной аннотации `@riverpod` и ни одного `*.g.dart`. Это «мёртвые» зависимости — на собеседовании честно сказать: «подключал, но пишу провайдеры вручную».
- Единственный `Notifier` в проекте — `ProStatus` в `lib/features/pro/pro_state.dart`:

```dart
final isProProvider = NotifierProvider<ProStatus, bool>(ProStatus.new);

class ProStatus extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(proEntitlementProvider, (_, next) {
      final granted = next.value ?? false;
      if (granted) state = true;
    }, fireImmediately: true);

    return kPreviewPro || (ref.read(proEntitlementProvider).value ?? false);
  }

  void set(bool value) => state = value;
}
```

### 1.3. Типы провайдеров в проекте

Всего в `lib/` ~75 провайдеров. Распределение: подавляющее большинство — `Provider` (производные/вычисляемые значения) и `StreamProvider` (Firestore-потоки); несколько `FutureProvider`; один `NotifierProvider`. **`StateProvider` не используется вообще** (в Riverpod 3 он считается legacy; локальный UI-стейт здесь живёт в `setState`).

| Тип | Пример | Файл | Зачем именно такой |
|---|---|---|---|
| `Provider<T>` | `budgetRepositoryProvider` | `lib/features/envelopes/budget_repository.dart:13` | Синхронно создаёт объект-зависимость (репозиторий). Это роль DI-контейнера. |
| `Provider<T>` (вычисляемый) | `activeEnvelopesProvider` | `lib/features/envelopes/budget_repository.dart:26` | Чистая производная от другого провайдера: фильтр без своей подписки на Firestore. |
| `StreamProvider<T>` | `envelopesProvider` | `lib/features/envelopes/budget_repository.dart:21` | Оборачивает `snapshots()` Firestore — экран обновляется сам при каждом изменении документа. |
| `StreamProvider.family` | `monthTxsProvider` | `lib/features/envelopes/budget_repository.dart:135` | Поток, параметризованный ключом месяца `'2026-06'`: на каждый ключ — свой кэшированный поток. |
| `FutureProvider<T>` | `walletMigrationProvider` | `lib/features/envelopes/budget_repository.dart:56` | Одноразовая async-операция (миграция); результат кэшируется, повторно не выполняется. |
| `FutureProvider.family` | `fxSnapshotProvider` | `lib/features/home/fx_providers.dart:12` | Загрузка таблицы курсов для базовой валюты; разные базы — разные кэши. |
| `NotifierProvider` | `isProProvider` | `lib/features/pro/pro_state.dart:17` | Единственное **изменяемое извне** состояние (`set(bool)`), с собственной логикой инициализации в `build()`. |
| `StateProvider` | — | — | **нет** |
| `AsyncNotifierProvider` / `StreamNotifierProvider` | — | — | **нет** |

Выдержки:

```dart
// lib/features/envelopes/budget_repository.dart
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    FirebaseFirestore.instance,
    ref.watch(uidProvider),
  );
});

final envelopesProvider = StreamProvider<List<Envelope>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchEnvelopes();
});

final activeEnvelopesProvider = Provider<List<Envelope>>((ref) {
  final envelopes = ref.watch(envelopesProvider).value ?? const [];
  return envelopes.where((e) => !e.archived && !e.isGoal).toList();
});

final monthTxsProvider =
    StreamProvider.family<List<Tx>, String>((ref, monthKey) {
  final start = DateTime.parse('$monthKey-01');
  final end = DateTime(start.year, start.month + 1);
  return ref.watch(budgetRepositoryProvider).watchTxsBetween(start, end);
});
```

```dart
// lib/features/home/fx_providers.dart
final fxSnapshotProvider =
    FutureProvider.family<FxSnapshot?, String>((ref, base) => loadFxSnapshot(base));
```

Важный приём — **цепочка производных провайдеров**: один `StreamProvider` (`recentTxsProvider`, 6 месяцев транзакций) → `currentMonthTxsProvider` (`Provider`, фильтр по месяцу) → `monthlySpentByEnvelopeProvider` (`Provider`, агрегация). Так на Firestore висит **один** слушатель, а не три. Комментарий в коде это прямо объясняет: `/// Bu ayın işlemleri — [recentTxsProvider]'dan türer (ekstra dinleyici yok).`

Ещё один нетипичный, но осмысленный приём — `Provider<void>` как «побочный эффект по подписке»: `widgetSyncProvider` (`lib/core/widget_service.dart:52`) и `reminderSchedulerProvider` (`lib/features/reminders/reminders_repository.dart:33`). Их `ref.watch`-ат один раз в `RootScreen`, и они переписывают home-виджет / локальные уведомления при изменении данных. Это «сервис-провайдер», не возвращающий значение.

### 1.4. `ConsumerWidget` vs `ConsumerStatefulWidget`

Счёт по `lib/`: `ConsumerWidget` — 32 файла, `ConsumerStatefulWidget` — 46, `StatefulWidget` (без ref) — 10, `StatelessWidget` — 64.

**`ConsumerWidget`** — когда виджету нужны только провайдеры и нет локального состояния. `lib/features/pro/pro_gate.dart`:

```dart
class ProGate extends ConsumerWidget {
  const ProGate({super.key, required this.feature, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isProProvider)) return child;
    final rs = ref.watch(rsProvider);
    return Stack(/* blur + paywall card */);
  }
}
```

**`ConsumerStatefulWidget`** — когда нужны `initState`/`dispose`/`setState` + `ref`. `lib/features/envelopes/home_screen.dart`:

```dart
class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _undoTxId;
  Timer? _undoTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _openQuickEntry() async {
    final result = await showQuickEntry(context);
    if (result == null || !mounted) return;
    _showUndo(result.lastTxId);
  }
```

Здесь `Timer` для чипа «Сохранено · Отменить» — его надо отменять в `dispose`, поэтому Stateful. В `ConsumerState` `ref` доступен как поле, а не параметр `build`.

Также `AuthGate` (`lib/features/auth/auth_gate.dart`) — Stateful только ради `initState`, где делается анонимный вход.

### 1.5. `ref.watch` vs `ref.read` vs `ref.listen`

**`ref.watch`** — подписка; при изменении провайдера виджет/провайдер пересобирается. Используется в `build` и внутри тел других провайдеров. `lib/features/root/root_screen.dart`:

```dart
@override
Widget build(BuildContext context) {
  ref.watch(widgetSyncProvider);
  if (ref.watch(isProProvider)) ref.watch(recurringMaterializerProvider);
  ref.watch(spaceNameMigrationProvider);
  return const HomeScreen();
}
```

Комментарий в коде объясняет, почему `watch`, а не `read`: «Hak sahipliği akışı geç gelirse isProProvider değişir, bu build yeniden çalışır ve yetişme o an olur» — если Pro-статус придёт позже, `build` перезапустится и материализация повторяющихся операций произойдёт в этот момент.

**`ref.read`** — одноразовое чтение без подписки. Правильно в обработчиках событий (`onTap`, `_save`). `lib/features/transactions/quick_entry_screen.dart:326`:

```dart
Future<void> _save() async {
  ...
  final repo = ref.read(budgetRepositoryProvider);
  final str = ref.read(strProvider);
  ...
  if (isExpense && wallet == null && envelopeId == null && note != null &&
      ref.read(isProProvider)) {
    final auto = await resolveCategoryFromText(ref, note);
```

Если бы здесь был `watch`, метод `_save` стал бы зависимостью — для callback это бессмысленно и в Riverpod 3 вызовет assert.

Ещё `ref.read` внутри **тела провайдера** — `reminderSchedulerProvider` (`lib/features/reminders/reminders_repository.dart`): внутри функции `reschedule()` берутся актуальные значения через `ref.read`, а подписка организована отдельно через `ref.listen`. Если бы в `reschedule()` стоял `watch`, провайдер пересоздавался бы при каждом изменении, а не вызывал функцию.

**`ref.listen`** — реагировать на изменение, не пересобирая. Три места в проекте:

```dart
// lib/features/reminders/reminders_repository.dart:87
ref.listen(remindersProvider, (_, _) => reschedule(), fireImmediately: true);
ref.listen(dailyReminderProvider, (_, _) => reschedule());
```

```dart
// lib/features/pro/pro_state.dart:28 — внутри Notifier.build()
ref.listen(proEntitlementProvider, (_, next) {
  final granted = next.value ?? false;
  if (granted) state = true;
}, fireImmediately: true);
```

Во втором случае выбран `listen`, а не `watch`, намеренно: `watch` пересоздал бы `Notifier` и **сбросил** состояние, выставленное вручную через `set(true)` (paywall-превью, тесты). `listen` только «OR-ит» серверное право в текущее состояние.

Обратите внимание на `(_, _)` — два подчёркивания как имена параметров: это Dart 3.7+ «wildcard variables».

Распространённый паттерн в проекте — `ref.watch(streamProvider).value ?? default` вместо `.when(...)`. Он короче, но теряет различие «загружается / ошибка / пусто». `.when` используется там, где это различие важно для UI (см. раздел 6).

### 1.6. Переопределение провайдеров в тестах

`test/support/harness.dart` — функция `pumpBudgyScreen` собирает `ProviderScope(overrides: [...])`:

```dart
ProviderScope(
  overrides: [
    budgetRepositoryProvider
        .overrideWithValue(BudgetRepository(db, testUid)),
    workDaysRepositoryProvider
        .overrideWithValue(WorkDaysRepository(db, testUid)),
    languageProvider.overrideWith((ref) => Stream.value(language)),
    currencyProvider.overrideWith((ref) => Stream.value(currency)),
    envelopesProvider.overrideWith((ref) => Stream.value(envelopes)),
    journalProvider.overrideWith((ref) => Stream.value(transactions)),
    ...
    reminderSchedulerProvider.overrideWithValue(null),
    recurringMaterializerProvider.overrideWith((ref) async => 0),
    appVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
    fxSnapshotProvider.overrideWith((ref, base) async => fxSnapshot),
    isProProvider.overrideWith(() => _TestProStatus(pro)),
  ],
  child: MaterialApp(...),
)
```

Три вида переопределений:
- `overrideWithValue(obj)` — подставить готовый объект (`BudgetRepository` с `FakeFirebaseFirestore` вместо реального Firestore).
- `overrideWith((ref) => Stream.value(x))` — для `StreamProvider` подменить поток готовым значением; для `FutureProvider` — `(ref) async => x`; для `.family` — `(ref, arg) => ...`.
- `overrideWith(() => _TestProStatus(pro))` — для `NotifierProvider` подставить подкласс `Notifier` с фиксированным `build()`:

```dart
class _TestProStatus extends ProStatus {
  _TestProStatus(this._value);
  final bool _value;
  @override
  bool build() => _value;
}
```

Почему нужно переопределять `budgetRepositoryProvider`: он зависит от `uidProvider`, который бросает `StateError`, если пользователя нет (`lib/features/auth/auth_gate.dart:16`). В тестах нет Firebase Auth, поэтому без override любой экран упал бы. Комментарий в harness это говорит прямо.

Юнит-тесты репозитория (`test/budget_repository_test.dart`) обходятся вообще без Riverpod — создают `BudgetRepository(FakeFirebaseFirestore(), 'test-user')` напрямую. Это возможно именно потому, что репозиторий получает зависимости через конструктор.

---

## 2. Архитектура

### 2.1. Слои data / domain / presentation

Формальных слоёв **нет**. Нет папок `data/`, `domain/`, `presentation/`, нет интерфейсов репозиториев, нет use-case'ов. Фактически есть два слоя внутри каждой фичи:

1. **Репозиторий + провайдеры** (`*_repository.dart`) — доступ к Firestore, маппинг документов в модели, атомарные записи.
2. **Экраны и виджеты** (`*_screen.dart`, `*_sheet.dart`) — UI, который `ref.watch`-ит провайдеры и `ref.read`-ит репозиторий для записи.

Плюс `lib/core/` — чистые функции и утилиты без Flutter-зависимостей (`calc.dart`, `fx_freeze.dart`, `fx.dart`, `category_rules.dart`, `formatters.dart`) — это ближе всего к «domain», и именно они покрыты юнит-тестами.

Честная формулировка для собеседования: «feature-first без формального разделения на слои; репозиторий отвечает за данные, виджеты за UI, вычисления вынесены в производные провайдеры и чистые функции».

### 2.2. Repository pattern

**`lib/features/envelopes/budget_repository.dart`** — класс `BudgetRepository` (~1000 строк, главный репозиторий):

```dart
class BudgetRepository {
  BudgetRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  FirebaseFirestore get db => _db;
  String get uid => _uid;

  CollectionReference<Map<String, dynamic>> get _envelopes =>
      _db.collection('users').doc(_uid).collection('envelopes');

  DocumentReference<Map<String, dynamic>> get _cash =>
      _db.collection('users').doc(_uid).collection('accounts').doc('cash');

  CollectionReference<Map<String, dynamic>> get _txs =>
      _db.collection('users').doc(_uid).collection('transactions');
```

Что инкапсулирует:
- **Пути в Firestore** — все данные лежат под `users/{uid}/...`; геттеры `_envelopes`, `_txs`, `_settings`, `_cash`, `_recurring` — единственное место, где эти пути написаны.
- **Чтение как потоки** — `watchEnvelopes()`, `watchTransactions()`, `watchTxsBetween()`, `watchCashBalance()`, `watchLanguage()` и т.д. возвращают `Stream<Model>`.
- **Запись как атомарные батчи** — `addExpense`, `addCashIncome`, `convert`, `fundGoal`, `deleteTx`, `updateTx` — каждая операция «транзакция + изменение баланса» пишется одним `WriteBatch`.
- **Инварианты денег** — `_cashDelta`, `_reversalOf`, `_applyDeltas` — логика «как отменить эффект транзакции» живёт здесь, а не в UI.
- **Миграции** — `migrateToWallet()`.

Расширения репозитория: `extension AutomationRepo on BudgetRepository` в `lib/features/settings/app_settings.dart:75` — добавляет методы для правил автокатегоризации, используя публичные `db`/`uid`. Это способ не раздувать основной файл и держать код фичи рядом с фичей.

**`lib/features/accounts/accounts_repository.dart`** — `AccountsRepository`, тот же шаблон:

```dart
final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(FirebaseFirestore.instance, ref.watch(uidProvider));
});

class AccountsRepository {
  AccountsRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _db.collection('users').doc(_uid).collection('accounts');

  Stream<List<Account>> watchAccounts() => _accounts.snapshots().map(
    (snap) => _sorted(snap.docs.map(Account.fromDoc).where((a) => !a.archived)),
  );
```

Интересное решение: сортировка и фильтр **на клиенте**, а не через `orderBy`/`where` Firestore. Причина в комментарии: серверный `where('archived', isNotEqualTo: true)` **выбросил бы** документы, у которых поля `archived` нет вовсе (старый документ `accounts/cash` содержит только `balance`). Коллекция маленькая — клиентская сортировка бесплатна.

Разделение ответственности между двумя репозиториями явно задокументировано:
> `users/{uid}/accounts` üzerinde CRUD. Bakiye HAREKETLERİ burada değil: gelir/gider yazan taraf (BudgetRepository) işlemle birlikte tek batch'te `balance`'ı artırıp azaltır.

То есть `AccountsRepository` — CRUD карточек счетов; движение денег по счетам делает `BudgetRepository` в том же батче, что и запись транзакции.

**Как получают `uid`.** Через `ref.watch(uidProvider)` при создании в провайдере:

```dart
// lib/features/auth/auth_gate.dart
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final uidProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) throw StateError('Пользователь не авторизован');
  return user.uid;
});
```

Следствие: когда пользователь меняется (анонимный → Google-аккаунт с другим uid), `uidProvider` меняется → `budgetRepositoryProvider` пересоздаётся → все `StreamProvider`-ы, зависящие от него, переподписываются на новые пути. Это «реактивный DI».

### 2.3. DI

`get_it` / `injectable` — **нет**. Роль DI полностью выполняют провайдеры Riverpod:

```dart
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    FirebaseFirestore.instance,
    ref.watch(uidProvider),
  );
});
```

Три свойства, которые делают это DI:
1. **Ленивость + синглтон** — объект создаётся при первом `ref.watch` и живёт, пока на него есть подписчики (у корневого `ProviderScope` — всё время работы приложения).
2. **Граф зависимостей** — `budgetRepositoryProvider` → `uidProvider` → `authStateProvider`; Riverpod сам пересоздаёт по цепочке.
3. **Подмена в тестах** — `overrideWithValue(BudgetRepository(fakeDb, testUid))`, см. 1.6.

Конструктор `BudgetRepository(this._db, this._uid)` принимает `FirebaseFirestore` снаружи, а не берёт `FirebaseFirestore.instance` внутри — это и есть constructor injection, без которого `fake_cloud_firestore` в тестах был бы невозможен.

Статические сервисы, которые DI обходят: `AuthService` (`lib/features/auth/auth_service.dart`), `ClaudeClient` (`lib/core/ai/claude_client.dart`), `Notifications` (`lib/core/notifications.dart`), `FxCache` (`lib/core/fx.dart`) — всё `static`. Их не подменить через overrides; для тестов есть обходные пути (`FxCache.directoryOverride`, `ClaudeClient.available` проверяет `Firebase.apps.isEmpty`).

### 2.4. Feature-first структура

Принцип: код группируется **по бизнес-возможности**, а не по техническому типу (не `models/`, `screens/`, `services/`). Всё, что относится к одной фиче — модель, репозиторий, провайдеры, экраны, bottom-sheet'ы — лежит в одной папке.

`lib/features/` содержит 22 папки. Три показательных примера:

- `lib/features/accounts/` — `account.dart` (модель), `accounts_repository.dart` (данные + провайдеры), `accounts_screen.dart`, `account_card.dart`, `account_editor_sheet.dart`, `account_picker.dart`, `bank_catalog.dart`, `account_suggestion.dart`.
- `lib/features/envelopes/` — `envelope.dart`, `budget_repository.dart`, `home_screen.dart`, `envelope_detail_screen.dart`, `add_envelope_sheet.dart`, `balance_chart.dart`, `onboarding_screen.dart`.
- `lib/features/transactions/` — `tx.dart`, `quick_entry_screen.dart`, `journal_screen.dart`, `ai_add_sheet.dart`, `receipt_scan.dart`, `category_sheet.dart`, `convert_sheet.dart`.

Общее — в `lib/core/` (тема, токены, форматирование, l10n, калькулятор, FX, AI-клиент).

Нюанс, за который могут зацепиться: `lib/features/envelopes/budget_repository.dart` исторически стал «главным» репозиторием и содержит транзакции, настройки, профиль, тему, язык, повторяющиеся операции — то есть обслуживает **несколько** фич. Папка `envelopes/` не вполне описывает его содержимое. Есть и `lib/features/home/accounts_screen.dart` рядом с `lib/features/accounts/accounts_screen.dart` — следы редизайна.

### 2.5. Где живёт бизнес-логика

Честная оценка — **в трёх местах, с осмысленным распределением**:

**В репозиториях — денежные инварианты.** `lib/features/envelopes/budget_repository.dart`, `_reversalOf`:

```dart
({double cash, Map<String, double> env}) _reversalOf(
    List<Map<String, dynamic>> docs) {
  var cashDelta = 0.0;
  final envDeltas = <String, double>{};
  ...
  for (final d in docs) {
    final type = d['type'] as String?;
    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
    final currency = d['currency'] as String? ?? 'TRY';
    final sign = type == TxType.expense.name ? 1.0
        : type == TxType.income.name ? -1.0 : 0.0;
    if (sign == 0) continue;
    if (currency == 'TRY') {
      cashDelta += sign * amount;
    } else {
      env(d['envelopeId'] as String?, sign * amount);
    }
```

Это правильно: логику «как откатить транзакцию» нельзя доверять UI, и её удобно тестировать с `FakeFirebaseFirestore`.

**В провайдерах — вычисляемые агрегаты.** `lib/features/insights/analytics.dart`:

```dart
final earningStreakProvider = Provider<int>((ref) {
  final earned = ref.watch(allWorkDaysProvider).value ?? const [];
  final days = <DateTime>{
    for (final d in earned)
      if ((d.amount ?? 0) > 0) _dayOnly(d.date),
  };
  if (days.isEmpty) return 0;
  var cursor = _dayOnly(DateTime.now());
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(cursor)) { streak++; cursor = cursor.subtract(const Duration(days: 1)); }
  return streak;
});
```

Аналогично `monthlySpentByEnvelopeProvider`, `paceProvider`, `monthComparisonProvider`, `budgetWindowProvider`. Это «view-model без класса»: виджеты получают готовые числа и только рисуют.

**В чистых функциях `lib/core/`** — `evalExpression` (`calc.dart`), `freezeToBase` (`fx_freeze.dart`), `nextOccurrence` (`recurring.dart`), `matchCategory` (`category_rules.dart`). Покрыты юнит-тестами (`test/calc_test.dart`, `test/fx_freeze_test.dart`, `test/recurring_test.dart`).

**В виджетах — оркестрация.** `_save()` в `quick_entry_screen.dart` (130 строк) решает: расход или доход, какой кошелёк, подобрать ли категорию по тексту, редактирование или создание, добавить ли правило повтора. Это не чистая «логика расчёта», а сценарий — но он довольно длинный и сидит в `State`. Для middle-уровня нормально; на собеседовании можно сказать: «кандидат на вынос в `AsyncNotifier`/контроллер, если экран будет расти».

Утечка логики в виджеты, которую стоит признать: `monthSpentProvider` и `uncategorizedTxsProvider` объявлены в `home_screen.dart`, а не рядом с остальной аналитикой; `greetingNameProvider` там же дёргает `FirebaseAuth.instance` напрямую.

---

## 3. Модели и JSON

### 3.1. `json_serializable` / `freezed`

**Нет ни того, ни другого** (проверено по `pubspec.yaml` и отсутствию `*.g.dart`/`*.freezed.dart`). Все модели — обычные immutable-классы с `const`-конструктором, `final`-полями, ручными `fromDoc`/`toMap`/`copyWith`.

**`lib/features/transactions/tx.dart`:**

```dart
factory Tx.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;
  return Tx(
    id: doc.id,
    type: TxType.values.byName(data['type'] as String),
    amount: (data['amount'] as num).toDouble(),
    date: (data['date'] as Timestamp).toDate(),
    note: data['note'] as String?,
    allocations: (data['allocations'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toDouble())),
    currency: data['currency'] as String? ?? 'TRY',
    isConvert: data['convert'] == true,
    accountId: data['accountId'] as String?,
    baseAmount: (data['baseAmount'] as num?)?.toDouble(),
    ...
```

У `Tx` **нет** `toMap()` — запись транзакций делает репозиторий, собирая `Map` вручную в `_writeExpense` / `_writeCashIncome`. Это асимметрия: модель только читается, схема записи живёт в репозитории.

**`lib/features/accounts/account.dart`** — полный набор `fromDoc` + `toMap` + `copyWith`:

```dart
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
```

`if (x != null) 'key': x` в литерале map — чтобы не писать `null` в Firestore (иначе поле будет существовать со значением null и `where`-запросы поведут себя иначе).

**`lib/features/envelopes/envelope.dart`** — только `fromDoc`, без `toMap` и `copyWith` (запись — через `BudgetRepository.addEnvelope`/`updateEnvelope`).

Обратите внимание: enum сериализуется через `.name` / `values.byName(...)` (встроено в Dart 2.15+), что убирает нужду в `json_serializable` для простых случаев. В `Account.fromDoc` используется более безопасный вариант `firstWhere(..., orElse: ...)`, чтобы незнакомое значение `kind` не уронило парсинг.

### 3.2. Почему `fromDoc(DocumentSnapshot)`, а не `fromJson(Map)`

Три причины, видные в коде:

1. **`id` не лежит внутри данных.** Firestore хранит id документа отдельно от полей; `fromJson(Map)` не смог бы заполнить `id: doc.id`. В `Account.fromDoc` id ещё и участвует в логике: `orElse: () => doc.id == cashId ? AccountKind.cash : AccountKind.card`.
2. **Типы Firestore — не JSON.** Дата приходит как `Timestamp`, а не строка/число: `date: (data['date'] as Timestamp).toDate()`. Числа могут быть `int` или `double` — отсюда везде `(x as num?)?.toDouble()`.
3. **Пустой документ.** `doc.data()` возвращает `null`, если документа нет; `Account.fromDoc` обрабатывает это (`doc.data() ?? const {}`), тогда как `Tx.fromDoc` и `Envelope.fromDoc` используют `!` (они создаются только из `QuerySnapshot`, где документ точно существует).

### 3.3. `Tx.baseOr(String mainCurrency)` — замороженный курс

Проблема: пользователь получает зарплату в ₺, но тратит с азербайджанской карты в ₼. Чтобы сложить «потрачено за месяц» в одной валюте, манаты надо перевести в лиры. Если переводить **по текущему курсу при каждом открытии**, прошлые месяцы будут «плавать» вместе с курсом — отчёт за август изменится в сентябре. Это неприемлемо для финансового учёта.

Решение — **заморозить курс в момент записи**. В `Tx` три поля:

```dart
/// [amount]'un ana para birimine çevrilmiş hâli. **İşlem kaydedilirken
/// o günün kuruyla hesaplanır ve bir daha DEĞİŞMEZ.**
final double? baseAmount;

/// [baseAmount] hangi para biriminde. Kullanıcı ana para birimini sonradan
/// değiştirirse eski kayıtların neye göre çevrildiği kaybolmasın diye.
final String? baseCurrency;

/// Kullanılan kur (1 [currency] kaç [baseCurrency]).
final double? fxRate;
```

И метод, который аналитика использует вместо `amount`:

```dart
double baseOr(String mainCurrency) {
  final frozen = baseAmount;
  if (frozen != null) return frozen;
  if (accountId == null && currency == legacyMainCode) return amount;
  return currency == mainCurrency ? amount : 0;
}

static const legacyMainCode = 'TRY';
```

Четыре ветви (документация в коде нумерует их так же):
1. Есть замороженный `baseAmount` → он. Все новые записи.
2. Нет `accountId` **и** `currency == 'TRY'` → это запись до появления счетов. В ту эпоху в `currency` писали константу `'TRY'`, означавшую «основная валюта», даже если пользователь выбрал символ $. Поэтому сравнивать с `mainCurrency` нельзя — у пользователя с основной USD вся история обнулилась бы.
3. Валюта операции совпадает с основной → `amount` как есть.
4. Иначе `0` — непереконвертированная иностранная запись. Комментарий: «yanlış rakamdansa eksik rakam» — лучше недосчитать, чем показать неверное число.

Сопутствующая чистая функция `freezeToBase` в `lib/core/fx_freeze.dart` возвращает record `({double baseAmount, double rate})`, округляет `baseAmount` до копеек, а `rate` не округляет, и **бросает `FxUnavailable`** вместо того, чтобы вернуть 0 или 1 — потому что «yanlış dondurulan tutar ay toplamını kalıcı bozar» (неправильно замороженная сумма портит месяц навсегда).

Что сказать на собеседовании: «денормализация ради неизменяемости истории: храним и исходную сумму, и сконвертированную, и курс — три поля вместо одного, зато отчёты детерминированы и аудируемы».

**Важный факт для честности:** `freezeToBase` вызывается только в `test/fx_freeze_test.dart`. В `lib/` ни один вызов `addExpense` не передаёт `baseAmount`/`fxRate` (в `quick_entry_screen.dart:389` их нет). То есть схема и чтение готовы, а запись замороженного курса ещё не подключена. Если спросят «работает ли это в проде» — ответ «инфраструктура есть, провод не воткнут».

### 3.4. Миграции данных: старые документы без новых полей

Явной системы миграций (версионирование схемы, `schemaVersion`) **нет**. Стратегия — **read-time defaults**: каждый новый атрибут читается с `??` или проверкой `== true`, запись добавляет поле только при необходимости.

`lib/features/envelopes/envelope.dart`:

```dart
emoji: data['emoji'] as String? ?? '💰',
balance: (data['balance'] as num?)?.toDouble() ?? 0,
sortOrder: data['sortOrder'] as int? ?? 0,
currency: data['currency'] as String? ?? 'TRY',
archived: data['archived'] == true,
targetAmount: (data['targetAmount'] as num?)?.toDouble(),
isGoal: data['goal'] == true,
```

`data['archived'] == true` вместо `as bool? ?? false` — одно выражение покрывает и отсутствие поля, и `null`, и неверный тип.

`lib/features/accounts/account.dart` — комментарий прямо называет сценарий:

```dart
// Eski `accounts/cash` belgesinde yalnız `balance` var; kalan alanlar
// okunurken varsayılana düşer, yazma gerektirmez.
currency: (d['currency'] as String?) ?? 'TRY',
kind: AccountKind.values.firstWhere(
  (k) => k.name == d['kind'],
  orElse: () => doc.id == cashId ? AccountKind.cash : AccountKind.card,
),
```

Там, где default'ов недостаточно, есть **одноразовые миграции-провайдеры**: `walletMigrationProvider` → `BudgetRepository.migrateToWallet()` (проверяет `if (cashSnap.exists) return;` — идемпотентна), `spaceNameMigrationProvider` (`lib/features/space/space.dart:65`). Они `ref.watch`-атся в `_OnboardingGate` / `RootScreen` до показа главного экрана, чтобы пользователь не увидел «прыжок» баланса.

Ещё приём совместимости — `set(..., SetOptions(merge: true))` вместо `update` там, где документ может не существовать (`AccountsRepository.rename`, `_cashDelta`): `update` упал бы на отсутствующем документе.

---

## 4. Локальное хранение

### 4.1. Что есть

Из `pubspec.yaml`: **нет** `shared_preferences`, `hive`, `isar`, `sqflite`, `drift`, `flutter_secure_storage`. Есть `path_provider` (используется в одном месте — `lib/features/insights/month_summary_card.dart:277`, временная папка для share-картинки).

Локальное состояние на диске всё же есть, но реализовано без БД-плагинов:

1. **Кэш курсов валют** — `FxCache` в `lib/core/fx.dart`: JSON-файл `budgy_fx_<base>.json` в `~/Library/Caches` (iOS) или `Directory.systemTemp`, плюс кэш в памяти. Свежесть 6 часов. Это `dart:io` напрямую:

```dart
static Directory _dir() {
  if (directoryOverride != null) return directoryOverride!;
  final home = Platform.environment['HOME'];
  if (Platform.isIOS && home != null) {
    return Directory('$home/Library/Caches');
  }
  return Directory.systemTemp;
}
```

2. **Данные home-виджета** — `home_widget` (`lib/core/widget_service.dart`) пишет строки в App Group (`UserDefaults` на iOS / `SharedPreferences` на Android) под капотом плагина.

3. **Расписание уведомлений** — `flutter_local_notifications` (`lib/core/notifications.dart`); живёт в ОС, при изменении списка в Firestore пересоздаётся целиком (`cancelAll()` → `scheduleMonthly(...)`).

4. **CSV-экспорт** — временный файл через `Directory.systemTemp.createTemp('budgy')` (`lib/features/settings/data_management_screen.dart`).

### 4.2. Что локально, что в облаке

| Данные | Где | Файл |
|---|---|---|
| Конверты, счета, транзакции, рабочие дни, правила, напоминания | Firestore `users/{uid}/...` | `budget_repository.dart`, `accounts_repository.dart`, `work_days_repository.dart`, `reminders_repository.dart` |
| Настройки: язык, валюта, тема, onboarding, профиль, раскладка клавиатуры, избранные валюты | Firestore `users/{uid}/settings/main` | `BudgetRepository.watchLanguage/watchCurrency/watchThemeMode/watchProfile` |
| Pro-право | Firestore `users/{uid}/entitlements/pro` (read-only для клиента) | `watchProEntitlement` |
| Курсы валют | Файл-кэш + память | `FxCache` |
| Данные виджета | App Group prefs | `BudgyWidget.push` |
| Расписание уведомлений | ОС | `Notifications` |

Нетипичное решение: **даже язык и тема хранятся в Firestore**, а не в `SharedPreferences`. Плюс — настройки переезжают между устройствами вместе с аккаунтом; минус — до первого ответа Firestore используется default (`AppLanguage.en`, `'TRY'`), и при смене языка пересобирается всё дерево через `KeyedSubtree(key: ValueKey('$symbol|${lang.code}'))` в `lib/app.dart`.

### 4.3. Офлайн-кэш

Firestore SDK на iOS/Android **по умолчанию** включает офлайн-персистентность (локальная SQLite/LevelDB-копия всех прочитанных документов + очередь незаписанных изменений). В коде проекта `FirebaseFirestore.instance.settings = ...` **нигде не задаётся** (grep по `persistenceEnabled`, `Settings(`, `.settings =` — пусто), значит действует default: персистентность включена, размер кэша 100 МБ.

Что это даёт: `snapshots()` сначала отдаёт данные из кэша (с `metadata.isFromCache == true`), запись в офлайне применяется локально сразу (optimistic) и уходит на сервер при появлении сети. UI на `StreamProvider` этого «не замечает».

Где это **кусается** — `lib/features/workdays/work_days_repository.dart:75`:

> Eskiden `ref.get()` + batch kullanılıyordu; get çevrimdışıyken ya da sunucu yanıtı gelmeden YEREL ÖNBELLEKTEN okuyor. Aynı güne arka arkaya iki kez kaydedilince ... cüzdana İKİ KEZ ekleniyordu.

Обычный `get()` в офлайне читает из кэша, и паттерн read-modify-write даёт двойное начисление. Поэтому там перешли на `runTransaction` (см. раздел 6.5).

### 4.4. Secure storage

`flutter_secure_storage` нет — и он не нужен, потому что в приложении **нет секретов на клиенте**:

- **Токены аутентификации** — внутри Firebase Auth SDK, который сам хранит refresh-token в Keychain (iOS) / EncryptedSharedPreferences (Android). Код проекта токенов не видит (`lib/features/auth/auth_service.dart` работает с `UserCredential`, не с raw-token).
- **API-ключ Anthropic** — на сервере. `lib/core/ai/claude_client.dart`:

```dart
/// Anthropic'e tek çağrı — ama telefondan değil, `aiCall` Cloud Function'ı
/// üzerinden. Anahtar cihazda yok: sunucu Secret Manager'dan okur, modeli
/// ve token tavanını kendisi sabitler, her başarılı çağrıyı kullanıcının
/// aylık sayacına işler.
```

Клиент вызывает `FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('aiCall')`; функция проверяет аутентификацию и лимиты. Это правильный ответ на вопрос «как хранить API-ключ в мобильном приложении» — никак, он не должен быть на устройстве.

- **Firebase config** (`lib/firebase_options.dart`) — это не секрет, а идентификаторы проекта; защита от злоупотребления — App Check (`main.dart: _activateAppCheck()`, Play Integrity / App Attest) и Security Rules.

---

## 5. Навигация

### 5.1. Что используется

**Navigator 1.0, императивный.** `go_router`/`auto_route` в `pubspec.yaml` нет. Именованных маршрутов (`routes:`, `onGenerateRoute`, `pushNamed`) — нет. Все переходы — `Navigator.of(context).push(MaterialPageRoute(...))`.

Счёт: `MaterialPageRoute` встречается 32 раза в `lib/`, `Navigator.*` — в 52 файлах.

Типичный хелпер — `lib/features/settings/settings_hub.dart:203`:

```dart
void pushSettings(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
```

и его двойник `_push` в `home_screen.dart:490`.

Экраны, возвращающие результат, оборачиваются в типизированную функцию — `lib/features/transactions/quick_entry_screen.dart:46`:

```dart
Future<QuickEntryResult?> showQuickEntry(
  BuildContext context, {
  String initialExpression = '',
  String? autoSheet,
}) {
  return Navigator.of(context).push<QuickEntryResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuickEntryScreen(
        initialExpression: initialExpression,
        autoSheet: autoSheet,
      ),
    ),
  );
}
```

`fullscreenDialog: true` даёт iOS-анимацию «снизу вверх» и кнопку «закрыть» вместо «назад». Результат возвращается через `Navigator.of(context).pop(QuickEntryResult(lastTxId: id!, count: 1))`, а вызывающий экран ждёт его через `await`:

```dart
// home_screen.dart
final result = await showQuickEntry(context);
if (result == null || !mounted) return;
_showUndo(result.lastTxId);
```

Возврат к корню — `Navigator.of(context).popUntil((r) => r.isFirst)` (`data_management_screen.dart:99`, `settings_account_screen.dart`) после удаления аккаунта/выхода: закрыть весь стек, а `AuthGate` сам переключит ветку.

Нижней панели вкладок нет (`lib/features/root/root_screen.dart`: «Kök ekran: alt sekme çubuğu yok — Takvim/Hedefler/İstatistik artık ana ekranın menüsünden push edilen rotalar»).

Deep links / web-URL — не поддерживаются; для такого приложения это приемлемо, но это прямой ответ на вопрос «почему не go_router».

### 5.2. Верхний уровень — `auth_gate.dart`: условный рендеринг, не роутер

`lib/app.dart` задаёт `home: AuthGate()` — без `routes`. Дальше — цепочка виджетов, которые **возвращают разное поддерево в зависимости от состояния**:

```dart
// lib/features/auth/auth_gate.dart
class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser == null) {
      FirebaseAuth.instance.signInAnonymously();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) =>
          user == null ? const _Splash() : const _OnboardingGate(),
      loading: () => const _Splash(),
      error: (e, _) => Scaffold(body: Center(child: Text('Ошибка входа: $e'))),
    );
  }
}

class _OnboardingGate extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(onboardingDoneProvider);
    final envelopes = ref.watch(envelopesProvider);
    final migration = ref.watch(walletMigrationProvider);
    if (done.isLoading || envelopes.isLoading || migration.isLoading) {
      return const _Splash();
    }
    final showOnboarding =
        done.value != true && (envelopes.value?.isEmpty ?? true);
    return showOnboarding ? const OnboardingFlow() : const RootScreen();
  }
}
```

Разница с роутером:
- **Нет стека.** `AuthGate` не «пушит» экран логина и не «попает» его — он просто пересобирается, когда `authStateProvider` испускает новое значение. Нельзя нажать «назад» и вернуться в сплэш.
- **Декларативно.** Состояние (есть пользователь? пройден onboarding? есть конверты?) однозначно определяет, что показано. Нет риска «забыть сделать `pushReplacement` после логина».
- **Переходы без анимации.** Смена ветки — это замена поддерева, а не page transition.
- **Ниже** `RootScreen` начинается обычный `Navigator`-стек с `push`.

Это стандартный паттерн для Firebase-приложений: «gate»-виджеты наверху, императивный Navigator внизу. Побочный эффект, который стоит знать: когда пользователь удаляет все данные, `envelopesProvider` становится пустым, `_OnboardingGate` пересобирается и показывает `OnboardingFlow` — экран «ушёл» без единого вызова `Navigator`. Именно поэтому в `_deleteAll` после удаления стоит `popUntil(isFirst)`: иначе под новым onboarding остался бы старый стек.

### 5.3. Модальные окна

Единый хелпер — `showExSheet` в `lib/core/ex_style.dart:303`:

```dart
Future<T?> showExSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Ex.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => child,
  );
}
```

Зачем обёртка: одни и те же `isScrollControlled` (чтобы sheet мог быть выше половины экрана и реагировать на клавиатуру), `useSafeArea`, цвет и скругление — в одном месте. Используется типизированно:

```dart
// lib/features/transactions/receipt_scan.dart
final source = await showExSheet<ImageSource>(context, const _SourcePicker());
if (source == null || !context.mounted) return;
```

```dart
// lib/features/transactions/quick_entry_screen.dart:223
final picked = await showExSheet<Recurrence>(...);
```

Внутри sheet-а выбор возвращается через `Navigator.of(context).pop(value)` — bottom sheet это тоже Route в том же Navigator.

Параллельно есть прямые вызовы `showModalBottomSheet` (`paywall_sheet.dart:17`, `goals_screen.dart`, `journal_screen.dart`, `add_funds_sheet.dart`) — там нужны свои параметры (например, другой фон для paywall). Каркас содержимого — `SheetFrame` (`ex_style.dart`): ручка, заголовок, кнопка закрытия, контент с учётом клавиатуры.

Повсеместный паттерн после `await` — `if (!context.mounted) return;` / `if (!mounted) return;` — защита от использования `BuildContext` после того, как виджет удалён (lint `use_build_context_synchronously`).

---

## 6. Асинхронность

### 6.1. Где `Future`, где `Stream`

Правило в проекте: **чтение — `Stream`, запись — `Future`.**

`Stream` (чтение, живые данные):
- `BudgetRepository.watchEnvelopes()` → `Stream<List<Envelope>>` — `lib/features/envelopes/budget_repository.dart`
- `AccountsRepository.watchAccounts()` → `Stream<List<Account>>` — `lib/features/accounts/accounts_repository.dart:56`
- `WorkDaysRepository.watchMonth(monthKey)` → `Stream<Map<DateTime, double?>>` — `lib/features/workdays/work_days_repository.dart:60`
- `FirebaseAuth.instance.authStateChanges()` → `Stream<User?>` — `auth_gate.dart:11`

`Future` (запись, одноразовые операции):
- `BudgetRepository.addExpense(...)` → `Future<String>` (id документа) — `budget_repository.dart`
- `AccountsRepository.transactionCount(id)` → `Future<int>` — агрегатный `count()` на сервере, `accounts_repository.dart:145`
- `loadFxSnapshot(base)` → `Future<FxSnapshot?>` — `lib/core/fx.dart`
- `ClaudeClient.callTool(...)` → `Future<Map<String, dynamic>>` — `lib/core/ai/claude_client.dart:80`

### 6.2. `StreamProvider` + Firestore snapshots — почему экран обновляется «сам»

Цепочка:

```
Firestore (сервер/кэш)
  └─ _envelopes.orderBy('sortOrder').snapshots()      Stream<QuerySnapshot>
       └─ .map((snap) => snap.docs.map(Envelope.fromDoc).toList())   Stream<List<Envelope>>
            └─ envelopesProvider = StreamProvider(...)                AsyncValue<List<Envelope>>
                 └─ ref.watch(envelopesProvider) в build()            виджет пересобирается
```

1. `snapshots()` открывает **listener** в Firestore SDK: сервер пушит изменения по gRPC-соединению, SDK применяет их к локальному кэшу и эмитит новый `QuerySnapshot`.
2. `.map(...)` превращает документы в модели — всё ещё ленивый `Stream`.
3. `StreamProvider` подписывается на этот `Stream`, когда появляется первый `ref.watch`, и хранит последнее значение как `AsyncValue` (`loading` → `data` → `data` → ...).
4. Каждый `ref.watch(envelopesProvider)` в `build` регистрирует виджет как зависимый; новое значение → `markNeedsBuild`.

Локальная запись через `batch.commit()` идёт в тот же кэш, поэтому listener срабатывает **сразу**, не дожидаясь сервера (optimistic update). Поэтому в `_save()` после `repo.addExpense` нет никакого «обнови список» — список уже обновился.

Ресурсы: `StreamProvider` без `autoDispose` держит подписку, пока жив `ProviderScope`, — то есть всё время. Для 10–15 коллекций это нормально; `autoDispose` в проекте не используется нигде.

### 6.3. `async`/`await` и обработка ошибок

**`AsyncValue.when`** — на уровне виджетов, когда нужны три состояния. `lib/features/envelopes/envelope_detail_screen.dart:504`:

```dart
txs.when(
  loading: () => const Padding(
    padding: EdgeInsets.only(top: 24),
    child: Center(child: CircularProgressIndicator()),
  ),
  error: (e, _) => Text('${str.errorPrefix}: $e', ...),
  data: (list) => list.isEmpty
      ? Center(child: Text(str.noOperations, ...))
      : Container(/* список */),
)
```

Используется редко (3 места: `auth_gate.dart`, `envelope_detail_screen.dart`, `reminders_screen.dart`). Доминирует `ref.watch(p).value ?? default` — выбор в пользу простоты: главный экран показывает нули и пустые списки, пока грузится, вместо спиннеров.

**`try/catch` с типизированным исключением** — `lib/core/ai/claude_client.dart:113`:

```dart
try {
  final result = await callable.call<Object?>({...});
  final data = jsonDecode(jsonEncode(result.data));
  ...
} on FirebaseFunctionsException catch (e) {
  throw _mapError(e, op);
}
```

`_mapError` переводит коды Cloud Functions (`resource-exhausted`, `unauthenticated`) в доменные исключения `AiLimitReached`, `AiUnavailable`, `AiNetworkError` — UI не знает про Firebase.

**Централизованный guard для записи** — `lib/core/feedback.dart:29`:

```dart
Future<bool> guardWrite(
  BuildContext context,
  Strings str,
  Future<void> Function() action, {
  String reason = 'write',
}) async {
  try {
    await action();
    return true;
  } catch (error, stack) {
    unawaited(FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason, fatal: false));
    if (context.mounted) showErrorSnack(context, str.errorSaveFailed);
    return false;
  }
}
```

Все денежные записи из UI идут через него (`quick_entry_screen.dart:364` и `:387`, `data_management_screen.dart:87`): одна точка, где ошибка и показывается пользователю, и уходит в Crashlytics. Возвращает `bool`, чтобы вызывающий решил, закрывать ли экран.

**`try/catch/finally` + `mounted`** — `lib/features/settings/data_management_screen.dart:31`:

```dart
try {
  ...
  await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
} catch (_) {
  if (mounted) showErrorSnack(context, str.errorSaveFailed);
} finally {
  if (mounted) setState(() => _busy = false);
}
```

**Глобальные ловушки** — `lib/main.dart`: `FlutterError.onError` (ошибки фреймворка) и `PlatformDispatcher.instance.onError` (необработанные async-ошибки) → Crashlytics.

**`.handleError` на потоке** — `watchProEntitlement()` в `budget_repository.dart`: `.handleError((_) => false)` — ошибка доступа не должна случайно открыть Pro.

**Антипаттерн, который стоит признать:** много `catch (_)` с подавлением (`fx.dart`, `widget_service.dart`, `auth_service.dart:97`). Каждый обоснован комментарием («widget не настроен — пропустить», «имя косметическое»), но на собеседовании спросят: «а как вы узнаете, что кэш курсов перестал писаться?» — ответ: никак.

### 6.4. `Isolate` / `compute`

**Нет** (grep по `compute(` и `Isolate.` — пусто). И в текущем объёме не нужны: самые тяжёлые операции — `evalExpression` над строкой из 20 символов, фильтрация ≤1000 транзакций в `monthlySpentByEnvelopeProvider`, `jsonDecode` таблицы курсов (~160 пар). Всё это микросекунды–единицы миллисекунд, дешевле, чем копирование данных в изолят.

Когда понадобились бы в этом проекте:
- **CSV-экспорт всей истории** (`buildTransactionsCsv` в `lib/core/csv_export.dart`) при десятках тысяч транзакций — построение строки заблокирует UI-поток; `compute(buildTransactionsCsv, args)` вынес бы это.
- **Обработка фото чека** перед отправкой в AI (`receipt_scan.dart`) — сейчас `image_picker` сжимает на нативной стороне (`maxWidth: 1600, imageQuality: 80`), поэтому Dart-коду ничего тяжёлого не остаётся; если бы делали crop/resize в Dart (`package:image`), это кандидат на `compute`.
- **Аналитика за годы** — если `recentTxsProvider` расширить с 6 месяцев до «всё время».

Ограничение: в изолят нельзя передать `Envelope` с замыканиями или `BuildContext`; модели в проекте — простые immutable-классы, они сериализуемы (Dart 2.15+ умеет передавать объекты между изолятами без ручного JSON).

### 6.5. Транзакции Firestore: `runTransaction`

Две транзакции в проекте — обе в `lib/features/workdays/work_days_repository.dart` (`setDay`, `removeDay`). Остальные записи — `WriteBatch` (13 вызовов `_db.batch()` в `budget_repository.dart`, один в `accounts_repository.dart`).

```dart
Future<void> setDay(DateTime day, {double? amount}) async {
  final ref = _workDays.doc(_dayId(day));
  await _db.runTransaction((tx) async {
    // Firestore kuralı: transaction içinde TÜM okumalar yazmalardan önce.
    final snap = await tx.get(ref);
    final cashSnap = await tx.get(_cash);
    final prev = (snap.data()?['amount'] as num?)?.toDouble() ?? 0;
    final next = amount ?? 0;

    tx.set(ref, {'month': monthKeyOf(day), 'amount': amount},
        SetOptions(merge: true));
    if (next != prev) {
      final cur = (cashSnap.data()?['balance'] as num?)?.toDouble() ?? 0;
      tx.set(_cash, {'balance': cur + (next - prev)}, SetOptions(merge: true));
    }
  });
}
```

**Зачем транзакция, а не batch.** Операция — read-modify-write: нужно прочитать старую сумму дня (`prev`), чтобы начислить в кошелёк **разницу**. С обычным `get()` + batch была реальная ошибка (описана в комментарии: 25.09, 3700 ₺ начислились дважды): `get()` в офлайне/до ответа сервера читает из локального кэша, два быстрых нажатия «сохранить» оба видят `prev = 0`, и в кошелёк уходит `+3700` два раза. `runTransaction` гарантирует, что чтение сделано на сервере, и если между чтением и записью документ изменился, транзакция перезапустится с новыми данными. Двойное начисление становится невозможным.

Правило Firestore, которое нужно знать: внутри транзакции **все `get` — до первого `set/update/delete`**, иначе ошибка. В коде это соблюдено и прокомментировано.

**Почему здесь `cur + delta`, а не `FieldValue.increment`.** Комментарий: транзакция уже даёт согласованное чтение, поэтому баланс считается в одном месте из прочитанного значения; `increment` был бы избыточен и скрыл бы логику.

**Почему остальное — batch, а не transaction.** `addExpense`, `convert`, `fundGoal` не читают перед записью: они только пишут транзакцию и делают `FieldValue.increment(delta)` на балансе. `increment` атомарен на сервере сам по себе, а batch гарантирует «всё или ничего» для набора записей. Это дешевле транзакции (нет round-trip на чтение, нет retry) и работает в офлайне (транзакции в офлайне — нет: `runTransaction` требует сети). Например:

```dart
// budget_repository.dart — fundGoal
final batch = _db.batch();
batch.set(_txs.doc(), {...'goalFund': true, 'goalId': goalId});
_cashDelta(batch, -amount);                             // FieldValue.increment
batch.update(_envelopes.doc(goalId), {'balance': FieldValue.increment(amount)});
return batch.commit();
```

Исключение — `deleteTx` и `updateTx` всё же читают (`ref.get()`) перед batch; это тот же риск, что был в `setDay`. Для них это менее критично (удаление дважды одного id → второй раз `!snap.exists` → return), но если спросят «где ещё может быть гонка» — это ответ.

---

## 7. Dart 3

Проект на `sdk: ^3.11.5`, поэтому доступно всё, включая null-aware elements (3.8) и wildcard variables (3.7).

### Switch-выражения — **есть**, много

`lib/core/l10n.dart:27`:

```dart
final strProvider = Provider<Strings>((ref) {
  final lang = ref.watch(languageProvider).value ?? AppLanguage.en;
  return switch (lang) {
    AppLanguage.en => Strings.en,
    AppLanguage.tr => Strings.tr,
    AppLanguage.ru => Strings.ru,
  };
});
```

Для enum компилятор проверяет **исчерпываемость**: добавишь четвёртый язык — не скомпилируется, пока не добавишь ветку.

`lib/features/envelopes/budget_repository.dart:92`:

```dart
ThemeMode _themeModeFromCode(String? code) => switch (code) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
```

Вложенные switch-выражения — `lib/features/root/root_screen.dart:72` (`final preview = switch (kPreviewBudget) { ... _ => switch (kPreviewConverter) { ... } }`).

### Records — **есть**

Именованные записи как возвращаемый тип — `lib/core/fx_freeze.dart:35`:

```dart
({double baseAmount, double rate}) freezeToBase({
  required double amount,
  required String from,
  required String to,
  required FxSnapshot fx,
}) {
  if (from == to) return (baseAmount: _toCents(amount), rate: 1);
  final rate = _crossRate(fx, from: from, to: to);
  if (rate == null) throw FxUnavailable(from, to);
  return (baseAmount: _toCents(amount * rate), rate: rate);
}
```

Как тип провайдера — `lib/features/reminders/reminders_repository.dart:23`:

```dart
final dailyReminderProvider = Provider<({bool enabled, int hour})>((ref) {
  final p = ref.watch(profileProvider).value ?? const {};
  return (
    enabled: p['dailyReminder'] == true,
    hour: (p['dailyHour'] as num?)?.toInt() ?? 21,
  );
});
```

Как элемент списка констант — `lib/core/l10n.dart:45`: `const presetEnvelopes = <({String key, String emoji})>[...]`.

Приватный «кортеж» для возврата двух значений из метода — `budget_repository.dart`: `({double cash, Map<String, double> env}) _reversalOf(...)`, затем `rev.cash`, `rev.env`.

Позиционные записи `(a, b)` как тип — **нет** (только именованные), но они появляются в деструктуризации ниже.

### Деструктуризация — **есть**

`lib/features/accounts/accounts_repository.dart:212`:

```dart
for (final (index, id) in orderedIds.indexed) {
  batch.set(_accounts.doc(id), {'sortOrder': index}, SetOptions(merge: true));
}
```

`.indexed` возвращает `Iterable<(int, T)>` — позиционную запись, которая тут же раскладывается на две переменные. Тот же приём в `budget_repository.dart` (`addEnvelopes`), `converter_logic.dart:74`, `goals_screen.dart:59`, `paywall_sheet.dart:561` (`for (final (title, items) in _groups())`).

Деструктуризация именованных записей `final (:a, :b) = ...` или объектов `final Point(:x, :y) = p` — **нет**; в коде предпочитают `rev.cash`.

### `if-case` — **есть**, одно место

`lib/features/onboarding/onboarding_bubbles.dart:101`:

```dart
if (catalogItem(key) case final item?)
```

Паттерн `final item?` — «не null, привяжи к `item`». Это внутри collection-literal (`[...]`), т.е. `if-case` как элемент списка.

### Pattern matching в `switch` — **есть**, одно место

`lib/features/transactions/ai_add_sheet.dart:339` — switch-выражение по `Envelope?` с null-check-паттерном:

```dart
switch ((ref.watch(envelopesProvider).value ?? const <Envelope>[])
    .where((e) => e.id == item.envelopeId)
    .firstOrNull) {
  final e? => CategoryAvatar(envelope: e, size: 32),
  null => const CategoryAvatar.none(size: 32),
},
```

Паттернов с деструктуризацией объектов (`case Tx(type: TxType.expense, :final amount)`) — **нет**.

### Sealed-классы — **нет**

Иерархии результатов моделируются либо enum-ами (`SocialAuthFailure`, `TxType`, `AccountKind`), либо отдельными `Exception`-классами (`AiUnavailable`, `AiLimitReached`, `AiNetworkError` в `claude_client.dart`). Есть один class modifier: `abstract final class Poster` (`lib/features/onboarding/onboarding_palette.dart:10`) — «нельзя наследовать, нельзя инстанцировать» = namespace для констант.

Как это выглядело бы здесь — результат AI-вызова вместо трёх несвязанных исключений:

```dart
sealed class AiResult {}
final class AiOk extends AiResult { AiOk(this.input); final Map<String, dynamic> input; }
final class AiLimit extends AiResult { AiLimit(this.resetsAt); final DateTime? resetsAt; }
final class AiOffline extends AiResult {}

// на вызывающей стороне — компилятор проверит, что разобраны все три:
final text = switch (await client.call(...)) {
  AiOk(:final input)        => parse(input),
  AiLimit(:final resetsAt)  => rs.aiLimitUntil(resetsAt),
  AiOffline()               => rs.aiOffline,
};
```

Сейчас аналог — `try { } on AiLimitReached catch (e) { } on AiUnavailable { }`, и забытая ветка обнаружится только в рантайме.

### Прочее из новых версий Dart — **есть**

- **Null-aware elements** (Dart 3.8): `'envelopeId': ?envelopeId` в `budget_repository.dart:899` и `'emoji': ?emoji` в `accounts_repository.dart:129` — ключ попадает в map только если значение не null; `[?envelopeId]` — список из нуля или одного элемента. Заменяет `if (envelopeId != null) 'envelopeId': envelopeId`.
- **Wildcard variables** (Dart 3.7): `(_, _) => reschedule()` в `reminders_repository.dart:87` — два неиспользуемых параметра с одним именем `_`.
- **Enhanced enums** (Dart 2.17): `enum ProPlan { monthly(priceLabel: ...), ...; const ProPlan({...}); bool get isLifetime => ... }` в `pro_state.dart:60`; `enum AppLanguage` с полями и static-методом в `l10n.dart`.
- **`firstOrNull`** из `package:collection`-подобных расширений, теперь в SDK (`ai_add_sheet.dart:341`).


---

<a id="часть-3"></a>

# 03 — UI, анимации, локализация, тесты, платформенный код

Справочник по проекту Budgy (`/Users/timurbatyrkul/Projects/kopilka_app`). Всё ниже — по реальному коду на 2026-10-02; где чего-то нет, так и написано: «нет».

---

## 1. Темы и дизайн-система

### 1.1. Три файла, три роли

| Файл | Что в нём | Как используется |
|---|---|---|
| `lib/core/tokens.dart` | `BudgyColors extends ThemeExtension<BudgyColors>` — 28 именованных цветов + `BudgyRadii` | `context.budgy.accent` (28 файлов) |
| `lib/core/ex_style.dart` | `abstract class Ex` — те же цвета как `static const` + готовые виджеты (`ExCard`, `PrimaryButton`, `SheetFrame`, `StepBar`…) | `Ex.brand`, `Ex.bg` — по комментарию в файле «~560 использований» |
| `lib/core/palette.dart` | Старые top-level константы (`accent`, `ink`, `pastels`, `vivids`) для ещё не переписанных экранов | обратная совместимость |
| `lib/core/theme.dart` | `buildTheme()` — собирает `ThemeData` из `BudgyColors` | `app.dart`, `test/support/harness.dart` |

Ключевая идея `tokens.dart` — цвета живут не в константах, а в **`ThemeExtension`**, который кладётся в `ThemeData.extensions` и читается через `Theme.of(context)`:

```dart
// lib/core/tokens.dart
@immutable
class BudgyColors extends ThemeExtension<BudgyColors> {
  const BudgyColors({ required this.bg, required this.surface, ..., required this.envAraba });

  final Color bg;
  final Color surface;
  final Color accent; // ana yeşil
  ...
  @override
  BudgyColors copyWith({ Color? bg, ... }) { ... }

  @override
  BudgyColors lerp(ThemeExtension<BudgyColors>? other, double t) {
    if (other is! BudgyColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BudgyColors(bg: l(bg, other.bg), ...);
  }
}

/// Kısayol: `context.budgy.accent`
extension BudgyColorsX on BuildContext {
  BudgyColors get budgy => Theme.of(this).extension<BudgyColors>()!;
}
```

**Что такое `ThemeExtension` (на собеседовании):** `ThemeData` в Material 3 знает только о своих цветах (`ColorScheme`). Если приложению нужны свои семантические токены (`amberBg`, `heat0…heat4`, `envKira…envAraba`), их регистрируют как подкласс `ThemeExtension<T>`. Обязательны два метода: `copyWith` и `lerp` — второй нужен, чтобы `AnimatedTheme`/`MaterialApp` могли плавно интерполировать цвета при смене темы (поэтому в `lerp` каждый цвет прогоняется через `Color.lerp`). Достаётся он через `Theme.of(context).extension<BudgyColors>()`.

`theme.dart` — одна функция-скелет, которая получает палитру и яркость и возвращает `ThemeData`:

```dart
// lib/core/theme.dart
ThemeData _build(BudgyColors c, Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',                 // один шрифт на всё приложение
    scaffoldBackgroundColor: c.bg,
    pageTransitionsTheme: _transitions,  // свой переход страниц (см. §2)
    extensions: [c],                     // <-- вот сюда кладётся BudgyColors
    colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness, surface: c.surface, primary: c.accent),
    appBarTheme: AppBarTheme(backgroundColor: c.bg, foregroundColor: c.text, elevation: 0, ...),
    filledButtonTheme: ..., outlinedButtonTheme: ..., inputDecorationTheme: ..., chipTheme: ...,
  );
}

ThemeData buildTheme() => _build(BudgyColors.dark, Brightness.light);
ThemeData buildDarkTheme() => buildTheme();
```

Там же — кастомный переход между страницами: `_SmoothTransitions extends PageTransitionsBuilder` = `FadeTransition` + `SlideTransition` на 3,5 % высоты с `Curves.easeOutCubic`, зарегистрированный для iOS/Android/macOS в `PageTransitionsTheme`.

### 1.2. Светлая/тёмная тема — честно

**Тема одна.** В `lib/app.dart`:

```dart
theme: buildTheme(),
darkTheme: buildDarkTheme(),
// Tek tema: afişin kâğıdı. Sistem ayarı ne olursa olsun aynı.
themeMode: ThemeMode.light,
```

При этом `buildDarkTheme()` просто возвращает `buildTheme()`, а в `tokens.dart`:

```dart
// Uygulama artık yalnız koyu: [light] ve [dark] aynı palete işaret eder
static const light = dark;

static const dark = BudgyColors(
  // Afiş dili (2026-10): krem kâğıt, siyah mürekkep, beyaz kart. Ad
  // "dark" olarak kaldı çünkü uygulama hâlâ tek temalı; değerler açık.
  bg: Color(0xFFFBFAF7),
  text: Color(0xFF111111),
  accent: Color(0xFF17855D),
  ...
```

То есть палитра **называется** `dark`, но **значения светлые** (кремовая бумага `#FBFAF7`, чёрные «чернила» `#111111`, зелёный `#17855D`). Это след истории: в 2026-09 было «dark emerald», в 2026-10 перешли на «афишную» бумагу и, чтобы не трогать ~560 вызовов, поменяли значения, а не имена (`Ex.mint` теперь тёмно-зелёный, комментарий в `ex_style.dart` это прямо признаёт).

Почему `Brightness.light` обязателен — комментарий в `theme.dart`: иначе встроенные части Material (календарь, меню, выделение текста) рисуются тёмными на светлом фоне и становятся нечитаемыми.

**Важная «дыра»:** инфраструктура выбора темы существует, но не подключена.
- `lib/features/envelopes/budget_repository.dart:84` — `themeModeProvider = StreamProvider<ThemeMode>` читает `settings/main.themeMode` из Firestore; есть `watchThemeMode()` / `setThemeMode()`.
- `lib/features/onboarding/onboarding_flow.dart:303` — онбординг **записывает** `setThemeMode(_worldIsDark ? ThemeMode.dark : ThemeMode.light)`.
- Но `app.dart` **не читает** `themeModeProvider` — `themeMode: ThemeMode.light` захардкожен. Экран `settings_appearance_screen.dart` темы тоже не предлагает (там раскладка клавиатуры, язык, валюта, язык голосового ввода).

Итог: настройка сохраняется, но ни на что не влияет. На собеседовании честнее сказать «тема одна по дизайн-решению, а чтобы включить тёмную, нужно (а) завести второй `BudgyColors`, (б) заменить `ThemeMode.light` на `ref.watch(themeModeProvider).value ?? ThemeMode.system`».

### 1.3. `GradientIcon`: `ShaderMask` + `BlendMode.srcIn`

`lib/core/gradient_icon.dart`:

```dart
const kIconGradient = [Color(0xFF45BE8A), Color(0xFF0B5540)];

class GradientIcon extends StatelessWidget {
  ...
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(begin: begin, end: end, colors: colors).createShader(bounds),
      // ShaderMask maskeyi çocuğun alfasından alır; çocuğun kendi rengi
      // görünmez, yalnız şekli önemli. Beyaz veriyoruz ki alfa tam olsun.
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
```

Механизм:
1. `ShaderMask` рисует ребёнка (`Icon`) в отдельный слой (`saveLayer`), затем поверх накладывает шейдер (здесь — линейный градиент, созданный `createShader(bounds)` под размер виджета).
2. `BlendMode.srcIn` означает «показать **источник** (градиент) только там, где у **назначения** (иконки) есть альфа». Пиксели фона иконки прозрачны → градиент там отбрасывается; пиксели глифа непрозрачны → на их месте оказывается градиент.
3. Поэтому цвет иконки задаётся белым: важна только альфа, а белый гарантирует полную непрозрачность и не «подмешивается» (при `srcIn` цвет назначения игнорируется).

Почему концы градиента так далеко друг от друга (`#45BE8A` → `#0B5540`): комментарий в файле — при 18 px слабый градиент глаз воспринимает как плоский цвет; нужен заметный скачок.

### 1.4. Шрифты

`pubspec.yaml`:

```yaml
fonts:
  - family: InterDisplay
    fonts:
      - asset: assets/fonts/InterDisplay-Black.ttf
        weight: 900
      - asset: assets/fonts/InterDisplay-SemiBold.ttf
        weight: 600
  - family: Inter
    fonts:
      - asset: assets/fonts/Inter-Regular.ttf
        weight: 400
      # Inter'in metin kesiminde elimizde yalnız Regular var. Kalın
      # ağırlıklar tanımlı olmayınca Flutter 400'e düşüyor ve w600 isteyen
      # her başlık inceliyordu. Aynı ailenin display kesimlerini bu iki
      # ağırlığa bağlıyoruz: optik boy farkı gövde puntosunda görünmüyor,
      # eksik ağırlık ise göze batıyordu.
      - asset: assets/fonts/InterDisplay-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/InterDisplay-Black.ttf
        weight: 900
  - family: Caveat
    fonts:
      - asset: assets/fonts/Caveat.ttf
```

Пересказ комментария: в `assets/fonts/` лежит только `Inter-Regular.ttf` (400). Если семейству объявлен лишь один вес, Flutter при запросе `FontWeight.w600` **не синтезирует жирность**, а берёт ближайший объявленный — 400, и все заголовки выглядели тонкими. Решение: в семейство `Inter` под веса 600 и 900 подложили файлы `InterDisplay-*` (это тот же Inter, но «display»-нарезка с чуть другими оптическими пропорциями). На размерах основного текста разница оптического размера не видна, а отсутствие жирного — видна. Отдельное семейство `InterDisplay` остаётся для «героических» цифр (86 упоминаний в `lib/`, напр. центр донат-графика в `donut_chart.dart`).

`Caveat` — вариативный шрифт (один файл), вес задаётся не через `fontWeight`, а через `fontVariations` (`lib/features/onboarding/onboarding_flow.dart:895`):

```dart
style: TextStyle(
  fontFamily: 'Caveat',
  fontVariations: const [FontVariation('wght', 650)],
  ...
```

Глобальный шрифт задаётся один раз: `ThemeData(fontFamily: 'Inter')` в `theme.dart` — комментарий объясняет, что иначе системный SF Pro и Inter перемешивались от экрана к экрану.

---

## 2. Анимации и `CustomPainter`

### 2.1. Карта анимационных API в проекте

| API | Где (файлы) | Показательный пример |
|---|---|---|
| `AnimationController` | 8 файлов | `_RollInChar` (`quick_entry_screen.dart`), конфетти (`budget_completed_screen.dart`), `budgy_money_envelope.dart` |
| `TweenAnimationBuilder` | 9 файлов | `lib/core/animated_bar.dart`, `donut_chart.dart` |
| `AnimatedBuilder` | 7 файлов | `onboarding_finale.dart` с `Listenable.merge` |
| `AnimatedContainer` | 17 файлов | `StepBar` в `ex_style.dart`, кольцо выбора в `account_card.dart` |
| `AnimatedSwitcher` | 3 файла (4 вызова) | `onboarding_questions.dart:106`, `onboarding_firstday.dart:345`, `onboarding_flow.dart:578, :614` |
| `AnimatedScale` / `AnimatedOpacity` / `AnimatedSize` | 5 / 1 / 1 | `PressScale` в `motion.dart` |
| `Hero` | **нет** | grep находит только классы `_Hero` (home_screen) и `SettingsHero` (settings_hub) — это имена, а не виджет `Hero` |
| `flutter_animate` | 2 файла | только через обёртку `lib/core/motion.dart` |
| `CustomPainter` | 24 класса в 15 файлах | см. §2.3 |
| `RepaintBoundary` | 3 файла | см. §2.4 |

**`AnimationController` — `_RollInChar`** (`lib/features/transactions/quick_entry_screen.dart:893`). Каждая введённая цифра — отдельный `StatefulWidget` со своим контроллером, который запускается в инициализаторе поля:

```dart
class _RollInCharState extends State<_RollInChar> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))..forward();
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(_curve),
        child: Text(widget.char, style: widget.style),
      ),
    );
  }
}
```

Почему не `AnimatedSwitcher` — комментарий над классом: `AnimatedSwitcher` анимирует только **смену** ребёнка, а свежедобавленный в `Row` switcher показывает первого ребёнка без анимации; поэтому раньше «въезжала» только первая цифра. Решение — анимация в `initState` каждого символа. Хороший ответ на вопрос «когда implicit-анимаций недостаточно».

**`TweenAnimationBuilder`** (`lib/core/animated_bar.dart`) — implicit-анимация без контроллера: при смене `value` виджет сам анимирует от старого к новому:

```dart
return ClipRRect(
  borderRadius: BorderRadius.circular(radius),
  child: TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: height, ...),
  ),
);
```

Та же техника в `donut_chart.dart`: `Tween(begin: 0, end: 1)` на 900 мс → `progress` в `_DonutPainter`, кольцо «дорисовывается» по кругу при появлении.

**`AnimatedBuilder` + `Listenable.merge`** (`lib/features/onboarding/onboarding_finale.dart:707`) — один `CustomPaint` слушает сразу два источника: внешний `widget.fall` (падение купюр) и свой `_idle` (60-секундный дрейф):

```dart
return RepaintBoundary(
  child: AnimatedBuilder(
    animation: Listenable.merge([widget.fall, _idle]),
    builder: (_, _) => CustomPaint(
      painter: _BillRainPainter(bills: _bills, symbol: _symbol, t: widget.fall.value, idle: _idle.value * 60),
    ),
  ),
);
```

**`AnimatedContainer` + `AnimatedScale`** (`lib/features/accounts/account_card.dart:144`) — кольцо выделения карты: при `selected` масштаб 1.03 и рамка цвета `Ex.text`, обе за 180 мс `easeOutCubic`.

**`AnimatedSwitcher`** — 3 файла; например `onboarding_questions.dart:106` — «утешительный пузырь»: невидим, пока нет выбора, при смене ответа текст кросс-фейдом обновляется (комментарий: «Hareket azaltmada anında» — при reduce-motion мгновенно). В `quick_entry_screen.dart` `AnimatedSwitcher` упоминается только в комментарии — как отвергнутый вариант.

**Общая обёртка `lib/core/motion.dart`** — единственная точка входа для `flutter_animate`. Extension на `Widget`:

```dart
extension BudgyMotion on Widget {
  Widget enterUp(BuildContext context, {int index = 0, double dy = 10}) {
    if (reduceMotion(context)) return this;
    return animate(delay: kEnterStep * math.min(index, _maxEnterSteps))
        .fadeIn(duration: kEnterDuration, curve: kEnterCurve)
        .move(begin: Offset(0, dy), end: Offset.zero, duration: kEnterDuration, curve: kEnterCurve);
  }
  Widget dropIn(...)   // 420 мс, для «сценических» карточек интро
  Widget enterPop(...) // 220 мс, scale 0.92→1, для плиток
  Widget reveal(BuildContext context, {required bool visible, double dy = 12}) // target-анимация
}
```

Правила в шапке файла: только вход/смена состояния, никаких циклов; длительность ≤ 320 мс; суммарная ступенчатая задержка ≤ ~250 мс (7 × 35 мс); при «уменьшить движение» — никаких анимаций. Домашний экран (`home_screen.dart:162`) просто вызывает `const _Hero().enterUp(context, index: 0)`, `_SpendSparkline().enterUp(context, index: 1)` и т.д.

### 2.2. `BudgyMoneyEnvelope`: один контроллер на два режима

`lib/features/onboarding/widgets/budgy_money_envelope.dart` — конверт с купюрой на последнем экране онбординга. Рисуется целиком `CustomPainter`'ом (ни картинок, ни Lottie), геометрия 1:1 с `assets/icon/budgy_icon_fg.svg`.

Приём, который стоит рассказать на собеседовании:

```dart
class _BudgyMoneyEnvelopeState extends State<BudgyMoneyEnvelope> with SingleTickerProviderStateMixin {
  /// Tek controller iki işi birden görüyor: 0..1 sakin döngü, −1..0 ise
  /// mühürleme. Böylece mühürleme için ikinci bir ticker açmaya gerek yok.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: BudgyMoneyEnvelope.loop,   // 4000 мс
    lowerBound: -1,
    upperBound: 1,
  );
```

- Диапазон контроллера расширен до `[-1, 1]`. **Положительная половина** `0..1` — бесконечный «спокойный» цикл: `_ctrl.repeat(min: 0, max: 1)` (клапан приоткрывается, купюра поднимается, пауза, всё закрывается — временные метки `_tOpenEnd = 1.2/4`, `_tHoldEnd = 1.8/4`, `_tCloseEnd = 3.0/4`).
- **Отрицательная половина** `-1..0` — одноразовое «запечатывание»: когда родитель ставит `sealed: true`, в `didUpdateWidget` вызывается:

```dart
Future<void> _seal() async {
  _ctrl.stop();
  await _ctrl.animateTo(-1, duration: BudgyMoneyEnvelope.sealDuration, curve: Curves.easeInOutCubic);
  if (mounted) widget.onSealed?.call();
}
```

`animateTo(-1)` из любой точки цикла едет в минус; `await` даёт точный момент «готово» для колбэка `onSealed`, по которому страница переходит дальше.

- Значение контроллера превращается в кадр чистой функцией `_frameAt(double v)`: если `v < 0` — это `notePress = -v` (купюра опускается, клапан прижат, в последних 40 % появляется галочка `check`); если `v ≥ 0` — кусочно-линейная кривая `open` через `Curves.easeInOutSine`. Painter получает уже готовый `_Frame`, а не контроллер.

Зачем так: второй `AnimationController` = второй `Ticker`, второе `dispose`, ветвление в `build`, и две анимации пришлось бы согласовывать (остановить цикл, запомнить фазу, начать запечатывание). Здесь «фаза» — просто число, а запечатывание — `animateTo` в другую часть числовой прямой.

Доступность и производительность в том же виджете:

```dart
return Semantics(
  image: true,
  label: widget.semanticsLabel,       // приходит из RS на языке страницы
  child: RepaintBoundary(
    child: SizedBox(
      width: widget.size, height: widget.size * _kBoxHeight / _kBoxWidth,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => CustomPaint(painter: _EnvelopePainter(frame: _frameAt(_ctrl.value), symbol: _symbol)),
      ),
    ),
  ),
);
```

и в `didChangeDependencies` — реакция на «уменьшить движение»: `if (still || widget.sealed) { _ctrl.stop(); _ctrl.value = 0; } else { _ctrl.repeat(min: 0, max: 1); }` (статичная поза «клапан закрыт, купюра видна»).

Символ валюты на купюре — `ui.Paragraph`, собранный один раз в `_buildSymbol` (`ParagraphBuilder` + `layout`), а в `paint` только `canvas.drawParagraph` с `scale(0.30)` — текст не перекладывается на каждом кадре.

Тест на это: `test/widget/budgy_money_envelope_test.dart` — цикл крутится без исключений и уходит на второй круг (`hasScheduledFrame` true), при `disableAnimations` кадры **не** запрашиваются (`hasScheduledFrame` false), `onSealed` срабатывает ровно после `sealDuration`, контроллер не утекает (размонтирование без «disposed with an active Ticker»), `find.bySemanticsLabel` находит метку.

### 2.3. `CustomPainter`: что есть и как устроены 3 самых интересных

Полный список (`grep "extends CustomPainter" lib`):

- `lib/core/brand.dart` — `_EnvelopePainter` (логотип)
- `lib/features/accounts/account_card.dart` — `MetalFacePainter`, `RibbonFacePainter`, `SplitFacePainter`, `ContactlessPainter`
- `lib/features/transactions/budget_completed_screen.dart` — `_ConfettiPainter`
- `lib/features/stats/donut_chart.dart` — `_DonutPainter`
- `lib/features/envelopes/balance_chart.dart` — `_LinePainter`
- `lib/features/envelopes/home_screen.dart` — `_SparkPainter`
- `lib/features/envelopes/onboarding_story_screen.dart` — `_BranchPainter`
- `lib/features/budget/budget_ring.dart` — `_RingPainter`
- `lib/features/onboarding/…` — `_FacePainter`, `_BubbleTailPainter`, `_TickPainter` (×2), `_DashPainter`, `_ReceiptPaperPainter`, `_WorldPainter`, `_BillRainPainter`, `_BellPainter`, `_SketchArrowPainter`, `_CalendarGridPainter`, `_ReplyMarkPainter`, `_EnvelopePainter` (money envelope)

**(а) `_SparkPainter`** (`home_screen.dart:304`) — спарклайн накопленных расходов за месяц. Данные: список накопительных сумм по дням (`values`) и число дней в месяце (`totalDays`), чтобы линия занимала ровно «прожитую» долю ширины:

```dart
final stepX = size.width / (totalDays - 1).clamp(1, 1 << 30);
double x(int i) => i * stepX;
double y(double v) => size.height - (v / maxV) * (size.height - 4) - 2;

final line = Path()..moveTo(x(0), y(values[0]));
for (var i = 1; i < values.length; i++) line.lineTo(x(i), y(values[i]));
final fill = Path.from(line)..lineTo(x(values.length - 1), size.height)..lineTo(0, size.height)..close();

canvas.drawPath(fill, Paint()..shader = LinearGradient(colors: [Ex.mint.withValues(alpha: 0.14), Ex.mint.withValues(alpha: 0)]).createShader(Offset.zero & size));
canvas.drawPath(line, Paint()..color = Ex.mint..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);
canvas.drawCircle(Offset(x(values.length - 1), y(values.last)), 3.5, Paint()..color = Ex.mint);

@override
bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.totalDays != totalDays;
```

Два пути из одного: `Path.from(line)` копирует линию и замыкает её к низу — получается заливка под графиком. Тонкость `shouldRepaint`: `old.values != values` для `List` — сравнение **по ссылке**, не по содержимому. Здесь это нормально (список строится заново в `build`, значит перерисовка при каждом rebuild родителя, что дёшево), но на собеседовании стоит сказать, что для «умного» `shouldRepaint` нужно `listEquals` или неизменяемые value-объекты.

**(б) `_DonutPainter`** (`donut_chart.dart:137`) — кольцо категорий с «дорисовкой» по `progress`:

```dart
const gap = 0.03;
final limit = progress * 2 * math.pi;
var start = -math.pi / 2;  // с 12 часов
var acc = 0.0;
for (var i = 0; i < values.length; i++) {
  final sweep = values[i] / total * 2 * math.pi;
  final allowed = limit - acc;
  if (allowed > 0) {
    final draw = math.min(math.max(sweep - gap, 0.01), allowed);
    paint.color = colors[i % colors.length];
    canvas.drawArc(arcRect, start + gap / 2, draw, false, paint);
  }
  start += sweep; acc += sweep;
}

@override
bool shouldRepaint(_DonutPainter oldDelegate) =>
    oldDelegate.values != values || oldDelegate.colors != colors || oldDelegate.progress != progress;
```

`progress` приходит от `TweenAnimationBuilder` (0→1 за 900 мс), а `shouldRepaint` возвращает `true`, пока `progress` меняется, и `false`, когда анимация закончилась и данные те же — кольцо больше не перерисовывается.

**(в) `MetalFacePainter`** (`account_card.dart:322`) — «металлическая» банковская карта: два `drawRect` с низкоуровневыми шейдерами `dart:ui`:

```dart
static List<Color> stopsFor(Color c) => [
  Color.lerp(c, Colors.black, 0.18)!, Color.lerp(c, Colors.white, 0.04)!,
  Color.lerp(c, Colors.white, 0.30)!, Color.lerp(c, Colors.black, 0.14)!,
];
static const stopPositions = [0.0, 0.36, 0.56, 1.0];

void paint(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), stopsFor(color), stopPositions));
  // блик под другим углом — иначе сливается с основным градиентом
  canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(Offset(size.width * 0.15, 0), Offset(size.width * 0.85, size.height),
      [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0)], const [0.30, 0.47, 0.64]));
}

@override
bool shouldRepaint(MetalFacePainter old) => old.color != color;
```

`stopsFor` вынесен в `static`, потому что его проверяет тест (`test/widget/account_card_test.dart:205`): каждая остановка градиента должна давать контраст ≥ 4.5:1 с цветом текста карты — чтобы надпись читалась даже в самом тёмном углу.

**Про `shouldRepaint` в целом.** В проекте три паттерна: `=> false` для статичной графики (`brand.dart`, `_ReceiptPaperPainter`, `_ReplyMarkPainter`) — Flutter перерисует только если `size` изменится или painter другого класса; сравнение полей (`old.color != color`) для параметризованных; сравнение времени (`old.t != t`) для анимируемых. Главное правило: `shouldRepaint` вызывается только когда `CustomPaint` получил **новый** экземпляр painter'а; если экземпляр тот же — не вызывается вовсе.

### 2.4. `RepaintBoundary` — три разных причины

1. **Изоляция вечной анимации** — `budgy_money_envelope.dart`, `onboarding_finale.dart` (60-секундный цикл купюр). Без границы каждый кадр помечал бы «грязным» весь слой страницы; с границей перерисовывается только слой конверта/купюр.
2. **Снимок виджета в PNG** — `lib/features/insights/month_summary_card.dart:228`. Карточка месяца рендерится **за экраном** (`Positioned(left: -2000)` + `Opacity(0)` в `Overlay`), ждёт два `endOfFrame`, затем:

```dart
final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
final image = await boundary.toImage(pixelRatio: 3); // 1080x1350
final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
```

и уходит в `share_plus`. Комментарий объясняет, почему не снимать видимую карточку: тогда размер картинки зависел бы от экрана.

3. **Тот же приём в тестах** — `test/widget/onboarding_bubbles_test.dart:224` оборачивает экран в `RepaintBoundary` и пишет PNG в `$BUBBLE_PNG_DIR` для дизайн-ревью (см. §4).

### 2.5. Доступность

- **«Уменьшить движение»** — одна функция, `lib/core/motion.dart`:

  ```dart
  bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);
  ```

  Используется в 10 файлах. Все хелперы `BudgyMotion` при `true` возвращают `this` (виджет без `Animate`), `PressScale` ставит `duration: Duration.zero`, `BudgyMoneyEnvelope` останавливает контроллер в позе покоя, `_BillRain` в `onboarding_finale.dart` не вызывает `_idle.repeat()`. Тестовый harness включает `disableAnimations: true`, чтобы `pumpAndSettle` не ждал бесконечный цикл (см. §4.3).

- **`Semantics`** — 10 файлов. Самый аккуратный пример — карточка счёта (`account_card.dart:130`):

  ```dart
  return Semantics(
    container: true, button: true, enabled: onTap != null, selected: selected,
    label: '$name, ${account.currency}',
    onTap: onTap,                 // действие здесь, т.к. ниже ExcludeSemantics
    child: ExcludeSemantics(      // внутренние тексты уже в label — не читать дважды
      child: GestureDetector(onTap: onTap, ...),
  ```

  `ExcludeSemantics` ещё в `account_picker.dart` и `home_screen.dart`; `semanticsLabel` — у конверта и в `onboarding_save.dart`. `MergeSemantics` — нет. Автоматических a11y-проверок (`meetsGuideline`) — нет; есть один тест на `find.bySemanticsLabel`.

---

## 3. Локализация

### 3.1. Как сделано — не `.arb`, а Dart-классы

- `.arb`-файлов и `l10n.yaml` — **нет**. Кодогенерации (`flutter gen-l10n`) — нет.
- `flutter_localizations` подключён, но только ради **встроенных строк Material/Cupertino** (календарь, «OK», контекстное меню) — `lib/app.dart`:

  ```dart
  locale: Locale(lang.code),
  supportedLocales: [for (final l in AppLanguage.values) Locale(l.code)],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  ```

- `intl` используется для `DateFormat`/`NumberFormat` (§3.4), не для переводов.

Все строки приложения живут в двух Dart-файлах:

| Файл | Класс | Полей | Экземпляры |
|---|---|---|---|
| `lib/core/l10n.dart` (1768 строк) | `Strings` | 308 `required final` | `Strings.en` (:692), `Strings.tr` (:1053), `Strings.ru` (:1411) |
| `lib/core/redesign_l10n.dart` (2172 строки) | `RS` | 399 | `RS.en` (:869), `RS.tr` (:1306), `RS.ru` (:1739) |

`RS` появился при редизайне «чтобы не раздувать `Strings`» (комментарий в шапке). Итого ~700 ключей × 3 языка.

### 3.2. Устройство: enum → StreamProvider → Provider<Strings>

```dart
// lib/core/l10n.dart
enum AppLanguage {
  en('en', 'English'), tr('tr', 'Türkçe'), ru('ru', 'Русский');
  const AppLanguage(this.code, this.title);
  final String code; final String title;
  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.en);
}

final languageProvider = StreamProvider<AppLanguage>((ref) {
  return ref.watch(budgetRepositoryProvider).watchLanguage();   // Firestore users/{uid}/settings/main.language
});

final strProvider = Provider<Strings>((ref) {
  final lang = ref.watch(languageProvider).value ?? AppLanguage.en;
  return switch (lang) {
    AppLanguage.en => Strings.en, AppLanguage.tr => Strings.tr, AppLanguage.ru => Strings.ru,
  };
});

/// Подстановка параметров: tpl('Hello {name}', {'name': 'Tim'}).
String tpl(String template, Map<String, String> params) { ... replaceAll('{$key}', value) ... }
```

```dart
// lib/core/redesign_l10n.dart
final rsProvider = Provider<RS>((ref) => RS.of(ref.watch(strProvider).localeCode));
class RS {
  ...
  static RS of(String code) => switch (code) { 'tr' => tr, 'ru' => ru, _ => en };
```

- **Три языка**: en, tr, ru. Источник правды — документ `users/{uid}/settings/main` в Firestore (`BudgetRepository.watchLanguage()` → `AppLanguage.fromCode(doc['language'])`). Пока стрим не отдал значение — `en` (`.value ?? AppLanguage.en`). Язык устройства как дефолт **не** берётся.
- В виджетах: `final str = ref.watch(strProvider); Text(str.save)` или `final rs = ref.watch(rsProvider); Text(rs.getStarted)`.
- Параметры — через `tpl()` (51 вызов): `tpl(str.dontForgetTpl, {'x': formatMoney(amount)})`.
- При смене языка/валюты **всё дерево пересобирается** — `app.dart` оборачивает `AuthGate` в `KeyedSubtree(key: ValueKey('$symbol|${lang.code}'))`. Смена ключа уничтожает поддерево и создаёт заново, поэтому любой `State`, закешировавший строку, обновится.
- `main.dart` заранее грузит данные дат для всех трёх локалей: `for (final lang in AppLanguage.values) await initializeDateFormatting(lang.code);`.

### 3.3. Оценка подхода против `flutter_localizations` + `.arb`

Это **нестандартно**, и на собеседовании это спросят. Честный разбор:

**Плюсы**
- **Compile-time полнота**: все поля `required` в `const`-конструкторе → забытый перевод в `Strings.ru` — ошибка компиляции, а не пустая строка в рантайме. В `.arb` для этого нужен `untranslated-messages-file` и дисциплина.
- Нет кодогенерации и `build_runner`-шага для строк; нет `AppLocalizations.of(context)!` — строки доступны вне `BuildContext` (в провайдерах, в планировщике уведомлений `reminders_repository.dart`, в `widget_service.dart`).
- Всё `const`, `switch` по enum исчерпывающий (Dart 3) — добавил язык в `AppLanguage` и компилятор покажет все места.
- Язык хранится в аккаунте → синхронизируется между устройствами пользователя.

**Минусы**
- **Нет ICU**: ни плюралов (`{count, plural, …}`), ни рода, ни select. `tpl()` — наивный `replaceAll`. Русские плюралы («1 операция / 2 операции / 5 операций») надо вручную; сейчас, например, `aiSaveAllTpl: 'Сохранить {n} операций'` — неправильно для n=1, 2.
- Нет формата для переводчиков: `.arb`/XLIFF можно отдать в Crowdin/Lokalise, Dart-класс — нет.
- Два гигантских файла (~4000 строк), дублирование ключей между `Strings` и `RS` (`save`, `removeBudget` есть в обоих), нет namespace'ов.
- Строки Material всё равно требуют `flutter_localizations` — то есть стандартный механизм всё равно подключён, просто не используется для своих текстов.
- Начальный `en`-«фликер» до прихода стрима из Firestore, и нет fallback на `Localizations.localeOf`/`PlatformDispatcher.locale`.
- Для iOS-разрешений (`Info.plist`) тексты только по-турецки — `InfoPlist.strings` нет (§5.2).

Короткая формулировка для интервью: «Выбрал typed-константы ради compile-time гарантий и доступа без контекста; осознанно потерял ICU-плюрализацию и инструменты переводчиков. Для 3 языков и одного разработчика окупается, при росте команды мигрировал бы на `.arb` с `gen-l10n`».

### 3.4. Числа, даты, валюты — `lib/core/formatters.dart`

```dart
const kCurrencies = {'TRY': '₺', 'USD': '\$', 'EUR': '€', 'RUB': '₽', 'KZT': '₸', 'GBP': '£'};

var currencySymbol = '₺';   // обновляет currencySymbolProvider (budget_repository.dart:98)
var moneyLocale = 'en';     // обновляет KopilkaApp.build (app.dart:21)

NumberFormat get _money {   // кеш по локали
  if (_cachedFormat == null || _cachedLocale != moneyLocale) {
    _cachedLocale = moneyLocale;
    _cachedFormat = NumberFormat('#,##0.##', moneyLocale);
  }
  return _cachedFormat!;
}

String formatMoney(double amount) => '${_money.format(amount)} $currencySymbol';   // «12,345.5 ₺» / «12.345,5 ₺» / «12 345,5 ₺»
String formatMoneyIn(double amount, String currencyCode) => ...;                   // для конверта в другой валюте
String formatMoneyCompact(double amount) => ... '2,4k';                            // ячейка календаря
String formatDay(DateTime date, Strings str) => ... DateFormat('d MMMM, EEEE', str.localeCode).format(date);
double? parseAmount(String input) { ... }   // принимает «1 250,50» · «1.250,50» · «1,250.50» · «1250.5»
```

- Разделители тысяч/дробной части зависят от **языка интерфейса** (`moneyLocale = lang.code`), а не от локали устройства — комментарий в `app.dart` объясняет: иначе у всех печатался бы русский формат «1 234,5».
- `parseAmount` — эвристика «если два разделителя, последний — десятичный; если один и после него ровно 3 цифры — тысячный». Покрыто `test/formatters_test.dart` (14 тестов).
- `DateFormat(...)` — 30 вызовов по `lib/`, всегда с явным `localeCode` там, где важен язык (`'LLLL yyyy'`, `'E'` в `app_date_picker.dart`, `'MMM'` в `savings_screen.dart`); без локали — только технические форматы (`'yyyy-MM-dd HH:mm'` в `csv_export.dart`, ключи `'yyyy-MM'`).
- Расширенный каталог валют — `lib/core/currency_catalog.dart` (там свой `NumberFormat(pattern, moneyLocale)`).

**Что стоит признать**: `currencySymbol` и `moneyLocale` — **глобальные мутабельные переменные**, которые выставляются как побочный эффект в `build()` (`app.dart:21`) и в `Provider` (`budget_repository.dart:98`). Работает, потому что `KeyedSubtree` пересобирает всё дерево, но это нарушает чистоту `build` и усложняет тестирование (тесты полагаются на дефолт `₺`/`en`). Чистая альтернатива — передавать `MoneyFormatter` через провайдер или `InheritedWidget`.

---

## 4. Тесты

### 4.1. Инвентарь и результат

```
$ ls test            → 19 файлов *_test.dart + support/ + widget/
$ ls test/widget     → 25 файлов
$ ls test/support    → harness.dart
итого 45 .dart-файлов

$ flutter test
00:23 +806 ~7: All tests passed!
```

**806 прошло, 7 пропущено, 0 упало, ~23 секунды.** Пропущенные: 3 PNG-«снимка» (`skip: pngDir == null` в `onboarding_bubbles_test`, `onboarding_response_test`, `onboarding_receipt_test`) и 3 в `onboarding_firstday_test.dart` с `skip: 'Şimdilik atla'` / `'Skip for now'` / `'Пока пропустить'` (grep находит 6 явных `skip:`; отчёт пишет `~7`). `test/widget/_tmp_drag_test.dart` — отладочный остаток («drag debug»), который стоит удалить.

Самые крупные по числу кейсов: `budget_repository_test` (23), `budget_period_test` (20), `analytics_test` (19), `converter_test` (19), `settings_hub_test` (18), `accounts_repository_test` (17), `calc_test` (17), `account_card_test` (15), `pro_locks_test` (15), `account_picker_test` (15).

### 4.2. Какие виды тестов есть

| Вид | Есть? | Пример |
|---|---|---|
| Unit (чистая логика) | да, 19 файлов в `test/` | `test/fx_freeze_test.dart`, `test/calc_test.dart`, `test/formatters_test.dart` |
| Unit с Riverpod `ProviderContainer` | да | `test/analytics_test.dart` (override стримов, `container.read(...future)`) |
| Unit с `FakeFirebaseFirestore` | да | `test/budget_repository_test.dart`, `test/accounts_write_test.dart` |
| Widget | да, 25 файлов в `test/widget/` | `budgy_money_envelope_test`, `quick_entry_test`, `settings_hub_test` |
| Layout/overflow (ширина × язык) | да | `test/widget/screen_layout_test.dart` — 36 кейсов |
| Golden (`matchesGoldenFile`) | **нет** | — (есть «псевдо-golden»: PNG по env-переменной, без сравнения) |
| Integration (`integration_test/`) | **нет** | — |
| Firestore Security Rules | да, отдельно на Node | `test_rules/rules.test.mjs` (`@firebase/rules-unit-testing`), запуск `tool/test_rules.sh` через эмулятор |

### 4.3. `test/support/harness.dart` — как экраны открываются без Firebase

Проблема: настоящий `budgetRepositoryProvider` зависит от `uidProvider` → `FirebaseAuth`, а в тесте сессии нет и всё падает. Решение — `pumpBudgyScreen`:

```dart
Future<void> pumpBudgyScreen(WidgetTester tester, Widget screen, {
  required FakeFirebaseFirestore db,
  List<Envelope> envelopes = const [], List<Tx> transactions = const [], List<WorkDay> workDays = const [],
  double cashBalance = 0, AppLanguage language = AppLanguage.tr, String currency = 'TRY',
  Map<String, dynamic> profile = const {}, FxSnapshot? fxSnapshot,
  Size logicalSize = const Size(360, 800), EdgeInsets safeArea = EdgeInsets.zero, bool pro = false,
}) async {
  // телефонный размер вместо дефолтных 800x600 — иначе кнопка «Сохранить» за экраном
  tester.view.physicalSize = logicalSize * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  ...
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        budgetRepositoryProvider.overrideWithValue(BudgetRepository(db, testUid)),
        workDaysRepositoryProvider.overrideWithValue(WorkDaysRepository(db, testUid)),
        languageProvider.overrideWith((ref) => Stream.value(language)),
        envelopesProvider.overrideWith((ref) => Stream.value(envelopes)),
        journalProvider.overrideWith((ref) => Stream.value(transactions)),
        ...
        reminderSchedulerProvider.overrideWithValue(null),   // иначе MissingPluginException от flutter_local_notifications
        fxSnapshotProvider.overrideWith((ref, base) async => fxSnapshot),
        isProProvider.overrideWith(() => _TestProStatus(pro)),
      ],
      child: MaterialApp(
        theme: buildTheme(),                 // настоящая тема — иначе context.budgy бросит null
        locale: Locale(language.code), supportedLocales: ..., localizationsDelegates: ...,
        home: Builder(builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),   // см. ниже
          child: screen,
        )),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

Три момента, которые стоит уметь объяснить:

1. **Подмена провайдеров.** Riverpod позволяет на уровне `ProviderScope(overrides: [...])` заменить любой провайдер: `overrideWithValue` — готовым объектом (репозиторий поверх фейковой БД), `overrideWith` — другим билдером (`Stream.value(...)` вместо Firestore-стрима). Экран ничего не знает о подмене — он всё так же делает `ref.watch(envelopesProvider)`.
2. **`fake_cloud_firestore`** (`^4.2.0` в dev_dependencies) — in-memory реализация интерфейса `FirebaseFirestore`: коллекции, документы, `snapshots()`, запросы, `SetOptions(merge: true)`. Репозиторий получает `FakeFirebaseFirestore()` вместо настоящего инстанса, и весь код записи/чтения выполняется по-настоящему, но в памяти. Это **фейк**, а не мок: не нужно описывать ожидания на каждый вызов, а можно потом прочитать документ и проверить (`seedEnvelope` пишет документ заранее, чтобы `increment` сработал).
3. **`disableAnimations: true`** — все анимации входа смотрят на `reduceMotion` и мгновенно отдают финальное состояние; бесконечные циклы (точки интро) не стартуют. Без этого `pumpAndSettle` висел бы вечно, а тесты вёрстки измеряли бы «середину анимации».

`_TestProStatus extends ProStatus` — ручной фейк Notifier'а: `build() => _value`.

### 4.4. Три показательных теста

**(1) Логика: `test/fx_freeze_test.dart`** — кросс-курсы и «заморозка» курса в момент транзакции.

```dart
final _snap = FxSnapshot(base: 'USD', rates: const {'TRY': 41.0, 'AZN': 1.7, 'EUR': 0.92}, fetchedAt: DateTime(2026, 10, 1));

test('çapraz kur: ikisi de tabandan farklı (AZN → TRY)', () {
  final r = freezeToBase(amount: 100, from: 'AZN', to: 'TRY', fx: _snap);
  expect(r.rate, closeTo(41 / 1.7, 1e-12));   // 1 ₼ = 41 / 1,7 ₺
  expect(r.baseAmount, 2411.76);               // округлено до копеек
});

test('kur yoksa FxUnavailable fırlatır, uydurma rakam dönmez', () {
  expect(() => freezeToBase(amount: 5, from: 'KZT', to: 'TRY', fx: _snap),
      throwsA(isA<FxUnavailable>().having((e) => e.from, 'from', 'KZT').having((e) => e.to, 'to', 'TRY')));
});
```

Что проверяет: таблица курсов хранится относительно базы (USD), а пара AZN→TRY считается через базу; при отсутствии курса функция обязана бросить типизированное исключение, а не вернуть 0/NaN. Почему полезно: ошибка здесь — тихая порча денег пользователя; тест фиксирует и формулу, и округление (`(value*100).round/100`), и контракт ошибки. Ноль зависимостей, миллисекунды.

**(2) Widget: `test/widget/budgy_money_envelope_test.dart`** (разобран в §2.2) — проверяет не «красоту», а поведение: цикл не бросает исключений и идёт по второму кругу (`tester.binding.hasScheduledFrame`), при reduce-motion кадры не планируются, `onSealed` вызывается ровно после `sealDuration`, `AnimationController` не утекает при размонтировании, `Semantics`-метка на месте. Это ровно те вещи, которые ломаются при рефакторинге анимаций и не видны глазом.

Альтернативный, более «обычный» widget-тест — `test/widget/month_summary_test.dart`: рендерит `MonthSummaryCard` с `RS.tr`/`Strings.tr` и проверяет `find.text(formatMoney(33700))`, «10 gün çalışıldı», наличие «Budgy» на шаримой картинке и что строка категории не рисуется при `topCategory: null`.

**(3) Вёрстка: `test/widget/screen_layout_test.dart`** — 2 ширины × 6 экранов × 3 языка = 36 кейсов:

```dart
final screens = <String, Widget>{
  'Ana ekran': const HomeScreen(), 'Takvim': const CalendarScreen(), 'Hedefler': const GoalsScreen(),
  'İstatistik': const StatsScreen(), 'Geçmiş': const JournalScreen(), 'Birikim': const SavingsScreen(),
};
// 320dp: iPhone SE (1. nesil) · 360dp: en yaygın Android genişliği.
for (final width in [320.0, 360.0]) {
  for (final entry in screens.entries) {
    for (final lang in AppLanguage.values) {
      testWidgets('${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor', (tester) async {
        final db = FakeFirebaseFirestore();
        for (final e in envelopes) await seedEnvelope(db, e);
        await pumpBudgyScreen(tester, entry.value, db: db, envelopes: envelopes, transactions: transactions,
            workDays: workDays, language: lang, logicalSize: Size(width, 800));
        expect(tester.takeException(), isNull);
      });
```

Механизм: в тестовом режиме `RenderFlex` overflow — это **исключение** (в проде — жёлто-чёрная полоса), и `pumpAndSettle` его поднимает. Данные специально «толстые»: длинные имена конвертов («Market ve Temel Gıda»), валютный конверт, цель с большой суммой, 7 рабочих дней. Почему полезно: русские строки длиннее английских на 20–40 %, и переполнение обычно всплывает в сторе на iPhone SE; этот тест ловит его до релиза за секунды.

Бонус-пример про доступность цвета: `test/widget/account_card_test.dart:205` — для каждого бренда банка все остановки металлического градиента должны давать `contrastBetween(c, ink) >= 4.5`.

### 4.5. Моки

- `fake_cloud_firestore` — единственная внешняя тестовая библиотека.
- Ручные фейки: `_TestProStatus`, override'ы `Stream.value(...)`, `overrideWithValue(null)` для планировщика уведомлений, `FxSnapshot` вручную.
- `mocktail` / `mockito` — **нет** (ни в `pubspec.yaml`, ни в `test/`).
- Firebase Auth в тестах не трогается вообще — всё, что зависит от `uidProvider`, подменяется на уровне репозитория.

---

## 5. Платформенный код и сервисы

### 5.1. Platform channels

Собственных `MethodChannel`/`EventChannel` — **нет** (grep по `lib/` пуст). Весь нативный мост — через плагины. Нативный код в проекте:

- `ios/Runner/AppDelegate.swift` — `FlutterAppDelegate, FlutterImplicitEngineDelegate`, регистрирует плагины в `didInitializeImplicitFlutterEngine`; `SceneDelegate.swift` — пустой подкласс `FlutterSceneDelegate` (новый iOS scene-based lifecycle, `UIApplicationSceneManifest` в Info.plist).
- `android/.../MainActivity.kt` — `class MainActivity : FlutterFragmentActivity()`. Комментарий: «для `local_auth` нужен FragmentActivity». **Но `local_auth` в `pubspec.yaml` нет**, и в `lib/` нет ни одного упоминания biometric — биометрический замок **не реализован**, остались только артефакты: `NSFaceIDUsageDescription` в Info.plist, `USE_BIOMETRIC` в манифесте, базовый класс активити.
- Домашний виджет (единственный «настоящий» нативный код): `android/.../BudgyWidgetProvider.kt` (`HomeWidgetProvider`, `RemoteViews`, читает `SharedPreferences`) и `ios/BudgyWidget/BudgyWidget.swift` (WidgetKit, `TimelineProvider`, читает `UserDefaults(suiteName: "group.co.ggtech.kopilkaApp")`). Данные пишет `lib/core/widget_service.dart` через пакет `home_widget` (ключи `today`, `moneyLeft`, `streak` + локализованные подписи), а `widgetSyncProvider` пересчитывает их при изменении `cashBalanceProvider`/`allWorkDaysProvider`. Статус по `WIDGET_SETUP.md`: Android работает; iOS-код написан, но Xcode-target не создан (`project.pbxproj` не содержит `BudgyWidget`) — нужен платный Apple Developer для App Group.

### 5.2. Нативные настройки

**`ios/Runner/Info.plist`**
- `CFBundleDisplayName`/`CFBundleName` = Budgy; версия из `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)`.
- Разрешения (тексты **только на турецком**, `InfoPlist.strings` нет): `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (фото профиля + скан чека), `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` (голосовой ввод), `NSFaceIDUsageDescription` (см. выше — без реализации).
- URL-схемы (`CFBundleURLTypes`): `app-1-838553523218-ios-…` (Firebase) и `com.googleusercontent.apps.838553523218-…` (reversed client id для Google Sign-In) + `GIDClientID`.
- `ITSAppUsesNonExemptEncryption = false`; `CADisableMinimumFrameDurationOnPhone = true` (ProMotion 120 Гц); ориентации — портрет **и** ландшафт (вероятно, дефолт шаблона, приложение под ландшафт не верстается).

**`ios/Runner/Runner.entitlements`** — ровно одна запись:

```xml
<!-- App Store kuralı 4.8: Google/Apple gibi üçüncü taraf girişi sunan
     uygulamalarda "Sign in with Apple" ZORUNLU. -->
<key>com.apple.developer.applesignin</key>
<array><string>Default</string></array>
```

App Group для виджета пока нет (см. 5.1).

**`android/app/build.gradle.kts`**
- `namespace`/`applicationId` = `co.ggtech.kopilka_app`; `minSdk = flutter.minSdkVersion`, `targetSdk`/`compileSdk` — тоже из Flutter-дефолтов (явно не зафиксированы).
- Java 17 + `isCoreLibraryDesugaringEnabled = true` (`desugar_jdk_libs:2.1.4`) — комментарий: `flutter_local_notifications` использует `java.time`.
- Плагины `com.google.gms.google-services` и `com.google.firebase.crashlytics`.
- Release-подпись читается из `android/key.properties` (вне git); если файла нет — fallback на debug-ключ с явным комментарием «Play Console такой APK не примет». `isMinifyEnabled = true`, `isShrinkResources = true`, `proguard-rules.pro`.

**`AndroidManifest.xml`** — разрешения `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `USE_BIOMETRIC`, `INTERNET`, `RECORD_AUDIO`; receiver'ы `ScheduledNotificationBootReceiver`/`ScheduledNotificationReceiver` (восстановление расписания после перезагрузки) и `BudgyWidgetProvider`; `<queries>` для `android.speech.RecognitionService`. Строковые ресурсы локализованы (`values-tr`, `values-ru`) только для описания виджета в системном пикере.

**Flavors** — **нет** (ни `productFlavors` в Gradle, ни отдельных xcconfig/схем под dev/prod). Один Firebase-проект `kopilka-b75f6` (`firebase.json`). Вместо flavors — `--dart-define` превью-флаги в `lib/core/preview.dart` (`PREVIEW_HOME`, `PREVIEW_PRO`, `PREVIEW_PAYWALL`…), все обёрнуты в `kDebugMode`.

### 5.3. Firebase: что подключено

| Сервис | Пакет | Где инициализируется |
|---|---|---|
| Core | `firebase_core` | `main.dart`: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` |
| Auth | `firebase_auth`, `google_sign_in` | `lib/features/auth/auth_service.dart`; Apple Sign-In только на Apple-платформах (`onboarding_save.dart:51` — `!kIsWeb && (Platform.isIOS || Platform.isMacOS)`) |
| Firestore | `cloud_firestore` | репозитории |
| Crashlytics | `firebase_crashlytics` | `main.dart` (ниже) |
| App Check | `firebase_app_check` | `main.dart` `_activateAppCheck()` |
| Cloud Functions | `cloud_functions` | `lib/core/ai/claude_client.dart` — callable `aiCall` (scan/parse/advice) с месячными лимитами на сервере |
| Analytics | — | **нет** |
| Messaging (push) | — | **нет** |

Crashlytics, `lib/main.dart`:

```dart
final crashlytics = FirebaseCrashlytics.instance;
await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);   // в debug выключен

FlutterError.onError = (details) {               // ошибки фреймворка: build/layout/paint
  FlutterError.presentError(details);
  crashlytics.recordFlutterFatalError(details);
};
PlatformDispatcher.instance.onError = (error, stack) {   // непойманные async-ошибки вне фреймворка
  crashlytics.recordError(error, stack, fatal: true);
  return true;
};
```

App Check — провайдеры по режиму сборки, и **не роняет** приложение при ошибке конфигурации:

```dart
await FirebaseAppCheck.instance.activate(
  providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
  providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestWithDeviceCheckFallbackProvider(),
);
} catch (error, stack) {
  await FirebaseCrashlytics.instance.recordError(error, stack, reason: 'appCheck', fatal: false);
}
```

### 5.4. Уведомления — локальные, не push

`flutter_local_notifications` + `timezone` + `flutter_timezone`. Push (`firebase_messaging`) — **нет**.

`lib/core/notifications.dart` — статический класс `Notifications`:
- `init()` — `tz_data.initializeTimeZones()`, локальная зона через `FlutterTimezone.getLocalTimezone()`, `_plugin.initialize(...)`, запрос разрешений iOS (`requestPermissions`) и Android 13+ (`requestNotificationsPermission` — комментарий: без него напоминания вообще не покажутся).
- `scheduleMonthly(id, title, body, day, channelName, channelDescription)` — `zonedSchedule` на 10:00 с `matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime`; день месяца **клампится** к длине месяца (`_monthlyAt`: 31-е в 30-дневном месяце → 30-е, иначе уехало бы в следующий месяц).
- `scheduleDaily` (`DateTimeComponents.time`), `scheduleWeekly` (`dayOfWeekAndTime`), `cancelAll`.
- Всё с `AndroidScheduleMode.inexactAllowWhileIdle`; названия каналов приходят из `Strings` (они видны в системных настройках Android).

Где планируется — `lib/features/reminders/reminders_repository.dart:33`, `reminderSchedulerProvider`: при любом изменении списка напоминаний в Firestore **всё отменяется и пересоздаётся**:

```dart
await Notifications.cancelAll();
for (final reminder in reminders) {
  for (var day = reminder.fromDay; day <= reminder.toDay; day++) {
    await Notifications.scheduleMonthly(
      id: Object.hash(reminder.id, day) & 0x7fffffff,   // детерминированный 31-битный id
      title: reminder.name,
      body: reminder.amount != null ? tpl(str.dontForgetTpl, {'x': formatMoney(reminder.amount!)}) : str.dontForgetPlain,
      day: day, channelName: str.channelPaymentsName, channelDescription: str.channelPaymentsDesc,
    );
  }
}
if (daily.enabled) await Notifications.scheduleDaily(id: 990001, ...);
```

Провайдер достаточно один раз `watch`-нуть на корневом экране. В тестах он подменяется на `null` (harness), иначе `MissingPluginException`.

### 5.5. Подписки / IAP — честно: заглушка

- `in_app_purchase`, `purchases_flutter` (RevenueCat) — **нет в pubspec**.
- `lib/features/pro/pro_state.dart`:

```dart
// ŞİMDİLİK YEREL: gerçek abonelik RevenueCat üzerinden gelecek. ... Apple Developer
// hesabı onaylanmadan mağazada ürün tanımlanamadığı için şimdilik bağlanamıyor.
final isProProvider = NotifierProvider<ProStatus, bool>(ProStatus.new);

class ProStatus extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(proEntitlementProvider, (_, next) { if (next.value ?? false) state = true; }, fireImmediately: true);
    return kPreviewPro || (ref.read(proEntitlementProvider).value ?? false);
  }
  void set(bool value) => state = value;
}

final proEntitlementProvider = StreamProvider<bool>((ref) => ref.watch(budgetRepositoryProvider).watchProEntitlement());
// → users/{uid}/entitlements/pro, поле pro == true; по rules клиенту read-only (выдаётся из консоли)
```

- Планы `ProPlan` (monthly ₺69,99 / yearly ₺569 / lifetime ₺3.999,99) — захардкоженные строки, с комментарием, что реальные цены придут из стора.
- `paywall_sheet.dart:_subscribe()` — показывает снэк `rs.paywallSoon` («скоро»), покупки нет.
- Что **реально работает**: `ProGate`/`requirePro`/`ProBadge` (`pro_gate.dart`) блокируют `ProFeature.analytics / aiEntry / automation`, paywall открывается, Pro включается серверной записью в Firestore или `--dart-define=PREVIEW_PRO=true`. Покрыто `pro_locks_test` (15) и `paywall_test` (5). Точка будущей интеграции обозначена одна — `ProStatus.build`.

### 5.6. Splash screen

`flutter_native_splash` (dev-зависимость), конфиг в `pubspec.yaml`:

```yaml
flutter_native_splash:
  color: "#FBFAF7"              # = Ex.bg — чтобы не было скачка цвета при переходе на первый экран
  image: assets/icon/budgy_splash.png
  android_12:
    color: "#FBFAF7"
    image: assets/icon/budgy_splash.png
  ios: true
  android: true
```

Сгенерировано: `ios/Runner/Base.lproj/LaunchScreen.storyboard` (полноэкранный `LaunchBackground` + центрированный `LaunchImage`), `android/.../drawable/launch_background.xml` (`background.png` + `splash.png`), `drawable-*/android12splash.png`, `values-v31/styles.xml` с `windowSplashScreenBackground = #FBFAF7`, плюс `values-night*` варианты. Иконка — `flutter_launcher_icons.yaml` (`budgy_icon_1024.png`, adaptive foreground `budgy_icon_fg.png`, фон `#07090A` — остаток тёмной темы).

Flutter-стороннего splash-экрана поверх (например, `AnimatedSplash`) нет: после нативного сразу `AuthGate`.


---

<a id="часть-4"></a>

# Путь данных: от нажатия кнопки до обновления экрана

Разберём один реальный сценарий: **пользователь добавляет расход**. Это самый
частый путь в приложении, и он проходит через все слои.

---

## Шаг 1. Экран — `lib/features/transactions/quick_entry_screen.dart`

```dart
class QuickEntryScreen extends ConsumerStatefulWidget {
```

Это `ConsumerStatefulWidget`, а не `ConsumerWidget`, потому что у экрана есть
**собственное локальное состояние**: введённая сумма, выбранная категория,
дата, флаг `_saving`. Это состояние никому, кроме экрана, не нужно — поэтому
оно живёт в `State`, а не в провайдере.

> **Важное различие для собеседования.** `setState` здесь используется только
> для UI-состояния формы (`_saving`, выбранная категория). Данные приложения
> через `setState` не ходят вообще — для них Riverpod.

Кнопка «Сохранить» вызывает `_save()`:

```dart
onPressed: canSave ? _save : null,
```

---

## Шаг 2. Обработчик — читает репозиторий через `ref.read`

```dart
Future<void> _save() async {
  final amount = _amount;
  if (amount <= 0 || _saving) return;
  setState(() => _saving = true);
  final repo = ref.read(budgetRepositoryProvider);
  final str = ref.read(strProvider);
```

**Почему `ref.read`, а не `ref.watch`?** `watch` подписывается на изменения и
перестраивает виджет. В обработчике нажатия перестраивать нечего — нужно
просто один раз взять объект и вызвать метод. Правило: `watch` в `build`,
`read` в колбэках.

`if (... || _saving) return;` — защита от двойного нажатия: пока идёт запись,
второй вызов ничего не делает.

---

## Шаг 3. Обёртка записи — `lib/core/feedback.dart`

```dart
Future<bool> guardWrite(
  BuildContext context,
  Strings str,
  Future<void> Function() action, {
  String reason = 'write',
}) async {
  try {
    await action();
    return true;
  } catch (error, stack) {
    unawaited(FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason, fatal: false));
    if (context.mounted) showErrorSnack(context, str.errorSaveFailed);
```

Каждая запись, которая трогает деньги, обёрнута в `guardWrite`. Он делает три
вещи: показывает пользователю понятное сообщение, **не проглатывает ошибку**
(отправляет в Crashlytics), и проверяет `context.mounted` — потому что после
`await` экран мог уже закрыться.

---

## Шаг 4. Репозиторий — `lib/features/envelopes/budget_repository.dart`

```dart
id = await repo.addExpense(
  envelopeId: envelopeId,
  envelopeName: envelopeName,
  amount: amount,
  currency: currency,
  note: note,
  date: date,
);
```

Внутри `addExpense` создаётся **батч** — пакет операций, который применяется
целиком или не применяется вовсе:

```dart
final batch = _db.batch();
final doc = _txs.doc();
_writeExpense(batch, doc, /* ... */);
await batch.commit();
```

`_writeExpense` кладёт в батч **две** операции:

```dart
batch.set(doc, {
  'type': TxType.expense.name,
  'amount': amount,
  'date': Timestamp.fromDate(date),
  // ...
});
if (accountId != null) {
  batch.update(_accounts.doc(accountId), {
    'balance': FieldValue.increment(-amount),
  });
} else if (currency == 'TRY') {
  _cashDelta(batch, -amount);
}
```

**Зачем батч.** Запись операции и изменение баланса должны произойти вместе.
Если бы это были два отдельных запроса и второй упал — в базе осталась бы
трата без списания с баланса, то есть неверные цифры навсегда.

`FieldValue.increment(-amount)` — атомарный инкремент на стороне сервера.
Мы не читаем баланс, не вычитаем в приложении и не записываем обратно: при
таком подходе два одновременных списания с разных устройств затёрли бы друг
друга.

---

## Шаг 5. Firestore

Документы ложатся в дерево пользователя:

```
users/{uid}/transactions/{autoId}   ← сама операция
users/{uid}/accounts/{accountId}    ← баланс карты
```

Доступ ограничен правилами в `firestore.rules`: пользователь видит и пишет
только своё поддерево.

---

## Шаг 6. Поток возвращается в приложение — `StreamProvider`

Никто не говорит экрану «обновись». Экран подписан на поток:

```dart
final recentTxsProvider = StreamProvider<List<Tx>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 5);
  final end = DateTime(now.year, now.month + 1);
  return ref.watch(budgetRepositoryProvider).watchTxsBetween(start, end);
});
```

`watchTxsBetween` возвращает `.snapshots()` — поток Firestore, который
выдаёт новое значение при каждом изменении данных.

> **Тонкость, которую любят спрашивать.** Firestore отдаёт изменение из
> локального кэша **сразу**, ещё до подтверждения сервера. Поэтому список
> обновляется мгновенно, даже при плохой сети, а если запись в итоге не
> пройдёт — поток откатит значение. Это называется оптимистичным обновлением,
> и здесь оно досталось бесплатно, без ручного кода.

---

## Шаг 7. Производные провайдеры пересчитываются

Над потоком построена цепочка обычных `Provider` — они не ходят в сеть, а
только считают:

```dart
final currentMonthTxsProvider = Provider<List<Tx>>((ref) {
  final txs = ref.watch(recentTxsProvider).value ?? const [];
  // ... фильтр по текущему месяцу
});
```

Комментарий в коде объясняет, почему поток ограничен диапазоном дат, а не
количеством: при лимите по количеству суммы «за месяц» начали бы молча врать,
когда операций станет больше лимита.

---

## Шаг 8. Экран перестраивается

```dart
final spent = ref.watch(monthSpentProvider);
```

`_Hero` в `lib/features/envelopes/home_screen.dart` смотрит на
`monthSpentProvider`. Тот зависит от `recentTxsProvider`. Поток выдал новое
значение → провайдер пересчитался → виджет перестроился. Цифра на чёрной
карточке меняется сама.

---

## Вся цепочка одним списком

| Шаг | Файл | Что происходит |
|---|---|---|
| 1 | `transactions/quick_entry_screen.dart` | нажатие, локальное состояние формы |
| 2 | там же, `_save()` | `ref.read` репозитория |
| 3 | `core/feedback.dart` | `guardWrite`: try/catch + Crashlytics + снекбар |
| 4 | `envelopes/budget_repository.dart` | `WriteBatch`: документ + `FieldValue.increment` |
| 5 | Firestore | `users/{uid}/transactions`, `users/{uid}/accounts` |
| 6 | `budget_repository.dart` | `StreamProvider` поверх `.snapshots()` |
| 7 | те же провайдеры | производные `Provider` пересчитывают суммы |
| 8 | `envelopes/home_screen.dart` | `ref.watch` → `build` → новая цифра |

**Главная мысль:** поток данных односторонний. Экран не обновляет сам себя
после записи — он пишет в базу и ждёт, пока изменение вернётся по потоку.
Поэтому одни и те же данные на всех экранах всегда согласованы: источник
истины один.


---

<a id="часть-5"></a>

# Чего в проекте нет, но про это спросят

Ниже — технологии, которые ждут от junior/middle Flutter-разработчика. Для
каждой: что это, почему в Budgy этого нет, и как бы это выглядело именно
здесь. Отвечать на собеседовании честно «у нас этого нет, потому что…»
сильнее, чем делать вид, что знаешь.

---

## REST, Dio, http, interceptors, Retrofit

**Что это.** Классический стек: приложение ходит на HTTP-эндпоинты, `Dio`
добавляет интерцепторы (логирование, подстановка токена, повтор запроса),
`Retrofit` генерирует клиент из аннотаций.

**Почему нет.** Бэкенд — Firestore. Его SDK общается с сервером по
собственному протоколу (gRPC), держит соединение и сам шлёт обновления.
Писать поверх него REST было бы шагом назад.

**Где HTTP всё-таки есть.** `lib/core/fx.dart` — курсы валют тянутся с
`open.er-api.com` через `HttpClient` из `dart:io`, с файловым кэшем на 6
часов. Один запрос, без авторизации — ради него подключать `Dio` смысла нет.

**Как бы выглядело здесь.** Если бы бэкенд был своим: `Dio` с
`InterceptorsWrapper`, в `onRequest` — подстановка `Authorization`, в
`onError` — ловля 401, обновление токена и повтор запроса. Сейчас эту работу
делает Firebase SDK: токен обновляется сам, и в коде приложения его нет.

---

## Refresh token

**Что это.** Access-токен живёт минуты, refresh-токен — недели; по нему
молча получают новый access.

**Почему нет в коде.** Firebase Auth делает это внутри себя. `FirebaseAuth`
хранит refresh-токен, обновляет ID-токен каждый час и пишет результат в
`authStateChanges()`. В приложении токена не видно нигде — и это правильно.

**Что сказать.** «Ротацией токенов занимается Firebase SDK; руками я её не
писал, но понимаю схему: короткий access + длинный refresh + повтор запроса при
401».

---

## BLoC / Cubit

**Что это.** Второй по популярности подход к состоянию: события входят,
состояния выходят, между ними — bloc.

**Почему нет.** Выбран Riverpod. Основная причина — природа данных: это
потоки из Firestore. `StreamProvider` оборачивает поток в одну строку, а
производные `Provider` пересчитывают суммы без единого слушателя больше.

**Как бы выглядело здесь.** `TransactionsBloc` с событиями
`AddExpenseRequested`, `TransactionsSubscribed` и состояниями
`TransactionsLoading / Loaded / Failure`. Поток Firestore пришлось бы
подписывать вручную в блоке и не забыть отписаться — Riverpod делает это сам.

---

## json_serializable / freezed

**Что это.** Кодогенерация моделей: `fromJson`/`toJson`, `copyWith`,
`==`/`hashCode`, sealed-классы состояний.

**Почему нет.** Модели пишутся вручную: `Tx.fromDoc`, `Account.fromDoc`,
`Envelope.fromDoc`. Для Firestore это даже естественнее — на вход приходит
`DocumentSnapshot`, у которого есть `id` отдельно от данных; `fromJson(Map)`
его бы потерял.

**Цена.** `copyWith` у `Account` написан руками (и это видно), `==` у моделей
нет. При росте числа полей ручной код начнёт отставать от схемы.

---

## get_it / injectable

**Что это.** Service locator и генератор DI.

**Почему нет.** Роль DI выполняют провайдеры Riverpod:
`budgetRepositoryProvider` собирает репозиторий из `FirebaseFirestore` и
`uid`, а в тестах подменяется одной строкой через `overrideWithValue`. Это и
есть внедрение зависимости, только без отдельной библиотеки.

---

## go_router / auto_route

**Что это.** Декларативная навигация, маршруты как данные, deep links.

**Почему нет.** В приложении ~32 `Navigator.push(MaterialPageRoute(...))` и
условный рендеринг на верхнем уровне (`auth_gate.dart`). Для приложения без
веб-версии и без диплинков этого хватает.

**Чего из-за этого нет.** Диплинков («открыть конкретную трату по ссылке»),
восстановления стека после убийства приложения, типизированных параметров
маршрута.

---

## Локальная БД: Hive, Isar, drift, sqflite

**Почему нет.** Офлайн обеспечивает сам Firestore: его кэш включён по
умолчанию, запись уходит в локальный кэш мгновенно и синхронизируется, когда
появится сеть. Отдельная локальная БД дублировала бы это и создала вторую
точку истины.

**Что хранится локально:** файловый кэш курсов валют (`lib/core/fx.dart`),
App Group для виджета, расписание локальных уведомлений. Всё остальное — в
Firestore.

---

## secure storage

**Почему не понадобился.** В приложении нечего прятать: токены держит
Firebase SDK в системном хранилище, ключ Anthropic лежит в Google Secret
Manager и доступен только Cloud Function. Пароли приложение не хранит.

---

## isolate / compute

**Почему нет.** Нет тяжёлых вычислений: самые дорогие операции — суммы по
нескольким сотням документов, это микросекунды.

**Когда понадобился бы.** Разбор CSV-выписки банка на тысячи строк или
локальная категоризация большого архива — вот это ушло бы в `compute`.

---

## Golden- и integration-тесты

**Что это.** Golden сравнивает отрисованный виджет с эталонным PNG;
integration гоняет приложение целиком на устройстве.

**Почему нет.** Есть 806 unit- и widget-тестов, включая layout-тесты на
переполнение (320dp × 3 языка). Golden не заведены, хотя проект визуальный и
они бы подошли.

---

## Analytics

Подключены Crashlytics и App Check, но `firebase_analytics` — нет. То есть
падения видны, а поведение пользователей не измеряется: нельзя ответить
«сколько людей дошло до конца онбординга».

---

## Подписки (in-app purchase)

**Честная формулировка:** монетизация **не реализована**. Есть paywall, есть
gate (`isProProvider`), есть точка интеграции, но покупка не совершается —
`_subscribe()` показывает «скоро», цены захардкожены, статус Pro ставится
вручную в консоли Firestore. RevenueCat не подключён.

Говорить «сделал подписки» нельзя. Говорить «спроектировал gate и paywall,
оставил точку интеграции под RevenueCat» — можно.


---

<a id="часть-6"></a>

# Шпаргалка: вопросы и ответы

Вопросы, которые реально задают про такой проект, и ответы, опирающиеся на
настоящий код. Коротко — чтобы можно было сказать вслух за 30–60 секунд.

---

**1. Расскажи про проект в двух словах.**
Budgy — приложение для учёта личных денег по методу «конвертов». Flutter +
Firebase, три языка, ~45 экранов. Написан один, от модели данных до анимаций.
Особенность — учёт в нескольких валютах: можно получать зарплату в лирах и
тратить с азербайджанской карты в манатах.

**2. Почему Riverpod, а не BLoC или Provider?**
Данные приходят потоками из Firestore. `StreamProvider` оборачивает поток в
одну строку, а производные `Provider` считают поверх него без лишних
подписок: один слушатель Firestore кормит десяток вычислений. В BLoC пришлось
бы подписываться и отписываться руками. Плюс Riverpod умеет подменяться в
тестах — весь `test/support/harness.dart` на этом построен.

**3. Какая версия Riverpod и какой API?**
Riverpod 3, новый API. `Notifier`/`NotifierProvider` — один (`ProStatus`),
остальное — `Provider`, `StreamProvider`, `FutureProvider`, есть `.family`.
`StateNotifier` не использую — он устарел.

> Честно добавь: `riverpod_generator` и `build_runner` лежат в pubspec, но ни
> одной аннотации `@riverpod` нет. Это остаток, надо убрать.

**4. Где у тебя бизнес-логика?**
В репозиториях. `BudgetRepository` держит все денежные инварианты: запись
операции и изменение баланса идут одним `WriteBatch`, откат операции считает
`_reversalOf`. Виджеты только показывают и вызывают.

> Слабое место, назови сам: `_save()` в `quick_entry_screen.dart` — около 130
> строк оркестрации прямо в `State`. Правильнее было бы вынести в контроллер.

**5. Как у тебя хранятся данные?**
Всё в Firestore, в поддереве пользователя: `users/{uid}/transactions`,
`/envelopes`, `/accounts`, `/settings/main`. Локальной БД нет — офлайн-кэш
Firestore включён по умолчанию: запись уходит в кэш мгновенно и
синхронизируется, когда появится сеть. Локально лежит только кэш курсов валют.

**6. Как обеспечиваешь согласованность баланса?**
Операция и изменение баланса пишутся одним батчем — или применяются вместе,
или не применяются вовсе. Баланс меняю через `FieldValue.increment`, а не
«прочитал, вычел, записал»: иначе два одновременных списания с разных
устройств затрут друг друга.

**7. Был реальный баг на этой почве?**
Да, и это моя любимая история. В кассе появились лишние 3700 ₺. Причина:
`setDay` читал баланс, прибавлял разницу и записывал обратно. Из-за
офлайн-кэша Firestore чтение успевало вернуть старое значение, и прибавка
применялась дважды. Починил через `runTransaction` — там чтение и запись
атомарны. Код в `work_days_repository.dart`, в комментарии описан сам баг.

**8. Как работает авторизация?**
Приложение всегда входит анонимно при первом запуске, чтобы можно было
пользоваться без регистрации. Когда человек нажимает «войти через Google», я
вызываю `linkWithCredential` — он привязывает Google к существующему
анонимному аккаунту, uid не меняется, все данные остаются. Если этот Google
уже привязан к другому аккаунту, ловлю `credential-already-in-use` и делаю
обычный `signInWithCredential`.

**9. Почему Google через `google_sign_in`, а не через Firebase?**
Сначала был федеративный поток Firebase — он открывает Safari со страницей
`<проект>.firebaseapp.com`, и Google показывает пользователю не имя
приложения, а этот домен. Выглядит подозрительно. Нативный SDK открывает
системный выбор аккаунта и показывает «Budgy».

**10. Где хранится API-ключ для AI?**
Нигде в приложении. Ключ лежит в Google Secret Manager, приложение вызывает
Cloud Function `aiCall`, она уже ходит в Anthropic. Модель и лимит токенов
задаются на сервере — клиент не может их подменить, иначе счётчики расходов
не имели бы смысла.

**11. Как тестируешь?**
806 тестов, проходят за 23 секунды. Unit — на чистую логику (курсы валют,
аналитика, разбор сумм). Widget — на экраны, с `fake_cloud_firestore` вместо
настоящей базы и подменой провайдеров через `overrideWith`. Отдельно —
layout-тесты: каждый экран рендерится на 320 и 360 dp на трёх языках, и
переполнение вёрстки считается падением теста.

**12. Что сложного было в анимациях?**
Конверт на финальном экране онбординга: один `AnimationController` с
`lowerBound: -1` обслуживает и бесконечный спокойный цикл (0…1), и
«запечатывание» после входа (−1…0). Кадр считает чистая функция `_frameAt`,
поэтому одно и то же значение всегда даёт одну картинку — это тестируемо.
Плюс `RepaintBoundary`, `Semantics` и уважение к «уменьшить движение».

**13. Как сделана локализация?**
Своя: классы `Strings` и `RS` с полями на трёх языках, язык берётся из
Firestore через провайдер. `.arb` и `flutter_localizations` для своих строк
не использую.

> Назови минус сам: нет ICU-плюралов, поэтому русские формы «1 операция / 2
> операции / 5 операций» сейчас неверны. На `.arb` это решилось бы из коробки.

**14. Тёмная тема есть?**
Нет. Приложение сегодня светлое: `themeMode: ThemeMode.light` задан жёстко.
Тёмная тема была раньше, и от неё остались `themeModeProvider` и экран выбора
темы — настройка сохраняется, но не применяется. Это долг, и я знаю, как его
закрыть.

**15. Что бы ты сделал по-другому?**
Три вещи. Разбил бы `BudgetRepository` — он вырос до тысячи строк и держит
всё сразу. Вынес бы оркестрацию из `_save()` в контроллер. И завёл бы
кодогенерацию моделей: сейчас `fromDoc`/`toMap` пишутся руками и при росте
схемы начнут отставать.

**16. Что в проекте не доделано?**
Отвечай прямо, это сильнее, чем умалчивать:
- подписки — есть paywall и gate, но покупка не совершается, RevenueCat не
  подключён;
- замороженный курс валют спроектирован и покрыт тестами, но экран записи
  ещё не передаёт его в репозиторий;
- три экрана восстановления пароля — макеты без логики;
- Cloud Function не проверяет App Check.

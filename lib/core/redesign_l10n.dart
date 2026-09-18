import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';

/// Yeni tasarımın (onboarding + ana ekran) metinleri. Büyük [Strings]
/// sınıfını şişirmemek için ayrı tutuldu; dil yine uygulama dilinden gelir.
final rsProvider =
    Provider<RS>((ref) => RS.of(ref.watch(strProvider).localeCode));

class RS {
  const RS({
    required this.onbTitle,
    required this.onbSubtitle,
    required this.featVoice,
    required this.featCurrency,
    required this.featCloud,
    required this.featNoSignup,
    required this.next,
    required this.haveAccount,
    required this.currencyTitle,
    required this.currencySubtitle,
    required this.continueWithTpl,
    required this.chooseAnother,
    required this.searchCurrency,
    required this.walletTitle,
    required this.walletSubtitle,
    required this.letsGo,
    required this.customize,
    required this.defaultWalletName,
    required this.startingAmount,
    required this.otherCurrencies,
    required this.otherCurrenciesHint,
    required this.addCurrencyWallet,
    required this.startingBalance,
    required this.currencyWalletTpl,
    required this.amount,
    required this.name,
    required this.icon,
    required this.color,
    required this.currency,
    required this.save,
    required this.spentInTpl,
    required this.budgetEmpty,
    required this.setBudget,
    required this.monthlyBudget,
    required this.leftTpl,
    required this.overTpl,
    required this.ofTpl,
    required this.daysLeftTpl,
    required this.removeBudget,
    required this.accounts,
    required this.cash,
    required this.addAccount,
    required this.recent,
    required this.recentEmpty,
    required this.seeAll,
    required this.dailyReminder,
    required this.dailyReminderSub,
    required this.calendar,
    required this.goals,
    required this.stats,
    required this.settings,
    required this.customizeWallet,
    required this.ratesTitle,
    required this.ratesNote,
    required this.ratesUnavailable,
    required this.scanTitle,
    required this.camera,
    required this.gallery,
    required this.scanning,
    required this.aiKeyMissing,
    required this.scanFailed,
    required this.enterAmount,
    required this.saveAllTpl,
    required this.expense,
    required this.income,
    required this.today,
    required this.noRepeat,
    required this.repeat,
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.note,
    required this.noteHint,
    required this.pickCategory,
    required this.calculatorMode,
    required this.multiMode,
    required this.savedCountTpl,
    required this.saved,
    required this.undo,
    required this.yourCategories,
    required this.newCategory,
    required this.searchCategory,
    required this.reviewTpl,
    required this.reviewTitle,
    required this.noCategory,
    required this.recurringTitle,
    required this.recurringEmpty,
    required this.nextTpl,
    required this.delete,
    required this.account,
    required this.dateTitle,
    required this.quickEntryTitle,
    required this.budgetTitle,
    required this.analyticsTitle,
    required this.noBudget,
    required this.noBudgetSub,
    required this.createBudget,
    required this.editBudget,
    required this.budgetAmountHint,
    required this.lastDaysTpl,
    required this.weeklyPeriod,
    required this.monthlyPeriod,
    required this.weekStartTpl,
    required this.continueLabel,
    required this.skipNote,
    required this.categoryBudgets,
    required this.allocatedTpl,
    required this.suggest,
    required this.suggestHint,
    required this.skip,
    required this.weeklyBudget,
    required this.noCategoriesYet,
    required this.overAllocated,
    required this.spentOfTpl,
    required this.allCategories,
    required this.spending,
    required this.byCategory,
    required this.expensesTpl,
    required this.topCategory,
    required this.mostPurchases,
    required this.busiestDay,
    required this.avgPerDay,
    required this.notEnoughData,
    required this.shareTpl,
    required this.purchasesTpl,
    required this.daysTpl,
    required this.weekStartLabel,
    required this.oneExpense,
    required this.onePurchase,
    required this.spaceSubtitle,
    required this.manage,
    required this.appSection,
    required this.accountSection,
    required this.helpSection,
    required this.categories,
    required this.tags,
    required this.tagsEmpty,
    required this.tagsHint,
    required this.automation,
    required this.automationHint,
    required this.builtinRulesTpl,
    required this.yourRules,
    required this.addKeyword,
    required this.keyword,
    required this.keywordHint,
    required this.ruleDisabled,
    required this.keypadLayout,
    required this.keypadTop,
    required this.keypadBottom,
    required this.voiceLanguage,
    required this.voiceAppLanguage,
    required this.searchLanguage,
    required this.dataManagement,
    required this.exportCsv,
    required this.exportCsvHint,
    required this.deleteAllData,
    required this.deleteAllDataHint,
    required this.deleteAllDataConfirm,
    required this.deleteAllDataConfirm2,
    required this.deleteAllDone,
    required this.paymentReminders,
    required this.privacyPolicy,
    required this.about,
    required this.versionTpl,
    required this.archived,
    required this.archive,
    required this.unarchive,
    required this.deleteCategoryTpl,
    required this.categoryCountTpl,
    required this.notInUse,
    required this.tapToAdd,
    required this.edit,
    required this.converterTitle,
    required this.starHint,
    required this.starLimit,
    required this.ratesUpdatedTpl,
    required this.justNow,
    required this.minutesAgoTpl,
    required this.hoursAgoTpl,
    required this.daysAgoTpl,
    required this.ratesOffline,
    required this.selectCurrency,
    required this.suggested,
    required this.allCurrencies,
    required this.removeRow,
    required this.newCategoryTitle,
    required this.editCategoryTitle,
    required this.categoryName,
    required this.sectionLabel,
    required this.noSection,
    required this.sectionHint,
    required this.useLetter,
    required this.chooseEmoji,
  });

  final String onbTitle;
  final String onbSubtitle;
  final String featVoice;
  final String featCurrency;
  final String featCloud;
  final String featNoSignup;
  final String next;
  final String haveAccount;
  final String currencyTitle;
  final String currencySubtitle;
  final String continueWithTpl;
  final String chooseAnother;
  final String searchCurrency;
  final String walletTitle;
  final String walletSubtitle;
  final String letsGo;
  final String customize;
  final String defaultWalletName;
  final String startingAmount;
  final String otherCurrencies;
  final String otherCurrenciesHint;
  final String addCurrencyWallet;
  final String startingBalance;
  final String currencyWalletTpl;
  final String amount;
  final String name;
  final String icon;
  final String color;
  final String currency;
  final String save;
  final String spentInTpl;
  final String budgetEmpty;
  final String setBudget;
  final String monthlyBudget;
  final String leftTpl;
  final String overTpl;
  final String ofTpl;
  final String daysLeftTpl;
  final String removeBudget;
  final String accounts;
  final String cash;
  final String addAccount;
  final String recent;
  final String recentEmpty;
  final String seeAll;
  final String dailyReminder;
  final String dailyReminderSub;
  final String calendar;
  final String goals;
  final String stats;
  final String settings;
  final String customizeWallet;
  final String ratesTitle;
  final String ratesNote;
  final String ratesUnavailable;
  final String scanTitle;
  final String camera;
  final String gallery;
  final String scanning;
  final String aiKeyMissing;
  final String scanFailed;
  final String enterAmount;
  final String saveAllTpl;
  final String expense;
  final String income;
  final String today;
  final String noRepeat;
  final String repeat;
  final String daily;
  final String weekly;
  final String monthly;
  final String yearly;
  final String note;
  final String noteHint;
  final String pickCategory;
  final String calculatorMode;
  final String multiMode;
  final String savedCountTpl;
  final String saved;
  final String undo;
  final String yourCategories;
  final String newCategory;
  final String searchCategory;
  final String reviewTpl;
  final String reviewTitle;
  final String noCategory;
  final String recurringTitle;
  final String recurringEmpty;
  final String nextTpl;
  final String delete;
  final String account;
  final String dateTitle;
  final String quickEntryTitle;
  final String budgetTitle;
  final String analyticsTitle;
  final String noBudget;
  final String noBudgetSub;
  final String createBudget;
  final String editBudget;
  final String budgetAmountHint;
  final String lastDaysTpl;
  final String weeklyPeriod;
  final String monthlyPeriod;
  final String weekStartTpl;
  final String continueLabel;
  final String skipNote;
  final String categoryBudgets;
  final String allocatedTpl;
  final String suggest;
  final String suggestHint;
  final String skip;
  final String weeklyBudget;
  final String noCategoriesYet;
  final String overAllocated;
  final String spentOfTpl;
  final String allCategories;
  final String spending;
  final String byCategory;
  final String expensesTpl;
  final String topCategory;
  final String mostPurchases;
  final String busiestDay;
  final String avgPerDay;
  final String notEnoughData;
  final String shareTpl;
  final String purchasesTpl;
  final String daysTpl;
  final String weekStartLabel;
  final String oneExpense;
  final String onePurchase;
  final String spaceSubtitle;
  final String manage;
  final String appSection;
  final String accountSection;
  final String helpSection;
  final String categories;
  final String tags;
  final String tagsEmpty;
  final String tagsHint;
  final String automation;
  final String automationHint;
  final String builtinRulesTpl;
  final String yourRules;
  final String addKeyword;
  final String keyword;
  final String keywordHint;
  final String ruleDisabled;
  final String keypadLayout;
  final String keypadTop;
  final String keypadBottom;
  final String voiceLanguage;
  final String voiceAppLanguage;
  final String searchLanguage;
  final String dataManagement;
  final String exportCsv;
  final String exportCsvHint;
  final String deleteAllData;
  final String deleteAllDataHint;
  final String deleteAllDataConfirm;
  final String deleteAllDataConfirm2;
  final String deleteAllDone;
  final String paymentReminders;
  final String privacyPolicy;
  final String about;
  final String versionTpl;
  final String archived;
  final String archive;
  final String unarchive;
  final String deleteCategoryTpl;
  final String categoryCountTpl;
  final String notInUse;
  final String tapToAdd;
  final String edit;
  final String converterTitle;
  final String starHint;
  final String starLimit;
  final String ratesUpdatedTpl;
  final String justNow;
  final String minutesAgoTpl;
  final String hoursAgoTpl;
  final String daysAgoTpl;
  final String ratesOffline;
  final String selectCurrency;
  final String suggested;
  final String allCurrencies;
  final String removeRow;
  final String newCategoryTitle;
  final String editCategoryTitle;
  final String categoryName;
  final String sectionLabel;
  final String noSection;
  final String sectionHint;
  final String useLetter;
  final String chooseEmoji;

  static RS of(String code) => switch (code) {
        'tr' => tr,
        'ru' => ru,
        _ => en,
      };

  static const en = RS(
    onbTitle: 'Know where\nevery coin goes.',
    onbSubtitle:
        'Log spending in seconds, set a monthly budget and watch your savings grow.',
    featVoice: 'Add by voice or receipt photo',
    featCurrency: 'Several currencies side by side',
    featCloud: 'Securely backed up in the cloud',
    featNoSignup: 'Start without signing up',
    next: 'Next',
    haveAccount: 'I already have an account',
    currencyTitle: 'Which currency do you use?',
    currencySubtitle:
        'Suggested from your region — you can change it later in Settings.',
    continueWithTpl: 'Continue with {code}',
    chooseAnother: 'Choose another currency',
    searchCurrency: 'Search currency',
    walletTitle: 'Name your wallet',
    walletSubtitle:
        'This is where your money lives. You can change its name, icon and color any time.',
    letsGo: 'Let’s go',
    customize: 'Customize',
    defaultWalletName: 'Personal',
    startingAmount: 'How much do you have now?',
    otherCurrencies: 'Other currencies',
    otherCurrenciesHint: 'Have dollars or euros too? Add them as separate wallets.',
    addCurrencyWallet: '+ Add a currency wallet',
    startingBalance: 'Starting balance',
    currencyWalletTpl: '{code} wallet',
    amount: 'Amount',
    name: 'Name',
    icon: 'Icon',
    color: 'Color',
    currency: 'Currency',
    save: 'Save',
    spentInTpl: 'Spent in {month}',
    budgetEmpty: 'Set a monthly limit and see how much you can still spend.',
    setBudget: 'Set budget',
    monthlyBudget: 'Monthly budget',
    leftTpl: '{amount} left',
    overTpl: '{amount} over',
    ofTpl: '{spent} of {total}',
    daysLeftTpl: '{n} days left',
    removeBudget: 'Remove budget',
    accounts: 'Accounts',
    cash: 'Cash',
    addAccount: 'Add',
    recent: 'Recent activity',
    recentEmpty: 'Nothing here yet — tap + below to add your first expense.',
    seeAll: 'See all',
    dailyReminder: 'Daily reminder',
    dailyReminderSub: 'A gentle nudge at 21:00 to log the day.',
    calendar: 'Calendar',
    goals: 'Goals',
    stats: 'Statistics',
    settings: 'Settings',
    customizeWallet: 'Customize wallet',
    ratesTitle: 'Exchange rates',
    ratesNote: 'Price of 1 unit in {code}',
    ratesUnavailable: 'Rates are unavailable right now',
    scanTitle: 'Scan receipt',
    camera: 'Camera',
    gallery: 'Photo library',
    scanning: 'Reading receipt…',
    aiKeyMissing: 'AI isn’t configured yet (API key missing)',
    scanFailed: 'Couldn’t read the receipt',
    enterAmount: 'Enter an amount',
    saveAllTpl: 'Save ({n})',
    expense: 'Expense',
    income: 'Income',
    today: 'Today',
    noRepeat: 'No repeat',
    repeat: 'Repeat',
    daily: 'Daily',
    weekly: 'Weekly',
    monthly: 'Monthly',
    yearly: 'Yearly',
    note: 'Note',
    noteHint: 'Note or #tags',
    pickCategory: 'Pick a category',
    calculatorMode: 'Calculator',
    multiMode: 'Multi-entry mode',
    savedCountTpl: '{n} saved',
    saved: 'Saved',
    undo: 'Undo',
    yourCategories: 'Your categories',
    newCategory: '+ New category',
    searchCategory: 'Search category',
    reviewTpl: 'Uncategorized: {n}',
    reviewTitle: 'Needs a category',
    noCategory: 'No category',
    recurringTitle: 'Recurring',
    recurringEmpty: 'No recurring transactions yet. Pick "Repeat" when adding one.',
    nextTpl: 'Next: {date}',
    delete: 'Delete',
    account: 'Account',
    dateTitle: 'Date',
    quickEntryTitle: 'New transaction',
    budgetTitle: 'Budget',
    analyticsTitle: 'Analytics',
    noBudget: 'No budget set',
    noBudgetSub: 'Set a limit for the week or month and Budgy will show how much is still safe to spend.',
    createBudget: 'Create budget',
    editBudget: 'Edit budget',
    budgetAmountHint: 'How much can you spend this period?',
    lastDaysTpl: 'Last {n} days: {amount}',
    weeklyPeriod: 'Weekly',
    monthlyPeriod: 'Monthly',
    weekStartTpl: 'Starts {day}',
    continueLabel: 'Continue',
    skipNote: 'Category limits come next — you can skip them.',
    categoryBudgets: 'Category budgets',
    allocatedTpl: '{pct}% allocated',
    suggest: 'Suggest',
    suggestHint: 'Split the budget by your recent spending.',
    skip: 'Skip',
    weeklyBudget: 'Weekly budget',
    noCategoriesYet: 'No expense categories yet — pick one when logging an expense.',
    overAllocated: 'Over budget',
    spentOfTpl: '{spent} of {total}',
    allCategories: 'All categories',
    spending: 'Spending',
    byCategory: 'By category',
    expensesTpl: '{n} expenses',
    topCategory: 'Top category',
    mostPurchases: 'Most purchases',
    busiestDay: 'Busiest day',
    avgPerDay: 'Average per day',
    notEnoughData: 'Not enough data for this month yet.',
    shareTpl: '{pct}% of spending',
    purchasesTpl: '{n} purchases',
    daysTpl: '{n} days',
    weekStartLabel: 'Week starts',
    oneExpense: '1 expense',
    onePurchase: '1 purchase',
    spaceSubtitle: 'Personal space',
    manage: 'Manage',
    appSection: 'App',
    accountSection: 'Account',
    helpSection: 'Help',
    categories: 'Categories',
    tags: 'Tags',
    tagsEmpty: 'No tags yet',
    tagsHint: 'Tags from your notes will appear here — write #home or #trip in a note.',
    automation: 'Category automation',
    automationHint: 'When you save an expense without a category, keywords in the note pick one for you. Your own rules run first.',
    builtinRulesTpl: 'Built-in rules ({n})',
    yourRules: 'Your rules',
    addKeyword: '+ Add keyword',
    keyword: 'Keyword',
    keywordHint: 'e.g. migros, netflix',
    ruleDisabled: 'Off',
    keypadLayout: 'Keypad layout',
    keypadTop: '1-2-3 on top',
    keypadBottom: '1-2-3 on bottom',
    voiceLanguage: 'Voice input language',
    voiceAppLanguage: 'App language',
    searchLanguage: 'Search language',
    dataManagement: 'Data management',
    exportCsv: 'Export transactions (CSV)',
    exportCsvHint: 'Date, type, amount, currency, category, note, account.',
    deleteAllData: 'Delete all data',
    deleteAllDataHint: 'Removes every transaction, category, wallet and setting. Your account stays.',
    deleteAllDataConfirm: 'Delete everything? This cannot be undone.',
    deleteAllDataConfirm2: 'Last check — really delete all data?',
    deleteAllDone: 'All data deleted',
    paymentReminders: 'Payment reminders',
    privacyPolicy: 'Privacy policy',
    about: 'About',
    versionTpl: 'Version {v}',
    archived: 'Archived',
    archive: 'Archive',
    unarchive: 'Unarchive',
    deleteCategoryTpl: 'Delete "{name}"? Past transactions keep their history.',
    categoryCountTpl: '{n}',
    notInUse: 'Not added yet',
    tapToAdd: 'Tap to add',
    edit: 'Edit',
    converterTitle: 'Currency converter',
    starHint: 'Star a currency to show its rate on the home screen.',
    starLimit: 'Up to two starred currencies fit on the home screen.',
    ratesUpdatedTpl: 'Rates updated {when}',
    justNow: 'just now',
    minutesAgoTpl: '{n} min ago',
    hoursAgoTpl: '{n} h ago',
    daysAgoTpl: '{n} d ago',
    ratesOffline: 'No rates yet — connect to the internet once to download them.',
    selectCurrency: 'Select currency',
    suggested: 'Suggested',
    allCurrencies: 'All currencies',
    removeRow: 'Remove',
    newCategoryTitle: 'New category',
    editCategoryTitle: 'Edit category',
    categoryName: 'Category name',
    sectionLabel: 'Section',
    noSection: 'No section',
    sectionHint: 'Put it in a section so the picker stays tidy.',
    useLetter: 'Use the first letter',
    chooseEmoji: 'Choose an emoji',
  );

  static const tr = RS(
    onbTitle: 'Her kuruşun\nyerini bil.',
    onbSubtitle:
        'Harcamanı saniyeler içinde gir, aylık bütçeni koy, birikimini büyüt.',
    featVoice: 'Sesle ya da fiş fotoğrafıyla ekle',
    featCurrency: 'Birden fazla para birimi yan yana',
    featCloud: 'Bulutta güvenle yedeklenir',
    featNoSignup: 'Kayıt olmadan başla',
    next: 'İleri',
    haveAccount: 'Zaten hesabım var',
    currencyTitle: 'Hangi para birimini kullanıyorsun?',
    currencySubtitle:
        'Bölgene göre önerdik — sonra Ayarlar’dan değiştirebilirsin.',
    continueWithTpl: '{code} ile devam et',
    chooseAnother: 'Başka para birimi seç',
    searchCurrency: 'Para birimi ara',
    walletTitle: 'Cüzdanına bir ad ver',
    walletSubtitle:
        'Paran burada duracak. Adını, simgesini ve rengini istediğin zaman değiştirebilirsin.',
    letsGo: 'Başlayalım',
    customize: 'Özelleştir',
    defaultWalletName: 'Kişisel',
    startingAmount: 'Şu an ne kadar var?',
    otherCurrencies: 'Diğer para birimlerin',
    otherCurrenciesHint: 'Doların ya da euron da mı var? Ayrı cüzdan olarak ekle.',
    addCurrencyWallet: '+ Döviz cüzdanı ekle',
    startingBalance: 'Başlangıç bakiyesi',
    currencyWalletTpl: '{code} cüzdanı',
    amount: 'Tutar',
    name: 'Ad',
    icon: 'Simge',
    color: 'Renk',
    currency: 'Para birimi',
    save: 'Kaydet',
    spentInTpl: '{month} ayında harcanan',
    budgetEmpty: 'Aylık bir sınır koy, daha ne kadar harcayabileceğini gör.',
    setBudget: 'Bütçe koy',
    monthlyBudget: 'Aylık bütçe',
    leftTpl: '{amount} kaldı',
    overTpl: '{amount} aşıldı',
    ofTpl: '{spent} / {total}',
    daysLeftTpl: '{n} gün kaldı',
    removeBudget: 'Bütçeyi kaldır',
    accounts: 'Hesaplar',
    cash: 'Nakit',
    addAccount: 'Ekle',
    recent: 'Son hareketler',
    recentEmpty: 'Henüz bir şey yok — ilk harcamanı aşağıdaki + ile ekle.',
    seeAll: 'Tümü',
    dailyReminder: 'Günlük hatırlatma',
    dailyReminderSub:
        'Her akşam 21:00’de günü kaydetmen için hafif bir dürtme.',
    calendar: 'Takvim',
    goals: 'Hedefler',
    stats: 'İstatistik',
    settings: 'Ayarlar',
    customizeWallet: 'Cüzdanı özelleştir',
    ratesTitle: 'Döviz kurları',
    ratesNote: '1 birimin {code} karşılığı',
    ratesUnavailable: 'Kurlar şu an alınamıyor',
    scanTitle: 'Fiş tara',
    camera: 'Kamera',
    gallery: 'Galeri',
    scanning: 'Fiş okunuyor…',
    aiKeyMissing: 'Yapay zekâ henüz ayarlı değil (API anahtarı yok)',
    scanFailed: 'Fiş okunamadı',
    enterAmount: 'Bir tutar gir',
    saveAllTpl: 'Kaydet ({n})',
    expense: 'Gider',
    income: 'Gelir',
    today: 'Bugün',
    noRepeat: 'Tekrar yok',
    repeat: 'Tekrar',
    daily: 'Her gün',
    weekly: 'Her hafta',
    monthly: 'Her ay',
    yearly: 'Her yıl',
    note: 'Not',
    noteHint: 'Not ya da #etiket',
    pickCategory: 'Kategori seç',
    calculatorMode: 'Hesap makinesi',
    multiMode: 'Çoklu giriş',
    savedCountTpl: '{n} kaydedildi',
    saved: 'Kaydedildi',
    undo: 'Geri al',
    yourCategories: 'Kendi kategorilerin',
    newCategory: '+ Yeni kategori',
    searchCategory: 'Kategori ara',
    reviewTpl: '{n} işlem kategori bekliyor',
    reviewTitle: 'Kategori bekleyenler',
    noCategory: 'Kategorisiz',
    recurringTitle: 'Tekrarlayan işlemler',
    recurringEmpty: 'Henüz tekrarlayan işlem yok. İşlem eklerken "Tekrar"ı seç.',
    nextTpl: 'Sıradaki: {date}',
    delete: 'Sil',
    account: 'Hesap',
    dateTitle: 'Tarih',
    quickEntryTitle: 'Yeni işlem',
    budgetTitle: 'Bütçe',
    analyticsTitle: 'Analiz',
    noBudget: 'Bütçe yok',
    noBudgetSub: 'Hafta ya da ay için bir sınır koy; Budgy daha ne kadar harcayabileceğini göstersin.',
    createBudget: 'Bütçe oluştur',
    editBudget: 'Bütçeyi düzenle',
    budgetAmountHint: 'Bu dönemde ne kadar harcayabilirsin?',
    lastDaysTpl: 'Son {n} gün: {amount}',
    weeklyPeriod: 'Haftalık',
    monthlyPeriod: 'Aylık',
    weekStartTpl: '{day} başlar',
    continueLabel: 'Devam',
    skipNote: 'Sırada kategori limitleri var — atlayabilirsin.',
    categoryBudgets: 'Kategori bütçeleri',
    allocatedTpl: '%{pct} dağıtıldı',
    suggest: 'Öner',
    suggestHint: 'Bütçeyi son harcamalarına göre dağıt.',
    skip: 'Atla',
    weeklyBudget: 'Haftalık bütçe',
    noCategoriesYet: 'Henüz harcama kategorisi yok — harcama girerken seçebilirsin.',
    overAllocated: 'Bütçeyi aşıyor',
    spentOfTpl: '{spent} / {total}',
    allCategories: 'Tüm kategoriler',
    spending: 'Harcama',
    byCategory: 'Kategoriye göre',
    expensesTpl: '{n} harcama',
    topCategory: 'En çok harcanan',
    mostPurchases: 'En sık alınan',
    busiestDay: 'En yoğun gün',
    avgPerDay: 'Günlük ortalama',
    notEnoughData: 'Bu ay için henüz yeterli veri yok.',
    shareTpl: 'harcamanın %{pct}’i',
    purchasesTpl: '{n} alışveriş',
    daysTpl: '{n} gün',
    weekStartLabel: 'Hafta başı',
    oneExpense: '1 harcama',
    onePurchase: '1 alışveriş',
    spaceSubtitle: 'Kişisel alan',
    manage: 'Yönet',
    appSection: 'Uygulama',
    accountSection: 'Hesap',
    helpSection: 'Yardım',
    categories: 'Kategoriler',
    tags: 'Etiketler',
    tagsEmpty: 'Henüz etiket yok',
    tagsHint: 'Notlarındaki etiketler burada görünür — nota #ev ya da #tatil yaz.',
    automation: 'Kategori otomasyonu',
    automationHint: 'Kategorisiz bir harcama kaydettiğinde nottaki anahtar kelimeler kategoriyi senin yerine seçer. Önce kendi kuralların çalışır.',
    builtinRulesTpl: 'Yerleşik kurallar ({n})',
    yourRules: 'Kuralların',
    addKeyword: '+ Anahtar kelime ekle',
    keyword: 'Anahtar kelime',
    keywordHint: 'örn. migros, netflix',
    ruleDisabled: 'Kapalı',
    keypadLayout: 'Tuş takımı düzeni',
    keypadTop: '1-2-3 üstte',
    keypadBottom: '1-2-3 altta',
    voiceLanguage: 'Sesli giriş dili',
    voiceAppLanguage: 'Uygulama dili',
    searchLanguage: 'Dil ara',
    dataManagement: 'Veri yönetimi',
    exportCsv: 'İşlemleri dışa aktar (CSV)',
    exportCsvHint: 'Tarih, tür, tutar, para birimi, kategori, not, hesap.',
    deleteAllData: 'Tüm verileri sil',
    deleteAllDataHint: 'Tüm işlemleri, kategorileri, cüzdanları ve ayarları kaldırır. Hesabın kalır.',
    deleteAllDataConfirm: 'Her şey silinsin mi? Geri alınamaz.',
    deleteAllDataConfirm2: 'Son kontrol — tüm veriler gerçekten silinsin mi?',
    deleteAllDone: 'Tüm veriler silindi',
    paymentReminders: 'Ödeme hatırlatıcıları',
    privacyPolicy: 'Gizlilik politikası',
    about: 'Hakkında',
    versionTpl: 'Sürüm {v}',
    archived: 'Arşiv',
    archive: 'Arşivle',
    unarchive: 'Arşivden çıkar',
    deleteCategoryTpl: '"{name}" silinsin mi? Geçmiş işlemler kayıtta kalır.',
    categoryCountTpl: '{n}',
    notInUse: 'Henüz eklenmedi',
    tapToAdd: 'Eklemek için dokun',
    edit: 'Düzenle',
    converterTitle: 'Döviz çevirici',
    starHint: 'Kurunu ana ekranda görmek için para birimini yıldızla.',
    starLimit: 'Ana ekrana en fazla iki yıldızlı para birimi sığar.',
    ratesUpdatedTpl: 'Kurlar güncellendi: {when}',
    justNow: 'az önce',
    minutesAgoTpl: '{n} dk önce',
    hoursAgoTpl: '{n} sa önce',
    daysAgoTpl: '{n} gün önce',
    ratesOffline: 'Henüz kur yok — bir kez internete bağlan, indirilsin.',
    selectCurrency: 'Para birimi seç',
    suggested: 'Önerilen',
    allCurrencies: 'Tüm para birimleri',
    removeRow: 'Kaldır',
    newCategoryTitle: 'Yeni kategori',
    editCategoryTitle: 'Kategoriyi düzenle',
    categoryName: 'Kategori adı',
    sectionLabel: 'Bölüm',
    noSection: 'Bölümsüz',
    sectionHint: 'Seçici düzenli kalsın diye bir bölüme koy.',
    useLetter: 'Baş harfi kullan',
    chooseEmoji: 'Emoji seç',
  );

  static const ru = RS(
    onbTitle: 'Знай, куда уходит\nкаждая монета.',
    onbSubtitle:
        'Записывай траты за секунды, ставь бюджет на месяц и копи больше.',
    featVoice: 'Добавляй голосом или фото чека',
    featCurrency: 'Несколько валют рядом',
    featCloud: 'Надёжная копия в облаке',
    featNoSignup: 'Начни без регистрации',
    next: 'Далее',
    haveAccount: 'У меня уже есть аккаунт',
    currencyTitle: 'Какой валютой пользуешься?',
    currencySubtitle:
        'Подобрали по региону — потом можно поменять в настройках.',
    continueWithTpl: 'Продолжить с {code}',
    chooseAnother: 'Выбрать другую валюту',
    searchCurrency: 'Поиск валюты',
    walletTitle: 'Назови свой кошелёк',
    walletSubtitle:
        'Здесь будут жить твои деньги. Название, иконку и цвет можно поменять в любой момент.',
    letsGo: 'Поехали',
    customize: 'Настроить',
    defaultWalletName: 'Личное',
    startingAmount: 'Сколько у тебя сейчас?',
    otherCurrencies: 'Другие валюты',
    otherCurrenciesHint: 'Есть доллары или евро? Добавь их отдельными кошельками.',
    addCurrencyWallet: '+ Добавить валютный кошелёк',
    startingBalance: 'Начальный баланс',
    currencyWalletTpl: 'Кошелёк {code}',
    amount: 'Сумма',
    name: 'Название',
    icon: 'Иконка',
    color: 'Цвет',
    currency: 'Валюта',
    save: 'Сохранить',
    spentInTpl: 'Потрачено за {month}',
    budgetEmpty:
        'Поставь лимит на месяц и смотри, сколько ещё можно потратить.',
    setBudget: 'Задать',
    monthlyBudget: 'Бюджет на месяц',
    leftTpl: 'Осталось {amount}',
    overTpl: 'Превышение {amount}',
    ofTpl: '{spent} из {total}',
    daysLeftTpl: 'Дней осталось: {n}',
    removeBudget: 'Удалить бюджет',
    accounts: 'Счета',
    cash: 'Наличные',
    addAccount: 'Добавить',
    recent: 'Последние операции',
    recentEmpty: 'Пока пусто — добавь первую трату кнопкой + внизу.',
    seeAll: 'Все',
    dailyReminder: 'Ежедневное напоминание',
    dailyReminderSub: 'Лёгкое напоминание в 21:00 записать день.',
    calendar: 'Календарь',
    goals: 'Цели',
    stats: 'Статистика',
    settings: 'Настройки',
    customizeWallet: 'Настроить кошелёк',
    ratesTitle: 'Курсы валют',
    ratesNote: 'Цена 1 единицы в {code}',
    ratesUnavailable: 'Курсы сейчас недоступны',
    scanTitle: 'Сканировать чек',
    camera: 'Камера',
    gallery: 'Галерея',
    scanning: 'Читаю чек…',
    aiKeyMissing: 'ИИ ещё не настроен (нет API-ключа)',
    scanFailed: 'Не удалось прочитать чек',
    enterAmount: 'Введи сумму',
    saveAllTpl: 'Сохранить ({n})',
    expense: 'Расход',
    income: 'Доход',
    today: 'Сегодня',
    noRepeat: 'Без повтора',
    repeat: 'Повтор',
    daily: 'Ежедневно',
    weekly: 'Еженедельно',
    monthly: 'Ежемесячно',
    yearly: 'Ежегодно',
    note: 'Заметка',
    noteHint: 'Заметка или #теги',
    pickCategory: 'Выбрать категорию',
    calculatorMode: 'Калькулятор',
    multiMode: 'Несколько подряд',
    savedCountTpl: 'Сохранено: {n}',
    saved: 'Сохранено',
    undo: 'Отменить',
    yourCategories: 'Твои категории',
    newCategory: '+ Новая категория',
    searchCategory: 'Поиск категории',
    reviewTpl: 'Без категории: {n}',
    reviewTitle: 'Ждут категорию',
    noCategory: 'Без категории',
    recurringTitle: 'Повторяющиеся',
    recurringEmpty: 'Повторяющихся операций пока нет. Выбери «Повтор» при добавлении.',
    nextTpl: 'Следующая: {date}',
    delete: 'Удалить',
    account: 'Счёт',
    dateTitle: 'Дата',
    quickEntryTitle: 'Новая операция',
    budgetTitle: 'Бюджет',
    analyticsTitle: 'Аналитика',
    noBudget: 'Бюджет не задан',
    noBudgetSub: 'Задай лимит на неделю или месяц — Budgy покажет, сколько ещё можно тратить.',
    createBudget: 'Создать бюджет',
    editBudget: 'Изменить бюджет',
    budgetAmountHint: 'Сколько можно тратить за период?',
    lastDaysTpl: 'За {n} дней: {amount}',
    weeklyPeriod: 'Неделя',
    monthlyPeriod: 'Месяц',
    weekStartTpl: 'С {day}',
    continueLabel: 'Продолжить',
    skipNote: 'Дальше лимиты по категориям — их можно пропустить.',
    categoryBudgets: 'Лимиты по категориям',
    allocatedTpl: 'Распределено {pct}%',
    suggest: 'Подсказать',
    suggestHint: 'Разделить бюджет по недавним тратам.',
    skip: 'Пропустить',
    weeklyBudget: 'Бюджет на неделю',
    noCategoriesYet: 'Категорий расходов пока нет — выбери при вводе траты.',
    overAllocated: 'Больше бюджета',
    spentOfTpl: '{spent} из {total}',
    allCategories: 'Все категории',
    spending: 'Расходы',
    byCategory: 'По категориям',
    expensesTpl: 'Трат: {n}',
    topCategory: 'Главная категория',
    mostPurchases: 'Чаще всего',
    busiestDay: 'Самый затратный день',
    avgPerDay: 'В среднем за день',
    notEnoughData: 'Пока мало данных за этот месяц.',
    shareTpl: '{pct}% расходов',
    purchasesTpl: 'Покупок: {n}',
    daysTpl: 'Дней: {n}',
    weekStartLabel: 'Начало недели',
    oneExpense: '1 трата',
    onePurchase: '1 покупка',
    spaceSubtitle: 'Личное пространство',
    manage: 'Управление',
    appSection: 'Приложение',
    accountSection: 'Аккаунт',
    helpSection: 'Помощь',
    categories: 'Категории',
    tags: 'Теги',
    tagsEmpty: 'Тегов пока нет',
    tagsHint: 'Теги из заметок появятся здесь — напиши #дом или #отпуск в заметке.',
    automation: 'Автокатегории',
    automationHint: 'Когда трата сохраняется без категории, ключевые слова в заметке подберут её. Твои правила проверяются первыми.',
    builtinRulesTpl: 'Встроенные правила ({n})',
    yourRules: 'Твои правила',
    addKeyword: '+ Добавить слово',
    keyword: 'Ключевое слово',
    keywordHint: 'напр. migros, netflix',
    ruleDisabled: 'Выкл',
    keypadLayout: 'Раскладка клавиш',
    keypadTop: '1-2-3 сверху',
    keypadBottom: '1-2-3 снизу',
    voiceLanguage: 'Язык голосового ввода',
    voiceAppLanguage: 'Язык приложения',
    searchLanguage: 'Поиск языка',
    dataManagement: 'Данные',
    exportCsv: 'Экспорт операций (CSV)',
    exportCsvHint: 'Дата, тип, сумма, валюта, категория, заметка, счёт.',
    deleteAllData: 'Удалить все данные',
    deleteAllDataHint: 'Удалит все операции, категории, кошельки и настройки. Аккаунт останется.',
    deleteAllDataConfirm: 'Удалить всё? Это нельзя отменить.',
    deleteAllDataConfirm2: 'Последняя проверка — точно удалить все данные?',
    deleteAllDone: 'Все данные удалены',
    paymentReminders: 'Напоминания о платежах',
    privacyPolicy: 'Политика конфиденциальности',
    about: 'О приложении',
    versionTpl: 'Версия {v}',
    archived: 'Архив',
    archive: 'В архив',
    unarchive: 'Из архива',
    deleteCategoryTpl: 'Удалить «{name}»? История операций сохранится.',
    categoryCountTpl: '{n}',
    notInUse: 'Ещё не добавлена',
    tapToAdd: 'Нажми, чтобы добавить',
    edit: 'Изменить',
    converterTitle: 'Конвертер валют',
    starHint: 'Отметь валюту звездой, чтобы видеть курс на главном экране.',
    starLimit: 'На главный экран помещаются не более двух валют.',
    ratesUpdatedTpl: 'Курсы обновлены: {when}',
    justNow: 'только что',
    minutesAgoTpl: '{n} мин назад',
    hoursAgoTpl: '{n} ч назад',
    daysAgoTpl: '{n} дн назад',
    ratesOffline: 'Курсов пока нет — подключись к интернету один раз, чтобы загрузить.',
    selectCurrency: 'Выбор валюты',
    suggested: 'Рекомендуемые',
    allCurrencies: 'Все валюты',
    removeRow: 'Убрать',
    newCategoryTitle: 'Новая категория',
    editCategoryTitle: 'Изменить категорию',
    categoryName: 'Название категории',
    sectionLabel: 'Раздел',
    noSection: 'Без раздела',
    sectionHint: 'Помести в раздел, чтобы список оставался аккуратным.',
    useLetter: 'Использовать первую букву',
    chooseEmoji: 'Выбрать эмодзи',
  );
}

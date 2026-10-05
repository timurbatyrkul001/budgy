import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/envelopes/budget_repository.dart';

/// Язык приложения. Хранится в users/{uid}/settings/main.language.
enum AppLanguage {
  en('en', 'English'),
  tr('tr', 'Türkçe'),
  ru('ru', 'Русский');

  const AppLanguage(this.code, this.title);

  final String code;
  final String title;

  static AppLanguage fromCode(String? code) => AppLanguage.values
      .firstWhere((l) => l.code == code, orElse: () => AppLanguage.en);
}

final languageProvider = StreamProvider<AppLanguage>((ref) {
  return ref.watch(budgetRepositoryProvider).watchLanguage();
});

/// Все строки интерфейса для текущего языка.
final strProvider = Provider<Strings>((ref) {
  final lang = ref.watch(languageProvider).value ?? AppLanguage.en;
  return switch (lang) {
    AppLanguage.en => Strings.en,
    AppLanguage.tr => Strings.tr,
    AppLanguage.ru => Strings.ru,
  };
});

/// Подстановка параметров: tpl('Hello {name}', {'name': 'Tim'}).
String tpl(String template, Map<String, String> params) {
  var result = template;
  params.forEach((key, value) {
    result = result.replaceAll('{$key}', value);
  });
  return result;
}

/// Стартовые конверты онбординга. Ключ хранится в Firestore (поле
/// preset), а имя берётся из текущего языка — конверт переводится сам.
const presetEnvelopes = <({String key, String emoji})>[
  (key: 'rent', emoji: '🏠'),
  (key: 'food', emoji: '🍔'),
  (key: 'travel', emoji: '✈️'),
  (key: 'transport', emoji: '🚗'),
  (key: 'health', emoji: '💊'),
  (key: 'gifts', emoji: '🎁'),
  (key: 'education', emoji: '📚'),
  (key: 'clothes', emoji: '👕'),
  (key: 'savings', emoji: '💰'),
];

class Strings {
  const Strings({
    required this.localeCode,
    required this.thisMonth,
    required this.nameHint,
    required this.create,
    required this.save,
    required this.saving,
    required this.cancel,
    required this.removeWord,
    required this.deleteWord,
    required this.deleteTxTitle,
    required this.deleteTxBody,
    required this.skip,
    required this.expenseFromThis,
    required this.incomeTitle,
    required this.amountHint,
    required this.expenseTitle,
    required this.addTxTitle,
    required this.amountTitle,
    required this.dateLabel,
    required this.selectCategory,
    required this.convertTitle,
    required this.giveLabel,
    required this.getLabel,
    required this.convertAction,
    required this.rateHint,
    required this.rateUnavailable,
    required this.moneyLeft,
    required this.goalLeft,
    required this.removeBudget,
    required this.createAccount,
    required this.createAccountHint,
    required this.verifyEmailTitle,
    required this.verifyEmailBody,
    required this.verifyDone,
    required this.verifyResend,
    required this.verifyNotYet,
    required this.verifySent,
    required this.invalidEmail,
    required this.passwordsDontMatch,
    required this.detailedEntry,
    required this.dailyReminderLabel,
    required this.dailyReminderTitle,
    required this.dailyReminderBody,
    required this.workEarning,
    required this.addFunds,
    required this.addFundsTitle,
    required this.savingsTitle,
    required this.savingsTotalLabel,
    required this.budgetDoneTitle,
    required this.budgetDoneSubtitle,
    required this.addMore,
    required this.pocketName,
    required this.transferTitle,
    required this.selectEnvelope,
    required this.envelopeLabel,
    required this.searchHint,
    required this.noteHint,
    required this.seeAll,
    required this.noOperations,
    required this.today,
    required this.yesterday,
    required this.incomeWord,
    required this.expenseWord,
    required this.workDaysTitle,
    required this.weekdaysShort,
    required this.worked,
    required this.planned,
    required this.earned,
    required this.monthForecast,
    required this.daysShort,
    required this.dayEarningsHint,
    required this.remindersEmpty,
    required this.newReminder,
    required this.reminderNameHint,
    required this.amountOptionalHint,
    required this.remindFrom,
    required this.toWord,
    required this.dayOfMonthWord,
    required this.dontForgetTpl,
    required this.dontForgetPlain,
    required this.analyticsTitle,
    required this.spent,
    required this.reportSubtitle,
    required this.accountInformation,
    required this.changePassword,
    required this.confidentialityPolicy,
    required this.faqs,
    required this.helpCenter,
    required this.signOutWord,
    required this.deleteAccount,
    required this.deleteAccountBody,
    required this.historyTitle,
    required this.searchHistory,
    required this.categoriesLabel,
    required this.applyFilter,
    required this.sortFilterTitle,
    required this.sortByLabel,
    required this.sortDate,
    required this.sortAmount,
    required this.sortCategory,
    required this.sortAscending,
    required this.sortDescending,
    required this.accountLabel,
    required this.filterAll,
    required this.filterNoAccount,
    required this.periodLabel,
    required this.periodAllTime,
    required this.periodThisMonth,
    required this.periodLast30,
    required this.periodPickDay,
    required this.spentThisMonth,
    required this.activityExpenses,
    required this.setAsideFor,
    required this.calculateBudget,
    required this.shareWord,
    required this.archiveWord,
    required this.unarchiveWord,
    required this.exportWord,
    required this.deleteCatTitle,
    required this.deleteCatBody,
    required this.exportTitle,
    required this.exportBody,
    required this.noteLabel,
    required this.budgetName,
    required this.budgetAmount,
    required this.startDate,
    required this.endDate,
    required this.timePeriod,
    required this.selectPeriod,
    required this.periodWeekly,
    required this.periodMonthly,
    required this.periodYearly,
    required this.chooseWord,
    required this.withoutEnvelope,
    required this.goalsTitle,
    required this.goalsEmpty,
    required this.newGoal,
    required this.targetAmountHint,
    required this.setGoal,
    required this.removeGoalTitle,
    required this.removeGoalBody,
    required this.languageTitle,
    required this.currencyTitle,
    required this.themeSystem,
    required this.themeLight,
    required this.themeDark,
    required this.weeklySummaryTitle,
    required this.weeklySummaryBodyTpl,
    required this.recurringTitle,
    required this.recurringMonthlyLabel,
    required this.dueInDaysTpl,
    required this.dueNowLabel,
    required this.anonymousTitle,
    required this.tabHome,
    required this.tabCalendar,
    required this.presetNames,
    required this.reviewTitle,
    required this.navCompleteProfile,
    required this.profileSubtitle,
    required this.phoneLabel,
    required this.phoneHint,
    required this.dontHaveAccount,
    required this.forgetTitle,
    required this.forgetSubtitle,
    required this.checkEmailTitle,
    required this.checkEmailBody,
    required this.notNow,
    required this.resend,
    required this.spamNote,
    required this.navSignUp,
    required this.signUpTitle,
    required this.signUpSubtitle,
    required this.fullNameLabel,
    required this.fullNameHint,
    required this.confirmPasswordLabel,
    required this.reqMin8,
    required this.reqNoName,
    required this.reqSymbol,
    required this.continueButton,
    required this.signInTitle,
    required this.signInSubtitle,
    required this.emailLabel,
    required this.emailHint,
    required this.passwordLabel,
    required this.passwordHint,
    required this.forgotPassword,
    required this.signInButton,
    required this.signInError,
    required this.continueGoogle,
    required this.continueApple,
    required this.orSignUpWith,
    required this.termsNote,
    required this.errorPrefix,
    required this.errorSaveFailed,
    required this.savedOffline,
    required this.errorGeneric,
    required this.channelPaymentsName,
    required this.channelPaymentsDesc,
    required this.channelDailyName,
    required this.channelDailyDesc,
    required this.channelWeeklyName,
    required this.channelWeeklyDesc,
    required this.confirmPasswordTitle,
    required this.deleteAccountFailed,
    required this.deleteAccountReauthFailed,
    required this.signInErrorNetwork,
    required this.signInErrorTooMany,
    required this.signInErrorDisabled,
    required this.signOutFailed,
    required this.dataLoadFailed,
    required this.verifySendFailed,
    required this.aiAddTitle,
    required this.aiAddHint,
    required this.aiInputHint,
    required this.aiParseAction,
    required this.aiSaveAllTpl,
    required this.aiNothingFound,
    required this.aiVoiceUnavailable,
    required this.aiVoicePermission,
    required this.aiVoicePermissionAndroid,
    required this.aiVoiceNothingHeard,
    required this.aiVoiceNetwork,
    required this.aiVoiceLanguage,
    required this.aiVoiceFailed,
    required this.notifTitle,
    required this.notifHeroBody,
    required this.notifSectionSystem,
    required this.notifPermGrantedTitle,
    required this.notifPermGrantedBody,
    required this.notifPermDeniedTitle,
    required this.notifPermDeniedBody,
    required this.notifSectionDaily,
    required this.notifDailyDesc,
    required this.notifDailyHourTitle,
    required this.notifWeeklyDesc,
    required this.notifSectionPayments,
    required this.notifPaymentsDescTpl,
    required this.notifManagePayments,
  });

  final String localeCode;
  final String thisMonth;
  final String nameHint;
  final String create;
  final String save;
  final String saving;
  final String cancel;
  final String removeWord;
  final String deleteWord;
  final String deleteTxTitle;
  final String deleteTxBody;
  final String skip;
  final String expenseFromThis;
  final String incomeTitle;
  final String amountHint;
  final String expenseTitle;
  final String addTxTitle;
  final String amountTitle;
  final String dateLabel;
  final String selectCategory;
  final String convertTitle;
  final String giveLabel;
  final String getLabel;
  final String convertAction;
  final String rateHint;
  final String rateUnavailable;
  final String moneyLeft;
  final String goalLeft;
  final String removeBudget;
  final String createAccount;
  final String createAccountHint;
  final String verifyEmailTitle;
  final String verifyEmailBody;
  final String verifyDone;
  final String verifyResend;
  final String verifyNotYet;
  final String verifySent;
  final String invalidEmail;
  final String passwordsDontMatch;
  final String detailedEntry;
  final String dailyReminderLabel;
  final String dailyReminderTitle;
  final String dailyReminderBody;
  final String workEarning;
  final String addFunds;
  final String addFundsTitle;
  final String savingsTitle;
  final String savingsTotalLabel;
  final String budgetDoneTitle;
  final String budgetDoneSubtitle;
  final String addMore;
  final String pocketName;
  final String transferTitle;
  final String selectEnvelope;
  final String envelopeLabel;
  final String searchHint;
  final String noteHint;
  final String seeAll;
  final String noOperations;
  final String today;
  final String yesterday;
  final String incomeWord;
  final String expenseWord;
  final String workDaysTitle;
  final List<String> weekdaysShort;
  final String worked;
  final String planned;
  final String earned;
  final String monthForecast;
  final String daysShort;
  final String dayEarningsHint;
  final String remindersEmpty;
  final String newReminder;
  final String reminderNameHint;
  final String amountOptionalHint;
  final String remindFrom;
  final String toWord;
  final String dayOfMonthWord;
  final String dontForgetTpl; // {x}
  final String dontForgetPlain;
  final String analyticsTitle;
  final String spent;
  final String reportSubtitle;
  final String accountInformation;
  final String changePassword;
  final String confidentialityPolicy;
  final String faqs;
  final String helpCenter;
  final String signOutWord;
  final String deleteAccount;
  final String deleteAccountBody;
  final String historyTitle;
  final String searchHistory;
  final String categoriesLabel;
  final String applyFilter;

  /// Geçmiş › "Sırala ve Filtrele" alt sayfası.
  final String sortFilterTitle;
  final String sortByLabel;
  final String sortDate;
  final String sortAmount;
  final String sortCategory;
  final String sortAscending;
  final String sortDescending;
  final String accountLabel;
  final String filterAll;
  final String filterNoAccount;
  final String periodLabel;
  final String periodAllTime;
  final String periodThisMonth;
  final String periodLast30;
  final String periodPickDay;
  final String spentThisMonth;
  final String activityExpenses;
  final String setAsideFor; // {amount}, {name}
  final String calculateBudget;
  final String shareWord;
  final String archiveWord;
  final String unarchiveWord;
  final String exportWord;
  final String deleteCatTitle;
  final String deleteCatBody;
  final String exportTitle;
  final String exportBody;
  final String noteLabel;
  final String budgetName;
  final String budgetAmount;
  final String startDate;
  final String endDate;
  final String timePeriod;
  final String selectPeriod;
  final String periodWeekly;
  final String periodMonthly;
  final String periodYearly;
  final String chooseWord;
  final String withoutEnvelope;
  final String goalsTitle;
  final String goalsEmpty;
  final String newGoal;
  final String targetAmountHint;
  final String setGoal;
  final String removeGoalTitle; // {name}
  final String removeGoalBody;
  final String languageTitle;
  final String currencyTitle;
  final String themeSystem;
  final String themeLight;
  final String themeDark;
  final String weeklySummaryTitle;
  final String weeklySummaryBodyTpl; // {x}
  final String recurringTitle;
  final String recurringMonthlyLabel;
  final String dueInDaysTpl; // {n}
  final String dueNowLabel;
  final String anonymousTitle;
  final String tabHome;
  final String tabCalendar;
  final Map<String, String> presetNames;

  /// Слайды стори-онбординга: заголовок + подзаголовок.
  final String reviewTitle;
  final String navCompleteProfile;
  final String profileSubtitle;
  final String phoneLabel;
  final String phoneHint;
  final String dontHaveAccount;
  final String forgetTitle;
  final String forgetSubtitle;
  final String checkEmailTitle;
  final String checkEmailBody; // {email}
  final String notNow;
  final String resend;
  final String spamNote;
  final String navSignUp;
  final String signUpTitle;
  final String signUpSubtitle;
  final String fullNameLabel;
  final String fullNameHint;
  final String confirmPasswordLabel;
  final String reqMin8;
  final String reqNoName;
  final String reqSymbol;
  final String continueButton;
  final String signInTitle;
  final String signInSubtitle;
  final String emailLabel;
  final String emailHint;
  final String passwordLabel;
  final String passwordHint;
  final String forgotPassword;
  final String signInButton;
  final String signInError;
  final String continueGoogle;
  final String continueApple;
  /// Hesap açmadan devam etme bağlantısı + altındaki uyarı.
  final String orSignUpWith;
  final String termsNote;
  final String errorPrefix;

  /// Kaydetme sırasında (ağ/Firestore) hata — kullanıcıya SnackBar.
  final String errorSaveFailed;

  /// Çevrimdışı yazma: kayıt yerel kuyrukta, ağ gelince gidecek.
  final String savedOffline;

  /// Beklenmedik durum: seçilen zarf silinmiş, birimler uyuşmuyor vb.
  final String errorGeneric;

  /// Android bildirim kanalı adları/açıklamaları. Sistem ayarlarında
  /// kullanıcıya göründükleri için çevrilir.
  final String channelPaymentsName;
  final String channelPaymentsDesc;
  final String channelDailyName;
  final String channelDailyDesc;
  final String channelWeeklyName;
  final String channelWeeklyDesc;

  /// Hesap silme: yeniden kimlik doğrulama akışı.
  final String confirmPasswordTitle;
  final String deleteAccountFailed;
  final String deleteAccountReauthFailed;

  /// Giriş ekranı: yanlış şifre DIŞINDAKİ sebepler. Eskiden hepsi
  /// [signInError] ("e-posta ya da şifre yanlış") olarak çıkıyordu — ağ
  /// yokken kullanıcı doğru şifresini değiştirip duruyordu.
  final String signInErrorNetwork;
  final String signInErrorTooMany;
  final String signInErrorDisabled;

  /// Çıkış için anonim oturum açılamadı (ağ yok); kullanıcı hesabında kaldı.
  final String signOutFailed;

  /// Açılışta Firestore akışları hata verdi (kural, App Check, dizin...).
  /// Onboarding yerine bu gösterilir — yoksa eski kullanıcı "verim gitti"
  /// sanır.
  final String dataLoadFailed;

  /// Doğrulama postası gönderilemedi (ağ dışı bir sebep). Eskiden gönderim
  /// hatası yutulup her seferinde "gönderildi" yazılıyordu — kullanıcı
  /// hiç gitmemiş bir postayı bekliyordu.
  final String verifySendFailed;

  /// AI hızlı giriş (yaz/söyle → işlemler).
  final String aiAddTitle;
  final String aiAddHint;
  final String aiInputHint;
  final String aiParseAction;
  final String aiSaveAllTpl;
  final String aiNothingFound;
  final String aiVoiceUnavailable;
  final String aiVoicePermission;
  final String aiVoicePermissionAndroid;
  final String aiVoiceNothingHeard;
  final String aiVoiceNetwork;
  final String aiVoiceLanguage;
  final String aiVoiceFailed;

  /// Bildirim tercihleri ekranı (ayarlar › Bildirimler).
  final String notifTitle;
  final String notifHeroBody;
  final String notifSectionSystem;
  final String notifPermGrantedTitle;
  final String notifPermGrantedBody;
  final String notifPermDeniedTitle;
  final String notifPermDeniedBody;
  final String notifSectionDaily;
  final String notifDailyDesc;
  final String notifDailyHourTitle;
  final String notifWeeklyDesc;
  final String notifSectionPayments;
  final String notifPaymentsDescTpl; // {n} = tanımlı hatırlatıcı sayısı
  final String notifManagePayments;

  static const en = Strings(
    localeCode: 'en',
    thisMonth: 'this month',
    nameHint: 'Name',
    create: 'Create',
    save: 'Save',
    saving: 'Saving...',
    cancel: 'Cancel',
    removeWord: 'Remove',
    deleteWord: 'Delete',
    deleteTxTitle: 'Delete transaction?',
    deleteTxBody: 'It will be removed and balances updated.',
    skip: 'Skip',
    expenseFromThis: '− Expense from this envelope',
    incomeTitle: 'Income',
    amountHint: 'Amount, ₺',
    expenseTitle: 'Expense',
    addTxTitle: 'Add new transaction',
    amountTitle: 'Amount',
    dateLabel: 'Date',
    selectCategory: 'Select category',
    convertTitle: 'Convert currency',
    giveLabel: 'You give',
    getLabel: 'You get',
    convertAction: 'Convert',
    rateHint: 'live rate',
    rateUnavailable: 'Rate unavailable — enter manually',
    moneyLeft: 'Money left',
    goalLeft: 'left',
    removeBudget: 'Remove budget',
    createAccount: 'Create account',
    createAccountHint: 'Secure your data & sign in on any device',
    verifyEmailTitle: 'Verify your email',
    verifyEmailBody:
        'We sent a verification link to your email. Open it, then tap below.',
    verifyDone: 'I verified',
    verifyResend: 'Resend link',
    verifyNotYet: 'Not verified yet — check your email',
    verifySent: 'Verification link sent',
    invalidEmail: 'Enter a valid email',
    passwordsDontMatch: 'Passwords don\'t match',
    detailedEntry: 'More options',
    dailyReminderLabel: 'Daily reminder',
    dailyReminderTitle: 'Did you log today\'s spending?',
    dailyReminderBody: 'Keep your Money left up to date — takes seconds.',
    workEarning: 'Work earnings',
    addFunds: 'Add funds',
    addFundsTitle: 'Add funds',
    savingsTitle: 'Savings',
    savingsTotalLabel: 'Total saved',
    budgetDoneTitle: 'Budget Completed',
    budgetDoneSubtitle:
        'All done! Your budget is ready, so you can start managing your money',
    addMore: 'Add more',
    pocketName: 'Cash (unallocated)',
    transferTitle: 'Transfer',
    selectEnvelope: 'Select an envelope',
    envelopeLabel: 'Envelope',
    searchHint: 'Search',
    noteHint: 'Note',
    seeAll: 'See all',
    noOperations: 'No transactions yet',
    today: 'Today',
    yesterday: 'Yesterday',
    incomeWord: 'Income',
    expenseWord: 'Expense',
    workDaysTitle: 'Work days',
    weekdaysShort: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    worked: 'Worked',
    planned: 'Planned',
    earned: 'Earned',
    monthForecast: 'Month forecast',
    daysShort: 'd.',
    dayEarningsHint: 'Earnings for the day, ₺',
    remindersEmpty:
        'Add a reminder for a recurring payment — e.g. rent from the 1st to the 5th. You\'ll get a notification on those days every month.',
    newReminder: '+ New reminder',
    reminderNameHint: 'Name (Rent...)',
    amountOptionalHint: 'Amount, ₺ (optional)',
    remindFrom: 'Remind from',
    toWord: 'to',
    dayOfMonthWord: 'day',
    dontForgetTpl: 'Don\'t forget: {x}',
    dontForgetPlain: 'Don\'t forget this payment',
    analyticsTitle: 'Analytics',
    spent: 'spent',
    reportSubtitle: 'View a simple report of your spending',
    accountInformation: 'Account information',
    changePassword: 'Change password',
    confidentialityPolicy: 'Confidentiality policy',
    faqs: 'FAQs',
    helpCenter: 'Help Center',
    signOutWord: 'Sign out',
    deleteAccount: 'Delete account',
    deleteAccountBody:
        'This permanently deletes your account and all your data. This cannot be undone.',
    historyTitle: 'History of Spending',
    searchHistory: 'Search history',
    categoriesLabel: 'Categories',
    applyFilter: 'Apply Filter',
    sortFilterTitle: 'Sort & Filter',
    sortByLabel: 'Sort by',
    sortDate: 'Date',
    sortAmount: 'Amount',
    sortCategory: 'Category',
    sortAscending: 'Ascending',
    sortDescending: 'Descending',
    accountLabel: 'Account',
    filterAll: 'All',
    filterNoAccount: 'No account',
    periodLabel: 'Period',
    periodAllTime: 'All time',
    periodThisMonth: 'This month',
    periodLast30: '30 days',
    periodPickDay: 'Pick a day',
    spentThisMonth: 'Spent this month',
    activityExpenses: 'Activity Expenses',
    setAsideFor: 'You\'ve set aside {amount} for {name}',
    calculateBudget: 'Calculate Budget',
    shareWord: 'Share',
    archiveWord: 'Archive',
    unarchiveWord: 'Unarchive',
    exportWord: 'Export',
    deleteCatTitle: 'Delete Category',
    deleteCatBody:
        'Deleting this category will permanently remove it from your list',
    exportTitle: 'Export of report',
    exportBody:
        'Exporting this data will create a copy that you can save or share outside the app',
    noteLabel: 'Note',
    budgetName: 'Budget Name',
    budgetAmount: 'Budget Amount',
    startDate: 'Start Date',
    endDate: 'End Date',
    timePeriod: 'Time Period',
    selectPeriod: 'Select period',
    periodWeekly: 'Weekly',
    periodMonthly: 'Monthly',
    periodYearly: 'Yearly',
    chooseWord: 'Choose',
    withoutEnvelope: 'No envelope',
    goalsTitle: 'Goals',
    goalsEmpty:
        'Set a goal for any envelope — a car, a vacation, a laptop — and watch it grow.',
    newGoal: '+ New goal',
    targetAmountHint: 'Target amount, ₺',
    setGoal: 'Set goal',
    removeGoalTitle: 'Remove goal "{name}"?',
    removeGoalBody:
        'The envelope and money stay, only the goal disappears.',
    languageTitle: 'Language',
    currencyTitle: 'Currency',
    themeSystem: 'System',
    themeLight: 'Light',
    themeDark: 'Dark',
    weeklySummaryTitle: 'Weekly summary',
    weeklySummaryBodyTpl: 'You earned {x} this week',
    recurringTitle: 'Recurring bills',
    recurringMonthlyLabel: 'Monthly total',
    dueInDaysTpl: 'in {n} days',
    dueNowLabel: 'Due now',
    anonymousTitle: 'Anonymous account',
    tabHome: 'Home',
    tabCalendar: 'Calendar',
    presetNames: {
      'rent': 'Rent',
      'food': 'Food',
      'travel': 'Travel',
      'transport': 'Transport',
      'health': 'Health',
      'gifts': 'Gifts',
      'education': 'Education',
      'clothes': 'Clothes',
      'savings': 'Savings',
      'other': 'Other',
    },
    reviewTitle: 'Your envelopes are ready',
    navCompleteProfile: 'Complete profile',
    profileSubtitle: 'Introduce yourself to others in your profile',
    phoneLabel: 'Phone number',
    phoneHint: 'Enter your number',
    dontHaveAccount: 'Don\'t have an account?',
    forgetTitle: 'Forget password',
    forgetSubtitle: 'Enter your email address to change your password',
    checkEmailTitle: 'Check your email',
    checkEmailBody:
        'We contacted {email} to help you set up a new password',
    notNow: 'Not now',
    resend: 'Resend',
    spamNote: 'Check your spam folder if you don\'t see the email',
    navSignUp: 'Sign up',
    signUpTitle: 'Sign Up',
    signUpSubtitle:
        'It\'s free and takes a minute. Get a clear daily picture of your money.',
    fullNameLabel: 'Full name',
    fullNameHint: 'Enter your full name',
    confirmPasswordLabel: 'Confirm password',
    reqMin8: 'Must be at least 8 characters',
    reqNoName: 'Can\'t include your name or email address',
    reqSymbol: 'Must have at least a symbol or number',
    continueButton: 'Continue',
    signInTitle: 'Sign in',
    signInSubtitle:
        'We\'re thrilled to have you back. Let\'s dive in and get updated news for you!',
    emailLabel: 'Email',
    emailHint: 'Enter your email',
    passwordLabel: 'Password',
    passwordHint: 'Enter your password',
    forgotPassword: 'Forgot password',
    signInButton: 'Sign in',
    signInError:
        'Oops! The email or password you entered is incorrect, please check your email and password!',
    continueGoogle: 'Continue with Google',
    continueApple: 'Continue with Apple',
    orSignUpWith: 'or sign up with',
    termsNote:
        'By signing up you acknowledge and agree to Budgy Terms of Use and Privacy Policy',
    errorPrefix: 'Error',
    errorSaveFailed: "Couldn't save. Check your connection and try again.",
    savedOffline: 'Saved. It will sync when you are back online.',
    errorGeneric: 'Something went wrong. Please try again.',
    channelPaymentsName: 'Payment reminders',
    channelPaymentsDesc: 'Reminders for rent, bills and other regular payments',
    channelDailyName: 'Daily reminder',
    channelDailyDesc: 'A nudge to log today\'s spending',
    channelWeeklyName: 'Weekly summary',
    channelWeeklyDesc: 'Your earnings for the week',
    confirmPasswordTitle: 'Confirm your password',
    deleteAccountFailed:
        "Your account couldn't be deleted. Please try again.",
    deleteAccountReauthFailed:
        'We need to verify it\'s you before deleting the account. '
        'Sign in again and retry.',
    signInErrorNetwork:
        'No connection. Check your internet and try again.',
    signInErrorTooMany:
        'Too many attempts. Wait a moment and try again.',
    signInErrorDisabled:
        'This account has been disabled. Please contact support.',
    signOutFailed: "Couldn't sign out. Check your connection and try again.",
    dataLoadFailed:
        "Couldn't load your data. Check your connection and try again.",
    verifySendFailed:
        "Couldn't send the verification email. Please try again.",
    aiAddTitle: 'Quick add',
    aiAddHint: 'Type or speak — amounts and categories are filled in for you.',
    aiInputHint: 'e.g. "coffee 90, groceries 450"',
    aiParseAction: 'Parse',
    aiSaveAllTpl: 'Save {n} transactions',
    aiNothingFound: "Couldn't find an amount — try rephrasing.",
    aiVoiceUnavailable: 'Voice input is unavailable on this device.',
    aiVoicePermission:
        'Budgy doesn’t have access to the microphone. Allow it in Settings → Budgy → Microphone and Speech Recognition, then try again.',
    aiVoicePermissionAndroid:
        'Budgy doesn’t have access to the microphone. Allow it in Settings → Apps → Budgy → Permissions → Microphone, then try again.',
    aiVoiceNothingHeard:
        'Didn’t catch anything. Tap the microphone and speak a bit closer to the phone.',
    aiVoiceNetwork:
        'Speech recognition needs internet right now. Check your connection and try again — or just type it.',
    aiVoiceLanguage:
        'Voice input isn’t available in this language on this device. Pick another one in Settings → Voice input language, or just type it.',
    aiVoiceFailed: 'Voice input stopped. Try again — or just type it.',
    notifTitle: 'Notifications',
    notifHeroBody: 'Choose which reminders reach you. Everything is scheduled '
        'on this device — nothing is sent from a server.',
    notifSectionSystem: 'System permission',
    notifPermGrantedTitle: 'Notifications allowed',
    notifPermGrantedBody: 'This device can show reminders from Budgy.',
    notifPermDeniedTitle: 'Notifications are off in system settings',
    notifPermDeniedBody: 'None of the reminders below can appear until you '
        'allow them in your device settings: Notifications › Budgy.',
    notifSectionDaily: 'Daily',
    notifDailyDesc: 'Every day at the hour you pick, a nudge to log what you '
        'spent today.',
    notifDailyHourTitle: 'Time',
    notifWeeklyDesc: 'Sundays at 20:00 — your earnings for the week. '
        'Comes with the daily reminder.',
    notifSectionPayments: 'Payments',
    notifPaymentsDescTpl: 'For each recurring expense, on its payment days '
        'at 10:00. {n} set up right now.',
    notifManagePayments: 'Manage recurring expenses',
  );

  static const tr = Strings(
    localeCode: 'tr',
    thisMonth: 'bu ay',
    nameHint: 'İsim',
    create: 'Oluştur',
    save: 'Kaydet',
    saving: 'Kaydediliyor...',
    cancel: 'İptal',
    removeWord: 'Kaldır',
    deleteWord: 'Sil',
    deleteTxTitle: 'İşlemi sil?',
    deleteTxBody: 'İşlem kaldırılacak, bakiyeler güncellenecek.',
    skip: 'Atla',
    expenseFromThis: '− Bu zarftan harcama',
    incomeTitle: 'Gelir',
    amountHint: 'Tutar, ₺',
    expenseTitle: 'Harcama',
    addTxTitle: 'Yeni işlem ekle',
    amountTitle: 'Tutar',
    dateLabel: 'Tarih',
    selectCategory: 'Kategori seç',
    convertTitle: 'Döviz çevir',
    giveLabel: 'Verdiğin',
    getLabel: 'Aldığın',
    convertAction: 'Çevir',
    rateHint: 'güncel kur',
    rateUnavailable: 'Kur alınamadı — elle gir',
    moneyLeft: 'Kalan para',
    goalLeft: 'kaldı',
    removeBudget: 'Bütçeyi kaldır',
    createAccount: 'Hesap oluştur',
    createAccountHint: 'Verini güvenceye al, her cihazdan gir',
    verifyEmailTitle: 'E-postanı doğrula',
    verifyEmailBody:
        'E-postana doğrulama linki gönderdik. Linke tıkla, sonra aşağıdaki butona bas.',
    verifyDone: 'Doğruladım',
    verifyResend: 'Linki tekrar gönder',
    verifyNotYet: 'Henüz doğrulanmadı — mailini kontrol et',
    verifySent: 'Doğrulama linki gönderildi',
    invalidEmail: 'Geçerli bir e-posta gir',
    passwordsDontMatch: 'Şifreler eşleşmiyor',
    detailedEntry: 'Detaylı giriş',
    dailyReminderLabel: 'Günlük hatırlatma',
    dailyReminderTitle: 'Bugün harcamalarını girdin mi?',
    dailyReminderBody: 'Kalan paranı güncel tut — birkaç saniye sürer.',
    workEarning: 'Çalışma kazancı',
    addFunds: 'Para ekle',
    addFundsTitle: 'Para ekle',
    savingsTitle: 'Birikim',
    savingsTotalLabel: 'Toplam birikim',
    budgetDoneTitle: 'Bütçe Hazır',
    budgetDoneSubtitle:
        'Her şey tamam! Bütçen hazır, paranı yönetmeye başlayabilirsin',
    addMore: 'Daha ekle',
    pocketName: 'Kasa (dağıtılmamış)',
    transferTitle: 'Transfer',
    selectEnvelope: 'Bir zarf seç',
    envelopeLabel: 'Zarf',
    searchHint: 'Ara',
    noteHint: 'Not',
    seeAll: 'Tümü',
    noOperations: 'Henüz işlem yok',
    today: 'Bugün',
    yesterday: 'Dün',
    incomeWord: 'Gelir',
    expenseWord: 'Harcama',
    workDaysTitle: 'Çalışma günleri',
    weekdaysShort: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    worked: 'Çalışıldı',
    planned: 'Planlandı',
    earned: 'Kazanıldı',
    monthForecast: 'Ay tahmini',
    daysShort: 'gün',
    dayEarningsHint: 'O günün kazancı, ₺',
    remindersEmpty:
        'Düzenli bir ödeme için hatırlatıcı ekle — örn. kira ayın 1\'i ile 5\'i arası. Her ay o günlerde bildirim gelir.',
    newReminder: '+ Yeni hatırlatıcı',
    reminderNameHint: 'İsim (Kira...)',
    amountOptionalHint: 'Tutar, ₺ (isteğe bağlı)',
    remindFrom: 'Hatırlat:',
    toWord: '–',
    dayOfMonthWord: 'günleri',
    dontForgetTpl: 'Unutma: {x}',
    dontForgetPlain: 'Bu ödemeyi unutma',
    analyticsTitle: 'Analiz',
    spent: 'harcandı',
    reportSubtitle: 'Harcamalarının basit bir raporunu gör',
    accountInformation: 'Hesap Bilgileri',
    changePassword: 'Şifre değiştir',
    confidentialityPolicy: 'Gizlilik politikası',
    faqs: 'SSS',
    helpCenter: 'Yardım Merkezi',
    signOutWord: 'Çıkış yap',
    deleteAccount: 'Hesabı sil',
    deleteAccountBody:
        'Bu, hesabını ve tüm verini kalıcı olarak siler. Geri alınamaz.',
    historyTitle: 'Harcama Geçmişi',
    searchHistory: 'Geçmişte ara',
    categoriesLabel: 'Kategoriler',
    applyFilter: 'Filtreyi Uygula',
    sortFilterTitle: 'Sırala ve Filtrele',
    sortByLabel: 'Sıralama',
    sortDate: 'Tarih',
    sortAmount: 'Tutar',
    sortCategory: 'Kategori',
    sortAscending: 'Artan',
    sortDescending: 'Azalan',
    accountLabel: 'Hesap',
    filterAll: 'Tümü',
    filterNoAccount: 'Hesapsız',
    periodLabel: 'Dönem',
    periodAllTime: 'Tüm zamanlar',
    periodThisMonth: 'Bu ay',
    periodLast30: '30 gün',
    periodPickDay: 'Gün seç',
    spentThisMonth: 'Bu ay harcanan',
    activityExpenses: 'İşlem Hareketleri',
    setAsideFor: '{name} için {amount} ayırdın',
    calculateBudget: 'Bütçe Belirle',
    shareWord: 'Paylaş',
    archiveWord: 'Arşivle',
    unarchiveWord: 'Arşivden çıkar',
    exportWord: 'Dışa aktar',
    deleteCatTitle: 'Zarfı sil',
    deleteCatBody: 'Bu zarfı silmek onu listenden kalıcı olarak kaldırır',
    exportTitle: 'Raporu dışa aktar',
    exportBody:
        'Dışa aktarınca, uygulama dışında saklayıp paylaşabileceğin bir kopya oluşur',
    noteLabel: 'Not',
    budgetName: 'Bütçe Adı',
    budgetAmount: 'Bütçe Tutarı',
    startDate: 'Başlangıç',
    endDate: 'Bitiş',
    timePeriod: 'Periyot',
    selectPeriod: 'Periyot seç',
    periodWeekly: 'Haftalık',
    periodMonthly: 'Aylık',
    periodYearly: 'Yıllık',
    chooseWord: 'Seç',
    withoutEnvelope: 'Zarfsız',
    goalsTitle: 'Hedefler',
    goalsEmpty:
        'Herhangi bir zarfa hedef koy — araba, tatil, laptop — ve birikimi izle.',
    newGoal: '+ Yeni hedef',
    targetAmountHint: 'Hedef tutar, ₺',
    setGoal: 'Hedef koy',
    removeGoalTitle: '"{name}" hedefi kaldırılsın mı?',
    removeGoalBody: 'Zarf ve para kalır, sadece hedef silinir.',
    languageTitle: 'Dil',
    currencyTitle: 'Para birimi',
    themeSystem: 'Sistem',
    themeLight: 'Açık',
    themeDark: 'Koyu',
    weeklySummaryTitle: 'Haftalık özet',
    weeklySummaryBodyTpl: 'Bu hafta {x} kazandın',
    recurringTitle: 'Düzenli Giderler',
    recurringMonthlyLabel: 'Aylık toplam',
    dueInDaysTpl: '{n} gün sonra',
    dueNowLabel: 'Ödeme zamanı',
    anonymousTitle: 'Anonim hesap',
    tabHome: 'Ana sayfa',
    tabCalendar: 'Takvim',
    presetNames: {
      'rent': 'Kira',
      'food': 'Yemek',
      'travel': 'Seyahat',
      'transport': 'Ulaşım',
      'health': 'Sağlık',
      'gifts': 'Hediyeler',
      'education': 'Eğitim',
      'clothes': 'Giyim',
      'savings': 'Birikim',
      'other': 'Diğer',
    },
    reviewTitle: 'Zarfların hazır',
    navCompleteProfile: 'Profili tamamla',
    profileSubtitle: 'Profilinde kendini başkalarına tanıt',
    phoneLabel: 'Telefon numarası',
    phoneHint: 'Numaranı gir',
    dontHaveAccount: 'Hesabın yok mu?',
    forgetTitle: 'Şifremi unuttum',
    forgetSubtitle: 'Şifreni değiştirmek için e-posta adresini gir',
    checkEmailTitle: 'E-postanı kontrol et',
    checkEmailBody:
        'Yeni şifre oluşturman için {email} adresine ulaştık',
    notNow: 'Şimdi değil',
    resend: 'Tekrar gönder',
    spamNote: 'E-postayı görmüyorsan spam klasörünü kontrol et',
    navSignUp: 'Kaydol',
    signUpTitle: 'Kaydol',
    signUpSubtitle:
        'Ücretsiz ve bir dakika sürer. Paranın günlük net görünümünü elde et.',
    fullNameLabel: 'Ad soyad',
    fullNameHint: 'Adını gir',
    confirmPasswordLabel: 'Şifreyi onayla',
    reqMin8: 'En az 8 karakter olmalı',
    reqNoName: 'Adını veya e-posta adresini içeremez',
    reqSymbol: 'En az bir sembol veya rakam içermeli',
    continueButton: 'Devam',
    signInTitle: 'Giriş yap',
    signInSubtitle:
        'Geri döndüğüne çok sevindik. Hadi başlayalım ve sana özel haberlere bakalım!',
    emailLabel: 'E-posta',
    emailHint: 'E-postanı gir',
    passwordLabel: 'Şifre',
    passwordHint: 'Şifreni gir',
    forgotPassword: 'Şifremi unuttum',
    signInButton: 'Giriş yap',
    signInError:
        'Hata! Girdiğin e-posta veya şifre yanlış, lütfen e-postanı ve şifreni kontrol et!',
    continueGoogle: 'Google ile devam et',
    continueApple: 'Apple ile devam et',
    orSignUpWith: 'veya şununla kaydol',
    termsNote:
        'Kaydolarak Budgy Kullanım Koşulları ve Gizlilik Politikası\'nı kabul etmiş olursun',
    errorPrefix: 'Hata',
    errorSaveFailed: 'Kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
    savedOffline: 'Kaydedildi. Bağlantı gelince eşitlenecek.',
    errorGeneric: 'Bir şeyler ters gitti. Lütfen tekrar dene.',
    channelPaymentsName: 'Ödeme hatırlatmaları',
    channelPaymentsDesc: 'Kira, fatura ve diğer düzenli ödemeler için hatırlatma',
    channelDailyName: 'Günlük hatırlatma',
    channelDailyDesc: 'Bugünkü harcamalarını girmen için dürtme',
    channelWeeklyName: 'Haftalık özet',
    channelWeeklyDesc: 'Bu haftaki kazancın',
    confirmPasswordTitle: 'Şifreni doğrula',
    deleteAccountFailed: 'Hesabın silinemedi. Lütfen tekrar dene.',
    deleteAccountReauthFailed:
        'Hesabı silmeden önce kimliğini doğrulamamız gerekiyor. '
        'Tekrar giriş yapıp yeniden dene.',
    signInErrorNetwork: 'Bağlantı yok. İnternetini kontrol edip tekrar dene.',
    signInErrorTooMany: 'Çok fazla deneme oldu. Biraz bekleyip tekrar dene.',
    signInErrorDisabled:
        'Bu hesap devre dışı bırakılmış. Lütfen destekle iletişime geç.',
    signOutFailed: 'Çıkış yapılamadı. Bağlantını kontrol edip tekrar dene.',
    dataLoadFailed:
        'Verilerin yüklenemedi. Bağlantını kontrol edip tekrar dene.',
    verifySendFailed: 'Doğrulama e-postası gönderilemedi. Lütfen tekrar dene.',
    aiAddTitle: 'Hızlı ekle',
    aiAddHint: 'Yaz ya da söyle — tutar ve kategori senin yerine doldurulur.',
    aiInputHint: 'örn. "kahve 90, market 450"',
    aiParseAction: 'Çözümle',
    aiSaveAllTpl: '{n} işlemi kaydet',
    aiNothingFound: 'Tutar bulamadım — biraz farklı yazmayı dene.',
    aiVoiceUnavailable: 'Bu cihazda sesli giriş kullanılamıyor.',
    aiVoicePermission:
        'Budgy’nin mikrofona erişim izni yok. Ayarlar → Budgy → Mikrofon ve Konuşma Tanıma’dan izin ver, sonra tekrar dene.',
    aiVoicePermissionAndroid:
        'Budgy’nin mikrofona erişim izni yok. Ayarlar → Uygulamalar → Budgy → İzinler → Mikrofon’dan izin ver, sonra tekrar dene.',
    aiVoiceNothingHeard:
        'Hiçbir şey duyamadım. Mikrofona dokunup telefona biraz daha yakın konuş.',
    aiVoiceNetwork:
        'Konuşma tanıma şu an internet istiyor. Bağlantını kontrol edip tekrar dene — ya da yazıver.',
    aiVoiceLanguage:
        'Bu dilde sesli giriş bu cihazda yok. Ayarlar → Sesli giriş dili’nden başka bir dil seç ya da yazıver.',
    aiVoiceFailed: 'Sesli giriş durdu. Tekrar dene — ya da yazıver.',
    notifTitle: 'Bildirimler',
    notifHeroBody: 'Hangi hatırlatmaların geleceğini buradan seç. Her şey bu '
        'cihazda planlanır — sunucudan bir şey gönderilmez.',
    notifSectionSystem: 'Sistem izni',
    notifPermGrantedTitle: 'Bildirimlere izin verildi',
    notifPermGrantedBody: 'Bu cihaz Budgy hatırlatmalarını gösterebilir.',
    notifPermDeniedTitle: 'Bildirimler sistemde kapalı',
    notifPermDeniedBody: 'Cihaz ayarlarında Bildirimler › Budgy açılana kadar '
        'aşağıdaki hatırlatmaların hiçbiri görünmez.',
    notifSectionDaily: 'Günlük',
    notifDailyDesc: 'Her gün seçtiğin saatte bugünkü harcamalarını girmeni '
        'hatırlatır.',
    notifDailyHourTitle: 'Saat',
    notifWeeklyDesc: 'Pazar 20:00 — haftanın kazancı. Günlük hatırlatma '
        'açıkken gelir.',
    notifSectionPayments: 'Ödemeler',
    notifPaymentsDescTpl: 'Her düzenli gider için ödeme günlerinde 10:00\'da. '
        'Şu an {n} tanımlı.',
    notifManagePayments: 'Düzenli giderleri yönet',
  );

  static const ru = Strings(
    localeCode: 'ru',
    thisMonth: 'в этом месяце',
    nameHint: 'Название',
    create: 'Создать',
    save: 'Сохранить',
    saving: 'Сохраняю...',
    cancel: 'Отмена',
    removeWord: 'Убрать',
    deleteWord: 'Удалить',
    deleteTxTitle: 'Удалить операцию?',
    deleteTxBody: 'Операция удалится, балансы обновятся.',
    skip: 'Пропустить',
    expenseFromThis: '− Расход из этого конверта',
    incomeTitle: 'Доход',
    amountHint: 'Сумма, ₺',
    expenseTitle: 'Расход',
    addTxTitle: 'Новая операция',
    amountTitle: 'Сумма',
    dateLabel: 'Дата',
    selectCategory: 'Категория',
    convertTitle: 'Обмен валюты',
    giveLabel: 'Отдаёшь',
    getLabel: 'Получаешь',
    convertAction: 'Обменять',
    rateHint: 'текущий курс',
    rateUnavailable: 'Курс недоступен — введи вручную',
    moneyLeft: 'Остаток',
    goalLeft: 'осталось',
    removeBudget: 'Убрать бюджет',
    createAccount: 'Создать аккаунт',
    createAccountHint: 'Сохрани данные и входи с любого устройства',
    verifyEmailTitle: 'Подтверди email',
    verifyEmailBody:
        'Мы отправили ссылку для подтверждения на твою почту. Открой её и нажми кнопку ниже.',
    verifyDone: 'Я подтвердил',
    verifyResend: 'Отправить ссылку снова',
    verifyNotYet: 'Ещё не подтверждено — проверь почту',
    verifySent: 'Ссылка для подтверждения отправлена',
    invalidEmail: 'Введи корректный email',
    passwordsDontMatch: 'Пароли не совпадают',
    detailedEntry: 'Подробный ввод',
    dailyReminderLabel: 'Ежедневное напоминание',
    dailyReminderTitle: 'Записал сегодняшние траты?',
    dailyReminderBody: 'Держи остаток в курсе — это пара секунд.',
    workEarning: 'Заработок',
    addFunds: 'Пополнить',
    addFundsTitle: 'Пополнение',
    savingsTitle: 'Накопления',
    savingsTotalLabel: 'Всего накоплено',
    budgetDoneTitle: 'Бюджет готов',
    budgetDoneSubtitle:
        'Готово! Твой бюджет настроен, можно управлять деньгами',
    addMore: 'Добавить ещё',
    pocketName: 'Наличные (нераспределённые)',
    transferTitle: 'Перевод',
    selectEnvelope: 'Выбери конверт',
    envelopeLabel: 'Конверт',
    searchHint: 'Поиск',
    noteHint: 'Заметка',
    seeAll: 'Все',
    noOperations: 'Пока нет операций',
    today: 'Сегодня',
    yesterday: 'Вчера',
    incomeWord: 'Доход',
    expenseWord: 'Расход',
    workDaysTitle: 'Рабочие дни',
    weekdaysShort: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
    worked: 'Отработано',
    planned: 'Запланировано',
    earned: 'Заработано',
    monthForecast: 'Прогноз за месяц',
    daysShort: 'дн.',
    dayEarningsHint: 'Заработок за день, ₺',
    remindersEmpty:
        'Добавь напоминание о регулярном платеже — например, аренда с 1 по 5 число. Каждый месяц в эти дни придёт уведомление.',
    newReminder: '+ Новое напоминание',
    reminderNameHint: 'Название (Аренда...)',
    amountOptionalHint: 'Сумма, ₺ (необязательно)',
    remindFrom: 'Напоминать с',
    toWord: 'по',
    dayOfMonthWord: 'число',
    dontForgetTpl: 'Не забудь: {x}',
    dontForgetPlain: 'Не забудь про этот платёж',
    analyticsTitle: 'Аналитика',
    spent: 'потрачено',
    reportSubtitle: 'Простой отчёт о твоих расходах',
    accountInformation: 'Информация об аккаунте',
    changePassword: 'Сменить пароль',
    confidentialityPolicy: 'Политика конфиденциальности',
    faqs: 'Вопросы',
    helpCenter: 'Поддержка',
    signOutWord: 'Выйти',
    deleteAccount: 'Удалить аккаунт',
    deleteAccountBody:
        'Аккаунт и все данные будут удалены навсегда. Отменить нельзя.',
    historyTitle: 'История трат',
    searchHistory: 'Поиск',
    categoriesLabel: 'Категории',
    applyFilter: 'Применить',
    sortFilterTitle: 'Сортировка и фильтр',
    sortByLabel: 'Сортировка',
    sortDate: 'Дата',
    sortAmount: 'Сумма',
    sortCategory: 'Категория',
    sortAscending: 'По возрастанию',
    sortDescending: 'По убыванию',
    accountLabel: 'Счёт',
    filterAll: 'Все',
    filterNoAccount: 'Без счёта',
    periodLabel: 'Период',
    periodAllTime: 'Всё время',
    periodThisMonth: 'Этот месяц',
    periodLast30: '30 дней',
    periodPickDay: 'Выбрать день',
    spentThisMonth: 'Потрачено в этом месяце',
    activityExpenses: 'Движения',
    setAsideFor: 'Отложено {amount} на {name}',
    calculateBudget: 'Задать бюджет',
    shareWord: 'Поделиться',
    archiveWord: 'В архив',
    unarchiveWord: 'Из архива',
    exportWord: 'Экспорт',
    deleteCatTitle: 'Удалить конверт',
    deleteCatBody: 'Удаление навсегда уберёт этот конверт из списка',
    exportTitle: 'Экспорт отчёта',
    exportBody:
        'Экспорт создаст копию, которую можно сохранить или отправить вне приложения',
    noteLabel: 'Заметка',
    budgetName: 'Название',
    budgetAmount: 'Сумма бюджета',
    startDate: 'Начало',
    endDate: 'Конец',
    timePeriod: 'Период',
    selectPeriod: 'Выбери период',
    periodWeekly: 'Еженедельно',
    periodMonthly: 'Ежемесячно',
    periodYearly: 'Ежегодно',
    chooseWord: 'Выбрать',
    withoutEnvelope: 'Без конверта',
    goalsTitle: 'Цели',
    goalsEmpty:
        'Поставь цель любому конверту — машина, отпуск, ноутбук — и следи, как копится.',
    newGoal: '+ Новая цель',
    targetAmountHint: 'Целевая сумма, ₺',
    setGoal: 'Поставить цель',
    removeGoalTitle: 'Убрать цель «{name}»?',
    removeGoalBody: 'Конверт и деньги останутся, исчезнет только цель.',
    languageTitle: 'Язык',
    currencyTitle: 'Валюта',
    themeSystem: 'Системная',
    themeLight: 'Светлая',
    themeDark: 'Тёмная',
    weeklySummaryTitle: 'Итоги недели',
    weeklySummaryBodyTpl: 'На этой неделе вы заработали {x}',
    recurringTitle: 'Регулярные платежи',
    recurringMonthlyLabel: 'Всего в месяц',
    dueInDaysTpl: 'через {n} дн.',
    dueNowLabel: 'Пора платить',
    anonymousTitle: 'Анонимный аккаунт',
    tabHome: 'Главная',
    tabCalendar: 'Календарь',
    presetNames: {
      'rent': 'Аренда',
      'food': 'Еда',
      'travel': 'Путешествия',
      'transport': 'Транспорт',
      'health': 'Здоровье',
      'gifts': 'Подарки',
      'education': 'Обучение',
      'clothes': 'Одежда',
      'savings': 'Накопления',
      'other': 'Прочее',
    },
    reviewTitle: 'Конверты готовы',
    navCompleteProfile: 'Заполни профиль',
    profileSubtitle: 'Расскажи о себе в своём профиле',
    phoneLabel: 'Телефон',
    phoneHint: 'Введи номер',
    dontHaveAccount: 'Нет аккаунта?',
    forgetTitle: 'Забыли пароль',
    forgetSubtitle: 'Введи email, чтобы сменить пароль',
    checkEmailTitle: 'Проверь почту',
    checkEmailBody:
        'Мы написали на {email}, чтобы помочь задать новый пароль',
    notNow: 'Не сейчас',
    resend: 'Отправить ещё раз',
    spamNote: 'Если письма нет — проверь папку «Спам»',
    navSignUp: 'Регистрация',
    signUpTitle: 'Регистрация',
    signUpSubtitle:
        'Это бесплатно и займёт минуту. Получи ясную картину своих денег каждый день.',
    fullNameLabel: 'Имя',
    fullNameHint: 'Введи своё имя',
    confirmPasswordLabel: 'Повтори пароль',
    reqMin8: 'Минимум 8 символов',
    reqNoName: 'Без имени или email-адреса',
    reqSymbol: 'Хотя бы один символ или цифра',
    continueButton: 'Продолжить',
    signInTitle: 'Вход',
    signInSubtitle:
        'Мы очень рады, что ты вернулся. Давай продолжим и узнаем свежие новости для тебя!',
    emailLabel: 'Email',
    emailHint: 'Введи email',
    passwordLabel: 'Пароль',
    passwordHint: 'Введи пароль',
    forgotPassword: 'Забыл пароль',
    signInButton: 'Войти',
    signInError:
        'Ошибка! Введённый email или пароль неверны, проверь email и пароль!',
    continueGoogle: 'Войти через Google',
    continueApple: 'Войти через Apple',
    orSignUpWith: 'или войди через',
    termsNote:
        'Регистрируясь, ты принимаешь Условия использования и Политику конфиденциальности Budgy',
    errorPrefix: 'Ошибка',
    errorSaveFailed: 'Не удалось сохранить. Проверьте соединение и повторите.',
    savedOffline: 'Сохранено. Синхронизируется, когда появится сеть.',
    errorGeneric: 'Что-то пошло не так. Попробуйте ещё раз.',
    channelPaymentsName: 'Напоминания о платежах',
    channelPaymentsDesc: 'Напоминания об аренде, счетах и других регулярных платежах',
    channelDailyName: 'Ежедневное напоминание',
    channelDailyDesc: 'Напоминание внести траты за день',
    channelWeeklyName: 'Итоги недели',
    channelWeeklyDesc: 'Ваш заработок за неделю',
    confirmPasswordTitle: 'Подтвердите пароль',
    deleteAccountFailed: 'Не удалось удалить аккаунт. Попробуйте ещё раз.',
    deleteAccountReauthFailed:
        'Перед удалением аккаунта нужно подтвердить личность. '
        'Войдите заново и повторите.',
    signInErrorNetwork: 'Нет соединения. Проверь интернет и попробуй снова.',
    signInErrorTooMany:
        'Слишком много попыток. Подожди немного и попробуй снова.',
    signInErrorDisabled: 'Этот аккаунт отключён. Обратись в поддержку.',
    signOutFailed: 'Не удалось выйти. Проверь соединение и попробуй снова.',
    dataLoadFailed:
        'Не удалось загрузить данные. Проверь соединение и попробуй снова.',
    verifySendFailed:
        'Не удалось отправить письмо для подтверждения. Попробуй ещё раз.',
    aiAddTitle: 'Быстрая запись',
    aiAddHint: 'Напиши или скажи — суммы и категории заполнятся сами.',
    aiInputHint: 'напр. «кофе 90, продукты 450»',
    aiParseAction: 'Разобрать',
    aiSaveAllTpl: 'Сохранить {n} операций',
    aiNothingFound: 'Не нашёл сумму — попробуй сказать иначе.',
    aiVoiceUnavailable: 'Голосовой ввод недоступен на этом устройстве.',
    aiVoicePermission:
        'У Budgy нет доступа к микрофону. Разреши его в Настройки → Budgy → Микрофон и Распознавание речи, потом попробуй снова.',
    aiVoicePermissionAndroid:
        'У Budgy нет доступа к микрофону. Разреши его в Настройки → Приложения → Budgy → Разрешения → Микрофон, потом попробуй снова.',
    aiVoiceNothingHeard:
        'Ничего не расслышал. Нажми на микрофон и скажи чуть ближе к телефону.',
    aiVoiceNetwork:
        'Распознаванию речи сейчас нужен интернет. Проверь соединение и попробуй снова — или просто напиши.',
    aiVoiceLanguage:
        'Голосовой ввод на этом языке на устройстве недоступен. Выбери другой в Настройки → Язык голосового ввода — или просто напиши.',
    aiVoiceFailed: 'Голосовой ввод прервался. Попробуй ещё раз — или просто напиши.',
    notifTitle: 'Уведомления',
    notifHeroBody: 'Выбери, какие напоминания приходить. Всё планируется на '
        'этом устройстве — с сервера ничего не отправляется.',
    notifSectionSystem: 'Разрешение системы',
    notifPermGrantedTitle: 'Уведомления разрешены',
    notifPermGrantedBody: 'Это устройство может показывать напоминания Budgy.',
    notifPermDeniedTitle: 'Уведомления выключены в системе',
    notifPermDeniedBody: 'Ни одно из напоминаний ниже не появится, пока ты не '
        'разрешишь их в настройках устройства: Уведомления › Budgy.',
    notifSectionDaily: 'Ежедневно',
    notifDailyDesc: 'Каждый день в выбранный час — напоминание записать '
        'сегодняшние траты.',
    notifDailyHourTitle: 'Время',
    notifWeeklyDesc: 'По воскресеньям в 20:00 — заработок за неделю. '
        'Приходит вместе с ежедневным напоминанием.',
    notifSectionPayments: 'Платежи',
    notifPaymentsDescTpl: 'Для каждого регулярного расхода в дни оплаты в '
        '10:00. Сейчас настроено: {n}.',
    notifManagePayments: 'Управлять регулярными расходами',
  );
}

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
    required this.goodMorning,
    required this.goodAfternoon,
    required this.goodEvening,
    required this.goodNight,
    required this.totalBreakdown,
    required this.thisMonth,
    required this.bannerSubtitle,
    required this.bannerNote,
    required this.distributeHint,
    required this.newEnvelope,
    required this.editEnvelope,
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
    required this.deleteEnvelopeTitle,
    required this.deleteEnvelopeWithBalance,
    required this.deleteEnvelopeHistory,
    required this.incomeTitle,
    required this.amountHint,
    required this.incomeNoteHint,
    required this.distribution,
    required this.allDistributed,
    required this.remainingTpl,
    required this.createEnvelopesFirst,
    required this.expenseTitle,
    required this.newTransaction,
    required this.addTxTitle,
    required this.amountTitle,
    required this.dateLabel,
    required this.selectCategory,
    required this.repeatLabel,
    required this.convertTitle,
    required this.giveLabel,
    required this.getLabel,
    required this.convertAction,
    required this.rateHint,
    required this.rateUnavailable,
    required this.moneyLeft,
    required this.waitingToDistribute,
    required this.waitingSubtitle,
    required this.distributeToEnvelopes,
    required this.thisWeekEarnings,
    required this.envelopesTitle,
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
    required this.lockTitle,
    required this.unlockButton,
    required this.biometricUnavailable,
    required this.quickAddTitle,
    required this.detailedEntry,
    required this.dailyReminderLabel,
    required this.dailyReminderTitle,
    required this.dailyReminderBody,
    required this.workEarning,
    required this.addFunds,
    required this.addFundsTitle,
    required this.savingsTitle,
    required this.savingsMonthlyTitle,
    required this.savingsTotalLabel,
    required this.savingsEmpty,
    required this.budgetDoneTitle,
    required this.budgetDoneSubtitle,
    required this.addMore,
    required this.pocketName,
    required this.transferTitle,
    required this.fromLabel,
    required this.toLabel,
    required this.selectEnvelope,
    required this.onbSelectTitle,
    required this.envelopeLabel,
    required this.searchHint,
    required this.noteHint,
    required this.journalTitle,
    required this.overallActivity,
    required this.recentTitle,
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
    required this.dailyRate,
    required this.dailyRateHint,
    required this.dayEarningsHint,
    required this.emptyByRateTpl,
    required this.remindersTitle,
    required this.remindersEmpty,
    required this.newReminder,
    required this.reminderNameHint,
    required this.amountOptionalHint,
    required this.remindFrom,
    required this.toWord,
    required this.dayOfMonthWord,
    required this.everyDayTpl,
    required this.fromToTpl,
    required this.dontForgetTpl,
    required this.dontForgetPlain,
    required this.notificationsChannel,
    required this.analyticsTitle,
    required this.spent,
    required this.noExpensesMonth,
    required this.incomeLabel,
    required this.expenseLabel,
    required this.last6Months,
    required this.reportTitle,
    required this.reportSubtitle,
    required this.accountSettings,
    required this.securitySection,
    required this.otherSection,
    required this.accountInformation,
    required this.personalInfo,
    required this.notificationPreferences,
    required this.notificationSettings,
    required this.changePassword,
    required this.confidentialityPolicy,
    required this.passwordSecurity,
    required this.biometricAuth,
    required this.faqs,
    required this.helpCenter,
    required this.settingsWord,
    required this.comingSoon,
    required this.signOutWord,
    required this.deleteAccount,
    required this.deleteAccountBody,
    required this.historyTitle,
    required this.searchHistory,
    required this.filterTitle,
    required this.categoriesLabel,
    required this.applyFilter,
    required this.spentThisMonth,
    required this.allCategoryExpenses,
    required this.viewMoreDetail,
    required this.activityExpenses,
    required this.setAsideFor,
    required this.calculateBudget,
    required this.shareWord,
    required this.archiveWord,
    required this.unarchiveWord,
    required this.exportWord,
    required this.archivedSection,
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
    required this.profileTitle,
    required this.dailyRateSubtitle,
    required this.remindersSubtitle,
    required this.journalSubtitle,
    required this.languageTitle,
    required this.currencyTitle,
    required this.appearanceTitle,
    required this.themeSystem,
    required this.themeLight,
    required this.themeDark,
    required this.streakTitle,
    required this.streakDaysTpl,
    required this.streakKeepGoing,
    required this.streakStart,
    required this.paceOverTpl,
    required this.paceProjectedTpl,
    required this.paceOnTrack,
    required this.insightsTitle,
    required this.vsLastMonth,
    required this.newBadge,
    required this.weeklySummaryTitle,
    required this.weeklySummaryBodyTpl,
    required this.recurringTitle,
    required this.recurringMonthlyLabel,
    required this.dueInDaysTpl,
    required this.dueNowLabel,
    required this.customEmojiHint,
    required this.anonymousTitle,
    required this.anonymousBody,
    required this.tabHome,
    required this.tabAnalytics,
    required this.tabGoals,
    required this.tabCalendar,
    required this.tabProfile,
    required this.onboardSubtitle,
    required this.createEnvelopesTpl,
    required this.presetNames,
    required this.onbStory,
    required this.onbContinue,
    required this.onbStart,
    required this.welcomeTitle,
    required this.welcomeSubtitle,
    required this.reviewTitle,
    required this.reviewSubtitle,
    required this.navCompleteProfile,
    required this.yourProfileTitle,
    required this.profileSubtitle,
    required this.phoneLabel,
    required this.phoneHint,
    required this.genderLabel,
    required this.genderMale,
    required this.genderFemale,
    required this.genderOther,
    required this.dobLabel,
    required this.dobHint,
    required this.addressLabel,
    required this.addressHint,
    required this.dontHaveAccount,
    required this.navForgetPassword,
    required this.forgetTitle,
    required this.forgetSubtitle,
    required this.checkEmailTitle,
    required this.checkEmailBody,
    required this.notNow,
    required this.resend,
    required this.spamNote,
    required this.passwordUpdated,
    required this.navNewPassword,
    required this.newPasswordTitle,
    required this.repeatPasswordLabel,
    required this.repeatPasswordHint,
    required this.navVerifyOtp,
    required this.otpTitle,
    required this.otpSubtitle,
    required this.enterOtp,
    required this.resendIn,
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
    required this.rememberMe,
    required this.forgotPassword,
    required this.signInButton,
    required this.signInError,
    required this.signUpApple,
    required this.continueGoogle,
    required this.continueApple,
    required this.continueFacebook,
    required this.orSignUpWith,
    required this.loginMyAccount,
    required this.termsNote,
    required this.errorPrefix,
  });

  final String localeCode;
  final String waitingToDistribute; // amber kart başlığı
  final String waitingSubtitle; // amber kart alt metni
  final String distributeToEnvelopes; // "Zarflara böl" butonu
  final String thisWeekEarnings; // haftalık kazanç şeridi başlığı
  final String envelopesTitle; // "Zarflar" bölüm başlığı
  final String goodMorning;
  final String goodAfternoon;
  final String goodEvening;
  final String goodNight;
  final String totalBreakdown; // {in} / {un}
  final String thisMonth;
  final String bannerSubtitle; // {n}
  final String bannerNote; // {n}
  final String distributeHint;
  final String newEnvelope;
  final String editEnvelope;
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
  final String deleteEnvelopeTitle; // {name}
  final String deleteEnvelopeWithBalance; // {balance}
  final String deleteEnvelopeHistory;
  final String incomeTitle;
  final String amountHint;
  final String incomeNoteHint;
  final String distribution;
  final String allDistributed;
  final String remainingTpl; // {x}
  final String createEnvelopesFirst;
  final String expenseTitle;
  final String newTransaction;
  final String addTxTitle;
  final String amountTitle;
  final String dateLabel;
  final String selectCategory;
  final String repeatLabel;
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
  final String lockTitle;
  final String unlockButton;
  final String biometricUnavailable;
  final String quickAddTitle;
  final String detailedEntry;
  final String dailyReminderLabel;
  final String dailyReminderTitle;
  final String dailyReminderBody;
  final String workEarning;
  final String addFunds;
  final String addFundsTitle;
  final String savingsTitle;
  final String savingsMonthlyTitle;
  final String savingsTotalLabel;
  final String savingsEmpty;
  final String budgetDoneTitle;
  final String budgetDoneSubtitle;
  final String addMore;
  final String pocketName;
  final String transferTitle;
  final String fromLabel;
  final String toLabel;
  final String selectEnvelope;
  final String onbSelectTitle;
  final String envelopeLabel;
  final String searchHint;
  final String noteHint;
  final String journalTitle;
  final String overallActivity;
  final String recentTitle;
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
  final String dailyRate;
  final String dailyRateHint;
  final String dayEarningsHint;
  final String emptyByRateTpl; // {x}
  final String remindersTitle;
  final String remindersEmpty;
  final String newReminder;
  final String reminderNameHint;
  final String amountOptionalHint;
  final String remindFrom;
  final String toWord;
  final String dayOfMonthWord;
  final String everyDayTpl; // {d}
  final String fromToTpl; // {from} {to}
  final String dontForgetTpl; // {x}
  final String dontForgetPlain;
  final String notificationsChannel;
  final String analyticsTitle;
  final String spent;
  final String noExpensesMonth;
  final String incomeLabel;
  final String expenseLabel;
  final String last6Months;
  final String reportTitle;
  final String reportSubtitle;
  final String accountSettings;
  final String securitySection;
  final String otherSection;
  final String accountInformation;
  final String personalInfo;
  final String notificationPreferences;
  final String notificationSettings;
  final String changePassword;
  final String confidentialityPolicy;
  final String passwordSecurity;
  final String biometricAuth;
  final String faqs;
  final String helpCenter;
  final String settingsWord;
  final String comingSoon;
  final String signOutWord;
  final String deleteAccount;
  final String deleteAccountBody;
  final String historyTitle;
  final String searchHistory;
  final String filterTitle;
  final String categoriesLabel;
  final String applyFilter;
  final String spentThisMonth;
  final String allCategoryExpenses;
  final String viewMoreDetail;
  final String activityExpenses;
  final String setAsideFor; // {amount}, {name}
  final String calculateBudget;
  final String shareWord;
  final String archiveWord;
  final String unarchiveWord;
  final String exportWord;
  final String archivedSection;
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
  final String profileTitle;
  final String dailyRateSubtitle;
  final String remindersSubtitle;
  final String journalSubtitle;
  final String languageTitle;
  final String currencyTitle;
  final String appearanceTitle; // "Görünüm" ayar satırı
  final String themeSystem;
  final String themeLight;
  final String themeDark;
  final String streakTitle;
  final String streakDaysTpl; // {n}
  final String streakKeepGoing;
  final String streakStart;
  final String paceOverTpl; // {n}
  final String paceProjectedTpl; // {x}
  final String paceOnTrack;
  final String insightsTitle;
  final String vsLastMonth;
  final String newBadge;
  final String weeklySummaryTitle;
  final String weeklySummaryBodyTpl; // {x}
  final String recurringTitle;
  final String recurringMonthlyLabel;
  final String dueInDaysTpl; // {n}
  final String dueNowLabel;
  final String customEmojiHint;
  final String anonymousTitle;
  final String anonymousBody;
  final String tabHome;
  final String tabAnalytics;
  final String tabGoals;
  final String tabCalendar;
  final String tabProfile;
  final String onboardSubtitle;
  final String createEnvelopesTpl; // {n}
  final Map<String, String> presetNames;

  /// Слайды стори-онбординга: заголовок + подзаголовок.
  final List<({String title, String subtitle})> onbStory;
  final String onbContinue;
  final String onbStart;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final String reviewTitle;
  final String reviewSubtitle;
  final String navCompleteProfile;
  final String yourProfileTitle;
  final String profileSubtitle;
  final String phoneLabel;
  final String phoneHint;
  final String genderLabel;
  final String genderMale;
  final String genderFemale;
  final String genderOther;
  final String dobLabel;
  final String dobHint;
  final String addressLabel;
  final String addressHint;
  final String dontHaveAccount;
  final String navForgetPassword;
  final String forgetTitle;
  final String forgetSubtitle;
  final String checkEmailTitle;
  final String checkEmailBody; // {email}
  final String notNow;
  final String resend;
  final String spamNote;
  final String passwordUpdated;
  final String navNewPassword;
  final String newPasswordTitle;
  final String repeatPasswordLabel;
  final String repeatPasswordHint;
  final String navVerifyOtp;
  final String otpTitle;
  final String otpSubtitle;
  final String enterOtp;
  final String resendIn; // {time}
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
  final String rememberMe;
  final String forgotPassword;
  final String signInButton;
  final String signInError;
  final String signUpApple;
  final String continueGoogle;
  final String continueApple;
  final String continueFacebook;
  final String orSignUpWith;
  final String loginMyAccount;
  final String termsNote;
  final String errorPrefix;

  static const en = Strings(
    localeCode: 'en',
    goodMorning: 'Good morning',
    goodAfternoon: 'Good afternoon',
    goodEvening: 'Good evening',
    goodNight: 'Good night',
    totalBreakdown: '{in} in envelopes · {un} unsorted',
    thisMonth: 'this month',
    bannerSubtitle: 'Earned over {n} days — sort into envelopes',
    bannerNote: 'Earnings for {n} days',
    distributeHint: 'Tap to sort into envelopes',
    newEnvelope: 'New envelope',
    editEnvelope: 'Edit envelope',
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
    deleteEnvelopeTitle: 'Delete "{name}"?',
    deleteEnvelopeWithBalance:
        'This envelope holds {balance} — it will disappear from your total. Transaction history stays in the journal.',
    deleteEnvelopeHistory: 'Transaction history stays in the journal.',
    incomeTitle: 'Income',
    amountHint: 'Amount, ₺',
    incomeNoteHint: 'Note (salary...)',
    distribution: 'Distribution',
    allDistributed: '✓ all sorted',
    remainingTpl: 'left: {x}',
    createEnvelopesFirst: 'Create envelopes on the home screen first',
    expenseTitle: 'Expense',
    newTransaction: 'New transaction',
    addTxTitle: 'Add new transaction',
    amountTitle: 'Amount',
    dateLabel: 'Date',
    selectCategory: 'Select category',
    repeatLabel: 'Repeat',
    convertTitle: 'Convert currency',
    giveLabel: 'You give',
    getLabel: 'You get',
    convertAction: 'Convert',
    rateHint: 'live rate',
    rateUnavailable: 'Rate unavailable — enter manually',
    moneyLeft: 'Money left',
    waitingToDistribute: 'Waiting to distribute',
    waitingSubtitle: "Today's earnings aren't in envelopes yet. Choose how to split them.",
    distributeToEnvelopes: 'Sort into envelopes',
    thisWeekEarnings: "This week's earnings",
    envelopesTitle: 'Envelopes',
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
    lockTitle: 'Budgy is locked',
    unlockButton: 'Unlock',
    biometricUnavailable: 'No Face ID / fingerprint set up on this device',
    quickAddTitle: 'Quick expense',
    detailedEntry: 'More options',
    dailyReminderLabel: 'Daily reminder',
    dailyReminderTitle: 'Did you log today\'s spending?',
    dailyReminderBody: 'Keep your Money left up to date — takes seconds.',
    workEarning: 'Work earnings',
    addFunds: 'Add funds',
    addFundsTitle: 'Add funds',
    savingsTitle: 'Savings',
    savingsMonthlyTitle: 'Monthly savings',
    savingsTotalLabel: 'Total saved',
    savingsEmpty: 'No savings yet',
    budgetDoneTitle: 'Budget Completed',
    budgetDoneSubtitle:
        'All done! Your budget is ready, so you can start managing your money',
    addMore: 'Add more',
    pocketName: 'Cash (unallocated)',
    transferTitle: 'Transfer',
    fromLabel: 'From',
    toLabel: 'To',
    selectEnvelope: 'Select an envelope',
    onbSelectTitle: 'Select 5 or more envelopes',
    envelopeLabel: 'Envelope',
    searchHint: 'Search',
    noteHint: 'Note',
    journalTitle: 'Journal',
    overallActivity: 'Overall activity',
    recentTitle: 'Detail activity',
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
    dailyRate: 'Daily rate',
    dailyRateHint: 'Used when a day has no amount',
    dayEarningsHint: 'Earnings for the day, ₺',
    emptyByRateTpl: 'Empty — uses rate {x}',
    remindersTitle: 'Reminders',
    remindersEmpty:
        'Add a reminder for a recurring payment — e.g. rent from the 1st to the 5th. You\'ll get a notification on those days every month.',
    newReminder: '+ New reminder',
    reminderNameHint: 'Name (Rent...)',
    amountOptionalHint: 'Amount, ₺ (optional)',
    remindFrom: 'Remind from',
    toWord: 'to',
    dayOfMonthWord: 'day',
    everyDayTpl: 'Every month on day {d}',
    fromToTpl: 'From day {from} to {to}',
    dontForgetTpl: 'Don\'t forget: {x}',
    dontForgetPlain: 'Don\'t forget this payment',
    notificationsChannel: 'Reminders',
    analyticsTitle: 'Analytics',
    spent: 'spent',
    noExpensesMonth: 'No expenses this month',
    incomeLabel: 'Income',
    expenseLabel: 'Expense',
    last6Months: 'Last 6 months',
    reportTitle: 'Report of Spending',
    reportSubtitle: 'View a simple report of your spending',
    accountSettings: 'Account settings',
    securitySection: 'Security',
    otherSection: 'Other',
    accountInformation: 'Account information',
    personalInfo: 'Personal Information',
    notificationPreferences: 'Notification Preferences',
    notificationSettings: 'Notification settings',
    changePassword: 'Change password',
    confidentialityPolicy: 'Confidentiality policy',
    passwordSecurity: 'Password & Security',
    biometricAuth: 'Biometric Authentication',
    faqs: 'FAQs',
    helpCenter: 'Help Center',
    settingsWord: 'Settings',
    comingSoon: 'Coming soon',
    signOutWord: 'Sign out',
    deleteAccount: 'Delete account',
    deleteAccountBody:
        'This permanently deletes your account and all your data. This cannot be undone.',
    historyTitle: 'History of Spending',
    searchHistory: 'Search history',
    filterTitle: 'Filter',
    categoriesLabel: 'Categories',
    applyFilter: 'Apply Filter',
    spentThisMonth: 'Spent this month',
    allCategoryExpenses: 'All Category Expenses',
    viewMoreDetail: 'View more detail',
    activityExpenses: 'Activity Expenses',
    setAsideFor: 'You\'ve set aside {amount} for {name}',
    calculateBudget: 'Calculate Budget',
    shareWord: 'Share',
    archiveWord: 'Archive',
    unarchiveWord: 'Unarchive',
    exportWord: 'Export',
    archivedSection: 'Archived',
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
    profileTitle: 'Profile',
    dailyRateSubtitle: 'Default daily earnings',
    remindersSubtitle: 'Rent and other payments',
    journalSubtitle: 'All transactions',
    languageTitle: 'Language',
    currencyTitle: 'Currency',
    appearanceTitle: 'Appearance',
    themeSystem: 'System',
    themeLight: 'Light',
    themeDark: 'Dark',
    streakTitle: 'Earning streak',
    streakDaysTpl: '{n} days in a row',
    streakKeepGoing: 'Keep it going — log today',
    streakStart: 'Start your earning streak',
    paceOverTpl: '{n} envelope(s) may go over budget this month',
    paceProjectedTpl: 'Projected month-end: {x}',
    paceOnTrack: 'Spending is on track',
    insightsTitle: 'Insights',
    vsLastMonth: 'vs last month',
    newBadge: 'new',
    weeklySummaryTitle: 'Weekly summary',
    weeklySummaryBodyTpl: 'You earned {x} this week',
    recurringTitle: 'Recurring bills',
    recurringMonthlyLabel: 'Monthly total',
    dueInDaysTpl: 'in {n} days',
    dueNowLabel: 'Due now',
    customEmojiHint: 'Pick your own emoji',
    anonymousTitle: 'Anonymous account',
    anonymousBody:
        'Your data is stored in the cloud and tied to this device. Google/Apple sign-in is coming later — then your data follows you to any phone.',
    tabHome: 'Home',
    tabAnalytics: 'Analytics',
    tabGoals: 'Goals',
    tabCalendar: 'Calendar',
    tabProfile: 'Profile',
    onboardSubtitle:
        'Money gets sorted into envelopes: rent, food, dreams. Here\'s a starter set — remove extras or skip and create your own.',
    createEnvelopesTpl: 'Create envelopes ({n})',
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
    onbStory: [
      (
        title: 'Enter your income',
        subtitle:
            'Log your workdays or income in the Calendar. You instantly see how much money you have left.',
      ),
      (
        title: 'Spend by category',
        subtitle:
            'Write each expense into a category. Your “Money left” drops automatically — no confusing math.',
      ),
      (
        title: 'Save & set goals',
        subtitle:
            'Stash money in dollars and set goals (a car, a trip) — watch the bar fill toward each one.',
      ),
    ],
    onbContinue: 'Next',
    onbStart: 'Get started',
    welcomeTitle: 'Welcome to Budgy',
    welcomeSubtitle:
        'Get a daily overview of your spending and savings, personalized just for you inside the app.',
    reviewTitle: 'Your envelopes are ready',
    reviewSubtitle:
        'Here\'s what you\'ll sort your money into. You can always add or edit them later.',
    navCompleteProfile: 'Complete profile',
    yourProfileTitle: 'Your Profile',
    profileSubtitle: 'Introduce yourself to others in your profile',
    phoneLabel: 'Phone number',
    phoneHint: 'Enter your number',
    genderLabel: 'Gender',
    genderMale: 'Male',
    genderFemale: 'Female',
    genderOther: 'Other',
    dobLabel: 'Date of birth',
    dobHint: 'Select your birth',
    addressLabel: 'Address',
    addressHint: 'Enter your address',
    dontHaveAccount: 'Don\'t have an account?',
    navForgetPassword: 'Forget password',
    forgetTitle: 'Forget password',
    forgetSubtitle: 'Enter your email address to change your password',
    checkEmailTitle: 'Check your email',
    checkEmailBody:
        'We contacted {email} to help you set up a new password',
    notNow: 'Not now',
    resend: 'Resend',
    spamNote: 'Check your spam folder if you don\'t see the email',
    passwordUpdated: 'Password updated — sign in',
    navNewPassword: 'New password',
    newPasswordTitle: 'New password',
    repeatPasswordLabel: 'Repeat password',
    repeatPasswordHint: 'Enter your repeat password',
    navVerifyOtp: 'Verify OTP code',
    otpTitle: 'Enter OTP code',
    otpSubtitle: 'We\'ve sent a one time OTP to your email',
    enterOtp: 'Enter OTP',
    resendIn: 'Resend code in {time}',
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
    rememberMe: 'Remember me',
    forgotPassword: 'Forgot password',
    signInButton: 'Sign in',
    signInError:
        'Oops! The email or password you entered is incorrect, please check your email and password!',
    signUpApple: 'Sign up with Apple',
    continueGoogle: 'Continue with Google',
    continueApple: 'Continue with Apple',
    continueFacebook: 'Continue with Facebook',
    orSignUpWith: 'or sign up with',
    loginMyAccount: 'Login with my account',
    termsNote:
        'By signing up you acknowledge and agree to Budgy Terms of Use and Privacy Policy',
    errorPrefix: 'Error',
  );

  static const tr = Strings(
    localeCode: 'tr',
    goodMorning: 'Günaydın',
    goodAfternoon: 'İyi günler',
    goodEvening: 'İyi akşamlar',
    goodNight: 'İyi geceler',
    totalBreakdown: 'zarflarda {in} · dağıtılmamış {un}',
    thisMonth: 'bu ay',
    bannerSubtitle: '{n} günlük kazanç — zarflara dağıt',
    bannerNote: '{n} günlük kazanç',
    distributeHint: 'Zarflara dağıtmak için dokun',
    newEnvelope: 'Yeni zarf',
    editEnvelope: 'Zarfı düzenle',
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
    deleteEnvelopeTitle: '"{name}" silinsin mi?',
    deleteEnvelopeWithBalance:
        'Bu zarfta {balance} var — toplamdan düşecek. İşlem geçmişi günlükte kalır.',
    deleteEnvelopeHistory: 'İşlem geçmişi günlükte kalır.',
    incomeTitle: 'Gelir',
    amountHint: 'Tutar, ₺',
    incomeNoteHint: 'Not (maaş...)',
    distribution: 'Dağıtım',
    allDistributed: '✓ hepsi dağıtıldı',
    remainingTpl: 'kalan: {x}',
    createEnvelopesFirst: 'Önce ana ekranda zarf oluştur',
    expenseTitle: 'Harcama',
    newTransaction: 'Yeni işlem',
    addTxTitle: 'Yeni işlem ekle',
    amountTitle: 'Tutar',
    dateLabel: 'Tarih',
    selectCategory: 'Kategori seç',
    repeatLabel: 'Tekrarla',
    convertTitle: 'Döviz çevir',
    giveLabel: 'Verdiğin',
    getLabel: 'Aldığın',
    convertAction: 'Çevir',
    rateHint: 'güncel kur',
    rateUnavailable: 'Kur alınamadı — elle gir',
    moneyLeft: 'Kalan para',
    waitingToDistribute: 'Dağıtılmayı bekleyen',
    waitingSubtitle: 'Bugünkü kazancın henüz zarflara konmadı. Nasıl böleceğini seç.',
    distributeToEnvelopes: 'Zarflara böl',
    thisWeekEarnings: 'Bu haftaki kazanç',
    envelopesTitle: 'Zarflar',
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
    lockTitle: 'Budgy kilitli',
    unlockButton: 'Kilidi aç',
    biometricUnavailable: 'Bu cihazda Face ID / parmak izi tanımlı değil',
    quickAddTitle: 'Hızlı harcama',
    detailedEntry: 'Detaylı giriş',
    dailyReminderLabel: 'Günlük hatırlatma',
    dailyReminderTitle: 'Bugün harcamalarını girdin mi?',
    dailyReminderBody: 'Kalan paranı güncel tut — birkaç saniye sürer.',
    workEarning: 'Çalışma kazancı',
    addFunds: 'Para ekle',
    addFundsTitle: 'Para ekle',
    savingsTitle: 'Birikim',
    savingsMonthlyTitle: 'Aylık birikim',
    savingsTotalLabel: 'Toplam birikim',
    savingsEmpty: 'Henüz birikim yok',
    budgetDoneTitle: 'Bütçe Hazır',
    budgetDoneSubtitle:
        'Her şey tamam! Bütçen hazır, paranı yönetmeye başlayabilirsin',
    addMore: 'Daha ekle',
    pocketName: 'Kasa (dağıtılmamış)',
    transferTitle: 'Transfer',
    fromLabel: 'Kimden',
    toLabel: 'Kime',
    selectEnvelope: 'Bir zarf seç',
    onbSelectTitle: '5 veya daha fazla zarf seç',
    envelopeLabel: 'Zarf',
    searchHint: 'Ara',
    noteHint: 'Not',
    journalTitle: 'Günlük',
    overallActivity: 'Genel aktivite',
    recentTitle: 'İşlem detayı',
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
    dailyRate: 'Günlük ücret',
    dailyRateHint: 'Tutar girilmeyen günlerde kullanılır',
    dayEarningsHint: 'O günün kazancı, ₺',
    emptyByRateTpl: 'Boş — {x} ücret uygulanır',
    remindersTitle: 'Hatırlatıcılar',
    remindersEmpty:
        'Düzenli bir ödeme için hatırlatıcı ekle — örn. kira ayın 1\'i ile 5\'i arası. Her ay o günlerde bildirim gelir.',
    newReminder: '+ Yeni hatırlatıcı',
    reminderNameHint: 'İsim (Kira...)',
    amountOptionalHint: 'Tutar, ₺ (isteğe bağlı)',
    remindFrom: 'Hatırlat:',
    toWord: '–',
    dayOfMonthWord: 'günleri',
    everyDayTpl: 'Her ayın {d}. günü',
    fromToTpl: 'Ayın {from}. – {to}. günleri',
    dontForgetTpl: 'Unutma: {x}',
    dontForgetPlain: 'Bu ödemeyi unutma',
    notificationsChannel: 'Hatırlatıcılar',
    analyticsTitle: 'Analiz',
    spent: 'harcandı',
    noExpensesMonth: 'Bu ay harcama yok',
    incomeLabel: 'Gelir',
    expenseLabel: 'Harcama',
    last6Months: 'Son 6 ay',
    reportTitle: 'Harcama Raporu',
    reportSubtitle: 'Harcamalarının basit bir raporunu gör',
    accountSettings: 'Hesap ayarları',
    securitySection: 'Güvenlik',
    otherSection: 'Diğer',
    accountInformation: 'Hesap Bilgileri',
    personalInfo: 'Kişisel Bilgiler',
    notificationPreferences: 'Bildirim Tercihleri',
    notificationSettings: 'Bildirim ayarları',
    changePassword: 'Şifre değiştir',
    confidentialityPolicy: 'Gizlilik politikası',
    passwordSecurity: 'Şifre & Güvenlik',
    biometricAuth: 'Biyometrik Giriş',
    faqs: 'SSS',
    helpCenter: 'Yardım Merkezi',
    settingsWord: 'Ayarlar',
    comingSoon: 'Yakında',
    signOutWord: 'Çıkış yap',
    deleteAccount: 'Hesabı sil',
    deleteAccountBody:
        'Bu, hesabını ve tüm verini kalıcı olarak siler. Geri alınamaz.',
    historyTitle: 'Harcama Geçmişi',
    searchHistory: 'Geçmişte ara',
    filterTitle: 'Filtre',
    categoriesLabel: 'Kategoriler',
    applyFilter: 'Filtreyi Uygula',
    spentThisMonth: 'Bu ay harcanan',
    allCategoryExpenses: 'Tüm Kategori Harcamaları',
    viewMoreDetail: 'Detayı gör',
    activityExpenses: 'İşlem Hareketleri',
    setAsideFor: '{name} için {amount} ayırdın',
    calculateBudget: 'Bütçe Belirle',
    shareWord: 'Paylaş',
    archiveWord: 'Arşivle',
    unarchiveWord: 'Arşivden çıkar',
    exportWord: 'Dışa aktar',
    archivedSection: 'Arşivlenenler',
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
    profileTitle: 'Profil',
    dailyRateSubtitle: 'Varsayılan günlük kazanç',
    remindersSubtitle: 'Kira ve diğer ödemeler',
    journalSubtitle: 'Tüm işlemler',
    languageTitle: 'Dil',
    currencyTitle: 'Para birimi',
    appearanceTitle: 'Görünüm',
    themeSystem: 'Sistem',
    themeLight: 'Açık',
    themeDark: 'Koyu',
    streakTitle: 'Kazanç serisi',
    streakDaysTpl: '{n} gün üst üste',
    streakKeepGoing: 'Seriyi sürdür — bugünü işaretle',
    streakStart: 'Kazanç serine başla',
    paceOverTpl: '{n} zarf bu ay bütçesini aşabilir',
    paceProjectedTpl: 'Ay sonu tahmini: {x}',
    paceOnTrack: 'Harcaman hedefinde',
    insightsTitle: 'İçgörüler',
    vsLastMonth: 'geçen aya göre',
    newBadge: 'yeni',
    weeklySummaryTitle: 'Haftalık özet',
    weeklySummaryBodyTpl: 'Bu hafta {x} kazandın',
    recurringTitle: 'Düzenli Giderler',
    recurringMonthlyLabel: 'Aylık toplam',
    dueInDaysTpl: '{n} gün sonra',
    dueNowLabel: 'Ödeme zamanı',
    customEmojiHint: 'Kendi emojini seç',
    anonymousTitle: 'Anonim hesap',
    anonymousBody:
        'Verilerin bulutta saklanıyor ve bu cihaza bağlı. Google/Apple girişi yakında — o zaman verilerin her telefonda seninle olur.',
    tabHome: 'Ana sayfa',
    tabAnalytics: 'Analiz',
    tabGoals: 'Hedefler',
    tabCalendar: 'Takvim',
    tabProfile: 'Profil',
    onboardSubtitle:
        'Para zarflara dağıtılır: kira, yemek, hayaller. İşte başlangıç seti — fazlasını kaldır ya da atla, kendininkini oluştur.',
    createEnvelopesTpl: 'Zarfları oluştur ({n})',
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
    onbStory: [
      (
        title: 'Önce maaşını gir',
        subtitle:
            'Çalıştığın günleri ya da gelirini Takvim\'e gir. Cebinde kalan parayı anında gör.',
      ),
      (
        title: 'Kategoriye yazarak harca',
        subtitle:
            'Her harcamayı bir kategoriye yaz. “Kalan para” otomatik düşsün — karışık hesap yok.',
      ),
      (
        title: 'Biriktir ve hedef koy',
        subtitle:
            'Dolar biriktir, hedef koy (araba, tatil) — çubuğun her hedefe doğru dolmasını izle.',
      ),
    ],
    onbContinue: 'İleri',
    onbStart: 'Başla',
    welcomeTitle: 'Budgy\'ye hoş geldin',
    welcomeSubtitle:
        'Harcama ve birikiminin günlük genel görünümünü, sana özel olarak uygulamada gör.',
    reviewTitle: 'Zarfların hazır',
    reviewSubtitle:
        'Paranı işte bunlara dağıtacaksın. İstediğin zaman ekleyip düzenleyebilirsin.',
    navCompleteProfile: 'Profili tamamla',
    yourProfileTitle: 'Profilin',
    profileSubtitle: 'Profilinde kendini başkalarına tanıt',
    phoneLabel: 'Telefon numarası',
    phoneHint: 'Numaranı gir',
    genderLabel: 'Cinsiyet',
    genderMale: 'Erkek',
    genderFemale: 'Kadın',
    genderOther: 'Diğer',
    dobLabel: 'Doğum tarihi',
    dobHint: 'Doğum tarihini seç',
    addressLabel: 'Adres',
    addressHint: 'Adresini gir',
    dontHaveAccount: 'Hesabın yok mu?',
    navForgetPassword: 'Şifremi unuttum',
    forgetTitle: 'Şifremi unuttum',
    forgetSubtitle: 'Şifreni değiştirmek için e-posta adresini gir',
    checkEmailTitle: 'E-postanı kontrol et',
    checkEmailBody:
        'Yeni şifre oluşturman için {email} adresine ulaştık',
    notNow: 'Şimdi değil',
    resend: 'Tekrar gönder',
    spamNote: 'E-postayı görmüyorsan spam klasörünü kontrol et',
    passwordUpdated: 'Şifren güncellendi — giriş yap',
    navNewPassword: 'Yeni şifre',
    newPasswordTitle: 'Yeni şifre',
    repeatPasswordLabel: 'Şifreyi tekrarla',
    repeatPasswordHint: 'Şifreni tekrar gir',
    navVerifyOtp: 'OTP kodunu doğrula',
    otpTitle: 'OTP kodunu gir',
    otpSubtitle: 'E-postana tek kullanımlık bir kod gönderdik',
    enterOtp: 'OTP gir',
    resendIn: 'Kodu yeniden gönder: {time}',
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
    rememberMe: 'Beni hatırla',
    forgotPassword: 'Şifremi unuttum',
    signInButton: 'Giriş yap',
    signInError:
        'Hata! Girdiğin e-posta veya şifre yanlış, lütfen e-postanı ve şifreni kontrol et!',
    signUpApple: 'Apple ile kaydol',
    continueGoogle: 'Google ile devam et',
    continueApple: 'Apple ile devam et',
    continueFacebook: 'Facebook ile devam et',
    orSignUpWith: 'veya şununla kaydol',
    loginMyAccount: 'Hesabımla giriş yap',
    termsNote:
        'Kaydolarak Budgy Kullanım Koşulları ve Gizlilik Politikası\'nı kabul etmiş olursun',
    errorPrefix: 'Hata',
  );

  static const ru = Strings(
    localeCode: 'ru',
    goodMorning: 'Доброе утро',
    goodAfternoon: 'Добрый день',
    goodEvening: 'Добрый вечер',
    goodNight: 'Доброй ночи',
    totalBreakdown: 'в конвертах {in} · не разложено {un}',
    thisMonth: 'в этом месяце',
    bannerSubtitle: 'Заработок за {n} дн. — разложить по конвертам',
    bannerNote: 'Заработок за {n} дн.',
    distributeHint: 'Нажми, чтобы разложить по конвертам',
    newEnvelope: 'Новый конверт',
    editEnvelope: 'Редактировать конверт',
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
    deleteEnvelopeTitle: 'Удалить «{name}»?',
    deleteEnvelopeWithBalance:
        'На конверте {balance} — баланс пропадёт из общего счёта. История операций останется в журнале.',
    deleteEnvelopeHistory: 'История операций останется в журнале.',
    incomeTitle: 'Доход',
    amountHint: 'Сумма, ₺',
    incomeNoteHint: 'Заметка (зарплата...)',
    distribution: 'Распределение',
    allDistributed: '✓ всё распределено',
    remainingTpl: 'осталось: {x}',
    createEnvelopesFirst: 'Сначала создай конверты на главном экране',
    expenseTitle: 'Расход',
    newTransaction: 'Новая операция',
    addTxTitle: 'Новая операция',
    amountTitle: 'Сумма',
    dateLabel: 'Дата',
    selectCategory: 'Категория',
    repeatLabel: 'Повтор',
    convertTitle: 'Обмен валюты',
    giveLabel: 'Отдаёшь',
    getLabel: 'Получаешь',
    convertAction: 'Обменять',
    rateHint: 'текущий курс',
    rateUnavailable: 'Курс недоступен — введи вручную',
    moneyLeft: 'Остаток',
    waitingToDistribute: 'Ждёт распределения',
    waitingSubtitle: 'Сегодняшний заработок ещё не разложен по конвертам. Выбери, как распределить.',
    distributeToEnvelopes: 'Разложить по конвертам',
    thisWeekEarnings: 'Заработок за неделю',
    envelopesTitle: 'Конверты',
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
    lockTitle: 'Budgy заблокирован',
    unlockButton: 'Разблокировать',
    biometricUnavailable: 'На устройстве не настроены Face ID / отпечаток',
    quickAddTitle: 'Быстрый расход',
    detailedEntry: 'Подробный ввод',
    dailyReminderLabel: 'Ежедневное напоминание',
    dailyReminderTitle: 'Записал сегодняшние траты?',
    dailyReminderBody: 'Держи остаток в курсе — это пара секунд.',
    workEarning: 'Заработок',
    addFunds: 'Пополнить',
    addFundsTitle: 'Пополнение',
    savingsTitle: 'Накопления',
    savingsMonthlyTitle: 'Накопления по месяцам',
    savingsTotalLabel: 'Всего накоплено',
    savingsEmpty: 'Пока нет накоплений',
    budgetDoneTitle: 'Бюджет готов',
    budgetDoneSubtitle:
        'Готово! Твой бюджет настроен, можно управлять деньгами',
    addMore: 'Добавить ещё',
    pocketName: 'Наличные (нераспределённые)',
    transferTitle: 'Перевод',
    fromLabel: 'Откуда',
    toLabel: 'Куда',
    selectEnvelope: 'Выбери конверт',
    onbSelectTitle: 'Выбери 5 или больше конвертов',
    envelopeLabel: 'Конверт',
    searchHint: 'Поиск',
    noteHint: 'Заметка',
    journalTitle: 'Журнал',
    overallActivity: 'Общая активность',
    recentTitle: 'Детали',
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
    dailyRate: 'Ставка за день',
    dailyRateHint: 'Если не указать сумму у дня',
    dayEarningsHint: 'Заработок за день, ₺',
    emptyByRateTpl: 'Пусто — по ставке {x}',
    remindersTitle: 'Напоминания',
    remindersEmpty:
        'Добавь напоминание о регулярном платеже — например, аренда с 1 по 5 число. Каждый месяц в эти дни придёт уведомление.',
    newReminder: '+ Новое напоминание',
    reminderNameHint: 'Название (Аренда...)',
    amountOptionalHint: 'Сумма, ₺ (необязательно)',
    remindFrom: 'Напоминать с',
    toWord: 'по',
    dayOfMonthWord: 'число',
    everyDayTpl: 'Каждое {d} число',
    fromToTpl: 'С {from} по {to} число',
    dontForgetTpl: 'Не забудь: {x}',
    dontForgetPlain: 'Не забудь про этот платёж',
    notificationsChannel: 'Напоминания',
    analyticsTitle: 'Аналитика',
    spent: 'потрачено',
    noExpensesMonth: 'В этом месяце расходов нет',
    incomeLabel: 'Доход',
    expenseLabel: 'Расход',
    last6Months: 'Последние 6 месяцев',
    reportTitle: 'Отчёт о тратах',
    reportSubtitle: 'Простой отчёт о твоих расходах',
    accountSettings: 'Настройки аккаунта',
    securitySection: 'Безопасность',
    otherSection: 'Другое',
    accountInformation: 'Информация об аккаунте',
    personalInfo: 'Личные данные',
    notificationPreferences: 'Уведомления',
    notificationSettings: 'Настройки уведомлений',
    changePassword: 'Сменить пароль',
    confidentialityPolicy: 'Политика конфиденциальности',
    passwordSecurity: 'Пароль и безопасность',
    biometricAuth: 'Биометрия',
    faqs: 'Вопросы',
    helpCenter: 'Поддержка',
    settingsWord: 'Настройки',
    comingSoon: 'Скоро',
    signOutWord: 'Выйти',
    deleteAccount: 'Удалить аккаунт',
    deleteAccountBody:
        'Аккаунт и все данные будут удалены навсегда. Отменить нельзя.',
    historyTitle: 'История трат',
    searchHistory: 'Поиск',
    filterTitle: 'Фильтр',
    categoriesLabel: 'Категории',
    applyFilter: 'Применить',
    spentThisMonth: 'Потрачено в этом месяце',
    allCategoryExpenses: 'Все расходы по категориям',
    viewMoreDetail: 'Подробнее',
    activityExpenses: 'Движения',
    setAsideFor: 'Отложено {amount} на {name}',
    calculateBudget: 'Задать бюджет',
    shareWord: 'Поделиться',
    archiveWord: 'В архив',
    unarchiveWord: 'Из архива',
    exportWord: 'Экспорт',
    archivedSection: 'Архив',
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
    profileTitle: 'Профиль',
    dailyRateSubtitle: 'Заработок по умолчанию',
    remindersSubtitle: 'Аренда и другие платежи',
    journalSubtitle: 'Все операции',
    languageTitle: 'Язык',
    currencyTitle: 'Валюта',
    appearanceTitle: 'Оформление',
    themeSystem: 'Системная',
    themeLight: 'Светлая',
    themeDark: 'Тёмная',
    streakTitle: 'Серия заработка',
    streakDaysTpl: '{n} дней подряд',
    streakKeepGoing: 'Продолжи — отметь сегодня',
    streakStart: 'Начни серию заработка',
    paceOverTpl: 'Конвертов с риском перерасхода: {n}',
    paceProjectedTpl: 'Прогноз на конец месяца: {x}',
    paceOnTrack: 'Расходы в норме',
    insightsTitle: 'Инсайты',
    vsLastMonth: 'к прошлому месяцу',
    newBadge: 'новое',
    weeklySummaryTitle: 'Итоги недели',
    weeklySummaryBodyTpl: 'На этой неделе вы заработали {x}',
    recurringTitle: 'Регулярные платежи',
    recurringMonthlyLabel: 'Всего в месяц',
    dueInDaysTpl: 'через {n} дн.',
    dueNowLabel: 'Пора платить',
    customEmojiHint: 'Свой эмодзи',
    anonymousTitle: 'Анонимный аккаунт',
    anonymousBody:
        'Данные хранятся в облаке и привязаны к этому устройству. Вход через Google/Apple добавим позже — тогда данные переедут за тобой на любой телефон.',
    tabHome: 'Главная',
    tabAnalytics: 'Аналитика',
    tabGoals: 'Цели',
    tabCalendar: 'Календарь',
    tabProfile: 'Профиль',
    onboardSubtitle:
        'Деньги раскладываются по конвертам: на аренду, еду, мечты. Вот с чего можно начать — убери лишнее или пропусти и создай свои.',
    createEnvelopesTpl: 'Создать конверты ({n})',
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
    onbStory: [
      (
        title: 'Сначала внеси доход',
        subtitle:
            'Отметь рабочие дни или доход в Календаре. Сразу видишь, сколько денег осталось.',
      ),
      (
        title: 'Трать по категориям',
        subtitle:
            'Записывай каждый расход в категорию. «Остаток» уменьшается сам — без путаницы.',
      ),
      (
        title: 'Копи и ставь цели',
        subtitle:
            'Откладывай в долларах и ставь цели (машина, поездка) — следи, как полоса растёт.',
      ),
    ],
    onbContinue: 'Далее',
    onbStart: 'Начать',
    welcomeTitle: 'Добро пожаловать в Budgy',
    welcomeSubtitle:
        'Ежедневный обзор трат и накоплений — лично для тебя, прямо в приложении.',
    reviewTitle: 'Конверты готовы',
    reviewSubtitle:
        'Сюда будешь раскладывать деньги. Всегда можно добавить или изменить.',
    navCompleteProfile: 'Заполни профиль',
    yourProfileTitle: 'Твой профиль',
    profileSubtitle: 'Расскажи о себе в своём профиле',
    phoneLabel: 'Телефон',
    phoneHint: 'Введи номер',
    genderLabel: 'Пол',
    genderMale: 'Мужской',
    genderFemale: 'Женский',
    genderOther: 'Другой',
    dobLabel: 'Дата рождения',
    dobHint: 'Выбери дату',
    addressLabel: 'Адрес',
    addressHint: 'Введи адрес',
    dontHaveAccount: 'Нет аккаунта?',
    navForgetPassword: 'Забыли пароль',
    forgetTitle: 'Забыли пароль',
    forgetSubtitle: 'Введи email, чтобы сменить пароль',
    checkEmailTitle: 'Проверь почту',
    checkEmailBody:
        'Мы написали на {email}, чтобы помочь задать новый пароль',
    notNow: 'Не сейчас',
    resend: 'Отправить ещё раз',
    spamNote: 'Если письма нет — проверь папку «Спам»',
    passwordUpdated: 'Пароль обновлён — войди',
    navNewPassword: 'Новый пароль',
    newPasswordTitle: 'Новый пароль',
    repeatPasswordLabel: 'Повтори пароль',
    repeatPasswordHint: 'Введи пароль ещё раз',
    navVerifyOtp: 'Подтверди код',
    otpTitle: 'Введи код из SMS',
    otpSubtitle: 'Мы отправили одноразовый код на твою почту',
    enterOtp: 'Код',
    resendIn: 'Отправить код снова через {time}',
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
    rememberMe: 'Запомнить меня',
    forgotPassword: 'Забыл пароль',
    signInButton: 'Войти',
    signInError:
        'Ошибка! Введённый email или пароль неверны, проверь email и пароль!',
    signUpApple: 'Войти через Apple',
    continueGoogle: 'Войти через Google',
    continueApple: 'Войти через Apple',
    continueFacebook: 'Войти через Facebook',
    orSignUpWith: 'или войди через',
    loginMyAccount: 'Войти со своим аккаунтом',
    termsNote:
        'Регистрируясь, ты принимаешь Условия использования и Политику конфиденциальности Budgy',
    errorPrefix: 'Ошибка',
  );
}

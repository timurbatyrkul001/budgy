import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';

/// Yeni tasarımın (onboarding + ana ekran) metinleri. Büyük [Strings]
/// sınıfını şişirmemek için ayrı tutuldu; dil yine uygulama dilinden gelir.
final rsProvider = Provider<RS>(
  (ref) => RS.of(ref.watch(strProvider).localeCode),
);

class RS {
  const RS({
    required this.onbTitle,
    required this.onbSubtitle,
    required this.onbBadge,
    required this.onbNote,
    required this.onbLegalTpl,
    required this.onbLegalTerms,
    required this.onbLegalPrivacy,
    required this.getStarted,
    required this.introFastTitle,
    required this.introFastSubtitle,
    required this.introRulesTitle,
    required this.introRulesSubtitleTpl,
    required this.introBudgetTitle,
    required this.introBudgetSubtitle,
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
    required this.summarySpent,
    required this.summaryTop,
    required this.summaryDaysTpl,
    required this.shareSummary,
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
    required this.aiLimitReached,
    required this.aiNetworkError,
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
    required this.termsTitle,
    required this.termsUpdated,
    required this.paywallTitleAnalytics,
    required this.paywallTitleAi,
    required this.paywallTitleAutomation,
    required this.paywallSubtitle,
    required this.paywallTrialTpl,
    required this.paywallMonthly,
    required this.paywallYearly,
    required this.paywallPerMonth,
    required this.paywallSaveTpl,
    required this.paywallBilledYearlyTpl,
    required this.paywallStartTrialTpl,
    required this.paywallAutoRenew,
    required this.paywallTerms,
    required this.paywallSoon,
    required this.paywallBrand,
    required this.paywallProPill,
    required this.paywallLifetime,
    required this.paywallOneTime,
    required this.paywallLifetimeNote,
    required this.paywallBuyLifetimeTpl,
    required this.paywallGroupInsights,
    required this.paywallGroupEntry,
    required this.paywallGroupAutomation,
    required this.paywallGroupMoney,
    required this.paywallAnalyticsTitle,
    required this.paywallAnalyticsDesc,
    required this.paywallShareTitle,
    required this.paywallShareDesc,
    required this.paywallAiCatTitle,
    required this.paywallAiCatDesc,
    required this.paywallScanTitle,
    required this.paywallScanDesc,
    required this.paywallVoiceTitle,
    required this.paywallVoiceDesc,
    required this.paywallQuickAddTitle,
    required this.paywallQuickAddDesc,
    required this.paywallBenefitsTitle,
    required this.paywallGroupSpaces,
    required this.paywallSoonBadge,
    required this.paywallSpacesMultiTitle,
    required this.paywallSpacesMultiDesc,
    required this.paywallSpacesSharedTitle,
    required this.paywallSpacesSharedDesc,
    required this.paywallSpacesFamilyTitle,
    required this.paywallSpacesFamilyDesc,
    required this.paywallRecurringTitle,
    required this.paywallRecurringDesc,
    required this.paywallRulesTitle,
    required this.paywallRulesDesc,
    required this.paywallWalletsTitle,
    required this.paywallWalletsDesc,
    required this.paywallGoalsTitle,
    required this.paywallGoalsDesc,
    required this.proLocked,
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
    required this.editingLabel,
    required this.incomeBySource,
    required this.entriesTpl,
    required this.pickIncomeSource,
    required this.qMoodTitle,
    required this.qMoodStressed,
    required this.qMoodUnsure,
    required this.qMoodGood,
    required this.qMoodComfortStressed,
    required this.qMoodComfortUnsure,
    required this.qMoodComfortGood,
    required this.qHardTitle,
    required this.qHardIncome,
    required this.qHardWhere,
    required this.qHardMonthEnd,
    required this.qHardHabit,
    required this.qHardOther,
    required this.qMethodTitle,
    required this.qMethodNone,
    required this.qMethodPaper,
    required this.qMethodSheet,
    required this.qMethodApp,
    required this.rIncomeTitle,
    required this.rIncomeBody,
    required this.rWhereTitle,
    required this.rWhereBody,
    required this.rMonthEndTitle,
    required this.rMonthEndBody,
    required this.rHabitTitle,
    required this.rHabitBody,
    required this.rOtherTitle,
    required this.rOtherBody,
    required this.summaryTitle,
    required this.summaryExpensesTpl,
    required this.summaryIncomesTpl,
    required this.summaryBody,
    required this.summaryEmpty,
    required this.bubblesExpenseTitle,
    required this.bubblesIncomeTitle,
    required this.bubblesContinue,
    required this.bubblesContinueTpl,
    required this.receiptEmpty,
    required this.worldTitle,
    required this.worldSubtitle,
    required this.worldFootnote,
    required this.worldGo,
    required this.worldNight,
    required this.worldDawn,
    required this.worldForest,
    required this.worldOcean,
    required this.welcomeBurstTitle,
    required this.welcomeBurstSub,
    required this.notifTitle,
    required this.notifBody,
    required this.notifAllow,
    required this.notifLater,
    required this.firstDayTitle,
    required this.firstDayBody,
    required this.firstDayTapHint,
    required this.firstDayAmountHint,
    required this.firstDayConfirm,
    required this.firstDayDone,
    required this.firstDaySkip,
  });

  final String onbTitle;
  final String onbSubtitle;

  /// Karşılama: kimin için olduğunu söyleyen rozet.
  final String onbBadge;

  /// Karşılama: gravürün yanındaki el yazısı not (kimin için yaptık).
  final String onbNote;

  /// Karşılama altındaki yasal not; {terms} ve {privacy} tıklanabilir
  /// bağlantı metinleriyle ([onbLegalTerms], [onbLegalPrivacy]) doldurulur —
  /// bağlantı sözcükleri dile göre ek alabildiği için ayrı tutuluyor.
  final String onbLegalTpl;
  final String onbLegalTerms;
  final String onbLegalPrivacy;
  final String getStarted;
  final String introFastTitle;
  final String introFastSubtitle;
  final String introRulesTitle;
  final String introRulesSubtitleTpl;
  final String introBudgetTitle;
  final String introBudgetSubtitle;
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
  final String summarySpent;
  final String summaryTop;
  final String summaryDaysTpl;
  final String shareSummary;
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
  final String aiLimitReached;
  final String aiNetworkError;
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
  final String termsTitle;
  final String termsUpdated;
  final String paywallTitleAnalytics;
  final String paywallTitleAi;
  final String paywallTitleAutomation;
  final String paywallSubtitle;
  final String paywallTrialTpl;
  final String paywallMonthly;
  final String paywallYearly;
  final String paywallPerMonth;
  final String paywallSaveTpl;
  final String paywallBilledYearlyTpl;
  final String paywallStartTrialTpl;
  final String paywallAutoRenew;
  final String paywallTerms;
  final String paywallSoon;
  final String paywallBrand;
  final String paywallProPill;
  final String paywallLifetime;
  final String paywallOneTime;
  final String paywallLifetimeNote;
  final String paywallBuyLifetimeTpl;
  final String paywallGroupInsights;
  final String paywallGroupEntry;
  final String paywallGroupAutomation;
  final String paywallGroupMoney;
  final String paywallAnalyticsTitle;
  final String paywallAnalyticsDesc;
  final String paywallShareTitle;
  final String paywallShareDesc;
  final String paywallAiCatTitle;
  final String paywallAiCatDesc;
  final String paywallScanTitle;
  final String paywallScanDesc;
  final String paywallVoiceTitle;
  final String paywallVoiceDesc;
  final String paywallQuickAddTitle;
  final String paywallQuickAddDesc;
  final String paywallBenefitsTitle;
  final String paywallGroupSpaces;
  final String paywallSoonBadge;
  final String paywallSpacesMultiTitle;
  final String paywallSpacesMultiDesc;
  final String paywallSpacesSharedTitle;
  final String paywallSpacesSharedDesc;
  final String paywallSpacesFamilyTitle;
  final String paywallSpacesFamilyDesc;
  final String paywallRecurringTitle;
  final String paywallRecurringDesc;
  final String paywallRulesTitle;
  final String paywallRulesDesc;
  final String paywallWalletsTitle;
  final String paywallWalletsDesc;
  final String paywallGoalsTitle;
  final String paywallGoalsDesc;
  final String proLocked;
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
  final String editingLabel;
  final String incomeBySource;
  final String entriesTpl;
  final String pickIncomeSource;

  // ── Onboarding anketi, balonlar ve finali ──
  final String qMoodTitle;
  final String qMoodStressed;
  final String qMoodUnsure;
  final String qMoodGood;
  final String qMoodComfortStressed;
  final String qMoodComfortUnsure;
  final String qMoodComfortGood;
  final String qHardTitle;
  final String qHardIncome;
  final String qHardWhere;
  final String qHardMonthEnd;
  final String qHardHabit;
  final String qHardOther;
  final String qMethodTitle;
  final String qMethodNone;
  final String qMethodPaper;
  final String qMethodSheet;
  final String qMethodApp;
  final String rIncomeTitle;
  final String rIncomeBody;
  final String rWhereTitle;
  final String rWhereBody;
  final String rMonthEndTitle;
  final String rMonthEndBody;
  final String rHabitTitle;
  final String rHabitBody;
  final String rOtherTitle;
  final String rOtherBody;
  final String summaryTitle;
  final String summaryExpensesTpl;
  final String summaryIncomesTpl;
  final String summaryBody;
  final String summaryEmpty;
  final String bubblesExpenseTitle;
  final String bubblesIncomeTitle;
  final String bubblesContinue;
  final String bubblesContinueTpl;

  /// Fiş boşken kâğıdın ortasındaki soluk yönerge.
  final String receiptEmpty;
  final String worldTitle;
  final String worldSubtitle;
  final String worldFootnote;
  final String worldGo;
  final String worldNight;
  final String worldDawn;
  final String worldForest;
  final String worldOcean;
  final String welcomeBurstTitle;
  final String welcomeBurstSub;
  final String notifTitle;
  final String notifBody;
  final String notifAllow;
  final String notifLater;
  final String firstDayTitle;
  final String firstDayBody;
  final String firstDayTapHint;
  final String firstDayAmountHint;
  final String firstDayConfirm;
  final String firstDayDone;
  final String firstDaySkip;

  static RS of(String code) => switch (code) {
    'tr' => tr,
    'ru' => ru,
    _ => en,
  };

  static const en = RS(
    onbTitle: 'Mark the days you work',
    onbSubtitle:
        'Your earnings add up on their own and land in your wallet.',
    onbBadge: 'Built for irregular income',
    onbNote: 'For people who earn by the day, not by the month.',
    onbLegalTpl: 'By continuing you agree to the {terms} and {privacy}.',
    onbLegalTerms: 'Terms of Use',
    onbLegalPrivacy: 'Privacy Policy',
    getStarted: 'Get started',
    introFastTitle: 'Log it in seconds',
    introFastSubtitle:
        'Type the amount on the keypad, say it out loud, or scan the receipt.',
    introRulesTitle: 'Categories sort themselves',
    introRulesSubtitleTpl:
        'The merchant name picks the category: {n}+ built-in rules, plus any you add.',
    introBudgetTitle: 'Set a limit, watch the month',
    introBudgetSubtitle:
        'Weekly or monthly, split per category, and see where the money is going before it is gone.',
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
    otherCurrenciesHint:
        'Have dollars or euros too? Add them as separate wallets.',
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
    summarySpent: 'Spent',
    summaryTop: 'Top category',
    summaryDaysTpl: '{n} days worked',
    shareSummary: 'Share month summary',
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
    aiKeyMissing: 'Sign in to use AI features',
    aiLimitReached: 'Your AI quota for this month is used up',
    aiNetworkError: 'AI is unreachable right now, try again later',
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
    recurringEmpty:
        'No recurring transactions yet. Pick "Repeat" when adding one.',
    nextTpl: 'Next: {date}',
    delete: 'Delete',
    account: 'Account',
    dateTitle: 'Date',
    quickEntryTitle: 'New transaction',
    budgetTitle: 'Budget',
    analyticsTitle: 'Analytics',
    noBudget: 'No budget set',
    noBudgetSub:
        'Set a limit for the week or month and Budgy will show how much is still safe to spend.',
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
    noCategoriesYet:
        'No expense categories yet — pick one when logging an expense.',
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
    automation: 'Category automation',
    automationHint:
        'When you save an expense without a category, keywords in the note pick one for you. Your own rules run first.',
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
    deleteAllDataHint:
        'Removes every transaction, category, wallet and setting. Your account stays.',
    deleteAllDataConfirm: 'Delete everything? This cannot be undone.',
    deleteAllDataConfirm2: 'Last check — really delete all data?',
    deleteAllDone: 'All data deleted',
    paymentReminders: 'Payment reminders',
    privacyPolicy: 'Privacy policy',
    termsTitle: 'Terms of use',
    paywallTitleAnalytics: 'Unlock your spending analytics',
    paywallTitleAi: 'Let Budgy read your receipts',
    paywallTitleAutomation: 'Put your entries on autopilot',
    paywallSubtitle:
        'Budgy Pro turns what you enter into answers: where the money goes, and what to do about it.',
    paywallTrialTpl: '{days}-day free trial',
    paywallMonthly: 'Monthly',
    paywallYearly: 'Yearly',
    paywallPerMonth: 'mo',
    paywallSaveTpl: '−{n}%',
    paywallBilledYearlyTpl: '({price} a year)',
    paywallStartTrialTpl: 'Start {days} free days',
    paywallAutoRenew:
        'Renews automatically until you cancel in the App Store or Google Play.',
    paywallTerms: 'Terms of use',
    paywallSoon: 'Subscriptions aren\'t live yet — coming soon.',
    paywallBrand: 'Budgy',
    paywallProPill: 'Pro',
    paywallLifetime: 'Lifetime',
    paywallOneTime: 'One-time',
    paywallLifetimeNote: 'One-time payment. No subscription, no renewals.',
    paywallBuyLifetimeTpl: 'Get lifetime for {price}',
    paywallGroupInsights: 'Insights',
    paywallGroupEntry: 'Effortless entry',
    paywallGroupAutomation: 'Automation',
    paywallGroupMoney: 'Money',
    paywallAnalyticsTitle: 'Spending analytics',
    paywallAnalyticsDesc:
        'Category breakdown each month and month-over-month comparison',
    paywallShareTitle: 'Month summary sharing',
    paywallShareDesc: 'Share your month as a card to your story',
    paywallAiCatTitle: 'AI categorization',
    paywallAiCatDesc: 'Guesses the category from the merchant name',
    paywallScanTitle: 'Receipt scan',
    paywallScanDesc: 'Snap a receipt and the entry fills itself',
    paywallVoiceTitle: 'Voice input',
    paywallVoiceDesc: 'Say the expense instead of typing it',
    paywallQuickAddTitle: 'Quick-add mode',
    paywallQuickAddDesc: 'Keep the sheet open and log a whole week in one go',
    paywallBenefitsTitle: 'Benefits',
    paywallGroupSpaces: 'Spaces & sharing',
    paywallSoonBadge: 'Soon',
    paywallSpacesMultiTitle: 'Multiple spaces',
    paywallSpacesMultiDesc:
        'Separate personal, business and travel — nothing mixes',
    paywallSpacesSharedTitle: 'Shared spaces',
    paywallSpacesSharedDesc:
        'See every shared expense in one place, in real time',
    paywallSpacesFamilyTitle: 'Family sharing',
    paywallSpacesFamilyDesc:
        'One subscription, shared with up to 5 family members',
    paywallRecurringTitle: 'Recurring rules',
    paywallRecurringDesc: 'Rent, subscriptions and salary logged on schedule',
    paywallRulesTitle: 'Category automation',
    paywallRulesDesc: 'Keyword → category rules that apply as you type',
    paywallWalletsTitle: 'Multi-currency wallets',
    paywallWalletsDesc: 'Wallets in any currency, converted at live rates',
    paywallGoalsTitle: 'Goals & savings',
    paywallGoalsDesc: 'Set targets and watch your savings grow',
    proLocked: 'Included in Budgy Pro',
    termsUpdated: 'Last updated 22 September 2026',
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
    ratesOffline:
        'No rates yet — connect to the internet once to download them.',
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
    editingLabel: 'Editing',
    incomeBySource: 'Income by source',
    entriesTpl: 'Entries: {n}',
    pickIncomeSource: 'Source',
    qMoodTitle: 'How does tracking money make you feel?',
    qMoodStressed: 'Stressed',
    qMoodUnsure: 'Unsure',
    qMoodGood: 'Good',
    qMoodComfortStressed:
        'We get it. Budgy is here to take that weight off — one small step at a time.',
    qMoodComfortUnsure:
        "Totally normal. In a few days you'll see clearly where it goes.",
    qMoodComfortGood: "That's great. We'll help you keep that feeling.",
    qHardTitle: "What's the hardest part?",
    qHardIncome: 'Not knowing when I earn what',
    qHardWhere: 'Not seeing where the money goes',
    qHardMonthEnd: 'Running out before month end',
    qHardHabit: 'Not keeping it up regularly',
    qHardOther: 'Something else',
    qMethodTitle: 'How do you track it today?',
    qMethodNone: "I don't track it",
    qMethodPaper: 'Pen and paper',
    qMethodSheet: 'Spreadsheet',
    qMethodApp: 'Another app',
    rIncomeTitle: "It's not you. It's the calendar.",
    rIncomeBody:
        'Irregular income never fit a notebook. Budgy marks the days you work and tells you when the money lands — and how much.',
    rWhereTitle: "Money doesn't vanish. It just goes unrecorded.",
    rWhereBody:
        "Remembering isn't a system. Budgy files every expense under its category, so where it went is one glance away.",
    rMonthEndTitle: "The 20th shouldn't be a surprise.",
    rMonthEndBody:
        "You can't pace yourself without a line. Budgy sets a budget per category and warns you when you're burning through it too fast.",
    rHabitTitle: "You didn't quit. The method was too much work.",
    rHabitBody:
        'A habit that costs five minutes a day never sticks. In Budgy an expense takes three seconds: tap it in, say it, or snap the receipt.',
    rOtherTitle: 'Whatever it is, step one is the same.',
    rOtherBody:
        'You can only manage what you can see. Budgy starts by showing you — the rest shapes itself around you.',
    summaryTitle: 'All set.',
    summaryExpensesTpl: 'Expense categories: {n}',
    summaryIncomesTpl: 'Income sources: {n}',
    summaryBody:
        "They're waiting on your home screen. The picture starts filling in with your first expense.",
    summaryEmpty:
        "No categories yet — that's fine, Budgy will suggest one with your first expense.",
    bubblesExpenseTitle: 'What do you spend on?',
    bubblesIncomeTitle: 'Where does your money come from?',
    bubblesContinue: 'Continue',
    bubblesContinueTpl: 'Continue with {n}',
    receiptEmpty: 'Tap a category to print it here',
    worldTitle: 'Pick a world that fits you',
    worldSubtitle:
        'Night and Forest are dark, Dawn and Ocean are light. Your pick is saved as your look preference.',
    worldFootnote: 'Just a look preference — your budget stays the same.',
    worldGo: "Let's do this",
    worldNight: 'Night',
    worldDawn: 'Dawn',
    worldForest: 'Forest',
    worldOcean: 'Ocean',
    welcomeBurstTitle: 'Welcome to the Budgy world',
    welcomeBurstSub: 'All set. Your book is waiting.',
    notifTitle: "Don't forget to mark the day",
    notifBody:
        'One tap in the evening: "What did you earn today?" Miss a day and the month won\'t add up — let us remind you.',
    notifAllow: 'Allow',
    notifLater: 'Not now',
    firstDayTitle: 'Mark your first day',
    firstDayBody:
        "Tap today and type what you earned. That's how Budgy works — that's all.",
    firstDayTapHint: 'Tap today',
    firstDayAmountHint: 'What did you earn today?',
    firstDayConfirm: 'Save',
    firstDayDone: 'First day is in the book. Keep going.',
    firstDaySkip: 'Skip for now',
  );

  static const tr = RS(
    onbTitle: 'Çalıştığın günü işaretle',
    onbSubtitle: 'Kazancın kendiliğinden toplanır, cüzdanına yazılır.',
    onbBadge: 'Sabit maaşı olmayanlar için',
    onbNote: 'Ay sonunu değil, çalıştığı günü sayanlar için yaptık.',
    onbLegalTpl: 'Devam ederek {terms} ve {privacy} kabul etmiş olursun.',
    onbLegalTerms: 'Kullanım şartları',
    onbLegalPrivacy: 'Gizlilik politikasını',
    getStarted: 'Hadi başlayalım',
    introFastTitle: 'Saniyeler içinde kaydet',
    introFastSubtitle: 'Tutarı tuş takımına yaz, sesle söyle ya da fişi tara.',
    introRulesTitle: 'Kategori kendiliğinden gelir',
    introRulesSubtitleTpl:
        'İşletme adı kategoriyi seçer: {n}+ yerleşik kural, üstüne kendi kuralların.',
    introBudgetTitle: 'Sınır koy, ayı izle',
    introBudgetSubtitle:
        'Haftalık ya da aylık, kategoriye böl; para bitmeden nereye gittiğini gör.',
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
    otherCurrenciesHint:
        'Doların ya da euron da mı var? Ayrı cüzdan olarak ekle.',
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
    summarySpent: 'Harcandı',
    summaryTop: 'En çok',
    summaryDaysTpl: '{n} gün çalışıldı',
    shareSummary: 'Ay özetini paylaş',
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
    aiKeyMissing: 'Yapay zekâ için giriş yapman gerekiyor',
    aiLimitReached: 'Bu ayki yapay zekâ hakkın doldu',
    aiNetworkError: 'Yapay zekâya şu an ulaşılamıyor, sonra tekrar dene',
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
    recurringEmpty:
        'Henüz tekrarlayan işlem yok. İşlem eklerken "Tekrar"ı seç.',
    nextTpl: 'Sıradaki: {date}',
    delete: 'Sil',
    account: 'Hesap',
    dateTitle: 'Tarih',
    quickEntryTitle: 'Yeni işlem',
    budgetTitle: 'Bütçe',
    analyticsTitle: 'Analiz',
    noBudget: 'Bütçe yok',
    noBudgetSub:
        'Hafta ya da ay için bir sınır koy; Budgy daha ne kadar harcayabileceğini göstersin.',
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
    noCategoriesYet:
        'Henüz harcama kategorisi yok — harcama girerken seçebilirsin.',
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
    automation: 'Kategori otomasyonu',
    automationHint:
        'Kategorisiz bir harcama kaydettiğinde nottaki anahtar kelimeler kategoriyi senin yerine seçer. Önce kendi kuralların çalışır.',
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
    deleteAllDataHint:
        'Tüm işlemleri, kategorileri, cüzdanları ve ayarları kaldırır. Hesabın kalır.',
    deleteAllDataConfirm: 'Her şey silinsin mi? Geri alınamaz.',
    deleteAllDataConfirm2: 'Son kontrol — tüm veriler gerçekten silinsin mi?',
    deleteAllDone: 'Tüm veriler silindi',
    paymentReminders: 'Ödeme hatırlatıcıları',
    privacyPolicy: 'Gizlilik politikası',
    termsTitle: 'Kullanım şartları',
    paywallTitleAnalytics: 'Harcama analizini aç',
    paywallTitleAi: 'Fişlerini Budgy okusun',
    paywallTitleAutomation: 'Girişleri otomatiğe bağla',
    paywallSubtitle:
        'Budgy Pro, girdiklerini cevaba çevirir: para nereye gidiyor ve ne yapmalısın.',
    paywallTrialTpl: '{days} gün ücretsiz deneme',
    paywallMonthly: 'Aylık',
    paywallYearly: 'Yıllık',
    paywallPerMonth: 'ay',
    paywallSaveTpl: '−{n}%',
    paywallBilledYearlyTpl: '(yılda {price})',
    paywallStartTrialTpl: '{days} gün ücretsiz başla',
    paywallAutoRenew:
        'App Store ya da Google Play\'den iptal edene kadar otomatik yenilenir.',
    paywallTerms: 'Kullanım şartları',
    paywallSoon: 'Abonelik henüz açık değil — çok yakında.',
    paywallBrand: 'Budgy',
    paywallProPill: 'Pro',
    paywallLifetime: 'Ömür boyu',
    paywallOneTime: 'Tek seferlik',
    paywallLifetimeNote: 'Tek seferlik ödeme. Abonelik yok, yenileme yok.',
    paywallBuyLifetimeTpl: 'Ömür boyu al — {price}',
    paywallGroupInsights: 'İçgörüler',
    paywallGroupEntry: 'Zahmetsiz giriş',
    paywallGroupAutomation: 'Otomasyon',
    paywallGroupMoney: 'Para',
    paywallAnalyticsTitle: 'Harcama analizi',
    paywallAnalyticsDesc: 'Aylık kategori dağılımı ve ay ay karşılaştırma',
    paywallShareTitle: 'Ay özetini paylaş',
    paywallShareDesc: 'Ayını kart olarak hikâyene at',
    paywallAiCatTitle: 'Yapay zekâ ile kategori',
    paywallAiCatDesc: 'Satıcı adından kategoriyi tahmin eder',
    paywallScanTitle: 'Fiş tarama',
    paywallScanDesc: 'Fişi çek, işlem kendiliğinden dolsun',
    paywallVoiceTitle: 'Sesli giriş',
    paywallVoiceDesc: 'Yazmak yerine harcamayı söyle',
    paywallQuickAddTitle: 'Hızlı ekleme kipi',
    paywallQuickAddDesc:
        'Ekran kapanmadan arka arkaya gir, bir haftayı tek seferde yaz',
    paywallBenefitsTitle: 'Neler var',
    paywallGroupSpaces: 'Alanlar ve paylaşım',
    paywallSoonBadge: 'Yakında',
    paywallSpacesMultiTitle: 'Birden fazla alan',
    paywallSpacesMultiDesc:
        'Kişisel, iş ve seyahat ayrı dursun — hiçbiri karışmaz',
    paywallSpacesSharedTitle: 'Paylaşımlı alan',
    paywallSpacesSharedDesc: 'Ortak harcamaların hepsi tek yerde, anlık olarak',
    paywallSpacesFamilyTitle: 'Aile paylaşımı',
    paywallSpacesFamilyDesc: 'Tek abonelik, 5 aile üyesine kadar paylaşılır',
    paywallRecurringTitle: 'Tekrarlayan işlemler',
    paywallRecurringDesc: 'Kira, abonelik ve maaş zamanında işlensin',
    paywallRulesTitle: 'Kategori otomasyonu',
    paywallRulesDesc: 'Anahtar kelime → kategori kuralları, yazarken uygulanır',
    paywallWalletsTitle: 'Döviz cüzdanları',
    paywallWalletsDesc: 'İstediğin para biriminde cüzdan, canlı kurla çevrim',
    paywallGoalsTitle: 'Hedefler ve birikim',
    paywallGoalsDesc: 'Hedef koy, birikimin büyüsün',
    proLocked: 'Budgy Pro\'ya dahil',
    termsUpdated: 'Son güncelleme 22 Eylül 2026',
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
    editingLabel: 'Düzenleniyor',
    incomeBySource: 'Gelir kaynakları',
    entriesTpl: 'Kayıt: {n}',
    pickIncomeSource: 'Kaynak',
    qMoodTitle: 'Parayı takip etmek sana ne hissettiriyor?',
    qMoodStressed: 'Stresli',
    qMoodUnsure: 'Kararsız',
    qMoodGood: 'İyi',
    qMoodComfortStressed:
        'Anlıyoruz. Budgy o yükü hafifletmek için var — küçük adımlarla.',
    qMoodComfortUnsure:
        'Gayet normal. Birkaç günde nereye gittiğini net göreceksin.',
    qMoodComfortGood: 'Harika. Bu hissi korumana yardım edeceğiz.',
    qHardTitle: 'En zor gelen ne?',
    qHardIncome: 'Ne zaman ne kazandığımı bilmemek',
    qHardWhere: 'Harcamaların nereye gittiğini görmemek',
    qHardMonthEnd: 'Ay sonunu getirememek',
    qHardHabit: 'Düzenli takip edememek',
    qHardOther: 'Başka bir şey',
    qMethodTitle: 'Şu an nasıl takip ediyorsun?',
    qMethodNone: 'Hiç takip etmiyorum',
    qMethodPaper: 'Kâğıt kalem',
    qMethodSheet: 'Tablo (Excel, Sheets)',
    qMethodApp: 'Başka bir uygulama',
    rIncomeTitle: 'Sorun sende değil, takvimde.',
    rIncomeBody:
        'Düzensiz gelir deftere sığmaz. Budgy çalıştığın günleri işaretler; ne zaman ne alacağını kendisi hesaplar.',
    rWhereTitle: 'Para uçmuyor. Sadece kayıt yok.',
    rWhereBody:
        'Aklında tutmak bir yöntem değil. Budgy her harcamayı kategorisine koyar; nereye ne gitti, tek bakışta.',
    rMonthEndTitle: "Ayın 20'si sürpriz olmamalı.",
    rMonthEndBody:
        'Sınırı bilmeden tutumlu olunmaz. Budgy her kategoriye bütçe koyar; tempon hızlıysa ay bitmeden söyler.',
    rHabitTitle: 'Bırakmadın. Yöntem çok uğraştırıyordu.',
    rHabitBody:
        "Günde beş dakika isteyen alışkanlık tutmaz. Budgy'de bir harcama üç saniye: tuşla, sesle söyle ya da fişi çek.",
    rOtherTitle: 'Ne olursa olsun, ilk adım aynı.',
    rOtherBody:
        'Gördüğün parayı yönetirsin. Budgy önce göstermeye başlar; gerisi sana göre şekillenir.',
    summaryTitle: 'Hazır.',
    summaryExpensesTpl: '{n} gider kategorisi',
    summaryIncomesTpl: '{n} gelir kaynağı',
    summaryBody:
        'Hepsi ana ekranda seni bekliyor. İlk harcamanı girdiğin an tablo dolmaya başlar.',
    summaryEmpty:
        'Şimdilik kategori seçmedin — sorun değil, ilk harcamada Budgy önerir.',
    bubblesExpenseTitle: 'Nelere para harcıyorsun?',
    bubblesIncomeTitle: 'Paran nereden geliyor?',
    bubblesContinue: 'Devam et',
    bubblesContinueTpl: '{n} tanesiyle devam et',
    receiptEmpty: 'Bir kategoriye dokun, fişe yazılsın',
    worldTitle: 'Sana uyan bir dünya seç',
    worldSubtitle:
        'Gece ve Orman koyu, Şafak ve Okyanus açık ton. Seçimin görünüm tercihi olarak kaydedilir.',
    worldFootnote: 'Sadece görünüm tercihi — bütçen aynı kalır.',
    worldGo: 'Hadi başlayalım',
    worldNight: 'Gece',
    worldDawn: 'Şafak',
    worldForest: 'Orman',
    worldOcean: 'Okyanus',
    welcomeBurstTitle: 'Budgy dünyasına hoş geldin',
    welcomeBurstSub: 'Her şey hazır. Defterin seni bekliyor.',
    notifTitle: 'Günü işaretlemeyi unutma',
    notifBody:
        'Akşam tek bir dokunuş: "Bugün ne kazandın?" Bir kez unutursan ay sonu hesabı tutmaz — hatırlatalım.',
    notifAllow: 'İzin ver',
    notifLater: 'Şimdi değil',
    firstDayTitle: 'İlk gününü işaretle',
    firstDayBody:
        'Bugüne dokun, kazancını yaz. Uygulamaya böyle başlanır — hepsi bu.',
    firstDayTapHint: 'Bugüne dokun',
    firstDayAmountHint: 'Bugün ne kazandın?',
    firstDayConfirm: 'Kaydet',
    firstDayDone: 'İlk günün defterde. Böyle devam.',
    firstDaySkip: 'Şimdilik atla',
  );

  static const ru = RS(
    onbTitle: 'Отмечай рабочие дни',
    onbSubtitle: 'Заработок сложится сам и попадёт в кошелёк.',
    onbBadge: 'Для тех, у кого нет оклада',
    onbNote: 'Для тех, кто зарабатывает по дням, а не по окладу.',
    onbLegalTpl: 'Продолжая, ты принимаешь {terms} и {privacy}.',
    onbLegalTerms: 'Условия использования',
    onbLegalPrivacy: 'Политику конфиденциальности',
    getStarted: 'Начать',
    introFastTitle: 'Записывай за секунды',
    introFastSubtitle:
        'Введи сумму на клавиатуре, скажи вслух или отсканируй чек.',
    introRulesTitle: 'Категории проставляются сами',
    introRulesSubtitleTpl:
        'Категорию подбирает название магазина: {n}+ встроенных правил и твои собственные.',
    introBudgetTitle: 'Поставь лимит и следи за месяцем',
    introBudgetSubtitle:
        'На неделю или месяц, по категориям — и видно, куда уходят деньги, пока они не кончились.',
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
    otherCurrenciesHint:
        'Есть доллары или евро? Добавь их отдельными кошельками.',
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
    summarySpent: 'Потрачено',
    summaryTop: 'Больше всего',
    summaryDaysTpl: 'отработано {n} дн.',
    shareSummary: 'Поделиться итогами месяца',
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
    aiKeyMissing: 'Войди в аккаунт, чтобы пользоваться ИИ',
    aiLimitReached: 'Лимит ИИ на этот месяц исчерпан',
    aiNetworkError: 'ИИ сейчас недоступен, попробуй позже',
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
    recurringEmpty:
        'Повторяющихся операций пока нет. Выбери «Повтор» при добавлении.',
    nextTpl: 'Следующая: {date}',
    delete: 'Удалить',
    account: 'Счёт',
    dateTitle: 'Дата',
    quickEntryTitle: 'Новая операция',
    budgetTitle: 'Бюджет',
    analyticsTitle: 'Аналитика',
    noBudget: 'Бюджет не задан',
    noBudgetSub:
        'Задай лимит на неделю или месяц — Budgy покажет, сколько ещё можно тратить.',
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
    automation: 'Автокатегории',
    automationHint:
        'Когда трата сохраняется без категории, ключевые слова в заметке подберут её. Твои правила проверяются первыми.',
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
    deleteAllDataHint:
        'Удалит все операции, категории, кошельки и настройки. Аккаунт останется.',
    deleteAllDataConfirm: 'Удалить всё? Это нельзя отменить.',
    deleteAllDataConfirm2: 'Последняя проверка — точно удалить все данные?',
    deleteAllDone: 'Все данные удалены',
    paymentReminders: 'Напоминания о платежах',
    privacyPolicy: 'Политика конфиденциальности',
    termsTitle: 'Условия использования',
    paywallTitleAnalytics: 'Открой аналитику расходов',
    paywallTitleAi: 'Пусть Budgy читает чеки',
    paywallTitleAutomation: 'Переведи записи на автопилот',
    paywallSubtitle:
        'Budgy Pro превращает записи в ответы: куда уходят деньги и что с этим делать.',
    paywallTrialTpl: '{days} дней бесплатно',
    paywallMonthly: 'Месяц',
    paywallYearly: 'Год',
    paywallPerMonth: 'мес.',
    paywallSaveTpl: '−{n}%',
    paywallBilledYearlyTpl: '({price} в год)',
    paywallStartTrialTpl: 'Начать {days} бесплатных дней',
    paywallAutoRenew:
        'Продлевается автоматически, пока не отменишь в App Store или Google Play.',
    paywallTerms: 'Условия использования',
    paywallSoon: 'Подписка ещё не запущена — скоро.',
    paywallBrand: 'Budgy',
    paywallProPill: 'Pro',
    paywallLifetime: 'Навсегда',
    paywallOneTime: 'Разово',
    paywallLifetimeNote: 'Разовый платёж. Без подписки и продлений.',
    paywallBuyLifetimeTpl: 'Купить навсегда за {price}',
    paywallGroupInsights: 'Аналитика',
    paywallGroupEntry: 'Лёгкий ввод',
    paywallGroupAutomation: 'Автоматизация',
    paywallGroupMoney: 'Деньги',
    paywallAnalyticsTitle: 'Аналитика расходов',
    paywallAnalyticsDesc: 'Разбивка по категориям за месяц и сравнение месяцев',
    paywallShareTitle: 'Итоги месяца',
    paywallShareDesc: 'Поделись месяцем как карточкой в сторис',
    paywallAiCatTitle: 'Категория от ИИ',
    paywallAiCatDesc: 'Угадывает категорию по названию продавца',
    paywallScanTitle: 'Скан чека',
    paywallScanDesc: 'Сфотографируй чек — запись заполнится сама',
    paywallVoiceTitle: 'Голосовой ввод',
    paywallVoiceDesc: 'Скажи расход вместо того, чтобы печатать',
    paywallQuickAddTitle: 'Быстрый ввод',
    paywallQuickAddDesc: 'Окно не закрывается — внеси всю неделю подряд',
    paywallBenefitsTitle: 'Что входит',
    paywallGroupSpaces: 'Пространства и доступ',
    paywallSoonBadge: 'Скоро',
    paywallSpacesMultiTitle: 'Несколько пространств',
    paywallSpacesMultiDesc: 'Личное, работа и поездки — ничего не смешивается',
    paywallSpacesSharedTitle: 'Общее пространство',
    paywallSpacesSharedDesc:
        'Все общие расходы в одном месте, в реальном времени',
    paywallSpacesFamilyTitle: 'Семейный доступ',
    paywallSpacesFamilyDesc: 'Одна подписка на 5 членов семьи',
    paywallRecurringTitle: 'Повторяющиеся операции',
    paywallRecurringDesc:
        'Аренда, подписки и зарплата записываются по расписанию',
    paywallRulesTitle: 'Автокатегории',
    paywallRulesDesc: 'Правила «ключевое слово → категория» при вводе',
    paywallWalletsTitle: 'Мультивалютные кошельки',
    paywallWalletsDesc: 'Кошельки в любой валюте, пересчёт по живому курсу',
    paywallGoalsTitle: 'Цели и накопления',
    paywallGoalsDesc: 'Ставь цели и смотри, как растут накопления',
    proLocked: 'Входит в Budgy Pro',
    termsUpdated: 'Обновлено 22 сентября 2026',
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
    ratesOffline:
        'Курсов пока нет — подключись к интернету один раз, чтобы загрузить.',
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
    editingLabel: 'Правка',
    incomeBySource: 'Источники дохода',
    entriesTpl: 'Записей: {n}',
    pickIncomeSource: 'Источник',
    qMoodTitle: 'Что ты чувствуешь, когда следишь за деньгами?',
    qMoodStressed: 'Стресс',
    qMoodUnsure: 'Не знаю',
    qMoodGood: 'Хорошо',
    qMoodComfortStressed:
        'Понимаем. Budgy здесь, чтобы снять этот груз — маленькими шагами.',
    qMoodComfortUnsure:
        'Это нормально. Через пару дней ты ясно увидишь, куда всё уходит.',
    qMoodComfortGood: 'Отлично. Поможем сохранить это чувство.',
    qHardTitle: 'Что даётся труднее всего?',
    qHardIncome: 'Не знаю, когда и сколько заработал',
    qHardWhere: 'Не вижу, куда уходят деньги',
    qHardMonthEnd: 'Не дотягиваю до конца месяца',
    qHardHabit: 'Не получается вести регулярно',
    qHardOther: 'Другое',
    qMethodTitle: 'Как ты ведёшь учёт сейчас?',
    qMethodNone: 'Никак',
    qMethodPaper: 'Ручка и бумага',
    qMethodSheet: 'Таблица (Excel, Sheets)',
    qMethodApp: 'Другое приложение',
    rIncomeTitle: 'Дело не в тебе, а в календаре.',
    rIncomeBody:
        'Нерегулярный доход не помещается в тетрадь. Budgy отмечает рабочие дни и сам считает, когда и сколько придёт.',
    rWhereTitle: 'Деньги не исчезают. Их просто никто не записал.',
    rWhereBody:
        'Держать всё в голове — не метод. Budgy раскладывает каждую трату по категориям: куда ушло — видно с одного взгляда.',
    rMonthEndTitle: 'Двадцатое число не должно быть сюрпризом.',
    rMonthEndBody:
        'Нельзя экономить, не зная границы. Budgy ставит бюджет на каждую категорию и предупреждает, если тратишь быстрее, чем нужно.',
    rHabitTitle: 'Дело не в дисциплине. Дело в методе.',
    rHabitBody:
        'Привычка, которая требует пять минут в день, не приживается. В Budgy трата занимает три секунды: набери, надиктуй или сфотографируй чек.',
    rOtherTitle: 'С чего бы ни начать, первый шаг один.',
    rOtherBody:
        'Управлять можно только тем, что видишь. Budgy начинает с того, что показывает, — остальное подстроится под тебя.',
    summaryTitle: 'Готово.',
    summaryExpensesTpl: 'Категорий расходов: {n}',
    summaryIncomesTpl: 'Источников дохода: {n}',
    summaryBody:
        'Они уже ждут на главном экране. Картина начнёт складываться с первой записи.',
    summaryEmpty:
        'Категории пока не выбраны — ничего, Budgy предложит при первой трате.',
    bubblesExpenseTitle: 'На что ты тратишь?',
    bubblesIncomeTitle: 'Откуда приходят деньги?',
    bubblesContinue: 'Продолжить',
    bubblesContinueTpl: 'Выбрано {n} · Продолжить',
    receiptEmpty: 'Нажми на категорию — она появится в чеке',
    worldTitle: 'Выбери мир под себя',
    worldSubtitle:
        'Ночь и Лес — тёмные, Рассвет и Океан — светлые. Выбор сохранится как настройка оформления.',
    worldFootnote: 'Только оформление — бюджет тот же.',
    worldGo: 'Поехали',
    worldNight: 'Ночь',
    worldDawn: 'Рассвет',
    worldForest: 'Лес',
    worldOcean: 'Океан',
    welcomeBurstTitle: 'Добро пожаловать в мир Budgy',
    welcomeBurstSub: 'Всё готово. Блокнот ждёт тебя.',
    notifTitle: 'Не забывай отмечать день',
    notifBody:
        'Одно касание вечером: «Сколько заработал сегодня?» Пропустишь день — месяц не сойдётся. Мы напомним.',
    notifAllow: 'Разрешить',
    notifLater: 'Не сейчас',
    firstDayTitle: 'Отметь первый день',
    firstDayBody:
        'Коснись сегодняшнего дня и впиши заработок. Так и работает Budgy — вот и всё.',
    firstDayTapHint: 'Коснись сегодня',
    firstDayAmountHint: 'Сколько заработал сегодня?',
    firstDayConfirm: 'Сохранить',
    firstDayDone: 'Первый день в блокноте. Так держать.',
    firstDaySkip: 'Пока пропустить',
  );
}

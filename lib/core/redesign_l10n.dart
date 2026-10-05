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
    required this.addSavingsWallet,
    required this.recent,
    required this.recentEmpty,
    required this.seeAll,
    required this.dailyReminder,
    required this.dailyReminderSub,
    required this.calendar,
    required this.goals,
    required this.settings,
    required this.customizeWallet,
    required this.ratesUnavailable,
    required this.scanTitle,
    required this.camera,
    required this.gallery,
    required this.scanning,
    required this.aiKeyMissing,
    required this.aiLimitReached,
    required this.aiNetworkError,
    required this.scanFailed,
    required this.scanNoTotal,
    required this.cameraDenied,
    required this.cameraDeniedAndroid,
    required this.cameraRestricted,
    required this.cameraUnavailable,
    required this.photosDenied,
    required this.photosDeniedAndroid,
    required this.photosRestricted,
    required this.aiLimitResetTpl,
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
    required this.recurringHold,
    required this.recurringHoldAccountMissing,
    required this.recurringHoldFxUnavailable,
    required this.recurringHoldGeneric,
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
    required this.exportCsvLimitTpl,
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
    required this.archived,
    required this.searchNoMatch,
    required this.archive,
    required this.unarchive,
    required this.deleteCategoryTpl,
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
    required this.saveTitle,
    required this.saveBody,
    required this.saveApple,
    required this.saveGoogle,
    required this.saveSkip,
    required this.saveNote,
    required this.saveFailed,
    required this.saveMarkLabel,
    required this.saveErrDifferent,
    required this.saveErrOffline,
    required this.startupFailed,
    required this.retry,
    required this.heroGreetingTpl,
    required this.heroGreetingPlain,
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
    required this.accountsTitle,
    required this.accountCountTpl,
    required this.accountAdd,
    required this.accountEmptyTitle,
    required this.accountEmptyBody,
    required this.accountReorderHint,
    required this.walletsSection,
    required this.savingsSignpostTitle,
    required this.savingsSignpostBody,
    required this.accountBalance,
    required this.accountRename,
    required this.accountArchive,
    required this.accountArchiveNote,
    required this.accountArchivedTpl,
    required this.accountNewTitle,
    required this.accountEditTitle,
    required this.accountCountry,
    required this.accountCountryTR,
    required this.accountCountryAZ,
    required this.accountCountryKZ,
    required this.accountCountryRU,
    required this.accountBank,
    required this.accountOtherBank,
    required this.accountNameHint,
    required this.accountStartingBalance,
    required this.accountCurrencyLocked,
    required this.accountCurrencyAuto,
    required this.accountDelete,
    required this.accountDeleteNote,
    required this.accountDeleteConfirmTitle,
    required this.accountDeleteConfirmBodyTpl,
    required this.accountDeleteIrreversible,
    required this.accountDeleteButton,
    required this.accountDeleteCancel,
    required this.accountHasTxTpl,
    required this.accountDeletedTpl,
    required this.hubMyAccount,
    required this.hubNotifications,
    required this.hubAppearance,
    required this.hubHelp,
    required this.hubAbout,
    required this.hubAccountBody,
    required this.hubAppearanceBody,
    required this.hubAboutBody,
    required this.hubProTitle,
    required this.hubProBody,
    required this.hubProCta,
    required this.hubProRestoreTpl,
    required this.hubProRestore,
    required this.hubVersion,
    required this.hubPersonalDetails,
    required this.hubLoginSecurity,
    required this.hubDataNoteMember,
    required this.hubDataNoteAnon,
    required this.hubExportData,
    required this.hubEditAvatar,
    required this.hubNotSet,
    required this.hubSectionIdentity,
    required this.hubSectionData,
    required this.hubSectionDanger,
    required this.resetTooMany,
    required this.resetResent,
    required this.accountFromTitle,
    required this.accountFxNoteTpl,
    required this.fxFreezeUnavailable,
    required this.accountToTitle,
    required this.fxFreezeUnavailableIncome,
    required this.fxFreezeUnavailableEdit,
    required this.signinBodyMember,
    required this.signinBodyAnon,
    required this.signinMethodsLabel,
    required this.signinConnected,
    required this.signinConnectGoogle,
    required this.signinConnectApple,
    required this.signinEmailPassword,
    required this.signinLastTpl,
    required this.signinEmailLabel,
    required this.signinEmailAccount,
    required this.signinEmailChangePassword,
    required this.appearancePrefsLabel,
    required this.appearanceReadabilityLabel,
    required this.appearanceSetupLabel,
    required this.highContrastTitle,
    required this.highContrastBody,
    required this.rerunOnboardingTitle,
    required this.rerunOnboardingBody,
    required this.rerunOnboardingDialogTitle,
    required this.rerunOnboardingDialogBody,
    required this.rerunOnboardingConfirm,
    required this.editNameTitle,
    required this.editNameBody,
    required this.editNameFirst,
    required this.editNameLast,
    required this.editAvatarTitle,
    required this.editAvatarBody,
    required this.editAvatarPickTitle,
    required this.editAvatarLetter,
    required this.editAvatarResetTitle,
    required this.editAvatarResetBody,
    required this.editAvatarResetConfirm,
    required this.tabHome,
    required this.tabJournal,
    required this.tabCalendar,
    required this.addSheetTitle,
    required this.addExpenseManual,
    required this.addIncomeManual,
    required this.addScanReceipt,
    required this.addByVoice,
    required this.conflictTitle,
    required this.conflictBody,
    required this.conflictSignIn,
    required this.conflictKeep,
    required this.intentBadRequest,
    required this.intentInvalidAmount,
    required this.intentSavedTpl,
    required this.intentSavedNoCategoryTpl,
    required this.intentCategoryMissTpl,
    required this.intentAccountMissTpl,
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

  /// Ana ekran "Birikim" bölümündeki "+" kutucuğu: döviz kumbarası ekler
  /// (hesap değil). İki satıra sığacak kadar kısa.
  final String addSavingsWallet;
  final String recent;
  final String recentEmpty;
  final String seeAll;
  final String dailyReminder;
  final String dailyReminderSub;
  final String calendar;
  final String goals;
  final String settings;
  final String customizeWallet;
  final String ratesUnavailable;
  final String scanTitle;
  final String camera;
  final String gallery;
  final String scanning;
  final String aiKeyMissing;
  final String aiLimitReached;
  final String aiNetworkError;
  final String scanFailed;
  final String scanNoTotal;
  final String cameraDenied;
  final String cameraDeniedAndroid;
  final String cameraRestricted;
  final String cameraUnavailable;
  final String photosDenied;
  final String photosDeniedAndroid;
  final String photosRestricted;
  final String aiLimitResetTpl;
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
  final String recurringHold;
  final String recurringHoldAccountMissing;
  final String recurringHoldFxUnavailable;
  final String recurringHoldGeneric;
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
  final String exportCsvLimitTpl;
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
  final String archived;

  /// Arama hiçbir şey bulamadı — boş liste yerine çıkan metin.
  final String searchNoMatch;
  final String archive;
  final String unarchive;
  final String deleteCategoryTpl;
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

  /// Kapanış: hesabı bağlama daveti.
  final String saveTitle;
  final String saveBody;
  final String saveApple;
  final String saveGoogle;
  final String saveSkip;
  final String saveNote;
  final String saveFailed;

  /// Kapanış fişindeki satır etiketleri.

  /// Kapanış sayfasındaki origami animasyonunun ekran okuyucu açıklaması.
  final String saveMarkLabel;

  /// Bu e-posta başka bir yöntemle kayıtlı.
  final String saveErrDifferent;

  /// Ağ yok.
  final String saveErrOffline;

  /// Açılışta anonim oturum kurulamadı — ağ yok ya da Firebase'e
  /// ulaşılamıyor. Kullanıcı sonsuz açılış ekranında kalmasın.
  final String startupFailed;
  final String retry;

  /// Ana ekrandaki siyah karşılama kartı. `{name}` kullanıcının adı;
  /// adı bilmiyorsak [heroGreetingPlain] kullanılır. [heroSpentTpl] içinde
  /// `{amount}` beyaz, gerisi soluk çizilir — tutar cümlenin içinde öne
  /// çıksın diye.
  final String heroGreetingTpl;
  final String heroGreetingPlain;
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

  // ── Hesaplar (kart yönetimi) ─────────────────────────────────────────
  // `account*` öneki: hesap listesi ekranı + kart ekleme/düzenleme sayfası.
  // [accountCountTpl] `{n}`, [accountArchivedTpl] `{name}` alır.
  final String accountsTitle;
  final String accountCountTpl;
  final String accountAdd;
  final String accountEmptyTitle;
  final String accountEmptyBody;
  final String accountReorderHint;

  /// Hedefler ekranındaki döviz cüzdanı grubunun alt başlığı.
  final String walletsSection;

  /// Hesap yönetimi ekranının altındaki yön levhası: "döviz cüzdanı hesap
  /// değil, Birikim'de" — kullanıcı dövizi buraya eklemeye kalkmasın.
  final String savingsSignpostTitle;
  final String savingsSignpostBody;
  final String accountBalance;
  final String accountRename;
  final String accountArchive;
  final String accountArchiveNote;
  final String accountArchivedTpl;
  final String accountNewTitle;
  final String accountEditTitle;
  final String accountCountry;
  final String accountCountryTR;
  final String accountCountryAZ;
  final String accountCountryKZ;
  final String accountCountryRU;
  final String accountBank;
  final String accountOtherBank;
  final String accountNameHint;
  final String accountStartingBalance;
  final String accountCurrencyLocked;
  final String accountCurrencyAuto;
  // Tamamen silme (yalnız işlemi olmayan kart). [accountDeleteConfirmBodyTpl]
  // ve [accountDeletedTpl] `{name}`, [accountHasTxTpl] `{n}` alır.
  final String accountDelete;
  final String accountDeleteNote;
  final String accountDeleteConfirmTitle;
  final String accountDeleteConfirmBodyTpl;
  final String accountDeleteIrreversible;
  final String accountDeleteButton;
  final String accountDeleteCancel;
  final String accountHasTxTpl;
  final String accountDeletedTpl;

  // ── Ayarlar merkezi (2026-10 yeniden yapı) ────────────────────────────
  // `hub*` öneki: bölüm başlıksız kart düzeni, alt ekran açıklamaları ve
  // Pro tanıtım kartı. [hubProRestoreTpl] `{restore}` alır — tıklanabilir
  // parça [hubProRestore] ile doldurulur, böylece cümle dil kurallarına göre
  // kurulabilir (TR'de bağlantı sonda, EN'de de sonda ama ayrı cümle).
  final String hubMyAccount;
  final String hubNotifications;
  final String hubAppearance;
  final String hubHelp;
  final String hubAbout;
  final String hubAccountBody;
  final String hubAppearanceBody;
  final String hubAboutBody;
  final String hubProTitle;
  final String hubProBody;
  final String hubProCta;
  final String hubProRestoreTpl;
  final String hubProRestore;
  final String hubVersion;

  // ── Hesabım + Kişisel bilgiler (2026-10 ikinci tur) ───────────────────
  // [hubDataNoteMember] / [hubDataNoteAnon]: "Hesabım" ekranındaki bilgi
  // kartı. Üye ve anonim için AYRI metin: veri Firestore'da, hesaba bağlı —
  // anonim kullanıcı hesabını bağlamazsa telefonla birlikte erişimi de
  // kaybeder. Bu ikisini tek cümleye indirgemek kullanıcıya verisinin
  // nerede durduğu konusunda yanlış bilgi verir.
  final String hubPersonalDetails;
  final String hubLoginSecurity;
  final String hubDataNoteMember;
  final String hubDataNoteAnon;
  final String hubExportData;
  final String hubEditAvatar;
  final String hubNotSet;

  // Alt ekran kart etiketleri: hub'da bölüm başlığı yok ama alt ekranlarda
  // kartların üstünde küçük gri etiket var (referans düzen).
  final String hubSectionIdentity;
  final String hubSectionData;
  final String hubSectionDanger;

  /// Şifre sıfırlama: too-many-requests ve tekrar gönderim onayı.
  final String resetTooMany;
  final String resetResent;

  // ── Hızlı girişte hesap seçimi (2026-10) ──────────────────────────────
  // [accountFxNoteTpl] `{from}` (kartın birimi) ve `{to}` (ana birim) alır.
  // [fxFreezeUnavailable] kayıt ANINDA kur bulunamayınca gösterilir — işlem
  // kaydedilmez, form dolu kalır; metin bunu açıkça söylemeli ki kullanıcı
  // "kaydoldu mu?" diye tereddüt etmesin.
  final String accountFromTitle;
  final String accountFxNoteTpl;
  final String fxFreezeUnavailable;

  // Gelir ve düzenleme de hesap seçebiliyor (2026-10). [accountToTitle]
  // gelirde seçici başlığı: para hesaba GİRİYOR, "hangi hesaptan" yanlış
  // olurdu. [fxFreezeUnavailableIncome] / [fxFreezeUnavailableEdit]:
  // kur bulunamayınca aynı ret, ama "harcama kaydedilmedi" demek gelirde
  // ve düzenlemede yanıltır — ne kaydedilmediği doğru söylenmeli.
  final String accountToTitle;
  final String fxFreezeUnavailableIncome;
  final String fxFreezeUnavailableEdit;

  // ── Giriş ve güvenlik (2026-10) ────────────────────────────────────────
  // [signinBodyMember] / [signinBodyAnon]: ekran başı paragrafı. Anonim ve
  // üye için AYRI: anonimde ekranın derdi "hesabın korunmuyor, bağla";
  // üyede "hangi yollarla giriyorsun". Tek metin ikisini de yarım anlatırdı.
  // [signinConnected]: bağlı sağlayıcının yanındaki rozet. "Birincil" DEĞİL —
  // Firebase'de birincil sağlayıcı kavramı yok, providerData düz liste.
  // Olmayan bir statüyü ekrana yazmaktansa olanı ("bağlı") yazıyoruz.
  // [signinLastTpl] `{date}` alır. [signinEmailAccount] e-posta satırının
  // alt yazısı (şifre yoksa); [signinEmailChangePassword] şifre varsa.
  final String signinBodyMember;
  final String signinBodyAnon;
  final String signinMethodsLabel;
  final String signinConnected;
  final String signinConnectGoogle;
  final String signinConnectApple;
  final String signinEmailPassword;
  final String signinLastTpl;
  final String signinEmailLabel;
  final String signinEmailAccount;
  final String signinEmailChangePassword;

  // Ayarlar → Görünüm: kart etiketleri, kontrast anahtarı, kurulum sihirbazı.
  final String appearancePrefsLabel;
  final String appearanceReadabilityLabel;
  final String appearanceSetupLabel;
  final String highContrastTitle;
  final String highContrastBody;
  final String rerunOnboardingTitle;
  final String rerunOnboardingBody;
  final String rerunOnboardingDialogTitle;
  final String rerunOnboardingDialogBody;
  final String rerunOnboardingConfirm;

  // ── Kişisel bilgiler › Ad / Avatar düzenleme (2026-10) ─────────────────
  // [editNameFirst] / [editNameLast]: form iki alan gösterir ama profilde
  // tek `name` var; metinler yalnız ETİKET, şema değişmedi.
  // [editAvatarBody]: avatar bu uygulamada renk + simge (ya da baş harf).
  // Fotoğraf yükleme YOK (Storage bağlı değil) — metinler fotoğraf, galeri,
  // kamera vaat etmez; test bunu sabitliyor.
  // [editAvatarResetBody]: çöp kutusu hesabı değil avatarı sıfırlar; metin
  // neyin değişip neyin değişmediğini açıkça söyler ki kullanıcı "verim
  // gidiyor mu" diye korkmasın.
  final String editNameTitle;
  final String editNameBody;
  final String editNameFirst;
  final String editNameLast;
  final String editAvatarTitle;
  final String editAvatarBody;
  final String editAvatarPickTitle;
  final String editAvatarLetter;
  final String editAvatarResetTitle;
  final String editAvatarResetBody;
  final String editAvatarResetConfirm;

  // ── alt sekme çubuğu + "+" seçim sayfası ──────────────────────────────
  final String tabHome;
  final String tabJournal;
  final String tabCalendar;

  /// "+" düğmesinin açtığı seçim sayfasının başlığı.
  final String addSheetTitle;

  /// Seçim kartlarının etiketleri. Satır sonu bilinçli: referansta her
  /// kart iki satırlı yazar, yazı tipine/dile göre kendiliğinden kırılmasına
  /// bırakılırsa TR'de tek, RU'da üç satır olabiliyordu.
  final String addExpenseManual;
  final String addIncomeManual;
  final String addScanReceipt;
  final String addByVoice;

  /// Giriş sırasında kimlik BAŞKA bir hesaba aitken ve anonim hesapta
  /// kaybedilecek kayıt varken çıkan diyalog (bkz. auth/sign_in_guard.dart).
  /// "Birleştirme" sözü vermez; iki hesap birleştirilmiyor.
  final String conflictTitle;
  final String conflictBody;

  /// Kırmızı metin düğmesi: o hesaba geç, buradaki kayıtlar erişilmez olur.
  final String conflictSignIn;

  /// Güvenli seçenek (dolu düğme): hiçbir şey değişmez.
  final String conflictKeep;

  // ── App Intent (Kısayollar / Siri "harcama ekle") cevapları (2026-10) ──
  // Siri bu metinleri SESLİ okur, Kısayollar sonuç kutusunda gösterir: kısa,
  // tam cümle, kullanıcıya ne olduğunu söyleyen. [intentSavedTpl] `{amount}`
  // (biçimli tutar) ve `{category}`; [intentSavedNoCategoryTpl] yalnız
  // `{amount}`. [intentCategoryMissTpl] `{name}`: istenen kategori yoktu —
  // kayıt yapıldı ama sessizce tahmin etmedik, söylüyoruz.
  // [intentAccountMissTpl] `{name}` (istenen) ve `{account}` (kullanılan).
  // Kur yokken ret metni [fxFreezeUnavailable] ile aynı.
  final String intentBadRequest;
  final String intentInvalidAmount;
  final String intentSavedTpl;
  final String intentSavedNoCategoryTpl;
  final String intentCategoryMissTpl;
  final String intentAccountMissTpl;

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
    addSavingsWallet: 'Currency wallet',
    recent: 'Recent activity',
    recentEmpty: 'Nothing here yet — tap + below to add your first expense.',
    seeAll: 'See all',
    dailyReminder: 'Daily reminder',
    dailyReminderSub: 'A gentle nudge at 21:00 to log the day.',
    calendar: 'Calendar',
    goals: 'Goals',
    settings: 'Settings',
    customizeWallet: 'Customize wallet',
    ratesUnavailable: 'Rates are unavailable right now',
    scanTitle: 'Scan receipt',
    camera: 'Camera',
    gallery: 'Photo library',
    scanning: 'Reading receipt…',
    aiKeyMissing: 'Sign in to use AI features',
    aiLimitReached: 'Your AI quota for this month is used up',
    aiNetworkError: 'AI is unreachable right now, try again later',
    scanFailed: 'Couldn’t read the receipt',
    scanNoTotal:
        'Couldn’t find a total on this photo. Make sure the whole receipt is in the frame and sharp, then try again.',
    cameraDenied:
        'Budgy doesn’t have access to the camera. Allow it in Settings → Budgy → Camera, then try again.',
    cameraDeniedAndroid:
        'Budgy doesn’t have access to the camera. Allow it in Settings → Apps → Budgy → Permissions → Camera, then try again.',
    cameraRestricted:
        'Camera use is blocked on this device (Screen Time or a device profile). Pick a photo from the library instead.',
    cameraUnavailable: 'This device has no camera. Pick a photo from the library instead.',
    photosDenied:
        'Budgy doesn’t have access to your photos. Allow it in Settings → Budgy → Photos, then try again.',
    photosDeniedAndroid:
        'Budgy doesn’t have access to your photos. Allow it in Settings → Apps → Budgy → Permissions → Photos and videos, then try again.',
    photosRestricted:
        'Access to photos is blocked on this device (Screen Time or a device profile). Take a photo with the camera instead.',
    aiLimitResetTpl: 'Your AI quota for this month is used up — it resets on {date}.',
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
    recurringHold: 'On hold',
    recurringHoldAccountMissing:
        'The account for this rule is archived or deleted, so the payment wasn’t recorded. Bring the account back from the archive — or, if it’s gone, delete this rule and set it up again. Missed payments are added at the next launch.',
    recurringHoldFxUnavailable:
        'The exchange rate couldn’t be fetched, so the payment wasn’t recorded. Nothing to do on your side: it will be retried the next time you open Budgy with internet.',
    recurringHoldGeneric:
        'This payment wasn’t recorded. It will be retried the next time you open Budgy.',
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
    exportCsvLimitTpl:
        'The file holds at most the latest {n} transactions — anything older is left out.',
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
    archived: 'Archived',
    searchNoMatch: 'Nothing matches that. Try a shorter word.',
    archive: 'Archive',
    unarchive: 'Unarchive',
    deleteCategoryTpl: 'Delete "{name}"? Past transactions keep their history.',
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
    worldTitle: 'Which world feels like you?',
    worldSubtitle:
        'A small mood check before your first entry: night owl, early bird, deep forest or open sea.',
    worldFootnote:
        'Just a moment for fun — Budgy itself keeps its paper look.',
    worldGo: "Let's do this",
    worldNight: 'Night',
    worldDawn: 'Dawn',
    worldForest: 'Forest',
    worldOcean: 'Ocean',
    welcomeBurstTitle: 'Welcome to the Budgy world',
    welcomeBurstSub: 'All set. Your book is waiting.',
    saveTitle: "Keep your book safe",
    saveBody: "Connect an account so your records survive a lost or new phone. Everything you just set up comes with you.",
    saveApple: "Continue with Apple",
    saveGoogle: "Continue with Google",
    saveSkip: "Not now",
    saveNote: "You can do this later in Settings.",
    saveFailed: "Couldn't connect the account. Your data is safe — try again from Settings.",
    saveMarkLabel: "Your book, safely stored",
    saveErrDifferent: "This email is already registered with another sign-in method. Use that one instead.",
    saveErrOffline: "No connection. Try again once you are back online.",
    startupFailed: "Couldn't start. Check your connection and try again.",
    retry: "Try again",
    heroGreetingTpl: "Hey {name}!",
    heroGreetingPlain: "Hey there!",
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
    accountsTitle: 'My accounts',
    accountCountTpl: '{n} accounts',
    accountAdd: '+ Add card',
    accountEmptyTitle: 'Add your first card',
    accountEmptyBody: 'The card your salary lands on, the card you spend with — each keeps its own currency.',
    accountReorderHint: 'Hold a card to reorder',
    walletsSection: 'Currency wallets',
    savingsSignpostTitle: 'Saving in another currency?',
    savingsSignpostBody:
        'A currency wallet is not an account — it is money set aside. You will find it under Savings.',
    accountBalance: 'Balance',
    accountRename: 'Rename',
    accountArchive: 'Archive',
    accountArchiveNote: 'The card leaves the list; past transactions stay.',
    accountArchivedTpl: '{name} archived',
    accountNewTitle: 'Add card',
    accountEditTitle: 'Edit card',
    accountCountry: 'Country',
    accountCountryTR: 'Türkiye',
    accountCountryAZ: 'Azerbaijan',
    accountCountryKZ: 'Kazakhstan',
    accountCountryRU: 'Russia',
    accountBank: 'Bank',
    accountOtherBank: 'Other bank',
    accountNameHint: 'e.g. Enpara salary',
    accountStartingBalance: 'Starting balance (optional)',
    accountCurrencyLocked: 'Currency can\'t be changed — transactions are recorded in it.',
    accountCurrencyAuto: 'Set from the country — you can change it',
    accountDelete: 'Delete permanently',
    accountDeleteNote: 'Only for a card with no transactions.',
    accountDeleteConfirmTitle: 'Delete this card?',
    accountDeleteConfirmBodyTpl: '{name} will be removed for good.',
    accountDeleteIrreversible: 'This cannot be undone.',
    accountDeleteButton: 'Delete',
    accountDeleteCancel: 'Cancel',
    accountHasTxTpl: 'This card has {n} transactions — archive it instead.',
    accountDeletedTpl: '{name} deleted',
    hubMyAccount: 'My account',
    hubNotifications: 'Notifications',
    hubAppearance: 'Appearance',
    hubHelp: 'Help',
    hubAbout: 'About',
    hubAccountBody:
        'Your sign-in, personal details and security — and the way out, if you ever need it.',
    hubAppearanceBody:
        'How Budgy looks and talks to you: keypad, language, currency and voice input.',
    hubAboutBody: 'The legal bits, your data and which version you\'re on.',
    hubProTitle: 'Get more out of Budgy',
    hubProBody: 'Analytics, automation and AI entry — all in one Pro.',
    hubProCta: 'Go Pro',
    hubProRestoreTpl: 'Already Pro? {restore}',
    hubProRestore: 'Restore purchase',
    hubVersion: 'Version',
    hubPersonalDetails: 'Personal details',
    hubLoginSecurity: 'Sign-in & security',
    hubDataNoteMember:
        'Your data is stored in the cloud and tied to your account. Switch phones or reinstall Budgy — it comes back with you.',
    hubDataNoteAnon:
        'Your data is stored in the cloud under this anonymous account. Until you link an account, losing this phone means losing the data too.',
    hubExportData: 'Export my data',
    hubEditAvatar: 'Edit avatar',
    hubNotSet: 'Not set',
    hubSectionIdentity: 'Identity & sign-in',
    hubSectionData: 'Your data',
    hubSectionDanger: 'Danger zone',
    resetTooMany: 'Too many attempts. Try again in a few minutes.',
    resetResent: 'Email sent again.',
    accountFromTitle: 'Which account?',
    accountFxNoteTpl:
        'This card uses {from}; your main currency is {to}. The amount will be converted at today\'s rate.',
    fxFreezeUnavailable:
        'Couldn\'t get the exchange rate — try again in a moment. The expense was not saved.',
    accountToTitle: 'To which account?',
    fxFreezeUnavailableIncome:
        'Couldn\'t get the exchange rate — try again in a moment. The income was not saved.',
    fxFreezeUnavailableEdit:
        'Couldn\'t get the exchange rate — try again in a moment. The changes were not saved.',
    signinBodyMember:
        'The ways you can sign in to this account, and the email it belongs to. Link another method and both will work.',
    signinBodyAnon:
        'This account isn\'t protected: your data can only be reached from this phone. Link Google or Apple so it follows you to a new one.',
    signinMethodsLabel: 'Sign-in methods',
    signinConnected: 'Linked',
    signinConnectGoogle: 'Link Google',
    signinConnectApple: 'Link Apple',
    signinEmailPassword: 'Email & password',
    signinLastTpl: 'Last sign-in: {date}',
    signinEmailLabel: 'Email',
    signinEmailAccount: 'Account email',
    signinEmailChangePassword: 'Change password',
    appearancePrefsLabel: 'Preferences',
    appearanceReadabilityLabel: 'Readability',
    appearanceSetupLabel: 'Setup',
    highContrastTitle: 'Increase text contrast',
    highContrastBody:
        'Makes secondary grey text darker so it\'s easier to read.',
    rerunOnboardingTitle: 'Show setup wizard',
    rerunOnboardingBody:
        'Walk through the first-time setup again: currency, wallet, categories.',
    rerunOnboardingDialogTitle: 'Show the setup wizard?',
    rerunOnboardingDialogBody:
        'Your data stays exactly as it is — nothing is deleted. You\'ll just see the first-time setup again, and anything you pick there is added on top of what you already have.',
    rerunOnboardingConfirm: 'Show wizard',
    editNameTitle: 'Edit your name',
    editNameBody:
        'How Budgy addresses you. Leave it empty and your wallet name is shown instead.',
    editNameFirst: 'First name',
    editNameLast: 'Last name',
    editAvatarTitle: 'Avatar',
    editAvatarBody: 'Pick a colour and an icon, or keep the initial of your wallet.',
    editAvatarPickTitle: 'Colour & icon',
    editAvatarLetter: 'Initial',
    editAvatarResetTitle: 'Reset the avatar?',
    editAvatarResetBody:
        'The colour goes back to the default green and the icon is replaced by the initial. Your data and account are not affected.',
    editAvatarResetConfirm: 'Reset',
    tabHome: 'Home',
    tabJournal: 'Expenses',
    tabCalendar: 'Calendar',
    addSheetTitle: 'What do you want to do?',
    addExpenseManual: 'Add expense\nmanually',
    addIncomeManual: 'Add income\nmanually',
    addScanReceipt: 'Scan\nreceipt',
    addByVoice: 'Add by\nvoice',
    conflictTitle: 'That account has its own records',
    conflictBody:
        "What you've written in this app so far isn't tied to an account yet. The account you picked already has records of its own, and the two can't be combined.\n\nIf you sign in to it, the records on this phone will no longer be reachable. You can stay as you are for now and connect a different account later in Settings.",
    conflictSignIn: 'Sign in anyway',
    conflictKeep: 'Keep my records',
    intentBadRequest: 'Budgy couldn\'t read the request.',
    intentInvalidAmount: 'The amount must be greater than zero.',
    intentSavedTpl: 'Recorded {amount} in {category}.',
    intentSavedNoCategoryTpl: 'Recorded {amount} without a category.',
    intentCategoryMissTpl: 'Category “{name}” wasn\'t found.',
    intentAccountMissTpl: 'Account “{name}” wasn\'t found — used {account}.',
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
    addSavingsWallet: 'Döviz cüzdanı',
    recent: 'Son hareketler',
    recentEmpty: 'Henüz bir şey yok — ilk harcamanı aşağıdaki + ile ekle.',
    seeAll: 'Tümü',
    dailyReminder: 'Günlük hatırlatma',
    dailyReminderSub:
        'Her akşam 21:00’de günü kaydetmen için hafif bir dürtme.',
    calendar: 'Takvim',
    goals: 'Hedefler',
    settings: 'Ayarlar',
    customizeWallet: 'Cüzdanı özelleştir',
    ratesUnavailable: 'Kurlar şu an alınamıyor',
    scanTitle: 'Fiş tara',
    camera: 'Kamera',
    gallery: 'Galeri',
    scanning: 'Fiş okunuyor…',
    aiKeyMissing: 'Yapay zekâ için giriş yapman gerekiyor',
    aiLimitReached: 'Bu ayki yapay zekâ hakkın doldu',
    aiNetworkError: 'Yapay zekâya şu an ulaşılamıyor, sonra tekrar dene',
    scanFailed: 'Fiş okunamadı',
    scanNoTotal:
        'Bu fotoğrafta toplam tutar bulunamadı. Fişin tamamı karede ve net olsun, sonra tekrar dene.',
    cameraDenied:
        'Budgy’nin kameraya erişim izni yok. Ayarlar → Budgy → Kamera’dan izin ver, sonra tekrar dene.',
    cameraDeniedAndroid:
        'Budgy’nin kameraya erişim izni yok. Ayarlar → Uygulamalar → Budgy → İzinler → Kamera’dan izin ver, sonra tekrar dene.',
    cameraRestricted:
        'Bu cihazda kamera kullanımı engellenmiş (Ekran Süresi ya da cihaz profili). Bunun yerine galeriden fotoğraf seç.',
    cameraUnavailable: 'Bu cihazda kamera yok. Bunun yerine galeriden fotoğraf seç.',
    photosDenied:
        'Budgy’nin fotoğraflarına erişim izni yok. Ayarlar → Budgy → Fotoğraflar’dan izin ver, sonra tekrar dene.',
    photosDeniedAndroid:
        'Budgy’nin fotoğraflarına erişim izni yok. Ayarlar → Uygulamalar → Budgy → İzinler → Fotoğraflar ve videolar’dan izin ver, sonra tekrar dene.',
    photosRestricted:
        'Bu cihazda fotoğraflara erişim engellenmiş (Ekran Süresi ya da cihaz profili). Bunun yerine kamerayla çek.',
    aiLimitResetTpl: 'Bu ayki yapay zekâ hakkın doldu — {date} tarihinde yenilenir.',
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
    recurringHold: 'Beklemede',
    recurringHoldAccountMissing:
        'Bu kuralın hesabı arşivde ya da silinmiş, bu yüzden ödeme yazılmadı. Hesabı arşivden geri getir; silindiyse bu kuralı silip yeniden oluştur. Kaçan ödemeler bir sonraki açılışta eklenir.',
    recurringHoldFxUnavailable:
        'Kur alınamadığı için ödeme yazılmadı. Senin yapman gereken bir şey yok: internet varken Budgy’yi bir sonraki açışında tekrar denenir.',
    recurringHoldGeneric:
        'Bu ödeme yazılmadı. Budgy’yi bir sonraki açışında tekrar denenir.',
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
    exportCsvLimitTpl:
        'Dosyaya en fazla son {n} işlem girer — daha eskileri dışarıda kalır.',
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
    archived: 'Arşiv',
    searchNoMatch: 'Eşleşen bir şey yok. Daha kısa bir kelime dene.',
    archive: 'Arşivle',
    unarchive: 'Arşivden çıkar',
    deleteCategoryTpl: '"{name}" silinsin mi? Geçmiş işlemler kayıtta kalır.',
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
    worldTitle: 'Hangi dünya sana benziyor?',
    worldSubtitle:
        'İlk kaydından önce küçük bir ruh hâli sorusu: gece kuşu, erkenci, derin orman ya da açık deniz.',
    worldFootnote:
        'Sadece keyfine bir an — Budgy\'nin kendisi kâğıt görünümünde kalır.',
    worldGo: 'Hadi başlayalım',
    worldNight: 'Gece',
    worldDawn: 'Şafak',
    worldForest: 'Orman',
    worldOcean: 'Okyanus',
    welcomeBurstTitle: 'Budgy dünyasına hoş geldin',
    welcomeBurstSub: 'Her şey hazır. Defterin seni bekliyor.',
    saveTitle: "Defterini güvene al",
    saveBody: "Bir hesap bağla, telefonun kaybolsa da değişse de kayıtların sende kalsın. Az önce kurduğun her şey seninle gelir.",
    saveApple: "Apple ile devam et",
    saveGoogle: "Google ile devam et",
    saveSkip: "Şimdi değil",
    saveNote: "Bunu sonra Ayarlar'dan da yapabilirsin.",
    saveFailed: "Hesap bağlanamadı. Verin duruyor — Ayarlar'dan tekrar deneyebilirsin.",
    saveMarkLabel: "Defterin güvende saklanıyor",
    saveErrDifferent: "Bu e-posta başka bir giriş yöntemiyle kayıtlı. Onunla girmen gerekiyor.",
    saveErrOffline: "Bağlantı yok. İnternete bağlanınca tekrar dene.",
    startupFailed: "Başlatılamadı. Bağlantını kontrol edip tekrar dene.",
    retry: "Tekrar dene",
    heroGreetingTpl: "Merhaba {name}!",
    heroGreetingPlain: "Merhaba!",
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
    accountsTitle: 'Hesaplarım',
    accountCountTpl: '{n} hesap',
    accountAdd: '+ Kart ekle',
    accountEmptyTitle: 'İlk kartını ekle',
    accountEmptyBody: 'Maaşının geldiği kart, harcadığın kart — her biri kendi para biriminde durur.',
    accountReorderHint: 'Sıralamak için karta basılı tut',
    walletsSection: 'Döviz cüzdanları',
    savingsSignpostTitle: 'Döviz biriktiriyor musun?',
    savingsSignpostBody:
        'Döviz cüzdanı hesap değil, kenara ayrılmış para — Birikim bölümünde.',
    accountBalance: 'Bakiye',
    accountRename: 'Yeniden adlandır',
    accountArchive: 'Arşivle',
    accountArchiveNote: 'Kart listeden kalkar; geçmiş işlemler silinmez.',
    accountArchivedTpl: '{name} arşivlendi',
    accountNewTitle: 'Kart ekle',
    accountEditTitle: 'Kartı düzenle',
    accountCountry: 'Ülke',
    accountCountryTR: 'Türkiye',
    accountCountryAZ: 'Azerbaycan',
    accountCountryKZ: 'Kazakistan',
    accountCountryRU: 'Rusya',
    accountBank: 'Banka',
    accountOtherBank: 'Diğer banka',
    accountNameHint: 'Örn. Enpara maaş',
    accountStartingBalance: 'Başlangıç bakiyesi (isteğe bağlı)',
    accountCurrencyLocked: 'Para birimi değiştirilemez — işlemler bu birimde kayıtlı.',
    accountCurrencyAuto: 'Ülkeden geldi, değiştirebilirsin',
    accountDelete: 'Tamamen sil',
    accountDeleteNote: 'Yalnız hiç işlemi olmayan kart için.',
    accountDeleteConfirmTitle: 'Kart tamamen silinsin mi?',
    accountDeleteConfirmBodyTpl: '{name} kalıcı olarak kaldırılacak.',
    accountDeleteIrreversible: 'Bu geri alınamaz.',
    accountDeleteButton: 'Sil',
    accountDeleteCancel: 'İptal',
    accountHasTxTpl: 'Bu kartta {n} işlem var — silmek yerine kaldır.',
    accountDeletedTpl: '{name} silindi',
    hubMyAccount: 'Hesabım',
    hubNotifications: 'Bildirimler',
    hubAppearance: 'Görünüm',
    hubHelp: 'Yardım',
    hubAbout: 'Hakkında',
    hubAccountBody:
        'Giriş bilgilerin, kişisel verilerin ve güvenlik ayarların — gerekirse çıkış kapısı da burada.',
    hubAppearanceBody:
        'Budgy\'nin sana nasıl göründüğü ve seninle nasıl konuştuğu: tuş takımı, dil, para birimi, sesli giriş.',
    hubAboutBody: 'Yasal metinler, verin ve hangi sürümde olduğun.',
    hubProTitle: 'Budgy\'den daha fazlasını al',
    hubProBody: 'Analiz, otomasyon ve AI ile giriş — hepsi tek Pro\'da.',
    hubProCta: 'Pro\'ya geç',
    hubProRestoreTpl: 'Zaten Pro üyesi misin? {restore}',
    hubProRestore: 'Satın alımı geri yükle',
    hubVersion: 'Sürüm',
    hubPersonalDetails: 'Kişisel bilgiler',
    hubLoginSecurity: 'Giriş ve güvenlik',
    hubDataNoteMember:
        'Verilerin hesabına bağlı olarak bulutta saklanır. Telefon değişse ya da Budgy\'yi yeniden kursan da seninle gelir.',
    hubDataNoteAnon:
        'Verilerin bu anonim hesap altında bulutta duruyor. Hesabını bağlamazsan telefonu kaybettiğinde veriler de gider.',
    hubExportData: 'Verilerimi dışa aktar',
    hubEditAvatar: 'Avatarı düzenle',
    hubNotSet: 'Belirtilmedi',
    hubSectionIdentity: 'Kimlik ve giriş',
    hubSectionData: 'Verilerin',
    hubSectionDanger: 'Tehlikeli işlemler',
    resetTooMany: 'Çok fazla deneme oldu. Birkaç dakika sonra tekrar dene.',
    resetResent: 'E-posta tekrar gönderildi.',
    accountFromTitle: 'Hangi hesaptan?',
    accountFxNoteTpl:
        'Bu kart {from} ile çalışıyor; ana para biriminiz {to}. Tutar günün kuruyla çevrilecek.',
    fxFreezeUnavailable:
        'Kur alınamadı — birazdan tekrar dene. Harcama kaydedilmedi.',
    accountToTitle: 'Hangi hesaba?',
    fxFreezeUnavailableIncome:
        'Kur alınamadı — birazdan tekrar dene. Gelir kaydedilmedi.',
    fxFreezeUnavailableEdit:
        'Kur alınamadı — birazdan tekrar dene. Değişiklik kaydedilmedi.',
    signinBodyMember:
        'Bu hesaba hangi yollarla girebildiğin ve bağlı olduğu e-posta. Başka bir yöntem bağlarsan ikisi de çalışır.',
    signinBodyAnon:
        'Bu hesap korunmuyor: verilerine yalnızca bu telefondan ulaşılabiliyor. Google ya da Apple bağla, yeni telefonda da seninle gelsin.',
    signinMethodsLabel: 'Giriş yöntemleri',
    signinConnected: 'Bağlı',
    signinConnectGoogle: 'Google\'ı bağla',
    signinConnectApple: 'Apple\'ı bağla',
    signinEmailPassword: 'E-posta ve şifre',
    signinLastTpl: 'Son giriş: {date}',
    signinEmailLabel: 'E-posta',
    signinEmailAccount: 'Hesap e-postası',
    signinEmailChangePassword: 'Şifreni değiştir',
    appearancePrefsLabel: 'Tercihler',
    appearanceReadabilityLabel: 'Okunabilirlik',
    appearanceSetupLabel: 'Kurulum',
    highContrastTitle: 'Yazı kontrastını artır',
    highContrastBody:
        'İkincil gri yazıları koyulaştırır; okumakta zorlananlar için.',
    rerunOnboardingTitle: 'Kurulum sihirbazını göster',
    rerunOnboardingBody:
        'İlk kurulumu baştan geç: para birimi, cüzdan, kategoriler.',
    rerunOnboardingDialogTitle: 'Kurulum sihirbazı gösterilsin mi?',
    rerunOnboardingDialogBody:
        'Verilerin olduğu gibi kalır — hiçbir şey silinmez. Sadece ilk kurulum ekranlarını yeniden görürsün; orada seçtiklerin mevcut olanların üstüne eklenir.',
    rerunOnboardingConfirm: 'Sihirbazı göster',
    editNameTitle: 'Adını düzenle',
    editNameBody:
        'Budgy sana bu adla seslenir. Boş bırakırsan yerine cüzdan adı görünür.',
    editNameFirst: 'Ad',
    editNameLast: 'Soyad',
    editAvatarTitle: 'Avatar',
    editAvatarBody: 'Bir renk ve simge seç ya da cüzdanının baş harfiyle kalsın.',
    editAvatarPickTitle: 'Renk ve simge',
    editAvatarLetter: 'Baş harf',
    editAvatarResetTitle: 'Avatar sıfırlansın mı?',
    editAvatarResetBody:
        'Renk varsayılan yeşile döner, simgenin yerini baş harf alır. Verilerine ve hesabına dokunulmaz.',
    editAvatarResetConfirm: 'Sıfırla',
    tabHome: 'Ana sayfa',
    tabJournal: 'Harcamalar',
    tabCalendar: 'Takvim',
    addSheetTitle: 'Ne yapmak istiyorsun?',
    addExpenseManual: 'Elle gider\nekle',
    addIncomeManual: 'Elle gelir\nekle',
    addScanReceipt: 'Fiş\ntara',
    addByVoice: 'Sesle\nekle',
    conflictTitle: 'Bu hesabın kendi kayıtları var',
    conflictBody:
        'Bu uygulamada şimdiye kadar yazdıkların henüz bir hesaba bağlı değil. Seçtiğin hesabın ise kendi kayıtları var ve ikisi birleştirilemiyor.\n\nO hesaba girersen bu telefondaki kayıtlara bir daha ulaşamazsın. Şimdilik böyle kalabilir, sonra Ayarlar\'dan başka bir hesapla bağlanabilirsin.',
    conflictSignIn: 'Yine de gir',
    conflictKeep: 'Kayıtlarımı koru',
    intentBadRequest: 'Budgy isteği okuyamadı.',
    intentInvalidAmount: 'Tutar sıfırdan büyük olmalı.',
    intentSavedTpl: '{amount} {category} kategorisine kaydedildi.',
    intentSavedNoCategoryTpl: '{amount} kategorisiz kaydedildi.',
    intentCategoryMissTpl: '“{name}” kategorisi bulunamadı.',
    intentAccountMissTpl: '“{name}” hesabı bulunamadı — {account} kullanıldı.',
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
    addSavingsWallet: 'Валютный кошелёк',
    recent: 'Последние операции',
    recentEmpty: 'Пока пусто — добавь первую трату кнопкой + внизу.',
    seeAll: 'Все',
    dailyReminder: 'Ежедневное напоминание',
    dailyReminderSub: 'Лёгкое напоминание в 21:00 записать день.',
    calendar: 'Календарь',
    goals: 'Цели',
    settings: 'Настройки',
    customizeWallet: 'Настроить кошелёк',
    ratesUnavailable: 'Курсы сейчас недоступны',
    scanTitle: 'Сканировать чек',
    camera: 'Камера',
    gallery: 'Галерея',
    scanning: 'Читаю чек…',
    aiKeyMissing: 'Войди в аккаунт, чтобы пользоваться ИИ',
    aiLimitReached: 'Лимит ИИ на этот месяц исчерпан',
    aiNetworkError: 'ИИ сейчас недоступен, попробуй позже',
    scanFailed: 'Не удалось прочитать чек',
    scanNoTotal:
        'На этом фото не нашлась итоговая сумма. Проверь, что чек целиком в кадре и не размыт, и попробуй снова.',
    cameraDenied:
        'У Budgy нет доступа к камере. Разреши его в Настройки → Budgy → Камера и попробуй снова.',
    cameraDeniedAndroid:
        'У Budgy нет доступа к камере. Разреши его в Настройки → Приложения → Budgy → Разрешения → Камера и попробуй снова.',
    cameraRestricted:
        'Камера на этом устройстве заблокирована (Экранное время или профиль устройства). Выбери фото из галереи.',
    cameraUnavailable: 'На этом устройстве нет камеры. Выбери фото из галереи.',
    photosDenied:
        'У Budgy нет доступа к фото. Разреши его в Настройки → Budgy → Фото и попробуй снова.',
    photosDeniedAndroid:
        'У Budgy нет доступа к фото. Разреши его в Настройки → Приложения → Budgy → Разрешения → Фото и видео и попробуй снова.',
    photosRestricted:
        'Доступ к фото на этом устройстве заблокирован (Экранное время или профиль устройства). Сними чек камерой.',
    aiLimitResetTpl: 'Лимит ИИ на этот месяц исчерпан — обновится {date}.',
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
    recurringHold: 'На паузе',
    recurringHoldAccountMissing:
        'Счёт этого правила в архиве или удалён, поэтому платёж не записан. Верни счёт из архива, а если его уже нет — удали это правило и создай заново. Пропущенные платежи добавятся при следующем запуске.',
    recurringHoldFxUnavailable:
        'Не удалось получить курс валют, поэтому платёж не записан. Делать ничего не нужно: попробуем снова, когда ты откроешь Budgy с интернетом.',
    recurringHoldGeneric:
        'Этот платёж не записан. Попробуем снова при следующем запуске Budgy.',
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
    exportCsvLimitTpl:
        'В файл попадают не больше {n} последних операций — всё, что старше, в него не войдёт.',
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
    archived: 'Архив',
    searchNoMatch: 'Ничего не нашлось. Попробуй слово покороче.',
    archive: 'В архив',
    unarchive: 'Из архива',
    deleteCategoryTpl: 'Удалить «{name}»? История операций сохранится.',
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
    worldTitle: 'Какой мир похож на тебя?',
    worldSubtitle:
        'Маленький вопрос о настроении перед первой записью: ночь, рассвет, глухой лес или открытое море.',
    worldFootnote:
        'Просто минутка для настроения — сам Budgy остаётся в бумажном оформлении.',
    worldGo: 'Поехали',
    worldNight: 'Ночь',
    worldDawn: 'Рассвет',
    worldForest: 'Лес',
    worldOcean: 'Океан',
    welcomeBurstTitle: 'Добро пожаловать в мир Budgy',
    welcomeBurstSub: 'Всё готово. Блокнот ждёт тебя.',
    saveTitle: "Сохрани свой блокнот",
    saveBody: "Привяжи аккаунт — записи останутся с тобой, даже если телефон потеряется или сменится. Всё, что ты настроил, переедет вместе с тобой.",
    saveApple: "Продолжить с Apple",
    saveGoogle: "Продолжить с Google",
    saveSkip: "Не сейчас",
    saveNote: "Это можно сделать позже в настройках.",
    saveFailed: "Не удалось привязать аккаунт. Данные на месте — попробуй ещё раз в настройках.",
    saveMarkLabel: "Твой блокнот надёжно сохранён",
    saveErrDifferent: "Эта почта уже зарегистрирована другим способом входа. Войди через него.",
    saveErrOffline: "Нет соединения. Попробуй ещё раз, когда появится интернет.",
    startupFailed: "Не удалось запустить. Проверь соединение и попробуй снова.",
    retry: "Повторить",
    heroGreetingTpl: "Привет, {name}!",
    heroGreetingPlain: "Привет!",
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
    accountsTitle: 'Мои счета',
    accountCountTpl: 'Счетов: {n}',
    accountAdd: '+ Добавить карту',
    accountEmptyTitle: 'Добавь первую карту',
    accountEmptyBody: 'Карта, куда приходит зарплата, карта, с которой тратишь — каждая в своей валюте.',
    accountReorderHint: 'Удерживай карту, чтобы изменить порядок',
    walletsSection: 'Валютные кошельки',
    savingsSignpostTitle: 'Копите в валюте?',
    savingsSignpostBody:
        'Валютный кошелёк — не счёт, а отложенные деньги. Он в разделе «Накопления».',
    accountBalance: 'Баланс',
    accountRename: 'Переименовать',
    accountArchive: 'В архив',
    accountArchiveNote: 'Карта исчезнет из списка; прошлые операции останутся.',
    accountArchivedTpl: '{name} — в архиве',
    accountNewTitle: 'Новая карта',
    accountEditTitle: 'Изменить карту',
    accountCountry: 'Страна',
    accountCountryTR: 'Турция',
    accountCountryAZ: 'Азербайджан',
    accountCountryKZ: 'Казахстан',
    accountCountryRU: 'Россия',
    accountBank: 'Банк',
    accountOtherBank: 'Другой банк',
    accountNameHint: 'Напр. Enpara зарплата',
    accountStartingBalance: 'Начальный баланс (необязательно)',
    accountCurrencyLocked: 'Валюту нельзя изменить — операции записаны в ней.',
    accountCurrencyAuto: 'Подставлена по стране — можно изменить',
    accountDelete: 'Удалить навсегда',
    accountDeleteNote: 'Только для карты без операций.',
    accountDeleteConfirmTitle: 'Удалить карту навсегда?',
    accountDeleteConfirmBodyTpl: '{name} будет удалена без возможности восстановления.',
    accountDeleteIrreversible: 'Это нельзя отменить.',
    accountDeleteButton: 'Удалить',
    accountDeleteCancel: 'Отмена',
    accountHasTxTpl: 'На этой карте {n} операций — лучше убрать её в архив.',
    accountDeletedTpl: '{name} удалена',
    hubMyAccount: 'Мой аккаунт',
    hubNotifications: 'Уведомления',
    hubAppearance: 'Внешний вид',
    hubHelp: 'Помощь',
    hubAbout: 'О приложении',
    hubAccountBody:
        'Вход, личные данные и безопасность — а если понадобится, и выход.',
    hubAppearanceBody:
        'Как Budgy выглядит и говорит с тобой: клавиатура, язык, валюта и голосовой ввод.',
    hubAboutBody: 'Юридические документы, твои данные и версия приложения.',
    hubProTitle: 'Возьми от Budgy больше',
    hubProBody: 'Аналитика, автоматизация и ввод с AI — всё в одном Pro.',
    hubProCta: 'Перейти на Pro',
    hubProRestoreTpl: 'Уже Pro? {restore}',
    hubProRestore: 'Восстановить покупку',
    hubVersion: 'Версия',
    hubPersonalDetails: 'Личные данные',
    hubLoginSecurity: 'Вход и безопасность',
    hubDataNoteMember:
        'Твои данные хранятся в облаке и привязаны к аккаунту. Смени телефон или переустанови Budgy — они вернутся вместе с тобой.',
    hubDataNoteAnon:
        'Твои данные хранятся в облаке под этим анонимным аккаунтом. Пока ты не привяжешь аккаунт, потеря телефона означает и потерю данных.',
    hubExportData: 'Экспорт моих данных',
    hubEditAvatar: 'Изменить аватар',
    hubNotSet: 'Не указано',
    hubSectionIdentity: 'Профиль и вход',
    hubSectionData: 'Твои данные',
    hubSectionDanger: 'Опасная зона',
    resetTooMany: 'Слишком много попыток. Попробуй через пару минут.',
    resetResent: 'Письмо отправлено ещё раз.',
    accountFromTitle: 'С какого счёта?',
    accountFxNoteTpl:
        'Эта карта в {from}, основная валюта — {to}. Сумма будет пересчитана по курсу на сегодня.',
    fxFreezeUnavailable:
        'Курс не получен — попробуй чуть позже. Трата не сохранена.',
    accountToTitle: 'На какой счёт?',
    fxFreezeUnavailableIncome:
        'Курс не получен — попробуй чуть позже. Доход не сохранён.',
    fxFreezeUnavailableEdit:
        'Курс не получен — попробуй чуть позже. Изменения не сохранены.',
    signinBodyMember:
        'Способы входа в этот аккаунт и почта, к которой он привязан. Привяжи ещё один способ — будут работать оба.',
    signinBodyAnon:
        'Этот аккаунт не защищён: данные доступны только с этого телефона. Привяжи Google или Apple, чтобы они перешли с тобой на новый.',
    signinMethodsLabel: 'Способы входа',
    signinConnected: 'Привязан',
    signinConnectGoogle: 'Привязать Google',
    signinConnectApple: 'Привязать Apple',
    signinEmailPassword: 'Почта и пароль',
    signinLastTpl: 'Последний вход: {date}',
    signinEmailLabel: 'Почта',
    signinEmailAccount: 'Почта аккаунта',
    signinEmailChangePassword: 'Сменить пароль',
    appearancePrefsLabel: 'Предпочтения',
    appearanceReadabilityLabel: 'Читаемость',
    appearanceSetupLabel: 'Настройка',
    highContrastTitle: 'Повысить контраст текста',
    highContrastBody:
        'Делает серый вспомогательный текст темнее — так его легче читать.',
    rerunOnboardingTitle: 'Показать мастер настройки',
    rerunOnboardingBody:
        'Пройти первоначальную настройку заново: валюта, кошелёк, категории.',
    rerunOnboardingDialogTitle: 'Показать мастер настройки?',
    rerunOnboardingDialogBody:
        'Твои данные останутся как есть — ничего не удалится. Ты просто снова увидишь экраны первоначальной настройки; всё выбранное там добавится к тому, что уже есть.',
    rerunOnboardingConfirm: 'Показать мастер',
    editNameTitle: 'Изменить имя',
    editNameBody:
        'Так Budgy будет к тебе обращаться. Оставь пустым — покажем название кошелька.',
    editNameFirst: 'Имя',
    editNameLast: 'Фамилия',
    editAvatarTitle: 'Аватар',
    editAvatarBody: 'Выбери цвет и значок — или оставь первую букву кошелька.',
    editAvatarPickTitle: 'Цвет и значок',
    editAvatarLetter: 'Буква',
    editAvatarResetTitle: 'Сбросить аватар?',
    editAvatarResetBody:
        'Цвет вернётся к зелёному по умолчанию, вместо значка будет первая буква. Данные и аккаунт не затрагиваются.',
    editAvatarResetConfirm: 'Сбросить',
    tabHome: 'Главная',
    tabJournal: 'Расходы',
    tabCalendar: 'Календарь',
    addSheetTitle: 'Что хочешь сделать?',
    addExpenseManual: 'Расход\nвручную',
    addIncomeManual: 'Доход\nвручную',
    addScanReceipt: 'Сканировать\nчек',
    addByVoice: 'Добавить\nголосом',
    conflictTitle: 'У этого аккаунта свои записи',
    conflictBody:
        'Всё, что ты записал в приложении до сих пор, ещё не привязано к аккаунту. У выбранного аккаунта уже есть свои записи, и объединить их нельзя.\n\nЕсли войти в него, записи на этом телефоне станут недоступны. Можно оставить всё как есть и позже привязать другой аккаунт в настройках.',
    conflictSignIn: 'Всё равно войти',
    conflictKeep: 'Оставить мои записи',
    intentBadRequest: 'Budgy не смог прочитать запрос.',
    intentInvalidAmount: 'Сумма должна быть больше нуля.',
    intentSavedTpl: 'Записал {amount} в «{category}».',
    intentSavedNoCategoryTpl: 'Записал {amount} без категории.',
    intentCategoryMissTpl: 'Категория «{name}» не найдена.',
    intentAccountMissTpl: 'Счёт «{name}» не найден — записал на {account}.',
  );
}

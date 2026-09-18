import 'package:flutter/foundation.dart';

/// Debug önizleme anahtarları — ekran görüntüsü / tasarım kontrolü için,
/// veriye dokunmadan. Hepsi `--dart-define` ile ve yalnız debug'da.
///
/// * PREVIEW_ONBOARDING=true [PREVIEW_STEP=0..2] — onboarding.
/// * PREVIEW_HOME=true — ana ekran, örnek veriyle (bkz. preview_home.dart).
/// * PREVIEW_QUICK_ENTRY=true — ana ekran açılınca "+" ekranı otomatik
///   açılır; PREVIEW_QUICK_ENTRY_AMOUNT="2000" tutarı yazar,
///   PREVIEW_QUICK_ENTRY_SHEET=category|recurrence|date ilgili sayfayı açar.
/// * PREVIEW_HOME_TOAST=true — ana ekranda "Kaydedildi · Geri al" çipi.
const kPreviewQuickEntry =
    kDebugMode && bool.fromEnvironment('PREVIEW_QUICK_ENTRY');
const kPreviewQuickEntryAmount =
    String.fromEnvironment('PREVIEW_QUICK_ENTRY_AMOUNT');
const kPreviewQuickEntrySheet =
    String.fromEnvironment('PREVIEW_QUICK_ENTRY_SHEET');
const kPreviewHomeToast =
    kDebugMode && bool.fromEnvironment('PREVIEW_HOME_TOAST');

/// PREVIEW_BUDGET=empty|amount|amountMonthly|categories — Bütçe ekranları
/// (PREVIEW_HOME ile; 'empty' örnek profildeki bütçeyi de kaldırır).
/// PREVIEW_ANALYTICS=true [PREVIEW_ANALYTICS_OFFSET=-1] — Analiz ekranı.
const kPreviewBudget = String.fromEnvironment('PREVIEW_BUDGET');
const kPreviewAnalytics =
    kDebugMode && bool.fromEnvironment('PREVIEW_ANALYTICS');
const kPreviewAnalyticsOffset =
    int.fromEnvironment('PREVIEW_ANALYTICS_OFFSET');

/// PREVIEW_SETTINGS=hub|categories|automation|automationCat|tags|data
/// |newCategory|newCategoryFilled|sectionPicker.
const kPreviewSettings = String.fromEnvironment('PREVIEW_SETTINGS');

/// PREVIEW_CONVERTER=two|four|picker|pickerScrolled; PREVIEW_STARRED=true
/// örnek profile yıldızlı EUR ekler.
const kPreviewConverter = String.fromEnvironment('PREVIEW_CONVERTER');
const kPreviewStarred = kDebugMode && bool.fromEnvironment('PREVIEW_STARRED');

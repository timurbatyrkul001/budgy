package co.ggtech.kopilka_app

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * local_auth (parmak izi / yüz tanıma) AndroidX BiometricPrompt kullanır ve
 * bu da bir FragmentActivity ister. Düz FlutterActivity ile biyometrik kilit
 * Android'de çalışmaz — bu yüzden FlutterFragmentActivity'den türüyoruz.
 */
class MainActivity : FlutterFragmentActivity()

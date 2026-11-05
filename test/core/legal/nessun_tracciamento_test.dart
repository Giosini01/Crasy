import 'dart:io';

import 'package:crasy/core/legal/legal_documents.dart';
import 'package:flutter_test/flutter_test.dart';

/// **CRASY dichiara ad Apple che non traccia nessuno. Qui si controlla che resti vero.**
///
/// La linea guida 5.1.2(i) chiede App Tracking Transparency a chi traccia, e nel
/// novembre 2026 ha bocciato una build per una frase che prometteva "pubblicita' vicina
/// ai gusti" senza che ci fosse niente di simile. La dichiarazione vale finche' nessuno
/// aggiunge un pacchetto: **se questa prova fallisce, prima di toglierla si legge
/// `conformita_apple.md`**, perche' vuol dire che serve ATT e vanno riscritte le risposte
/// su App Store Connect.
void main() {
  String leggi(String percorso) => File(percorso).readAsStringSync();

  test('nessun pacchetto di statistica, pubblicita\' o attribuzione', () {
    final pacchetti = RegExp(
      r'^  ([a-z0-9_]+):$',
      multiLine: true,
    ).allMatches(leggi('pubspec.lock')).map((m) => m.group(1)!).toList();

    expect(
      pacchetti,
      contains('firebase_core'),
      reason: 'il file si legge giusto',
    );

    final vietati = RegExp(
      'analytics|crashlytics|performance|google_mobile_ads|admob|facebook|'
      'meta_|appsflyer|adjust|branch|kochava|singular|mixpanel|amplitude|segment|'
      'sentry|tiktok|app_tracking|tracking_transparency|advertising|gma_',
    );

    expect(pacchetti.where(vietati.hasMatch).toList(), isEmpty);
  });

  test('Firebase non raccoglie statistiche', () {
    final configurazione = leggi('ios/Runner/GoogleService-Info.plist');

    for (final chiave in ['IS_ANALYTICS_ENABLED', 'IS_ADS_ENABLED']) {
      expect(
        RegExp('<key>$chiave</key>\\s*<false').hasMatch(configurazione),
        isTrue,
        reason: chiave,
      );
    }

    expect(
      leggi('lib/firebase_options.dart'),
      isNot(contains('measurementId')),
    );
  });

  test('il manifesto della privacy dice che non si traccia', () {
    final manifesto = leggi('ios/Runner/PrivacyInfo.xcprivacy');

    expect(
      RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(manifesto),
      isTrue,
    );
    expect(
      RegExp(
        r'<key>NSPrivacyTrackingDomains</key>\s*<array/>',
      ).hasMatch(manifesto),
      isTrue,
    );
    expect(
      RegExp(
        r'<key>NSPrivacyCollectedDataTypeTracking</key>\s*<true/>',
      ).hasMatch(manifesto),
      isFalse,
      reason: 'nessun dato e\' usato per tracciare',
    );
    expect(manifesto, isNot(contains('PurposeThirdPartyAdvertising')));
  });

  test('il manifesto nomina quello che si raccoglie davvero', () {
    final manifesto = leggi('ios/Runner/PrivacyInfo.xcprivacy');

    for (final tipo in [
      'EmailAddress',
      'PhoneNumber',
      'UserID',
      'DeviceID',
      'PhotosorVideos',
      'OtherUserContent',
      'CoarseLocation',
      'PaymentInfo',
      'CrashData',
    ]) {
      expect(
        manifesto,
        contains('NSPrivacyCollectedDataType$tipo'),
        reason: tipo,
      );
    }

    // I commenti non sono richieste di assistenza: stava scritto cosi'.
    expect(manifesto, isNot(contains('DataTypeCustomerSupport')));
  });

  test('non si chiede il permesso di tracciare: non serve', () {
    expect(
      leggi('ios/Runner/Info.plist'),
      isNot(contains('NSUserTrackingUsageDescription')),
    );
  });

  test('Android non chiede l\'identificativo pubblicitario', () {
    expect(
      leggi('android/app/src/main/AndroidManifest.xml'),
      contains('com.google.android.gms.permission.AD_ID" tools:node="remove"'),
    );
  });

  test('i testi non promettono profilazione, e dicono che non si traccia', () {
    final privacy = LegalTexts.privacy.body;

    expect(privacy, contains('NESSUN TRACCIAMENTO'));
    expect(privacy, isNot(contains('contenuti personalizzati')));
    expect(leggi('web/privacy/index.html'), contains('NESSUN TRACCIAMENTO'));
    expect(leggi('web/termini/index.html'), contains('TOLLERANZA ZERO'));
  });

  test('l\'informativa nomina tutti i dati che si raccolgono', () {
    final privacy = LegalTexts.privacy.body.replaceAll(RegExp(r'\s+'), ' ');

    for (final dato in [
      'numero di telefono',
      'Rubrica',
      'Posizione',
      'recapito del dispositivo',
      'codice fiscale',
      'IBAN',
      'Segnalazioni e blocchi',
    ]) {
      expect(privacy, contains(dato), reason: dato);
    }
  });

  test('l\'account per la revisione di Apple deve vedere i Termini', () {
    // Apple vuole vedere che senza accettarli non si entra: un account gia' a posto
    // non glieli mostrerebbe mai. Vedi `functions/tool/account_revisione.js`.
    expect(
      leggi('functions/tool/account_revisione.js'),
      contains('legalVersion: admin.firestore.FieldValue.delete()'),
    );
  });
}

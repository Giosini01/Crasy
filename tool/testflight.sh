#!/usr/bin/env bash
#
# Da qui a TestFlight, in un comando solo.
#
#   ./tool/testflight.sh
#
# Fa le quattro cose che si fanno ogni volta e che ogni volta si sbagliano:
# prende il lavoro nuovo, **alza il numero di build**, compila, e carica.
#
# Il numero di build e' il punto. App Store Connect rifiuta un caricamento con
# un numero gia' usato, e lo dice con un messaggio che parla d'altro: si scopre
# venti minuti dopo, a compilazione finita. Qui sale da solo.
#
# Per il caricamento automatico servono le tre cose della chiave API di App
# Store Connect (Users and Access -> Integrations -> App Store Connect API):
#
#   export APP_STORE_KEY_ID=XXXXXXXXXX
#   export APP_STORE_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   # il file .p8 va messo in ~/.appstoreconnect/private_keys/
#
# Senza quelle, la compilazione si fa lo stesso e alla fine si apre la cartella
# con il pacchetto: si trascina su Transporter e si carica a mano.

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Questo gira solo su macOS: un binario per iPhone lo puo' costruire"
  echo "solo un Mac, e non e' una limitazione di Flutter ma di Apple."
  exit 1
fi

echo "==> Prendo il lavoro nuovo"
git pull --ff-only

# --- il numero di build, alzato di uno -------------------------------------
#
# Sta in `pubspec.yaml` come `version: 1.0.0+7`: la parte dopo il piu'. Il
# numero prima resta quello — quello lo si cambia a mano quando cambia davvero
# qualcosa di grosso, e non a ogni prova.
versione=$(grep '^version:' pubspec.yaml | sed 's/version: //')
nome=${versione%%+*}
build=${versione##*+}
prossimo=$((build + 1))

sed -i '' "s/^version: .*/version: ${nome}+${prossimo}/" pubspec.yaml
echo "==> Build ${nome}+${prossimo} (prima era ${versione})"

echo "==> Compilo"
flutter pub get
flutter build ipa --release

pacchetto=$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)

if [[ -z "$pacchetto" ]]; then
  echo
  echo "Il pacchetto non e' stato creato: quasi sempre e' la firma."
  echo "Apri ios/Runner.xcworkspace e controlla Signing & Capabilities."
  exit 1
fi

if [[ -n "${APP_STORE_KEY_ID:-}" && -n "${APP_STORE_ISSUER_ID:-}" ]]; then
  echo "==> Carico su App Store Connect"
  xcrun altool --upload-app \
    --type ios \
    --file "$pacchetto" \
    --apiKey "$APP_STORE_KEY_ID" \
    --apiIssuer "$APP_STORE_ISSUER_ID"

  echo
  echo "Fatto. La build compare in TestFlight fra cinque e venti minuti:"
  echo "prima Apple la elabora, poi arriva la notifica a chi la sta provando."
else
  echo
  echo "Chiave API non configurata: il pacchetto e' pronto ma va caricato a mano."
  echo "Trascinalo su Transporter (gratis sul Mac App Store):"
  echo
  echo "  $pacchetto"
  echo
  open build/ios/ipa
fi

# Il numero nuovo si tiene: e' quello che sta su App Store Connect, e il
# prossimo caricamento deve partire da li'. Lasciarlo solo sul proprio computer
# vuol dire ritrovarsi due build con lo stesso numero il giorno che si compila
# da un'altra parte.
git add pubspec.yaml
git commit -m "Build ${nome}+${prossimo}"
echo "==> Ricordati di fare git push"

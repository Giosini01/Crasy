"""Manda una notifica di prova a tutti i telefoni registrati.

**A cosa serve.** Quando qualcuno dice "non mi arriva niente" ci sono due
domande diverse: *il suo telefono e' raggiungibile?* e *la cosa che doveva
partire e' partita?*. I registri del server rispondono alla seconda; questa
risponde alla prima, ed e' l'unica che si puo' verificare senza aspettare che
succeda qualcosa.

Il messaggio dice apertamente che e' una prova: mandare una notifica finta che
sembra vera — "hai vinto", "c'e' una missione" — per controllare un impianto
vuol dire far aprire l'app a qualcuno per niente.

Uso:

    python tool/prova_notifica.py           # dice a chi la manderebbe
    python tool/prova_notifica.py --vai     # la manda davvero
"""

import io
import json
import os
import sys
import urllib.error
import urllib.request

PROGETTO = "daily-dating-app"
FIRESTORE = (
    "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents"
    % PROGETTO
)
FCM = "https://fcm.googleapis.com/v1/projects/%s/messages:send" % PROGETTO

TESTO = "Prova di CRASY: se leggi questo, le notifiche arrivano"


def token():
    percorso = os.path.expanduser("~/.config/configstore/firebase-tools.json")

    with io.open(percorso, encoding="utf-8") as file:
        return json.load(file)["tokens"]["access_token"]


def chiama(url, permesso, corpo):
    richiesta = urllib.request.Request(
        url, data=json.dumps(corpo).encode("utf-8"), method="POST"
    )
    richiesta.add_header("Authorization", "Bearer " + permesso)
    richiesta.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(richiesta) as risposta:
            return json.loads(risposta.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as errore:
        return {"errore": errore.code, "testo": errore.read().decode("utf-8")[:300]}


def telefoni(permesso):
    """Tutti i `devices`, ovunque stiano: e' la stessa domanda che fa il server."""

    risposta = chiama(
        FIRESTORE + ":runQuery",
        permesso,
        {
            "structuredQuery": {
                "from": [{"collectionId": "devices", "allDescendants": True}],
                "limit": 500,
            }
        },
    )

    trovati = []

    for riga in risposta if isinstance(risposta, list) else []:
        documento = riga.get("document")

        if documento:
            pezzi = documento["name"].split("/")
            trovati.append((pezzi[-3], pezzi[-1]))

    return trovati


def main():
    prova = "--vai" not in sys.argv
    permesso = token()
    elenco = telefoni(permesso)

    print("telefoni registrati: %d" % len(elenco))

    for chi, indirizzo in elenco:
        print("   %s  %s..." % (chi, indirizzo[:18]))

    if prova:
        print("\n(aggiungi --vai per mandare davvero)")

        return

    for chi, indirizzo in elenco:
        esito = chiama(
            FCM,
            permesso,
            {
                "message": {
                    "token": indirizzo,
                    "notification": {"title": "CRASY", "body": TESTO},
                    "apns": {"payload": {"aps": {"sound": "crasy.wav", "badge": 1}}},
                    "android": {
                        "priority": "high",
                        "notification": {"sound": "crasy", "color": "#C8102E"},
                    },
                }
            },
        )
        print(
            "%s -> %s"
            % (chi, "mandata" if "name" in esito else esito.get("testo", esito))
        )


if __name__ == "__main__":
    main()

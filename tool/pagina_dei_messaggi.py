"""Dice a Firebase dove mandare chi clicca il link di un nostro messaggio.

**Il problema.** Il link dentro l'email di conferma porta a una pagina di
Firebase: bianca, mezza in inglese, e su `daily-dating-app.firebaseapp.com` —
il vecchio nome del progetto, che non compare da nessun'altra parte. L'ultima
cosa che vede chi si e' appena registrato e' una schermata che sembra di
qualcun altro.

L'indirizzo si cambia da qui: `notification.sendEmail.callbackUri`. Ci mettiamo
la nostra pagina, dentro il nostro sito.

**Perche' con il cancelletto.** L'app sul web tiene la rotta dopo `#`. Un
indirizzo senza cancelletto farebbe caricare l'app dalla porta principale, e
`mode` e `oobCode` — che sono tutto quello che serve — resterebbero fuori dalla
parte di indirizzo che l'app legge: si aprirebbe la home come se il link non
avesse detto niente.

Uso:

    python tool/pagina_dei_messaggi.py          # dice com'e' adesso
    python tool/pagina_dei_messaggi.py --vai    # la cambia
"""

import io
import json
import os
import sys
import urllib.error
import urllib.request

PROGETTO = "daily-dating-app"
NOSTRA = "https://crasy.web.app/#/conferma"
CONFIG = (
    "https://identitytoolkit.googleapis.com/admin/v2/projects/%s/config" % PROGETTO
)


def token():
    percorso = os.path.expanduser("~/.config/configstore/firebase-tools.json")

    with io.open(percorso, encoding="utf-8") as file:
        return json.load(file)["tokens"]["access_token"]


def chiama(url, permesso, metodo="GET", corpo=None):
    dati = None if corpo is None else json.dumps(corpo).encode("utf-8")
    richiesta = urllib.request.Request(url, data=dati, method=metodo)
    richiesta.add_header("Authorization", "Bearer " + permesso)
    richiesta.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(richiesta) as risposta:
            return json.loads(risposta.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as errore:
        raise RuntimeError("%s -> %s %s" % (url, errore.code, errore.read()[:400]))


def main():
    permesso = token()
    adesso = chiama(CONFIG, permesso)["notification"]["sendEmail"]
    print("adesso: %s" % adesso.get("callbackUri"))

    if "--vai" not in sys.argv:
        print("(aggiungi --vai per metterci %s)" % NOSTRA)

        return

    dopo = chiama(
        CONFIG + "?updateMask=notification.sendEmail.callbackUri",
        permesso,
        "PATCH",
        {"notification": {"sendEmail": {"callbackUri": NOSTRA}}},
    )
    print("dopo:   %s" % dopo["notification"]["sendEmail"].get("callbackUri"))


if __name__ == "__main__":
    main()

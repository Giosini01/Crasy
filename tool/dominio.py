"""Prepara crasyapp.com dentro Firebase Auth.

**Cosa fa e cosa non fa.** Aggiunge il dominio nuovo all'elenco di quelli
autorizzati e sposta l'indirizzo a cui portano i link dei nostri messaggi. Non
tocca il DNS e non compra niente: quella parte sta dal registrar, e i record da
scrivere li da' la console di Firebase quando si aggiunge il dominio a Hosting.

**L'elenco dei domini autorizzati e' una serratura, non un elenco.** Firebase
rifiuta di aprire le proprie finestre — accesso, controllo anti-robot, gestore
dei link — su un indirizzo che non sta li' dentro. Aggiungere il dominio prima
che serva non ha controindicazioni; farlo dopo aver cambiato il codice vuol dire
un'app che non fa piu' entrare nessuno nel frattempo.

Uso:

    python tool/dominio.py            # dice com'e' adesso
    python tool/dominio.py --vai      # aggiunge il dominio e sposta i link
"""

import io
import json
import os
import sys
import urllib.error
import urllib.request

PROGETTO = "daily-dating-app"
NUOVO = "crasyapp.com"

# Dove portano i link dei nostri messaggi.
#
# **Finche' crasyapp.com non e' su Hosting, resta crasy.web.app.** Sono lo
# stesso sito: uno e' l'indirizzo di casa e l'altro il nome sulla porta. Ma
# spostare i link su un dominio che ancora punta alla pagina parcheggio del
# registrar vorrebbe dire mandare chi si registra su una pubblicita' — e con un
# codice usa e getta in mano, che scade.
#
# Si cambia qui il giorno che il dominio risponde, e il controllo qui sotto non
# lascia farlo un minuto prima.
GESTORE = "https://crasy.web.app/#/conferma"
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
        raise RuntimeError("%s -> %s %s" % (url, errore.code, errore.read()[:300]))


def rispondeDavvero(indirizzo):
    """Controlla che li' dentro ci sia la nostra app e non altro.

    **E' il controllo che sarebbe servito ad agosto.** Un indirizzo scritto
    male, o un dominio comprato e non ancora collegato, non da' nessun errore
    quando lo si mette qui: da' un errore fra due giorni, al primo che prova a
    confermare la propria email e finisce su una pagina che non lo conosce.
    """

    pagina = indirizzo.split("#")[0]

    try:
        with urllib.request.urlopen(pagina, timeout=15) as risposta:
            testo = risposta.read(4000).decode("utf-8", "ignore")
    except Exception as errore:  # noqa: BLE001 — qualunque cosa vada storta e' un no
        return "non risponde (%s)" % errore

    # `flutter_bootstrap.js` c'e' solo dentro una pagina costruita da Flutter:
    # e' la firma piu' corta che distingue la nostra app da qualunque altra
    # cosa un dominio possa servire.
    if "flutter_bootstrap" not in testo and "CRASY" not in testo:
        return "risponde, ma non e' CRASY"

    return None


def main():
    permesso = token()
    adesso = chiama(CONFIG, permesso)
    domini = adesso.get("authorizedDomains", [])
    posta = adesso.get("notification", {}).get("sendEmail", {})

    print("domini autorizzati: %s" % ", ".join(domini))
    print("gestore dei link:   %s" % posta.get("callbackUri"))
    print("dominio della posta: %s (%s)" % (
        posta.get("dnsInfo", {}).get("pendingCustomDomain", "—"),
        posta.get("dnsInfo", {}).get("customDomainState", "—"),
    ))

    if "--vai" not in sys.argv:
        print("\n(aggiungi --vai per autorizzare %s e portare i link su %s)"
              % (NUOVO, GESTORE))

        return

    guaio = rispondeDavvero(GESTORE)

    if guaio:
        print("\nNON lo sposto: %s -> %s" % (GESTORE, guaio))
        print("Il dominio si aggiunge a Hosting prima, non dopo.")

        return

    if NUOVO not in domini:
        domini = domini + [NUOVO]

    dopo = chiama(
        CONFIG + "?updateMask=authorizedDomains,notification.sendEmail.callbackUri",
        permesso,
        "PATCH",
        {
            "authorizedDomains": domini,
            "notification": {"sendEmail": {"callbackUri": GESTORE}},
        },
    )

    print("\nadesso:")
    print("   domini: %s" % ", ".join(dopo.get("authorizedDomains", [])))
    print("   link:   %s" % dopo["notification"]["sendEmail"].get("callbackUri"))


if __name__ == "__main__":
    main()

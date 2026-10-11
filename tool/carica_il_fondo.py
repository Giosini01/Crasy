"""Carica il fondo delle missioni automatiche, dopo che i soldi sono arrivati.

**Prima i soldi veri, poi questo strumento. Mai il contrario.**

Quello che si scrive qui diventa un premio che qualcuno vincera' e prelevera'.
Se il saldo lo si scrive senza che i soldi siano davvero da qualche parte, il
buco non si vede subito: si vede fra due settimane, quando il primo vincitore
chiede i suoi dieci euro e non ci sono. Il registro che si scrive qui sotto
serve esattamente a poter rispondere, quel giorno, da dove venivano.

Uso:

    python tool/carica_il_fondo.py                      # dice cosa farebbe
    python tool/carica_il_fondo.py --vai                # lo fa

    # chi, quanto, e come deve lanciare
    python tool/carica_il_fondo.py \\
        --chi giosyni --euro 50 --al-giorno 2 --premio 2,50 \\
        --fino 2026-11-21 --vai

    python tool/carica_il_fondo.py --spegni giosyni --vai
    python tool/carica_il_fondo.py --guarda
"""

import argparse
import io
import json
import os
import sys
import urllib.error
import urllib.request

PROGETTO = "daily-dating-app"
BASE = (
    "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents"
    % PROGETTO
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


def valore(campi, nome, difetto=None):
    dato = campi.get(nome)

    if dato is None:
        return difetto

    for tipo in ("stringValue", "integerValue", "booleanValue", "timestampValue"):
        if tipo in dato:
            return dato[tipo]

    return difetto


def tutte(url, permesso):
    pagina = None

    while True:
        risposta = chiama(url + ("&pageToken=" + pagina if pagina else ""), permesso)

        for documento in risposta.get("documents", []):
            yield documento

        pagina = risposta.get("nextPageToken")

        if not pagina:
            return


def trova(nome, permesso):
    """Dall'etichetta al suo identificativo. Si scrive il nome, non l'uid."""
    for utente in tutte(BASE + "/users?pageSize=300&mask.fieldPaths=username", permesso):
        if valore(utente.get("fields", {}), "username") == nome:
            return utente["name"].rsplit("/", 1)[1]

    return None


def centesimi(testo):
    """`2,50` e `2.50` fanno duecentocinquanta. Un numero intero fa gli euro."""
    pulito = str(testo).replace(",", ".").strip()

    return int(round(float(pulito) * 100))


def euro(valore_centesimi):
    return "%.2f EUR" % (valore_centesimi / 100.0)


def guarda(permesso):
    print("%-14s %10s %8s %7s %9s %12s" % ("CHI", "FONDO", "ACCESO", "AL GG", "PREMIO", "FINO"))

    for salvadanaio in tutte(BASE + "/salvadanai?pageSize=100", permesso):
        uid = salvadanaio["name"].rsplit("/", 1)[1]
        campi = salvadanaio.get("fields", {})
        utente = chiama(BASE + "/users/" + uid, permesso)
        suoi = utente.get("fields", {})

        print(
            "%-14s %10s %8s %7s %9s %12s"
            % (
                valore(suoi, "username", uid)[:14],
                euro(int(valore(campi, "fondoCents", 0) or 0)),
                "si" if valore(campi, "acceso") in (True, "true") else "no",
                valore(campi, "alGiorno", "-"),
                euro(int(valore(campi, "premioCents", 0) or 0)),
                valore(campi, "fino", "-"),
            )
        )


def main():
    lettore = argparse.ArgumentParser(description=__doc__)
    lettore.add_argument("--chi", help="il nome di chi lancia, non l'uid")
    lettore.add_argument("--euro", help="quanti soldi NETTI sono arrivati su Stripe")
    lettore.add_argument("--al-giorno", type=int, default=2)
    lettore.add_argument("--premio", default="1")
    lettore.add_argument("--posti", type=int, default=10)
    lettore.add_argument("--ore", type=int, default=24)
    lettore.add_argument("--fino", help="ultimo giorno, tipo 2026-11-21")
    lettore.add_argument("--spegni", help="ferma il salvadanaio di questa persona")
    lettore.add_argument("--guarda", action="store_true")
    lettore.add_argument("--vai", action="store_true")
    scelte = lettore.parse_args()

    permesso = token()
    prova = not scelte.vai

    if scelte.guarda:
        guarda(permesso)

        return

    if scelte.spegni:
        uid = trova(scelte.spegni, permesso)

        if not uid:
            print("non trovo nessuno che si chiami %s" % scelte.spegni)
            sys.exit(1)

        print("spengo il salvadanaio di %s" % scelte.spegni)

        if not prova:
            chiama(
                BASE
                + "/salvadanai/"
                + uid
                + "?updateMask.fieldPaths=acceso&updateMask.fieldPaths=spentoPerche",
                permesso,
                "PATCH",
                {
                    "fields": {
                        "acceso": {"booleanValue": False},
                        "spentoPerche": {"stringValue": "a mano"},
                    }
                },
            )
            print("spento.")
        else:
            print("(aggiungi --vai per spegnerlo davvero)")

        return

    if not scelte.chi or not scelte.euro:
        lettore.print_help()
        sys.exit(1)

    uid = trova(scelte.chi, permesso)

    if not uid:
        print("non trovo nessuno che si chiami %s" % scelte.chi)
        sys.exit(1)

    da_mettere = centesimi(scelte.euro)
    premio = centesimi(scelte.premio)

    try:
        gia = chiama(BASE + "/salvadanai/" + uid, permesso)
        nel_fondo = int(valore(gia.get("fields", {}), "fondoCents", 0) or 0)
    except RuntimeError:
        nel_fondo = 0

    print("%s (%s)" % (scelte.chi, uid))
    print("  nel fondo      : %s" % euro(nel_fondo))
    print("  ci metto       : %s" % euro(da_mettere))
    print("  fondo dopo     : %s" % euro(nel_fondo + da_mettere))
    print("  premio a gara  : %s" % euro(premio))
    print("  al giorno      : %d" % scelte.al_giorno)
    quante = (nel_fondo + da_mettere) // premio if premio else 0
    print("  missioni       : %d" % quante)
    print("  durano         : circa %d giorni"
          % (quante // scelte.al_giorno if scelte.al_giorno else 0))
    print("  fino al        : %s" % (scelte.fino or "(nessuna scadenza: sconsigliato)"))

    if prova:
        print("\n(aggiungi --vai per scriverlo davvero)")

        return

    # **Nel fondo, non nel portafoglio.** Nel portafoglio quel numero lo
    # leggerebbe chiunque: vive dentro la scheda del profilo, e quella serve
    # per il nome e la foto, quindi e' aperta a tutti. Firestore protegge i
    # documenti, non i campi dentro.
    #
    # E poi non sono soldi di chi lancia da spendere come vuole: sono messi da
    # parte per i premi. Nel portafoglio si confonderebbero con quelli vinti,
    # che invece si possono prelevare.
    chiama(
        BASE + "/salvadanai/" + uid,
        permesso,
        "PATCH",
        {
            "fields": {
                "acceso": {"booleanValue": True},
                "fondoCents": {"integerValue": str(nel_fondo + da_mettere)},
                "alGiorno": {"integerValue": str(scelte.al_giorno)},
                "premioCents": {"integerValue": str(premio)},
                "oreDiGara": {"integerValue": str(scelte.ore)},
                "maxPartecipanti": {"integerValue": str(scelte.posti)},
                "fino": {"stringValue": scelte.fino or ""},
            }
        },
    )

    print("\nfatto: fondo caricato, missioni accese.")


if __name__ == "__main__":
    main()

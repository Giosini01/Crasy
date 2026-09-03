"""Legge quello che l'app manda a noi: segnalazioni e guasti.

**Nessuna delle due cose si vede da dentro CRASY, ed e' voluto.** Una schermata
di amministrazione dentro l'app vorrebbe dire un permesso in piu' nelle regole —
qualcuno che puo' leggere le segnalazioni di tutti — e quel permesso, una volta
scritto, vale per chiunque riesca a farsi passare per quel qualcuno. Finche'
siamo in pochi, si legge da qui con il token della CLI: nessun permesso nuovo,
nessuna schermata da proteggere.

Le due caselle:

- **segnalazioni** (`reports`): le manda una persona su una foto, un commento o
  un profilo. Vanno guardate a mano: sono poche e ognuna e' una decisione.
- **guasti** (`crashes`): li manda l'app da sola quando un pezzo di schermata va
  in errore. In una versione pubblicata un errore si vede come un rettangolo
  nero, e senza questi non resterebbe nessuna traccia di cosa sia successo.

Uso:

    python tool/posta_in_arrivo.py
"""

import io
import json
import os
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


def leggi(percorso, permesso, quanti=25):
    richiesta = urllib.request.Request("%s/%s?pageSize=%d" % (BASE, percorso, quanti))
    richiesta.add_header("Authorization", "Bearer " + permesso)

    try:
        with urllib.request.urlopen(richiesta) as risposta:
            return json.loads(risposta.read().decode("utf-8") or "{}").get(
                "documents", []
            )
    except urllib.error.HTTPError as errore:
        raise RuntimeError("%s -> %s" % (percorso, errore.code))


def valore(campo):
    if campo is None:
        return ""

    for chiave in ("stringValue", "timestampValue", "integerValue"):
        if chiave in campo:
            return campo[chiave]

    return ""


def main():
    permesso = token()

    print("=== SEGNALAZIONI ===")
    righe = leggi("reports", permesso)

    if not righe:
        print("   nessuna")

    for riga in righe:
        f = riga.get("fields", {})
        print(
            "   %s  %s  su %s  di %s"
            % (
                valore(f.get("createdAt"))[:19],
                valore(f.get("reason")),
                valore(f.get("kind")),
                valore(f.get("reportedUserId"))[:12],
            )
        )
        for campo in ("challengeId", "entryId", "commentId"):
            if valore(f.get(campo)):
                print("        %-12s %s" % (campo, valore(f.get(campo))))

    print("\n=== GUASTI ===")
    righe = leggi("crashes", permesso)

    if not righe:
        print("   nessuno")

    for riga in righe:
        f = riga.get("fields", {})
        print(
            "   %s  %s  %s"
            % (
                valore(f.get("quando"))[:19],
                valore(f.get("piattaforma")),
                valore(f.get("utente"))[:12],
            )
        )
        print("        %s" % valore(f.get("guasto"))[:200])

        pila = valore(f.get("pila"))

        for linea in pila.split("\n")[:4]:
            if linea.strip():
                print("        | %s" % linea.strip()[:110])


if __name__ == "__main__":
    main()

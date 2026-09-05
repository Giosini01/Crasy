"""Rimette i due campi mancanti nelle sfide del giorno gia' scritte.

**Il difetto.** Le funzioni di pulizia sul server cercano le gare da chiudere
con `winnerEntryId == null` e quelle da svuotare con `purgedAt == null`. In
Firestore un campo **che non c'e' non e' nullo**: e' assente, e una ricerca sul
nullo non lo trova.

Le sfide del giorno le scrive `tool/sfide_del_giorno.py`, che quei due campi non
li metteva. Risultato: sessanta sfide **invisibili a tutte e due le funzioni** —
mai chiuse dal server, e con le foto che non venivano mai cancellate. Il difetto
non produceva nessun errore: produceva silenzio, che e' il tipo peggiore.

Lo strumento e' stato corretto per quelle che verranno. Questo rimette a posto
quelle che ci sono gia'.

**Le tre che hanno gia' un vincitore non si toccano.** Sono quelle che l'app ha
chiuso quando qualcuno le ha aperte: scriverci sopra un `winnerEntryId` nullo
vorrebbe dire cancellare il risultato di una gara.

Uso:

    python tool/rattoppa_le_sfide.py          # dice cosa farebbe
    python tool/rattoppa_le_sfide.py --vai    # lo fa
"""

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


def main():
    prova = "--vai" not in sys.argv
    permesso = token()
    pagina = None
    rattoppate = 0
    saltate = 0

    while True:
        url = BASE + "/challenges?pageSize=300"

        if pagina:
            url += "&pageToken=" + pagina

        risposta = chiama(url, permesso)

        for gara in risposta.get("documents", []):
            campi = gara.get("fields", {})
            nome = gara["name"]
            manca = {}

            # Solo se manca davvero: chi ha gia' un vincitore lo tiene.
            if "winnerEntryId" not in campi:
                manca["winnerEntryId"] = {"nullValue": None}

            if "purgedAt" not in campi:
                manca["purgedAt"] = {"nullValue": None}

            if not manca:
                saltate += 1

                continue

            rattoppate += 1
            print(
                "%-24s manca: %s"
                % (nome.rsplit("/", 1)[1][:22], ", ".join(sorted(manca)))
            )

            if not prova:
                maschera = "".join(
                    "&updateMask.fieldPaths=" + chiave for chiave in manca
                )
                chiama(
                    "https://firestore.googleapis.com/v1/%s?%s"
                    % (nome, maschera.lstrip("&")),
                    permesso,
                    "PATCH",
                    {"fields": manca},
                )

        pagina = risposta.get("nextPageToken")

        if not pagina:
            break

    print("\nda rattoppare: %d   gia' a posto: %d" % (rattoppate, saltate))

    if prova:
        print("(aggiungi --vai per farlo davvero)")


if __name__ == "__main__":
    main()

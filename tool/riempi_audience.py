"""Scrive `audience` sulle gare che non ce l'hanno.

**Perche' serve.** Da adesso ogni gara porta dentro di se' chi la puo' vedere:
`["*"]` se e' pubblica, l'elenco degli amici di chi l'ha lanciata se e'
riservata. Tutte le query filtrano su quel campo — e **una query che filtra su un
campo salta i documenti che quel campo non ce l'hanno**. Le gare scritte prima di
oggi sparirebbero tutte insieme dalla home, senza un errore da nessuna parte.

Si lancia una volta sola, prima di pubblicare la versione nuova dell'app:

    python tool/riempi_audience.py --prova   # dice cosa farebbe
    python tool/riempi_audience.py

Il permesso arriva dal token della CLI di Firebase (`firebase login`).
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

# Il valore che vuol dire "la vedono tutti".
TUTTI = "*"


def token():
    percorso = os.path.expanduser("~/.config/configstore/firebase-tools.json")

    with io.open(percorso, encoding="utf-8") as file:
        return json.load(file)["tokens"]["access_token"]


def chiedi(indirizzo, permesso, dati=None, metodo="GET"):
    richiesta = urllib.request.Request(
        indirizzo,
        data=None if dati is None else json.dumps(dati).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + permesso,
            "Content-Type": "application/json",
        },
        method=metodo,
    )

    with urllib.request.urlopen(richiesta) as risposta:
        corpo = risposta.read()

    return json.loads(corpo) if corpo else {}


def gare(permesso):
    """Tutte le gare, pagina per pagina."""
    prossima = None

    while True:
        indirizzo = "%s/challenges?pageSize=200" % BASE

        if prossima:
            indirizzo += "&pageToken=%s" % prossima

        risposta = chiedi(indirizzo, permesso)

        for documento in risposta.get("documents", []):
            yield documento

        prossima = risposta.get("nextPageToken")

        if not prossima:
            return


def main():
    prova = "--prova" in sys.argv
    permesso = token()

    da_fare = 0
    gia_a_posto = 0

    for documento in gare(permesso):
        campi = documento.get("fields", {})
        nome = documento["name"].split("/")[-1]

        if "audience" in campi:
            gia_a_posto += 1
            continue

        da_fare += 1
        titolo = campi.get("title", {}).get("stringValue", "")

        if prova:
            print(nome, "|", titolo)
            continue

        chiedi(
            "%s/challenges/%s?updateMask.fieldPaths=audience" % (BASE, nome),
            permesso,
            {
                "fields": {
                    "audience": {
                        "arrayValue": {"values": [{"stringValue": TUTTI}]}
                    }
                }
            },
            metodo="PATCH",
        )
        print(nome, "|", titolo, "-> pubblica")

    print("gia' a posto:", gia_a_posto, "| da sistemare:", da_fare)


if __name__ == "__main__":
    main()

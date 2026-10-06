"""Ricalcola `followersCount` e `followingCount` di tutti i profili.

**Il difetto.** I tre trigger che tengono in piedi i contatori —
`contaFollowerNuovi`, `contaFollowerAmici`, `contaSeguiti` — sono scritti in
`functions/index.js` da sempre e **non sono mai stati pubblicati**. Si vede
confrontando il codice con il deploy:

    firebase functions:list --project daily-dating-app

Non c'era nessun errore da nessuna parte: i contatori erano semplicemente fermi
al numero con cui erano nati. Il profilo diceva "3 e 3" e gli elenchi sotto ne
mostravano decine, perche' gli elenchi leggono i documenti veri.

**Pubblicare i trigger non basta.** Sono incrementi: da domani contano quello che
succede, e il numero sbagliato di oggi resta sbagliato per sempre — ogni nuovo
follower lo fa diventare 4, 5, 6 partendo da un 3 che non e' mai stato vero.
Questo strumento rimette i numeri sulla realta', una volta.

Nell'ordine giusto: **prima si pubblicano i trigger, poi si gira questo.** Al
contrario, i follower arrivati nel frattempo non li conta nessuno.

**I conti, uguali a quelli del server.** Sono le stesse due righe di
`functions/index.js`, e devono restare le stesse: se divergono, il numero
ricalcolato qui e quello che il trigger fara' crescere domani partono da due idee
diverse di cosa sia un follower.

- follower  = `friendRequests` (chi mi segue e aspetta che ricambi) + `friends`
- seguiti   = `following`

Uso:

    python tool/rimetti_i_contatori.py          # dice cosa cambierebbe
    python tool/rimetti_i_contatori.py --vai    # lo scrive
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


def quante(utente, cartella, permesso):
    """Quanti documenti ci sono in una sottocartella di un profilo.

    Si chiedono gli identificativi e nient'altro — `mask.fieldPaths=__name__` —
    perche' qui interessa contare: senza la maschera, contare i follower di
    qualcuno vorrebbe dire scaricare il nome e la data di ognuno.
    """
    totale = 0
    pagina = None

    while True:
        url = "%s/%s/%s?pageSize=300&mask.fieldPaths=__name__" % (
            BASE,
            utente,
            cartella,
        )

        if pagina:
            url += "&pageToken=" + pagina

        risposta = chiama(url, permesso)
        totale += len(risposta.get("documents", []))
        pagina = risposta.get("nextPageToken")

        if not pagina:
            return totale


def numero(campi, nome):
    """Il valore attuale di un contatore, che puo' non esserci affatto."""
    valore = campi.get(nome, {})

    if "integerValue" in valore:
        return int(valore["integerValue"])

    if "doubleValue" in valore:
        return int(valore["doubleValue"])

    return None


def main():
    prova = "--vai" not in sys.argv
    permesso = token()
    pagina = None
    corretti = 0
    gia_giusti = 0

    print("profilo                   follower      seguiti")
    print("-" * 52)

    while True:
        url = BASE + "/users?pageSize=300&mask.fieldPaths=followersCount"
        url += "&mask.fieldPaths=followingCount&mask.fieldPaths=username"

        if pagina:
            url += "&pageToken=" + pagina

        risposta = chiama(url, permesso)

        for profilo in risposta.get("documents", []):
            nome = profilo["name"]
            corto = nome.split("/documents/")[1]
            campi = profilo.get("fields", {})

            veri_follower = quante(corto, "friendRequests", permesso) + quante(
                corto, "friends", permesso
            )
            veri_seguiti = quante(corto, "following", permesso)

            scritto_follower = numero(campi, "followersCount")
            scritto_seguiti = numero(campi, "followingCount")

            if (
                scritto_follower == veri_follower
                and scritto_seguiti == veri_seguiti
            ):
                gia_giusti += 1

                continue

            corretti += 1
            etichetta = (
                campi.get("username", {}).get("stringValue")
                or corto.rsplit("/", 1)[1]
            )
            print(
                "%-24s %5s -> %-5d %5s -> %-5d"
                % (
                    etichetta[:24],
                    "-" if scritto_follower is None else scritto_follower,
                    veri_follower,
                    "-" if scritto_seguiti is None else scritto_seguiti,
                    veri_seguiti,
                )
            )

            if not prova:
                chiama(
                    "https://firestore.googleapis.com/v1/%s"
                    "?updateMask.fieldPaths=followersCount"
                    "&updateMask.fieldPaths=followingCount" % nome,
                    permesso,
                    "PATCH",
                    {
                        "fields": {
                            "followersCount": {
                                "integerValue": str(veri_follower)
                            },
                            "followingCount": {
                                "integerValue": str(veri_seguiti)
                            },
                        }
                    },
                )

        pagina = risposta.get("nextPageToken")

        if not pagina:
            break

    print("\nda correggere: %d   gia' giusti: %d" % (corretti, gia_giusti))

    if prova:
        print("(aggiungi --vai per scriverli davvero)")


if __name__ == "__main__":
    main()

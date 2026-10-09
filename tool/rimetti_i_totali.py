"""Riempie `totalWonCents` e `totalStakedCents` con la storia gia' successa.

**Perche' servono due numeri nuovi.** La classifica sommava le gare chiuse di
recente — una finestra di quarantotto ore — e per questo calava da sola: un
premio di tre giorni fa usciva dalla finestra e il totale di quella persona
scendeva, mentre il suo profilo continuava a dire la cifra giusta. Sulla stessa
persona si leggevano 5,85 e 6,75, e un totale di soldi che scende da solo
sembra un ammanco anche quando non lo e'.

Nessuno dei numeri che c'erano puo' fare da classifica storica:

- il **saldo** dice quanto uno ha adesso, e scende quando preleva o quando paga
  una missione con quei soldi;
- le **gare** vengono svuotate quarantotto ore dopo la fine, e quelle cancellate
  spariscono del tutto.

Quindi il totale si scrive sull'utente nell'istante in cui il premio entra, e da
li' non si tocca piu'. Da adesso lo fanno le funzioni; questo strumento mette a
posto quello che e' successo prima.

**Da dove si ricostruisce.** Dai movimenti del portafoglio, non dalle gare: i
movimenti sono scritti dal server a ogni premio e a ogni pagamento, restano per
sempre, e sopravvivono alla cancellazione della gara a cui si riferiscono. Sono
l'unica traccia che non si perde — ed e' esattamente il motivo per cui la
classifica non deve piu' guardare le gare.

- `totalWonCents`   = somma dei movimenti `prize` (i positivi)
- `totalStakedCents`= somma dei movimenti `challengePayment` piu' le gare
                      pagate con la carta e non rimborsate

**Le gare pagate con la carta non lasciano un movimento nel portafoglio** —
quei soldi non sono mai passati di li' — quindi per quella meta' si guardano le
gare, accettando che le cancellate non si possano contare. E' una perdita
inevitabile e vale una volta sola: da adesso il contatore sale da solo.

Uso:

    python tool/rimetti_i_totali.py          # dice cosa scriverebbe
    python tool/rimetti_i_totali.py --vai    # lo scrive
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


def valore(campi, nome, difetto=None):
    dato = campi.get(nome)

    if dato is None:
        return difetto

    for tipo in ("stringValue", "integerValue", "booleanValue"):
        if tipo in dato:
            return dato[tipo]

    return difetto


def numero(campi, nome):
    grezzo = valore(campi, nome)

    return int(grezzo) if grezzo is not None else 0


def tutte(url, permesso):
    """Scorre tutte le pagine di una raccolta."""
    pagina = None

    while True:
        indirizzo = url + ("&pageToken=" + pagina if pagina else "")
        risposta = chiama(indirizzo, permesso)

        for documento in risposta.get("documents", []):
            yield documento

        pagina = risposta.get("nextPageToken")

        if not pagina:
            return


def main():
    prova = "--vai" not in sys.argv
    permesso = token()

    # **Le gare pagate con la carta, per chi le ha lanciate.** Le rimborsate no:
    # quei soldi sono tornati indietro e non hanno fatto giocare nessuno.
    carta = {}

    for gara in tutte(BASE + "/challenges?pageSize=300", permesso):
        campi = gara.get("fields", {})

        if valore(campi, "prizeStatus") not in ("held", "paidOut"):
            continue

        if valore(campi, "paidFromWallet") in (True, "true"):
            continue  # quelle dal portafoglio hanno gia' il loro movimento

        chi = valore(campi, "createdByUserId", "")

        if chi:
            soldi, quante = carta.get(chi, (0, 0))
            carta[chi] = (soldi + numero(campi, "prizeCents"), quante + 1)

    corretti = 0
    gia_giusti = 0

    print("profilo            vinto            messo in palio")
    print("-" * 56)

    for utente in tutte(
        BASE + "/users?pageSize=300&mask.fieldPaths=username"
        "&mask.fieldPaths=totalWonCents&mask.fieldPaths=totalStakedCents"
        "&mask.fieldPaths=totalWonCount&mask.fieldPaths=totalStakedCount",
        permesso,
    ):
        nome = utente["name"]
        corto = nome.split("/documents/")[1]
        uid = corto.rsplit("/", 1)[1]
        campi = utente.get("fields", {})

        vinto = 0
        quante_vinte = 0
        dal_portafoglio = 0
        quante_pagate = 0

        for riga in tutte(BASE + "/" + corto + "/wallet?pageSize=300", permesso):
            mosse = riga.get("fields", {})
            quanto = numero(mosse, "amountCents")
            tipo = valore(mosse, "kind", "")

            if tipo == "prize" or (tipo == "" and quanto > 0):
                vinto += quanto
                quante_vinte += 1
            elif tipo == "challengePayment":
                dal_portafoglio += -quanto
                quante_pagate += 1

        con_la_carta, quante_carta = carta.get(uid, (0, 0))
        messo = dal_portafoglio + con_la_carta
        quante_messe = quante_pagate + quante_carta

        if (
            numero(campi, "totalWonCents") == vinto
            and numero(campi, "totalStakedCents") == messo
            and numero(campi, "totalWonCount") == quante_vinte
            and numero(campi, "totalStakedCount") == quante_messe
        ):
            gia_giusti += 1

            continue

        corretti += 1
        print(
            "%-18s %5d -> %-5d   %5d -> %-5d"
            % (
                (valore(campi, "username") or uid)[:18],
                numero(campi, "totalWonCents"),
                vinto,
                numero(campi, "totalStakedCents"),
                messo,
            )
        )

        if not prova:
            chiama(
                "https://firestore.googleapis.com/v1/%s"
                "?updateMask.fieldPaths=totalWonCents"
                "&updateMask.fieldPaths=totalStakedCents"
                "&updateMask.fieldPaths=totalWonCount"
                "&updateMask.fieldPaths=totalStakedCount" % nome,
                permesso,
                "PATCH",
                {
                    "fields": {
                        "totalWonCents": {"integerValue": str(vinto)},
                        "totalStakedCents": {"integerValue": str(messo)},
                        "totalWonCount": {"integerValue": str(quante_vinte)},
                        "totalStakedCount": {
                            "integerValue": str(quante_messe)
                        },
                    }
                },
            )

    print("\nda scrivere: %d   gia' giusti: %d" % (corretti, gia_giusti))

    if prova:
        print("(aggiungi --vai per scriverli davvero)")


if __name__ == "__main__":
    main()

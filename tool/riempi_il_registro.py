"""Riempie il registro dei movimenti con quello che e' gia' successo.

Da adesso ogni movimento di denaro scrive la sua riga da solo. Questo strumento
serve una volta sola, per il passato.

**Da dove si ricostruisce, e cosa non si puo' ricostruire.**

- I **premi vinti**, i **prelievi** e le **missioni pagate col portafoglio** si
  rileggono dai movimenti del portafoglio: quelli ci sono tutti e restano anche
  quando la gara a cui si riferiscono e' stata cancellata.

- Le **missioni pagate con la carta** si rileggono dalle gare, perche' quei
  soldi nel portafoglio non sono mai passati.

- Le missioni pagate con la carta e poi **annullate non si possono
  ricostruire**: annullare cancella la gara, e prima di oggi non restava
  nessuna traccia da nessuna parte. Sono gli undici pagamenti parzialmente
  rimborsati che si vedono su Stripe e in nessun altro posto. Per quelli
  l'unico registro e' Stripe, e resta cosi'.

  E' esattamente il buco che il registro esiste per non riaprire mai piu'.

Uso:

    python tool/riempi_il_registro.py          # dice cosa scriverebbe
    python tool/riempi_il_registro.py --vai    # lo scrive
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

    for tipo in ("stringValue", "integerValue", "booleanValue", "timestampValue"):
        if tipo in dato:
            return dato[tipo]

    return difetto


def numero(campi, nome):
    grezzo = valore(campi, nome)

    return int(grezzo) if grezzo is not None else 0


def tutte(url, permesso):
    pagina = None

    while True:
        risposta = chiama(url + ("&pageToken=" + pagina if pagina else ""), permesso)

        for documento in risposta.get("documents", []):
            yield documento

        pagina = risposta.get("nextPageToken")

        if not pagina:
            return


def testo(valore_testo):
    return {"stringValue": valore_testo}


def main():
    prova = "--vai" not in sys.argv
    permesso = token()

    # Le gare pagate con la carta, raggruppate per chi le ha lanciate.
    carta = {}

    for gara in tutte(BASE + "/challenges?pageSize=300", permesso):
        campi = gara.get("fields", {})

        if valore(campi, "prizeStatus") not in ("held", "paidOut"):
            continue

        if valore(campi, "paidFromWallet") in (True, "true"):
            continue

        chi = valore(campi, "createdByUserId", "")

        if chi:
            carta.setdefault(chi, []).append(
                (
                    gara["name"].rsplit("/", 1)[1],
                    valore(campi, "title", "") or "",
                    numero(campi, "prizeCents"),
                    valore(campi, "paidAt") or valore(campi, "startsAt"),
                )
            )

    scritte = 0
    gia = 0

    for utente in tutte(
        BASE + "/users?pageSize=300&mask.fieldPaths=username", permesso
    ):
        corto = utente["name"].split("/documents/")[1]
        uid = corto.rsplit("/", 1)[1]
        nome = valore(utente.get("fields", {}), "username") or uid

        # Cosa c'e' gia' nel registro: si riscrive solo cio' che manca.
        presenti = {
            documento["name"].rsplit("/", 1)[1]
            for documento in tutte(
                BASE + "/" + corto + "/ledger?pageSize=300&mask.fieldPaths=kind",
                permesso,
            )
        }

        righe = []

        for movimento in tutte(
            BASE + "/" + corto + "/wallet?pageSize=300", permesso
        ):
            campi = movimento.get("fields", {})
            quanto = numero(campi, "amountCents")
            tipo = valore(campi, "kind", "")
            gara = valore(campi, "challengeId", "") or movimento[
                "name"
            ].rsplit("/", 1)[1]

            if tipo == "prize" or (tipo == "" and quanto > 0):
                righe.append(
                    (
                        "premio_" + gara,
                        "prize",
                        quanto,
                        gara,
                        valore(campi, "challengeTitle", "") or "",
                        "crasy",
                        "Premio vinto",
                        valore(campi, "createdAt"),
                    )
                )
            elif tipo == "challengePayment":
                righe.append(
                    (
                        "pagamento_" + gara,
                        "challengePayment",
                        quanto,
                        gara,
                        valore(campi, "challengeTitle", "") or "",
                        "wallet",
                        "Premio messo in palio",
                        valore(campi, "createdAt"),
                    )
                )
            elif tipo == "refund":
                righe.append(
                    (
                        "rimborso_" + gara,
                        "refund",
                        quanto,
                        gara,
                        valore(campi, "challengeTitle", "") or "",
                        "wallet",
                        "Rimborso",
                        valore(campi, "createdAt"),
                    )
                )
            elif tipo == "withdrawal" or (tipo == "" and quanto < 0):
                righe.append(
                    (
                        "prelievo_" + movimento["name"].rsplit("/", 1)[1],
                        "withdrawal",
                        quanto,
                        "",
                        "",
                        "bank",
                        "Prelievo",
                        valore(campi, "createdAt"),
                    )
                )

        for gara, titolo, premio, quando in carta.get(uid, []):
            righe.append(
                (
                    "pagamento_" + gara,
                    "challengePayment",
                    -premio,
                    gara,
                    titolo,
                    "card",
                    "Premio messo in palio, pagato con la carta",
                    quando,
                )
            )

        for (
            identificativo,
            tipo,
            quanto,
            gara,
            titolo,
            fonte,
            nota,
            quando,
        ) in righe:
            if identificativo in presenti:
                gia += 1

                continue

            scritte += 1
            print(
                "   %-12s %-34s %6d  %s"
                % (nome[:12], identificativo[:34], quanto, fonte)
            )

            if not prova:
                campi = {
                    "kind": testo(tipo),
                    "amountCents": {"integerValue": str(quanto)},
                    "challengeId": testo(gara),
                    "challengeTitle": testo(titolo),
                    "source": testo(fonte),
                    "note": testo(nota),
                }

                if quando:
                    campi["at"] = {"timestampValue": quando}

                chiama(
                    "https://firestore.googleapis.com/v1/%s/ledger/%s"
                    % (utente["name"], identificativo),
                    permesso,
                    "PATCH",
                    {"fields": campi},
                )

    print("\nda scrivere: %d   gia' presenti: %d" % (scritte, gia))

    if prova:
        print("(aggiungi --vai per scriverle davvero)")


if __name__ == "__main__":
    main()

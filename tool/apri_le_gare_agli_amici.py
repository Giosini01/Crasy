"""Rimette negli `audience` gli amici arrivati **dopo** il lancio.

**Il difetto.** Chi puo' vedere una gara fra amici sta scritto dentro la gara,
nel campo `audience`, e quella lista si scrive una volta sola: al lancio, con gli
amici di quel momento. Chi diventa amico un'ora dopo non vede una gara che dura
sei ore — e non c'e' niente nell'app che glielo spieghi. Uno aggiunge un amico
**proprio perche' gli ha parlato di quella gara**, apre la scheda degli amici, e
la trova vuota.

Da adesso ci pensa il server: `openFriendChallengesToNewFriend` scatta appena
nasce un'amicizia e allarga la lista delle gare ancora aperte. Ma le gare che
sono aperte **adesso** quella funzione non le ha mai viste nascere, e per loro
non scattera' mai niente.

Questo strumento le rattoppa: per ogni gara fra amici ancora aperta, prende gli
amici di oggi di chi l'ha lanciata e li mette fra i destinatari.

**Solo quelle ancora aperte.** Una gara finita non si puo' piu' giocare, e
infilarci dentro qualcuno vorrebbe dire farlo comparire fra i destinatari di una
cosa che ha perso per definizione.

**Il tetto di trecento e' quello delle regole**, non un'idea nostra: un
documento che lo supera diventa impossibile da aggiornare per chiunque, perche'
la regola guarda la dimensione a ogni scrittura. Meglio lasciare fuori un amico
che murare una gara.

Uso:

    python tool/apri_le_gare_agli_amici.py          # dice cosa farebbe
    python tool/apri_le_gare_agli_amici.py --vai    # lo fa

Il permesso arriva dal token della CLI di Firebase (`firebase login`).
"""

import datetime
import sys

from riempi_audience import BASE, chiedi, gare, token

# Il tetto scritto nelle regole del database.
QUANTI_AL_MASSIMO = 300


def adesso():
    return datetime.datetime.now(datetime.timezone.utc)


def quando(testo):
    """La data come la scrive Firestore, letta senza sorprese."""

    if not testo:
        return None

    # Firestore scrive la Z finale, e i frammenti di secondo hanno un numero di
    # cifre che cambia. `fromisoformat` di Python vuole il fuso scritto per
    # esteso e non piu' di sei cifre.
    pulita = testo.replace("Z", "+00:00")

    if "." in pulita:
        testa, coda = pulita.split(".", 1)
        cifre = "".join(c for c in coda if c.isdigit())[:6]
        fuso = coda[len(coda) - 6:] if "+" in coda else "+00:00"
        pulita = "%s.%s%s" % (testa, cifre.ljust(6, "0"), fuso)

    return datetime.datetime.fromisoformat(pulita)


def amici_di(chi, permesso):
    """Chi sono gli amici di qualcuno, oggi."""

    risposta = chiedi("%s/users/%s/friends?pageSize=300" % (BASE, chi), permesso)

    return [d["name"].split("/")[-1] for d in risposta.get("documents", [])]


def main():
    vai = "--vai" in sys.argv
    permesso = token()
    ora = adesso()

    guardate = 0
    sistemate = 0
    aggiunti = 0

    for documento in gare(permesso):
        campi = documento.get("fields", {})

        if campi.get("scope", {}).get("stringValue") != "friends":
            continue

        fine = quando(campi.get("endsAt", {}).get("timestampValue"))

        if fine is None or fine <= ora:
            continue

        guardate += 1
        nome = documento["name"].split("/")[-1]
        titolo = campi.get("title", {}).get("stringValue", "")
        autore = campi.get("createdByUserId", {}).get("stringValue", "")

        if not autore:
            print("saltata (senza autore):", nome)
            continue

        destinatari = [
            v.get("stringValue")
            for v in campi.get("audience", {}).get("arrayValue", {}).get("values", [])
        ]

        # Una pubblica non si tocca: ha la stella dentro, e allungare la lista
        # non cambierebbe chi la vede.
        if "*" in destinatari:
            continue

        mancanti = [a for a in amici_di(autore, permesso) if a not in destinatari]

        if not mancanti:
            continue

        nuovi = destinatari + mancanti

        if len(nuovi) > QUANTI_AL_MASSIMO:
            tagliati = len(nuovi) - QUANTI_AL_MASSIMO
            nuovi = nuovi[:QUANTI_AL_MASSIMO]
            print("attenzione:", nome, "-", tagliati, "amici restano fuori (tetto)")

        sistemate += 1
        aggiunti += len(nuovi) - len(destinatari)

        print(
            "%s | %s -> %d destinatari (erano %d)"
            % (nome, titolo[:40], len(nuovi), len(destinatari))
        )

        if not vai:
            continue

        chiedi(
            "%s/challenges/%s?updateMask.fieldPaths=audience" % (BASE, nome),
            permesso,
            {
                "fields": {
                    "audience": {
                        "arrayValue": {
                            "values": [{"stringValue": u} for u in nuovi]
                        }
                    }
                }
            },
            metodo="PATCH",
        )

    print(
        "\ngare fra amici ancora aperte: %d | sistemate: %d | persone aggiunte: %d"
        % (guardate, sistemate, aggiunti)
    )

    if not vai and sistemate:
        print("\nProva soltanto. Per farlo davvero: --vai")


if __name__ == "__main__":
    main()

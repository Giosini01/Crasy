"""Riscrive le sfide del giorno future con le consegne nuove.

**Serve perche' le sfide si scrivono in anticipo.** `sfide_del_giorno.py` ne
prepara un mese alla volta, e non sovrascrive niente: e' la scelta giusta —
rilanciarlo per sbaglio non deve poter cambiare una gara sotto i piedi di chi la
sta giocando. Il prezzo pero' e' che **un elenco nuovo non entra in vigore**
finche' non finiscono quelle gia' scritte, cioe' fra settimane.

Questo strumento le rinnova. Con due regole, e sono tutte e due sulla stessa
cosa: non si tocca una gara che qualcuno sta gia' giocando.

1. **Quella di oggi non si tocca mai.** E' aperta adesso: qualcuno l'ha letta
   stamattina, e magari e' gia' uscito di casa per farla. Cambiargliela sotto
   sarebbe la cosa peggiore che si puo' fare a chi ti ha dato retta.

2. **E nessuna che abbia gia' un partecipante.** Non dovrebbe capitare — sono
   nel futuro — ma se capita, quella foto e' stata mandata per **quella**
   consegna, e cambiarla trasformerebbe una partecipazione valida in una fuori
   tema.

Uso:

    python tool/rinnova_le_sfide.py          # dice cosa farebbe
    python tool/rinnova_le_sfide.py --vai    # lo fa

Il permesso arriva dal token della CLI di Firebase (`firebase login`).
"""

import datetime
import sys

import sfide_del_giorno as sfide
from riempi_audience import BASE, chiedi, token


def oggi():
    return datetime.date.today()


def main():
    vai = "--vai" in sys.argv
    permesso = token()
    limite = oggi()

    guardate = 0
    rinnovate = 0
    saltate = 0

    # Lo stesso giro di date e lo stesso ordine di consegne che usa lo strumento
    # che le scrive: cosi' il calendario resta quello, e cambia solo il
    # contenuto.
    # Trenta giorni, gli stessi che scrive `sfide_del_giorno.py`.
    for passo in range(30):
        giorno = limite + datetime.timedelta(days=passo)
        chiave = "daily-%s" % giorno.isoformat()
        consegna = sfide.CONSEGNE[passo % len(sfide.CONSEGNE)]

        if giorno <= limite:
            print("%s | e' quella di oggi, non si tocca" % chiave)
            saltate += 1
            continue

        guardate += 1

        try:
            adesso = chiedi("%s/challenges/%s" % (BASE, chiave), permesso)
        except Exception:  # noqa: BLE001 — non c'e', la scrivera' l'altro strumento
            print("%s | non esiste ancora" % chiave)
            continue

        campi = adesso.get("fields", {})
        quanti = int(campi.get("participantsCount", {}).get("integerValue", 0) or 0)

        if quanti > 0:
            print("%s | ha gia' %d partecipanti, non si tocca" % (chiave, quanti))
            saltate += 1
            continue

        vecchio = campi.get("title", {}).get("stringValue", "")

        if vecchio == consegna[0]:
            continue

        rinnovate += 1
        print("%s | %s  ->  %s" % (chiave, vecchio[:34], consegna[0][:40]))

        if not vai:
            continue

        sfide.scrivi(
            "challenges",
            chiave,
            sfide.documento(giorno, consegna),
            permesso,
            sovrascrivi=True,
        )

    print(
        "\nguardate: %d | rinnovate: %d | lasciate stare: %d"
        % (guardate, rinnovate, saltate)
    )

    if not vai and rinnovate:
        print("\nProva soltanto. Per farlo davvero: --vai")


if __name__ == "__main__":
    main()

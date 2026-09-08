"""Scrive le sfide del giorno di CRASY dentro Firestore.

**Perche' esiste questo file e non una funzione che gira sul server.** Le
funzioni programmate di Firebase vogliono il piano a consumo, che non e' attivo.
Allora le gare si scrivono in anticipo — un mese alla volta — e l'app non deve
fare altro che pescare quella aperta adesso: nessuno deve essere sveglio a
mezzanotte.

**La sfida del giorno non ha premio, ed e' la ragione per cui puo' essere di
CRASY.** Una societa' che promette un premio fa un concorso a premi (DPR
430/2001): comunicazione al ministero, cauzione, verbale, ritenuta. Senza premio
non c'e' niente da notificare. Le consegne qui sotto sono tutte cose che si
fanno in casa con quello che si ha — **niente che chieda di rischiare
qualcosa** — perche' a scriverle e' l'app, e di quello che chiede risponde
l'app.

Uso:

    python tool/sfide_del_giorno.py             # trenta giorni da oggi
    python tool/sfide_del_giorno.py 60          # sessanta
    python tool/sfide_del_giorno.py 30 --prova  # dice cosa scriverebbe, e basta

Il permesso arriva dal token della CLI di Firebase: serve aver fatto
`firebase login` su questa macchina.
"""

import datetime
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

# Il nome con cui CRASY firma le proprie sfide. Deve combaciare con
# `Challenge.crasyUserId` dentro l'app.
CRASY = "crasy"

# La fotografia del profilo di CRASY: l'icona dell'app, servita dal sito.
#
# **Non sta su Storage di proposito.** Un file su Storage vuole un indirizzo con
# un gettone dentro, che si ottiene caricandolo dall'app; questo e' gia' online,
# e' pubblico, ed e' esattamente la stessa immagine che la gente ha sul telefono.
FOTO = "https://crasy.web.app/icons/Icon-512.png"

# Le consegne, in ordine. Si ripetono quando finiscono: meglio una che torna fra
# due mesi che un giorno senza sfida.
CONSEGNE = [
    ("La cosa piu' brutta che hai in casa", "Cercala bene. C'e'.", "photo"),
    ("La faccia che fai appena sveglio", "Nessun filtro, nessuna scusa.", "photo"),
    ("Il tuo pranzo, com'e' davvero", "Anche se e' triste. Soprattutto.", "photo"),
    ("Travestiti con quello che trovi in casa", "Hai due minuti e un armadio.", "photo"),
    ("Il posto piu' assurdo in cui riesci a farti una foto", "Dentro casa vale.", "photo"),
    ("Imita qualcuno che conosci", "Deve capirsi chi e' senza scriverlo.", "video"),
    ("Presenta il tuo animale, o la tua pianta", "Ha un nome? Diccelo.", "photo"),
    ("La scarpa piu' consumata che hai", "Piu' e' distrutta piu' vale.", "photo"),
    ("Apri il frigo e fotografalo", "Cosi' com'e', adesso.", "photo"),
    ("Il selfie piu' brutto che riesci a farti", "Impegnati.", "photo"),
    ("Ricrea la copertina di un disco", "Con quello che hai in casa.", "photo"),
    ("La tua stanza, la verita'", "Senza mettere niente a posto.", "photo"),
    ("Fai la faccia del cattivo", "Quella che fa paura ai bambini.", "photo"),
    ("Il tuo caffe', fotografato benissimo", "Come se finisse su una rivista.", "photo"),
    ("Balla cinque secondi dove ti trovi", "Dove ti trovi adesso, non dopo.", "video"),
    ("L'oggetto piu' vecchio che possiedi", "Raccontacelo in una riga.", "photo"),
    ("Il tuo posto preferito, in una foto sola", "Deve capirsi perche'.", "photo"),
    ("Fai vedere le tue mani", "Dicono piu' di quanto pensi.", "photo"),
    ("Il disegno peggiore che sai fare", "Trenta secondi, poi si consegna.", "photo"),
    ("Canta due parole di una canzone", "Due. Non tre.", "video"),
    ("La cosa piu' inutile che hai comprato", "E dicci quanto l'hai pagata.", "photo"),
    ("Il tuo tramonto di oggi", "Se piove, il tuo cielo.", "photo"),
    ("Fai una torre con quello che hai sul tavolo", "Piu' e' alta meglio e'.", "photo"),
    ("La maglietta che non butti mai", "E il motivo, in tre parole.", "photo"),
    ("Un travestimento da anziano", "Con quello che hai.", "photo"),
    ("Il tuo angolo di casa piu' bello", "Uno solo.", "photo"),
    ("Fai vedere cosa stai guardando adesso", "Alza il telefono e gira.", "video"),
    ("La foto piu' vecchia che hai nel telefono", "Scorri fino in fondo.", "photo"),
    ("Il tuo pigiama", "Indossato. Non piegato sul letto.", "photo"),
    ("Costruisci una faccia con del cibo", "Poi mangiala.", "photo"),
]


def token():
    percorso = os.path.expanduser("~/.config/configstore/firebase-tools.json")

    with io.open(percorso, encoding="utf-8") as file:
        return json.load(file)["tokens"]["access_token"]


def quando(giorno, ora, minuto=0, secondo=0):
    """L'istante scritto come lo vuole Firestore, in ora universale.

    Il fuso e' quello di questa macchina: le sfide cominciano e finiscono a
    mezzanotte **italiana**, che e' la mezzanotte di chi usa l'app.
    """
    locale = datetime.datetime(
        giorno.year, giorno.month, giorno.day, ora, minuto, secondo
    )
    scarto = locale.astimezone().utcoffset()

    return (locale - scarto).strftime("%Y-%m-%dT%H:%M:%SZ")


def documento(giorno, consegna):
    titolo, dettaglio, media = consegna

    return {
        "fields": {
            "title": {"stringValue": titolo},
            "brief": {"stringValue": dettaglio},
            # **Zero, e non e' una dimenticanza.** Vedi il commento in testa.
            "prizeCents": {"integerValue": "0"},
            "kind": {"stringValue": "daily"},
            "scope": {"stringValue": "global"},
            "place": {"stringValue": ""},
            "mediaKind": {"stringValue": media},
            # **Sempre istantanea.** La sfida del giorno chiede di fare una
            # cosa oggi: e' tutto il suo senso. Scritto per esteso invece che
            # lasciato mancante perche' un campo assente si fa dimenticare —
            # e' gia' successo con `purgedAt`, e sono state sessanta sfide
            # invisibili alla pulizia per mesi.
            "source": {"stringValue": "instant"},
            "createdByUsername": {"stringValue": CRASY},
            # **Un identificativo vero, non una casella vuota.** Cosi' la sfida
            # ha una faccia e un profilo come tutte le altre gare, e chi la
            # legge puo' toccare il nome. Nessuno puo' entrare con questo nome:
            # non esiste un account con una password, esiste solo un documento.
            "createdByUserId": {"stringValue": CRASY},
            # **Ventiquattro ore esatte.** Da mezzanotte a mezzanotte, e la fine
            # dell'una e' l'inizio dell'altra: allo scoccare, la vecchia e' gia'
            # chiusa e la nuova gia' aperta, senza un istante in cui ce ne sono
            # due o nessuna.
            "startsAt": {"timestampValue": quando(giorno, 0)},
            "endsAt": {
                "timestampValue": quando(giorno + datetime.timedelta(days=1), 0)
            },
            "participantsCount": {"integerValue": "0"},
            # **I due campi che nessuno guarda, e senza i quali le sfide non
            # muoiono mai.**
            #
            # Le due funzioni di pulizia sul server cercano le gare da chiudere
            # con `winnerEntryId == null` e quelle da svuotare con
            # `purgedAt == null`. In Firestore un campo **che non c'e' non e'
            # nullo**: e' assente, e una ricerca sul nullo non lo trova. Senza
            # queste due righe le sfide del giorno restavano invisibili a tutte
            # e due — non venivano mai chiuse dal server, e le foto non venivano
            # mai cancellate.
            #
            # L'app li scrive da sempre sulle gare che crea lei (vedi
            # `challenge_mapper.dart`); qui erano stati dimenticati, e il difetto
            # non si vedeva perche' non produce nessun errore: produce silenzio.
            "winnerEntryId": {"nullValue": None},
            "purgedAt": {"nullValue": None},
            "prizeStatus": {"stringValue": "unpaid"},
            "rules": {"arrayValue": {"values": []}},
            # Chi la puo' vedere: tutti. Le gare riservate agli amici portano
            # qui dentro l'elenco degli amici di chi le ha lanciate.
            "audience": {"arrayValue": {"values": [{"stringValue": "*"}]}},
        }
    }


def profilo():
    """Il documento del profilo di CRASY.

    Serve perche' toccare il nome sotto una sfida del giorno apra qualcosa. Un
    nome che si tocca e non apre niente e' peggio di un nome che non si tocca.
    """
    return {
        "fields": {
            "username": {"stringValue": CRASY},
            "bio": {"stringValue": "La sfida del giorno. Gratis, ogni giorno."},
            "city": {"stringValue": ""},
            "photoUrl": {"stringValue": FOTO},
        }
    }


def scrivi(percorso, chiave, corpo, permesso, sovrascrivi=False):
    # L'identificativo e' la data: rilanciare lo script non crea doppioni.
    indirizzo = "%s/%s?documentId=%s" % (BASE, percorso, chiave)
    richiesta = urllib.request.Request(
        indirizzo,
        data=json.dumps(corpo).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + permesso,
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        urllib.request.urlopen(richiesta)

        return "scritto"
    except urllib.error.HTTPError as errore:
        if errore.code != 409:
            raise

        if not sovrascrivi:
            return "c'era gia'"

    # Esisteva: si aggiorna soltanto quello che gli passiamo, cosi' correggere
    # una consegna sbagliata e' questione di rilanciare lo script.
    campi = "&".join(
        "updateMask.fieldPaths=%s" % nome for nome in corpo["fields"]
    )
    aggiorna = urllib.request.Request(
        "%s/%s/%s?%s" % (BASE, percorso, chiave, campi),
        data=json.dumps(corpo).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + permesso,
            "Content-Type": "application/json",
        },
        method="PATCH",
    )
    urllib.request.urlopen(aggiorna)

    return "aggiornato"


def main():
    argomenti = [a for a in sys.argv[1:] if not a.startswith("--")]
    quanti = int(argomenti[0]) if argomenti else 30
    prova = "--prova" in sys.argv

    permesso = None if prova else token()
    oggi = datetime.date.today()

    if prova:
        print("users/%s | il profilo di CRASY" % CRASY)
    else:
        print(
            "users/%s | il profilo di CRASY ->" % CRASY,
            scrivi("users", CRASY, profilo(), permesso, sovrascrivi=True),
        )

    for passo in range(quanti):
        giorno = oggi + datetime.timedelta(days=passo)
        chiave = "daily-%s" % giorno.isoformat()
        consegna = CONSEGNE[passo % len(CONSEGNE)]

        if prova:
            print(chiave, "|", consegna[0])
            continue

        esito = scrivi(
            "challenges", chiave, documento(giorno, consegna), permesso
        )
        print(chiave, "|", consegna[0], "->", esito)


if __name__ == "__main__":
    main()

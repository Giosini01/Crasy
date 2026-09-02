"""Svuota CRASY: gare, foto, account. Tutto, senza rete di salvataggio.

**A cosa serve.** Prima di aprire agli altri bisogna rifare il giro da capo
almeno una volta: iscrizione, conferma dell'email, verifica del numero, prima
gara. Con dentro i conti delle prove vecchie quel giro non si puo' fare — chi
ha gia' l'email confermata non vede la schermata della conferma, e il difetto
che sta li' resta li'.

**Non e' un ripristino: e' una cancellazione.** Non c'e' cestino, non c'e'
copia, non si torna indietro. Per questo non parte senza `--vai` scritto a
mano: un comando che svuota tutto e parte da solo e' un comando che prima o poi
parte per sbaglio.

Uso:

    python tool/svuota_tutto.py            # dice cosa cancellerebbe, e basta
    python tool/svuota_tutto.py --vai      # lo fa davvero

Il permesso arriva dal token della CLI di Firebase: serve aver fatto
`firebase login` su questa macchina.
"""

import io
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

PROGETTO = "daily-dating-app"
SECCHIO = "daily-dating-app.firebasestorage.app"
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
            testo = risposta.read().decode("utf-8")

            return json.loads(testo) if testo else {}
    except urllib.error.HTTPError as errore:
        # 404 = qualcun altro l'ha gia' tolto di mezzo, va bene cosi'.
        if errore.code == 404:
            return {}

        raise RuntimeError(
            "%s %s -> %s %s" % (metodo, url, errore.code, errore.read()[:400])
        )


# --- Firestore ----------------------------------------------------------------
#
# I documenti si cancellano uno per uno, e **le sottoraccolte non se ne vanno
# con il padre**: cancellare `users/pippo` lascia in vita `users/pippo/devices`,
# che resta li' invisibile e continua a ricevere notifiche. Per questo si scende
# fino in fondo prima di risalire.


def documenti(percorso, permesso):
    """I nomi completi dei documenti dentro una raccolta, tutte le pagine."""

    trovati = []
    pagina = None

    while True:
        url = percorso + "?pageSize=300&mask.fieldPaths=__name__"

        if pagina:
            url += "&pageToken=" + pagina

        risposta = chiama(url, permesso)
        # Firestore torna il nome senza indirizzo davanti — `projects/.../
        # documents/gare/xyz` — che come indirizzo non vale niente.
        trovati += [
            "https://firestore.googleapis.com/v1/" + riga["name"]
            for riga in risposta.get("documents", [])
        ]
        pagina = risposta.get("nextPageToken")

        if not pagina:
            return trovati


def sottoraccolte(documento, permesso):
    risposta = chiama(documento + ":listCollectionIds", permesso, "POST", {})

    return risposta.get("collectionIds", [])


def pulisci(percorso, permesso, prova, conta):
    """Cancella tutto quello che sta dentro una raccolta."""

    for documento in documenti(percorso, permesso):
        for figlia in sottoraccolte(documento, permesso):
            pulisci(documento + "/" + figlia, permesso, prova, conta)

        conta[0] += 1

        if not prova:
            chiama(documento, permesso, "DELETE")


# --- Storage ------------------------------------------------------------------


def svuota_il_secchio(permesso, prova):
    quanti = 0
    pagina = None
    elenco = "https://storage.googleapis.com/storage/v1/b/%s/o" % SECCHIO

    while True:
        url = elenco + "?maxResults=500"

        if pagina:
            url += "&pageToken=" + pagina

        risposta = chiama(url, permesso)

        for oggetto in risposta.get("items", []):
            quanti += 1

            if not prova:
                chiama(
                    elenco + "/" + urllib.parse.quote(oggetto["name"], safe=""),
                    permesso,
                    "DELETE",
                )

        pagina = risposta.get("nextPageToken")

        if not pagina:
            return quanti


# --- Account ------------------------------------------------------------------
#
# **Gli account si cancellano per ultimi.** Finche' esistono, le regole di
# Firestore continuano a valere e le cancellazioni di sopra si possono
# rifare; tolti quelli, se qualcosa e' rimasto indietro resta orfano e non lo
# raggiunge piu' nessuno.


def conti(permesso):
    url = (
        "https://identitytoolkit.googleapis.com/v1/projects/%s/accounts:query"
        % PROGETTO
    )
    trovati = []
    da = 0

    while True:
        risposta = chiama(
            url, permesso, "POST", {"returnUserInfo": True, "offset": str(da), "limit": "500"}
        )
        pezzo = risposta.get("userInfo", [])
        trovati += pezzo

        if len(pezzo) < 500:
            return trovati

        da += len(pezzo)


def cancella_i_conti(permesso, prova):
    elenco = conti(permesso)

    for riga in elenco:
        print(
            "   %s  %s  %s"
            % (riga.get("localId"), riga.get("email", "-"), riga.get("phoneNumber", "-"))
        )

    if not prova and elenco:
        url = (
            "https://identitytoolkit.googleapis.com/v1/projects/%s/accounts:batchDelete"
            % PROGETTO
        )

        for inizio in range(0, len(elenco), 500):
            chiama(
                url,
                permesso,
                "POST",
                {
                    "localIds": [
                        riga["localId"] for riga in elenco[inizio : inizio + 500]
                    ],
                    # Serve a togliere anche chi ha una sessione aperta: senza,
                    # Firebase rifiuta di cancellare chi non e' disabilitato.
                    "force": True,
                },
            )

    return len(elenco)


def main():
    prova = "--vai" not in sys.argv
    permesso = token()

    if prova:
        print("PROVA — non cancello niente. Aggiungi --vai per farlo davvero.\n")

    print("Gare, profili, voti, commenti...")
    conta = [0]

    for raccolta in chiama(BASE + ":listCollectionIds", permesso, "POST", {}).get(
        "collectionIds", []
    ):
        prima = conta[0]
        pulisci(BASE + "/" + raccolta, permesso, prova, conta)
        print("   %-16s %d" % (raccolta, conta[0] - prima))

    print("   totale documenti: %d\n" % conta[0])

    print("Foto e video...")
    print("   file: %d\n" % svuota_il_secchio(permesso, prova))

    print("Account...")
    print("   totale: %d\n" % cancella_i_conti(permesso, prova))

    print("Fatto." if not prova else "Fine della prova.")


if __name__ == "__main__":
    main()

"""Dice, per ogni persona, se il suo telefono e' raggiungibile.

**Perche' serve.** Quando una notifica non arriva ci sono cinque motivi
possibili e da fuori si assomigliano tutti: l'app non ha chiesto il permesso, il
permesso e' stato negato, Apple non ha dato l'indirizzo, l'indirizzo c'e' ma e'
morto, oppure la notifica non e' proprio mai partita. Indovinare costa un
pomeriggio; questo elenco li distingue in dieci secondi.

`pushStatus` lo scrive l'app stessa a ogni tentativo di registrazione — vedi
`PushRegistry._annota`. E' una diagnosi, non un dato del prodotto: nessuna
schermata lo mostra.

Uso:

    python tool/diagnosi_notifiche.py
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


def chiama(url, permesso):
    richiesta = urllib.request.Request(url)
    richiesta.add_header("Authorization", "Bearer " + permesso)

    try:
        with urllib.request.urlopen(richiesta) as risposta:
            return json.loads(risposta.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as errore:
        raise RuntimeError("%s -> %s %s" % (url, errore.code, errore.read()[:300]))


def valore(campo):
    if campo is None:
        return ""

    for chiave in ("stringValue", "timestampValue", "integerValue"):
        if chiave in campo:
            return campo[chiave]

    if "booleanValue" in campo:
        return str(campo["booleanValue"])

    return ""


def main():
    permesso = token()
    persone = chiama(BASE + "/users?pageSize=300", permesso).get("documents", [])

    print("%-20s %-30s %-8s %s" % ("CHI", "ESITO", "TELEFONI", "ULTIMO GIRO"))
    print("-" * 88)

    for persona in persone:
        campi = persona.get("fields", {})
        nome = persona["name"]
        chiave = nome.rsplit("/", 1)[1]

        dispositivi = chiama(
            "https://firestore.googleapis.com/v1/%s/devices?pageSize=20" % nome,
            permesso,
        ).get("documents", [])

        print(
            "%-20s %-30s %-8d %s"
            % (
                valore(campi.get("username")) or chiave[:18],
                valore(campi.get("pushStatus")) or "— mai provato —",
                len(dispositivi),
                (valore(campi.get("pushStatusAt")) or "")[:19],
            )
        )

        for dispositivo in dispositivi:
            fatti = dispositivo.get("fields", {})
            print(
                "                       %s  agg. %s"
                % (
                    valore(fatti.get("platform")),
                    (valore(fatti.get("updatedAt")) or "")[:19],
                )
            )


if __name__ == "__main__":
    main()

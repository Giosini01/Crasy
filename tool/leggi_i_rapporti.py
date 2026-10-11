"""Legge i rapporti DMARC e li racconta in italiano.

Ogni giorno Google — e presto Microsoft, Yahoo e gli altri — manda a
`register@crasyapp.com` un rapporto su tutte le email uscite a nome di
crasyapp.com: da quale indirizzo, con quale firma, e cosa ne hanno fatto.

Dentro c'e' un XML compresso, che a occhio non si legge. Questo strumento lo
apre e dice le due cose che contano:

- **le nostre email passano?** Se un canale comincia a fallire — una chiave
  scaduta, un record cambiato per sbaglio — qui si vede prima che qualcuno si
  lamenti che non gli arriva niente;
- **qualcuno si spaccia per noi?** Email firmate male da indirizzi che non
  conosciamo sono qualcuno che usa il nostro nome per mandare truffe. Con un
  dominio nuovo succede poco; succede appena il nome comincia a valere.

Uso:

    python tool/leggi_i_rapporti.py rapporto.xml.gz
    python tool/leggi_i_rapporti.py *.zip
    python tool/leggi_i_rapporti.py cartella-dei-rapporti/
"""

import glob
import gzip
import io
import os
import sys
import xml.etree.ElementTree as ET
import zipfile

# Gli indirizzi da cui esce la nostra posta, per dire "questo siamo noi"
# invece di un numero che non significa niente.
NOSTRI = {
    "amazonses": "Resend (le email dell'app)",
    "ionos": "IONOS (la casella)",
    "kundenserver": "IONOS (la casella)",
    "united-internet": "IONOS (la casella)",
    "google": "Firebase (la rete di sicurezza)",
}


def apri(percorso):
    """Il contenuto XML, qualunque sia l'involucro."""
    if percorso.endswith(".gz"):
        with gzip.open(percorso, "rb") as file:
            return file.read()

    if percorso.endswith(".zip"):
        with zipfile.ZipFile(percorso) as archivio:
            dentro = archivio.namelist()[0]

            return archivio.read(dentro)

    with io.open(percorso, "rb") as file:
        return file.read()


def chi(indirizzo, nomi):
    """Da un indirizzo IP a un nome che si capisce."""
    testo = (nomi or "").lower()

    for pezzo, nome in NOSTRI.items():
        if pezzo in testo:
            return nome

    return "SCONOSCIUTO"


def leggi(percorso):
    radice = ET.fromstring(apri(percorso))
    meta = radice.find("report_metadata")
    da = meta.findtext("org_name", "?")
    policy = radice.find("policy_published")

    print("=" * 62)
    print("rapporto di %s   politica dichiarata: p=%s"
          % (da, policy.findtext("p", "?") if policy is not None else "?"))

    righe = []
    buone = 0
    cattive = 0

    for record in radice.findall("record"):
        fila = record.find("row")
        ip = fila.findtext("source_ip", "?")
        quante = int(fila.findtext("count", "0"))
        esito = fila.find("policy_evaluated")
        spf = esito.findtext("spf", "?")
        dkim = esito.findtext("dkim", "?")

        nomi = ""

        for auth in record.findall(".//dkim/domain") + record.findall(".//spf/domain"):
            nomi += " " + (auth.text or "")

        identificato = chi(ip, nomi)
        passa = spf == "pass" or dkim == "pass"

        if passa:
            buone += quante
        else:
            cattive += quante

        righe.append((quante, ip, identificato, spf, dkim, passa))

    righe.sort(reverse=True)

    print("%-7s %-17s %-32s %s" % ("QUANTE", "DA DOVE", "CHI E'", "ESITO"))

    for quante, ip, identificato, spf, dkim, passa in righe:
        print("%-7d %-17s %-32s %s (spf %s, dkim %s)"
              % (quante, ip, identificato,
                 "passa" if passa else "NON PASSA", spf, dkim))

    print()
    print("  email che passano i controlli : %d" % buone)
    print("  email che NON passano         : %d" % cattive)

    if cattive:
        print()
        print("  ATTENZIONE: quelle che non passano sono email mandate a nome")
        print("  di crasyapp.com senza una firma valida. Se vengono da un")
        print("  indirizzo SCONOSCIUTO, qualcuno sta usando il nostro nome.")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    percorsi = []

    for argomento in sys.argv[1:]:
        if os.path.isdir(argomento):
            percorsi += sorted(glob.glob(os.path.join(argomento, "*")))
        else:
            percorsi += sorted(glob.glob(argomento)) or [argomento]

    for percorso in percorsi:
        try:
            leggi(percorso)
        except Exception as guaio:
            print("non riesco a leggere %s: %s" % (percorso, guaio))


if __name__ == "__main__":
    main()

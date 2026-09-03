"""Legge i testi legali dal file dell'app.

**Sta a parte, e senza espressioni regolari.** Il file Dart e' pieno di apici,
apostrofi protetti dalla barra e blocchi fra tre apici: scriverne il modello con
un'espressione regolare significa scrivere una riga in cui ogni carattere e'
protetto due volte, che nessuno rilegge piu' e che si rompe alla prima virgola
spostata. Qui si scorre il testo e basta — piu' righe, e si capisce cosa fanno.
"""

import io

APICE = chr(39)
TRIPLO = APICE * 3
BARRA = chr(92)


def _stringaDopo(testo, da):
    """La prossima stringa fra apici singoli, a partire da `da`.

    Torna il contenuto gia' ripulito e la posizione subito dopo la chiusura.
    Gli apostrofi protetti dalla barra non chiudono niente: sono proprio quelli
    che rompevano il modello di prima.
    """

    inizio = testo.index(APICE, da) + 1
    fuori = []
    i = inizio

    while i < len(testo):
        c = testo[i]

        if c == BARRA and i + 1 < len(testo):
            prossimo = testo[i + 1]
            fuori.append(chr(10) if prossimo == 'n' else prossimo)
            i += 2

            continue

        if c == APICE:
            return ''.join(fuori), i + 1

        fuori.append(c)
        i += 1

    raise ValueError('stringa mai chiusa')


def costante(testo, nome):
    """Il valore di una `static const String`, anche spezzata su piu' righe."""

    da = testo.index('static const String ' + nome + ' =')
    fine = testo.index(';', da)
    pezzi = []
    i = da + len('static const String ' + nome + ' =')

    while True:
        prossimo = testo.find(APICE, i)

        if prossimo == -1 or prossimo > fine:
            break

        valore, i = _stringaDopo(testo, i)
        pezzi.append(valore)

    return ''.join(pezzi)


def documento(testo, nome):
    """Titolo e corpo di un `LegalDocument`."""

    da = testo.index('static const ' + nome + ' = LegalDocument(')
    titolo, dopo = _stringaDopo(testo, testo.index('title:', da))
    apertura = testo.index(TRIPLO, dopo) + 3
    chiusura = testo.index(TRIPLO, apertura)

    return titolo, testo[apertura:chiusura]


def tutti(percorso):
    """I tre documenti, con le sostituzioni gia' fatte."""

    testo = io.open(percorso, encoding='utf-8').read()
    avviso = costante(testo, 'draftWarning')
    titolare = costante(testo, 'controller')
    versione = costante(testo, 'version')

    fuori = {}

    for nome in ('terms', 'privacy', 'contentLicense'):
        titolo, corpo = documento(testo, nome)
        # Dentro il file sono interpolazioni Dart: qui vanno sostituite a mano.
        corpo = corpo.replace('$draftWarning', avviso)
        corpo = corpo.replace('$controller', titolare)
        fuori[nome] = (titolo, corpo.strip())

    return fuori, versione

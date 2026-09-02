"""Fabbrica il suono che fa CRASY quando arriva una notifica.

**Perche' non un file scaricato.** Un suono preso in giro e' di qualcun altro:
o si paga una licenza, o prima o poi arriva la richiesta di toglierlo. Questo
nasce qui, da una manciata di numeri, e si rifa' diverso in dieci secondi
cambiando le note.

**Com'e' fatto: un "pop" e una scaletta che sale.**

Il primo pezzo e' uno schiocco — una frequenza che precipita da novecento a
duecento hertz in quaranta millesimi. E' il suono di una bolla che scoppia, e
serve a far girare la testa: una notifica che comincia con una nota comincia
gia' a meta', perche' i primi cinquanta millesimi il cervello li usa per capire
che sta arrivando qualcosa.

Poi quattro note che salgono, suonate con un'onda quadra addolcita — il timbro
dei videogiochi, quello che si sente quando si raccoglie una moneta. L'ultima
si tira su di un tono mentre suona. **E' questo il pezzo sfizioso**: una nota
che sale mentre la ascolti dice *e' andata bene*, e lo dice senza parole.

Sotto c'e' una marimba che raddoppia la prima e l'ultima nota. Da sola l'onda
quadra e' un giocattolo di plastica; con un po' di legno sotto diventa uno
strumento.

Mezzo secondo e' una scelta: una notifica si sente mentre si sta facendo altro,
e un suono che dura piu' di un respiro smette di essere un avviso e diventa
un'interruzione. Quello di iOS dura 0,4 secondi.

Uso:

    python tool/suono_della_notifica.py

Riscrive `ios/Runner/crasy.wav` e la copia dentro le risorse di Android. Su
iPhone il file deve stare nel pacchetto dell'app, non sul server: il suono lo
sceglie il telefono leggendo il nome che gli arriva nella notifica, e se quel
nome non corrisponde a niente suona quello di sistema — senza dirlo a nessuno.
"""

import math
import os
import shutil
import struct
import wave

CAMPIONI = 44100
DURATA = 0.62

# Do, Mi, Sol, Do: la scaletta che sale. Non e' un accordo scelto a caso — e'
# il maggiore, che in musica vuol dire "e' successa una cosa bella".
SCALETTA = [1046.50, 1318.51, 1567.98, 2093.00]

# Quando entra ciascuna nota e quanto dura. Settanta millesimi l'una: sotto i
# cinquanta diventa un trillo unico, sopra i cento si sente la fila.
PASSO = 0.075
INIZIO_SCALETTA = 0.055

# L'ultima si tira su di un tono mentre suona.
BENDA = 2 ** (2 / 12)


def schiocco(dentro):
    """Il "pop" iniziale: una frequenza che precipita."""

    quanti = int(0.045 * CAMPIONI)
    fase = 0.0

    for i in range(quanti):
        t = i / CAMPIONI
        # Da 900 a 200 hertz, in fretta. La discesa e' esponenziale perche'
        # l'orecchio sente le altezze in proporzione, non in differenza: una
        # discesa lineare si sentirebbe tutta schiacciata alla fine.
        frequenza = 900 * math.exp(-t / 0.018) + 200
        fase += 2 * math.pi * frequenza / CAMPIONI
        dentro[i] += 0.85 * math.sin(fase) * math.exp(-t / 0.016)


def quadra(frequenza, t):
    """Un'onda quadra addolcita: solo le prime armoniche dispari.

    Quella vera ne ha infinite e frigge. Fermandosi alla nona resta il timbro
    da videogioco senza il fischio che fa stringere i denti.
    """

    valore = 0.0

    for n in (1, 3, 5, 7, 9):
        valore += math.sin(2 * math.pi * frequenza * n * t) / n

    return valore


def nota(frequenza, ritardo, dentro, ultima=False):
    inizio = int(ritardo * CAMPIONI)
    coda = 0.20 if ultima else 0.055
    fase = 0.0

    for i in range(inizio, len(dentro)):
        t = (i - inizio) / CAMPIONI
        # L'ultima sale di un tono nei primi ottanta millesimi e poi resta li'.
        tira = BENDA ** min(1.0, t / 0.08) if ultima else 1.0
        fase += 2 * math.pi * frequenza * tira / CAMPIONI
        salita = min(1.0, t / 0.003)
        valore = 0.0

        for n in (1, 3, 5, 7, 9):
            valore += math.sin(fase * n) / n

        dentro[i] += 0.45 * valore * salita * math.exp(-t / coda)


def marimba(frequenza, ritardo, dentro):
    """Il legno sotto: da sola l'onda quadra e' un giocattolo di plastica."""

    inizio = int(ritardo * CAMPIONI)

    for i in range(inizio, len(dentro)):
        t = (i - inizio) / CAMPIONI
        valore = (
            math.sin(2 * math.pi * frequenza * t)
            + 0.25 * math.sin(2 * math.pi * frequenza * 2 * t)
            + 0.08 * math.sin(2 * math.pi * frequenza * 4.62 * t)
        )
        dentro[i] += 0.55 * valore * min(1.0, t / 0.004) * math.exp(-t / 0.12)


def main():
    quanti = int(DURATA * CAMPIONI)
    campo = [0.0] * quanti

    schiocco(campo)

    for indice, frequenza in enumerate(SCALETTA):
        quando = INIZIO_SCALETTA + indice * PASSO
        ultima = indice == len(SCALETTA) - 1
        nota(frequenza, quando, campo, ultima=ultima)

        if indice == 0 or ultima:
            marimba(frequenza / 2, quando, campo)

    # Si normalizza al 90 per cento: sopra, i campioni si tagliano e il taglio
    # si sente come una crepa.
    piu_forte = max(abs(valore) for valore in campo) or 1.0
    guadagno = 0.9 / piu_forte

    # Gli ultimi cinque millesimi scendono a zero: un file che finisce mentre
    # l'onda e' ancora alta fa un colpo secco in coda.
    fine = int(0.005 * CAMPIONI)
    dati = bytearray()

    for i, valore in enumerate(campo):
        chiusura = min(1.0, (quanti - i) / fine)
        campione = max(-1.0, min(1.0, valore * guadagno * chiusura))
        dati += struct.pack('<h', int(campione * 32767))

    percorso = os.path.join('ios', 'Runner', 'crasy.wav')

    with wave.open(percorso, 'wb') as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(CAMPIONI)
        file.writeframes(bytes(dati))

    # Android lo vuole fra le proprie risorse, con lo stesso nome.
    android = os.path.join('android', 'app', 'src', 'main', 'res', 'raw', 'crasy.wav')
    shutil.copyfile(percorso, android)

    print('%s — %.2f s, %d byte' % (percorso, DURATA, os.path.getsize(percorso)))
    print('%s — copiato' % android)


if __name__ == '__main__':
    main()

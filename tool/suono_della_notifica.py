"""Fabbrica il suono che fa CRASY quando arriva una notifica.

**Perche' non un file scaricato.** Un suono preso in giro e' di qualcun altro:
o si paga una licenza, o prima o poi arriva la richiesta di toglierlo. Questo
invece nasce qui, da tre numeri, e si puo' rifare diverso in dieci secondi
cambiando le note.

**Com'e' fatto.** Tre note che salgono — un accordo maggiore spezzato, quello
che in musica vuol dire *e' successa una cosa bella* — suonate come una
marimba: attacco secco, coda corta. Mezzo secondo in tutto.

Mezzo secondo e' una scelta, non un caso: una notifica si sente mentre si sta
facendo altro, e un suono che dura piu' di un respiro smette di essere un
avviso e diventa un'interruzione. Quello di iOS dura 0,4 secondi.

Uso:

    python tool/suono_della_notifica.py

Riscrive `ios/Runner/crasy.wav`. Su iPhone il file deve stare dentro il
pacchetto dell'app, non sul server: il suono lo sceglie il telefono leggendo il
nome che gli arriva nella notifica, e se quel nome non corrisponde a niente
suona quello di sistema — senza dire niente a nessuno.
"""

import io
import math
import os
import struct
import wave

CAMPIONI = 44100

# Sol, Do, Mi: un Do maggiore che sale. Le tre note entrano a distanza di
# novanta millesimi, abbastanza da sentirle separate e poco da sentirle come
# una cosa sola.
NOTE = [(783.99, 0.00), (1046.50, 0.09), (1318.51, 0.18)]

DURATA = 0.55

# Quanto ci mette una nota a spegnersi. Corto: e' quello che distingue una
# marimba da un organo, e un avviso da un allarme.
CODA = 0.13

# I primi armonici. Senza, una nota sola e' un fischio da apparecchio medico;
# con questi diventa uno strumento.
ARMONICI = [(1.0, 1.00), (2.0, 0.28), (3.0, 0.11), (4.62, 0.06)]

ATTACCO = 0.004


def nota(frequenza, ritardo, dentro):
    """Somma una nota dentro il campo `dentro`, a partire da `ritardo`."""

    inizio = int(ritardo * CAMPIONI)

    for i in range(inizio, len(dentro)):
        t = (i - inizio) / CAMPIONI
        # L'attacco non e' istantaneo: un suono che parte di colpo fa "toc"
        # prima di fare la nota, ed e' quel "toc" che si sente come un difetto.
        salita = min(1.0, t / ATTACCO)
        spegnimento = math.exp(-t / CODA)
        valore = 0.0

        for moltiplicatore, peso in ARMONICI:
            valore += peso * math.sin(2 * math.pi * frequenza * moltiplicatore * t)

        dentro[i] += valore * salita * spegnimento


def main():
    quanti = int(DURATA * CAMPIONI)
    campo = [0.0] * quanti

    for frequenza, ritardo in NOTE:
        nota(frequenza, ritardo, campo)

    # Si normalizza al 90 per cento del massimo: sopra, i campioni si tagliano
    # e il taglio si sente come una crepa.
    piu_forte = max(abs(valore) for valore in campo) or 1.0
    guadagno = 0.9 / piu_forte

    # Gli ultimi cinque millesimi scendono a zero. Un file che finisce mentre
    # l'onda e' ancora alta fa un colpo secco in coda.
    fine = int(0.005 * CAMPIONI)

    dati = bytearray()

    for i, valore in enumerate(campo):
        chiusura = min(1.0, (quanti - i) / fine)
        dati += struct.pack('<h', int(max(-1.0, min(1.0, valore * guadagno * chiusura)) * 32767))

    percorso = os.path.join('ios', 'Runner', 'crasy.wav')

    with wave.open(percorso, 'wb') as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(CAMPIONI)
        file.writeframes(bytes(dati))

    print('%s — %.2f s, %d byte' % (percorso, DURATA, os.path.getsize(percorso)))


if __name__ == '__main__':
    main()

"""Fabbrica il suono che fa CRASY quando arriva una notifica.

**Perche' non un file scaricato.** Un suono preso in giro e' di qualcun altro:
o si paga una licenza, o prima o poi arriva la richiesta di toglierlo. Questo
nasce qui, da una manciata di numeri, e si rifa' diverso in dieci secondi
cambiando le note.

## Cosa lo fa sembrare vero

La versione di prima era un'onda quadra: il timbro dei videogiochi. Carina per
dieci volte, e poi si sente che e' finta — perche' **nessuna cosa vera al mondo
fa quel suono**.

Un suono suonato da qualcosa di reale ha tre cose che una nota sintetizzata non
ha, e ci sono tutte e tre qui dentro:

1. **Un colpo prima della nota.** Il legno che tocca la lamella, il martelletto
   sulla corda: qualche millesimo di rumore, prima che l'altezza si senta. E' la
   cosa che il cervello usa per capire *che cos'e'* che sta suonando, e senza si
   riconosce subito un computer.

2. **Armoniche stonate, che si spengono prima.** Su una corda vera le armoniche
   non stanno esattamente al doppio e al triplo: sono un filo piu' su, e muoiono
   molto prima della nota fondamentale. E' per questo che un pianoforte comincia
   brillante e finisce scuro. Una somma di seni perfetti resta uguale a se stessa
   dal primo all'ultimo istante, ed e' quello a suonare di plastica.

3. **Una stanza intorno.** Nessun suono, in natura, arriva senza il muro dietro
   che lo rimanda indietro. Un filo di riverbero non si sente come riverbero: si
   sente come *dove* sta la cosa che suona. Toglierlo lascia una nota sospesa nel
   vuoto, ed e' esattamente il suono di un file.

## Perche' queste note e non altre

Quattro note, un'ottava piu' su di dove stavano prima: **Do, Mi, Sol, Do**.

La nota che fa la differenza e' la seconda. Do-Sol-Do e' una quinta e un'ottava:
l'intervallo delle campane e dei richiami — aperto, serio, un po' solenne.
Infilando il **Mi** in mezzo l'accordo diventa maggiore, ed e' quello, e solo
quello, che in musica occidentale suona come una cosa bella che e' appena
successa. Non e' un'opinione sui gusti: e' l'intervallo con cui finiscono le
canzoni allegre da quattrocento anni.

L'ottava piu' su serve alla leggerezza. Le note basse hanno un corpo che si
sente addosso; le stesse note piu' in alto le si sente **davanti**, e in mezzo a
una giornata rumorosa passano sopra il rumore invece di combatterci — e' il
motivo per cui i campanelli sono acuti e i tuoni no.

E in coda ci sono due scintille: due note altissime, cortissime, quasi
inudibili da sole. Sono i coriandoli — non si contano, si vedono cadere.

Uso:

    python tool/suono_della_notifica.py

Riscrive `ios/Runner/crasy.wav` e lo copia fra le risorse di Android. Su iPhone
il file deve stare nel pacchetto dell'app, non sul server: il suono lo sceglie
il telefono leggendo il nome che gli arriva nella notifica, e se quel nome non
corrisponde a niente suona quello di sistema — senza dirlo a nessuno.
"""

import math
import os
import random
import shutil
import struct
import wave

CAMPIONI = 44100
DURATA = 0.80

# Do, Mi, Sol, Do: l'accordo maggiore per intero, e quando entrano.
# Ravvicinate: una fila lenta e' una cerimonia, una veloce e' una festa.
NOTE = [(1046.50, 0.000), (1318.51, 0.070), (1567.98, 0.140), (2093.00, 0.210)]

# I coriandoli: due note altissime, appena accennate, dopo l'ultima.
SCINTILLE = [(2637.02, 0.285, 0.30), (3135.96, 0.330, 0.22)]

# Le armoniche di una lamella vera: **un filo stonate, e sempre piu' corte**.
# (quante volte la fondamentale, quanto forte, quanto ci mette a spegnersi)
ARMONICHE = [
    (1.000, 1.00, 0.32),
    (2.010, 0.22, 0.17),
    # **La stonata che fa il campanello.** Due volte e tre quarti la
    # fondamentale non e' un'armonica di niente: e' il rapporto che hanno le
    # barre di metallo percosse, ed e' quello che distingue un carillon da un
    # organo. Senza, la nota e' pulita e non brilla.
    (2.760, 0.26, 0.13),
    (5.404, 0.10, 0.07),
    (8.930, 0.04, 0.04),
]

# **Mezzo secondo di suono e poi silenzio.** Una coda lunga sta bene su una
# cosa che si ascolta; una notifica si sente mentre si sta facendo altro, e un
# suono che continua a ronzare dopo che si e' capito cos'era diventa la ragione
# per cui uno le spegne.

ATTACCO = 0.003


def colpo(dentro, quando, forza=0.09):
    """Il rumore del legno che tocca, prima che si senta la nota."""

    inizio = int(quando * CAMPIONI)
    quanti = int(0.005 * CAMPIONI)
    caso = random.Random(int(quando * 100000) + 7)
    memoria = 0.0

    for i in range(quanti):
        if inizio + i >= len(dentro):
            break

        t = i / CAMPIONI
        # Un rumore bianco crudo e' un "ps": passato per una media mobile
        # diventa un "toc", che e' il suono di una cosa che ne tocca un'altra.
        memoria = 0.45 * memoria + 0.55 * caso.uniform(-1.0, 1.0)
        dentro[inizio + i] += forza * memoria * math.exp(-t / 0.0016)


def nota(dentro, frequenza, quando, forza=1.0, accorcia=1.0):
    inizio = int(quando * CAMPIONI)

    for i in range(inizio, len(dentro)):
        t = (i - inizio) / CAMPIONI
        valore = 0.0

        for rapporto, peso, coda in ARMONICHE:
            valore += (
                peso
                * math.exp(-t / (coda * accorcia))
                * math.sin(2 * math.pi * frequenza * rapporto * t)
            )

        dentro[i] += forza * valore * min(1.0, t / ATTACCO)


def stanza(secco, ritardo, ritorno):
    """Un muro dietro: quello che suona torna indietro, piu' piano e piu' scuro."""

    passi = int(ritardo * CAMPIONI)
    eco = [0.0] * len(secco)
    scuro = 0.0

    for i in range(len(secco)):
        vecchio = eco[i - passi] if i >= passi else 0.0
        # Le pareti vere si mangiano gli acuti per prime: senza questo, il
        # ritorno e' metallico e si sente come un effetto invece che come un
        # posto.
        scuro = 0.78 * vecchio + 0.22 * scuro
        eco[i] = secco[i] + ritorno * scuro

    return eco


def main():
    quanti = int(DURATA * CAMPIONI)
    secco = [0.0] * quanti

    for frequenza, quando in NOTE:
        colpo(secco, quando)
        nota(secco, frequenza, quando)

    # Le scintille non hanno il colpo di legno: non sono note suonate, sono
    # luccichii. Un attacco percosso le farebbe sentire come una quinta e una
    # sesta nota, e la fila e' finita al Do.
    for frequenza, quando, forza in SCINTILLE:
        nota(secco, frequenza, quando, forza=forza, accorcia=0.45)

    # Tre ritardi diversi e primi fra loro: con uno solo si sentirebbe l'eco
    # battere a tempo, che non e' una stanza — e' un effetto.
    code = [
        stanza(secco, 0.0231, 0.26),
        stanza(secco, 0.0289, 0.23),
        stanza(secco, 0.0331, 0.20),
    ]

    campo = [
        secco[i] + 0.18 * (code[0][i] + code[1][i] + code[2][i]) / 3
        for i in range(quanti)
    ]

    # Si normalizza al 90 per cento: sopra, i campioni si tagliano e il taglio
    # si sente come una crepa.
    piu_forte = max(abs(valore) for valore in campo) or 1.0
    guadagno = 0.9 / piu_forte

    # Gli ultimi venti millesimi scendono a zero: un file che finisce mentre
    # l'onda e' ancora viva fa un colpo secco in coda.
    fine = int(0.02 * CAMPIONI)
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

    android = os.path.join('android', 'app', 'src', 'main', 'res', 'raw', 'crasy.wav')
    shutil.copyfile(percorso, android)

    print('%s — %.2f s, %d byte' % (percorso, DURATA, os.path.getsize(percorso)))
    print('%s — copiato' % android)


if __name__ == '__main__':
    main()

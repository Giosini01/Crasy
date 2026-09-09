"""Fabbrica il suono che faceva CRASY quando si apriva.

**NON E' PIU' IN USO.** La sigla di due secondi c'e' stata ed e' stata tolta: un
suono che parte da solo all'apertura da' fastidio piu' spesso di quanto piaccia
— si apre un'app in fila alla cassa, in ufficio, a letto accanto a chi dorme — e
restava fastidioso anche fatto bene. Lo strumento resta perche' rifare quel
suono e' un comando solo, se un giorno si cambia idea.

**Non e' la suoneria delle notifiche, ed e' un mestiere diverso.** Quella deve
farsi notare mentre uno sta facendo altro: corta, brillante, e finita. Questo si
sente quando l'app e' gia' in mano, con lo schermo davanti agli occhi: non deve
chiamare nessuno, deve **dire chi e'**. E' la cosa che in televisione fanno i
due secondi di sigla prima di un programma.

## Com'e' fatto

Tre pezzi, e seguono la fiamma che si accende sullo schermo.

1. **L'innesco.** Mezzo secondo di soffio che sale — rumore passato per un
   filtro che si apre — come il gas che prende. Non e' una nota: e' il rumore di
   una cosa che sta per succedere, e serve a far arrivare l'accordo su qualcosa
   invece che sul silenzio.

2. **L'accordo che sboccia.** Do, Sol, Do all'ottava, tre note che entrano una
   dietro l'altra in un decimo di secondo l'una dall'altra. Salgono, e salire e'
   la sola cosa che un suono puo' fare per significare che qualcosa comincia.

3. **La coda.** Una nota bassa lunga sotto, che tiene, e la stanza attorno. E'
   quella che fa finire il suono invece di troncarlo.

Due secondi e due decimi in tutto: esattamente quanto resta il sipario. Un suono
che continua dopo che l'immagine e' sparita si sente come un errore.

## Perche' non un file scaricato

Un suono preso in giro e' di qualcun altro: o si paga una licenza, o prima o poi
arriva la richiesta di toglierlo. Questo nasce qui, da una manciata di numeri, e
si rifa' diverso in dieci secondi cambiando le note.

Uso:

    python tool/suono_di_apertura.py

Scrive `assets/audio/apertura.wav`.
"""

import array
import math
import os
import random
import wave

CAMPIONI = 44100
DURATA = 2.20

# Do, Sol, Do: la quinta e l'ottava, e non l'accordo maggiore intero.
# **Senza la terza.** Un accordo maggiore pieno e' allegro, e allegro non e'
# quello che CRASY vuole dire: quinta e ottava sono la cosa piu' vicina a uno
# squillo che esista in musica — aperti, larghi, e senza un'emozione addosso.
NOTE = [
    (261.63, 0.42, 0.55),   # Do basso: il corpo
    (392.00, 0.50, 0.45),   # Sol
    (523.25, 0.58, 0.60),   # Do all'ottava: la punta
]

# Le armoniche: le stesse del suono di notifica, perche' e' lo stesso strumento.
# Un filo stonate e sempre piu' corte — e' quello che distingue una cosa
# percossa da una somma di seni.
ARMONICHE = [
    (1.000, 1.00, 0.90),
    (2.008, 0.30, 0.52),
    (2.760, 0.14, 0.30),
    (4.020, 0.08, 0.20),
    (5.404, 0.04, 0.12),
]

ATTACCO = 0.004

# Quando comincia il soffio e quanto dura.
INNESCO_DA = 0.02
INNESCO_A = 0.56


def innesco(dentro):
    """Il soffio che sale: il gas che prende, prima che ci sia una fiamma.

    E' rumore, non una nota, e passa per un filtro che **si apre** man mano: al
    principio si sente solo il basso — un fruscio sordo — e verso la fine ci
    sono anche gli acuti. Un filtro che si apre e' il modo in cui il cervello
    riconosce che qualcosa sta arrivando, ed e' il motivo per cui questo mezzo
    secondo non si sente come rumore ma come attesa.
    """

    da = int(INNESCO_DA * CAMPIONI)
    a = int(INNESCO_A * CAMPIONI)
    caso = random.Random(11)
    memoria = 0.0

    for i in range(da, min(a, len(dentro))):
        avanti = (i - da) / max(1, a - da)

        # Il filtro si apre: da 0,06 (molto chiuso, solo basse) a 0,55.
        apertura = 0.06 + 0.49 * avanti
        memoria = (1 - apertura) * memoria + apertura * caso.uniform(-1.0, 1.0)

        # E il volume sale e poi si ritira, cosi' il soffio lascia il posto
        # all'accordo invece di sovrapporsi.
        forza = 0.16 * math.sin(math.pi * avanti) ** 1.4

        dentro[i] += forza * memoria


def colpo(dentro, quando, forza=0.07):
    """Il rumore di una cosa che ne tocca un'altra, prima che si senta la nota."""

    inizio = int(quando * CAMPIONI)
    quanti = int(0.006 * CAMPIONI)
    caso = random.Random(int(quando * 100000) + 3)
    memoria = 0.0

    for i in range(quanti):
        if inizio + i >= len(dentro):
            break

        t = i / CAMPIONI
        memoria = 0.45 * memoria + 0.55 * caso.uniform(-1.0, 1.0)
        dentro[inizio + i] += forza * memoria * math.exp(-t / 0.0018)


def nota(dentro, frequenza, quando, coda):
    inizio = int(quando * CAMPIONI)

    for i in range(inizio, len(dentro)):
        t = (i - inizio) / CAMPIONI
        valore = 0.0

        for rapporto, peso, durata in ARMONICHE:
            valore += (
                peso
                * math.exp(-t / (durata * coda / 0.55))
                * math.sin(2 * math.pi * frequenza * rapporto * t)
            )

        dentro[i] += 0.42 * valore * min(1.0, t / ATTACCO)


def stanza(secco, ritardo, ritorno):
    """Un muro dietro: quello che suona torna indietro, piu' piano e piu' scuro."""

    passi = int(ritardo * CAMPIONI)
    eco = [0.0] * len(secco)
    scuro = 0.0

    for i in range(len(secco)):
        vecchio = eco[i - passi] if i >= passi else 0.0
        scuro = 0.78 * vecchio + 0.22 * scuro
        eco[i] = secco[i] + ritorno * scuro

    return eco


def main():
    quanti = int(DURATA * CAMPIONI)
    onda = [0.0] * quanti

    innesco(onda)

    for frequenza, quando, coda in NOTE:
        colpo(onda, quando)
        nota(onda, frequenza, quando, coda)

    # Una stanza piccola: quaranta millesimi di ritardo. Piu' lunga sarebbe una
    # chiesa, e una sigla di due secondi in una chiesa suona lenta.
    onda = stanza(onda, 0.040, 0.20)

    # **La fine si spegne a mano.** Senza, l'ultimo campione taglia la coda di
    # netto e si sente un "toc" alla fine — il difetto piu' comune dei suoni
    # fatti in casa.
    spegnimento = int(0.22 * CAMPIONI)

    for i in range(quanti - spegnimento, quanti):
        onda[i] *= (quanti - i) / spegnimento

    picco = max(abs(v) for v in onda) or 1.0
    # Novanta per cento e non cento: un margine, cosi' nessun apparecchio lo
    # trova gia' al limite e ci mette la sua distorsione.
    scala = 0.90 / picco

    dati = array.array('h', (int(max(-1.0, min(1.0, v * scala)) * 32767) for v in onda))

    cartella = os.path.join('assets', 'audio')
    os.makedirs(cartella, exist_ok=True)
    percorso = os.path.join(cartella, 'apertura.wav')

    with wave.open(percorso, 'wb') as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(CAMPIONI)
        file.writeframes(dati.tobytes())

    print('scritto %s (%.1f KB, %.2f secondi)' % (
        percorso, os.path.getsize(percorso) / 1024, DURATA,
    ))


if __name__ == '__main__':
    main()

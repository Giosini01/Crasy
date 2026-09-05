"""Mette gli accenti veri nelle scritte che l'app mostra.

**Solo dentro le stringhe, mai nei commenti.** E' una distinzione che non
richiede di capire il Dart, e il motivo e' una particolarita' della lingua: in
una stringa fra apici singoli — che e' come sono scritte quasi tutte le scritte
di CRASY — un apostrofo va protetto con la barra rovesciata, `e{BARRA}'`. Nei
commenti no: li' si scrive `e'` e basta.

Quindi cercare **la barra piu' l'apostrofo** trova le scritte e lascia stare i
commenti, senza dover distinguere le une dagli altri. I commenti restano in puro
ASCII, che e' la convenzione del progetto e serve a non ritrovarsi un sorgente
storto perche' qualcuno l'ha aperto con la codifica sbagliata.

Le stesse parole del sito: la tabella sta in `tool/accenti.py` e si tocca in un
posto solo.

Uso:

    python tool/accenti_nellapp.py          # dice quante ne cambierebbe
    python tool/accenti_nellapp.py --vai    # le cambia
"""

import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import accenti

DOVE = 'lib'
BARRA = chr(92)

# **L'informativa non si tocca da qui.** Quel testo lo legge anche il sito, che
# ci mette gli accenti per conto suo al momento di stampare la pagina: se li
# avesse gia' dentro non cambierebbe niente, ma il giorno che arriva il testo
# dell'avvocato si sostituisce un file intero — e un file che nel frattempo
# qualcuno ha ritoccato e' un file su cui bisogna stare attenti.
SALTA = {os.path.join('lib', 'core', 'legal', 'legal_documents.dart')}


def main():
    prova = '--vai' not in sys.argv
    toccati = 0
    cambi = 0

    for cartella, _, file in os.walk(DOVE):
        for nome in file:
            if not nome.endswith('.dart'):
                continue

            percorso = os.path.join(cartella, nome)

            if percorso in SALTA:
                continue

            prima = io.open(percorso, encoding='utf-8').read()
            dopo = accenti.metti_con(prima, BARRA + "'")

            if dopo == prima:
                continue

            quante = sum(
                1
                for a, b in zip(prima.split(BARRA + "'"), dopo.split(BARRA + "'"))
                if a != b
            )
            toccati += 1
            cambi += prima.count(BARRA + "'") - dopo.count(BARRA + "'")
            print('%-64s %d' % (percorso, prima.count(BARRA + "'") - dopo.count(BARRA + "'")))

            if not prova:
                io.open(percorso, 'w', encoding='utf-8', newline='').write(dopo)

    print('\nfile: %d   parole accentate: %d' % (toccati, cambi))

    if prova:
        print('(aggiungi --vai per cambiarle davvero)')


if __name__ == '__main__':
    main()

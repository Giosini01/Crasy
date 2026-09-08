"""Mette la vetrina alla radice e sposta l'app dentro `/app`.

**Perche' serve uno scambio e non una riga di configurazione.** Firebase Hosting
decide cosa servire in un ordine preciso: prima i file veri, poi le regole di
riscrittura. `flutter build web` scrive il proprio `index.html` alla radice —
quindi quel file **vince sempre**, e qualunque regola che dica "alla radice
mostra la vetrina" non verrebbe nemmeno guardata.

L'unico modo perche' la radice sia la vetrina e' che alla radice ci sia
davvero la vetrina. Qui si scambiano i due file dopo la compilazione:

    build/web/index.html      -> build/web/app/index.html    (l'app)
    web/benvenuto/index.html  -> build/web/index.html        (la vetrina)

**L'app resta raggiungibile e deve restarlo**, anche se il sito non la mostra
piu': la pagina che conferma l'indirizzo email e' una schermata dell'app, e i
link dentro i messaggi ci passano. Senza `/app` quei link non porterebbero da
nessuna parte.

E' idempotente: riconosce l'`index.html` di Flutter da `flutter_bootstrap.js`,
quindi rilanciarlo due volte non fa danni.

Gira da solo prima di ogni `firebase deploy` — vedi `predeploy` in
`firebase.json` — perche' `build/` non sta nel repository e va rifatto ogni
volta. Un passaggio manuale che si puo' dimenticare e' un passaggio che prima o
poi si dimentica, e il giorno che si dimentica il sito mostra l'app a chi
cercava la vetrina.
"""

import io
import os
import shutil

RADICE = os.path.join('build', 'web', 'index.html')
APP = os.path.join('build', 'web', 'app', 'index.html')
VETRINA = os.path.join('web', 'benvenuto', 'index.html')

# La firma dell'`index.html` di Flutter: nessun'altra pagina nostra ce l'ha.
FIRMA = 'flutter_bootstrap.js'


def main():
    if not os.path.exists(RADICE):
        print('niente da fare: %s non esiste' % RADICE)

        return

    testo = io.open(RADICE, encoding='utf-8').read()

    if FIRMA in testo:
        os.makedirs(os.path.dirname(APP), exist_ok=True)
        shutil.copyfile(RADICE, APP)
        print('app  -> %s' % APP)
    else:
        print('app  -> gia spostata')

    shutil.copyfile(VETRINA, RADICE)
    print('vetrina -> %s' % RADICE)

    # **I due file che dicono ad Apple e Google che `/foto` apre l'app.**
    #
    # Copiati a mano invece di lasciarli alla compilazione: stanno in una
    # cartella che comincia col punto, e le cartelle col punto davanti sono
    # esattamente il tipo di cosa che gli strumenti saltano senza dirlo. Se qui
    # non arrivano, i link condivisi tornano ad aprire il browser — e nessun
    # errore lo segnala da nessuna parte.
    permessi = os.path.join('web', '.well-known')
    dove = os.path.join('build', 'web', '.well-known')

    if os.path.isdir(permessi):
        os.makedirs(dove, exist_ok=True)

        for nome in os.listdir(permessi):
            shutil.copyfile(
                os.path.join(permessi, nome), os.path.join(dove, nome)
            )
            print('permesso -> %s' % os.path.join(dove, nome))


if __name__ == '__main__':
    main()

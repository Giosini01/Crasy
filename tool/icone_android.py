"""Fabbrica le icone di CRASY per Android, partendo da quella di iPhone.

**Erano ancora quelle di Flutter.** Le cinque misure dentro `android/app/src/
main/res/mipmap-*` combaciavano byte per byte con il modello: il gabbiano
azzurro. Su iPhone l'icona vera c'era gia' da mesi.

## Perche' dall'icona di iPhone

Perche' cosi' non possono divergere. Un'icona ridisegnata a parte diventa
"quasi uguale" al primo ritocco, e due icone quasi uguali sono peggio di due
diverse: nessuno le nota, e intanto l'app ha due facce.

## Due icone, non una

Android ne vuole due, e chi ne mette una sola si riconosce a colpo d'occhio.

1. **Quella quadrata** (`ic_launcher.png`), per i telefoni fino ad Android 7.
2. **Quella adattiva**, da Android 8 in poi: uno sfondo e una figura su due
   livelli separati, che il sistema ritaglia nella forma che vuole — tondo,
   quadrato con gli angoli, goccia. Senza, il sistema prende quella quadrata e
   la mette **dentro un cerchietto bianco** con un bordo grigio: e' il modo in
   cui si riconosce un'app fatta di fretta.

## La zona sicura

Nell'icona adattiva la figura sta su una tela di 108 unita', ma il sistema
**puo' ritagliare fino a 18 unita' per lato**: quello che deve restare visibile
sta nel tondo centrale da 66. Percio' la fiamma qui dentro occupa meno spazio
che nell'icona quadrata — non e' un errore di misura, e' il margine che
impedisce che le venga tagliata la punta su un telefono che usa il tondo.

## E si ricentra

Nell'originale la fiamma sta piu' in alto, con piu' bianco sotto che sopra. Su
iPhone non si nota perche' l'icona e' un quadrato pieno; ritagliata in un tondo
diventa evidente. Qui si prende la fiamma da sola — il rettangolo minimo che la
contiene — e si rimette al centro.

Uso:

    python tool/icone_android.py
"""

import io
import os

from PIL import Image

SORGENTE = os.path.join(
    'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset',
    'Icon-App-1024x1024@1x.png',
)

RES = os.path.join('android', 'app', 'src', 'main', 'res')

# Le cinque densita' di Android, e quanto misura l'icona in ognuna.
DENSITA = [
    ('mdpi', 48),
    ('hdpi', 72),
    ('xhdpi', 96),
    ('xxhdpi', 144),
    ('xxxhdpi', 192),
]

# Il lato della tela dell'icona adattiva, per densita' (108 unita' * densita').
ADATTIVA = [
    ('mdpi', 108),
    ('hdpi', 162),
    ('xhdpi', 216),
    ('xxhdpi', 324),
    ('xxxhdpi', 432),
]

# Quanto della larghezza occupa la fiamma.
#
# Nell'icona quadrata sta larga: e' tutta visibile e il bianco intorno e' poco.
# Nell'adattiva sta stretta, perche' il sistema puo' mangiarsi i bordi.
QUANTO_QUADRATA = 0.68
QUANTO_ADATTIVA = 0.52

# Il bianco dell'app. Lo stesso di `AppColors.paper`.
BIANCO = (255, 255, 255, 255)


def laFiamma(immagine):
    """Ritaglia la fiamma dal suo sfondo, e restituisce solo lei.

    **Non si fida della trasparenza.** Il file di iPhone ha il fondo bianco
    pieno, non trasparente — le icone di iPhone non possono essere trasparenti —
    quindi `getbbox()` sull'alfa restituirebbe tutta l'immagine. Qui si cerca il
    primo pixel che **non e' quasi bianco**, che e' il modo di trovare una
    figura su una pagina.
    """

    rgba = immagine.convert('RGBA')
    larghezza, altezza = rgba.size
    pixel = rgba.load()

    sinistra, destra = larghezza, 0
    sopra, sotto = altezza, 0

    for y in range(altezza):
        for x in range(larghezza):
            r, g, b, a = pixel[x, y]

            # Trasparente, o abbastanza bianco da essere sfondo. La soglia e'
            # alta apposta: l'ombra sotto la fiamma e' un grigio chiarissimo, e
            # prenderla dentro allargherebbe il ritaglio di una decina di pixel
            # per niente.
            if a < 24 or (r > 246 and g > 246 and b > 246):
                continue

            sinistra = min(sinistra, x)
            destra = max(destra, x)
            sopra = min(sopra, y)
            sotto = max(sotto, y)

    if destra <= sinistra or sotto <= sopra:
        raise SystemExit('non ho trovato nessuna figura dentro %s' % SORGENTE)

    return rgba.crop((sinistra, sopra, destra + 1, sotto + 1))


def suTela(fiamma, lato, quanto, fondo):
    """La fiamma al centro di una tela quadrata, grande `quanto` del lato."""

    largo = int(lato * quanto)
    alto = max(1, int(fiamma.height * largo / fiamma.width))

    # Se e' piu' alta che larga, comanda l'altezza: altrimenti una fiamma
    # slanciata uscirebbe sopra e sotto.
    if alto > largo:
        alto = largo
        largo = max(1, int(fiamma.width * alto / fiamma.height))

    ridotta = fiamma.resize((largo, alto), Image.LANCZOS)
    tela = Image.new('RGBA', (lato, lato), fondo)
    tela.paste(ridotta, ((lato - largo) // 2, (lato - alto) // 2), ridotta)

    return tela


def scrivi(immagine, cartella, nome):
    os.makedirs(cartella, exist_ok=True)
    percorso = os.path.join(cartella, nome)
    immagine.save(percorso, 'PNG', optimize=True)

    return percorso


def main():
    fiamma = laFiamma(Image.open(SORGENTE))
    print('fiamma ritagliata: %d x %d' % (fiamma.width, fiamma.height))

    for densita, lato in DENSITA:
        cartella = os.path.join(RES, 'mipmap-' + densita)
        scrivi(suTela(fiamma, lato, QUANTO_QUADRATA, BIANCO), cartella, 'ic_launcher.png')

    print('scritte le %d icone quadrate' % len(DENSITA))

    for densita, lato in ADATTIVA:
        cartella = os.path.join(RES, 'mipmap-' + densita)
        trasparente = suTela(fiamma, lato, QUANTO_ADATTIVA, (0, 0, 0, 0))
        scrivi(trasparente, cartella, 'ic_launcher_foreground.png')

    print('scritte le %d figure adattive' % len(ADATTIVA))

    # Il colore di fondo dell'icona adattiva.
    valori = os.path.join(RES, 'values')
    os.makedirs(valori, exist_ok=True)

    with io.open(os.path.join(valori, 'ic_launcher_background.xml'), 'w',
                 encoding='utf-8', newline='\n') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <!-- Il fondo dell\'icona adattiva: lo stesso bianco dell\'app.\n'
            '         La fiamma ci sta sopra su un livello separato, e il sistema\n'
            '         ritaglia i due insieme nella forma che preferisce. -->\n'
            '    <color name="ic_launcher_background">#FFFFFF</color>\n'
            '</resources>\n'
        )

    # E il file che tiene insieme i due livelli.
    anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)

    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )

    for nome in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        with io.open(os.path.join(anydpi, nome), 'w',
                     encoding='utf-8', newline='\n') as f:
            f.write(xml)

    print('scritta l\'icona adattiva')


if __name__ == '__main__':
    main()

"""Mette gli accenti veri nel testo che finisce sul sito.

**Perche' il codice li scrive senza.** Dentro il progetto le parole accentate si
scrivono con l'apostrofo — `e'`, `piu'`, `perche'` — e non e' una svista: e' una
convenzione che tiene i sorgenti in puro ASCII, dove un file non puo' arrivare
storto perche' qualcuno l'ha aperto con la codifica sbagliata. E' successo piu'
di una volta in questo stesso progetto, e ogni volta il danno era invisibile
finche' non lo leggeva un utente.

Sul sito pero' quella convenzione non c'entra niente: **`e'` scritto in una
pagina pubblica e' semplicemente italiano sbagliato**, e su un'informativa o su
una vetrina si nota subito.

Quindi i sorgenti restano come sono e la traduzione avviene qui, nel momento in
cui il testo diventa una pagina. Una fonte sola, e nessuno deve ricordarsi di
scrivere le due versioni.

## Cosa non tocca

**Il codice.** Dentro `<script>` e `<style>` non entra: li' dentro un apostrofo
apre e chiude le stringhe, e una sostituzione fatta alla cieca dentro del
programma e' il modo piu' rapido di rompere una pagina senza accorgersene. Le
parole accentate nei commenti del codice restano com'erano — non le legge
nessuno se non chi apre il sorgente, e chi apre il sorgente sa perche' sono
scritte cosi'.
"""

import re

# Le parole che il progetto scrive con l'apostrofo, e come vanno lette.
#
# **L'ordine conta**: le piu' lunghe prima. Mettendo `e'` in cima, la parola
# `perche'` verrebbe spezzata a meta' — `perch` piu' una `è` — e nessuno se ne
# accorgerebbe fino a leggere la pagina.
PAROLE = [
    ('perche', 'perché'),
    ('poiche', 'poiché'),
    ('finche', 'finché'),
    ('affinche', 'affinché'),
    ('benche', 'benché'),
    ('cosi', 'così'),
    ('piu', 'più'),
    ('puo', 'può'),
    ('gia', 'già'),
    ('sara', 'sarà'),
    ('verra', 'verrà'),
    ('citta', 'città'),
    ('societa', 'società'),
    ('eta', 'età'),
    ('meta', 'metà'),
    ('liberta', 'libertà'),
    ('verita', 'verità'),
    ('novita', 'novità'),
    ('ne', 'né'),
    ('se', 'sé'),
    ('e', 'è'),
]

# Tutte le parole che finiscono in `-ita'` diventano `-ità`: possibilita',
# responsabilita', attivita', identita'... Sono decine e cambiano ogni volta
# che si scrive una riga nuova, quindi si prendono con una regola invece che
# una per una.
ITA = re.compile(r'\b(\w+?)ita(?:\'|&#39;)')


def _unaVolta(testo, apostrofo):
    fuori = ITA.sub(lambda m: m.group(1) + 'ità', testo)

    for parola, accentata in PAROLE:
        # Il confine di parola davanti evita che `che'` dentro `perche'`
        # sopravviva alla prima passata e venga preso dalla seconda.
        fuori = re.sub(
            r'\b' + parola + re.escape(apostrofo),
            accentata,
            fuori,
        )

    return fuori


def metti(testo):
    """Il testo con gli accenti al posto degli apostrofi."""

    return _unaVolta(_unaVolta(testo, "'"), '&#39;')


_BLOCCHI = re.compile(r'(<script\b.*?</script>|<style\b.*?</style>)', re.S | re.I)


def nellaPagina(html):
    """Come [metti], ma lascia stare il codice dentro la pagina."""

    pezzi = _BLOCCHI.split(html)

    return ''.join(
        pezzo if _BLOCCHI.fullmatch(pezzo) else metti(pezzo) for pezzo in pezzi
    )

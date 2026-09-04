"""Fabbrica le pagine pubbliche del sito: privacy, termini, contenuti, supporto,
e la vetrina.

**I testi legali non si riscrivono: si leggono da dove gia' stanno.** Le tre
informative vivono in `lib/core/legal/legal_documents.dart`, sono quelle che
l'app fa accettare, e sono legate a un numero di versione: se cambia una riga
cambia la versione, e l'app richiede il consenso a tutti prima di lasciarli
rientrare.

Copiarle a mano dentro delle pagine web avrebbe creato **due verita'**. Il
giorno che si corregge una riga dell'informativa, il sito resterebbe indietro —
e un'informativa pubblicata diversa da quella accettata non e' un dettaglio
estetico: e' esattamente il tipo di cosa su cui si viene contestati.

Qui il file Dart si legge, si estraggono i tre documenti e si scrivono le
pagine. Una fonte sola, e per aggiornare il sito basta rilanciare questo.

Uso:

    python tool/pagine_del_sito.py
"""

import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import leggi_legale
import vetrina

SORGENTE = os.path.join('lib', 'core', 'legal', 'legal_documents.dart')
DOVE = 'web'

# **La casella a cui si scrive.** Oggi e' quella che esiste; il giorno che
# nasce `supporto@crasyapp.com` si cambia questa riga e si rilancia. Un
# indirizzo di supporto che non risponde e' peggio di nessun indirizzo: chi
# scrive resta ad aspettare senza sapere che sta aspettando invano.
POSTA = 'register@crasyapp.com'

# **Gli indirizzi degli store, vuoti finche' non esistono.**
#
# Vuoto vuol dire "tasto spento, con scritto presto". Il giorno che l'app e'
# pubblicata si incollano qui e si rilancia questo file: i tasti si accendono da
# soli, senza toccare la pagina.
APP_STORE = ''
PLAY_STORE = ''

# Dove sta l'app dentro il sito. Non e' piu' la radice: li' c'e' la vetrina.
APP = '/app/'


def dalDart():
    """I tre documenti, letti da dove gia stanno."""

    return leggi_legale.tutti(SORGENTE)


def alSicuro(testo):
    return (
        testo.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    )


def inParagrafi(corpo):
    """Da testo battuto a mano a paragrafi e titoli.

    **I titoli si riconoscono da soli**: nel file sono scritti tutti in
    maiuscolo, o cominciano con un numero e un punto. Non c'e' nessun segno di
    formattazione da nessuna parte — il testo e' fatto per essere letto dentro
    un foglio che sale dal basso — e riconoscerli qui costa dieci righe e
    lascia il file dell'app pulito.
    """

    pezzi = []

    for blocco in re.split(r'\n\s*\n', corpo):
        righe = [r.strip() for r in blocco.strip().split('\n') if r.strip()]

        if not righe:
            continue

        prima = righe[0]
        titolo = (
            prima == prima.upper() and len(prima) < 70 and any(c.isalpha() for c in prima)
        ) or re.match(r'^\d+\.\s', prima)

        if titolo:
            pezzi.append('<h2>%s</h2>' % alSicuro(prima))
            righe = righe[1:]

        if not righe:
            continue

        # **Gli elenchi restano elenchi.** Una voce comincia con il trattino;
        # le righe dopo, che nel file vanno a capo per non sforare il margine,
        # appartengono alla voce di prima. Senza questa distinzione tutte le
        # voci finivano schiacciate in un paragrafo solo con i trattini in
        # mezzo, che e' il modo piu' rapido di rendere illeggibile un elenco di
        # categorie di dati personali.
        if righe[0].startswith('- '):
            voci = []

            for riga in righe:
                if riga.startswith('- '):
                    voci.append(riga[2:])
                elif voci:
                    voci[-1] += ' ' + riga

            pezzi.append(
                '<ul>%s</ul>'
                % ''.join('<li>%s</li>' % alSicuro(v.strip()) for v in voci)
            )
        else:
            pezzi.append('<p>%s</p>' % alSicuro(' '.join(righe)))

    return '\n'.join(pezzi)


# **La tavolozza e' quella dell'app, non una che le somiglia.**
#
# I valori vengono da `lib/core/theme/app_colors.dart`: il rosso e' `crasyRed`,
# il fondo e' `paper`, le righe sono `line`, il testo e' `ink` e `inkSoft`. Un
# sito con un rosso di mezzo tono diverso da quello del marchio non si nota
# guardandolo da solo — si nota quando lo si mette accanto all'app, ed e' li'
# che sembra la copia di qualcun altro.
STILE = """
:root {
  --rosso: #FA0000; --inchiostro: #0A0A0B; --tenue: #6B6B70;
  --fioco: #A1A1A6; --riga: #E8E8EA; --spento: #F4F4F5;
  color-scheme: light;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0;
  background: #FFFFFF;
  color: var(--inchiostro);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.65;
  -webkit-font-smoothing: antialiased;
}

/* La testata sta ferma in cima mentre si scorre: **un'informativa e' lunga**, e
   a meta' pagina non si sa piu' che cosa si sta leggendo ne' come si torna
   indietro. Il velo sfocato tiene le lettere leggibili sopra il testo che
   passa sotto. */
.cima {
  position: sticky; top: 0; z-index: 10;
  background: #FFFFFF;
  border-bottom: 1px solid var(--riga);
}
.cima__dentro {
  max-width: 720px; margin: 0 auto; padding: 12px 22px;
  display: flex; align-items: center; justify-content: space-between; gap: 16px;
}
.cima img { width: 96px; height: auto; display: block; }
.indietro {
  font-size: 13px; font-weight: 700; color: var(--fioco); text-decoration: none;
  white-space: nowrap;
}
.indietro:hover { color: var(--rosso); }

.foglio { max-width: 720px; margin: 0 auto; padding: 44px 22px 40px; }
h1 {
  font-size: clamp(32px, 6.5vw, 50px);
  line-height: 1.02; letter-spacing: -.03em;
  margin: 0 0 6px; font-weight: 800; text-transform: uppercase;
}
h1 .punto { color: var(--rosso); }

/* Ogni titoletto porta un trattino rosso davanti: dentro un testo lungo e tutto
   della stessa misura, e' il segno che fa ritrovare il punto in cui si era. */
h2 {
  font-size: 12px; letter-spacing: .16em; text-transform: uppercase;
  color: var(--rosso); margin: 40px 0 10px; font-weight: 800;
  display: flex; align-items: center; gap: 10px;
}
h2::before {
  content: ''; width: 18px; height: 2px; background: var(--rosso);
  flex: none; border-radius: 2px;
}
p, li { color: var(--tenue); font-size: 16.5px; margin: 0 0 13px; }
li { margin-bottom: 8px; }
ul { padding-left: 20px; margin: 0 0 14px; }
strong { color: var(--inchiostro); }
a { color: var(--rosso); }
.avviso {
  border: 1px solid var(--riga); border-radius: 14px; padding: 16px 18px;
  background: var(--spento); font-size: 14px; color: var(--tenue); margin-top: 18px;
}
.data {
  font-size: 11px; font-weight: 800; letter-spacing: .14em; color: var(--fioco);
  margin: 0 0 30px; text-transform: uppercase;
}
footer {
  margin-top: 60px; padding: 26px 0 70px;
  border-top: 1px solid var(--riga); font-size: 14px; color: var(--fioco);
}
footer a { margin-right: 18px; text-decoration: none; }
"""

# **Niente versione scura, ed e' la stessa scelta dell'app.** CRASY e' bloccata
# sul chiaro perche' le foto devono cadere sempre sullo stesso fondo e il rosso
# deve avere sempre lo stesso peso: su fondo nero lo stesso rosso urla, su fondo
# bianco chiama. Un sito che si gira da solo quando il telefono e' in tema scuro
# non sarebbe coerente con l'app che sta descrivendo.


def pagina(titolo, sottotitolo, contenuto, descrizione):
    """Il vestito di ogni pagina del sito."""

    return """<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s — CRASY</title>
<meta name="description" content="%s">
<link rel="icon" href="/favicon.png">
<style>%s</style>
</head>
<body>
<div class="cima">
  <div class="cima__dentro">
    <a href="/"><img src="/brand/crasy-wordmark.png" alt="CRASY" width="96"></a>
    <a class="indietro" href="/">&larr; crasyapp.com</a>
  </div>
</div>
<div class="foglio">
  <h1>%s<span class="punto">.</span></h1>
  %s
  %s
  <footer>
    <a href="/">CRASY</a>
    <a href="/termini/">Termini</a>
    <a href="/privacy/">Privacy</a>
    <a href="/contenuti/">Foto e video</a>
    <a href="/supporto/">Supporto</a>
  </footer>
</div>
</body>
</html>
""" % (
        alSicuro(titolo),
        alSicuro(descrizione),
        STILE,
        alSicuro(titolo),
        '<p class="data">%s</p>' % alSicuro(sottotitolo) if sottotitolo else '',
        contenuto,
    )


def scrivi(cartella, html):
    percorso = os.path.join(DOVE, cartella)
    os.makedirs(percorso, exist_ok=True)
    file = os.path.join(percorso, 'index.html')
    io.open(file, 'w', encoding='utf-8', newline='\n').write(html)
    print('%-28s %d byte' % (file, len(html.encode('utf-8'))))


def versione():
    return leggi_legale.tutti(SORGENTE)[1]


def supporto():
    return """
  <p>Scrivici: <a href="mailto:%s">%s</a>. Rispondiamo a tutto, e in fretta —
  siamo in pochi e le email sono poche.</p>

  <h2>Se qualcosa non funziona</h2>
  <p>Raccontaci cosa stavi facendo e cosa e' successo, e se puoi allega una
  fotografia dello schermo. Se compare un riquadro con scritto un errore,
  quella fotografia vale un pomeriggio di indagini: dentro c'e' il nome preciso
  del guasto.</p>

  <h2>Segnalare una foto o una persona</h2>
  <p>Dentro l'app, sotto ogni foto e su ogni profilo c'e' il comando per
  segnalare. Le segnalazioni le leggiamo una per una. Puoi anche bloccare una
  persona: da quel momento non vedrai piu' niente di suo, e lei niente di
  tuo.</p>

  <h2>Cancellare l'account</h2>
  <p>Dal tuo profilo, in fondo alle impostazioni. Si chiude subito e i dati
  vengono cancellati, tranne quelli che siamo obbligati a conservare per legge —
  sono elencati nell'<a href="/privacy/">informativa privacy</a>.</p>

  <h2>I tuoi dati</h2>
  <p>Puoi chiedere di vederli, correggerli, portarteli via o cancellarli.
  Scrivici allo stesso indirizzo: e' un tuo diritto e non serve motivarlo.</p>

  <h2>I premi</h2>
  <p>Il premio di una missione viene versato da chi la lancia prima che
  cominci, e viene accreditato a chi vince alla chiusura. Se qualcosa non
  torna, scrivici: le somme e le date sono tracciate e si controllano.</p>
""" % (POSTA, POSTA)


def main():
    documenti, v = dalDart()
    quando = 'Versione %s' % v

    scrivi(
        'termini',
        pagina(
            documenti['terms'][0],
            quando,
            inParagrafi(documenti['terms'][1]),
            'Le condizioni per usare CRASY: chi puo iscriversi, come si '
            'partecipa, come funzionano i premi.',
        ),
    )
    scrivi(
        'privacy',
        pagina(
            documenti['privacy'][0],
            quando,
            inParagrafi(documenti['privacy'][1]),
            'Quali dati tratta CRASY, perche, per quanto tempo e quali diritti '
            'hai su di essi.',
        ),
    )
    scrivi(
        'contenuti',
        pagina(
            documenti['contentLicense'][0],
            quando,
            inParagrafi(documenti['contentLicense'][1]),
            'Le foto e i video che carichi su CRASY restano tuoi: cosa ci '
            'autorizzi a farne e per quanto.',
        ),
    )
    scrivi(
        'supporto',
        pagina(
            'Supporto',
            '',
            supporto(),
            'Come contattare CRASY, segnalare un contenuto, cancellare '
            'l account.',
        ),
    )
    # La vetrina ha un vestito suo: vedi `tool/vetrina.py`. Un documento si
    # apre per cercare una riga, una vetrina ha dieci secondi per farsi
    # capire da chi non ha chiesto niente — due mestieri, due impaginazioni.
    dove = os.path.join(DOVE, 'benvenuto', 'index.html')
    os.makedirs(os.path.dirname(dove), exist_ok=True)
    vetrina.scrivi(dove, POSTA, APP, APP_STORE, PLAY_STORE)
    print('%-28s vetrina' % dove)

    print('\ntesti legali: versione %s, presi da %s' % (v, SORGENTE))


if __name__ == '__main__':
    main()

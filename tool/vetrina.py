"""La vetrina di crasyapp.com: la pagina che vede chi non ha ancora l'app.

**Sta a parte dalle altre pagine, e non e' disordine.** Privacy, termini e
supporto sono documenti: si aprono per cercare una riga, e tutto quello che non
e' quella riga e' un ostacolo — margini larghi, niente colore, niente
movimento. Questa e' l'opposto: ha dieci secondi per far capire cos'e' CRASY a
qualcuno che non lo sa e non ha chiesto niente.

Due mestieri diversi vogliono due vestiti diversi. Tenerli nello stesso stampo
avrebbe voluto dire o una vetrina che sembra un contratto, o un contratto pieno
di animazioni.

## Il movimento c'e', ma non e' decorazione

Le consegne che scorrono nel titolo sono **quelle vere**, lette dallo stesso
elenco che l'app pubblica ogni giorno (`tool/sfide_del_giorno.py`). Una vetrina
che dice "lancia una missione" resta un'astrazione; una che ti fa vedere *"La
cosa piu' brutta che hai in casa"* ha gia' spiegato tutto.

E chi ha chiesto di non vedere animazioni non ne vede: `prefers-reduced-motion`
spegne tutto. Non e' una gentilezza — per certe persone il movimento su una
pagina provoca nausea vera.
"""

import io

# Il glifo della mela e quello del triangolo di Google Play, disegnati qui.
#
# **Non sono le immagini ufficiali dei due negozi**, e non lo sono di proposito:
# quelle vanno scaricate dai rispettivi kit, hanno regole d'uso proprie e
# arrivano come file da tenere aggiornati. Questi sono due tracciati dentro la
# pagina: pesano zero, restano nitidi a qualunque ingrandimento e prendono il
# colore del testo che gli sta accanto.
MELA = (
    '<svg viewBox="0 0 384 512" width="20" height="20" fill="currentColor" '
    'aria-hidden="true"><path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"/></svg>'
)

PLAY = (
    '<svg viewBox="0 0 512 512" width="20" height="20" fill="currentColor" '
    'aria-hidden="true"><path d="M325.3 234.3 104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l256.6-256L47 0zm425.2 225.6-58.9-34.1-65.7 64.5 65.7 64.5 60.1-34.1c18-14.3 18-46.5-1.2-60.8zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z"/></svg>'
)


def consegneVere():
    """Qualche consegna presa dall'elenco che l'app pubblica davvero."""

    try:
        import sfide_del_giorno

        return [titolo for titolo, _, _ in sfide_del_giorno.CONSEGNE]
    except Exception:  # noqa: BLE001 — senza, la vetrina si scrive lo stesso
        return []


def _scelte(quante=6):
    tutte = consegneVere()

    if len(tutte) < quante:
        return [
            'La cosa piu&#39; brutta che hai in casa',
            'La faccia che fai appena sveglio',
            'Travestiti con quello che trovi in casa',
            'Il posto piu&#39; assurdo in cui riesci a farti una foto',
            'Costruisci una faccia con del cibo',
            'Il tuo pranzo, com&#39;e&#39; davvero',
        ]

    # Prese distanziate lungo l'elenco: prendendo le prime sei si vedrebbe
    # sempre lo stesso inizio, e l'elenco e' lungo mesi.
    passo = max(1, len(tutte) // quante)

    return [
        t.replace("'", '&#39;') for t in tutte[::passo][:quante]
    ]


def _tastoStore(nome, glifo, indirizzo):
    spento = not indirizzo
    classe = 'store' + (' store--spento' if spento else '')
    dentro = (
        '<span class="store__glifo">' + glifo + '</span>'
        '<span class="store__testo">'
        '<span class="store__sopra">' + ('PRESTO SU' if spento else 'SCARICA SU') + '</span>'
        '<span class="store__nome">' + nome + '</span>'
        '</span>'
    )

    if spento:
        return '<span class="' + classe + '">' + dentro + '</span>'

    return '<a class="' + classe + '" href="' + indirizzo + '">' + dentro + '</a>'


STAMPO = """<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CRASY — le sfide che pagano</title>
<meta name="description" content="Qualcuno mette in palio dei soldi veri e lancia una missione. Tu la fai con una foto scattata sul momento. Vince quella che piace di piu.">
<meta property="og:title" content="CRASY — le sfide che pagano">
<meta property="og:description" content="Una missione, un premio vero, una foto scattata sul momento. Vince chi prende piu fiamme.">
<meta property="og:image" content="https://crasyapp.com/brand/crasy-wordmark.png">
<link rel="icon" href="/favicon.png">
<style>
:root {
  --rosso: #FA0000;
  --inchiostro: #0A0A0B;
  --tenue: #6B6B70;
  --fioco: #A1A1A6;
  --riga: #E8E8EA;
  --spento: #F4F4F5;
  color-scheme: light;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0;
  background: #FFF;
  color: var(--inchiostro);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.55;
  -webkit-font-smoothing: antialiased;
  overflow-x: hidden;
}
.dentro { width: 100%; max-width: 860px; margin: 0 auto; padding: 0 22px; }
a { color: var(--rosso); }

/* Il rosso di CRASY, usato come si usa in casa: poco, e sulle cose che
   contano. Se lo mettessimo dappertutto smetterebbe di voler dire qualcosa. */
.rosso { color: var(--rosso); }

/* --- l'apertura --- */
.cielo {
  position: relative;
  padding: 52px 0 70px;
  overflow: hidden;
}
/* Un alone rosso appena accennato dietro il titolo: si sente, non si vede. */
.cielo::before {
  content: '';
  position: absolute;
  top: -280px; left: 50%;
  width: 760px; height: 620px;
  transform: translateX(-50%);
  background: radial-gradient(closest-side, rgba(250,0,0,.10), rgba(250,0,0,0));
  pointer-events: none;
  animation: respiro 7s ease-in-out infinite;
}
@keyframes respiro {
  0%, 100% { opacity: .75; transform: translateX(-50%) scale(1); }
  50%      { opacity: 1;   transform: translateX(-50%) scale(1.08); }
}
.marchio { width: 138px; height: auto; display: block; }
.beta {
  display: inline-block;
  margin-left: 6px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .14em;
  color: var(--fioco);
  vertical-align: super;
}
h1 {
  font-size: clamp(40px, 9vw, 78px);
  line-height: .95;
  letter-spacing: -.035em;
  font-weight: 800;
  margin: 34px 0 0;
  text-transform: uppercase;
}
.occhiello {
  font-size: clamp(17px, 2.4vw, 20px);
  color: var(--tenue);
  max-width: 32ch;
  margin: 18px 0 0;
}

/* --- la consegna che cambia --- */
.consegna {
  margin-top: 30px;
  border: 1px solid var(--riga);
  border-radius: 16px;
  padding: 16px 18px;
  max-width: 460px;
  background: #FFF;
  box-shadow: 0 10px 30px rgba(10,10,11,.05);
}
.consegna__etichetta {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .16em;
  color: var(--rosso);
}
.finestra { height: 30px; overflow: hidden; margin-top: 4px; }
.nastro { animation: scorri 15s cubic-bezier(.7,0,.3,1) infinite; }
.nastro span {
  display: block;
  height: 30px;
  line-height: 30px;
  font-size: 17px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
@keyframes scorri {
  0%,13%   { transform: translateY(0); }
  16%,29%  { transform: translateY(-30px); }
  32%,45%  { transform: translateY(-60px); }
  48%,61%  { transform: translateY(-90px); }
  64%,77%  { transform: translateY(-120px); }
  80%,93%  { transform: translateY(-150px); }
  100%     { transform: translateY(-180px); }
}

/* --- i tasti dei negozi --- */
.negozi { display: flex; gap: 12px; flex-wrap: wrap; margin: 30px 0 12px; }
.store {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  padding: 12px 20px;
  border-radius: 14px;
  text-decoration: none;
  background: var(--inchiostro);
  color: #FFF;
  transition: transform .18s ease, box-shadow .18s ease;
}
.store:hover { transform: translateY(-2px); box-shadow: 0 12px 26px rgba(10,10,11,.22); }
.store--spento {
  background: var(--spento);
  color: var(--fioco);
  border: 1px solid var(--riga);
  cursor: default;
}
.store--spento:hover { transform: none; box-shadow: none; }
.store__glifo { display: flex; }
.store__sopra { display: block; font-size: 10px; letter-spacing: .1em; opacity: .75; }
.store__nome { display: block; font-size: 16px; font-weight: 800; letter-spacing: -.01em; }
.sottotasti { font-size: 14px; color: var(--fioco); margin: 0; }

/* --- i tre passi --- */
.passi { display: grid; gap: 14px; grid-template-columns: 1fr; margin: 0; padding: 0; }
@media (min-width: 760px) { .passi { grid-template-columns: repeat(3, 1fr); } }
.passo {
  border: 1px solid var(--riga);
  border-radius: 18px;
  padding: 22px;
  list-style: none;
  background: #FFF;
  transition: transform .2s ease, border-color .2s ease, box-shadow .2s ease;
}
.passo:hover {
  transform: translateY(-4px);
  border-color: rgba(250,0,0,.35);
  box-shadow: 0 16px 34px rgba(10,10,11,.07);
}
.passo__numero {
  font-size: 34px;
  font-weight: 800;
  letter-spacing: -.04em;
  color: var(--rosso);
  line-height: 1;
}
.passo__titolo { font-weight: 800; margin: 12px 0 6px; font-size: 17px; }
.passo p { color: var(--tenue); font-size: 15px; margin: 0; }

/* --- la fascia nera --- */
.fascia {
  background: var(--inchiostro);
  color: #FFF;
  padding: 64px 0;
  margin: 74px 0;
}
.fascia h2 {
  font-size: clamp(28px, 5.5vw, 46px);
  line-height: 1.02;
  letter-spacing: -.03em;
  font-weight: 800;
  margin: 0;
  text-transform: uppercase;
}
.fascia p { color: #B9B9BE; max-width: 46ch; margin: 16px 0 0; }

/* --- la sfida del giorno --- */
.giornaliera {
  border: 2px solid var(--rosso);
  border-radius: 18px;
  padding: 24px;
  margin: 0 0 20px;
}
.giornaliera__etichetta {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .16em;
  color: var(--rosso);
}
.giornaliera h3 { margin: 8px 0 6px; font-size: 22px; font-weight: 800; letter-spacing: -.02em; }
.giornaliera p { color: var(--tenue); margin: 0; }

h2.sezione {
  font-size: 11px;
  letter-spacing: .18em;
  text-transform: uppercase;
  color: var(--rosso);
  font-weight: 800;
  margin: 0 0 18px;
}
.nota {
  border: 1px solid var(--riga);
  background: var(--spento);
  border-radius: 14px;
  padding: 16px 18px;
  color: var(--tenue);
  font-size: 14px;
}
footer {
  margin-top: 70px;
  padding: 26px 0 60px;
  border-top: 1px solid var(--riga);
  font-size: 14px;
  color: var(--fioco);
}
footer a { margin-right: 18px; text-decoration: none; }

/* Ogni pezzo entra da solo, poco dopo quello prima. */
.entra { opacity: 0; transform: translateY(14px); animation: entrata .7s ease forwards; }
.r1 { animation-delay: .05s; } .r2 { animation-delay: .13s; }
.r3 { animation-delay: .21s; } .r4 { animation-delay: .29s; }
.r5 { animation-delay: .37s; }
@keyframes entrata { to { opacity: 1; transform: none; } }

/* **Chi ha chiesto di non vedere animazioni non ne vede.** Non e' una
   gentilezza: per certe persone il movimento su una pagina provoca nausea. */
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; transition: none !important; }
  .entra { opacity: 1; transform: none; }
  .nastro { transform: none; }
}
</style>
</head>
<body>

<header class="cielo">
  <div class="dentro">
    <div class="entra r1">
      <img class="marchio" src="/brand/crasy-wordmark.png" alt="CRASY" width="138">
      <span class="beta">BETA</span>
    </div>

    <h1 class="entra r2">Le sfide<br>che <span class="rosso">pagano.</span></h1>

    <p class="occhiello entra r2">Qualcuno mette in palio dei soldi veri e lancia
    una missione. Tu la fai, mandi la foto, e vince quella che piace di piu&#39;
    agli altri.</p>

    <div class="consegna entra r3">
      <div class="consegna__etichetta">OGGI SI FA QUESTO</div>
      <div class="finestra">
        <div class="nastro">@NASTRO@</div>
      </div>
    </div>

    <div class="negozi entra r4">@NEGOZI@</div>
    <p class="sottotasti entra r5">Stiamo finendo di prepararla.
    <a href="@APP@">Sei tra chi la sta provando? Entra da qui.</a></p>
  </div>
</header>

<main>
  <section class="dentro">
    <h2 class="sezione">Come funziona</h2>
    <ol class="passi">
      <li class="passo">
        <div class="passo__numero">01</div>
        <div class="passo__titolo">Una missione, un premio</div>
        <p>Chi la lancia mette i soldi in palio <strong class="rosso">prima</strong>
        che cominci. Non e&#39; una promessa: il premio e&#39; gia&#39; li&#39;.</p>
      </li>
      <li class="passo">
        <div class="passo__numero">02</div>
        <div class="passo__titolo">Una foto, sul momento</div>
        <p>Non quella che avevi in galleria. <strong class="rosso">Cinque
        partecipazioni al giorno</strong>, non una di piu&#39;: si sceglie dove
        spenderle.</p>
      </li>
      <li class="passo">
        <div class="passo__numero">03</div>
        <div class="passo__titolo">Vince chi piace</div>
        <p>Non decide chi ha messo i soldi: <strong class="rosso">decidono gli
        altri</strong>, una fiamma alla volta.</p>
      </li>
    </ol>
  </section>

  <section class="fascia">
    <div class="dentro">
      <h2>Le fiamme sono<br><span class="rosso">nascoste.</span></h2>
      <p>Finche&#39; la gara e&#39; aperta nessuno sa come sta andando — nemmeno
      tu. Niente classifica da guardare, niente foto che parte avvantaggiata
      perche&#39; e&#39; arrivata prima. Si scopre tutto alla fine, insieme.</p>
    </div>
  </section>

  <section class="dentro">
    <div class="giornaliera">
      <div class="giornaliera__etichetta">SFIDA DEL GIORNO &middot; GRATIS</div>
      <h3>Ogni mattina ce n&#39;e&#39; una nuova.</h3>
      <p>Uguale per tutti, ventiquattro ore esatte, e non consuma nessuna delle
      tue cinque partecipazioni.</p>
    </div>

    <h2 class="sezione" style="margin-top:52px;">Non e&#39; un gioco di fortuna</h2>
    <p style="color:var(--tenue);max-width:56ch;">Partecipare non costa niente e
    l&#39;esito non dipende dal caso: dipende da quanto piace quello che hai
    fatto. Si entra da maggiorenni, con un account per persona.</p>

    <div class="nota" style="margin-top:26px;">
      <strong style="color:var(--inchiostro);">CRASY e&#39; in prova.</strong>
      Le cose cambiano spesso e qualcosa si rompe. Se trovi qualcosa che non va
      scrivici a <a href="mailto:@POSTA@">@POSTA@</a>: leggiamo tutto.
    </div>

    <footer>
      <a href="/termini/">Termini</a>
      <a href="/privacy/">Privacy</a>
      <a href="/contenuti/">Foto e video</a>
      <a href="/supporto/">Supporto</a>
      <div style="margin-top:14px;">crasyapp.com</div>
    </footer>
  </section>
</main>

</body>
</html>
"""


def html(posta, app, appStore, playStore):
    scelte = _scelte()
    # L'ultima riga ripete la prima: l'animazione torna al principio senza che
    # si veda il salto.
    nastro = ''.join('<span>' + t + '</span>' for t in scelte + scelte[:1])
    negozi = _tastoStore('App Store', MELA, appStore) + _tastoStore(
        'Google Play', PLAY, playStore
    )

    return (
        STAMPO.replace('@NASTRO@', nastro)
        .replace('@NEGOZI@', negozi)
        .replace('@POSTA@', posta)
        .replace('@APP@', app)
    )


def scrivi(percorso, posta, app, appStore, playStore):
    io.open(percorso, 'w', encoding='utf-8', newline='\n').write(
        html(posta, app, appStore, playStore)
    )

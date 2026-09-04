"""La vetrina di crasyapp.com: la pagina che vede chi non ha ancora l'app.

**Sta a parte dalle altre pagine, e non e' disordine.** Privacy, termini e
supporto sono documenti: si aprono per cercare una riga, e tutto quello che non
e' quella riga e' un ostacolo. Questa e' l'opposto: ha dieci secondi per far
capire cos'e' CRASY a qualcuno che non lo sa e non ha chiesto niente.

## Il pezzo con cui si gioca

In mezzo alla pagina c'e' una foto finta con un tasto a fiamma. Si preme, il
numero sale, le fiamme volano via. Alla terza **il numero sparisce** e al suo
posto compare *nascoste fino alla fine*.

Non e' un giocattolo messo li' per far muovere qualcosa: e' l'unico modo di
spiegare in due secondi la regola piu' strana di CRASY. Scritta — *"le fiamme
restano nascoste finche' la gara e' aperta"* — e' una frase che si legge e si
dimentica. Fatta provare, e' il momento in cui uno capisce che qui non si guarda
la classifica.

**Chi non tocca niente la vede lo stesso**: dopo qualche secondo il tasto
tremola da solo, che e' il modo piu' educato di dire "questo si preme".

## Il movimento, e chi non lo vuole

Fiamme che salgono dal fondo, blocchi che compaiono scorrendo, carte che si
alzano sotto il dito. Con `prefers-reduced-motion` si spegne tutto e la pagina
resta intera: non e' una gentilezza, per certe persone il movimento su una
pagina provoca nausea vera.
"""

import io

# Il glifo della mela e quello del triangolo di Google Play, disegnati qui.
#
# **Non sono le immagini ufficiali dei due negozi**, e non lo sono di proposito:
# quelle vanno scaricate dai rispettivi kit, hanno regole d'uso proprie e
# arrivano come file da tenere aggiornati. Questi sono due tracciati dentro la
# pagina: pesano zero, restano nitidi a qualunque ingrandimento e prendono il
# colore del testo che gli sta accanto — quindi diventano bianchi da soli
# quando il tasto passa da spento ad acceso.
MELA = (
    '<svg viewBox="0 0 384 512" width="20" height="20" fill="currentColor" '
    'aria-hidden="true"><path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"/></svg>'
)

PLAY = (
    '<svg viewBox="0 0 512 512" width="20" height="20" fill="currentColor" '
    'aria-hidden="true"><path d="M325.3 234.3 104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l256.6-256L47 0zm425.2 225.6-58.9-34.1-65.7 64.5 65.7 64.5 60.1-34.1c18-14.3 18-46.5-1.2-60.8zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z"/></svg>'
)

# La fiamma. E' il segno di CRASY dopo il marchio: e' il gesto con cui si vota,
# e la moneta con cui si vince.
FIAMMA = (
    '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">'
    '<path d="M13.5 1.5c.6 3.3-1.1 5.2-2.8 6.9-1.7 1.8-3.4 3.4-3 6.6-2-1.2-2.6-3.6-2.6-3.6S3 13.6 3 16.3C3 20.6 7 23 12 23s9-2.6 9-7.2c0-5.6-4.5-7.5-4.5-7.5s.4 2.3-.8 3.6c-.2-2.3-1-6.5-2.2-10.4z"/>'
    '</svg>'
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

    return [t.replace("'", '&#39;') for t in tutte[::passo][:quante]]


def _tastoStore(nome, glifo, indirizzo):
    spento = not indirizzo
    classe = 'store' + (' store--spento' if spento else '')
    dentro = (
        '<span class="store__glifo">' + glifo + '</span>'
        '<span>'
        '<span class="store__sopra">'
        + ('PRESTO SU' if spento else 'SCARICA SU')
        + '</span>'
        '<span class="store__nome">' + nome + '</span>'
        '</span>'
    )

    if spento:
        return '<span class="' + classe + '">' + dentro + '</span>'

    return '<a class="' + classe + '" href="' + indirizzo + '">' + dentro + '</a>'


def _scintille(quante=9):
    """Le fiamme che salgono dal fondo dell'apertura.

    Posizioni e tempi sono scritti nella pagina invece di essere sorteggiati
    ogni volta: **una pagina che si disegna diversa a ogni ricarica non si puo'
    guardare due volte per capire se e' venuta bene.** Cosi' invece e' sempre
    identica, e si puo' correggere.
    """

    dove = [6, 17, 28, 39, 50, 61, 72, 83, 93]
    tempi = [9.5, 12.0, 10.5, 13.5, 11.0, 14.0, 10.0, 12.5, 11.5]
    ritardi = [0, 2.4, 4.8, 1.2, 6.0, 3.6, 7.2, 5.4, 8.4]
    misure = [16, 22, 13, 26, 18, 14, 24, 15, 20]

    return ''.join(
        '<span class="scintilla" style="left:%d%%;width:%dpx;height:%dpx;'
        'animation-duration:%.1fs;animation-delay:%.1fs;">%s</span>'
        % (dove[i], misure[i], misure[i], tempi[i], ritardi[i], FIAMMA)
        for i in range(quante)
    )


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
.dentro { width: 100%; max-width: 900px; margin: 0 auto; padding: 0 22px; position: relative; z-index: 1; }
a { color: var(--rosso); }
.rosso { color: var(--rosso); }

/* --- l'apertura --- */
.cielo { position: relative; padding: 48px 0 64px; overflow: hidden; }
.cielo::before {
  content: '';
  position: absolute;
  top: -300px; left: 50%;
  width: 820px; height: 660px;
  transform: translateX(-50%);
  background: radial-gradient(closest-side, rgba(250,0,0,.11), rgba(250,0,0,0));
  pointer-events: none;
  animation: respiro 7s ease-in-out infinite;
}
@keyframes respiro {
  0%, 100% { opacity: .7; transform: translateX(-50%) scale(1); }
  50%      { opacity: 1;  transform: translateX(-50%) scale(1.09); }
}

/* Le fiamme che salgono, dietro tutto. Piccole e pallide: devono farsi
   sentire con la coda dell'occhio, non farsi guardare. */
.scintille { position: absolute; inset: 0; pointer-events: none; overflow: hidden; }
.scintilla {
  position: absolute;
  bottom: -40px;
  color: var(--rosso);
  opacity: 0;
  animation-name: sale;
  animation-timing-function: linear;
  animation-iteration-count: infinite;
}
.scintilla svg { width: 100%; height: 100%; display: block; }
@keyframes sale {
  0%   { transform: translateY(0) rotate(-6deg) scale(.9); opacity: 0; }
  12%  { opacity: .16; }
  70%  { opacity: .10; }
  100% { transform: translateY(-88vh) rotate(8deg) scale(1.1); opacity: 0; }
}

.marchio { width: 138px; height: auto; display: block; }
.beta {
  display: inline-block; margin-left: 6px; font-size: 10px; font-weight: 800;
  letter-spacing: .14em; color: var(--fioco); vertical-align: super;
}
h1 {
  font-size: clamp(40px, 9vw, 78px);
  line-height: .95; letter-spacing: -.035em; font-weight: 800;
  margin: 32px 0 0; text-transform: uppercase;
}
.occhiello {
  font-size: clamp(17px, 2.4vw, 20px); color: var(--tenue);
  max-width: 34ch; margin: 18px 0 0;
}

/* --- il pezzo con cui si gioca --- */
.gioco {
  margin-top: 34px;
  border: 1px solid var(--riga);
  border-radius: 20px;
  padding: 20px;
  max-width: 470px;
  background: #FFF;
  box-shadow: 0 14px 40px rgba(10,10,11,.07);
  position: relative;
}
.gioco__etichetta {
  font-size: 10px; font-weight: 800; letter-spacing: .16em; color: var(--rosso);
}
.finestra { height: 30px; overflow: hidden; margin-top: 2px; }
.nastro { animation: scorri 15s cubic-bezier(.7,0,.3,1) infinite; }
.nastro span {
  display: block; height: 30px; line-height: 30px; font-size: 18px;
  font-weight: 800; letter-spacing: -.01em;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
@keyframes scorri {
  0%,13%  { transform: translateY(0); }
  16%,29% { transform: translateY(-30px); }
  32%,45% { transform: translateY(-60px); }
  48%,61% { transform: translateY(-90px); }
  64%,77% { transform: translateY(-120px); }
  80%,93% { transform: translateY(-150px); }
  100%    { transform: translateY(-180px); }
}
.riga {
  display: flex; align-items: center; justify-content: space-between;
  gap: 14px; margin-top: 16px; padding-top: 14px; border-top: 1px solid var(--riga);
}
.tasto {
  display: inline-flex; align-items: center; gap: 9px;
  border: 1px solid var(--riga); background: #FFF; color: var(--fioco);
  border-radius: 999px; padding: 10px 18px; cursor: pointer;
  font: inherit; font-weight: 800; font-size: 15px;
  transition: transform .14s ease, background .18s ease, color .18s ease, border-color .18s ease;
  position: relative;
}
.tasto svg { width: 19px; height: 19px; }
.tasto:hover { border-color: rgba(250,0,0,.4); color: var(--rosso); }
.tasto:active { transform: scale(.94); }
.tasto.acceso { background: var(--rosso); border-color: var(--rosso); color: #FFF; }
.tasto.invito { animation: bussa 1.6s ease-in-out 3; }
@keyframes bussa {
  0%,100%  { transform: none; }
  30%      { transform: scale(1.07); }
  45%      { transform: scale(.99); }
  60%      { transform: scale(1.04); }
}
.conto { font-size: 14px; color: var(--fioco); text-align: right; min-width: 132px; }
.conto b { color: var(--inchiostro); font-size: 17px; }
.conto.svelato b { color: var(--rosso); }

/* Le fiamme che schizzano via a ogni tocco. */
.volo {
  position: absolute; pointer-events: none; color: var(--rosso);
  width: 16px; height: 16px; opacity: 0;
}
.volo svg { width: 100%; height: 100%; display: block; }
@keyframes vola {
  0%   { opacity: 1; transform: translate(0,0) scale(.5) rotate(0deg); }
  100% { opacity: 0; transform: translate(var(--dx), -70px) scale(1.25) rotate(var(--gira)); }
}

/* --- i tasti dei negozi --- */
.negozi { display: flex; gap: 12px; flex-wrap: wrap; margin: 30px 0 12px; }
.store {
  display: inline-flex; align-items: center; gap: 12px;
  padding: 12px 20px; border-radius: 14px; text-decoration: none;
  background: var(--inchiostro); color: #FFF;
  transition: transform .18s ease, box-shadow .18s ease;
}
.store:hover { transform: translateY(-2px); box-shadow: 0 12px 26px rgba(10,10,11,.22); }
.store--spento {
  background: var(--spento); color: var(--fioco);
  border: 1px solid var(--riga); cursor: default;
}
.store--spento:hover { transform: none; box-shadow: none; }
.store__glifo { display: flex; }
.store__sopra { display: block; font-size: 10px; letter-spacing: .1em; opacity: .75; }
.store__nome { display: block; font-size: 16px; font-weight: 800; letter-spacing: -.01em; }
.sottotasti { font-size: 14px; color: var(--fioco); margin: 0; }

/* --- i tre passi --- */
.passi { display: grid; gap: 14px; grid-template-columns: 1fr; margin: 0; padding: 0; }
@media (min-width: 780px) { .passi { grid-template-columns: repeat(3, 1fr); } }
.passo {
  border: 1px solid var(--riga); border-radius: 18px; padding: 22px;
  list-style: none; background: #FFF;
  transition: transform .2s ease, border-color .2s ease, box-shadow .2s ease;
}
.passo:hover {
  transform: translateY(-5px); border-color: rgba(250,0,0,.35);
  box-shadow: 0 18px 36px rgba(10,10,11,.08);
}
.passo__numero {
  font-size: 34px; font-weight: 800; letter-spacing: -.04em;
  color: var(--rosso); line-height: 1;
}
.passo__titolo { font-weight: 800; margin: 12px 0 6px; font-size: 17px; }
.passo p { color: var(--tenue); font-size: 15px; margin: 0; }

/* --- la fascia nera --- */
.fascia {
  background: var(--inchiostro); color: #FFF;
  padding: 64px 0; margin: 74px 0; position: relative; overflow: hidden;
}
.fascia h2 {
  font-size: clamp(28px, 5.5vw, 46px); line-height: 1.02;
  letter-spacing: -.03em; font-weight: 800; margin: 0; text-transform: uppercase;
}
.fascia p { color: #B9B9BE; max-width: 46ch; margin: 16px 0 0; }
.fascia .scintilla { opacity: 0; }
.fascia .scintille { opacity: .55; }

/* --- la sfida del giorno --- */
.giornaliera { border: 2px solid var(--rosso); border-radius: 18px; padding: 24px; }
.giornaliera__etichetta {
  font-size: 10px; font-weight: 800; letter-spacing: .16em; color: var(--rosso);
}
.giornaliera h3 { margin: 8px 0 6px; font-size: 22px; font-weight: 800; letter-spacing: -.02em; }
.giornaliera p { color: var(--tenue); margin: 0; }

h2.sezione {
  font-size: 11px; letter-spacing: .18em; text-transform: uppercase;
  color: var(--rosso); font-weight: 800; margin: 0 0 18px;
}
.nota {
  border: 1px solid var(--riga); background: var(--spento);
  border-radius: 14px; padding: 16px 18px; color: var(--tenue); font-size: 14px;
}
footer {
  margin-top: 70px; padding: 26px 0 60px; border-top: 1px solid var(--riga);
  font-size: 14px; color: var(--fioco);
}
footer a { margin-right: 18px; text-decoration: none; }

/* Ogni pezzo entra da solo, e quelli piu' in basso entrano scorrendo. */
.entra { opacity: 0; transform: translateY(14px); animation: entrata .7s ease forwards; }
.r1 { animation-delay: .05s; } .r2 { animation-delay: .13s; }
.r3 { animation-delay: .21s; } .r4 { animation-delay: .29s; }
.r5 { animation-delay: .37s; }
@keyframes entrata { to { opacity: 1; transform: none; } }
.appare { opacity: 0; transform: translateY(22px); transition: opacity .6s ease, transform .6s ease; }
.appare.vista { opacity: 1; transform: none; }

@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; transition: none !important; }
  .entra, .appare { opacity: 1; transform: none; }
  .scintille { display: none; }
}
</style>
</head>
<body>

<header class="cielo">
  <div class="scintille" aria-hidden="true">@SCINTILLE@</div>
  <div class="dentro">
    <div class="entra r1">
      <img class="marchio" src="/brand/crasy-wordmark.png" alt="CRASY" width="138">
      <span class="beta">BETA</span>
    </div>

    <h1 class="entra r2">Le sfide<br>che <span class="rosso">pagano.</span></h1>

    <p class="occhiello entra r2">Qualcuno mette in palio dei soldi veri e lancia
    una missione. Tu la fai, mandi la foto, e vince quella che piace di piu&#39;
    agli altri.</p>

    <div class="gioco entra r3" id="gioco">
      <div class="gioco__etichetta">OGGI SI FA QUESTO</div>
      <div class="finestra"><div class="nastro">@NASTRO@</div></div>
      <div class="riga">
        <button class="tasto" id="fiamma" type="button" aria-label="Dai una fiamma">
          @FIAMMA@ <span>Fiamma</span>
        </button>
        <div class="conto" id="conto">provala: si fa cosi&#39;</div>
      </div>
    </div>

    <div class="negozi entra r4">@NEGOZI@</div>
    <p class="sottotasti entra r5">Stiamo finendo di prepararla.
    <a href="@APP@">Sei tra chi la sta provando? Entra da qui.</a></p>
  </div>
</header>

<main>
  <section class="dentro">
    <h2 class="sezione appare">Come funziona</h2>
    <ol class="passi">
      <li class="passo appare">
        <div class="passo__numero">01</div>
        <div class="passo__titolo">Una missione, un premio</div>
        <p>Chi la lancia mette i soldi in palio <strong class="rosso">prima</strong>
        che cominci. Non e&#39; una promessa: il premio e&#39; gia&#39; li&#39;.</p>
      </li>
      <li class="passo appare">
        <div class="passo__numero">02</div>
        <div class="passo__titolo">Una foto, sul momento</div>
        <p>Non quella che avevi in galleria. <strong class="rosso">Cinque
        partecipazioni al giorno</strong>, non una di piu&#39;: si sceglie dove
        spenderle.</p>
      </li>
      <li class="passo appare">
        <div class="passo__numero">03</div>
        <div class="passo__titolo">Vince chi piace</div>
        <p>Non decide chi ha messo i soldi: <strong class="rosso">decidono gli
        altri</strong>, una fiamma alla volta.</p>
      </li>
    </ol>
  </section>

  <section class="fascia">
    <div class="scintille" aria-hidden="true">@SCINTILLE@</div>
    <div class="dentro">
      <h2 class="appare">Le fiamme sono<br><span class="rosso">nascoste.</span></h2>
      <p class="appare">Finche&#39; la gara e&#39; aperta nessuno sa come sta
      andando — nemmeno tu. Niente classifica da guardare, niente foto che parte
      avvantaggiata perche&#39; e&#39; arrivata prima. Si scopre tutto alla fine,
      insieme.</p>
    </div>
  </section>

  <section class="dentro">
    <div class="giornaliera appare">
      <div class="giornaliera__etichetta">SFIDA DEL GIORNO &middot; GRATIS</div>
      <h3>Ogni mattina ce n&#39;e&#39; una nuova.</h3>
      <p>Uguale per tutti, ventiquattro ore esatte, e non consuma nessuna delle
      tue cinque partecipazioni.</p>
    </div>

    <h2 class="sezione appare" style="margin-top:52px;">Non e&#39; un gioco di fortuna</h2>
    <p class="appare" style="color:var(--tenue);max-width:56ch;">Partecipare non
    costa niente e l&#39;esito non dipende dal caso: dipende da quanto piace
    quello che hai fatto. Si entra da maggiorenni, con un account per persona.</p>

    <div class="nota appare" style="margin-top:26px;">
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

<script>
(function () {
  var calmo = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // --- i blocchi che compaiono scorrendo -----------------------------------
  //
  // Con l'osservatore quando c'e', altrimenti si mostrano e basta: una pagina
  // che nasconde meta' del contenuto quando un pezzo non funziona e' peggio di
  // una pagina senza animazioni.
  var pezzi = document.querySelectorAll('.appare');

  if (calmo || !('IntersectionObserver' in window)) {
    pezzi.forEach(function (p) { p.classList.add('vista'); });
  } else {
    var occhio = new IntersectionObserver(function (righe) {
      righe.forEach(function (r, i) {
        if (r.isIntersecting) {
          setTimeout(function () { r.target.classList.add('vista'); }, i * 70);
          occhio.unobserve(r.target);
        }
      });
    }, { rootMargin: '0px 0px -12% 0px' });

    pezzi.forEach(function (p) { occhio.observe(p); });
  }

  // --- il tasto della fiamma -----------------------------------------------
  var tasto = document.getElementById('fiamma');
  var conto = document.getElementById('conto');

  if (!tasto) { return; }

  var quante = 0;
  var SVELA = 3;
  var disegno = tasto.querySelector('svg').outerHTML;

  function scintilla() {
    if (calmo) { return; }

    for (var i = 0; i < 6; i++) {
      var f = document.createElement('span');
      f.className = 'volo';
      f.innerHTML = disegno;
      f.style.left = (18 + Math.random() * 46) + 'px';
      f.style.top = '6px';
      f.style.setProperty('--dx', (Math.random() * 70 - 35).toFixed(0) + 'px');
      f.style.setProperty('--gira', (Math.random() * 90 - 45).toFixed(0) + 'deg');
      f.style.animation = 'vola ' + (0.7 + Math.random() * 0.5).toFixed(2) + 's ease-out forwards';
      tasto.parentNode.appendChild(f);

      (function (nodo) {
        setTimeout(function () { nodo.remove(); }, 1400);
      })(f);
    }
  }

  tasto.addEventListener('click', function () {
    quante++;
    tasto.classList.remove('invito');
    tasto.classList.add('acceso');
    scintilla();

    if (quante < SVELA) {
      conto.className = 'conto';
      conto.innerHTML = '<b>' + quante + '</b> fiamm' + (quante === 1 ? 'a' : 'e');

      return;
    }

    // **Il momento per cui esiste tutto questo.** Al terzo tocco il numero
    // sparisce: e' la regola piu' strana di CRASY, e detta cosi' — mentre uno
    // sta contando le proprie fiamme — non si dimentica piu'.
    conto.className = 'conto svelato';
    conto.innerHTML = '<b>nascoste</b><br><span style="font-size:12px;">'
      + 'si scoprono alla fine</span>';
  });

  // Dopo qualche secondo il tasto tremola: e' il modo piu' educato di dire
  // "questo si preme" senza scriverlo da nessuna parte.
  if (!calmo) {
    setTimeout(function () {
      if (quante === 0) { tasto.classList.add('invito'); }
    }, 3200);
  }
})();
</script>

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
        .replace('@SCINTILLE@', _scintille())
        .replace('@FIAMMA@', FIAMMA)
        .replace('@POSTA@', posta)
        .replace('@APP@', app)
    )


def scrivi(percorso, posta, app, appStore, playStore):
    io.open(percorso, 'w', encoding='utf-8', newline='\n').write(
        html(posta, app, appStore, playStore)
    )

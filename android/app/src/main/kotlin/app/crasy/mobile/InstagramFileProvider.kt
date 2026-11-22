package app.crasy.mobile

import androidx.core.content.FileProvider

/**
 * **Il passaggio di una foto a Instagram.** Una classe tutta sua e non
 * `FileProvider` diretto: piu' librerie nell'app dichiarano un fornitore di
 * file, e due dichiarazioni con lo stesso nome nel manifesto si scontrano.
 * Mostra a Instagram solo la cartella `instagram/` della cache, nient'altro.
 */
class InstagramFileProvider : FileProvider()

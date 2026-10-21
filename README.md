# TelaCut — studio video mobile

Versione **0.2.0** in preparazione, originale, per Android e iPhone. Nome provvisorio.
Non è CapCut, non ne contiene il codice o i contenuti e non dichiara parità funzionale.
È un progetto in sviluppo: leggere `VERIFICA.md` prima di installare o distribuire.

## Funzioni implementate nel codice

- Importazione multipla di video, copiati nello spazio privato dell'app.
- Progetti locali, riapertura, rinomina, eliminazione con conferma e salvataggio atomico.
- Timeline sequenziale fino a 60 clip; selezione e anteprima.
- Taglio degli estremi, divisione al cursore, riordino, rimozione dalla timeline.
- Annullamento delle ultime 30 modifiche della sessione.
- Titolo globale, massimo 120 caratteri, incluso nell'esportazione.
- Importazione di una traccia audio, ripetuta per la durata del montaggio.
- Volume della musica e opzione per silenziare l'audio originale.
- Formati verticale 9:16, orizzontale 16:9 e quadrato 1:1, senza deformare i video.
- Pipeline MP4 fino a 1080p/30 fps, annullamento e condivisione.
- Nessun account, backend, telemetria o filigrana aggiunta.

Questa lista descrive il codice presente, **non certifica il funzionamento su dispositivi**.
Prestazioni e formati decodificabili dipendono dai codec del telefono.

## Struttura

| Cartella | Contenuto |
| --- | --- |
| `android/` | App Java nativa; AndroidX Media3 per anteprima ed esportazione |
| `ios/` | App SwiftUI; AVFoundation per composizione ed esportazione |
| `tests/` | Controlli della logica di timeline eseguibili senza Android |
| `scripts/` | Verifiche strutturali, selezione simulatore e packaging IPA |
| `.github/workflows/` | Build Android/iOS da eseguire nel proprio repository |

Le due versioni condividono il comportamento progettato, non lo stesso codice UI.
I progetti restano sul proprio dispositivo e non sono ancora trasferibili tra i due sistemi.

## Android

Requisiti: JDK 17, Gradle 8.9, Android SDK Platform 35 e Build-Tools 35.0.0.
Telefono: Android 10/API 29 o successivo.

```sh
gradle -p android testDebugUnitTest assembleDebug
```

La build debug è destinata alle verifiche ed è firmata con una chiave di sviluppo.
L'application ID termina in `.dev`, quindi non sostituisce la futura versione pubblica.

Per la release:

```sh
gradle -p android assembleRelease
```

Senza configurazione della firma, questa produce un APK **non firmato e non installabile**.
Per una release firmata, configurare nell'ambiente `TELACUT_KEYSTORE_PATH`,
`TELACUT_KEYSTORE_PASSWORD`, `TELACUT_KEY_ALIAS`, `TELACUT_KEY_PASSWORD`.
La chiave deve essere propria, custodita fuori dal repository e conservata per gli aggiornamenti.
Nessuna chiave privata di distribuzione è inclusa in questo progetto.
Le copie private dei media e dei progetti sono escluse dai meccanismi di backup
configurabili dall'app; i video che l'utente salva in Foto o in altri servizi possono
essere sincronizzati dalle impostazioni di quei servizi.

I video esportati vengono inseriti in `Movies/TelaCut`. Non viene richiesta l'autorizzazione
all'intero archivio del telefono: l'importazione usa il selettore di documenti di Android.
Il codice non richiede il permesso Internet.

## iPhone

Requisiti di compilazione: macOS, Xcode con SDK iOS e XcodeGen. Deployment target iOS 16.

```sh
cd ios
xcodegen generate
open TelaCut.xcodeproj
```

Selezionare il proprio team di firma per un'installazione gestita da Xcode.
La UI permette di importare dalla libreria Foto o da File. Il permesso di aggiunta a Foto
viene richiesto soltanto quando si sceglie «Salva in Foto» dopo un'esportazione.

Il workflow incluso può compilare su un runner macOS e preparare un IPA **non firmato**.
Non è stato eseguito da questa sessione e non costituisce un IPA già disponibile.
Il pacchetto andrà firmato/importato con un metodo appropriato, ad esempio AltStore Classic,
rispettandone i limiti già discussi. Non è una pubblicazione su AltStore PAL.

## GitHub

Repository: https://github.com/th1sable/telacut . Le compilazioni e le prove
di esportazione vengono eseguite con GitHub Actions. Nessuna release è stata ancora pubblicata.
Il workflow produce artefatti di sviluppo; **non pubblica automaticamente release per gli utenti**.
Prima della distribuzione pubblica occorrono test reali, firma Android definitiva,
build/firma iOS, istruzioni d'installazione e una scelta esplicita della licenza del progetto.
La licenza del codice originale non è stata scelta al posto del proprietario.

## Limiti di questa prima versione

- Non include IA, sottotitoli automatici, text-to-speech, rimozione sfondo o tracking.
- Non include filtri, transizioni, keyframe, maschere, velocità variabile o stabilizzazione.
- Non include un editor fotografico, tracce video sovrapposte o un catalogo di template/musica.
- Il testo è un solo titolo globale; la preview iOS usa un overlay UI e può differire
  nella disposizione dal titolo renderizzato nel file finale.
- La preview Android usa l'API sperimentale `CompositionPlayer` di Media3 1.9.3:
  versione fissata e opt-in esplicito; richiede prove su dispositivi prima della release.
- L'audio aggiunto parte dall'inizio e viene ripetuto; non ci sono fade, ritardo o limiter.
- Nessuna sincronizzazione, autenticazione, collaborazione o gestione abbonamenti.
- Nessuna garanzia 4K, HDR, HEVC, codec particolari o montaggi lunghi.
- Tenere l'app in primo piano durante l'export. Non è presente un servizio di export in background.
- Limite di importazione: 1 GB per file. Lo spazio per copie e video esportati resta necessario.
- I media importati restano conservati anche quando una clip è rimossa dalla timeline:
  possono servire ad altri progetti o all'annullamento. Non c'è ancora pulizia dello spazio da UI.
- Non sono ancora presenti ripristino da backup o migrazioni di schema.
- Il nome e l'icona sono provvisori. L'interfaccia nativa non è stata verificata visivamente su telefono.

## REA

REA 6.7.0 è stato usato precedentemente per l'inventario statico dell'APK ufficiale di CapCut.
L'inventario non è una decompilazione e non recupera i servizi cloud.
L'analisi approfondita è rimasta bloccata: JADX non configurato e controllo processi
non compatibile con l'ambiente. Questo codice è una nuova implementazione indipendente.
Dettagli e identificativi: `REA-PROVENIENZA.txt`.
REA è stato usato anche per inventariare l'APK di TelaCut consegnato;
risultati, hash e limiti della verifica sono in `VERIFICA.md`.

## Documentazione tecnica usata

- https://developer.android.com/media/media3/transformer/composition
- https://developer.android.com/reference/androidx/media3/transformer/CompositionPlayer
- https://developer.android.com/reference/androidx/media3/effect/TextOverlay
- https://developer.apple.com/documentation/avfoundation/avassetexportsession
- https://developer.apple.com/documentation/avfoundation/avvideocompositioncoreanimationtool
- https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md

Media3 e le altre dipendenze mantengono le proprie licenze; non si assume alcun diritto
sui cataloghi, la musica, i template, il marchio o i servizi di CapCut.

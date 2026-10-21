# TelaCut 0.1.0 — stato della verifica

Data: 21 ottobre 2026. Questa è una prima versione di sviluppo, non una release
pronta per il pubblico e non una ricostruzione completa di CapCut.

## Android: pacchetto compilato

File consegnato: `TelaCut-0.1.0-android-dev.apk` (15.546.779 byte).
Requisito minimo: Android 10. Non è installabile su iPhone.

SHA-256:

```text
34472d9bbc785408588661ab88c25352aacc3d83e2c5dc2d4081bcdc113a36ae
```

La build pulita Gradle con `clean :app:assembleDebug :app:testDebugUnitTest
:app:lintDebug` è terminata con successo. Ambiente: JDK 17, Gradle 8.9,
Android SDK 35 e Build-Tools 35.0.0.

| Controllo | Risultato |
| --- | --- |
| Compilazione e packaging APK debug | Superati |
| Firma APK, controllo con `apksigner verify --verbose` | Valida, schema v2, un firmatario |
| Test unitari Java/JUnit | 16 eseguiti, nessun errore, fallimento o test saltato |
| Verifiche aritmetiche aggiuntive della timeline | 24.752 controlli superati |
| Android Lint | 0 errori, 7 avvertimenti |
| Installazione, avvio e uso su telefono | Non eseguiti |
| Anteprima, decodifica ed export effettivo su dispositivo | Non verificati |

Gli avvertimenti Lint riguardano orientamento bloccato, un'API sconsigliata,
configurazione backup per Android precedenti alla versione 12 e quattro casi
di testo costruito nel codice. Il manifest imposta `allowBackup=false` e
regole di esclusione per Android 12+. Gli avvertimenti restano da riesaminare
prima di una release pubblica, insieme a localizzazione e adattamento dello schermo.

La firma è di sviluppo: non identifica una futura release commerciale.
Il package è `dev.telacut.mobile.dev`. Per aggiornamenti pubblici occorre
una propria chiave di firma stabile. Nessuna chiave privata è inclusa nei sorgenti.
I controlli aritmetici non sono prove su telefono e non certificano l'export.

## REA: ispezione dell'APK consegnato

Comando eseguito con REA 6.7.0: `inspect-artifact`, sul pacchetto con l'hash sopra.
Inventario completato: 605 nodi, 636 occorrenze e 635 relazioni.

Evidence ID:

```text
ev_0b5f9fc771e37280c4098ec4aa41d7b5b941fc2b29e4fa31962b97b3c493316e
```

È un inventario statico del contenitore ZIP, non un'esecuzione dell'app,
una verifica funzionale o un audit di sicurezza. Il numero di nodi non è
il numero di funzioni dell'app. Il controllo della firma sopra è separato da REA.
La provenienza della precedente analisi di riferimento è in `REA-PROVENIENZA.txt`.

## iPhone: sorgenti, non un IPA pronto

Sono inclusi progetto XcodeGen, sorgenti SwiftUI/AVFoundation, sei test XCTest
e workflow GitHub Actions per un runner macOS. Nessun workflow è stato eseguito
su GitHub e nessun repository è stato modificato o pubblicato.

- Parsing sintattico dei file Swift superato con tree-sitter.
- Controlli strutturali XML, plist, YAML e dell'icona superati.
- Nessuna compilazione o verifica dei tipi con il compilatore Swift/Xcode.
- Test XCTest, simulatore e iPhone reale non eseguiti.
- Nessun IPA prodotto, firmato, installato o collaudato.

Il parsing non esclude errori di API, tipi, concorrenza o comportamento.
La prossima verifica necessaria è una build su macOS/Xcode, seguita dai test
e da un'installazione autorizzata sul proprio iPhone. L'eventuale IPA non firmato
generato dal workflow necessita ancora di firma e di un metodo d'installazione.

## Prima di distribuire ai consumatori

Eseguire la checklist `TEST-SU-TELEFONO.md` su entrambe le piattaforme,
correggere i problemi emersi, scegliere la licenza, completare la verifica
delle dipendenze e delle rispettive attribuzioni e predisporre firme e istruzioni.
Le funzioni mancanti rispetto a un editor completo sono elencate nel README.

Non sono stati caricati video personali, attivati servizi a pagamento o
pubblicati repository/release. L'archivio sorgente non include l'APK di CapCut,
cache di compilazione, SDK o chiavi di firma.

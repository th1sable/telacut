# TelaCut 0.2.0 - verifiche eseguite

Data: 21 ottobre 2026. Editor originale: le funzioni sono elencate nel README.
Questa versione non dichiara la parità con CapCut.

## Android

File: `TelaCut-0.2.0-Android.apk`, 12.995.152 byte. Package `dev.telacut.mobile`,
versione 0.2.0, codice 2. Minimo Android 10/API 29, target API 35.
Build release non debuggabile; il manifest finale non richiede INTERNET.
Commit: `4108352901f94186a7554d28e323f2247128a212`.
Verifica: https://github.com/th1sable/telacut/actions/runs/39668722229

| Controllo | Risultato |
| --- | --- |
| Build debug/release, Gradle 8.9, Java 17, SDK 35 | Superata |
| Test unitari timeline | 16 superati, nessuno saltato |
| Avvio editor e ricreazione Activity su emulatore Android 15 | Superati |
| Salvataggio, riapertura ed eliminazione progetto | Superati |
| Esportazione MP4 reale, tagli, riordino, titolo e musica | Superata |
| Formato verticale 1080x1920, durata, colore e pixel del testo | Verificati |
| Allineamento zipalign e verifica firma apksigner | Superati |
| Installazione release e utilizzo su telefono fisico | Non eseguiti |

I tre test su emulatore usano la build debug dello stesso codice.
L'export combina due filmati originali generati (rosso e blu) e un tono audio.
Il controllo delle dimensioni considera la rotazione MP4: Media3 può codificare
1920x1080 con una matrice di rotazione per visualizzare 1080x1920.

SHA-256 APK:

```text
9f867c34d53ace291c02c5198bd5731a21ac34aeef5fc8f96ab209fa5c80a068
```

Firma: APK Signature Scheme v3, RSA 3072 bit, un firmatario, CN=TelaCut.
SHA-256 certificato pubblico:

```text
cbb7368be24e7d8cda00645aa243976a606748e5445bed2b03817444acee86a7
```

Chiave e password protetta restano locali in `.signing`, escluse da Git
e dagli archivi. Conservarle per firmare gli aggiornamenti.

## REA sul pacchetto Android release

REA 6.7.0, `inspect-artifact`, sul pacchetto firmato con l'hash sopra.
Inventario: 609 nodi, 640 occorrenze, 639 relazioni.
Evidence: `ev_330d75940373627640bae14a356bbb9517b18999b83f38f60aee6809582f340e`.
Evidence inventario: `ev_009984fd49fa81ecb0ab4086176bd46e211a88239f156f77ff143764536bc0f5`.
JSON completo locale: `dist/REA-Android-0.2.0.json`.

È un inventario delle entry ZIP, non una prova funzionale o di firma.
REA segnala nomi coincidenti ignorando maiuscole/minuscole; i byte del blocco
firma APK non sono entry ZIP. La firma è stata verificata separatamente.

## iPhone

File: `TelaCut-0.2.0-iPhone.ipa`, 242.712 byte. Bundle `dev.telacut.mobile`,
versione 0.2.0, build 2. Minimo iOS 16.0.
Build release per dispositivo iPhoneOS, eseguibile Mach-O ARM64 da 1.076.000 byte;
non è una build per simulatore. Il bit eseguibile è conservato nell'archivio.
Xcode 16.4, SDK iOS 18.5, runner macOS 15.7.9.
Commit: `3fd11e91b0182196c81e73bd2633231338420af9`.
Verifica Android e iPhone completata con successo:
https://github.com/th1sable/telacut/actions/runs/39671973955

| Controllo | Risultato |
| --- | --- |
| Build release per iPhone e creazione IPA dopo i test | Superate |
| Test di modello, limiti, divisione, riordino e serializzazione | 6 superati |
| Salvataggio, riapertura ed eliminazione progetto | Superati |
| Esportazione MP4 reale con tagli, riordino, titolo e musica | Superata |
| 1080x1920, durata di 2 secondi, ordine clip, pixel del titolo, traccia audio | Verificati |
| Totale test su iPhone 16 Pro simulato, iOS 18.5 ARM64 | 8 superati, 0 falliti, 0 saltati |
| Integrità ZIP, Info.plist e presenza eseguibile nativo | Verificate |
| Installazione e utilizzo su iPhone fisico tramite AltStore | Non eseguiti |

Il fotogramma decodificato allegato al test è stato anche controllato visivamente:
clip blu, bande nere proporzionate al formato e titolo bianco leggibile in basso.
I test usano media sintetici originali, non video personali.

SHA-256 IPA:

```text
c57417f012595f0f245c90be0b6810c6fa1ea6b7baf8a6f3a85325baa29fd242
```

Il pacchetto non è firmato con un certificato personale Apple. AltStore Classic
deve applicare la firma durante l'installazione. La compilazione e i test non
sostituiscono la verifica sul proprio iPhone. Nel normale uso gratuito la firma
va rinnovata ogni 7 giorni; vedere `INSTALLAZIONE.txt`.

## REA sul pacchetto iPhone

REA 6.7.0, `inspect-artifact`, sull'IPA con l'hash sopra.
Inventario: 7 nodi, 7 occorrenze, 6 relazioni.
Evidence: `ev_976ea30fcce897f9ce6ef2d2b9a27004dfce597fc3f25239138ac18aaa51d353`.
Evidence inventario: `ev_09d1793f69431ada0458a567935690254d5cd35113a8cb5e1b13f23d37a523dc`.
JSON completo locale: `dist/REA-iPhone-0.2.0.json`.
L'inventario elenca le entry ZIP; non esegue l'app e non verifica la firma Apple.

## Limiti

Non verificati tutti i codec, HDR/4K, montaggi lunghi, spazio esaurito,
selettori Foto/File e condivisione su telefoni fisici.
Per questi controlli vedere `TEST-SU-TELEFONO.md`.
I limiti funzionali sono nel README. Nessun video personale è stato caricato.

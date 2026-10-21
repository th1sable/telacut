package dev.telacut.mobile;

import android.app.*;
import android.os.*;
import android.content.*;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.provider.*;
import android.text.InputFilter;
import android.text.InputType;
import android.view.*;
import android.widget.*;
import androidx.media3.common.*;
import androidx.media3.transformer.*;
import androidx.media3.ui.PlayerView;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

@androidx.annotation.OptIn(markerClass = {androidx.media3.common.util.UnstableApi.class, androidx.media3.common.util.ExperimentalApi.class})
public class MainActivity extends Activity {
    private static final int BG = 0xff101117, PANEL = 0xff1d1f2b, INK = 0xfff5f3ff, MUTED = 0xffa2a4b9, ACCENT = 0xffb7acff;
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ArrayDeque<Project> undo = new ArrayDeque<>();
    private Project p; private ProjectStore store;
    private CompositionPlayer player; private PlayerView playerView;
    private LinearLayout root; private TextView status; private Button cancel;
    private Transformer exporter; private File exportFile;
    private int selected; private boolean busy; private boolean destroyed;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state); store = new ProjectStore(this); p = new Project();
        try { File[] files = store.list(); if (files.length > 0) p = store.load(files[0]); }
        catch (Exception e) { message("L'ultimo progetto non è leggibile. I file precedenti non sono stati eliminati."); }
        screen(); refreshPreview();
    }
    private int dp(float n) { return (int) (getResources().getDisplayMetrics().density * n + .5f); }
    private GradientDrawable shape(int color, int stroke) {
        GradientDrawable d = new GradientDrawable(); d.setColor(color); d.setCornerRadius(dp(16));
        if (stroke != 0) d.setStroke(dp(1), stroke); return d;
    }
    private TextView label(String value, int size, int color) {
        TextView t = new TextView(this); t.setText(value); t.setTextSize(size); t.setTextColor(color);
        t.setPadding(dp(3), dp(7), dp(3), dp(7)); return t;
    }
    private Button button(String name, Runnable action) {
        Button b = new Button(this); b.setText(name); b.setAllCaps(false); b.setTextColor(INK); b.setTextSize(13);
        b.setBackground(shape(PANEL, 0)); b.setMinHeight(dp(48)); b.setPadding(dp(10), dp(5), dp(10), dp(5));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(48), 1); lp.setMargins(dp(3), dp(3), dp(3), dp(3)); b.setLayoutParams(lp);
        b.setOnClickListener(v -> { if (!busy) { try { action.run(); } catch (Exception e) { message(e.getMessage()); } } }); return b;
    }
    private LinearLayout row() { LinearLayout l = new LinearLayout(this); l.setOrientation(LinearLayout.HORIZONTAL); return l; }
    private void screen() {
        if (playerView != null) playerView.setPlayer(null);
        ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true); scroll.setBackgroundColor(BG);
        root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setPadding(dp(16), dp(12), dp(16), dp(24));
        scroll.addView(root); scroll.setOnApplyWindowInsetsListener((v, inset) -> {
            v.setPadding(0, inset.getSystemWindowInsetTop(), 0, inset.getSystemWindowInsetBottom()); return inset;
        }); setContentView(scroll);
        LinearLayout heading = row(); TextView logo = label("TelaCut", 28, INK); logo.setTypeface(null, Typeface.BOLD);
        heading.addView(logo, new LinearLayout.LayoutParams(0, -2, 1));
        TextView badge = label("STUDIO MOBILE", 10, ACCENT); heading.addView(badge); root.addView(heading);
        TextView sub = label("La tua storia, un taglio alla volta.", 13, MUTED); root.addView(sub);
        LinearLayout navigation = row(); navigation.addView(button("Progetti", this::projects));
        navigation.addView(button("Nuovo", () -> { save(); p = new Project(); selected = 0; undo.clear(); changed(); }));
        navigation.addView(button("Rinomina", this::rename)); root.addView(navigation);
        root.addView(label(p.name, 18, INK));
        FrameLayout frame = new FrameLayout(this); frame.setBackground(shape(0xff06070b, 0));
        playerView = new PlayerView(this); playerView.setPlayer(player); frame.addView(playerView, new FrameLayout.LayoutParams(-1, -1));
        if (p.clips.isEmpty()) {
            TextView empty = label("Il primo fotogramma\naspetta te.\n\nImporta un video per iniziare", 20, MUTED);
            empty.setGravity(Gravity.CENTER); frame.addView(empty, new FrameLayout.LayoutParams(-1, -1));
        }
        root.addView(frame, new LinearLayout.LayoutParams(-1, dp(255)));
        status = label(p.clips.size() + " clip  ·  " + seconds(p.durationMs()) + " s  ·  " + p.aspect + "  ·  1080p", 12, MUTED); root.addView(status);
        LinearLayout imports = row(); imports.addView(button("＋ Video", () -> pick("video/*", 10, true)));
        imports.addView(button("♫ Audio", () -> pick("audio/*", 11, false)));
        imports.addView(button("T Testo", this::editTitle)); root.addView(imports);
        TextView tl = label("TIMELINE", 11, ACCENT); tl.setLetterSpacing(.18f); root.addView(tl);
        HorizontalScrollView timeline = new HorizontalScrollView(this); LinearLayout cards = row();
        for (int i = 0; i < p.clips.size(); i++) {
            final int index = i; Project.Clip c = p.clips.get(i);
            TextView card = label(String.format(Locale.ITALIAN, "%02d  ▷\n%s\n%s s", i + 1, shortName(c.name), seconds(c.durationMs())), 13, INK);
            card.setPadding(dp(12), dp(8), dp(12), dp(8)); card.setBackground(shape(i == selected ? 0xff35304e : PANEL, i == selected ? ACCENT : 0));
            LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(dp(145), dp(90)); cp.setMargins(0, 0, dp(8), 0); cards.addView(card, cp);
            card.setContentDescription("Clip " + (i + 1) + ", " + c.name + ", " + seconds(c.durationMs()) + " secondi");
            card.setOnClickListener(v -> { if (busy) return; selected = index; if (player != null) player.seekTo(p.startMs(index)); screen(); });
        }
        timeline.addView(cards); root.addView(timeline);
        LinearLayout edit = row(); edit.addView(button("Taglia", this::trim));
        edit.addView(button("Dividi", this::split)); edit.addView(button("Elimina", this::remove)); root.addView(edit);
        LinearLayout order = row(); order.addView(button("← Sposta", () -> move(-1))); order.addView(button("Sposta →", () -> move(1)));
        order.addView(button("Annulla", () -> { if (!undo.isEmpty()) { p = undo.pop(); selected = 0; changed(); } })); root.addView(order);
        LinearLayout options = row(); options.addView(button("Formato " + p.aspect, this::aspect)); options.addView(button("Mix audio", this::audio)); root.addView(options);
        if (!p.musicFile.isEmpty()) root.addView(label("♫ " + p.musicName + " · ripetuto fino alla fine", 12, ACCENT));
        if (!p.title.isEmpty()) root.addView(label("T  " + p.title, 13, MUTED));
        Button export = button("Esporta MP4  ↗", this::export); export.setTextColor(BG); export.setBackground(shape(ACCENT, 0));
        root.addView(export, new LinearLayout.LayoutParams(-1, dp(54)));
        cancel = new Button(this); cancel.setText("Annulla esportazione"); cancel.setVisibility(busy && exporter != null ? View.VISIBLE : View.GONE);
        cancel.setOnClickListener(v -> cancelExport()); root.addView(cancel);
        root.addView(label("v0.2 · elaborazione sul dispositivo · nessun account\nTieni l'app aperta durante l'esportazione.", 11, MUTED));
    }
    private void remember() { undo.push(p.copy()); if (undo.size() > 30) undo.removeLast(); }
    private void save() { try { store.save(p); } catch (Exception e) { message("Salvataggio non riuscito: " + e.getMessage()); } }
    private void changed() { selected = Math.max(0, Math.min(selected, p.clips.size() - 1)); save(); screen(); refreshPreview(); }
    private void refreshPreview() {
        if (player != null) { playerView.setPlayer(null); player.release(); player = null; }
        if (p.clips.isEmpty() || busy) return;
        try {
            player = new CompositionPlayer.Builder(this).build(); playerView.setPlayer(player);
            player.addListener(new Player.Listener() { @Override public void onPlayerError(PlaybackException e) { message("Anteprima: " + e.getMessage()); } });
            player.setComposition(MediaEngine.composition(p)); player.prepare();
            if (selected > 0) player.seekTo(p.startMs(selected));
        } catch (Exception e) { message("Anteprima non disponibile: " + e.getMessage()); }
    }
    private void pick(String type, int code, boolean multiple) {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT).setType(type).addCategory(Intent.CATEGORY_OPENABLE);
        i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple); startActivityForResult(i, code);
    }
    @Override protected void onActivityResult(int code, int result, Intent data) {
        super.onActivityResult(code, result, data);
        if (result != RESULT_OK || data == null || (code != 10 && code != 11)) return;
        ArrayList<Uri> uris = new ArrayList<>();
        if (data.getClipData() != null) for (int i = 0; i < data.getClipData().getItemCount(); i++) uris.add(data.getClipData().getItemAt(i).getUri());
        else if (data.getData() != null) uris.add(data.getData());
        if (code == 10 && uris.size() + p.clips.size() > Project.MAX_CLIPS) { message("Massimo 60 clip"); return; }
        busy = true; if (player != null) player.pause(); status.setText("Importazione in corso…");
        io.execute(() -> {
            ArrayList<Project.Clip> imported = new ArrayList<>(); ArrayList<File> copied = new ArrayList<>();
            try {
                File mediaDir = new File(getFilesDir(), "media"); mediaDir.mkdirs();
                for (Uri uri : uris) {
                    String name = "Media";
                    try (Cursor c = getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
                        if (c != null && c.moveToFirst()) name = c.getString(0);
                    }
                    File file = new File(mediaDir, UUID.randomUUID() + (code == 10 ? ".video" : ".audio")); copied.add(file);
                    try (InputStream in = getContentResolver().openInputStream(uri); OutputStream out = new FileOutputStream(file)) {
                        if (in == null) throw new IOException("File non leggibile");
                        byte[] buffer = new byte[65536]; long total = 0; int count;
                        while ((count = in.read(buffer)) != -1) { total += count; if (total > 1_073_741_824L) throw new IOException("Limite: 1 GB per file"); out.write(buffer, 0, count); }
                    }
                    try (MediaMetadataRetriever meta = new MediaMetadataRetriever()) {
                        meta.setDataSource(file.getAbsolutePath());
                        if (code == 10 && !"yes".equals(meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO))) throw new IOException("Il file non contiene video");
                        if (code == 11 && !"yes".equals(meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO))) throw new IOException("Il file non contiene audio");
                        String duration = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                        if (duration == null) throw new IOException("Durata non leggibile");
                        imported.add(new Project.Clip(file.getAbsolutePath(), name, Long.parseLong(duration)));
                    }
                }
                main.post(() -> {
                    if (destroyed) { for (File f : copied) f.delete(); return; }
                    remember();
                    if (code == 10) { for (Project.Clip c : imported) p.add(c); }
                    else if (!imported.isEmpty()) { Project.Clip c = imported.get(0); p.musicFile = c.file; p.musicName = c.name; p.musicDurationMs = c.sourceDurationMs; }
                    busy = false; changed();
                });
            } catch (Exception e) {
                for (File f : copied) f.delete();
                main.post(() -> { if (!destroyed) { busy = false; screen(); message("Importazione annullata: " + e.getMessage()); } });
            }
        });
    }
    private Project.Clip current() { if (p.clips.isEmpty()) throw new IllegalArgumentException("Importa un video prima"); return p.clips.get(selected); }
    private EditText input(String value, boolean numeric) {
        EditText t = new EditText(this); t.setText(value); t.setTextColor(INK);
        t.setInputType(numeric ? InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL : InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        return t;
    }
    private void trim() {
        Project.Clip c = current(); LinearLayout content = new LinearLayout(this); content.setPadding(dp(20), 0, dp(20), 0); content.setOrientation(LinearLayout.VERTICAL);
        content.addView(label("Inizio e fine nel video originale (secondi)", 13, MUTED));
        EditText start = input(seconds(c.inMs), true), end = input(seconds(c.outMs), true); content.addView(start); content.addView(end);
        AlertDialog dialog = new AlertDialog.Builder(this).setTitle("Taglia clip").setView(content).setNegativeButton("Annulla", null).setPositiveButton("Applica", null).create();
        dialog.setOnShowListener(d -> dialog.getButton(DialogInterface.BUTTON_POSITIVE).setOnClickListener(v -> {
            try { long from = parseTime(start.getText().toString()), to = parseTime(end.getText().toString());
                Project.Clip check = c.copy(); check.trim(from, to); remember(); c.trim(from, to); changed(); dialog.dismiss();
            } catch (Exception e) { message(e.getMessage()); }
        })); dialog.show();
    }
    private static long parseTime(String s) {
        double n = Double.parseDouble(s.trim().replace(',', '.'));
        if (!Double.isFinite(n) || n < 0 || n > 86_400) throw new IllegalArgumentException("Tempo non valido");
        return Math.round(n * 1000);
    }
    private void split() {
        current(); long position = player == null ? 0 : player.getCurrentPosition(); long local = position - p.startMs(selected);
        Project candidate = p.copy(); candidate.split(selected, local); remember(); p = candidate; changed();
    }
    private void move(int delta) { current(); Project candidate = p.copy(); candidate.move(selected, delta); remember(); p = candidate; selected += delta; changed(); }
    private void remove() {
        Project.Clip c = current(); new AlertDialog.Builder(this).setTitle("Rimuovi questa clip?")
            .setMessage("Il video originale sul telefono non verrà eliminato.")
            .setNegativeButton("Annulla", null).setPositiveButton("Rimuovi", (d, w) -> { remember(); p.clips.remove(c); changed(); }).show();
    }
    private void editTitle() {
        EditText input = input(p.title, false); input.setFilters(new InputFilter[]{new InputFilter.LengthFilter(120)});
        new AlertDialog.Builder(this).setTitle("Titolo su tutto il video").setMessage("Fino a 120 caratteri. Lascia vuoto per rimuoverlo.")
            .setView(input).setNegativeButton("Annulla", null).setPositiveButton("Applica", (d, w) -> { remember(); p.title = input.getText().toString(); changed(); }).show();
    }
    private void rename() {
        EditText input = input(p.name, false); input.setFilters(new InputFilter[]{new InputFilter.LengthFilter(60)});
        new AlertDialog.Builder(this).setTitle("Nome progetto").setView(input).setNegativeButton("Annulla", null)
            .setPositiveButton("Salva", (d, w) -> { String name = input.getText().toString().trim(); if (!name.isEmpty()) { remember(); p.name = name; changed(); } }).show();
    }
    private void aspect() { new AlertDialog.Builder(this).setTitle("Formato di uscita").setItems(new String[]{"9:16 · Verticale", "16:9 · Orizzontale", "1:1 · Quadrato"}, (d, which) -> { remember(); p.aspect = new String[]{"9:16", "16:9", "1:1"}[which]; changed(); }).show(); }
    private void audio() {
        LinearLayout content = new LinearLayout(this); content.setOrientation(LinearLayout.VERTICAL); content.setPadding(dp(20), 0, dp(20), 0);
        CheckBox mute = new CheckBox(this); mute.setText("Silenzia l'audio dei video"); mute.setChecked(p.muteOriginal); content.addView(mute);
        content.addView(label("Volume musica aggiunta", 14, INK)); SeekBar gain = new SeekBar(this); gain.setMax(100); gain.setProgress(Math.round(p.musicVolume * 100)); content.addView(gain);
        new AlertDialog.Builder(this).setTitle("Mix audio").setView(content).setNegativeButton("Annulla", null)
            .setNeutralButton("Rimuovi musica", (d, w) -> { remember(); p.musicFile = ""; p.musicName = ""; p.musicDurationMs = 0; changed(); })
            .setPositiveButton("Applica", (d, w) -> { remember(); p.muteOriginal = mute.isChecked(); p.musicVolume = gain.getProgress() / 100f; changed(); }).show();
    }
    private void projects() {
        File[] files = store.list(); ArrayList<Project> projects = new ArrayList<>(); ArrayList<String> names = new ArrayList<>();
        for (File file : files) try { Project loaded = store.load(file); projects.add(loaded); names.add(loaded.name + " · " + seconds(loaded.durationMs()) + " s"); } catch (Exception ignored) { }
        if (names.isEmpty()) { message("Ancora nessun progetto salvato"); return; }
        new AlertDialog.Builder(this).setTitle("I tuoi progetti").setItems(names.toArray(new String[0]), (d, which) -> {
            Project target = projects.get(which);
            new AlertDialog.Builder(this).setTitle(target.name).setItems(new String[]{"Apri progetto", "Elimina progetto"}, (dialog, action) -> {
                if (action == 0) { save(); p = target; undo.clear(); selected = 0; changed(); }
                else new AlertDialog.Builder(this).setTitle("Eliminare il progetto?").setMessage("I video originali rimangono sul telefono.")
                    .setNegativeButton("Annulla", null).setPositiveButton("Elimina", (confirm, button) -> {
                        try { store.delete(target); if (p.id.equals(target.id)) { p = new Project(); undo.clear(); selected = 0; screen(); refreshPreview(); } }
                        catch (Exception e) { message(e.getMessage()); }
                    }).show();
            }).show();
        }).show();
    }
    private void export() {
        p.validate(); Composition composition = MediaEngine.composition(p); save();
        busy = true; if (player != null) { playerView.setPlayer(null); player.release(); player = null; }
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        exportFile = new File(getCacheDir(), "telacut-" + UUID.randomUUID() + ".mp4");
        exporter = new Transformer.Builder(this).setUsePlatformDiagnostics(false).setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(new Transformer.Listener() {
                @Override public void onCompleted(Composition c, ExportResult r) { publishVideo(exportFile); }
                @Override public void onError(Composition c, ExportResult r, ExportException e) {
                    if (exportFile != null) exportFile.delete(); endExport(); message("Esportazione non riuscita: " + e.getMessage());
                }
            }).build();
        screen(); cancel.setVisibility(View.VISIBLE);
        try { exporter.start(composition, exportFile.getAbsolutePath()); main.post(progress); }
        catch (Exception e) { exportFile.delete(); endExport(); message(e.getMessage()); }
    }
    private final Runnable progress = new Runnable() { public void run() {
        if (exporter == null || destroyed) return;
        ProgressHolder holder = new ProgressHolder();
        int state = exporter.getProgress(holder);
        status.setText(state == Transformer.PROGRESS_STATE_AVAILABLE ? "Esportazione " + holder.progress + "%" : "Preparazione del video…");
        main.postDelayed(this, 500);
    }};
    private void publishVideo(File file) {
        main.removeCallbacks(progress); exporter = null; cancel.setVisibility(View.GONE); status.setText("Salvataggio nella galleria…");
        io.execute(() -> {
            Uri output = null;
            try {
                ContentValues values = new ContentValues(); values.put(MediaStore.Video.Media.DISPLAY_NAME, "TelaCut-" + System.currentTimeMillis() + ".mp4");
                values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4"); values.put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/TelaCut"); values.put(MediaStore.Video.Media.IS_PENDING, 1);
                output = getContentResolver().insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
                if (output == null) throw new IOException("Galleria non disponibile");
                try (InputStream in = new FileInputStream(file); OutputStream out = getContentResolver().openOutputStream(output)) {
                    if (out == null) throw new IOException("Impossibile scrivere il video"); byte[] b = new byte[65536]; int n;
                    while ((n = in.read(b)) != -1) out.write(b, 0, n);
                }
                values.clear(); values.put(MediaStore.Video.Media.IS_PENDING, 0); getContentResolver().update(output, values, null, null);
                Uri finalOutput = output;
                main.post(() -> { if (!destroyed) { endExport(); new AlertDialog.Builder(this).setTitle("Video esportato")
                    .setMessage("Salvato in Movies/TelaCut. Nessuna filigrana aggiunta.").setNegativeButton("Chiudi", null)
                    .setPositiveButton("Condividi", (d, w) -> startActivity(Intent.createChooser(new Intent(Intent.ACTION_SEND).setType("video/mp4")
                        .putExtra(Intent.EXTRA_STREAM, finalOutput).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION), "Condividi video"))).show(); } });
            } catch (Exception e) {
                if (output != null) getContentResolver().delete(output, null, null);
                main.post(() -> { if (!destroyed) { endExport(); message("Salvataggio non riuscito: " + e.getMessage()); } });
            } finally { file.delete(); }
        });
    }
    private void cancelExport() { if (exporter != null) { exporter.cancel(); if (exportFile != null) exportFile.delete(); endExport(); message("Esportazione annullata"); } }
    private void endExport() { main.removeCallbacks(progress); exporter = null; busy = false; getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON); screen(); refreshPreview(); }
    private void message(String text) { Toast.makeText(this, text == null ? "Operazione non riuscita" : text, Toast.LENGTH_LONG).show(); }
    private static String seconds(long ms) { return String.format(Locale.ITALIAN, "%.2f", ms / 1000.0); }
    private static String shortName(String s) { return s.length() > 18 ? s.substring(0, 16) + "…" : s; }
    @Override protected void onStop() { super.onStop(); if (player != null) player.pause(); save(); }
    @Override protected void onDestroy() {
        destroyed = true; main.removeCallbacksAndMessages(null); if (exporter != null) exporter.cancel();
        if (player != null) player.release(); if (exporter != null && exportFile != null) exportFile.delete(); io.shutdown(); super.onDestroy();
    }
}

package dev.telacut.mobile;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.media.MediaMetadataRetriever;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.media3.common.MimeTypes;
import androidx.media3.transformer.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import java.io.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
@androidx.annotation.OptIn(markerClass = androidx.media3.common.util.UnstableApi.class)
public class VideoExportTest {
    private File fixture(Context context, String name) throws Exception {
        File destination = new File(context.getCacheDir(), "fixture-" + name);
        try (InputStream in = InstrumentationRegistry.getInstrumentation().getContext().getAssets().open(name);
             OutputStream out = new FileOutputStream(destination)) {
            byte[] bytes = new byte[65536]; int size;
            while ((size = in.read(bytes)) != -1) out.write(bytes, 0, size);
        }
        return destination;
    }

    @Test public void exportsRealVideoWithTrimReorderTitleAndMusic() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        File red = fixture(context, "red.mp4"), blue = fixture(context, "blue.mp4"), music = fixture(context, "music.wav");
        File output = new File(context.getCacheDir(), "export-test.mp4");
        if (output.exists() && !output.delete()) throw new IOException("Previous test output not removable");
        Project p = new Project();
        p.add(new Project.Clip(red.getAbsolutePath(), "Red", 2000));
        p.add(new Project.Clip(blue.getAbsolutePath(), "Blue", 2000));
        p.clips.get(0).trim(500, 1500); p.clips.get(1).trim(500, 1500); p.move(0, 1);
        p.title = "TelaCut export test"; p.muteOriginal = true;
        p.musicFile = music.getAbsolutePath(); p.musicDurationMs = 1000;
        CountDownLatch complete = new CountDownLatch(1);
        AtomicReference<Throwable> failure = new AtomicReference<>();
        AtomicReference<Transformer> transformer = new AtomicReference<>();
        try {
            InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> {
                try {
                    Transformer t = new Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC)
                        .addListener(new Transformer.Listener() {
                            @Override public void onCompleted(Composition c, ExportResult r) { complete.countDown(); }
                            @Override public void onError(Composition c, ExportResult r, ExportException e) { failure.set(e); complete.countDown(); }
                        }).build();
                    transformer.set(t); t.start(MediaEngine.composition(p), output.getAbsolutePath());
                } catch (Throwable e) { failure.set(e); complete.countDown(); }
            });
            assertTrue("Export timed out", complete.await(180, TimeUnit.SECONDS));
            if (failure.get() != null) throw new AssertionError("Export failed", failure.get());
            try (MediaMetadataRetriever meta = new MediaMetadataRetriever()) {
                meta.setDataSource(output.getAbsolutePath());
                assertEquals(2000, Long.parseLong(meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)), 120);
                assertEquals("1080", meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH));
                assertEquals("1920", meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT));
                assertEquals("yes", meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO));
                Bitmap frame = meta.getFrameAtTime(250000, MediaMetadataRetriever.OPTION_CLOSEST);
                assertNotNull(frame);
                int center = frame.getPixel(frame.getWidth() / 2, frame.getHeight() / 2);
                assertTrue("Reordered first clip should be blue", Color.blue(center) > Color.red(center) + 100);
                int white = 0;
                for (int y = 0; y < frame.getHeight(); y += 4) for (int x = 0; x < frame.getWidth(); x += 4) {
                    int c = frame.getPixel(x, y);
                    if (Color.red(c) > 210 && Color.green(c) > 210 && Color.blue(c) > 210) white++;
                }
                frame.recycle(); assertTrue("Title should appear in exported video", white > 30);
            }
        } finally {
            InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> { if (transformer.get() != null) transformer.get().cancel(); });
            for (File file : new File[]{red, blue, music, output}) file.delete();
        }
    }

    @Test public void savesReloadsAndDeletesProject() throws Exception {
        ProjectStore store = new ProjectStore(InstrumentationRegistry.getInstrumentation().getTargetContext());
        Project p = new Project(); p.name = "Persistence test"; p.title = "Saved title";
        try {
            store.save(p);
            Project reopened = null;
            for (File file : store.list()) if (file.getName().equals(p.id + ".json")) reopened = store.load(file);
            assertNotNull(reopened); assertEquals(p.title, reopened.title);
            store.delete(p);
            for (File file : store.list()) assertNotEquals(p.id + ".json", file.getName());
        } finally { store.delete(p); }
    }
}

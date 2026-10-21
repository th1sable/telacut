package dev.telacut.mobile;

import android.graphics.Color;
import android.net.Uri;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.*;
import androidx.media3.common.*;
import androidx.media3.common.audio.*;
import androidx.media3.effect.*;
import androidx.media3.transformer.*;
import com.google.common.collect.ImmutableList;
import java.io.File;
import java.util.ArrayList;

/** The same composition is used for playback and export. */
@androidx.annotation.OptIn(markerClass = {androidx.media3.common.util.UnstableApi.class, androidx.media3.common.util.ExperimentalApi.class})
final class MediaEngine {
    static Composition composition(Project p) {
        p.validate();
        ArrayList<EditedMediaItem> clips = new ArrayList<>();
        for (Project.Clip c : p.clips) {
            File source = new File(c.file);
            if (!source.isFile()) throw new IllegalArgumentException("File non disponibile: " + c.name);
            MediaItem item = new MediaItem.Builder().setUri(Uri.fromFile(source))
                .setClippingConfiguration(new MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(c.inMs).setEndPositionMs(c.outMs).build()).build();
            clips.add(new EditedMediaItem.Builder(item).setDurationUs(c.sourceDurationMs * 1000)
                .setRemoveAudio(p.muteOriginal).setFrameRate(30)
                .setEffects(new Effects(ImmutableList.of(), ImmutableList.of(
                    Presentation.createForWidthAndHeight(p.width(), p.height(), Presentation.LAYOUT_SCALE_TO_FIT))))
                .build());
        }
        ArrayList<EditedMediaItemSequence> tracks = new ArrayList<>();
        tracks.add(EditedMediaItemSequence.withAudioAndVideoFrom(clips));
        if (!p.musicFile.isEmpty()) {
            if (!new File(p.musicFile).isFile()) throw new IllegalArgumentException("Audio non disponibile");
            ChannelMixingAudioProcessor gain = new ChannelMixingAudioProcessor();
            // Normalize mono/stereo and common multichannel inputs to stereo before mixing.
            for (int n = 1; n <= 8; n++) {
                float[] coefficients = new float[n * 2];
                for (int c = 0; c < n; c++) {
                    if (n == 1) { coefficients[0] = p.musicVolume; coefficients[1] = p.musicVolume; }
                    else coefficients[c * 2 + c % 2] = p.musicVolume / ((n + 1) / 2f);
                }
                if (n == 2) { coefficients[0] = p.musicVolume; coefficients[3] = p.musicVolume; }
                gain.putChannelMixingMatrix(new ChannelMixingMatrix(n, 2, coefficients));
            }
            EditedMediaItem music = new EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(new File(p.musicFile))))
                .setDurationUs(p.musicDurationMs * 1000).setRemoveVideo(true)
                .setEffects(new Effects(ImmutableList.of(gain), ImmutableList.of())).build();
            tracks.add(EditedMediaItemSequence.withAudioFrom(ImmutableList.of(music)).buildUpon().setIsLooping(true).build());
        }
        ArrayList<Effect> effects = new ArrayList<>();
        if (!p.title.trim().isEmpty()) {
            SpannableString title = new SpannableString(wrapTitle(p.title.trim(), 26));
            title.setSpan(new ForegroundColorSpan(Color.WHITE), 0, title.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            title.setSpan(new BackgroundColorSpan(0xB0000000), 0, title.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            title.setSpan(new AbsoluteSizeSpan(48), 0, title.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
            StaticOverlaySettings settings = new StaticOverlaySettings.Builder()
                .setBackgroundFrameAnchor(0f, -.70f).setOverlayFrameAnchor(0f, 0f).build();
            effects.add(new OverlayEffect(ImmutableList.of(TextOverlay.createStaticTextOverlay(title, settings))));
        }
        return new Composition.Builder(tracks).setEffects(new Effects(ImmutableList.of(), effects))
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL).build();
    }
    static String wrapTitle(String text, int width) {
        StringBuilder out = new StringBuilder(); int column = 0;
        for (int offset = 0; offset < text.length();) {
            int cp = text.codePointAt(offset); offset += Character.charCount(cp);
            if (cp == '\n') { column = 0; out.append('\n'); continue; }
            if (column >= width) { out.append('\n'); column = 0; }
            out.appendCodePoint(cp); column++;
        }
        return out.toString();
    }
}

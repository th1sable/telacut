package dev.telacut.mobile;

import java.util.ArrayList;
import java.util.UUID;

/** Editing decisions, independent of Android and of decoder implementations. */
public final class Project {
    public static final int MAX_CLIPS = 60;
    public static final long MIN_CLIP_MS = 100;
    public String id = UUID.randomUUID().toString();
    public String name = "Il mio montaggio";
    public String title = "";
    public String aspect = "9:16";
    public String musicFile = "";
    public String musicName = "";
    public long musicDurationMs;
    public float musicVolume = .35f;
    public boolean muteOriginal;
    public final ArrayList<Clip> clips = new ArrayList<>();

    public static final class Clip {
        public String id, file, name;
        public long sourceDurationMs, inMs, outMs;
        public Clip(String file, String name, long duration) {
            if (duration < MIN_CLIP_MS) throw new IllegalArgumentException("Video troppo breve");
            id = UUID.randomUUID().toString(); this.file = file; this.name = name;
            sourceDurationMs = duration; outMs = duration;
        }
        public long durationMs() { return outMs - inMs; }
        public Clip copy() {
            Clip c = new Clip(file, name, sourceDurationMs);
            c.id = id; c.inMs = inMs; c.outMs = outMs; return c;
        }
        public void trim(long start, long end) {
            if (start < 0 || end > sourceDurationMs || end - start < MIN_CLIP_MS)
                throw new IllegalArgumentException("Intervallo non valido: minimo 0,1 secondi");
            inMs = start; outMs = end;
        }
    }
    public void add(Clip clip) {
        if (clips.size() >= MAX_CLIPS) throw new IllegalArgumentException("Massimo 60 clip per progetto");
        clips.add(clip);
    }
    public long durationMs() {
        long total = 0;
        for (Clip c : clips) total = Math.addExact(total, c.durationMs());
        return total;
    }
    public long startMs(int index) {
        if (index < 0 || index >= clips.size()) throw new IndexOutOfBoundsException();
        long start = 0;
        for (int i = 0; i < index; i++) start += clips.get(i).durationMs();
        return start;
    }
    public void split(int index, long localPositionMs) {
        Clip c = clips.get(index);
        if (clips.size() >= MAX_CLIPS) throw new IllegalArgumentException("Massimo 60 clip");
        if (localPositionMs < MIN_CLIP_MS || c.durationMs() - localPositionMs < MIN_CLIP_MS)
            throw new IllegalArgumentException("Sposta il cursore all'interno della clip");
        Clip right = c.copy(); right.id = UUID.randomUUID().toString();
        right.inMs = c.inMs + localPositionMs;
        c.outMs = right.inMs;
        clips.add(index + 1, right);
    }
    public void move(int index, int delta) {
        int destination = index + delta;
        if (index < 0 || index >= clips.size() || destination < 0 || destination >= clips.size())
            throw new IllegalArgumentException("La clip è già al bordo della timeline");
        Clip c = clips.remove(index); clips.add(destination, c);
    }
    public int width() { return aspect.equals("16:9") ? 1920 : 1080; }
    public int height() { return aspect.equals("9:16") ? 1920 : 1080; }
    public Project copy() {
        Project p = new Project(); p.id = id; p.name = name; p.title = title; p.aspect = aspect;
        p.musicFile = musicFile; p.musicName = musicName; p.musicDurationMs = musicDurationMs;
        p.musicVolume = musicVolume; p.muteOriginal = muteOriginal;
        for (Clip c : clips) p.clips.add(c.copy());
        return p;
    }
    public void validate() {
        if (clips.isEmpty()) throw new IllegalArgumentException("Importa almeno un video");
        if (clips.size() > MAX_CLIPS) throw new IllegalArgumentException("Troppe clip");
        if (!aspect.equals("9:16") && !aspect.equals("16:9") && !aspect.equals("1:1"))
            throw new IllegalArgumentException("Formato non valido");
        if (!Float.isFinite(musicVolume) || musicVolume < 0 || musicVolume > 1)
            throw new IllegalArgumentException("Volume non valido");
        if (!musicFile.isEmpty() && musicDurationMs < MIN_CLIP_MS)
            throw new IllegalArgumentException("Durata audio non valida");
        if (title.length() > 120) throw new IllegalArgumentException("Titolo troppo lungo");
        for (Clip c : clips) c.trim(c.inMs, c.outMs);
    }
}

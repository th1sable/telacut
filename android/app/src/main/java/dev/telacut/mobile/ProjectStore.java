package dev.telacut.mobile;

import android.content.Context;
import android.util.AtomicFile;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

final class ProjectStore {
    private final File root;
    ProjectStore(Context context) { root = new File(context.getFilesDir(), "projects"); root.mkdirs(); }
    void save(Project p) throws Exception {
        JSONObject j = new JSONObject();
        j.put("schema", 1).put("id", p.id).put("name", p.name).put("title", p.title)
            .put("aspect", p.aspect).put("musicFile", p.musicFile).put("musicName", p.musicName)
            .put("musicDurationMs", p.musicDurationMs).put("musicVolume", p.musicVolume)
            .put("muteOriginal", p.muteOriginal);
        JSONArray clips = new JSONArray();
        for (Project.Clip c : p.clips) clips.put(new JSONObject().put("id", c.id)
            .put("file", c.file).put("name", c.name).put("duration", c.sourceDurationMs)
            .put("in", c.inMs).put("out", c.outMs));
        j.put("clips", clips);
        AtomicFile file = new AtomicFile(new File(root, UUID.fromString(p.id) + ".json"));
        FileOutputStream out = null;
        try { out = file.startWrite(); out.write(j.toString().getBytes(StandardCharsets.UTF_8)); file.finishWrite(out); }
        catch (Exception e) { if (out != null) file.failWrite(out); throw e; }
    }
    Project load(File file) throws Exception {
        byte[] data = new AtomicFile(file).readFully();
        if (data.length > 2_000_000) throw new IOException("Progetto troppo grande");
        JSONObject j = new JSONObject(new String(data, StandardCharsets.UTF_8));
        if (j.getInt("schema") != 1) throw new IOException("Versione progetto non supportata");
        Project p = new Project(); p.id = UUID.fromString(j.getString("id")).toString();
        p.name = j.getString("name"); p.title = j.getString("title"); p.aspect = j.getString("aspect");
        p.musicFile = j.getString("musicFile"); p.musicName = j.getString("musicName");
        p.musicDurationMs = j.getLong("musicDurationMs"); p.musicVolume = (float) j.getDouble("musicVolume");
        p.muteOriginal = j.getBoolean("muteOriginal");
        JSONArray clips = j.getJSONArray("clips");
        for (int i = 0; i < clips.length(); i++) {
            JSONObject x = clips.getJSONObject(i);
            Project.Clip c = new Project.Clip(x.getString("file"), x.getString("name"), x.getLong("duration"));
            c.id = x.getString("id"); c.trim(x.getLong("in"), x.getLong("out")); p.add(c);
        }
        if (!p.clips.isEmpty()) p.validate();
        return p;
    }
    File[] list() {
        File[] files = root.listFiles((d, n) -> n.endsWith(".json"));
        if (files == null) return new File[0];
        Arrays.sort(files, Comparator.comparingLong(File::lastModified).reversed()); return files;
    }
    void delete(Project project) throws IOException {
        File file = new File(root, UUID.fromString(project.id) + ".json");
        new AtomicFile(file).delete();
        if (file.exists()) throw new IOException("Impossibile eliminare il progetto");
    }
}

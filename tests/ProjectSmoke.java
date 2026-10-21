import dev.telacut.mobile.Project;

/** No Android SDK required: exhaustive checks of split/trim boundary arithmetic. */
public class ProjectSmoke {
    private static int checks;
    static void check(boolean condition) { checks++; if (!condition) throw new AssertionError("Check " + checks); }
    public static void main(String[] args) {
        for (int duration = 200; duration <= 10000; duration += 100) {
            for (int position = 100; position <= duration - 100; position += 100) {
                Project p = new Project(); p.add(new Project.Clip("media", "Clip", duration + 700));
                p.clips.get(0).trim(700, duration + 700);
                Project original = p.copy(); p.split(0, position);
                check(p.durationMs() == duration);
                check(p.clips.get(0).outMs == p.clips.get(1).inMs);
                check(p.clips.get(0).durationMs() == position);
                check(p.clips.get(1).durationMs() == duration - position);
                check(original.clips.size() == 1 && original.clips.get(0).durationMs() == duration);
            }
        }
        Project p = new Project(); p.add(new Project.Clip("a", "a", 1000)); p.add(new Project.Clip("b", "b", 2000));
        p.move(0, 1); check(p.clips.get(0).file.equals("b")); check(p.startMs(1) == 2000);
        System.out.println(checks + " timeline checks passed");
    }
}

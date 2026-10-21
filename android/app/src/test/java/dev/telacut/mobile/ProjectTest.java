package dev.telacut.mobile;
import org.junit.Test;
import static org.junit.Assert.*;

public class ProjectTest {
    private Project project() { Project p = new Project(); p.add(new Project.Clip("one", "One", 10000)); p.add(new Project.Clip("two", "Two", 5000)); return p; }
    @Test public void durationAndOffsets() { Project p = project(); assertEquals(15000, p.durationMs()); assertEquals(10000, p.startMs(1)); }
    @Test public void splitPreservesDurationAndSource() { Project p = project(); p.clips.get(0).trim(1000, 9000); p.split(0, 3000); assertEquals(13000, p.durationMs()); assertEquals(4000, p.clips.get(0).outMs); assertEquals(4000, p.clips.get(1).inMs); assertNotEquals(p.clips.get(0).id, p.clips.get(1).id); }
    @Test public void copyDoesNotAliasClips() { Project p = project(); Project copy = p.copy(); copy.clips.get(0).trim(2000, 3000); assertEquals(10000, p.clips.get(0).durationMs()); }
    @Test public void movePreservesTimelineDuration() { Project p = project(); p.move(0, 1); assertEquals("Two", p.clips.get(0).name); assertEquals(15000, p.durationMs()); }
    @Test(expected = IllegalArgumentException.class) public void rejectsNegativeTrim() { project().clips.get(0).trim(-1, 1000); }
    @Test(expected = IllegalArgumentException.class) public void rejectsPastEnd() { project().clips.get(0).trim(0, 10001); }
    @Test(expected = IllegalArgumentException.class) public void rejectsZeroLength() { project().clips.get(0).trim(500, 500); }
    @Test(expected = IllegalArgumentException.class) public void rejectsSplitAtStart() { project().split(0, 0); }
    @Test(expected = IllegalArgumentException.class) public void rejectsSplitAtEnd() { project().split(0, 10000); }
    @Test(expected = IllegalArgumentException.class) public void rejectsMoveOutside() { project().move(0, -1); }
    @Test(expected = IllegalArgumentException.class) public void rejectsEmptyExport() { new Project().validate(); }
    @Test(expected = IllegalArgumentException.class) public void rejectsNaNVolume() { Project p = project(); p.musicVolume = Float.NaN; p.validate(); }
    @Test public void canvasSizes() { Project p = project(); assertEquals(1080, p.width()); assertEquals(1920, p.height()); p.aspect = "16:9"; assertEquals(1920, p.width()); assertEquals(1080, p.height()); p.aspect = "1:1"; assertEquals(p.width(), p.height()); }
    @Test public void boundsFailureIsAtomic() { Project p = project(); try { p.split(0, -100); fail(); } catch (IllegalArgumentException expected) {} assertEquals(2, p.clips.size()); assertEquals(15000, p.durationMs()); }
    @Test(expected = IllegalArgumentException.class) public void enforcesClipLimit() { Project p = new Project(); for (int i = 0; i < 61; i++) p.add(new Project.Clip("x", "x", 1000)); }
    @Test public void minimumSplit() { Project p = new Project(); p.add(new Project.Clip("x", "x", 200)); p.split(0, 100); assertEquals(100, p.clips.get(0).durationMs()); assertEquals(100, p.clips.get(1).durationMs()); }
}

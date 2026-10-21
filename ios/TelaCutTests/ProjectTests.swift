import XCTest
@testable import TelaCut

final class ProjectTests: XCTestCase {
    func fixture() -> Project {
        var p = Project()
        p.clips = [Clip(file: "one.mov", name: "One", sourceDuration: 10, end: 10), Clip(file: "two.mov", name: "Two", sourceDuration: 5, end: 5)]
        return p
    }
    func testSplitPreservesDuration() throws {
        var p = fixture(); try p.clips[0].trim(from: 1, to: 9); try p.split(index: 0, position: 3)
        XCTAssertEqual(p.duration, 13); XCTAssertEqual(p.clips[0].end, 4); XCTAssertEqual(p.clips[1].start, 4)
        XCTAssertNotEqual(p.clips[0].id, p.clips[1].id)
    }
    func testSplitOnSecondClipUsesGlobalCursor() throws {
        var p = fixture(); try p.split(index: 1, position: 12)
        XCTAssertEqual(p.clips[1].duration, 2); XCTAssertEqual(p.clips[2].duration, 3)
    }
    func testInvalidBounds() {
        var p = fixture()
        XCTAssertThrowsError(try p.clips[0].trim(from: -1, to: 4))
        XCTAssertThrowsError(try p.clips[0].trim(from: 0, to: 11))
        XCTAssertThrowsError(try p.split(index: 0, position: 0))
        XCTAssertThrowsError(try p.split(index: 0, position: .nan))
        XCTAssertEqual(p.duration, 15)
    }
    func testMoveAndValueCopy() throws {
        var p = fixture(); let before = p; try p.move(index: 0, delta: 1)
        XCTAssertEqual(p.clips[0].name, "Two"); XCTAssertEqual(before.clips[0].name, "One")
        XCTAssertEqual(p.duration, before.duration)
    }
    func testCodableRoundTrip() throws {
        let p = fixture(); let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: data), p)
    }
    func testRejectsEmptyProjectAndInvalidVolume() {
        XCTAssertThrowsError(try Project().validate()); var p = fixture(); p.musicVolume = .nan
        XCTAssertThrowsError(try p.validate())
    }
}

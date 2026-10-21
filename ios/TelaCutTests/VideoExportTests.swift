import XCTest
import AVFoundation
import UIKit
@testable import TelaCut

final class VideoExportTests: XCTestCase {
    private func fixture(_ name: String, extension fileExtension: String) throws -> URL {
        try MediaFiles.prepare()
        let source = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: fileExtension))
        let url = MediaFiles.media.appendingPathComponent(UUID().uuidString + "." + fileExtension)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    func testExportRendersCutsOrderTitleAndMusic() async throws {
        NSLog("TelaCut export test: loading original test videos")
        let red = try fixture("red", extension: "mp4")
        let blue = try fixture("blue", extension: "mp4")
        NSLog("TelaCut export test: preparing music and composition")
        let sound = try fixture("music", extension: "wav")
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { for url in [red, blue, sound, output] { try? FileManager.default.removeItem(at: url) } }
        var project = Project()
        project.clips = [try await VideoEngine.inspect(url: red, name: "Red"), try await VideoEngine.inspect(url: blue, name: "Blue")]
        try project.clips[0].trim(from: 0.5, to: 1.5)
        try project.clips[1].trim(from: 0.5, to: 1.5)
        try project.move(index: 0, delta: 1)
        project.title = "TelaCut export test"
        project.musicFile = sound.lastPathComponent
        project.muteOriginal = true
        let payload = try await VideoEngine.build(project, forExport: true)
        NSLog("TelaCut export test: composition ready, starting export")
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: payload.composition, presetName: AVAssetExportPresetHighestQuality))
        exporter.outputURL = output; exporter.outputFileType = .mp4
        exporter.videoComposition = payload.video; exporter.audioMix = payload.audio
        await exporter.export()
        NSLog("TelaCut export test: export finished with status %ld", exporter.status.rawValue)
        XCTAssertEqual(exporter.status, .completed, exporter.error?.localizedDescription ?? "Export incomplete")
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(duration.seconds, 2, accuracy: 0.12)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let video = try XCTUnwrap(videoTracks.first)
        let size = try await video.load(.naturalSize)
        XCTAssertEqual(size.width, 1080); XCTAssertEqual(size.height, 1920)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(audioTracks.count, 1)
        let generator = AVAssetImageGenerator(asset: asset)
        NSLog("TelaCut export test: checking decoded pixels")
        generator.appliesPreferredTrackTransform = true
        let frame = try generator.copyCGImage(at: CMTime(seconds: 0.25, preferredTimescale: 600), actualTime: nil)
        let attachment = XCTAttachment(image: UIImage(cgImage: frame))
        attachment.name = "Exported frame: reordered blue clip and title"
        attachment.lifetime = .keepAlways
        add(attachment)
        var bytes = [UInt8](repeating: 0, count: frame.width * frame.height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: frame.width, height: frame.height, bitsPerComponent: 8, bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        let center = ((frame.height / 2) * frame.width + frame.width / 2) * 4
        XCTAssertGreaterThan(Int(bytes[center + 2]), Int(bytes[center]) + 100, "First clip should be blue after reorder")
        var white = 0
        for pixel in stride(from: 0, to: bytes.count, by: 16) {
            if bytes[pixel] > 210 && bytes[pixel + 1] > 210 && bytes[pixel + 2] > 210 { white += 1 }
        }
        XCTAssertGreaterThan(white, 30, "Title must be rendered into the exported video")
    }

    func testSaveReopenAndDeleteProject() throws {
        var p = Project(); p.name = "Persistence test"; p.title = "Saved title"
        defer { try? MediaFiles.delete(p) }
        try MediaFiles.save(p)
        XCTAssertEqual(try MediaFiles.list().first(where: { $0.id == p.id }), p)
        try MediaFiles.delete(p)
        XCTAssertFalse(try MediaFiles.list().contains(where: { $0.id == p.id }))
    }
}

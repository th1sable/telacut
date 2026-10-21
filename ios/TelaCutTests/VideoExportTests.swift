import XCTest
import AVFoundation
import CoreImage
@testable import TelaCut

final class VideoExportTests: XCTestCase {
    private func movie(color: CIColor) async throws -> URL {
        try MediaFiles.prepare()
        let url = MediaFiles.media.appendingPathComponent(UUID().uuidString + ".mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? EditError.invalid("Fixture writer failed") }
        writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        let image = CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 180))
        for index in 0..<60 {
            let deadline = Date().addingTimeInterval(10)
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing, Date() < deadline else { throw EditError.invalid("Fixture writer stalled") }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool,
                  CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                  let pixel = buffer else { throw EditError.invalid("Fixture buffer failed") }
            context.render(image, to: pixel)
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(index), timescale: 30)) else {
                throw writer.error ?? EditError.invalid("Fixture frame failed")
            }
        }
        writer.endSession(atSourceTime: CMTime(seconds: 2, preferredTimescale: 600))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? EditError.invalid("Fixture movie failed") }
        return url
    }

    private func music() throws -> URL {
        let url = MediaFiles.media.appendingPathComponent(UUID().uuidString + ".caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
        buffer.frameLength = 48000
        for i in 0..<48000 { buffer.floatChannelData![0][i] = Float(sin(Double(i) * 2 * .pi * 220 / 48000)) * 0.2 }
        try file.write(from: buffer)
        return url
    }

    func testExportRendersCutsOrderTitleAndMusic() async throws {
        let red = try await movie(color: CIColor(red: 1, green: 0, blue: 0))
        let blue = try await movie(color: CIColor(red: 0, green: 0, blue: 1))
        let sound = try music()
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
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: payload.composition, presetName: AVAssetExportPresetHighestQuality))
        exporter.outputURL = output; exporter.outputFileType = .mp4
        exporter.videoComposition = payload.video; exporter.audioMix = payload.audio
        await exporter.export()
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
        generator.appliesPreferredTrackTransform = true
        let frame = try generator.copyCGImage(at: CMTime(seconds: 0.25, preferredTimescale: 600), actualTime: nil)
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

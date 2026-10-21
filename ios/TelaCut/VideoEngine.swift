import AVFoundation
import UIKit

struct RenderPayload {
    let composition: AVMutableComposition
    let video: AVMutableVideoComposition
    let audio: AVMutableAudioMix
}

enum VideoEngine {
    static func inspect(url: URL, name: String) async throws -> Clip {
        let asset = AVURLAsset(url: url)
        guard !(try await asset.loadTracks(withMediaType: .video)).isEmpty else { throw EditError.invalid("Il file non contiene video") }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration >= 0.1 else { throw EditError.invalid("Video troppo breve o non leggibile") }
        return Clip(file: url.lastPathComponent, name: name, sourceDuration: duration, end: duration)
    }
    @MainActor static func build(_ project: Project, forExport: Bool) async throws -> RenderPayload {
        try project.validate()
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw EditError.invalid("Motore video non disponibile") }
        var originalAudio: AVMutableCompositionTrack?
        var cursor = CMTime.zero
        var instructions: [AVVideoCompositionInstructionProtocol] = []
        let size = CGSize(width: CGFloat(project.canvas.width), height: CGFloat(project.canvas.height))
        for clip in project.clips {
            let asset = AVURLAsset(url: try MediaFiles.url(clip.file))
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw EditError.invalid("Traccia video mancante: \(clip.name)") }
            let range = CMTimeRange(start: CMTime(seconds: clip.start, preferredTimescale: 600), duration: CMTime(seconds: clip.duration, preferredTimescale: 600))
            try videoTrack.insertTimeRange(range, of: track, at: cursor)
            if !project.muteOriginal, let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                if originalAudio == nil { originalAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) }
                let available = try await audioTrack.load(.timeRange)
                let usable = CMTimeRangeGetIntersection(range, otherRange: available)
                if usable.duration > .zero {
                    try originalAudio?.insertTimeRange(usable, of: audioTrack, at: cursor + (usable.start - range.start))
                }
            }
            let natural = try await track.load(.naturalSize)
            let preferred = try await track.load(.preferredTransform)
            let oriented = CGRect(origin: .zero, size: natural).applying(preferred)
            guard oriented.width > 0, oriented.height > 0 else { throw EditError.invalid("Dimensioni video non valide") }
            let scale = min(size.width / oriented.width, size.height / oriented.height)
            let transform = preferred
                .concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: (size.width - oriented.width * scale) / 2, y: (size.height - oriented.height * scale) / 2))
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layer.setTransform(transform, at: cursor)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: range.duration)
            instruction.layerInstructions = [layer]
            instruction.backgroundColor = UIColor.black.cgColor
            instructions.append(instruction); cursor = cursor + range.duration
        }
        let mix = AVMutableAudioMix()
        var parameters: [AVAudioMixInputParameters] = []
        if let track = originalAudio { let parameter = AVMutableAudioMixInputParameters(track: track); parameter.setVolume(1, at: .zero); parameters.append(parameter) }
        if let musicFile = project.musicFile {
            let music = AVURLAsset(url: try MediaFiles.url(musicFile))
            guard let track = try await music.loadTracks(withMediaType: .audio).first,
                  let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw EditError.invalid("Audio non disponibile") }
            let available = try await track.load(.timeRange)
            guard available.duration.seconds.isFinite, available.duration.seconds >= 0.1 else { throw EditError.invalid("Audio troppo breve") }
            var point = CMTime.zero
            while point < cursor {
                let length = CMTimeMinimum(available.duration, cursor - point)
                try target.insertTimeRange(CMTimeRange(start: available.start, duration: length), of: track, at: point)
                point = point + length
            }
            let parameter = AVMutableAudioMixInputParameters(track: target)
            parameter.setVolume(project.musicVolume, at: .zero); parameters.append(parameter)
        }
        mix.inputParameters = parameters
        let video = AVMutableVideoComposition()
        video.renderSize = size; video.frameDuration = CMTime(value: 1, timescale: 30); video.instructions = instructions
        // CoreAnimationTool is export-only; the preview draws the title as a SwiftUI overlay.
        if forExport && !project.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // The title is static: rasterize it once so export does not depend on
            // CATextLayer's asynchronous display/transaction lifecycle.
            let font = UIFont.systemFont(ofSize: 48, weight: .semibold)
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .paragraphStyle: paragraph]
            let bounds = (project.title as NSString).boundingRect(with: CGSize(width: size.width * 0.8 - 20, height: 480), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            let height = min(500, ceil(bounds.height) + 20)
            let titleRect = CGRect(x: size.width * 0.1, y: size.height * 0.9 - height, width: size.width * 0.8, height: height)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
            let titleImage = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                UIColor.black.withAlphaComponent(0.7).setFill()
                UIBezierPath(roundedRect: titleRect, cornerRadius: 12).fill()
                (project.title as NSString).draw(with: titleRect.insetBy(dx: 10, dy: 10), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            }
            let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: size)
            parent.contents = titleImage.cgImage
            // Composite the title as a separate track. The post-processing API can
            // crash inside CoreAnimation/IOSurface on iOS simulators.
            let titleTrackID = composition.unusedTrackID()
            video.animationTool = AVVideoCompositionCoreAnimationTool(additionalLayer: parent, asTrackID: titleTrackID)
            for case let instruction as AVMutableVideoCompositionInstruction in instructions {
                let overlay = AVMutableVideoCompositionLayerInstruction()
                overlay.trackID = titleTrackID
                overlay.setOpacity(1, at: .zero)
                instruction.layerInstructions.insert(overlay, at: 0)
            }
        }
        return RenderPayload(composition: composition, video: video, audio: mix)
    }
}

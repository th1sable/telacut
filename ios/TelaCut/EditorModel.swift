import SwiftUI
import AVFoundation
import Photos

@MainActor final class EditorModel: ObservableObject {
    @Published var project = Project()
    @Published var player = AVPlayer()
    @Published var selected = 0
    @Published var busy = false
    @Published var status = "Tutto resta sul dispositivo"
    @Published var error: String?
    @Published var exportURL: URL?
    @Published var progress: Float = 0
    @Published var savedProjects: [Project] = []
    @Published var exporting = false
    private var history: [Project] = []
    private var previewTask: Task<Void, Never>?
    private var session: AVAssetExportSession?
    private var progressTask: Task<Void, Never>?
    private var previewGeneration = UUID()

    init() {
        do { savedProjects = try MediaFiles.list(); if let first = savedProjects.first { project = first } }
        catch { self.error = error.localizedDescription }
        preview()
    }
    var current: Clip? { project.clips.indices.contains(selected) ? project.clips[selected] : nil }
    var canUndo: Bool { !history.isEmpty }
    func save() {
        do { try MediaFiles.save(project); savedProjects = try MediaFiles.list() }
        catch { self.error = "Salvataggio non riuscito: \(error.localizedDescription)" }
    }
    func edit(_ change: (inout Project) throws -> Void) {
        guard !busy else { return }
        do {
            var candidate = project; try change(&candidate)
            if !candidate.clips.isEmpty { try candidate.validate() }
            history.append(project); if history.count > 30 { history.removeFirst() }
            project = candidate; selected = max(0, min(selected, project.clips.count - 1)); save(); preview()
        } catch { self.error = error.localizedDescription }
    }
    func undo() { guard !busy, let previous = history.popLast() else { return }; project = previous; selected = 0; save(); preview() }
    func newProject() { guard !busy else { return }; save(); project = Project(); selected = 0; history = []; save(); preview() }
    func open(_ p: Project) { guard !busy else { return }; save(); project = p; selected = 0; history = []; preview() }
    func select(_ index: Int) { selected = index; player.seek(to: CMTime(seconds: project.offset(of: index), preferredTimescale: 600)) }
    func split() { let position = player.currentTime().seconds; let index = selected; edit { try $0.split(index: index, position: position) } }
    func move(_ delta: Int) {
        let index = selected
        guard project.clips.indices.contains(index + delta) else { return }
        edit { try $0.move(index: index, delta: delta) }; selected = index + delta
    }
    func preview() {
        previewTask?.cancel(); player.pause(); player.replaceCurrentItem(with: nil)
        guard !project.clips.isEmpty else { return }
        let snapshot = project; let generation = UUID(); previewGeneration = generation
        previewTask = Task {
            do {
                let payload = try await VideoEngine.build(snapshot, forExport: false)
                guard !Task.isCancelled, generation == previewGeneration else { return }
                let item = AVPlayerItem(asset: payload.composition); item.videoComposition = payload.video; item.audioMix = payload.audio
                player.replaceCurrentItem(with: item)
                player.seek(to: CMTime(seconds: snapshot.offset(of: selected), preferredTimescale: 600))
            } catch { if !Task.isCancelled { self.error = "Anteprima: \(error.localizedDescription)" } }
        }
    }
    func importFiles(_ urls: [URL], audio: Bool) async {
        guard !busy else { return }; busy = true; player.pause(); status = "Importazione in corso…"
        var owned: [URL] = []
        do {
            guard audio || urls.count + project.clips.count <= 60 else { throw EditError.invalid("Massimo 60 clip") }
            for url in urls {
                let copy = try await Task.detached { try MediaFiles.copy(url) }.value
                owned.append(copy)
            }
            try await acceptOwned(owned, names: urls.map(\.lastPathComponent), audio: audio)
        } catch { for url in owned { try? FileManager.default.removeItem(at: url) }; self.error = error.localizedDescription }
        busy = false; status = "Progetto salvato sul dispositivo"
    }
    func acceptOwned(_ urls: [URL], names: [String], audio: Bool) async throws {
        var candidate = project
        if audio {
            guard let url = urls.first else { return }
            let asset = AVURLAsset(url: url)
            guard let track = try await asset.loadTracks(withMediaType: .audio).first,
                  try await track.load(.timeRange).duration.seconds >= 0.1 else { throw EditError.invalid("File audio non valido") }
            candidate.musicFile = url.lastPathComponent; candidate.musicName = names.first ?? "Musica"
        } else {
            guard candidate.clips.count + urls.count <= 60 else { throw EditError.invalid("Massimo 60 clip") }
            for (i, url) in urls.enumerated() { candidate.clips.append(try await VideoEngine.inspect(url: url, name: names[i])) }
        }
        history.append(project); if history.count > 30 { history.removeFirst() }
        project = candidate; save(); preview()
    }
    func export() {
        guard !busy else { return }
        do { try project.validate() } catch { self.error = error.localizedDescription; return }
        busy = true; exporting = true; progress = 0; status = "Preparazione esportazione…"; player.pause(); save()
        UIApplication.shared.isIdleTimerDisabled = true
        let snapshot = project
        Task {
            var destination: URL?
            defer {
                busy = false; exporting = false; session = nil; progressTask?.cancel()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            do {
                let payload = try await VideoEngine.build(snapshot, forExport: true)
                guard exporting else { throw CancellationError() }
                let directory = MediaFiles.documents.appendingPathComponent("Exports", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent("TelaCut-\(UUID().uuidString).mp4"); destination = url
                guard let exporter = AVAssetExportSession(asset: payload.composition, presetName: AVAssetExportPresetHighestQuality),
                      exporter.supportedFileTypes.contains(.mp4) else { throw EditError.invalid("Esportazione MP4 non disponibile per questi file") }
                session = exporter; exporter.outputURL = url; exporter.outputFileType = .mp4
                exporter.videoComposition = payload.video; exporter.audioMix = payload.audio; exporter.shouldOptimizeForNetworkUse = true
                status = "Esportazione MP4 in corso…"
                progressTask = Task { while !Task.isCancelled { progress = exporter.progress; try? await Task.sleep(nanoseconds: 400_000_000) } }
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    exporter.exportAsynchronously {
                        switch exporter.status {
                        case .completed: continuation.resume()
                        case .cancelled: continuation.resume(throwing: CancellationError())
                        default: continuation.resume(throwing: exporter.error ?? EditError.invalid("Esportazione non riuscita"))
                        }
                    }
                }
                exportURL = url; progress = 1; status = "Video esportato. Puoi condividerlo o salvarlo in Foto."
            } catch {
                if let url = destination { try? FileManager.default.removeItem(at: url) }
                if error is CancellationError { status = "Esportazione annullata" } else { self.error = error.localizedDescription; status = "Esportazione non riuscita" }
            }
        }
    }
    func cancelExport() { exporting = false; session?.cancelExport() }
    func saveToPhotos() async {
        guard let url = exportURL else { return }
        let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard auth == .authorized || auth == .limited else { error = "Consenti l'aggiunta a Foto nelle impostazioni oppure usa Condividi."; return }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }
            status = "Video salvato in Foto"
        } catch { self.error = error.localizedDescription }
    }
}

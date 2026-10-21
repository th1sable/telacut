import Foundation

enum EditError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

struct Clip: Codable, Identifiable, Equatable {
    var id = UUID()
    var file: String
    var name: String
    var sourceDuration: Double
    var start: Double = 0
    var end: Double
    var duration: Double { end - start }
    mutating func trim(from: Double, to: Double) throws {
        guard from.isFinite, to.isFinite, from >= 0, to <= sourceDuration,
              to - from >= 0.1 - 0.00001 else { throw EditError.invalid("Intervallo non valido: minimo 0,1 secondi") }
        start = from; end = to
    }
}

enum Canvas: String, Codable, CaseIterable, Identifiable {
    case portrait = "9:16", landscape = "16:9", square = "1:1"
    var id: String { rawValue }
    var width: Int { self == .landscape ? 1920 : 1080 }
    var height: Int { self == .portrait ? 1920 : 1080 }
}

struct Project: Codable, Identifiable, Equatable {
    var schema = 1
    var id = UUID()
    var name = "Il mio montaggio"
    var clips: [Clip] = []
    var title = ""
    var canvas: Canvas = .portrait
    var muteOriginal = false
    var musicFile: String?
    var musicName = ""
    var musicVolume: Float = 0.35
    var duration: Double { clips.reduce(0) { $0 + $1.duration } }
    func offset(of index: Int) -> Double { clips.prefix(index).reduce(0) { $0 + $1.duration } }
    mutating func split(index: Int, position: Double) throws {
        guard clips.indices.contains(index), clips.count < 60 else { throw EditError.invalid("Clip non disponibile o limite di 60 clip") }
        let local = position - offset(of: index)
        guard local.isFinite, local >= 0.1, clips[index].duration - local >= 0.1 else { throw EditError.invalid("Sposta il cursore all'interno della clip") }
        var right = clips[index]; right.id = UUID(); right.start += local
        clips[index].end = right.start; clips.insert(right, at: index + 1)
    }
    mutating func move(index: Int, delta: Int) throws {
        guard clips.indices.contains(index), clips.indices.contains(index + delta) else { throw EditError.invalid("La clip è già al bordo della timeline") }
        let clip = clips.remove(at: index); clips.insert(clip, at: index + delta)
    }
    func validate() throws {
        guard schema == 1, !clips.isEmpty, clips.count <= 60 else { throw EditError.invalid("Importa da 1 a 60 video") }
        guard title.count <= 120, musicVolume.isFinite, musicVolume >= 0, musicVolume <= 1 else { throw EditError.invalid("Titolo o volume non valido") }
        for var clip in clips { try clip.trim(from: clip.start, to: clip.end) }
    }
}

enum MediaFiles {
    static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var media: URL { documents.appendingPathComponent("Media", isDirectory: true) }
    static var projects: URL { documents.appendingPathComponent("Projects", isDirectory: true) }
    static func prepare() throws {
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        for var directory in [media, projects] {
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
        }
    }
    static func url(_ file: String) throws -> URL {
        guard !file.isEmpty, file == URL(fileURLWithPath: file).lastPathComponent, !file.contains("..") else { throw EditError.invalid("Percorso media non valido") }
        let url = media.appendingPathComponent(file)
        guard FileManager.default.fileExists(atPath: url.path) else { throw EditError.invalid("File media non più disponibile") }
        return url
    }
    static func copy(_ source: URL) throws -> URL {
        try prepare()
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 1_073_741_824 else { throw EditError.invalid("Limite: 1 GB per file") }
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let destination = media.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            let copiedSize = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard copiedSize <= 1_073_741_824 else { throw EditError.invalid("Limite: 1 GB per file") }
        }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        return destination
    }
    static func save(_ project: Project) throws {
        try prepare()
        let data = try JSONEncoder().encode(project)
        try data.write(to: projects.appendingPathComponent(project.id.uuidString + ".json"), options: .atomic)
    }
    static func list() throws -> [Project] {
        try prepare()
        let urls = try FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" }
            .sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url), data.count <= 2_000_000,
                  let project = try? JSONDecoder().decode(Project.self, from: data), project.schema == 1 else { return nil }
            return project
        }
    }
    static func delete(_ project: Project) throws {
        let file = projects.appendingPathComponent(project.id.uuidString + ".json")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}

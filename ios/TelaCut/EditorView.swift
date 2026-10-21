import SwiftUI
import AVKit
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

struct ImportedVideo: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in SentTransferredFile(video.url) } importing: { received in ImportedVideo(url: try MediaFiles.copy(received.file)) }
    }
}

struct EditorView: View {
    @StateObject private var model = EditorModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showFiles = false
    @State private var importingAudio = false
    @State private var showProjects = false
    @State private var showTitle = false
    @State private var showRename = false
    @State private var showTrim = false
    @State private var showAudio = false
    @State private var confirmRemove = false
    @State private var textDraft = ""
    @State private var nameDraft = ""
    private let accent = Color(red: 0.72, green: 0.67, blue: 1)
    private let panel = Color(red: 0.115, green: 0.12, blue: 0.17)
    private let background = Color(red: 0.063, green: 0.067, blue: 0.09)
    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("TelaCut").font(.system(size: 32, weight: .bold, design: .rounded))
                        Spacer(); Text("STUDIO MOBILE").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(accent)
                    }
                    Text("La tua storia, un taglio alla volta.").font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        tool("Progetti", "square.stack") { showProjects = true }
                        tool("Nuovo", "plus") { model.newProject() }
                        tool("Nome", "pencil") { nameDraft = model.project.name; showRename = true }
                    }
                    Text(model.project.name).font(.headline)
                    preview
                    HStack {
                        Text("\(model.project.clips.count) clip · \(model.project.duration, specifier: "%.2f") s")
                        Spacer(); Text("\(model.project.canvas.rawValue) · 1080p")
                    }.font(.caption).foregroundStyle(.secondary)
                    HStack {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: max(1, 60 - model.project.clips.count), matching: .videos) {
                            Label("Video", systemImage: "plus.rectangle.on.rectangle").frame(maxWidth: .infinity, minHeight: 48)
                        }.buttonStyle(.plain).background(panel, in: RoundedRectangle(cornerRadius: 14))
                        tool("Audio", "music.note") { importingAudio = true; showFiles = true }
                        tool("Testo", "textformat") { textDraft = model.project.title; showTitle = true }
                    }.font(.subheadline)
                    Button("Importa video da File") { importingAudio = false; showFiles = true }.font(.caption).foregroundStyle(accent)
                    Text("TIMELINE").font(.caption2.weight(.semibold)).tracking(3).foregroundStyle(accent)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(model.project.clips.enumerated()), id: \.element.id) { index, clip in
                                Button { model.select(index) } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack { Text(String(format: "%02d", index + 1)); Spacer(); Image(systemName: "play.rectangle") }
                                        Text(clip.name).lineLimit(1)
                                        Text("\(clip.duration, specifier: "%.2f") s").foregroundStyle(.secondary)
                                    }.font(.caption).padding(12).frame(width: 140, alignment: .leading)
                                        .background(index == model.selected ? accent.opacity(0.22) : panel, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(index == model.selected ? accent : .clear))
                                }.buttonStyle(.plain).accessibilityLabel("Clip \(index + 1), \(clip.name), \(clip.duration) secondi")
                            }
                        }
                    }
                    HStack {
                        tool("Taglia", "crop") { if model.current != nil { showTrim = true } }
                        tool("Dividi", "scissors") { model.split() }
                        tool("Rimuovi", "trash") { if model.current != nil { confirmRemove = true } }
                    }
                    HStack {
                        tool("Prima", "arrow.left") { model.move(-1) }
                        tool("Dopo", "arrow.right") { model.move(1) }
                        tool("Annulla", "arrow.uturn.backward") { model.undo() }.disabled(!model.canUndo)
                    }
                    HStack {
                        Menu {
                            ForEach(Canvas.allCases) { canvas in Button(canvas.rawValue) { model.edit { $0.canvas = canvas } } }
                        } label: { Label(model.project.canvas.rawValue, systemImage: "aspectratio").frame(maxWidth: .infinity, minHeight: 48) }
                            .background(panel, in: RoundedRectangle(cornerRadius: 14))
                        tool("Mix audio", "slider.horizontal.3") { showAudio = true }
                    }
                    if model.project.musicFile != nil { Label(model.project.musicName + " · in loop", systemImage: "music.note").font(.caption).foregroundStyle(accent) }
                    Button { model.export() } label: { Label("Esporta MP4", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity, minHeight: 56) }
                        .buttonStyle(.plain).foregroundStyle(background).background(accent, in: RoundedRectangle(cornerRadius: 18))
                        .disabled(model.project.clips.isEmpty)
                    if let url = model.exportURL {
                        HStack {
                            ShareLink(item: url) { Label("Condividi", systemImage: "square.and.arrow.up") }
                            Spacer(); Button("Salva in Foto") { Task { await model.saveToPhotos() } }
                        }.font(.subheadline).foregroundStyle(accent)
                    }
                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                    Text("v0.1 · elaborazione sul dispositivo · nessun account\nTieni l'app aperta durante l'esportazione.").font(.caption2).foregroundStyle(.secondary)
                }.padding(20)
            }.disabled(model.busy)
            if model.busy {
                Color.black.opacity(0.65).ignoresSafeArea()
                VStack(spacing: 20) {
                    if model.exporting { ProgressView(value: model.progress).tint(accent) } else { ProgressView().tint(accent) }
                    Text(model.status).multilineTextAlignment(.center)
                    if model.exporting { Button("Annulla esportazione", role: .cancel) { model.cancelExport() }.tint(accent) }
                }.padding(28).frame(maxWidth: 320).background(panel, in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .tint(accent)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: importingAudio ? [.audio] : [.movie], allowsMultipleSelection: !importingAudio) { result in
            switch result { case .success(let urls): Task { await model.importFiles(urls, audio: importingAudio) }; case .failure(let error): model.error = error.localizedDescription }
        }
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty, !model.busy else { return }
            model.busy = true; model.player.pause(); model.status = "Importazione dalla libreria Foto…"
            Task {
                var owned: [URL] = []
                do {
                    for item in items {
                        guard let video = try await item.loadTransferable(type: ImportedVideo.self) else { throw EditError.invalid("Video non leggibile") }
                        owned.append(video.url)
                    }
                    try await model.acceptOwned(owned, names: owned.enumerated().map { "Video \($0.offset + 1)" }, audio: false)
                } catch { for url in owned { try? FileManager.default.removeItem(at: url) }; model.error = error.localizedDescription }
                pickerItems = []; model.busy = false; model.status = "Progetto salvato sul dispositivo"
            }
        }
        .onChange(of: scenePhase) { phase in if phase != .active { model.player.pause(); model.save() } }
        .sheet(isPresented: $showProjects) {
            NavigationStack { List(model.savedProjects) { p in Button { model.open(p); showProjects = false } label: { VStack(alignment: .leading) { Text(p.name); Text("\(p.clips.count) clip · \(p.duration, specifier: "%.1f") s").font(.caption).foregroundStyle(.secondary) } } }
                .navigationTitle("I tuoi progetti").toolbar { Button("Chiudi") { showProjects = false } } }
        }
        .sheet(isPresented: $showTrim) { if let clip = model.current { TrimSheet(clip: clip) { from, to in let index = model.selected; model.edit { try $0.clips[index].trim(from: from, to: to) } } } }
        .sheet(isPresented: $showAudio) { AudioSheet(project: model.project) { mute, volume, remove in model.edit { $0.muteOriginal = mute; $0.musicVolume = volume; if remove { $0.musicFile = nil; $0.musicName = "" } } } }
        .alert("Titolo su tutto il video", isPresented: $showTitle) {
            TextField("Titolo, massimo 120 caratteri", text: $textDraft)
            Button("Applica") { model.edit { $0.title = String(textDraft.prefix(120)) } }; Button("Annulla", role: .cancel) {}
        } message: { Text("Lascia vuoto per rimuoverlo. Verrà incluso nel video esportato.") }
        .alert("Nome progetto", isPresented: $showRename) {
            TextField("Nome", text: $nameDraft)
            Button("Salva") { let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines); if !name.isEmpty { model.edit { $0.name = String(name.prefix(60)) } } }; Button("Annulla", role: .cancel) {}
        }
        .confirmationDialog("Rimuovere la clip dalla timeline? Il video originale non viene eliminato.", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Rimuovi clip", role: .destructive) { let index = model.selected; model.edit { if $0.clips.indices.contains(index) { $0.clips.remove(at: index) } } }
        }
        .alert("TelaCut", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    private func tool(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.caption).frame(maxWidth: .infinity, minHeight: 48) }
            .buttonStyle(.plain).background(panel, in: RoundedRectangle(cornerRadius: 14))
    }
    private var preview: some View {
        ZStack {
            Color.black
            if model.project.clips.isEmpty {
                VStack(spacing: 18) { Image(systemName: "play.rectangle.on.rectangle").font(.largeTitle).foregroundStyle(accent); Text("Il primo fotogramma\naspetta te.").font(.title3.weight(.medium)).multilineTextAlignment(.center); Text("Importa un video per iniziare").font(.caption).foregroundStyle(.secondary) }
            } else {
                VideoPlayer(player: model.player)
                if !model.project.title.isEmpty {
                    VStack { Spacer(); Text(model.project.title).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.center).padding(5).background(.black.opacity(0.7)).padding(.horizontal, 26).padding(.bottom, 48) }
                        .allowsHitTesting(false)
                }
            }
        }.frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct TrimSheet: View {
    let clip: Clip
    let apply: (Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var start: Double
    @State private var end: Double
    init(clip: Clip, apply: @escaping (Double, Double) -> Void) { self.clip = clip; self.apply = apply; _start = State(initialValue: clip.start); _end = State(initialValue: clip.end) }
    var body: some View {
        NavigationStack {
            Form {
                Text(clip.name)
                Section("Inizio · \(start, specifier: "%.2f") s") { Slider(value: $start, in: 0...max(0.001, end - 0.1), step: 0.01) }
                Section("Fine · \(end, specifier: "%.2f") s") { Slider(value: $end, in: min(start + 0.1, clip.sourceDuration)...clip.sourceDuration, step: 0.01) }
                Text("Durata finale: \(end - start, specifier: "%.2f") s")
                Text("I tempi si riferiscono al video originale, che rimane intatto.").font(.caption).foregroundStyle(.secondary)
            }.navigationTitle("Taglia clip").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Applica") { apply(start, end); dismiss() } }
            }
        }
    }
}

private struct AudioSheet: View {
    let apply: (Bool, Float, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mute: Bool
    @State private var volume: Float
    @State private var remove = false
    init(project: Project, apply: @escaping (Bool, Float, Bool) -> Void) { self.apply = apply; _mute = State(initialValue: project.muteOriginal); _volume = State(initialValue: project.musicVolume) }
    var body: some View {
        NavigationStack { Form {
            Toggle("Silenzia audio dei video", isOn: $mute)
            Section("Volume musica · \(Int(volume * 100))%") { Slider(value: $volume, in: 0...1) }
            Toggle("Rimuovi musica aggiunta", isOn: $remove)
            Text("La musica viene ripetuta fino alla fine del montaggio.").font(.caption)
        }.navigationTitle("Mix audio").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Applica") { apply(mute, volume, remove); dismiss() } }
        } }
    }
}

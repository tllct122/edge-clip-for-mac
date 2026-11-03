// EdgeClip — clipboard history that hides at the edge of your Mac screen.
// Hover the left edge (or press ⌥⌘V) to slide it out. Click a clip to copy it again.
// Star the ones you reuse. History lives in ~/EdgeClip/history.json — only on your Mac.
// Everything is customizable in Settings (⚙︎).

import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox
import CryptoKit
import ServiceManagement

// MARK: - Color helpers

extension Color {
    /// "RRGGBB" or "RRGGBBAA" (with or without #)
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        if s.count == 6 { s += "FF" }
        let v = UInt64(s, radix: 16) ?? 0x000000FF
        self.init(.sRGB,
                  red: Double((v >> 24) & 0xFF) / 255,
                  green: Double((v >> 16) & 0xFF) / 255,
                  blue: Double((v >> 8) & 0xFF) / 255,
                  opacity: Double(v & 0xFF) / 255)
    }

    /// Perceived brightness 0…1 of a "RRGGBB[AA]" string.
    static func luminance(hex: String) -> Double {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        if s.count == 6 { s += "FF" }
        let v = UInt64(s, radix: 16) ?? 0
        let r = Double((v >> 24) & 0xFF) / 255
        let g = Double((v >> 16) & 0xFF) / 255
        let b = Double((v >> 8) & 0xFF) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    var hex: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        let a = Int((ns.alphaComponent * 255).rounded())
        return String(format: "%02X%02X%02X%02X", r, g, b, a)
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Settings

enum FontChoice: String, CaseIterable {
    case mono, system, rounded, serif, custom
    var label: String {
        switch self {
        case .mono: return "Monospaced"
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .custom: return "Custom…"
        }
    }
}

enum WeightChoice: String, CaseIterable {
    case regular, medium, semibold, bold
    var label: String {
        switch self {
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        }
    }
    var weight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
    var bumped: WeightChoice {
        switch self {
        case .regular: return .medium
        case .medium: return .semibold
        case .semibold, .bold: return .bold
        }
    }
}

enum GlassChoice: String, CaseIterable {
    case clear, regular
    var label: String { self == .clear ? "Clear" : "Frosted" }
}

enum EdgeSide: String, CaseIterable {
    case left, right
    var label: String { self == .left ? "Left" : "Right" }
}

enum VPosition: String, CaseIterable {
    case top, middle, bottom
    var label: String { rawValue.capitalized }
}

/// Delete clips that aren't starred after a while.
enum AutoDelete: String, CaseIterable {
    case never, hour, day, week, month

    var label: String {
        switch self {
        case .never: return "Never"
        case .hour: return "1 hour"
        case .day: return "1 day"
        case .week: return "7 days"
        case .month: return "30 days"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .never: return nil
        case .hour: return 3600
        case .day: return 86_400
        case .week: return 7 * 86_400
        case .month: return 30 * 86_400
        }
    }
}

enum HotkeyChoice: String, CaseIterable {
    case optCmdV, ctrlOptV, ctrlCmdV, off

    var label: String {
        switch self {
        case .optCmdV: return "⌥⌘V"
        case .ctrlOptV: return "⌃⌥V"
        case .ctrlCmdV: return "⌃⌘V"
        case .off: return "Off"
        }
    }

    /// Carbon modifier flags
    var modifiers: UInt32? {
        switch self {
        case .optCmdV: return UInt32(optionKey | cmdKey)
        case .ctrlOptV: return UInt32(controlKey | optionKey)
        case .ctrlCmdV: return UInt32(controlKey | cmdKey)
        case .off: return nil
        }
    }
}

final class AppSettings: ObservableObject {
    private static let d = UserDefaults.standard

    enum Default {
        static let fontChoice = FontChoice.mono
        static let customFont = "Helvetica Neue"
        static let fontSize = 13.0
        static let weight = WeightChoice.medium
        static let textHex = "1C1C1EFF"
        static let pinnedTextHex = "000000E6"
        static let accentHex = "AF52DEFF"
        static let tintHex = "FFFFFFFF"
        static let tintStrength = 0.0
        static let bgOpacity = 1.0
        static let glass = GlassChoice.clear
        static let pinnedBolder = true
        static let halo = true
        static let width = 320.0
        static let height = 520.0
        static let corner = 18.0
        static let side = EdgeSide.left
        static let vPosition = VPosition.top
        static let historyLimit = 200
        static let autoDelete = AutoDelete.never
        static let previewLines = 2
        static let saveImages = true
        static let pasteDirectly = false
        static let hotkey = HotkeyChoice.optCmdV
        static let ignoredApps = "1Password, Bitwarden, Keychain Access, Passwords, Dashlane, LastPass"
        static let showAppIcons = true
    }

    @Published var fontChoice: FontChoice { didSet { save() } }
    @Published var customFont: String { didSet { save() } }
    @Published var fontSize: Double { didSet { save() } }
    @Published var weight: WeightChoice { didSet { save() } }
    @Published var textHex: String { didSet { save() } }
    @Published var pinnedTextHex: String { didSet { save() } }
    @Published var accentHex: String { didSet { save() } }
    @Published var tintHex: String { didSet { save() } }
    @Published var tintStrength: Double { didSet { save() } }
    @Published var bgOpacity: Double { didSet { save() } }
    @Published var glass: GlassChoice { didSet { save() } }
    @Published var pinnedBolder: Bool { didSet { save() } }
    @Published var halo: Bool { didSet { save() } }
    @Published var width: Double { didSet { save() } }
    @Published var height: Double { didSet { save() } }
    @Published var corner: Double { didSet { save() } }
    @Published var side: EdgeSide { didSet { save() } }
    @Published var vPosition: VPosition { didSet { save() } }
    @Published var historyLimit: Int { didSet { save() } }
    @Published var autoDelete: AutoDelete { didSet { save() } }
    @Published var previewLines: Int { didSet { save() } }
    @Published var saveImages: Bool { didSet { save() } }
    @Published var pasteDirectly: Bool { didSet { save() } }
    @Published var hotkey: HotkeyChoice { didSet { save() } }
    @Published var ignoredApps: String { didSet { save() } }
    @Published var showAppIcons: Bool { didSet { save() } }

    init() {
        let d = AppSettings.d
        fontChoice = FontChoice(rawValue: d.string(forKey: "fontChoice") ?? "") ?? Default.fontChoice
        customFont = d.string(forKey: "customFont") ?? Default.customFont
        fontSize = d.object(forKey: "fontSize") as? Double ?? Default.fontSize
        weight = WeightChoice(rawValue: d.string(forKey: "weight") ?? "") ?? Default.weight
        textHex = d.string(forKey: "textHex") ?? Default.textHex
        pinnedTextHex = d.string(forKey: "pinnedTextHex") ?? Default.pinnedTextHex
        accentHex = d.string(forKey: "accentHex") ?? Default.accentHex
        tintHex = d.string(forKey: "tintHex") ?? Default.tintHex
        tintStrength = d.object(forKey: "tintStrength") as? Double ?? Default.tintStrength
        bgOpacity = d.object(forKey: "bgOpacity") as? Double ?? Default.bgOpacity
        glass = GlassChoice(rawValue: d.string(forKey: "glass") ?? "") ?? Default.glass
        pinnedBolder = d.object(forKey: "pinnedBolder") as? Bool ?? Default.pinnedBolder
        halo = d.object(forKey: "halo") as? Bool ?? Default.halo
        width = d.object(forKey: "width") as? Double ?? Default.width
        height = d.object(forKey: "height") as? Double ?? Default.height
        corner = d.object(forKey: "corner") as? Double ?? Default.corner
        side = EdgeSide(rawValue: d.string(forKey: "side") ?? "") ?? Default.side
        vPosition = VPosition(rawValue: d.string(forKey: "vPosition") ?? "") ?? Default.vPosition
        historyLimit = d.object(forKey: "historyLimit") as? Int ?? Default.historyLimit
        autoDelete = AutoDelete(rawValue: d.string(forKey: "autoDelete") ?? "") ?? Default.autoDelete
        previewLines = d.object(forKey: "previewLines") as? Int ?? Default.previewLines
        saveImages = d.object(forKey: "saveImages") as? Bool ?? Default.saveImages
        pasteDirectly = d.object(forKey: "pasteDirectly") as? Bool ?? Default.pasteDirectly
        hotkey = HotkeyChoice(rawValue: d.string(forKey: "hotkey") ?? "") ?? Default.hotkey
        ignoredApps = d.string(forKey: "ignoredApps") ?? Default.ignoredApps
        showAppIcons = d.object(forKey: "showAppIcons") as? Bool ?? Default.showAppIcons
    }

    private func save() {
        let d = AppSettings.d
        d.set(fontChoice.rawValue, forKey: "fontChoice")
        d.set(customFont, forKey: "customFont")
        d.set(fontSize, forKey: "fontSize")
        d.set(weight.rawValue, forKey: "weight")
        d.set(textHex, forKey: "textHex")
        d.set(pinnedTextHex, forKey: "pinnedTextHex")
        d.set(accentHex, forKey: "accentHex")
        d.set(tintHex, forKey: "tintHex")
        d.set(tintStrength, forKey: "tintStrength")
        d.set(bgOpacity, forKey: "bgOpacity")
        d.set(glass.rawValue, forKey: "glass")
        d.set(pinnedBolder, forKey: "pinnedBolder")
        d.set(halo, forKey: "halo")
        d.set(width, forKey: "width")
        d.set(height, forKey: "height")
        d.set(corner, forKey: "corner")
        d.set(side.rawValue, forKey: "side")
        d.set(vPosition.rawValue, forKey: "vPosition")
        d.set(historyLimit, forKey: "historyLimit")
        d.set(autoDelete.rawValue, forKey: "autoDelete")
        d.set(previewLines, forKey: "previewLines")
        d.set(saveImages, forKey: "saveImages")
        d.set(pasteDirectly, forKey: "pasteDirectly")
        d.set(hotkey.rawValue, forKey: "hotkey")
        d.set(ignoredApps, forKey: "ignoredApps")
        d.set(showAppIcons, forKey: "showAppIcons")
    }

    func reset() {
        fontChoice = Default.fontChoice
        customFont = Default.customFont
        fontSize = Default.fontSize
        weight = Default.weight
        textHex = Default.textHex
        pinnedTextHex = Default.pinnedTextHex
        accentHex = Default.accentHex
        tintHex = Default.tintHex
        tintStrength = Default.tintStrength
        bgOpacity = Default.bgOpacity
        glass = Default.glass
        pinnedBolder = Default.pinnedBolder
        halo = Default.halo
        width = Default.width
        height = Default.height
        corner = Default.corner
        side = Default.side
        vPosition = Default.vPosition
        historyLimit = Default.historyLimit
        autoDelete = Default.autoDelete
        previewLines = Default.previewLines
        saveImages = Default.saveImages
        pasteDirectly = Default.pasteDirectly
        hotkey = Default.hotkey
        ignoredApps = Default.ignoredApps
        showAppIcons = Default.showAppIcons
    }

    /// White-ish text when pinned → switch the pinned panel to a dark look.
    var pinnedTextIsLight: Bool { Color.luminance(hex: pinnedTextHex) > 0.6 }

    /// App names / bundle IDs whose copies are never recorded.
    var ignoredList: [String] {
        ignoredApps.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    func font(_ size: CGFloat, _ w: Font.Weight) -> Font {
        switch fontChoice {
        case .mono: return .system(size: size, weight: w, design: .monospaced)
        case .system: return .system(size: size, weight: w, design: .default)
        case .rounded: return .system(size: size, weight: w, design: .rounded)
        case .serif: return .system(size: size, weight: w, design: .serif)
        case .custom:
            if customFont.isEmpty { return .system(size: size, weight: w) }
            return Font.custom(customFont, size: size).weight(w)
        }
    }
}

// MARK: - Model

enum ClipKind: String, Codable {
    case text, link, color, image, file

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .color: return "paintpalette"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    /// Figure out what a piece of copied text is.
    static func classify(_ s: String) -> ClipKind {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.contains(" "), !t.contains("\n"),
           let url = URL(string: t), let scheme = url.scheme?.lowercased(),
           ["http", "https", "mailto", "ftp"].contains(scheme), url.host != nil || scheme == "mailto" {
            return .link
        }
        if ClipKind.hexColor(t) != nil { return .color }
        return .text
    }

    /// "#FF8800", "ff8800", "#f80", "#FF880080" → "RRGGBBAA"
    static func hexColor(_ s: String) -> String? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("#") { t.removeFirst() } else if t.count != 6 && t.count != 8 { return nil }
        guard [3, 6, 8].contains(t.count), t.allSatisfy({ $0.isHexDigit }) else { return nil }
        // Without "#", only count it as a color if it mixes digits and letters
        // ("AF52DE" yes; "123456" or words like "facade" no)
        if !s.contains("#") && !(t.contains(where: { $0.isNumber }) && t.contains(where: { $0.isLetter })) {
            return nil
        }
        if t.count == 3 { t = t.map { "\($0)\($0)" }.joined() }
        if t.count == 6 { t += "FF" }
        return t.uppercased()
    }
}

enum ClipTab: String, CaseIterable {
    case all, text, links, images, colors

    var label: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .links: return "Links"
        case .images: return "Images"
        case .colors: return "Colors"
        }
    }

    func matches(_ k: ClipKind) -> Bool {
        switch self {
        case .all: return true
        case .text: return k == .text || k == .file
        case .links: return k == .link
        case .images: return k == .image
        case .colors: return k == .color
        }
    }
}

let isoFormatter = ISO8601DateFormatter()

struct ClipItem: Codable, Identifiable, Equatable {
    var id: String
    var kind: ClipKind
    var text: String?          // text, link, color, or file paths (one per line)
    var image: String?         // file name inside ~/EdgeClip/images
    var hash: String?          // for spotting duplicate images
    var app: String?           // app it was copied from
    var bundle: String?
    var created: String        // first copied
    var copied: String         // last copied
    var count: Int             // times copied
    var starred: String?       // when it was starred (nil = not starred)
    var label: String?         // optional name for a starred clip

    enum CodingKeys: String, CodingKey {
        case id, kind, text, image, hash, app, bundle, created, copied, count, starred, label
    }

    init(kind: ClipKind, text: String? = nil, image: String? = nil, hash: String? = nil,
         app: String? = nil, bundle: String? = nil) {
        let now = isoFormatter.string(from: Date())
        self.id = UUID().uuidString
        self.kind = kind
        self.text = text
        self.image = image
        self.hash = hash
        self.app = app
        self.bundle = bundle
        self.created = now
        self.copied = now
        self.count = 1
        self.starred = nil
        self.label = nil
    }

    // Lenient decoding: hand-written or AI-written entries only need "text".
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = isoFormatter.string(from: Date())
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        text = try? c.decode(String.self, forKey: .text)
        image = try? c.decode(String.self, forKey: .image)
        kind = (try? c.decode(ClipKind.self, forKey: .kind))
            ?? (image != nil ? .image : ClipKind.classify(text ?? ""))
        hash = try? c.decode(String.self, forKey: .hash)
        app = try? c.decode(String.self, forKey: .app)
        bundle = try? c.decode(String.self, forKey: .bundle)
        created = (try? c.decode(String.self, forKey: .created)) ?? now
        copied = (try? c.decode(String.self, forKey: .copied)) ?? created
        count = max(1, (try? c.decode(Int.self, forKey: .count)) ?? 1)
        starred = try? c.decode(String.self, forKey: .starred)
        label = try? c.decode(String.self, forKey: .label)
    }

    var isStarred: Bool { starred != nil }
    var copiedDate: Date { isoFormatter.date(from: copied) ?? Date() }

    /// Text used for searching
    var searchable: String {
        [text, label, app].compactMap { $0 }.joined(separator: " ").lowercased()
    }

    var fileURLs: [URL] {
        guard kind == .file, let t = text else { return [] }
        return t.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }
}

struct ClipFile: Codable {
    var clips: [ClipItem]
}

/// "now", "5m ago", "3h ago", "yesterday", "Oct 29"
func ago(_ d: Date, now: Date) -> String {
    let s = now.timeIntervalSince(d)
    let cal = Calendar.current
    if s < 60 { return "now" }
    if s < 3600 { return "\(Int(s / 60))m ago" }
    if cal.isDate(d, inSameDayAs: now) { return "\(Int(s / 3600))h ago" }
    if cal.isDateInYesterday(d) { return "yesterday" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US")
    f.dateFormat = cal.component(.year, from: d) == cal.component(.year, from: now) ? "MMM d" : "MMM d, yyyy"
    return f.string(from: d)
}

// MARK: - Store (reads / writes ~/EdgeClip/history.json)

final class ClipStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []     // most recent first
    let folderURL: URL
    let fileURL: URL
    let imagesURL: URL
    private var pendingSave: DispatchWorkItem?

    static let maxTextLength = 200_000
    static let maxImageBytes = 25_000_000

    init() {
        let fm = FileManager.default
        folderURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("EdgeClip", isDirectory: true)
        fileURL = folderURL.appendingPathComponent("history.json")
        imagesURL = folderURL.appendingPathComponent("images", isDirectory: true)
        try? fm.createDirectory(at: imagesURL, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: fileURL),
           let file = try? JSONDecoder().decode(ClipFile.self, from: data) {
            items = file.clips
        } else {
            items = ClipStore.welcome
            save()
        }
    }

    static let welcome: [ClipItem] = {
        var a = ClipItem(kind: .text, text: "Hi! Copy anything and it shows up here ✿\nClick a clip to copy it again.")
        a.starred = isoFormatter.string(from: Date())
        a.label = "welcome"
        let b = ClipItem(kind: .color, text: "#AF52DE")
        let c = ClipItem(kind: .link, text: "https://github.com/tllct122/edge-clip-for-mac")
        return [a, b, c]
    }()

    // MARK: Saving (debounced, so fast copying doesn't hammer the disk)

    private func save() {
        pendingSave?.cancel()
        let snapshot = items
        let url = fileURL
        let work = DispatchWorkItem {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            guard let data = try? enc.encode(ClipFile(clips: snapshot)) else { return }
            try? data.write(to: url, options: .atomic)
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    // MARK: Recording

    /// Adds a new clip, or moves an identical one to the top.
    func record(text: String, kind: ClipKind, app: String?, bundle: String?, limit: Int) {
        guard text.count <= ClipStore.maxTextLength else { return }
        if let i = items.firstIndex(where: { $0.kind == kind && $0.text == text }) {
            bump(at: i, app: app, bundle: bundle)
        } else {
            items.insert(ClipItem(kind: kind, text: text, app: app, bundle: bundle), at: 0)
        }
        trim(limit: limit)
        save()
    }

    func recordImage(_ png: Data, app: String?, bundle: String?, limit: Int) {
        guard png.count <= ClipStore.maxImageBytes else { return }
        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined().prefix(20)
        if let i = items.firstIndex(where: { $0.kind == .image && $0.hash == String(hash) }) {
            bump(at: i, app: app, bundle: bundle)
        } else {
            var item = ClipItem(kind: .image, hash: String(hash), app: app, bundle: bundle)
            let name = "\(item.id).png"
            guard (try? png.write(to: imagesURL.appendingPathComponent(name))) != nil else { return }
            item.image = name
            items.insert(item, at: 0)
        }
        trim(limit: limit)
        save()
    }

    private func bump(at i: Int, app: String?, bundle: String?) {
        var item = items.remove(at: i)
        item.copied = isoFormatter.string(from: Date())
        item.count += 1
        if app != nil { item.app = app; item.bundle = bundle }
        items.insert(item, at: 0)
    }

    /// Keeps every starred clip plus the newest `limit` others.
    func trim(limit: Int) {
        var kept = 0
        var removed: [ClipItem] = []
        items = items.filter { item in
            if item.isStarred { return true }
            kept += 1
            if kept <= limit { return true }
            removed.append(item)
            return false
        }
        removed.forEach(deleteImage)
    }

    // MARK: Actions

    /// Put a clip back on the clipboard.
    func copyToPasteboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .image:
            if let url = imageURL(item), let img = NSImage(contentsOf: url) {
                pb.writeObjects([img])
            }
        case .file:
            let urls = item.fileURLs
            pb.writeObjects(urls as [NSURL])
            pb.setString(item.text ?? "", forType: .string)
        default:
            pb.setString(item.text ?? "", forType: .string)
        }
    }

    /// Clip was used again → move it up (starred ones keep their spot).
    func markUsed(_ id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        if items[i].isStarred {
            items[i].copied = isoFormatter.string(from: Date())
            items[i].count += 1
        } else {
            bump(at: i, app: nil, bundle: nil)
        }
        save()
    }

    func toggleStar(_ id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].starred = items[i].isStarred ? nil : isoFormatter.string(from: Date())
        save()
    }

    func rename(_ id: String, _ label: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let t = label.trimmingCharacters(in: .whitespaces)
        items[i].label = t.isEmpty ? nil : t
        save()
    }

    func delete(_ id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        deleteImage(items.remove(at: i))
        save()
    }

    /// Removes clips that aren't starred and haven't been copied for `seconds`.
    @discardableResult
    func expire(after seconds: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-seconds)
        let old = items.filter { item in
            guard !item.isStarred, let last = isoFormatter.date(from: item.copied) else { return false }
            return last < cutoff
        }
        guard !old.isEmpty else { return 0 }
        let ids = Set(old.map { $0.id })
        items.removeAll { ids.contains($0.id) }
        old.forEach(deleteImage)
        save()
        return old.count
    }

    /// Removes everything except starred clips.
    func clearHistory() {
        let removed = items.filter { !$0.isStarred }
        items = items.filter { $0.isStarred }
        removed.forEach(deleteImage)
        save()
    }

    private func deleteImage(_ item: ClipItem) {
        if let url = imageURL(item) { try? FileManager.default.removeItem(at: url) }
        if let name = item.image { ThumbCache.shared.removeObject(forKey: name as NSString) }
    }

    func imageURL(_ item: ClipItem) -> URL? {
        item.image.map { imagesURL.appendingPathComponent($0) }
    }

    // MARK: Listing

    /// What the panel shows: starred clips (oldest star first), then history (newest first).
    func visible(query: String, tab: ClipTab) -> (starred: [ClipItem], recent: [ClipItem]) {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = items.filter { tab.matches($0.kind) && (q.isEmpty || $0.searchable.contains(q)) }
        let starred = shown.filter { $0.isStarred }.sorted { ($0.starred ?? "") < ($1.starred ?? "") }
        return (starred, shown.filter { !$0.isStarred })
    }

    var historyCount: Int { items.filter { !$0.isStarred }.count }
}

// MARK: - Image & app icon caches

final class ThumbCache {
    static let shared = NSCache<NSString, NSImage>()
}

func thumbnail(for item: ClipItem, store: ClipStore) -> NSImage? {
    guard let name = item.image else { return nil }
    if let img = ThumbCache.shared.object(forKey: name as NSString) { return img }
    guard let url = store.imageURL(item), let img = NSImage(contentsOf: url) else { return nil }
    ThumbCache.shared.setObject(img, forKey: name as NSString)
    return img
}

final class AppIconCache {
    static let shared = NSCache<NSString, NSImage>()

    static func icon(bundle: String?) -> NSImage? {
        guard let b = bundle else { return nil }
        if let img = shared.object(forKey: b as NSString) { return img }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        shared.setObject(img, forKey: b as NSString)
        return img
    }
}

// MARK: - Panel state

final class PanelState: ObservableObject {
    @Published var pinned = false          // panel kept open (📌)
    @Published var previewing = false      // true while the Settings window is open
    @Published var panelKey = false        // true while the panel itself has focus
    @Published var keyboardOpen = false    // opened with the hotkey → arrow keys + Return
    @Published var paused = false          // not recording new copies
    @Published var query = ""
    @Published var tab: ClipTab = .all
    @Published var selection = 0
    @Published var focusTick = 0           // bump to focus the search field
    @Published var flashID: String?        // shows "Copied ✓" on this clip
    @Published var flashText = "Copied ✓"
    var openSettings: (() -> Void)?
    var pick: ((ClipItem, Bool) -> Void)?  // (clip, chosen with keyboard)
}

// MARK: - Clear glass (no blur — you can see straight through it)

struct ClearGlass: View {
    let corner: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        ZStack {
            shape.fill(Color.white.opacity(0.05))
            shape.fill(LinearGradient(
                colors: [Color.white.opacity(0.22), Color.white.opacity(0.0), Color.white.opacity(0.0), Color.white.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.strokeBorder(LinearGradient(
                colors: [Color.white.opacity(0.9), Color.white.opacity(0.18), Color.white.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.3)
            shape.inset(by: 1.3).strokeBorder(Color.black.opacity(0.07), lineWidth: 0.6)
        }
    }
}

// MARK: - Palette (derived from settings + pinned state)

struct Palette {
    let s: AppSettings
    let pinned: Bool

    var primary: Color { Color(hex: pinned ? s.pinnedTextHex : s.textHex) }
    var secondary: Color { primary.opacity(0.62) }
    var accent: Color { Color(hex: s.accentHex) }
    /// Dark look: pinned with white-ish text
    var dark: Bool { pinned && s.pinnedTextIsLight }
    /// Fill for chips, fields and hover (contrasts with the text)
    var surface: Color { dark ? Color.black : Color.white }
    /// Glow behind text: dark glow for light text, white glow for dark text
    var halo: Color { dark ? Color.black.opacity(0.6) : Color.white.opacity(0.7) }
    var weight: Font.Weight { (pinned && s.pinnedBolder ? s.weight.bumped : s.weight).weight }

    func font(_ scale: CGFloat, bold: Bool = false) -> Font {
        s.font(CGFloat(s.fontSize) * scale, bold ? .bold : weight)
    }
}

// MARK: - Panel views

struct PanelView: View {
    @ObservedObject var store: ClipStore
    @ObservedObject var state: PanelState
    @ObservedObject var settings: AppSettings
    @FocusState private var searchFocused: Bool
    @State private var confirmClear = false
    @State private var now = Date()
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var pal: Palette { Palette(s: settings, pinned: state.pinned) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            searchField
            tabBar
            Divider().opacity(0.5)
            list
            footer
        }
        .padding(16)
        .frame(width: CGFloat(settings.width), height: CGFloat(settings.height))
        .shadow(color: (state.pinned && settings.halo) ? pal.halo : Color.clear, radius: 1.5)
        .background(
            ZStack {
                if state.pinned && !state.panelKey {
                    ClearGlass(corner: CGFloat(settings.corner))
                        .opacity(settings.bgOpacity)
                        .transition(.opacity)
                }
                RoundedRectangle(cornerRadius: CGFloat(settings.corner), style: .continuous)
                    .fill(Color(hex: settings.tintHex).opacity(settings.tintStrength))
            }
        )
        .animation(.easeInOut(duration: 0.2), value: state.pinned)
        .animation(.easeInOut(duration: 0.2), value: state.panelKey)
        .onReceive(clock) { now = $0 }
        .onChange(of: state.focusTick) { _ in searchFocused = true }
        .onChange(of: state.query) { _ in state.selection = 0 }
        .onChange(of: state.tab) { _ in state.selection = 0 }
    }

    private var header: some View {
        HStack {
            Button {
                state.openSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(pal.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Spacer()
            Button {
                state.paused.toggle()
            } label: {
                Text(state.paused ? "⏸ paused" : "clipboard")
                    .font(pal.font(0.93, bold: state.paused))
                    .foregroundColor(state.paused ? Color(hex: "FF9500") : pal.secondary)
            }
            .buttonStyle(.plain)
            .help(state.paused ? "Recording is paused — click to resume" : "Click to pause recording")
            Spacer()

            Button {
                state.pinned.toggle()
            } label: {
                Image(systemName: state.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(state.pinned ? pal.accent : pal.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Pin: keep open as Liquid Glass")
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(pal.secondary)
            TextField("Search clips", text: $state.query)
                .textFieldStyle(.plain)
                .font(pal.font(0.95))
                .foregroundColor(pal.primary)
                .focused($searchFocused)
            if !state.query.isEmpty {
                Button {
                    state.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(pal.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 9).fill(
            state.pinned ? pal.surface.opacity(pal.dark ? 0.3 : 0.35) : Color.primary.opacity(0.05)))
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(ClipTab.allCases, id: \.self) { t in
                Button {
                    state.tab = t
                } label: {
                    Text(t.label)
                        .font(pal.font(0.85, bold: state.tab == t))
                        .foregroundColor(state.tab == t ? pal.primary : pal.secondary)
                        .lineLimit(1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 7)
                        .background(
                            Capsule().fill(state.tab == t
                                ? pal.surface.opacity(pal.dark ? 0.35 : (state.pinned ? 0.55 : 0.75))
                                : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var list: some View {
        let v = store.visible(query: state.query, tab: state.tab)
        let flat = v.starred + v.recent
        if flat.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Text(state.query.isEmpty ? "nothing copied yet ✿" : "no matches")
                    .font(pal.font(1.0))
                    .foregroundColor(pal.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if !v.starred.isEmpty {
                            sectionTitle("★ starred")
                            ForEach(Array(v.starred.enumerated()), id: \.element.id) { i, item in
                                row(item, index: i)
                            }
                            if !v.recent.isEmpty { sectionTitle("recent").padding(.top, 8) }
                        }
                        ForEach(Array(v.recent.enumerated()), id: \.element.id) { i, item in
                            row(item, index: v.starred.count + i)
                        }
                    }
                    .padding(.vertical, 2)
                    .animation(.easeOut(duration: 0.15), value: store.items)
                }
                .onChange(of: state.selection) { sel in
                    guard state.keyboardOpen, flat.indices.contains(sel) else { return }
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(flat[sel].id, anchor: .center) }
                }
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(pal.font(0.9, bold: true))
            .foregroundColor(pal.primary)
            .padding(.leading, 2)
            .padding(.bottom, 2)
    }

    private func row(_ item: ClipItem, index: Int) -> some View {
        ClipRow(item: item, store: store, state: state, pal: pal, now: now,
                index: index, selected: state.keyboardOpen && state.selection == index)
            .id(item.id)
    }

    private var footer: some View {
        HStack {
            Text("\(store.historyCount) clip\(store.historyCount == 1 ? "" : "s")")
                .font(pal.font(0.8))
                .foregroundColor(pal.secondary)
            Spacer()
            if store.historyCount > 0 {
                Button {
                    if confirmClear {
                        store.clearHistory()
                        confirmClear = false
                    } else {
                        confirmClear = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmClear = false }
                    }
                } label: {
                    Text(confirmClear ? "click again to clear" : "clear")
                        .font(pal.font(0.8, bold: confirmClear))
                        .foregroundColor(confirmClear ? Color(hex: "FF3B30") : pal.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear history (starred clips stay)")
            }
        }
    }
}

struct ClipRow: View {
    let item: ClipItem
    @ObservedObject var store: ClipStore
    @ObservedObject var state: PanelState
    let pal: Palette
    let now: Date
    let index: Int
    let selected: Bool
    @State private var hover = false
    @State private var renaming = false
    @State private var newLabel = ""

    private var flashing: Bool { state.flashID == item.id }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            leading
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                if renaming {
                    TextField("Name this clip", text: $newLabel)
                        .textFieldStyle(.plain)
                        .font(pal.font(0.95, bold: true))
                        .foregroundColor(pal.primary)
                        .onSubmit {
                            store.rename(item.id, newLabel)
                            renaming = false
                        }
                } else if let label = item.label {
                    Text(label)
                        .font(pal.font(0.95, bold: true))
                        .foregroundColor(pal.primary)
                        .lineLimit(1)
                }
                preview
                meta
            }

            Spacer(minLength: 0)

            if hover || item.isStarred {
                Button {
                    store.toggleStar(item.id)
                } label: {
                    Image(systemName: item.isStarred ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(item.isStarred ? pal.accent : pal.secondary)
                }
                .buttonStyle(.plain)
                .help(item.isStarred ? "Unstar" : "Star — starred clips are never cleared")
            } else if state.keyboardOpen && index < 9 {
                Text("⌘\(index + 1)")
                    .font(pal.font(0.75))
                    .foregroundColor(pal.secondary.opacity(0.8))
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(rowFill))
        .overlay(alignment: .center) {
            if flashing {
                Text(state.flashText)
                    .font(pal.font(0.85, bold: true))
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(pal.accent))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.15), value: flashing)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { if !renaming { state.pick?(item, false) } }
        .contextMenu {
            Button("Copy") { state.pick?(item, false) }
            Button(item.isStarred ? "Unstar" : "Star") { store.toggleStar(item.id) }
            Button(item.label == nil ? "Name…" : "Rename…") {
                newLabel = item.label ?? ""
                renaming = true
            }
            if item.kind == .link, let t = item.text, let url = URL(string: t) {
                Button("Open Link") { NSWorkspace.shared.open(url) }
            }
            if item.kind == .file, !item.fileURLs.isEmpty {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(item.fileURLs) }
            }
            if item.kind == .image, let url = store.imageURL(item) {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            Divider()
            Button("Delete") { store.delete(item.id) }
        }
    }

    private var rowFill: Color {
        if selected { return pal.accent.opacity(0.2) }
        if hover { return (pal.pinned ? pal.surface : Color.primary).opacity(pal.pinned ? 0.3 : 0.06) }
        return .clear
    }

    @ViewBuilder
    private var leading: some View {
        switch item.kind {
        case .color:
            Circle()
                .fill(Color(hex: ClipKind.hexColor(item.text ?? "") ?? "000000"))
                .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                .frame(width: 16, height: 16)
        case .image:
            if let img = thumbnail(for: item, store: store) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo").foregroundColor(pal.secondary)
            }
        default:
            Image(systemName: item.kind.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(item.kind == .link ? pal.accent : pal.secondary)
                .frame(width: 16)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            Text("Image")
                .font(pal.font(1.0))
                .foregroundColor(pal.primary)
        case .file:
            let urls = item.fileURLs
            let first = urls.first?.lastPathComponent ?? "File"
            Text(urls.count > 1 ? "\(first) + \(urls.count - 1) more" : first)
                .font(pal.font(1.0))
                .foregroundColor(pal.primary)
                .lineLimit(1)
        default:
            Text(String((item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(600)))
                .font(pal.font(1.0))
                .foregroundColor(item.kind == .link ? pal.accent : pal.primary)
                .lineLimit(max(1, pal.s.previewLines))
                .truncationMode(.tail)
        }
    }

    private var meta: some View {
        HStack(spacing: 4) {
            if pal.s.showAppIcons, let icon = AppIconCache.icon(bundle: item.bundle) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 11, height: 11)
            }
            Text(metaText)
                .font(pal.font(0.78))
                .foregroundColor(pal.secondary)
                .lineLimit(1)
        }
    }

    private var metaText: String {
        var parts: [String] = []
        if let app = item.app { parts.append(app) }
        parts.append(ago(item.copiedDate, now: now))
        if item.count > 1 { parts.append("\(item.count)×") }
        if item.kind == .text, let t = item.text, t.count > 120 { parts.append("\(t.count) chars") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Settings window

struct SettingsView: View {
    @ObservedObject var s: AppSettings
    let glassAvailable: Bool
    private let families = NSFontManager.shared.availableFontFamilies.sorted()

    private func color(_ hex: Binding<String>) -> Binding<Color> {
        Binding(get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.hex })
    }

    private func sliderRow(_ title: String, _ value: Binding<Double>,
                           _ range: ClosedRange<Double>, step: Double,
                           _ format: @escaping (Double) -> String) -> some View {
        HStack {
            Text(title).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(format(value.wrappedValue))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }

    /// Small color chip button that sets the pinned text color.
    private func swatch(_ name: String, _ hex: String) -> some View {
        Button {
            s.pinnedTextHex = hex
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: hex))
                    .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                    .frame(width: 14, height: 14)
                Text(name)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Capsule().stroke(s.pinnedTextHex == hex ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    /// EdgeTodo uses the right edge — used to warn about overlapping panels.
    private var edgeTodoInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.local.edgetodo") != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Changes apply live — the panel stays open while this window is open.")
                    .font(.callout)
                    .foregroundColor(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Keep the last").frame(width: 120, alignment: .leading)
                            Stepper(value: $s.historyLimit, in: 20...1000, step: 20) {
                                Text("\(s.historyLimit) clips").foregroundColor(.secondary)
                            }
                        }
                        Picker("Delete unstarred clips after", selection: $s.autoDelete) {
                            ForEach(AutoDelete.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        Text("Counted from the last time a clip was copied. Starred clips are never removed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Open with shortcut", selection: $s.hotkey) {
                            ForEach(HotkeyChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Toggle("Paste right away when I pick a clip", isOn: $s.pasteDirectly)
                        if s.pasteDirectly {
                            Text("Needs Accessibility access: System Settings → Privacy & Security → Accessibility → turn on EdgeClip. Without it, clips are copied and you press ⌘V yourself.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Toggle("Save copied images", isOn: $s.saveImages)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Never record copies from these apps (comma separated):")
                            TextField("1Password, Keychain Access", text: $s.ignoredApps)
                                .textFieldStyle(.roundedBorder)
                            Text("Passwords that password managers mark as private are always skipped.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                } label: {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Font", selection: $s.fontChoice) {
                            ForEach(FontChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        if s.fontChoice == .custom {
                            Picker("Family", selection: $s.customFont) {
                                ForEach(families, id: \.self) { Text($0).tag($0) }
                            }
                        }
                        Picker("Weight", selection: $s.weight) {
                            ForEach(WeightChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        sliderRow("Size", $s.fontSize, 10...20, step: 0.5) { String(format: "%.1f pt", $0) }
                        HStack {
                            Text("Preview lines").frame(width: 120, alignment: .leading)
                            Stepper(value: $s.previewLines, in: 1...6) {
                                Text("\(s.previewLines)").foregroundColor(.secondary)
                            }
                        }
                        Toggle("Show app icons", isOn: $s.showAppIcons)
                    }
                    .padding(8)
                } label: {
                    Label("Text", systemImage: "textformat")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        ColorPicker("Text color", selection: color($s.textHex), supportsOpacity: true)
                        ColorPicker("Text color when pinned", selection: color($s.pinnedTextHex), supportsOpacity: true)
                        HStack(spacing: 8) {
                            Text("Quick pick:").foregroundColor(.secondary)
                            swatch("Dark", "000000E6")
                            swatch("White", "FFFFFFFF")
                            Spacer()
                        }
                        .font(.callout)
                        ColorPicker("Accent (stars, links, selection)", selection: color($s.accentHex), supportsOpacity: false)
                        ColorPicker("Background tint", selection: color($s.tintHex), supportsOpacity: false)
                        sliderRow("Tint strength", $s.tintStrength, 0...0.8, step: 0.01, percent)
                    }
                    .padding(8)
                } label: {
                    Label("Colors", systemImage: "paintpalette")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        sliderRow("Opacity", $s.bgOpacity, 0.2...1, step: 0.01, percent)
                        if glassAvailable {
                            Picker("Glass when focused", selection: $s.glass) {
                                ForEach(GlassChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        } else {
                            Text("Liquid Glass needs macOS 26 or later.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Toggle("Bolder text when pinned", isOn: $s.pinnedBolder)
                        Toggle("Glow behind text when pinned (white for dark text, dark for white text)", isOn: $s.halo)
                    }
                    .padding(8)
                } label: {
                    Label("Background", systemImage: "square.on.square")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Screen edge", selection: $s.side) {
                            ForEach(EdgeSide.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Position", selection: $s.vPosition) {
                            ForEach(VPosition.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if s.side == .right && edgeTodoInstalled && s.vPosition == .top {
                            Text("EdgeTodo also sits at the top of the right edge, so the two panels will overlap. Choose Left, or move EdgeClip to the bottom.")
                                .font(.caption)
                                .foregroundColor(Color(hex: "FF9500"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        sliderRow("Width", $s.width, 260...480, step: 10) { "\(Int($0))" }
                        sliderRow("Height", $s.height, 320...800, step: 10) { "\(Int($0))" }
                        sliderRow("Corner radius", $s.corner, 0...32, step: 1) { "\(Int($0))" }
                    }
                    .padding(8)
                } label: {
                    Label("Size & Position", systemImage: "rectangle.portrait")
                }

                HStack {
                    Spacer()
                    Button("Reset to Defaults") { s.reset() }
                }
            }
            .padding(20)
        }
        .frame(width: 460, height: 720)
    }
}

// MARK: - Global hotkey (Carbon — needs no extra permission)

final class HotKey {
    nonisolated(unsafe) static var action: (@MainActor () -> Void)?
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                Task { @MainActor in HotKey.action?() }
                return noErr
            }, 1, &spec, nil, &handler)
        }
        let id = EventHotKeyID(signature: OSType(0x45434C50), id: 1)   // "ECLP"
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let r = ref { UnregisterEventHotKey(r) }
        ref = nil
    }
}

// MARK: - Window plumbing

final class EdgePanel: NSPanel {
    /// Lets the app handle arrow keys / Return / Esc before the search field does.
    var keyHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let h = keyHandler, h(event) { return }
        super.sendEvent(event)
    }
}

final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

func roundedMask(radius: CGFloat) -> NSImage {
    let r = max(radius, 0.5)
    let edge = r * 2 + 1
    let img = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
        NSColor.black.set()
        NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
        return true
    }
    img.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
    img.resizingMode = .stretch
    return img
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = ClipStore()
    let state = PanelState()
    let settings = AppSettings()
    let hotKey = HotKey()
    var panel: EdgePanel!
    var frostView: NSVisualEffectView!
    var glassView: NSView?          // Liquid Glass (macOS 26+), shown while pinned
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem!
    var pauseItem: NSMenuItem!
    var expanded = false
    var outsideSince: Date?
    var suppressExpandUntil: Date?
    var mouseTimer: Timer?
    var clipTimer: Timer?
    var cancellables = Set<AnyCancellable>()
    var expireTimer: Timer?

    @objc func expireOldClips() {
        guard let seconds = settings.autoDelete.seconds else { return }
        store.expire(after: seconds)
    }
    var lastCorner: Double = -1
    var lastHotkey: HotkeyChoice?
    var lastChangeCount = NSPasteboard.general.changeCount
    var ownChangeCount = -1          // our own writes aren't recorded again
    var askedAccessibility = false

    let peek: CGFloat = 6      // how many px stay visible at the screen edge
    let margin: CGFloat = 10

    var panelSize: NSSize { NSSize(width: settings.width, height: settings.height) }
    var screen: NSScreen { NSScreen.screens.first ?? NSScreen.main! }

    func expandedFrame() -> NSRect {
        let v = screen.visibleFrame
        let x = settings.side == .left ? v.minX + margin : v.maxX - panelSize.width - margin
        let y: CGFloat
        switch settings.vPosition {
        case .top: y = v.maxY - panelSize.height - margin
        case .middle: y = v.midY - panelSize.height / 2
        case .bottom: y = v.minY + margin
        }
        return NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
    }

    func collapsedFrame() -> NSRect {
        var f = expandedFrame()
        f.origin.x = settings.side == .left
            ? screen.frame.minX - panelSize.width + peek
            : screen.frame.maxX - peek
        return f
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = EdgePanel(contentRect: collapsedFrame(),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.delegate = self
        panel.keyHandler = { [weak self] event in self?.handleKey(event) ?? false }

        let bounds = NSRect(origin: .zero, size: panelSize)
        let container = NSView(frame: bounds)

        let frost = NSVisualEffectView(frame: bounds)
        frost.material = .popover
        frost.blendingMode = .behindWindow
        frost.state = .active
        frost.autoresizingMask = [.width, .height]
        container.addSubview(frost)
        frostView = frost

        #if GLASS
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: bounds)
            glass.autoresizingMask = [.width, .height]
            glass.isHidden = true
            container.addSubview(glass)
            glassView = glass
        }
        #endif

        let host = ClickThroughHostingView(rootView: PanelView(store: store, state: state, settings: settings))
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)

        panel.contentView = container
        panel.orderFrontRegardless()

        state.openSettings = { [weak self] in self?.openSettings() }
        state.pick = { [weak self] item, viaKeyboard in self?.pick(item, viaKeyboard: viaKeyboard) }
        HotKey.action = { [weak self] in self?.toggleFromHotkey() }

        state.$pinned
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyMaterial() }
            .store(in: &cancellables)

        state.$paused
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)

        setupStatusItem()
        applySettings()

        let t = Timer(timeInterval: 0.05, target: self, selector: #selector(tick),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        mouseTimer = t

        let c = Timer(timeInterval: 0.4, target: self, selector: #selector(pollClipboard),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(c, forMode: .common)
        clipTimer = c

        // auto-delete: check every minute, and right away when the setting changes
        let x = Timer(timeInterval: 60, target: self, selector: #selector(expireOldClips),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(x, forMode: .common)
        expireTimer = x
        settings.$autoDelete
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.expireOldClips() } }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    // MARK: Clipboard watching

    @objc func pollClipboard() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        if count == ownChangeCount || state.paused { return }

        // Password managers mark secrets with these types — never record them
        let privateTypes: Set<String> = [
            "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
            "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword",
        ]
        let types = pb.types ?? []
        if types.contains(where: { privateTypes.contains($0.rawValue) }) { return }

        let front = NSWorkspace.shared.frontmostApplication
        let name = front?.localizedName
        let bundle = front?.bundleIdentifier
        let ignored = settings.ignoredList
        if ignored.contains(where: { $0 == name?.lowercased() || $0 == bundle?.lowercased() }) { return }
        let fromSelf = bundle == Bundle.main.bundleIdentifier
        let appName = fromSelf ? nil : name
        let appBundle = fromSelf ? nil : bundle
        let limit = settings.historyLimit

        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            store.record(text: urls.map { $0.path }.joined(separator: "\n"), kind: .file,
                         app: appName, bundle: appBundle, limit: limit)
        } else if let s = pb.string(forType: .string),
                  !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.record(text: s, kind: ClipKind.classify(s), app: appName, bundle: appBundle, limit: limit)
        } else if settings.saveImages, let img = NSImage(pasteboard: pb), let png = img.pngData() {
            store.recordImage(png, app: appName, bundle: appBundle, limit: limit)
        }
    }

    // MARK: Picking a clip

    func pick(_ item: ClipItem, viaKeyboard: Bool) {
        store.copyToPasteboard(item)
        ownChangeCount = NSPasteboard.general.changeCount
        lastChangeCount = ownChangeCount
        store.markUsed(item.id)

        let canPaste = settings.pasteDirectly && AXIsProcessTrusted()
        flash(item.id, text: settings.pasteDirectly && !canPaste ? "Copied — press ⌘V" : "Copied ✓")

        if settings.pasteDirectly {
            if !canPaste { askForAccessibility() }
            if canPaste || viaKeyboard {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    self.closePanel()
                    if canPaste {
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        self.sendPaste()
                    }
                }
            }
        } else if viaKeyboard {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                self.closePanel()
            }
        }
    }

    func flash(_ id: String, text: String) {
        state.flashText = text
        state.flashID = id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            if self.state.flashID == id { self.state.flashID = nil }
        }
    }

    /// Presses ⌘V in whatever app you were using.
    func sendPaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    func askForAccessibility() {
        guard !askedAccessibility else { return }
        askedAccessibility = true
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: Keyboard (hotkey mode)

    func toggleFromHotkey() {
        if expanded && state.keyboardOpen {
            closePanel()
            return
        }
        state.keyboardOpen = true
        state.selection = 0
        state.query = ""
        expand()
        panel.makeKeyAndOrderFront(nil)
        state.focusTick += 1
    }

    /// Arrow keys / Return / Esc / ⌘1–9 while the panel has focus.
    func handleKey(_ event: NSEvent) -> Bool {
        guard panel.isKeyWindow else { return false }
        let v = store.visible(query: state.query, tab: state.tab)
        let flat = v.starred + v.recent
        let cmd = event.modifierFlags.contains(.command)

        switch Int(event.keyCode) {
        case kVK_DownArrow:
            state.keyboardOpen = true
            state.selection = min(state.selection + 1, max(flat.count - 1, 0))
            return true
        case kVK_UpArrow:
            state.keyboardOpen = true
            state.selection = max(state.selection - 1, 0)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            guard flat.indices.contains(state.selection) else { return false }
            pick(flat[state.selection], viaKeyboard: true)
            return true
        case kVK_Escape:
            if !state.query.isEmpty { state.query = "" } else { closePanel() }
            return true
        case kVK_Delete where cmd:
            guard flat.indices.contains(state.selection) else { return false }
            store.delete(flat[state.selection].id)
            return true
        default:
            break
        }

        // ⌘1 … ⌘9 pick the first nine clips
        let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                      kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        if cmd, let n = digits.firstIndex(of: Int(event.keyCode)), flat.indices.contains(n) {
            pick(flat[n], viaKeyboard: true)
            return true
        }
        return false
    }

    func closePanel() {
        state.keyboardOpen = false
        suppressExpandUntil = Date().addingTimeInterval(0.6)
        collapse()
    }

    // MARK: Look

    /// Unpinned          → frosted (auto-hide mode)
    /// Pinned + focused  → Liquid Glass on top of frost
    /// Pinned + unfocused→ clear glass drawn in SwiftUI, no blur, see-through
    func applyMaterial() {
        let focused = panel.isKeyWindow
        if state.panelKey != focused { state.panelKey = focused }

        let darkLook = state.pinned && settings.pinnedTextIsLight
        frostView.material = darkLook ? .hudWindow : .popover
        panel.appearance = NSAppearance(named: darkLook ? .darkAqua : .aqua)

        if !state.pinned {
            frostView.isHidden = false
            glassView?.isHidden = true
        } else if focused {
            frostView.isHidden = false
            glassView?.isHidden = false
        } else {
            frostView.isHidden = true
            glassView?.isHidden = true
        }
        panel.invalidateShadow()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === panel { applyMaterial() }
    }

    func windowDidResignKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === panel {
            state.keyboardOpen = false
            applyMaterial()
        }
    }

    func applySettings() {
        if settings.corner != lastCorner {
            frostView.maskImage = roundedMask(radius: CGFloat(settings.corner))
            lastCorner = settings.corner
        }
        frostView.alphaValue = CGFloat(settings.bgOpacity)

        #if GLASS
        if #available(macOS 26.0, *), let glass = glassView as? NSGlassEffectView {
            glass.cornerRadius = CGFloat(settings.corner)
            glass.style = (settings.glass == .clear) ? .clear : .regular
            glass.alphaValue = CGFloat(settings.bgOpacity)
        }
        #endif

        if settings.hotkey != lastHotkey {
            lastHotkey = settings.hotkey
            if let mods = settings.hotkey.modifiers {
                hotKey.register(keyCode: UInt32(kVK_ANSI_V), modifiers: mods)
            } else {
                hotKey.unregister()
            }
        }

        let target = expanded ? expandedFrame() : collapsedFrame()
        if panel.frame != target {
            panel.setFrame(target, display: true)
        }
        applyMaterial()
    }

    // MARK: Settings window

    func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable],
                             backing: .buffered, defer: false)
            w.title = "EdgeClip Settings"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(s: settings, glassAvailable: glassView != nil))
            w.center()
            w.delegate = self
            settingsWindow = w
        }
        // Keep it clear of the panel.
        if let w = settingsWindow {
            var f = w.frame
            let v = screen.visibleFrame
            f.origin.x = settings.side == .left
                ? min(v.maxX - f.width - 40, v.minX + CGFloat(settings.width) + 60)
                : max(v.minX + 40, v.maxX - CGFloat(settings.width) - f.width - 60)
            w.setFrame(f, display: false)
        }
        state.previewing = true
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            state.previewing = false
        }
    }

    // MARK: Menu bar

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        pauseItem = NSMenuItem(title: "Pause Recording", action: #selector(togglePause), keyEquivalent: "")
        let pin = NSMenuItem(title: "Pin / Unpin Panel", action: #selector(togglePin), keyEquivalent: "")
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        let clear = NSMenuItem(title: "Clear History…", action: #selector(clearFromMenu), keyEquivalent: "")
        let folder = NSMenuItem(title: "Open Data Folder", action: #selector(openFolder), keyEquivalent: "")
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        for item in [pauseItem!, pin, prefs, clear, folder, login] { item.target = self; menu.addItem(item) }
        if #available(macOS 13.0, *) {
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            login.isHidden = true
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit EdgeClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
        updateStatusIcon()
    }

    func updateStatusIcon() {
        let name = state.paused ? "pause.circle" : "doc.on.clipboard"
        statusItem?.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "EdgeClip")
        pauseItem?.title = state.paused ? "Resume Recording" : "Pause Recording"
    }

    @objc func togglePause() {
        state.paused.toggle()
    }

    @objc func clearFromMenu() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Starred clips are kept."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { store.clearHistory() }
    }

    // MARK: Hover logic

    @objc func tick() {
        let m = NSEvent.mouseLocation
        let exp = expandedFrame()

        if state.pinned || state.previewing || state.keyboardOpen {
            outsideSince = nil
            if !expanded { expand() }
            return
        }

        if !expanded {
            if let until = suppressExpandUntil, until > Date() { return }
            let edgeX = settings.side == .left ? screen.frame.minX : screen.frame.maxX - 3
            let hotEdge = NSRect(x: edgeX, y: exp.minY, width: 3, height: exp.height)
            if hotEdge.contains(m) || panel.frame.contains(m) { expand() }
        } else {
            if exp.insetBy(dx: -24, dy: -24).contains(m) {
                outsideSince = nil
            } else if let since = outsideSince {
                if Date().timeIntervalSince(since) > 0.5 { collapse() }
            } else {
                outsideSince = Date()
            }
        }
    }

    func expand() {
        guard !expanded else { return }
        expanded = true
        outsideSince = nil
        animate(to: expandedFrame())
    }

    func collapse() {
        guard expanded else { return }
        expanded = false
        outsideSince = nil
        if panel.isKeyWindow {
            // Give keyboard focus back to whatever app you were using.
            panel.makeFirstResponder(nil)
            panel.orderOut(nil)
            panel.setFrame(collapsedFrame(), display: false)
            panel.orderFrontRegardless()
        } else {
            animate(to: collapsedFrame())
        }
    }

    func animate(to f: NSRect) {
        let p = panel!
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().setFrame(f, display: true)
        }
    }

    @objc func screensChanged() {
        panel.setFrame(expanded ? expandedFrame() : collapsedFrame(), display: true)
    }

    @objc func togglePin() {
        state.pinned.toggle()
    }

    @objc func openSettingsFromMenu() {
        openSettings()
    }

    @objc func openFolder() {
        NSWorkspace.shared.open(store.folderURL)
    }

    @objc func toggleLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
            } catch {
                NSSound.beep()
            }
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }
}

@main
struct EdgeClipMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

import Foundation
import ImageIO
import UniformTypeIdentifiers

public let importedImageCategory = "My Pictures"

public enum ImageImportError: LocalizedError {
    case unreadable, writeFailed

    public var errorDescription: String? {
        switch self {
        case .unreadable: return L("It could not be read. The file may be damaged, or in a format macOS cannot open.")
        case .writeFailed: return L("The picture thumbnail could not be saved.", ctx: "fork")
        }
    }
}

public func isImageFile(_ url: URL) -> Bool {
    UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
}

public func isImportableMedia(_ url: URL) -> Bool {
    ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) || isImageFile(url)
}

/// Decodes the first frame and applies EXIF orientation, including mirrored images.
public func generateImageThumbnail(
    image url: URL, destination: URL, maxDimension: Int = 1280
) throws {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
          ] as CFDictionary)
    else { throw ImageImportError.unreadable }
    guard let output = CGImageDestinationCreateWithURL(
        destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil
    ) else { throw ImageImportError.writeFailed }
    CGImageDestinationAddImage(output, image, [
        kCGImageDestinationLossyCompressionQuality: 0.92
    ] as CFDictionary)
    guard CGImageDestinationFinalize(output) else { throw ImageImportError.writeFailed }
}

/// Copies the original without re-encoding; only the library thumbnail is reduced.
@discardableResult
public func importImage(
    source: URL,
    title: String? = nil,
    category: String? = nil,
    root: URL = LibraryManifest.defaultRoot(),
    sourceFingerprint: String? = nil,
    progress: ((Double) -> Void)? = nil
) throws -> WallpaperEntry {
    guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
          let typeID = CGImageSourceGetType(imageSource),
          let type = UTType(typeID as String), type.conforms(to: .image),
          let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0
    else { throw ImageImportError.unreadable }
    let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
    let rotated = (5...8).contains(orientation)
    let id = UUID().uuidString.lowercased()
    let file = "Masters/\(id).\(type.preferredFilenameExtension ?? source.pathExtension.lowercased())"
    let thumbnail = "Thumbnails/\(id).jpg"
    let master = root.appendingPathComponent(file)
    let thumb = root.appendingPathComponent(thumbnail)
    for directory in [master.deletingLastPathComponent(), thumb.deletingLastPathComponent()] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    do {
        try FileManager.default.copyItem(at: source, to: master)
        progress?(0.5)
        // A successful pixel decode is required before committing the entry.
        try generateImageThumbnail(image: master, destination: thumb)
        let bytes = try master.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let entry = WallpaperEntry(
            id: id, title: title ?? source.deletingPathExtension().lastPathComponent,
            category: category ?? importedImageCategory, file: file, thumbnail: thumbnail,
            width: rotated ? height : width, height: rotated ? width : height,
            fps: 0, duration: 0, sizeBytes: Int64(bytes),
            sourceFingerprint: sourceFingerprint ?? videoFingerprint(of: source),
            mediaType: .image
        )
        try LibraryWriter.update(root: root) { $0.wallpapers.append(entry) }
        progress?(1)
        return entry
    } catch {
        try? FileManager.default.removeItem(at: master)
        try? FileManager.default.removeItem(at: thumb)
        throw error
    }
}

@discardableResult
public func importMedia(
    source: URL,
    title: String? = nil,
    category: String? = nil,
    root: URL = LibraryManifest.defaultRoot(),
    preserveOriginal: Bool = false,
    sourceFingerprint: String? = nil,
    keepAudio: Bool = false,
    progress: ((Double) -> Void)? = nil
) throws -> WallpaperEntry {
    if isImageFile(source) {
        return try importImage(
            source: source, title: title, category: category, root: root,
            sourceFingerprint: sourceFingerprint, progress: progress
        )
    }
    return try importVideo(
        source: source, title: title, category: category, root: root,
        preserveOriginal: preserveOriginal, sourceFingerprint: sourceFingerprint,
        keepAudio: keepAudio, progress: progress
    )
}

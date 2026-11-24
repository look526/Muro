import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import MuroKit

final class ImageImportTests: XCTestCase {
    private var folder: URL!
    private var root: URL { folder.appendingPathComponent("Library") }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("muro-images-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func fixture(type: UTType = .png, orientation: Int = 1) throws -> URL {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 160, height: 90, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 160, height: 90))
        let image = try XCTUnwrap(context.makeImage())
        let url = folder.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(try XCTUnwrap(type.preferredFilenameExtension))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyOrientation: orientation
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    func testPNGImportPreservesOriginalAndRoundTrips() throws {
        let source = try fixture()
        let original = try Data(contentsOf: source)
        var progress: [Double] = []
        let entry = try importMedia(source: source, root: root) { progress.append($0) }
        XCTAssertTrue(entry.isImage)
        XCTAssertEqual(entry.category, importedImageCategory)
        XCTAssertEqual(entry.width, 160)
        XCTAssertEqual(entry.height, 90)
        XCTAssertEqual(entry.fps, 0)
        XCTAssertEqual(entry.duration, 0)
        XCTAssertNil(entry.previewFile)
        XCTAssertNil(entry.efficientFile)
        XCTAssertEqual(entry.sizeBytes, Int64(original.count))
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(entry.file)), original)
        var expected = entry
        expected.dateAdded = Date(timeIntervalSince1970: floor(entry.dateAdded.timeIntervalSince1970))
        XCTAssertEqual(LibraryManifest.load(root: root).wallpapers, [expected])
        XCTAssertEqual(progress.last, 1)
        let thumbnail = try XCTUnwrap(CGImageSourceCreateWithURL(
            root.appendingPathComponent(entry.thumbnail) as CFURL, nil
        ))
        XCTAssertNotNil(CGImageSourceCreateImageAtIndex(thumbnail, 0, nil))
    }

    func testJPEGExifOrientationIsAppliedToMetadataAndThumbnail() throws {
        let source = try fixture(type: .jpeg, orientation: 6)
        let entry = try importImage(source: source, title: "Portrait", root: root)
        XCTAssertEqual(entry.title, "Portrait")
        XCTAssertEqual(entry.width, 90)
        XCTAssertEqual(entry.height, 160)
        let thumbnail = try XCTUnwrap(CGImageSourceCreateWithURL(
            root.appendingPathComponent(entry.thumbnail) as CFURL, nil
        ))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(thumbnail, 0, nil))
        XCTAssertEqual(image.width, 90)
        XCTAssertEqual(image.height, 160)
    }

    func testDesktopStillUsesOriginalPictureAndKeepsItsOrientation() throws {
        let entry = try importMedia(source: fixture(type: .jpeg, orientation: 6), root: root, keepAudio: true)
        XCTAssertNil(entry.hasSound)
        let still = folder.appendingPathComponent("desktop.jpg")
        try generateImageThumbnail(
            image: root.appendingPathComponent(entry.file), destination: still, maxDimension: 7680
        )
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(still as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, entry.width)
        XCTAssertEqual(image.height, entry.height)
    }

    func testSystemImageFormatsImport() throws {
        let supported = CGImageDestinationCopyTypeIdentifiers() as! [String]
        for type in [UTType.tiff, .bmp, .gif, .heic] where supported.contains(type.identifier) {
            let entry = try importMedia(source: fixture(type: type), root: root)
            XCTAssertTrue(entry.isImage, type.identifier)
            XCTAssertEqual(entry.width, 160)
            XCTAssertEqual(entry.height, 90)
        }
    }

    func testImageDuplicateIsRecognisedEvenAfterRename() throws {
        let source = try fixture()
        let entry = try importImage(source: source, root: root)
        let copy = folder.appendingPathComponent("Renamed.PNG")
        try FileManager.default.copyItem(at: source, to: copy)
        XCTAssertEqual(
            alreadyImported(source: copy, fingerprint: videoFingerprint(of: copy), in: [entry]),
            entry
        )
    }

    func testCorruptImageDoesNotCreateAnEntry() throws {
        let source = folder.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: source)
        XCTAssertThrowsError(try importMedia(source: source, root: root))
        XCTAssertTrue(LibraryManifest.load(root: root).wallpapers.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Masters").path))
    }

    func testFailedManifestWriteCleansUpImageFiles() throws {
        let source = try fixture()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let damaged = Data("damaged".utf8)
        try damaged.write(to: LibraryManifest.manifestURL(root: root))
        XCTAssertThrowsError(try importImage(source: source, root: root))
        for directory in ["Masters", "Thumbnails"] {
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(
                atPath: root.appendingPathComponent(directory).path
            ), [])
        }
        XCTAssertEqual(try Data(contentsOf: LibraryManifest.manifestURL(root: root)), damaged)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testDeletingImageRemovesOnlyLibraryCopies() throws {
        let source = try fixture()
        let entry = try importImage(source: source, root: root)
        XCTAssertEqual(try LibraryWriter.sweepOrphans(root: root, grace: 0), 0)
        try LibraryWriter.delete(ids: [entry.id], root: root)
        XCTAssertTrue(LibraryManifest.load(root: root).wallpapers.isEmpty)
        for file in entry.relativeFiles {
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(file).path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testLegacyVideoEntryWithoutMediaTypeStillDecodes() throws {
        let json = """
        {"id":"old","title":"Old","category":"Nature","file":"Masters/old.mov",
        "thumbnail":"Thumbnails/old.jpg","width":1920,"height":1080,
        "fps":30,"duration":5,"sizeBytes":1,"liked":false,"dateAdded":"2026-10-01T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(WallpaperEntry.self, from: Data(json.utf8))
        XCTAssertFalse(entry.isImage)
        XCTAssertNil(entry.mediaType)
    }

    func testImportFilterAcceptsMixedMediaButNotFoldersOrDocuments() {
        for name in ["Photo.JPG", "image.png", "image.heic", "image.webp", "clip.MOV", "clip.mp4", "clip.m4v"] {
            XCTAssertTrue(isImportableMedia(URL(fileURLWithPath: name)), name)
        }
        for name in ["folder", "document.pdf", "notes.txt"] {
            XCTAssertFalse(isImportableMedia(URL(fileURLWithPath: name)), name)
        }
    }
}

//
//  GalleryStore.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/11/26.
//

import UIKit
import Combine
import OSLog

nonisolated struct SunsetPhoto: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    var score: Int?
    var feedback: String?
}

@MainActor
final class GalleryStore: ObservableObject {
    @Published private(set) var photos: [SunsetPhoto] = []
    @Published private(set) var ratingInProgress: Set<UUID> = []
    @Published private(set) var ratingErrors: [UUID: String] = [:]

    private let rater = GeminiRater()
    private let folder = URL.documentsDirectory.appending(path: "Sunsets", directoryHint: .isDirectory)
    private var indexFile: URL { folder.appending(path: "photos.json") }
    private let imageCache = NSCache<NSUUID, UIImage>()

    init() {
        load()
    }

    @discardableResult
    func add(_ image: UIImage) -> SunsetPhoto? {
        guard let jpeg = image.resized(maxSide: 2048).jpegData(compressionQuality: 0.85) else { return nil }
        let photo = SunsetPhoto(id: UUID(), date: .now)

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try jpeg.write(to: imageFile(for: photo))
        } catch {
            AppLog.gallery.error("Couldn't save photo: \(error.localizedDescription)")
            return nil
        }

        AppLog.gallery.info("Saved photo \(photo.id) (\(jpeg.count / 1024) KB)")
        photos.insert(photo, at: 0)
        save()
        rate(photo)
        return photo
    }

    func rate(_ photo: SunsetPhoto) {
        guard !ratingInProgress.contains(photo.id),
              let jpeg = try? Data(contentsOf: imageFile(for: photo)) else { return }

        ratingInProgress.insert(photo.id)
        ratingErrors[photo.id] = nil

        Task {
            defer { ratingInProgress.remove(photo.id) }
            do {
                let rating = try await rater.rate(jpeg: jpeg)
                AppLog.gallery.info("Gemini rated \(photo.id): \(rating.score)")
                guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }  // Deleted meanwhile.
                photos[index].score = rating.score
                photos[index].feedback = rating.feedback
                save()
            } catch {
                AppLog.gallery.error("Rating failed: \(error.localizedDescription)")
                ratingErrors[photo.id] = error.localizedDescription
            }
        }
    }

    func delete(_ photo: SunsetPhoto) {
        try? FileManager.default.removeItem(at: imageFile(for: photo))
        imageCache.removeObject(forKey: photo.id as NSUUID)
        photos.removeAll { $0.id == photo.id }
        ratingErrors[photo.id] = nil
        save()
        AppLog.gallery.info("Deleted photo \(photo.id)")
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: folder)
        imageCache.removeAllObjects()
        photos = []
        ratingErrors = [:]
        AppLog.gallery.info("Deleted all photos")
    }

    func image(for photo: SunsetPhoto) -> UIImage? {
        if let cached = imageCache.object(forKey: photo.id as NSUUID) { return cached }
        guard let image = UIImage(contentsOfFile: imageFile(for: photo).path()) else { return nil }
        imageCache.setObject(image, forKey: photo.id as NSUUID)
        return image
    }

    // MARK: - Saving

    private func imageFile(for photo: SunsetPhoto) -> URL {
        folder.appending(path: "\(photo.id.uuidString).jpg")
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexFile) else { return }
        photos = (try? JSONDecoder().decode([SunsetPhoto].self, from: data)) ?? []
        AppLog.gallery.info("Loaded \(self.photos.count) photos")
    }

    private func save() {
        do {
            try JSONEncoder().encode(photos).write(to: indexFile, options: .atomic)
        } catch {
            AppLog.gallery.error("Couldn't save the photo list: \(error.localizedDescription)")
        }
    }
}

private extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

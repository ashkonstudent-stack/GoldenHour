//
//  GalleryView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/11/26.
//

import SwiftUI
import PhotosUI

struct GalleryView: View {
    @EnvironmentObject var vManager: viewModel
    @Environment(\.weatherTheme) private var theme

    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var capturedPhoto: SunsetPhoto?
    @State private var selectedPhoto: SunsetPhoto?

    private var gallery: GalleryStore { vManager.gallery }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        SkyScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Gallery")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.serif)
                    Text("Your sunsets, scored out of 100")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                .readableOnSky()

                addButtons
                    .readableOnSky()

                if gallery.photos.isEmpty {
                    Text("Take a photo of tonight's sunset to get your first score.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                        .readableOnSky()
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(gallery.photos) { photo in
                            Button { selectedPhoto = photo } label: {
                                PhotoCell(photo: photo)
                            }
                            .buttonStyle(.plain)
                            .fadesOnScroll()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: showCapturedPhoto) {
            CameraPicker { image in capturedPhoto = gallery.add(image) }
                .ignoresSafeArea()
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photoID: photo.id)
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task { await addFromLibrary(item) }
        }
    }

    private var addButtons: some View {
        let text = theme.textColor(atHeight: 0.3).color
        return HStack(spacing: 12) {
            if CameraPicker.isAvailable {
                Button { showCamera = true } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .foregroundStyle(theme.skyColor(atHeight: 0.3).color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(text, in: .capsule)
                }
            }
            PhotosPicker(selection: $libraryItem, matching: .images) {
                Label("Choose photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.tertiary.opacity(0.5), in: .capsule)
            }
        }
        .font(.headline)
    }

    private func showCapturedPhoto() {
        selectedPhoto = capturedPhoto
        capturedPhoto = nil
    }

    private func addFromLibrary(_ item: PhotosPickerItem) async {
        defer { libraryItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        selectedPhoto = gallery.add(image)
    }
}

private struct PhotoCell: View {
    @EnvironmentObject var vManager: viewModel
    let photo: SunsetPhoto

    var body: some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                if let image = vManager.gallery.image(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(.rect(cornerRadius: 20))
            .overlay(alignment: .bottomLeading) {
                ScoreBadge(photo: photo)
                    .padding(10)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(photo.score.map { "Sunset photo, score \($0)" } ?? "Sunset photo")
    }
}

private struct ScoreBadge: View {
    @EnvironmentObject var vManager: viewModel
    let photo: SunsetPhoto

    var body: some View {
        Group {
            if let score = photo.score {
                Text("\(score)")
                    .font(.headline.monospacedDigit())
            } else if vManager.gallery.ratingInProgress.contains(photo.id) {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45), in: .capsule)
        .environment(\.colorScheme, .dark)
    }
}

private struct PhotoDetailView: View {
    @EnvironmentObject var vManager: viewModel
    @Environment(\.weatherTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let photoID: UUID

    private var gallery: GalleryStore { vManager.gallery }
    private var photo: SunsetPhoto? { gallery.photos.first { $0.id == photoID } }

    var body: some View {
        let text = theme.textColor(atHeight: 0.6).color

        VStack(spacing: 24) {
            if let photo {
                if let image = gallery.image(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 24))
                        .frame(maxHeight: 360)
                }

                rating(for: photo)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        gallery.delete(photo)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.tertiary.opacity(0.5), in: .capsule)
                    }
                    Button { dismiss() } label: {
                        Label("Keep", systemImage: "checkmark")
                            .foregroundStyle(theme.skyColor(atHeight: 0.9).color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(text, in: .capsule)
                    }
                }
                .font(.headline)
                .foregroundStyle(text)
            }
        }
        .padding(24)
        .foregroundStyle(text, text.opacity(0.8), text.opacity(0.3))
        .fontDesign(.rounded)
        .presentationBackground { SkyBackground(theme: theme) }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func rating(for photo: SunsetPhoto) -> some View {
        if let score = photo.score {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(score)")
                        .font(.system(size: 72, weight: .bold))
                        .fontDesign(.serif)
                        .contentTransition(.numericText(value: Double(score)))
                    Text("/ 100")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if let feedback = photo.feedback {
                    Text(feedback)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else if gallery.ratingInProgress.contains(photo.id) {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Gemini is scoring your photo…")
                    .font(.headline)
            }
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                Text(gallery.ratingErrors[photo.id] ?? "This photo hasn't been scored yet.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("Try again") { gallery.rate(photo) }
                    .font(.headline)
                    .underline()
            }
            .padding(.vertical, 24)
        }
    }
}

#Preview {
    GalleryView()
        .environmentObject(viewModel())
        .weatherTheme(.preview(sunElevation: 2))
}

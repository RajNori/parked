//
//  PHPickerRepresentable.swift
//  parked
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Presents `PHPickerViewController` from SwiftUI without using `PhotosPicker`, avoiding nested sheet conflicts with a parent `.sheet`.
struct PHPickerRepresentable: UIViewControllerRepresentable {
    let onPick: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: (UIImage?) -> Void

        init(onPick: @escaping (UIImage?) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                deliver(nil)
                return
            }

            let provider = result.itemProvider
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    self?.deliver(object as? UIImage)
                }
            } else {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                    let image = data.flatMap { UIImage(data: $0) }
                    self?.deliver(image)
                }
            }
        }

        private func deliver(_ image: UIImage?) {
            DispatchQueue.main.async {
                self.onPick(image)
            }
        }
    }
}

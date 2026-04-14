//
//  ImageCompression.swift
//  parked
//

import Foundation
import UIKit

enum ImageCompressionError: LocalizedError {
    case invalidImageData
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            String(localized: "Could not load the selected photo.", comment: "Image compression invalid photo")
        case .compressionFailed:
            String(localized: "Could not compress the selected photo.", comment: "Image compression failure")
        }
    }
}

enum ImageCompression {
    private static let targetByteCount = 200 * 1024

    static func compressedJPEGThumbnail(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw ImageCompressionError.invalidImageData
        }
        var currentImage = image
        var compression: CGFloat = 0.82

        while compression >= 0.18 {
            if let jpegData = currentImage.jpegData(compressionQuality: compression), jpegData.count <= targetByteCount {
                return jpegData
            }
            compression -= 0.08
            if let resized = resize(image: currentImage, multiplier: 0.9) {
                currentImage = resized
            }
        }

        throw ImageCompressionError.compressionFailed
    }

    private static func resize(image: UIImage, multiplier: CGFloat) -> UIImage? {
        let size = CGSize(width: image.size.width * multiplier, height: image.size.height * multiplier)
        guard size.width >= 32, size.height >= 32 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

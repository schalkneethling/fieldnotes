import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoProcessingError: LocalizedError {
    case invalidImage
    case encodingFailed
    case encodedImageTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The selected image could not be decoded."
        case .encodingFailed:
            "The selected image could not be prepared."
        case .encodedImageTooLarge:
            "The selected image could not be reduced to a safe storage size."
        }
    }
}

enum PhotoProcessor {
    static let maximumPixelDimension = 2_048
    static let maximumEncodedBytes = 8 * 1_024 * 1_024

    private static let compressionQualities = [0.82, 0.72, 0.62, 0.52]

    static func normalize(_ sourceData: Data) throws -> Data {
        guard !sourceData.isEmpty,
              let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw PhotoProcessingError.invalidImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw PhotoProcessingError.invalidImage
        }

        for quality in compressionQualities {
            let data = try encodeJPEG(image, quality: quality)
            if data.count <= maximumEncodedBytes {
                return data
            }
        }

        throw PhotoProcessingError.encodedImageTooLarge
    }

    private static func encodeJPEG(_ image: CGImage, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw PhotoProcessingError.encodingFailed
        }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw PhotoProcessingError.encodingFailed
        }
        return data as Data
    }
}

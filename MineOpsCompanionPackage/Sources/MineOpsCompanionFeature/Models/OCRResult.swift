import Foundation
import UIKit

/// Legacy type kept so older tests and call sites continue to compile.
/// New code should move to `RecognizedSM` and `SMStats`.
@available(*, deprecated, message: "Use RecognizedSM instead")
public struct OCRResult: Hashable {
    public let image: UIImage
    public let parsedName: String
    public let parsedLevel: Int
    public let parsedBoost: Double
    public let parsedBoostType: String

    public init(
        image: UIImage,
        parsedName: String,
        parsedLevel: Int,
        parsedBoost: Double,
        parsedBoostType: String
    ) {
        self.image = image
        self.parsedName = parsedName
        self.parsedLevel = parsedLevel
        self.parsedBoost = parsedBoost
        self.parsedBoostType = parsedBoostType
    }
}

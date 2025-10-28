import Foundation
import UIKit

struct OCRResult: Identifiable, Hashable {
    let id = UUID()
    var image: UIImage
    var parsedName: String
    var parsedLevel: Int
    var parsedBoost: Double
    var parsedBoostType: String
}

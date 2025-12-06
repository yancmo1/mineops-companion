import Foundation

public enum ResourceLoader {
  public enum LoadError: Error, LocalizedError {
    case missing(String)
    public var errorDescription: String? {
      switch self {
      case .missing(let name): return "Resource not found in Bundle.module: \(name)"
      }
    }
  }

  public static func url(for name: String, ext: String? = nil, subdirectory: String? = nil) throws -> URL {
    // Try with subdirectory first
    if let subdirectory = subdirectory,
       let u = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
      return u
    }
    // Fallback: try without subdirectory (resources may be flattened in bundle)
    if let u = Bundle.module.url(forResource: name, withExtension: ext) {
      return u
    }
    throw LoadError.missing([name, ext].compactMap { $0 }.joined(separator: "."))
  }

  public static func data(named name: String, ext: String = "json", subdirectory: String? = nil) throws -> Data {
    try Data(contentsOf: url(for: name, ext: ext, subdirectory: subdirectory), options: .mappedIfSafe)
  }

  public static func decode<T: Decodable>(_ type: T.Type, from name: String, ext: String = "json", decoder: JSONDecoder = .init()) throws -> T {
    try decoder.decode(T.self, from: data(named: name, ext: ext))
  }
}

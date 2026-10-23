import Foundation
import os

/// Product events. Logged on-device today; wire a privacy-first analytics SDK here
/// (one call site) once an account exists. Never include audio or personal data.
enum Analytics {
    private static let logger = Logger(subsystem: "com.shahradazerisharghi.timbre", category: "events")
    static func log(_ event: String, _ properties: [String: String] = [:]) {
        let detail = properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        logger.info("\(event, privacy: .public) \(detail, privacy: .public)")
    }
}

import Foundation

final class KeychainHelper: Sendable {
    static let shared = KeychainHelper()
    
    private let storageDir: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("CalendarApp", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }
    
    func save(_ data: Data, service: String, account: String) {
        let fileURL = storageDir.appendingPathComponent("\(service)_\(account)")
        try? data.write(to: fileURL, options: .atomic)
    }
    
    func read(service: String, account: String) -> Data? {
        let fileURL = storageDir.appendingPathComponent("\(service)_\(account)")
        return try? Data(contentsOf: fileURL)
    }
    
    func delete(service: String, account: String) {
        let fileURL = storageDir.appendingPathComponent("\(service)_\(account)")
        try? FileManager.default.removeItem(at: fileURL)
    }
}

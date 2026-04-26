import Foundation
import AppKit

// MARK: - FaviconCache

/// A dual-layer (memory + disk) cache for website favicons.
/// - Memory cache provides fast access using NSCache (auto-evicted under memory pressure)
/// - Disk cache persists across app launches in the Caches directory
/// - Automatic cleanup of expired entries (30 days) and size management (10MB limit)
@MainActor
final class FaviconCache {
    
    static let shared = FaviconCache()
    
    // MARK: - Configuration
    
    /// Maximum cache size in bytes (10MB)
    private let maxCacheSize: Int = 10 * 1024 * 1024
    
    /// Cache expiration duration (30 days)
    private let expirationDuration: TimeInterval = 30 * 24 * 60 * 60
    
    /// Memory cache for fast access
    private let memoryCache = NSCache<NSString, NSImage>()
    
    /// Directory for disk cache
    private let cacheDirectory: URL? = {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return cachesURL?.appendingPathComponent("com.prism.browser.favicons", isDirectory: true)
    }()
    
    /// File manager for disk operations
    private let fileManager = FileManager.default
    
    private init() {
        // Set memory cache cost limit to ~5MB (images)
        memoryCache.totalCostLimit = 5 * 1024 * 1024
        memoryCache.countLimit = 100
        
        // Ensure cache directory exists
        if let cacheDirectory = cacheDirectory {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Perform periodic maintenance
        Task.detached(priority: .utility) {
            await self.performMaintenance()
        }
    }
    
    // MARK: - Public API
    
    /// Fetch a favicon for a domain, using cache when available.
    /// - Parameter domain: The domain to fetch the favicon for.
    /// - Returns: The cached or freshly fetched NSImage, or nil if unavailable.
    func fetchFavicon(for domain: String) async -> NSImage? {
        let normalizedDomain = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDomain.isEmpty else { return nil }
        
        // Check memory cache first
        if let cachedImage = getCachedImage(for: normalizedDomain) {
            return cachedImage
        }
        
        // Check disk cache
        if let cachedImage = await getCachedImageFromDisk(for: normalizedDomain) {
            // Store in memory cache for faster future access
            memoryCache.setObject(cachedImage, forKey: normalizedDomain as NSString, cost: estimateImageSize(cachedImage))
            return cachedImage
        }
        
        // Fetch from network
        return await fetchAndCacheFromNetwork(domain: normalizedDomain)
    }
    
    /// Clear all cached favicons (both memory and disk).
    func clearCache() {
        memoryCache.removeAllObjects()
        
        if let cacheDirectory = cacheDirectory {
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Private Methods
    
    /// Get image from memory cache.
    private func getCachedImage(for domain: String) -> NSImage? {
        memoryCache.object(forKey: domain as NSString)
    }
    
    /// Get image from disk cache.
    private func getCachedImageFromDisk(for domain: String) async -> NSImage? {
        guard let fileURL = fileURL(for: domain) else { return nil }
        guard let metaURL = metadataURL(for: domain) else { return nil }
        
        // Check if file exists and is not expired
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        // Check expiration
        if let meta = try? Data(contentsOf: metaURL),
           let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: meta) {
            let age = Date().timeIntervalSince(metadata.cachedAt)
            if age > expirationDuration {
                // File is expired, remove it
                try? fileManager.removeItem(at: fileURL)
                try? fileManager.removeItem(at: metaURL)
                return nil
            }
        }
        
        // Load image data
        guard let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else { return nil }
        
        return image
    }
    
    /// Fetch favicon from network and cache it.
    private func fetchAndCacheFromNetwork(domain: String) async -> NSImage? {
        let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64")
        guard let url = faviconURL else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else {
                return nil
            }
            
            // Cache in memory
            memoryCache.setObject(image, forKey: domain as NSString, cost: estimateImageSize(image))
            
            // Cache to disk
            await saveToDisk(data: data, for: domain)
            
            return image
        } catch {
            return nil
        }
    }
    
    /// Save favicon data to disk.
    private func saveToDisk(data: Data, for domain: String) async {
        guard let fileURL = fileURL(for: domain),
              let metaURL = metadataURL(for: domain) else { return }
        
        do {
            // Write image data
            try data.write(to: fileURL)
            
            // Write metadata
            let metadata = CacheMetadata(cachedAt: Date())
            let metaData = try JSONEncoder().encode(metadata)
            try metaData.write(to: metaURL)
            
            // Enforce size limit
            enforceSizeLimit()
        } catch {
            // Silently fail - caching is not critical
        }
    }
    
    /// Perform periodic cache maintenance.
    private func performMaintenance() {
        removeExpiredFiles()
        enforceSizeLimit()
    }
    
    /// Remove expired cache files.
    private func removeExpiredFiles() {
        guard let cacheDirectory = cacheDirectory,
              let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        
        let now = Date()
        for fileURL in files {
            // Skip metadata files (they'll be cleaned up with their parent)
            if fileURL.lastPathComponent.hasSuffix(".meta") { continue }
            
            let domain = fileURL.deletingPathExtension().lastPathComponent
            guard let metaURL = metadataURL(for: domain),
                  let meta = try? Data(contentsOf: metaURL),
                  let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: meta) else {
                // No metadata or invalid - remove orphaned file
                try? fileManager.removeItem(at: fileURL)
                continue
            }
            
            let age = now.timeIntervalSince(metadata.cachedAt)
            if age > expirationDuration {
                try? fileManager.removeItem(at: fileURL)
                try? fileManager.removeItem(at: metaURL)
            }
        }
    }
    
    /// Enforce the maximum cache size limit.
    private func enforceSizeLimit() {
        guard let cacheDirectory = cacheDirectory,
              let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        
        // Calculate total size
        var totalSize = 0
        var fileInfos: [(url: URL, size: Int, date: Date)] = []
        
        for fileURL in files {
            guard let metaURL = metadataURL(for: fileURL.deletingPathExtension().lastPathComponent),
                  let meta = try? Data(contentsOf: metaURL),
                  let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: meta) else { continue }
            
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += size
                fileInfos.append((url: fileURL, size: size, date: metadata.cachedAt))
            }
        }
        
        // If over limit, remove oldest files first
        if totalSize > maxCacheSize {
            let sorted = fileInfos.sorted { $0.date > $1.date } // Newest first
            var removed = 0
            
            for info in sorted {
                if totalSize - removed <= maxCacheSize { break }
                
                try? fileManager.removeItem(at: info.url)
                if let metaURL = metadataURL(for: info.url.deletingPathExtension().lastPathComponent) {
                    try? fileManager.removeItem(at: metaURL)
                }
                removed += info.size
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Get the file URL for a cached favicon.
    private func fileURL(for domain: String) -> URL? {
        cacheDirectory?.appendingPathComponent("\(cacheKey(for: domain)).png")
    }
    
    /// Get the metadata file URL for a cached favicon.
    private func metadataURL(for domain: String) -> URL? {
        cacheDirectory?.appendingPathComponent("\(cacheKey(for: domain)).meta")
    }
    
    /// Create a safe cache key from a domain.
    private func cacheKey(for domain: String) -> String {
        // Use MD5-like hash to avoid filesystem issues with special characters
        let data = domain.data(using: .utf8) ?? Data()
        return data.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Estimate the size of an NSImage in bytes (rough approximation).
    private func estimateImageSize(_ image: NSImage) -> Int {
        // Rough estimate: width * height * 4 (RGBA) * scale factor
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 10000 // Default estimate
        }
        return cgImage.bytesPerRow * cgImage.height
    }
}

// MARK: - Cache Metadata

/// Metadata stored alongside cached favicon data.
private struct CacheMetadata: Codable {
    let cachedAt: Date
}
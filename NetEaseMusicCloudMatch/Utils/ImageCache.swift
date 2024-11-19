import SwiftUI

class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, NSImage>()
    
    private init() {
        // 设置缓存容量
        cache.countLimit = 200
    }
    
    func set(_ image: NSImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(_ key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
} 
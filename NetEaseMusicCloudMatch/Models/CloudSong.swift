import Foundation

struct CloudSong: Identifiable, Equatable, Comparable {
    var id: String
    let name: String
    let artist: String
    let album: String
    let fileName: String
    let fileSize: Int64
    let bitrate: Int
    let addTime: Date
    let picUrl: String
    let duration: Int
    var matchId: String?
    
    init?(json: [String: Any]) {
        guard let simpleSong = json["simpleSong"] as? [String: Any],
              let id = simpleSong["id"] as? Int,
              let name = simpleSong["name"] as? String else {
            return nil
        }
        
        self.id = String(id)
        self.name = name
        
        // 处理艺术家信息
        if let ar = simpleSong["ar"] as? [[String: Any]], let firstArtist = ar.first {
            self.artist = firstArtist["name"] as? String ?? "未知艺术家"
        } else {
            self.artist = json["artist"] as? String ?? "未知艺术家"
        }
        
        // 处理专辑信息
        if let al = simpleSong["al"] as? [String: Any] {
            self.album = al["name"] as? String ?? "未知专辑"
            self.picUrl = al["picUrl"] as? String ?? ""
        } else {
            self.album = json["album"] as? String ?? "未知专辑"
            self.picUrl = ""
        }
        
        self.fileName = json["fileName"] as? String ?? ""
        self.fileSize = json["fileSize"] as? Int64 ?? 0
        self.bitrate = json["bitrate"] as? Int ?? 0
        
        if let addTime = json["addTime"] as? Int64 {
            self.addTime = Date(timeIntervalSince1970: TimeInterval(addTime) / 1000)
        } else {
            self.addTime = Date()
        }
        
        // 修正：从 simpleSong 中解析 dt 字段
        self.duration = simpleSong["dt"] as? Int ?? 0
    }
    
    static func < (lhs: CloudSong, rhs: CloudSong) -> Bool {
        lhs.addTime < rhs.addTime
    }

    static func compare(_ lhs: CloudSong, _ rhs: CloudSong, by comparators: [KeyPathComparator<CloudSong>]) -> ComparisonResult {
        for comparator in comparators {
            let result = comparator.compare(lhs, rhs)
            if result != .orderedSame {
                return result
            }
        }
        return .orderedSame
    }

    static func == (lhs: CloudSong, rhs: CloudSong) -> Bool {
        lhs.id == rhs.id
    }
} 
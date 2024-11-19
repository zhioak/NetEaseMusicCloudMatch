import Foundation

// 添加日志状态枚举
enum LogStatus {
    case success
    case error
    case info
}

struct LogInfo: Identifiable {
    let id = UUID()
    let songName: String      // 歌曲名
    let songId: String        // 歌曲ID（原cloudSongId）
    let matchSongId: String   // 匹配目标ID
    let message: String       // 其他信息
    let status: LogStatus     // 状态
    let timestamp: Date       // 添加时间戳
    
    init(
        songName: String,
        songId: String,
        matchSongId: String,
        message: String,
        status: LogStatus,
        timestamp: Date = Date()
    ) {
        self.songName = songName
        self.songId = songId
        self.matchSongId = matchSongId
        self.message = message
        self.status = status
        self.timestamp = timestamp
    }
} 
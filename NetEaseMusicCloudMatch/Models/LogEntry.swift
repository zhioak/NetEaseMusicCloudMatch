import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let songName: String      // 歌曲名
    let cloudSongId: String   // 云盘歌曲ID
    let matchSongId: String   // 匹配目标ID
    let message: String       // 其他信息
    let isSuccess: Bool       // 是否成功
    let timestamp: Date       // 添加时间戳
    
    init(
        songName: String,
        cloudSongId: String,
        matchSongId: String,
        message: String,
        isSuccess: Bool,
        timestamp: Date = Date()
    ) {
        self.songName = songName
        self.cloudSongId = cloudSongId
        self.matchSongId = matchSongId
        self.message = message
        self.isSuccess = isSuccess
        self.timestamp = timestamp
    }
} 
import Foundation
import AppKit

class SongManager: ObservableObject {
    static let shared = SongManager()
    private let networkManager = NetworkManager.shared
    private let userManager = UserManager.shared
    
    @Published var cloudSongs: [Song] = []
    @Published var isLoadingCloudSongs = false
    @Published private(set) var totalSongCount: Int = -1
    @Published private(set) var usedSize: Int64 = 0
    @Published private(set) var maxSize: Int64 = 0
    
    // 添加一个标志位来防止重复请求
    private var isFetching = false
    
    // 添加匹配日志属性
    @Published var matchLogs: [LogInfo] = []
    
    private init() {}
    
    // 获取云盘歌曲列表
    func fetchPage(page: Int = 1, limit: Int = 200) {
        guard userManager.isLoggedIn else {
            print("用户未登录，无法获取云盘歌曲")
            return
        }
        
        // 如果正在获取中，则直接返回
        guard !isFetching else {
            print("正在获取云盘歌曲中，请稍候...")
            return
        }
        
        isFetching = true
        isLoadingCloudSongs = true
        
        let offset = (page - 1) * limit
        let parameters = [
            "limit": limit,
            "offset": offset
        ]
        
        networkManager.post(
            endpoint: "https://music.163.com/api/v1/cloud/get",
            parameters: parameters
        ) { [weak self] result in
            guard let self = self else { return }
            
            // 在函数结束时重置状态
            defer { 
                DispatchQueue.main.async {
                    self.isLoadingCloudSongs = false
                    self.isFetching = false
                }
            }
            
            switch result {
            case .success(let (json, _)):
                if let code = json["code"] as? Int, code == 200,
                   let data = json["data"] as? [[String: Any]] {
                    
                    if self.totalSongCount == -1 {
                        if let count = json["count"] as? Int {
                            let sizeStr = String(describing: json["size"] ?? "0")
                            let maxSizeStr = String(describing: json["maxSize"] ?? "0")
                            let size = Int64(sizeStr) ?? 0
                            let maxSize = Int64(maxSizeStr) ?? 0
                            
                            DispatchQueue.main.async {
                                self.totalSongCount = count
                                self.usedSize = size
                                self.maxSize = maxSize
                            }
                        }
                    }
                    
                    // 解析歌曲数据
                    let songs = data.compactMap { Song(json: $0) }
                    DispatchQueue.main.async {
                        self.cloudSongs = songs
                    }
                } else if let code = json["code"] as? Int, code == 301 {
                    print("token过期重新登录")
                    Task { @MainActor in
                        await LoginManager.shared.logout()
                    }
                }
            case .failure(let error):
                print("获取云盘歌曲失败: \(error)")
            }
        }
    }
    
    // 匹配云盘歌曲
    func matchCloudSong(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String, Song?) -> Void) {
        guard userManager.isLoggedIn else {
            completion(false, "用户未登录", nil)
            return
        }
        
        guard let _ = cloudSongs.first(where: { $0.id == cloudSongId }) else {
            completion(false, "云盘文件不存在", nil)
            return
        }
        
        let endpoint = "https://music.163.com/api/cloud/user/song/match?userId=\(userManager.userId)&songId=\(cloudSongId)&adjustSongId=\(matchSongId)"
        
        networkManager.get(endpoint: endpoint) { result in
            switch result {
            case .success(let (json, _)):  // 解构元组，获取 json 数据
                if let code = json["code"] as? Int {
                    switch code {
                    case 200:
                        if let matchData = json["matchData"] as? [String: Any],
                           let updatedSong = Song(json: matchData) {
                            completion(true, "匹配成功", updatedSong)
                        } else {
                            completion(true, "匹配成功", nil)
                        }
                    default:
                        let msg = json["message"] as? String ?? "未知错误"
                        completion(false, msg, nil)
                    }
                }
            case .failure(let error):
                completion(false, "匹配失败: \(error)", nil)
            }
        }
    }
    
    // 将 performMatch 移动到这里
    func performMatch(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        // 验证输入
        guard !matchSongId.isEmpty else {
            let message = "请输入匹配ID"
            matchLogs.append(LogInfo(
                songName: "",
                songId: cloudSongId,
                matchSongId: "",
                message: message,
                status: .error
            ))
            completion(false, message)
            return
        }
        
        // 获取当前歌曲名称
        let songName = cloudSongs.first(where: { $0.id == cloudSongId })?.name ?? "未知歌曲"
        
        // 调用匹配API
        matchCloudSong(cloudSongId: cloudSongId, matchSongId: matchSongId) { [weak self] success, message, updatedSong in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.matchLogs.append(LogInfo(
                    songName: songName,
                    songId: cloudSongId,
                    matchSongId: matchSongId,
                    message: message,
                    status: success ? .success : .error
                ))
                
                if success, let song = updatedSong {
                    if let index = self.cloudSongs.firstIndex(where: { $0.id == cloudSongId }) {
                        self.cloudSongs[index] = song
                    }
                }
                
                completion(success, message)
            }
        }
    }
} 

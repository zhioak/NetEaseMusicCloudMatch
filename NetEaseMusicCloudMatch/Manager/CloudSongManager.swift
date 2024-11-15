import Foundation
import AppKit

class CloudSongManager: ObservableObject {
    static let shared = CloudSongManager()
    private let networkManager = NetworkManager.shared
    private let loginManager = LoginManager.shared
    
    @Published var cloudSongs: [CloudSong] = []
    @Published var isLoadingCloudSongs = false
    @Published private(set) var totalSongCount: Int = -1
    
    private init() {}
    
    // 获取云盘歌曲列表
    func fetchCloudSongs(page: Int = 1, limit: Int = 200) {
        guard loginManager.isLoggedIn else {
            print("用户未登录，无法获取云盘歌曲")
            return
        }
        
        print("开始获取云盘歌曲")
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
            
            // 在函数结束时重置加载状态
            defer { DispatchQueue.main.async { self.isLoadingCloudSongs = false } }
            
            switch result {
            case .success(let json):
                if let code = json["code"] as? Int, code == 200,
                   let data = json["data"] as? [[String: Any]] {
                    // 只在首次加载（totalSongCount == -1）时更新总数
                    if self.totalSongCount == -1,
                       let count = json["count"] as? Int {
                        DispatchQueue.main.async {
                            self.totalSongCount = count
                            print("首次加载，更新总数: \(count)")
                        }
                    }
                    
                    // 解析歌曲数据
                    let songs = data.compactMap { CloudSong(json: $0) }
                    DispatchQueue.main.async {
                        self.cloudSongs = songs
                    }
                } else if let code = json["code"] as? Int, code == 301 {
                    print("token过期重新登录")
                    self.loginManager.logout()
                }
            case .failure(let error):
                print("获取云盘歌曲失败: \(error)")
            }
        }
    }
    
    // 匹配云盘歌曲
    func matchCloudSong(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String, CloudSong?) -> Void) {
        guard loginManager.isLoggedIn else {
            completion(false, "用户未登录", nil)
            return
        }
        
        guard let _ = cloudSongs.first(where: { $0.id == cloudSongId }) else {
            completion(false, "云盘文件不存在", nil)
            return
        }
        
        let endpoint = "https://music.163.com/api/cloud/user/song/match?userId=\(loginManager.userId)&songId=\(cloudSongId)&adjustSongId=\(matchSongId)"
        
        networkManager.get(endpoint: endpoint) { result in
            switch result {
            case .success(let json):
                if let code = json["code"] as? Int {
                    switch code {
                    case 200:
                        if let matchData = json["matchData"] as? [String: Any],
                           let updatedSong = CloudSong(json: matchData) {
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
} 
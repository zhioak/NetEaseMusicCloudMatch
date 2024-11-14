import Foundation
import AppKit

class CloudSongManager: ObservableObject {
    static let shared = CloudSongManager()
    
    @Published var cloudSongs: [CloudSong] = []
    @Published var isLoadingCloudSongs = false
    @Published var totalSongCount: Int = 0
    
    private let loginManager = LoginManager.shared
    
    private init() {}
    
    // 获取云盘歌曲列表
    func fetchCloudSongs(page: Int = 1, limit: Int = 200) {
        // 检查登录状态
        guard loginManager.isLoggedIn else {
            print("用户未登录，无法获取云盘歌曲")
            return
        }
        
        print("开始获取云盘歌曲")
        isLoadingCloudSongs = true
        
        // 构建请求URL
        let urlString = "https://music.163.com/api/v1/cloud/get"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for cloud songs")
            isLoadingCloudSongs = false
            return
        }
        
        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 添加Cookie
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 设置请求参数
        let offset = (page - 1) * limit
        let parameters: [String: Any] = [
            "limit": limit,    // 每页显示数量
            "offset": offset   // 起始位置
        ]
        request.httpBody = parameters.percentEncoded()
        
        // 打印请求信息用于调试
        print("请求URL: \(urlString)")
        print("请求头: \(request.allHTTPHeaderFields ?? [:])")
        print("请求体: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "None")")
        
        // 发起网络请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 在函数结束时重置加载状态
            defer { DispatchQueue.main.async { self.isLoadingCloudSongs = false } }
            
            // 错误处理
            if let error = error {
                print("获取云盘歌曲时出错: \(error)")
                return
            }
            
            // 打印响应状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("云盘歌曲请求 HTTP 状态码: \(httpResponse.statusCode)")
                print("响应头: \(httpResponse.allHeaderFields)")
            }
            
            // 确保响应数据存在
            guard let data = data else {
                print("没有收到云盘歌曲数据")
                return
            }
            
            // 解析响应数据
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("解析后的云盘歌曲 JSON: \(json)")
                    if let code = json["code"] as? Int, code == 200,
                       let data = json["data"] as? [[String: Any]] {
                        // 添加总数解析
                        if let count = json["count"] as? Int {
                            DispatchQueue.main.async {
                                self.totalSongCount = count
                            }
                        }
                        
                        // 将JSON数据转换为CloudSong对象
                        let songs = data.compactMap { CloudSong(json: $0) }
                        print("成功解析的歌曲数量: \(songs.count)")
                        
                        // 在主线程更新UI
                        DispatchQueue.main.async {
                            self.cloudSongs = songs
                        }
                    } else {
                        print("无法从 JSON 中解析出云盘歌曲数据")
                        if let code = json["code"] as? Int {
                            print("返回的错误代码: \(code)")
                            if(code == 301){
                                print("token过期重新登录")
                                self.loginManager.logout()
                            }
                        }
                        if let message = json["message"] as? String {
                            print("返回的错误信息: \(message)")
                        }
                    }
                } else {
                    print("无法解析云盘歌曲信息为 JSON")
                }
            } catch {
                print("解析云盘歌曲数据时出错: \(error)")
            }
        }.resume()
    }
    
    // 匹配云盘歌曲
    func matchCloudSong(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String, CloudSong?) -> Void) {
        // 检查登录状态
        guard loginManager.isLoggedIn else {
            print("匹配失败: 用户未登录")
            completion(false, "用户未登录", nil)
            return
        }
        
        // 检查云盘文件是否存在
        guard let _ = cloudSongs.first(where: { $0.id == cloudSongId }) else {
            print("匹配失败: 云盘文件不存在")
            completion(false, "云盘文件不存在", nil)
            return
        }
        
        // 发送匹配请求
        sendMatchRequest(cloudSongId: cloudSongId, matchSongId: matchSongId, completion: completion)
    }
    
    // 发送匹配请求到服务器
    private func sendMatchRequest(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String, CloudSong?) -> Void) {
        guard !loginManager.userId.isEmpty else {
            print("匹配失败: 用户ID为空")
            completion(false, "用户ID为空", nil)
            return
        }

        let urlString = "https://music.163.com/api/cloud/user/song/match?userId=\(loginManager.userId)&songId=\(cloudSongId)&adjustSongId=\(matchSongId)"
        guard let url = URL(string: urlString) else {
            print("发送匹配请求失败: 无效的URL")
            completion(false, "Invalid URL", nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 发起网络请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 错误处理
            if let error = error {
                print("匹配请求失败: \(error.localizedDescription)")
                completion(false, "匹配请求失败: \(error.localizedDescription)", nil)
                return
            }
            
            // 打印响应信息
            if let httpResponse = response as? HTTPURLResponse {
                print("匹配请求响应状态码: \(httpResponse.statusCode)")
                print("响应头: \(httpResponse.allHeaderFields)")
            }
            
            // 确保响应数据存在
            guard let data = data else {
                print("匹配请求没有返回数据")
                completion(false, "无法解析响应", nil)
                return
            }
            
            // 解析响应数据
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("匹配响应: \(json)")
                    if let code = json["code"] as? Int {
                        switch code {
                        case 200:
                            if let matchData = json["matchData"] as? [String: Any] {
                                // 从匹配数据创建新的 CloudSong 对象
                                if let updatedSong = CloudSong(json: matchData) {
                                    print("匹配成功，获取到更新后的歌曲信息")
                                    completion(true, "匹配成功", updatedSong)
                                } else {
                                    completion(true, "匹配成功，但无法解析更新后的歌曲信息", nil)
                                }
                            } else {
                                completion(true, "匹配成功", nil)
                            }
                        default:
                            let msg = json["message"] as? String ?? "未知错误"
                            completion(false, msg, nil)
                        }
                    } else {
                        completion(false, "无法解析响应", nil)
                    }
                } else {
                    completion(false, "无法解析响应", nil)
                }
            } catch {
                completion(false, "无法解析响应", nil)
            }
        }.resume()
    }
}

// 添加 Dictionary 扩展
extension Dictionary {
    // 将字典转换为URL编码的字符串
    func percentEncoded() -> Data? {
        return map { key, value in
            // 对key和value进行URL编码
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
} 
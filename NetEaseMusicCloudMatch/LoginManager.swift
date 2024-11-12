//
//  LoginManager.swift
//  NetEaseMusicCloudMatch
//
//  Created by zhiozhou on 2024/10/25.
//


import Foundation
import CoreImage
import AppKit

// LoginManager: 负责处理网易云音乐的登录认证和云盘歌曲管理
// 使用 ObservableObject 使其可以在 SwiftUI 中作为状态管理器使用
class LoginManager: ObservableObject {
    // 使用单例模式确保整个应用只有一个登录管理实例
    static let shared = LoginManager()
    
    // MARK: - Published 属性
    // 这些属性使用 @Published 包装器，当值改变时会自动通知 UI 更新
    @Published var qrCodeImage: NSImage?         // 登录二维码图片
    @Published var isLoggedIn = false           // 登录状态
    @Published var username = ""                 // 用户名
    @Published var userAvatarURL: URL?          // 用户头像URL
    @Published var qrCodeStatus: QRCodeStatus = .loading  // 二维码状态
    @Published var userAvatar: NSImage?         // 用户头像图片
    @Published var cloudSongs: [CloudSong] = [] // 云盘歌曲列表
    @Published var isLoadingCloudSongs = false  // 是否正在加载云盘歌曲
    @Published var userId: String = ""          // 用户ID
    @Published private(set) var isGettingQRCode = false // 是否正在获取二维码
    
    // MARK: - 私有属性
    private var key: String = ""                // 二维码key
    private var qrCodeUrl: String = ""          // 二维码URL
    private var timer: Timer?                   // 用于轮询登录状态的定时器
    
    // 加密相关的密钥
    // 这些是网易云音乐API需要的固定值，用于请求加密
    private let secretKey = "TA3YiYCfY2dDJQgg"
    private let encSecKey = "84ca47bca10bad09a6b04c5c927ef077d9b9f1e37098aa3eac6ea70eb59df0aa28b691b7e75e4f1f9831754919ea784c8f74fbfadf2898b0be17849fd656060162857830e241aba44991601f137624094c114ea8d17bce815b0cd4e5b8e2fbaba978c6d1d14dc3d1faf852bdd28818031ccdaaa13a6018e1024e2aae98844210"
    
    private var userToken: String = ""          // 用户登录令牌
    private let loginExpirationDays = 30        // 登录信息过期天数
    private var isLoadingUserInfo = false       // 是否正在加载用户信息
    
    // MARK: - 枚举定义
    // 二维码状态枚举
    enum QRCodeStatus {
        case loading   // 加载中
        case ready    // 已准备好
        case expired  // 已过期
    }
    
    // MARK: - 初始化方法
    private init() {
        loadUserInfo() // 初始化时加载保存的用户信息
    }
    
    func startLoginProcess() {
        if isLoggedIn {
            print("用户已登录")
            return
        }
        if isGettingQRCode {
            print("正在获取二维码，请稍候")
            return
        }
        print("开始登录流程")
        qrCodeStatus = .loading
        getQRKey()
    }
    
    // 加载保存的用户信息
    private func loadUserInfo() {
        // 防止重复加载
        guard !isLoadingUserInfo else { return }
        isLoadingUserInfo = true
        
        // 从 UserDefaults 获取保存的用户信息
        if let savedUsername = UserDefaults.standard.string(forKey: "username"),
           let savedToken = UserDefaults.standard.string(forKey: "userToken"),
           let savedAvatarURL = UserDefaults.standard.url(forKey: "userAvatarURL"),
           let savedUserId = UserDefaults.standard.string(forKey: "userId"),
           let loginTime = UserDefaults.standard.object(forKey: "loginTime") as? Date {
            
            // 检查登录是否在有效期内（30天）
            if Date().timeIntervalSince(loginTime) < Double(loginExpirationDays * 24 * 60 * 60) {
                // 恢复用户信息
                username = savedUsername
                userToken = savedToken
                userAvatarURL = savedAvatarURL
                userId = savedUserId
                isLoggedIn = true
                
                // 打印调试信息
                print("本地加载的用户信息:")
                print("用户名: \(username)")
                print("用户ID: \(userId)")
                print("头像URL: \(userAvatarURL?.absoluteString ?? "无")")
                print("登录时间: \(loginTime)")
                print("用户Token: \(userToken)")
                
                // 下载用户头像
                if let avatarURL = userAvatarURL {
                    downloadUserAvatar(from: avatarURL)
                }
            } else {
                print("登录已过期，需要重新登录")
                clearUserInfo()
            }
        } else {
            print("没有找到保存的用户信息")
        }
        
        isLoadingUserInfo = false
    }
    
    // 保存用户信息到本地
    private func saveUserInfo() {
        // 使用 UserDefaults 保存用户信息
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(userToken, forKey: "userToken")
        UserDefaults.standard.set(userAvatarURL, forKey: "userAvatarURL")
        UserDefaults.standard.set(Date(), forKey: "loginTime")
        print("用户信息已保存")
    }
    
    // 清除本地保存的用户信息
    private func clearUserInfo() {
        // 从 UserDefaults 中移除所有用户相关信息
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "userToken")
        UserDefaults.standard.removeObject(forKey: "userAvatarURL")
        UserDefaults.standard.removeObject(forKey: "loginTime")
        UserDefaults.standard.removeObject(forKey: "userId")
        print("用户信息已清除")
    }
    
    // 获取登录二维码的key
    private func getQRKey() {
        print("正在获取二维码 key")
        let urlString = "https://music.163.com/api/login/qrcode/unikey?type=1"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        // 创建网络请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 发起网络请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 错误处理
            if let error = error {
                print("获取二维码 key 时出错: \(error)")
                return
            }
            
            // 打印HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP 状态码: \(httpResponse.statusCode)")
            }
            
            // 处理响应数据
            if let data = data, !data.isEmpty {
                print("收到的数据: \(String(data: data, encoding: .utf8) ?? "无法解码")")
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let code = json["code"] as? Int, code == 200 {
                            if let unikey = json["unikey"] as? String {
                                print("成功获取二维码 key: \(unikey)")
                                // 在主线程更新UI
                                DispatchQueue.main.async {
                                    self.key = unikey
                                    self.getQRCode()
                                }
                            } else {
                                print("无法从响应中解析 unikey")
                            }
                        } else {
                            print("请求失败，错误码：\(json["code"] ?? "未知")")
                        }
                    } else {
                        print("无法解析JSON响应")
                    }
                } catch {
                    print("解析 JSON 时出错: \(error)")
                }
            } else {
                print("没有收到数据或数据为空")
            }
        }.resume()
    }
    
    // 生成登录二维码
    private func getQRCode() {
        print("正在生成二维码")
        // 使用获取到的key构建二维码URL
        qrCodeUrl = "https://music.163.com/login?codekey=\(key)"
        // 生成二维码图像
        generateQRCode(from: qrCodeUrl)
        // 更新二维码状态
        qrCodeStatus = .ready
        // 开始轮询登录状态
        startPolling()
    }
    
    // 使用CoreImage生成二维码图像
    private func generateQRCode(from string: String) {
        // 将字符串转换为ASCII编码数据
        let data = string.data(using: String.Encoding.ascii)
        // 创建二维码生成器
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            // 设置二维码内容
            filter.setValue(data, forKey: "inputMessage")
            // 放大二维码图像，提高清晰度
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            if let output = filter.outputImage?.transformed(by: transform) {
                // 转换为NSImage以在UI中显示
                let rep = NSCIImageRep(ciImage: output)
                let nsImage = NSImage(size: rep.size)
                nsImage.addRepresentation(rep)
                DispatchQueue.main.async {
                    self.qrCodeImage = nsImage
                    print("二维码生成成功")
                }
            } else {
                print("生成二维码图像失败")
            }
        } else {
            print("创建 CIFilter 失败")
        }
    }
    
    // 开始轮询查登录状态
    private func startPolling() {
        print("开始轮询登录状态")
        // 每3秒检查一次登录状态
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.checkLoginStatus()
        }
    }
    
    // 检查用户是否已扫码登录
    private func checkLoginStatus() {
        // 如果已登录则停止轮询
        guard !isLoggedIn else {
            stopPolling()
            return
        }
        
        print("检查登录状态")
        let urlString = "https://music.163.com/api/login/qrcode/client/login"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 设置请求参数
        let parameters: [String: Any] = [
            "key": key,
            "type": 1
        ]
        request.httpBody = parameters.percentEncoded()
        
        // 发起网络请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 错误处理
            if let error = error {
                print("检查登录状态时出错: \(error)")
                return
            }
            
            // 打印HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP 状态码: \(httpResponse.statusCode)")
            }
            
            // 处理响应数据
            if let data = data, !data.isEmpty {
                print("收到的数据: \(String(data: data, encoding: .utf8) ?? "无法解码")")
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let code = json["code"] as? Int {
                            print("收到登录状态响应，代码: \(code)")
                            DispatchQueue.main.async {
                                switch code {
                                case 803: // 登录成功
                                    self.isLoggedIn = true
                                    // 保存userToken
                                    if let cookie = (response as? HTTPURLResponse)?.allHeaderFields["Set-Cookie"] as? String {
                                        self.userToken = cookie
                                    }
                                    self.stopPolling()
                                    print("登录成功")
                                    self.getUserInfo()
                                case 800: // 二维码过期
                                    if !self.isLoggedIn {
                                        print("二维码过期")
                                        self.qrCodeStatus = .expired
                                        self.stopPolling()
                                    }
                                default: // 等待扫码
                                    if !self.isLoggedIn {
                                        print("未登录，继续等待")
                                    }
                                }
                            }
                        } else {
                            print("无法从响应中解析 code")
                        }
                    } else {
                        print("无法解析JSON响应")
                    }
                } catch {
                    print("解析 JSON 时出错: \(error)")
                }
            } else {
                print("没有收到数据或数据为空")
            }
        }.resume()
    }
    
    // 停止登录状态轮询
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    // 获取用户信息
    private func getUserInfo() {
        let urlString = "https://music.163.com/api/nuser/account/get"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 发起网络请求获取用户信息
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("获取用户信息时出错: \(error)")
                return
            }
            
            if let data = data {
                do {
                    // 解析用户信息JSON数据
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let profile = json["profile"] as? [String: Any] {
                        DispatchQueue.main.async {
                            // 更新用户基本信息
                            self.username = profile["nickname"] as? String ?? "未知用户"
                            self.userId = String(profile["userId"] as? Int ?? 0)
                            UserDefaults.standard.set(self.userId, forKey: "userId")
                            
                            // 处理用户头像
                            if let avatarUrlString = profile["avatarUrl"] as? String,
                               let avatarUrl = URL(string: avatarUrlString) {
                                self.userAvatarURL = avatarUrl
                                print("准备下载头像: \(avatarUrl)")
                                self.downloadUserAvatar(from: avatarUrl)
                            } else {
                                print("无法获取头像 URL")
                            }
                            
                            // 打印调试信息
                            print("用户信息:")
                            print("用户名: \(self.username)")
                            print("头像URL: \(self.userAvatarURL?.absoluteString ?? "无")")
                            print("他信息: \(profile)")
                            
                            // 保存用户信息到本地
                            self.saveUserInfo()
                            
                            // 登录成功后自动获取云盘歌曲
                            self.fetchCloudSongs()
                        }
                    } else {
                        print("无法解析用户信息")
                    }
                } catch {
                    print("解析用户信息时出错: \(error)")
                }
            }
        }.resume()
    }
    
    // 下载用户头像
    private func downloadUserAvatar(from url: URL) {
        print("开始下载头像: \(url)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("下载头像时出错: \(error)")
                return
            }
            
            // 打印HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                print("头像下载 HTTP 状态码: \(httpResponse.statusCode)")
            }
            
            // 处理头像数据
            if let data = data {
                print("收到头像数据，大小: \(data.count) 字节")
                if let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self.userAvatar = image
                        print("头像成功下载并设置，大小: \(image.size)")
                    }
                } else {
                    print("无法从数据创建 NSImage")
                }
            } else {
                print("没有收到头像数据")
            }
        }.resume()
    }
    
    // 退出登录
    func logout() {
        // 清除用户数据
        clearUserInfo()
        // 停止轮询
        stopPolling()
        // 重置状态
        qrCodeStatus = .loading
        isLoggedIn = false
        username = ""
        userAvatar = nil
        userId = ""
        userToken = ""
        cloudSongs = []
        // 重新开始登录流程
        startLoginProcess()
    }
    
    // 获取用户云盘歌曲列表
    func fetchCloudSongs() {
        // 检查登录状态
        guard isLoggedIn else {
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
        
        // 添加Cookie信息
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 添加用户Token到请求头
        if !userToken.isEmpty {
            request.setValue(userToken, forHTTPHeaderField: "MUSIC_U")
        }
        
        // 设置请求参数
        let parameters: [String: Any] = [
            "limit": 15,    // 每页显示数量
            "offset": 0     // 起始位置
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
                        print("API 返回的歌曲数量: \(data.count)")
                        
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
                                self.logout()
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
        guard isLoggedIn else {
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
        guard !userId.isEmpty else {
            print("匹配失败: 用户ID为空")
            completion(false, "用户ID为空", nil)
            return
        }

        let urlString = "https://music.163.com/api/cloud/user/song/match?userId=\(userId)&songId=\(cloudSongId)&adjustSongId=\(matchSongId)"
        guard let url = URL(string: urlString) else {
            print("发送匹配请求失败: 无效的URL")
            completion(false, "Invalid URL", nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
                
        // 添加Cookie
        // if !userToken.isEmpty {
        //     request.setValue("MUSIC_U=\(userToken)", forHTTPHeaderField: "Cookie")
        // }
        
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

struct CloudSong: Identifiable, Equatable, Comparable {
    var id: String  // 改为可变
    let name: String
    let artist: String
    let album: String
    let fileName: String
    let fileSize: Int64
    let bitrate: Int
    let addTime: Date
    let picUrl: String
    let duration: Int
    var matchStatus: MatchStatus = .notMatched
    var matchId: String?  // 新增属性
    
    enum MatchStatus: Equatable {
        case notMatched
        case matched
        case failed(String)
        
        static func == (lhs: MatchStatus, rhs: MatchStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notMatched, .notMatched), (.matched, .matched):
                return true
            case let (.failed(lhsMessage), .failed(rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
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
                print("Comparing \(lhs.name) with \(rhs.name) using \(comparator.keyPath): \(result)")
                return result
            }
        }
        print("All comparisons were equal for \(lhs.name) and \(rhs.name)")
        return .orderedSame
    }

    static func == (lhs: CloudSong, rhs: CloudSong) -> Bool {
        lhs.id == rhs.id
    }
}

extension CloudSong.MatchStatus: Comparable {
    static func < (lhs: CloudSong.MatchStatus, rhs: CloudSong.MatchStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notMatched, .matched), (.notMatched, .failed), (.failed, .matched):
            return true
        case (.matched, _), (_, .notMatched), (.failed, .failed):
            return false
        }
    }
}

// 字典扩展 - 用于处理网络请求参数
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

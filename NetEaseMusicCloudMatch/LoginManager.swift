//
//  LoginManager.swift
//  NetEaseMusicCloudMatch
//
//  Created by zhiozhou on 2024/10/25.
//


import Foundation
import CoreImage
import AppKit
import Security
import CryptoKit

class LoginManager: ObservableObject {
    static let shared = LoginManager()
    
    @Published var qrCodeImage: NSImage?
    @Published var isLoggedIn = false
    @Published var username = ""
    @Published var userAvatarURL: URL?
    @Published var qrCodeStatus: QRCodeStatus = .loading
    @Published var userAvatar: NSImage?
    
    private var key: String = ""
    private var qrCodeUrl: String = ""
    private var timer: Timer?
    
    private let secretKey = "TA3YiYCfY2dDJQgg"
    private let encSecKey = "84ca47bca10bad09a6b04c5c927ef077d9b9f1e37098aa3eac6ea70eb59df0aa28b691b7e75e4f1f9831754919ea784c8f74fbfadf2898b0be17849fd656060162857830e241aba44991601f137624094c114ea8d17bce815b0cd4e5b8e2fbaba978c6d1d14dc3d1faf852bdd28818031ccdaaa13a6018e1024e2aae98844210"
    
    private var userToken: String = ""
    
    private let loginExpirationDays = 30 // 登录信息过期天数，设置为30天
    
    private var isLoadingUserInfo = false
    
    @Published var cloudSongs: [CloudSong] = []
    @Published var isLoadingCloudSongs = false
    
    @Published var userId: String = ""
    
    @Published private(set) var isGettingQRCode = false
    
    enum QRCodeStatus {
        case loading
        case ready
        case expired
    }
    
    private init() {
        loadUserInfo()
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
    
    private func loadUserInfo() {
        guard !isLoadingUserInfo else { return }
        isLoadingUserInfo = true
        
        if let savedUsername = UserDefaults.standard.string(forKey: "username"),
           let savedToken = UserDefaults.standard.string(forKey: "userToken"),
           let savedAvatarURL = UserDefaults.standard.url(forKey: "userAvatarURL"),
           let savedUserId = UserDefaults.standard.string(forKey: "userId"),
           let loginTime = UserDefaults.standard.object(forKey: "loginTime") as? Date {
            
            // 检查登录是否过期
            if Date().timeIntervalSince(loginTime) < Double(loginExpirationDays * 24 * 60 * 60) {
                username = savedUsername
                userToken = savedToken
                userAvatarURL = savedAvatarURL
                userId = savedUserId
                isLoggedIn = true
                
                // 打印从本地加载的用户信息
                print("本地加载的用户信息:")
                print("用户名: \(username)")
                print("用户ID: \(userId)")
                print("头像URL: \(userAvatarURL?.absoluteString ?? "无")")
                print("登录时间: \(loginTime)")
                print("用户Token: \(userToken)")
                
                // 加载头像
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
    
    private func saveUserInfo() {
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(userToken, forKey: "userToken")
        UserDefaults.standard.set(userAvatarURL, forKey: "userAvatarURL")
        UserDefaults.standard.set(Date(), forKey: "loginTime")
        print("用户信息已保存")
    }
    
    private func clearUserInfo() {
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "userToken")
        UserDefaults.standard.removeObject(forKey: "userAvatarURL")
        UserDefaults.standard.removeObject(forKey: "loginTime")
        UserDefaults.standard.removeObject(forKey: "userId")
        print("用户信息已清除")
    }
    
    private func getQRKey() {
        print("正在获取二维码 key")
        let urlString = "https://music.163.com/api/login/qrcode/unikey?type=1"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("获取二维码 key 时出错: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP 状态码: \(httpResponse.statusCode)")
            }
            
            if let data = data, !data.isEmpty {
                print("收到的数据: \(String(data: data, encoding: .utf8) ?? "无法解码")")
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let code = json["code"] as? Int, code == 200 {
                            if let unikey = json["unikey"] as? String {
                                print("成功获取二维码 key: \(unikey)")
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
    
    private func getQRCode() {
        print("正在生成二维码")
        qrCodeUrl = "https://music.163.com/login?codekey=\(key)"
        generateQRCode(from: qrCodeUrl)
        qrCodeStatus = .ready
        startPolling()
    }
    
    private func generateQRCode(from string: String) {
        let data = string.data(using: String.Encoding.ascii)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            if let output = filter.outputImage?.transformed(by: transform) {
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
    
    private func startPolling() {
        print("开始轮询登录状态")
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.checkLoginStatus()
        }
    }
    
    private func checkLoginStatus() {
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
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "key": key,
            "type": 1
        ]
        request.httpBody = parameters.percentEncoded()
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("检查登录状态时出错: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP 状态码: \(httpResponse.statusCode)")
            }
            
            if let data = data, !data.isEmpty {
                print("收到的数据: \(String(data: data, encoding: .utf8) ?? "无法解码")")
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let code = json["code"] as? Int {
                            print("收到登录状态响应，代码: \(code)")
                            DispatchQueue.main.async {
                                switch code {
                                case 803:
                                    self.isLoggedIn = true
                                    // 保存userToken
                                    if let cookie = (response as? HTTPURLResponse)?.allHeaderFields["Set-Cookie"] as? String {
                                        self.userToken = cookie
                                    }
                                    self.stopPolling()
                                    print("登录成功")
                                    self.getUserInfo()
                                case 800:
                                    if !self.isLoggedIn {
                                        print("二维码过期")
                                        self.qrCodeStatus = .expired
                                        self.stopPolling()
                                    }
                                default:
                                    if !self.isLoggedIn {
                                        print("尚未登录，继续等待")
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
    
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func getUserInfo() {
        let urlString = "https://music.163.com/api/nuser/account/get"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("获取用户信息时出错: \(error)")
                return
            }
            
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let profile = json["profile"] as? [String: Any] {
                        DispatchQueue.main.async {
                            self.username = profile["nickname"] as? String ?? "未知用户"
                            self.userId = String(profile["userId"] as? Int ?? 0)
                            UserDefaults.standard.set(self.userId, forKey: "userId")
                            
                            if let avatarUrlString = profile["avatarUrl"] as? String,
                               let avatarUrl = URL(string: avatarUrlString) {
                                self.userAvatarURL = avatarUrl
                                print("准备下载头像: \(avatarUrl)")
                                self.downloadUserAvatar(from: avatarUrl)
                            } else {
                                print("无法获取头像 URL")
                            }
                            
                            // 打印用户信息
                            print("用户信息:")
                            print("用户名: \(self.username)")
                            print("头像URL: \(self.userAvatarURL?.absoluteString ?? "无")")
                            print("其他信息: \(profile)")
                            
                            // 保存用户信息
                            self.saveUserInfo()
                            
                            // 登录成功后自动获歌曲
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
    
    private func downloadUserAvatar(from url: URL) {
        print("开始下载头像: \(url)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("载头像时出错: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("头像下载 HTTP 状态码: \(httpResponse.statusCode)")
            }
            
            if let data = data {
                print("收到头像数据，大小: \(data.count) 字节")
                if let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self.userAvatar = image
                        print("头像成功下载并设，大小: \(image.size)")
                    }
                } else {
                    print("法从创建 NSImage")
                }
            } else {
                print("没有收到头像数据")
            }
        }.resume()
    }
    
    func logout() {
        clearUserInfo()
        stopPolling()
        qrCodeStatus = .loading
        isLoggedIn = false
        username = ""
        userAvatar = nil
        userId = ""
        userToken = ""
        cloudSongs = []
        startLoginProcess()
    }
    
    func fetchCloudSongs() {
        guard isLoggedIn else {
            print("用户未登录，无法获取云盘歌曲")
            return
        }
        
        print("开始获取云盘歌曲")
        isLoadingCloudSongs = true
        
        let urlString = "https://music.163.com/api/v1/cloud/get"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for cloud songs")
            isLoadingCloudSongs = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 添加必要的cookie
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 添加用户Token到请头
        if !userToken.isEmpty {
            request.setValue(userToken, forHTTPHeaderField: "MUSIC_U")
        }
        
        let parameters: [String: Any] = [
            "limit": 2,
            "offset": 0
        ]
        request.httpBody = parameters.percentEncoded()
        
        print("请求URL: \(urlString)")
        print("请求头: \(request.allHTTPHeaderFields ?? [:])")
        print("请求体: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "None")")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { DispatchQueue.main.async { self.isLoadingCloudSongs = false } }
            
            if let error = error {
                print("获取云盘歌曲时出错: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("云盘歌曲请求 HTTP 状态码: \(httpResponse.statusCode)")
                print("响应头: \(httpResponse.allHeaderFields)")
            }
            
            guard let data = data else {
                print("没有收到云盘歌曲数据")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("解析后的云盘歌曲 JSON: \(json)")
                    if let code = json["code"] as? Int, code == 200,
                       let data = json["data"] as? [[String: Any]] {
                        print("API 返回的歌曲数量: \(data.count)")
                        
                        
                        let songs = data.compactMap { CloudSong(json: $0) }
                        print("成功解析的歌曲数量: \(songs.count)")
                        DispatchQueue.main.async {
                            self.cloudSongs = songs
                            print("成功获取 \(songs.count) 首云盘歌曲")
                            print("歌曲列表:")
                            for (index, song) in songs.enumerated() {
                                print("\(index + 1). \(song.name) - \(song.artist)")
                            }
                        }
                    } else {
                        print("无法从 JSON 中解析出云盘歌曲数据")
                        if let code = json["code"] as? Int {
                            print("返回的错误代码: \(code)")
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
    
    func matchCloudSong(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String) -> Void) {
        guard isLoggedIn else {
            print("匹配失败: 用户未登录")
            completion(false, "用户未登录")
            return
        }
        
        print("开始匹配歌曲")
        print("云盘歌曲ID: \(cloudSongId)")
        print("匹配歌曲ID: \(matchSongId)")
        print("用户ID: \(userId)")
        print("用户Token: \(userToken)")
        
        // 检查云盘文件是否存在
        guard let _ = cloudSongs.first(where: { $0.id == cloudSongId }) else {
            print("匹配失败: 云盘文件不存在")
            completion(false, "云盘文件不存在")
            return
        }
        
        // 直接送匹配请求，不再预先检查匹配歌曲ID
        sendMatchRequest(cloudSongId: cloudSongId, matchSongId: matchSongId) { success, message in
            DispatchQueue.main.async {
                if let index = self.cloudSongs.firstIndex(where: { $0.id == cloudSongId }) {
                    if success {
                        self.cloudSongs[index].matchStatus = .matched
                    } else {
                        self.cloudSongs[index].matchStatus = .failed(message)
                    }
                }
                completion(success, message)
            }
        }
    }
    
    private func sendMatchRequest(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String) -> Void) {
        guard !userId.isEmpty else {
            print("匹配失败: 用户ID为空")
            completion(false, "用户ID为空")
            return
        }

        let urlString = "https://music.163.com/api/cloud/user/song/match?userId=\(userId)&songId=\(cloudSongId)&adjustSongId=\(matchSongId)"
        guard let url = URL(string: urlString) else {
            print("发送匹配请求失败: 无效的URL")
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 设置完整的 Cookie
        //let fullCookie = "MUSIC_U=\(userToken); MUSIC_A_T=\(userToken)"
        // request.setValue(fullCookie, forHTTPHeaderField: "Cookie")
        
        
        print("发送匹配请求: \(urlString)")
        print("请求头: \(request.allHTTPHeaderFields ?? [:])")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("匹配请求败: \(error.localizedDescription)")
                completion(false, "匹配请求失败: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("匹配请求响应状态码: \(httpResponse.statusCode)")
                print("响应头: \(httpResponse.allHeaderFields)")
            }
            
            guard let data = data else {
                print("匹配请求没有返回数据")
                completion(false, "无法解析响应")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("匹配响应: \(json)")
                    if let code = json["code"] as? Int {
                        switch code {
                        case 200:
                            print("匹配成功")
                            completion(true, "匹配成功")
                        default:
                            let msg = json["message"] as? String ?? "未知错误"
                            print("匹配失败 (code: \(code)): \(msg)")
                            completion(false, "匹配失败: 错误代码 \(code), \(msg)")
                        }
                    } else {
                        print("匹配响应中没有code字段")
                        completion(false, "无法解析响应")
                    }
                } else {
                    print("无法将响应解析为JSON")
                    completion(false, "无法解析响应")
                }
            } catch {
                print("解析匹配响应时发生错误: \(error.localizedDescription)")
                completion(false, "无法解析响应")
            }
        }.resume()
    }
}

struct CloudSong: Identifiable, Equatable, Comparable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let fileName: String
    let fileSize: Int64
    let bitrate: Int
    let addTime: Date
    let picUrl: String
    var matchStatus: MatchStatus = .notMatched
    
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

extension Dictionary {
    func percentEncoded() -> Data? {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension String {
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// 辅助函数
extension LoginManager {
    private func createSecretKey(size: Int) -> String {
        return secretKey
    }
    
    private func aesEncrypt(_ text: String, key: String) -> String {
        guard let data = text.data(using: .utf8),
              let keyData = key.data(using: .utf8) else {
            print("AES encryption error: Failed to encode text or key")
            return ""
        }
        
        do {
            let key = SymmetricKey(data: keyData)
            let iv = "0102030405060708".data(using: .utf8)!
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: iv))
            return sealedBox.combined?.base64EncodedString() ?? ""
        } catch {
            print("AES encryption error: \(error)")
            return ""
        }
    }
    
    private func rsaEncrypt(_ text: String, pubKey: String, modulus: String) -> String {
        // 这里我们忽略传入的参数，直接回预定义的encSecKey
        return encSecKey
    }
}

extension String {
    func padLeft(toLength: Int, withPad: String) -> String {
        guard toLength > self.count else { return self }
        let padding = String(repeating: withPad, count: toLength - self.count)
        return padding + self
    }
}

// 添加随机IP生成函数
private func RandomIp() -> String {
    return (1...4).map { _ in String(Int.random(in: 1...255)) }.joined(separator: ".")
}




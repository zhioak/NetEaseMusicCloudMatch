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
    
    private let networkManager = NetworkManager.shared
    
    // MARK: - Published 属性
    // 这些属性使用 @Published 包装器，当值改变时会自动通知 UI 更新
    @Published var qrCodeImage: NSImage?         // 登录二维码图片
    @Published var isLoggedIn = false           // 登录状态
    @Published var username = ""                 // 用户名
    @Published var userAvatarURL: URL?          // 用户头像URL
    @Published var qrCodeStatus: QRCodeStatus = .loading  // 二维码状态
    @Published var userAvatar: NSImage?         // 用户头像图片
    @Published private(set) var isGettingQRCode = false // 是否正在获取二维码
    @Published var userId: String = ""          // 用户ID
    
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
        networkManager.get(
            endpoint: "https://music.163.com/api/login/qrcode/unikey",
            parameters: ["type": 1]
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let json):
                if let code = json["code"] as? Int, code == 200,
                   let unikey = json["unikey"] as? String {
                    print("成功获取二维码 key: \(unikey)")
                    DispatchQueue.main.async {
                        self.key = unikey
                        self.getQRCode()
                    }
                } else {
                    print("无法从响应中解析 unikey")
                }
            case .failure(let error):
                print("获取二维码 key 失败: \(error)")
            }
        }
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
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkLoginStatus()
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
        networkManager.post(
            endpoint: "https://music.163.com/api/login/qrcode/client/login",
            parameters: ["key": key, "type": 1]
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let json):
                if let code = json["code"] as? Int {
                    DispatchQueue.main.async {
                        switch code {
                        case 803: // 登录成功
                            self.isLoggedIn = true
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
                }
            case .failure(let error):
                print("检查登录状态失败: \(error)")
            }
        }
    }
    
    // 停止登录状态轮询
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    // 获取用户信息
    private func getUserInfo() {
        networkManager.post(
            endpoint: "https://music.163.com/api/nuser/account/get"
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let json):
                if let profile = json["profile"] as? [String: Any] {
                    DispatchQueue.main.async {
                        self.username = profile["nickname"] as? String ?? "未知用户"
                        self.userId = String(profile["userId"] as? Int ?? 0)
                        UserDefaults.standard.set(self.userId, forKey: "userId")
                        
                        if let avatarUrlString = profile["avatarUrl"] as? String,
                           let avatarUrl = URL(string: avatarUrlString) {
                            self.userAvatarURL = avatarUrl
                            print("准备下载头像: \(avatarUrl)")
                            self.downloadUserAvatar(from: avatarUrl)
                        }
                        
                        self.saveUserInfo()
                    }
                }
            case .failure(let error):
                print("获取用户信息失败: \(error)")
            }
        }
    }
    
    // 下载用户头像
    private func downloadUserAvatar(from url: URL) {
        networkManager.downloadImage(from: url) { [weak self] result in
            switch result {
            case .success(let data):
                if let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self?.userAvatar = image
                    }
                }
            case .failure(let error):
                print("下载头像失败: \(error)")
            }
        }
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
        // 重新开始登录流程
        startLoginProcess()
    }
}

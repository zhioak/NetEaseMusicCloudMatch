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
    private let userManager = UserManager.shared
    
    // MARK: - Published 属性
    // 这些属性使用 @Published 包装器，当值改变时会自动通知 UI 更新
    @Published var qrCodeImage: NSImage?         // 登录二维码图片
    @Published var qrCodeStatus: QRCodeStatus = .loading  // 二维码状态
    @Published var isGettingQRCode = false      // 是否正在获取二维码
    
    // MARK: - 计算属性
    var isLoggedIn: Bool { userManager.isLoggedIn }
    
    // MARK: - 私有属性
    private var key: String = ""                // 二维码key
    private var qrCodeUrl: String = ""          // 二维码URL
    private var timer: Timer?                   // 用于轮询登录状态的定时器
    
    // 加密相关的密钥
    // 这些是网易云音乐API需要的固定值，用于请求加密
    private let secretKey = "TA3YiYCfY2dDJQgg"
    private let encSecKey = "84ca47bca10bad09a6b04c5c927ef077d9b9f1e37098aa3eac6ea70eb59df0aa28b691b7e75e4f1f9831754919ea784c8f74fbfadf2898b0be17849fd656060162857830e241aba44991601f137624094c114ea8d17bce815b0cd4e5b8e2fbaba978c6d1d14dc3d1faf852bdd28818031ccdaaa13a6018e1024e2aae98844210"
    
    // MARK: - 枚举定义
    // 二维码状态枚举
    enum QRCodeStatus {
        case loading   // 加载中
        case ready    // 已准备好
        case expired  // 已过期
    }
    
    // MARK: - 初始化方法
    private init() {}
    
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
        guard !userManager.isLoggedIn else {
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
                            self.stopPolling()
                            print("登录成功")
                            self.getUserInfo()
                        case 800: // 二维码过期
                            if !self.userManager.isLoggedIn {
                                print("二维码过期")
                                self.qrCodeStatus = .expired
                                self.stopPolling()
                            }
                        default: // 等待扫码
                            if !self.userManager.isLoggedIn {
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
            switch result {
            case .success(let json):
                if let profile = json["profile"] as? [String: Any] {
                    DispatchQueue.main.async {
                        UserManager.shared.updateUserInfo(from: profile)
                        // 登录成功后获取一次云盘歌曲
                        CloudSongManager.shared.fetchCloudSongs()
                    }
                }
            case .failure(let error):
                print("获取用户信息失败: \(error)")
            }
        }
    }
    
    // 退出登录
    func logout() {
        userManager.clearUserInfo()
        stopPolling()
        qrCodeStatus = .loading
        startLoginProcess()
    }
}

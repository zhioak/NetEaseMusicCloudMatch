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
    
    // MARK: - 私有属性
    private var qrCodeUrl: String = ""          // 二维码URL
    private var timer: Timer?                   // 用于轮询登录状态的定时器
    
    private var userToken: String? = nil
    
    // 加密相关的密钥
    // 这些是网易云音乐API需要的固定值，用于请求加密
    private let secretKey = "TA3YiYCfY2dDJQgg"
    private let encSecKey = "84ca47bca10bad09a6b04c5c927ef077d9b9f1e37098aa3eac6ea70eb59df0aa28b691b7e75e4f1f9831754919ea784c8f74fbfadf2898b0be17849fd656060162857830e241aba44991601f137624094c114ea8d17bce815b0cd4e5b8e2fbaba978c6d1d14dc3d1faf852bdd28818031ccdaaa13a6018e1024e2aae98844210"
    
    // MARK: - 枚举定义
    enum QRCodeStatus: Equatable {
        case loading   // 加载中
        case ready    // 已准备好，等待扫码
        case expired  // 已过期
        case success  // 登录成功
        case failed(String)   // 失败，带错误信息
        
        // 实现 Equatable 协议
        static func == (lhs: QRCodeStatus, rhs: QRCodeStatus) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading),
                 (.ready, .ready),
                 (.expired, .expired),
                 (.success, .success):
                return true
            case (.failed(let lhsMessage), .failed(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    // MARK: - 初始化方法
    private init() {}
    
    @MainActor
    func startLoginProcess() {
        if userManager.isLoggedIn {
            print("用户已登录")
            return
        }
        // if isGettingQRCode {
        //     print("正在获取二维码，请稍候")
        //     return
        // }
        print("开始登录流程")
        qrCodeStatus = .loading
        
        // Task {
        //     if let unikey = await getQRCodeKey(),
        //        let qrImage = generateQRCode(unikey: unikey) {
        //         qrCodeImage = qrImage
        //         qrCodeStatus = .ready
        //         startPolling(unikey: unikey)
        //     }
        // }
    }
    
    // 获取登录二维码的key，直接返回 unikey
    private func getQRCodeKey() async -> String? {
        print("正在获取二维码 key")
        
        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                networkManager.get(
                    endpoint: "https://music.163.com/api/login/qrcode/unikey",
                    parameters: ["type": 1]
                ) { result in
                    continuation.resume(with: result)
                }
            }
            
            let (json, _) = result  // 解构返回的元组
            
            if let code = json["code"] as? Int,
               code == 200,
               let unikey = json["unikey"] as? String {
                print("成功获取二维码 key: \(unikey)")
                return unikey
            } else {
                print("无法从响应中解析 unikey")
                return nil
            }
        } catch {
            print("获取二维码 key 失败: \(error)")
            return nil
        }
    }

    
    // 获取用户信息，只负责获取数据
    private func getUserInfo() async -> [String: Any]? {
        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                networkManager.post(
                    endpoint: "https://music.163.com/api/nuser/account/get"
                ) { result in
                    continuation.resume(with: result)
                }
            }
            
            let (json, _) = result  // 解构返回的元组
            
            if let profile = json["profile"] as? [String: Any] {
                return profile
            } else {
                print("获取用户信息失败：无效的数据格式")
                return nil
            }
        } catch {
            print("获取用户信息失败: \(error)")
            return nil
        }
    }
    
    // 退出登录
    @MainActor
    func logout() async {
        userToken = nil  // 现在可以正确地设置为 nil
        userManager.clearUserInfo()
        SongManager.shared.clearCloudData()
        qrCodeStatus = .loading
        startLoginProcess()
    }
    
    // 添加获取 userToken 的方法
    func getUserToken() -> String? {
        return userToken
    }
    
    // MARK: - Cookie登录方法
    @MainActor
    func loginWithCookie(_ cookie: String) async {
        if userManager.isLoggedIn {
            print("用户已登录")
            return
        }
        
        print("开始Cookie登录流程")
        qrCodeStatus = .loading
        
        // 先设置cookie到UserManager，这样NetworkManager就能获取到token
        self.userToken = cookie
        userManager.setTemporaryToken(cookie)
        
        if let profile = await getUserInfo() {
            userManager.updateUserInfo(from: profile, token: cookie)
            qrCodeStatus = .success
            print("Cookie登录成功")
            // 登录成功后立刻拉取歌曲
            SongManager.shared.fetchPage(page: 1, limit: 200)
        } else {
            qrCodeStatus = .failed("无法获取用户信息，请检查Cookie是否有效")
            print("Cookie登录失败：无法获取用户信息")
            // 如果获取用户信息失败，清除临时信息
            userManager.clearUserInfo()
        }
    }
}

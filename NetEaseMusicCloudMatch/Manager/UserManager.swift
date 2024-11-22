import AppKit

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published private(set) var userInfo: UserInfo?
    private let loginExpirationDays = 30
    private var isLoadingUserInfo = false
    
    // MARK: - 计算属性
    var username: String { userInfo?.username ?? "" }
    var userId: String { userInfo?.userId ?? "" }
    var userAvatar: NSImage? { userInfo?.avatar }
    var userAvatarURL: URL? { userInfo?.avatarURL }
    var isLoggedIn: Bool { userInfo != nil }
    
    private init() {
        loadUserInfo()
    }
    
    // 加载用户信息
    func loadUserInfo() {
        guard !isLoadingUserInfo else { return }
        isLoadingUserInfo = true
        
        if let savedData = UserDefaults.standard.data(forKey: "userInfo"),
           let savedUserInfo = try? JSONDecoder().decode(UserInfo.self, from: savedData),
           Date().timeIntervalSince(savedUserInfo.loginTime) < Double(loginExpirationDays * 24 * 60 * 60) {
            
            self.userInfo = savedUserInfo
            
            if let avatarURL = savedUserInfo.avatarURL {
                downloadUserAvatar(from: avatarURL)
            }
            
            print("成功加载用户信息: \(savedUserInfo.username)")
        } else {
            print("没有找到有效的用户信息")
            clearUserInfo()
        }
        
        isLoadingUserInfo = false
    }
    
    // 更新用户信息
    func updateUserInfo(from profile: [String: Any], token: String? = nil) {
        let newUserInfo = UserInfo(
            username: profile["nickname"] as? String ?? "未知用户",
            userId: String(profile["userId"] as? Int ?? 0),
            avatarURL: URL(string: profile["avatarUrl"] as? String ?? ""),
            token: token ?? userInfo?.token ?? "",
            loginTime: Date()
        )
        
        self.userInfo = newUserInfo
        if let userInfo = userInfo,
           let encodedData = try? JSONEncoder().encode(userInfo) {
            UserDefaults.standard.set(encodedData, forKey: "userInfo")
            print("用户信息已保存")
        }
        
        if let avatarUrlString = profile["avatarUrl"] as? String,
           let avatarUrl = URL(string: avatarUrlString) {
            downloadUserAvatar(from: avatarUrl)
        }
    }
    
    // 清除用户信息
    func clearUserInfo() {
        userInfo = nil
        UserDefaults.standard.removeObject(forKey: "userInfo")
        print("用户信息已清除")
    }
    
    // 下载用户头像
    private func downloadUserAvatar(from url: URL) {
        NetworkManager.shared.downloadImage(from: url) { [weak self] result in
            switch result {
            case .success(let data):
                if let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        var updatedUserInfo = self?.userInfo
                        updatedUserInfo?.avatar = image
                        self?.userInfo = updatedUserInfo
                    }
                }
            case .failure(let error):
                print("下载头像失败: \(error)")
            }
        }
    }
    
    // 获取当前用户的token
    func getToken() -> String? {
        return userInfo?.token
    }
} 
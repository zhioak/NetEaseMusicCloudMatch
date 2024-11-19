import SwiftUI

// 主视图结构体
struct ContentView: View {
    // 状态管理
    @StateObject private var loginManager = LoginManager.shared  // 使用单例模式管理登录状态
    @State private var searchText = ""      // 搜索框的文本
    @State private var matchLogs: [LogInfo] = []  // 更新类型
    @StateObject private var songManager = SongManager.shared
    @StateObject private var userManager = UserManager.shared
    
    var body: some View {
        // 使用GeometryReader来获取可用空间尺寸，实现响应式布局
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 根据登录状态显示不同的界面
                if !userManager.isLoggedIn {
                    // 将 LoginView 包装在 VStack 中并居中
                    VStack {
                        Spacer()
                        LoginView(loginManager: loginManager)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // 主界面布局
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部工具栏：含用户信息和搜索栏
                        HeaderView(loginManager: loginManager, searchText: $searchText)
                        
                        // 音乐列表视图 - 使用双向绑定确保数据同步
                        SongListView(
                            songs: Binding(
                                get: { self.songManager.cloudSongs },
                                set: { self.songManager.cloudSongs = $0 }
                            ),
                            searchText: $searchText,
                            performMatch: performMatch
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height * 0.65) // 将表格高度调整为窗口高度的65%
                        
                        // 终端风格的日志视图容器
                        VStack(spacing: 0) {
                            // 添加分割线
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                            
                            LogView(logs: matchLogs)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        // 调整未登录状态下的窗口尺寸为 260x400
        .frame(
            minWidth: userManager.isLoggedIn ? 800 : 260,
            minHeight: userManager.isLoggedIn ? 500 : 400
        )
        .task {
            if !userManager.isLoggedIn {
                loginManager.startLoginProcess()
            }
            // 只在已登录状态下获取一次歌曲列表
            else if songManager.cloudSongs.isEmpty {
                songManager.fetchCloudSongs()
            }
        }
    }
    
    // 执行匹配操作的函数
    private func performMatch(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        // 验证输入
        guard !matchSongId.isEmpty else {
            let message = "请输入匹配ID"
            matchLogs.append(LogInfo(
                songName: "",
                cloudSongId: cloudSongId,
                matchSongId: "",
                message: message,
                isSuccess: false
            ))
            completion(false, message)
            return
        }
        
        // 获取当前歌曲名称
        let songName = songManager.cloudSongs.first(where: { $0.id == cloudSongId })?.name ?? "未知歌曲"
        
        // 调用匹配API
        songManager.matchCloudSong(cloudSongId: cloudSongId, matchSongId: matchSongId) { success, message, updatedSong in
            DispatchQueue.main.async {
                matchLogs.append(LogInfo(
                    songName: songName,
                    cloudSongId: cloudSongId,
                    matchSongId: matchSongId,
                    message: message,
                    isSuccess: success
                ))
                
                // 保留更新歌曲信息的逻辑
                if success, let song = updatedSong {
                    if let index = self.songManager.cloudSongs.firstIndex(where: { $0.id == cloudSongId }) {
                        self.songManager.cloudSongs[index] = song
                    }
                }
                
                completion(success, message)
            }
        }
    }
}

// 预览提供者
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}




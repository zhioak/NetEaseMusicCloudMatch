import SwiftUI

// 主视图结构体
struct ContentView: View {
    // 状态管理
    @StateObject private var loginManager = LoginManager.shared  // 使用单例模式管理登录状态
    @State private var searchText = ""      // 搜索框的文本
    @State private var matchLogs: [LogEntry] = []  // 更新类型
    @StateObject private var songManager = CloudSongManager.shared
    
    var body: some View {
        // 使用GeometryReader来获取可用空间尺寸，实现响应式布局
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 根据登录状态显示不同的界面
                if !loginManager.isLoggedIn {
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
                        // 顶部工具栏：包含用户信息和搜索栏
                        HStack {
                            // 用户信息区域：头像和用户名
                            HStack(spacing: 10) {
                                // 用户头像 - 如果有头像则显示，否则显示默认图标
                                if let avatar = loginManager.userAvatar {
                                    Image(nsImage: avatar)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .cornerRadius(4)  // 圆角效果提升视觉体验
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .cornerRadius(4)
                                }
                                
                                // 用户名和登出按钮垂直排列
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loginManager.username)
                                        .fontWeight(.medium)
                                    Button("Sign Out") {
                                        loginManager.logout()
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                }
                            }
                            
                            Spacer()
                            
                            // 搜索栏 - 使用HStack组合搜索图标和输入框
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("搜索音乐", text: $searchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .frame(width: 200)
                            }
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            
                            // 刷新按钮 - 用于重新加载云盘音乐
                            Button(action: {
                                songManager.fetchCloudSongs()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.leading, 10)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // 音乐列表视图 - 使用双向绑定确保数据同步
                         SongTableView(
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
            minWidth: loginManager.isLoggedIn ? 800 : 260,
            minHeight: loginManager.isLoggedIn ? 500 : 400
        )
        .onAppear {
            // 视图出现时根据登录状态执行相应操作
            if loginManager.isLoggedIn {
                songManager.fetchCloudSongs()
            } else {
                loginManager.startLoginProcess()
            }
        }
    }
    
    // 执行匹配操作的函数
    private func performMatch(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        // 验证输入
        guard !matchSongId.isEmpty else {
            let message = "请输入匹配ID"
            matchLogs.append(LogEntry(
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
                matchLogs.append(LogEntry(
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




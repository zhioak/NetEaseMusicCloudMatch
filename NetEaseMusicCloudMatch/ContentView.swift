import SwiftUI

// 主视图结构体
struct ContentView: View {
    // 状态管理
    @StateObject private var loginManager = LoginManager.shared  // 使用单例模式管理登录状态
    @State private var searchText = ""      // 搜索框的文本
    @StateObject private var songManager = SongManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var currentPage = 1  // 添加页码状态
    @State private var pageSize = 200  // 添加页面大小状态
    
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
                        HeaderView(
                            loginManager: loginManager, 
                            searchText: $searchText,
                            currentPage: $currentPage,
                            pageSize: $pageSize  // 传递 pageSize
                        )
                        
                        // 音乐列表视图 - 使用双向绑定确保数据同步
                        SongListView(
                            songs: Binding(
                                get: { self.songManager.cloudSongs },
                                set: { self.songManager.cloudSongs = $0 }
                            ),
                            searchText: $searchText,
                            currentPage: $currentPage,
                            pageSize: $pageSize  // 传递 pageSize
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height * 0.65) // 将表格高度调整为窗口高度的65%
                        
                        // 终端风格的日志视图容器
                        VStack(spacing: 0) {
                            // 添加分割线
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                            
                            LogView(
                                logs: songManager.matchLogs,
                                onClear: {
                                    songManager.matchLogs.removeAll()
                                }
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        // 调整未登录状态下的窗口尺寸为 260x400
        .frame(
            minWidth: userManager.isLoggedIn ? 800 : 120,
            minHeight: userManager.isLoggedIn ? 500 : 150
        )
        .task {
            if !userManager.isLoggedIn {
                loginManager.startLoginProcess()
            }
            // 只在已登录状态下获取一次歌曲列表，使用 SongListView 的 pageSize
            else if songManager.cloudSongs.isEmpty {
                songManager.fetchPage(page: currentPage, limit: pageSize)
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




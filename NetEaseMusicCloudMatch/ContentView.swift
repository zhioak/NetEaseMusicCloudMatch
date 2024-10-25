import SwiftUI

// 排序列枚举
enum SortColumn: String {
    case name = "歌曲名"
    case artist = "艺术家"
    case addTime = "上传时间"
}

// 排序方向枚举
enum SortOrder {
    case ascending, descending
}

// 在文件顶部，ContentView 结构体之外定义这些常量
private let columnPadding: CGFloat = 8

// 主视图
struct ContentView: View {
    @StateObject private var loginManager = LoginManager.shared
    @State private var searchText = ""
    @State private var selectedSongId: String?
    @State private var matchInputText = ""
    @State private var isMatching = false
    @State private var matchResult: String?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if !loginManager.isLoggedIn {
                    LoginView(loginManager: loginManager)
                } else {
                    // 主界面
                    VStack(alignment: .leading, spacing: 8) {
                        // 用户信息和搜索栏
                        HStack {
                            // 用户头像、用户名和注销按钮
                            HStack(spacing: 10) {
                                if let avatar = loginManager.userAvatar {
                                    Image(nsImage: avatar)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .cornerRadius(4)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .cornerRadius(4)
                                }
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
                            
                            // 搜索栏
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
                            
                            // 刷新按钮
                            Button(action: {
                                print("开始加载云盘音乐")
                                loginManager.fetchCloudSongs()
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
                        
                        // 音乐列表
                        CloudSongTableView(songs: Binding(
                            get: { self.loginManager.cloudSongs },
                            set: { self.loginManager.cloudSongs = $0 }
                        ), selectedSongId: $selectedSongId, searchText: $searchText)
                            .frame(maxWidth: .infinity)
                            .frame(height: geometry.size.height * 0.5)
                        
                        // 选中音乐项的详细信息和匹配功能
                        VStack(alignment: .leading, spacing: 10) {
                            if let selectedId = selectedSongId,
                               let selectedItem = loginManager.cloudSongs.first(where: { $0.id == selectedId }) {
                                Text("已选中: \(selectedItem.name)")
                                
                                HStack {
                                    Text("歌曲ID:")
                                    Text(selectedItem.id)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    TextField("匹配歌曲ID", text: $matchInputText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("确认匹配") {
                                        performMatch()
                                    }
                                    .disabled(selectedSongId == nil || matchInputText.isEmpty || isMatching)
                                }
                            } else {
                                Text("请选择歌曲")
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(height: 100)
                        .padding(.horizontal)
                        
                        if isMatching {
                            ProgressView()
                        }
                        if let result = matchResult {
                            Text(result)
                                .foregroundColor(result.contains("成功") ? .green : .red)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .frame(minWidth: 550, minHeight: 500)
        .onAppear {
            if loginManager.isLoggedIn {
                loginManager.fetchCloudSongs()
            } else {
                loginManager.startLoginProcess()
            }
        }
    }
    
    private func performMatch() {
        guard let selectedId = selectedSongId, !matchInputText.isEmpty else {
            matchResult = "请选择一首歌曲并输入匹配ID"
            return
        }
        
        isMatching = true
        matchResult = nil
        
        loginManager.matchCloudSong(cloudSongId: selectedId, matchSongId: matchInputText) { success, message in
            DispatchQueue.main.async {
                isMatching = false
                matchResult = message
                if success {
                    loginManager.fetchCloudSongs()
                }
            }
        }
    }
}

struct SortableColumnHeader: View {
    let title: String
    @Binding var currentSort: SortColumn
    @Binding var currentOrder: SortOrder
    let column: SortColumn
    let width: CGFloat
    
    var body: some View {
        Button(action: {
            if currentSort == column {
                currentOrder = currentOrder == .ascending ? .descending : .ascending
            } else {
                currentSort = column
                currentOrder = .ascending
            }
        }) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                Spacer()
                if currentSort == column {
                    Image(systemName: currentOrder == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .padding(.horizontal, columnPadding)
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
    }
}

// 登录视图
struct LoginView: View {
    @ObservedObject var loginManager: LoginManager
    
    var body: some View {
        VStack {
            Text("请使用网易音乐 App 扫描二维码登录")
                .padding()
            
            ZStack {
                if let image = loginManager.qrCodeImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .opacity(loginManager.qrCodeStatus == .expired ? 0.5 : 1)
                } else {
                    Text("加载二维码中...")
                }
                
                if loginManager.qrCodeStatus == .expired {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("二码过")
                            .padding(.top)
                    }
                    .frame(width: 200, height: 200)
                    .background(Color.black.opacity(0.6))
                }
            }
            .frame(width: 200, height: 200)
            .onTapGesture {
                // 点击
                if loginManager.qrCodeStatus == .expired {
                    loginManager.startLoginProcess()
                }
            }
        }
        .onAppear {
            // 首次
            loginManager.startLoginProcess()
        }
    }
}

// 搜索栏
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            TextField("搜索音乐", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("搜索1") {
                
                // TODO: 实现搜索功能
            }
        }
        .padding()
    }
}

// 音乐项数据模型
struct MusicItem: Identifiable {
    let id: String
    let name: String
    let artist: String
    let matchStatus: String
}

// 音乐项行视图
struct MusicItemRow: View {
    let item: MusicItem
    
    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            Text(item.artist)
            Spacer()
            Text(item.matchStatus)
        }
    }
}

// 预览提供者
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CloudSongRow: View {
    let song: CloudSong
    let isEven: Bool
    let isSelected: Bool
    let coverWidth: CGFloat
    let nameWidth: CGFloat
    let artistWidth: CGFloat
    let addTimeWidth: CGFloat
    let fileSizeWidth: CGFloat
    let matchStatusWidth: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // 背景层
            Rectangle()
                .fill(backgroundColor)
            
            // 内容层
            HStack(spacing: 0) {
                // 封面图片
                AsyncImage(url: URL(string: song.picUrl)) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 16, height: 16)
                .cornerRadius(2)
                .frame(width: coverWidth, alignment: .center)
                
                Text(song.name)
                    .frame(width: nameWidth - 2 * columnPadding, alignment: .leading)
                    .lineLimit(1)
                    .padding(.horizontal, columnPadding)
                
                Text(song.artist)
                    .frame(width: artistWidth - 2 * columnPadding, alignment: .leading)
                    .lineLimit(1)
                    .padding(.horizontal, columnPadding)
                
                Text(formatDate(song.addTime))
                    .frame(width: addTimeWidth - 2 * columnPadding, alignment: .leading)
                    .lineLimit(1)
                    .padding(.horizontal, columnPadding)
            
                Text(formatFileSize(song.fileSize))
                    .frame(width: fileSizeWidth - 2 * columnPadding, alignment: .trailing)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, columnPadding)
            
                // 添加匹配状态列
                HStack {
                    switch song.matchStatus {
                    case .matched:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .failed(let errorMessage):
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    case .notMatched:
                        EmptyView()
                    }
                }
                .frame(width: matchStatusWidth - 2 * columnPadding, alignment: .leading)
                .padding(.horizontal, columnPadding)
            }
            .foregroundColor(textColor)
        }
        .frame(height: 30)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if colorScheme == .dark {
            return isEven ? Color(nsColor: .alternatingContentBackgroundColors[0]) : Color(nsColor: .alternatingContentBackgroundColors[1])
        } else {
            return isEven ? Color(nsColor: .alternatingContentBackgroundColors[0]) : Color(nsColor: .alternatingContentBackgroundColors[1])
        }
    }
    
    private var textColor: Color {
        Color(nsColor: .labelColor)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// 云盘歌曲表格视图
struct CloudSongTableView: View {
    // 绑定云盘歌曲数组
    @Binding var songs: [CloudSong]
    // 绑定选中的歌曲ID
    @Binding var selectedSongId: String?
    // 绑定搜索文本
    @Binding var searchText: String
    // 初始排序顺序，按上传时间倒序
    @State private var sortOrder = [KeyPathComparator(\CloudSong.addTime, order: .reverse)]

    var body: some View {
        // 创建表格视图
        Table(filteredSongs, selection: $selectedSongId, sortOrder: $sortOrder) {
            // 封面列
            TableColumn("封面", value: \.picUrl) { song in
                // 异步加载图片
                AsyncImage(url: URL(string: song.picUrl)) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    // 图片加载前显示灰色占位符
                    Color.gray
                }
                // 设置图片大小
                .frame(width: 16, height: 16)
                // 设置圆角
                .cornerRadius(2)
            }
            // 设置列宽度
            .width(min: 20, ideal: 30)

            // 歌曲名列
            TableColumn("歌曲名", value: \.name)
                // 设置列宽度
                .width(min: 80, ideal: 100)

            // 艺术家列
            TableColumn("艺术家", value: \.artist)
                // 设置列宽度
                .width(min: 50, ideal: 80)

            // 上传时间列
            TableColumn("上传时间", value: \.addTime) { song in
                // 格式化日期
                Text(formatDate(song.addTime))
            }
            // 设置列宽度
            .width(min: 80, ideal: 120)

            // 文件大小列
            TableColumn("文件大小", value: \.fileSize) { song in
                // 格式化文件大小
                Text(formatFileSize(song.fileSize))
            }
            // 设置列宽度
            .width(min: 60, ideal: 80)

            // 匹配状态列
            TableColumn("匹配状态", value: \.matchStatus) { song in
                switch song.matchStatus {
                case .matched:
                    // 匹配成功显示勾号
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .failed(let errorMessage):
                    // 匹配失败显示叉号
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    // 显示错误信息
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                case .notMatched:
                    // 未匹配不显示任何内容
                    EmptyView()
                }
            }
            // 设置列宽度
            .width(min: 60, ideal: 100)
        }
        // 监听排序顺序变化
        .onChange(of: sortOrder) { newValue in
            // 使用动画效果
            withAnimation {
                // 对歌曲数组进行排序
                songs.sort { lhs, rhs in
                    // 遍历所有比较器
                    for comparator in newValue {
                        switch comparator.compare(lhs, rhs) {
                        case .orderedAscending:
                            // 升序排列
                            return true
                        case .orderedDescending:
                            // 降序排列
                            return false
                        case .orderedSame:
                            // 相等时继续比较下一个条件
                            continue
                        }
                    }
                    // 所有条件都相等时保持原有顺序
                    return false
                }
            }
        }
    }

    // 过滤后的歌曲列表
    private var filteredSongs: [CloudSong] {
        if searchText.isEmpty {
            return songs
        } else {
            return songs.filter { song in
                song.name.localizedCaseInsensitiveContains(searchText) ||
                song.artist.localizedCaseInsensitiveContains(searchText) ||
                song.album.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // 格式化日期的辅助函数
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // 格式化文件大小的辅助函数
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

extension View {
    func onChangeSafe<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            return onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            return onChange(of: value, perform: action)
        }
    }
}


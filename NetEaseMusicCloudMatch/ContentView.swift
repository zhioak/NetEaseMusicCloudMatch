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
private let coverColumnMinWidth: CGFloat = 30  // 封面列最小宽度
private let nameColumnMinWidth: CGFloat = 200   // 歌曲名列最小宽度
private let artistColumnMinWidth: CGFloat = 150 // 艺术家列最小宽度
private let addTimeColumnMinWidth: CGFloat = 150 // 上传时间列最小宽度
private let statusColumnMinWidth: CGFloat = 100 // 状态列最小宽度
private let columnPadding: CGFloat = 8

// 主视图
struct ContentView: View {
    @StateObject private var loginManager = LoginManager.shared
    @State private var searchText = ""
    @State private var selectedMusicItemId: String?
    @State private var matchInputText = ""
    @State private var sortColumn: SortColumn = .addTime
    @State private var sortOrder: SortOrder = .descending
    @State private var isMatching = false
    @State private var matchResult: String?
    
    // 视图主体
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if !loginManager.isLoggedIn {
                    LoginView(loginManager: loginManager)
                } else {
                    // 主界面
                    VStack(alignment: .leading, spacing: 8) {  // 将 spacing 调整为 8
                        // 用户信息和搜索栏
                        HStack {
                            // 用户头像和用户名
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
                                Text(loginManager.username)
                                    .fontWeight(.medium)
                            }
                            
                            // 注销按钮
                            Button("注销") {
                                loginManager.logout()
                            }
                            .padding(.leading, 10)
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
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)  // 调整垂直方向的内边距
                        
                        // 音乐列表
                        VStack(spacing: 0) {
                            // 表头区域
                            HStack(spacing: 0) {
                                // 封面列
                                Text("封面")
                                    .font(.headline)
                                    .frame(width: columnWidth(for: coverColumnMinWidth, totalWidth: geometry.size.width), alignment: .center)
                                
                                Divider().frame(height: 20).background(Color.primary.opacity(0.2))
                                
                                // 歌曲名称列
                                SortableColumnHeader(title: SortColumn.name.rawValue, currentSort: $sortColumn, currentOrder: $sortOrder, column: .name, width: columnWidth(for: nameColumnMinWidth, totalWidth: geometry.size.width))
                                
                                Divider().frame(height: 20).background(Color.primary.opacity(0.2))
                                
                                // 艺术家列
                                SortableColumnHeader(title: SortColumn.artist.rawValue, currentSort: $sortColumn, currentOrder: $sortOrder, column: .artist, width: columnWidth(for: artistColumnMinWidth, totalWidth: geometry.size.width))
                                
                                Divider().frame(height: 20).background(Color.primary.opacity(0.2))
                                
                                // 添加时间列
                                SortableColumnHeader(title: SortColumn.addTime.rawValue, currentSort: $sortColumn, currentOrder: $sortOrder, column: .addTime, width: columnWidth(for: addTimeColumnMinWidth, totalWidth: geometry.size.width))
                                
                                Divider().frame(height: 20).background(Color.primary.opacity(0.2))
                                
                                // 状态列
                                Text("状态")
                                    .font(.headline)
                                    .frame(width: columnWidth(for: statusColumnMinWidth, totalWidth: geometry.size.width) - 2 * columnPadding, alignment: .leading)
                                    .padding(.horizontal, columnPadding)
                            }
                            .frame(height: 30)
                            .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow))

                            // 列表区域
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(Array(sortedSongs.enumerated()), id: \.element.id) { index, song in
                                        CloudSongRow(song: song, 
                                                     isEven: index % 2 == 0, 
                                                     isSelected: song.id == selectedMusicItemId,
                                                     coverWidth: columnWidth(for: coverColumnMinWidth, totalWidth: geometry.size.width),
                                                     nameWidth: columnWidth(for: nameColumnMinWidth, totalWidth: geometry.size.width),
                                                     artistWidth: columnWidth(for: artistColumnMinWidth, totalWidth: geometry.size.width),
                                                     addTimeWidth: columnWidth(for: addTimeColumnMinWidth, totalWidth: geometry.size.width),
                                                     statusWidth: columnWidth(for: statusColumnMinWidth, totalWidth: geometry.size.width))
                                            .onTapGesture {
                                                selectedMusicItemId = song.id
                                            }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: geometry.size.height * 0.5)  // 使用窗口高度的一半
                        
                        // 选中音乐项的详细信息
                        VStack(alignment: .leading, spacing: 10) {
                            if let selectedId = selectedMusicItemId,
                               let selectedItem = loginManager.cloudSongs.first(where: { $0.id == selectedId }) {
                                Text("已选中: \(selectedItem.name)")
                                
                                HStack {
                                    Text("歌曲ID:")
                                    Text(selectedItem.id)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    TextField("匹配歌曲ID", text: Binding(
                                        get: { self.matchInputText },
                                        set: { self.matchInputText = $0 }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("确认匹配") {
                                        performMatch()
                                    }
                                    .disabled(selectedMusicItemId == nil || matchInputText.isEmpty || isMatching)
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
                        
                        // 功能按钮
                        HStack {
                            Button("加载云盘音乐") {
                                print("开始加载云盘音乐")
                                loginManager.fetchCloudSongs()
                            }
                            Button("开始匹配") {
                                guard let selectedId = selectedMusicItemId, !matchInputText.isEmpty else {
                                    matchResult = "请选择一首歌曲并输匹ID"
                                    return
                                }
                                
                                isMatching = true
                                matchResult = nil
                                
                                loginManager.matchCloudSong(cloudSongId: selectedId, matchSongId: matchInputText) { success, message in
                                    DispatchQueue.main.async {
                                        isMatching = false
                                        matchResult = message
                                        if success {
                                            // 匹配成功后刷新云盘歌曲列表
                                            loginManager.fetchCloudSongs()
                                        }
                                    }
                                }
                            }
                            .disabled(selectedMusicItemId == nil || matchInputText.isEmpty || isMatching)
                        }
                        .padding()

                        Spacer() // 添加这行，将所有内容推到顶部
                    }
                }
            }
        }
        .frame(minWidth: 550, minHeight: 500)  // 设置最小宽度和高度
        .onAppear {
            if !loginManager.isLoggedIn {
                loginManager.startLoginProcess()
            } else {
                // 如果用户已登录，自动获取云盘歌曲
                loginManager.fetchCloudSongs()
            }
        }
    }
    
    private var sortedSongs: [CloudSong] {
        loginManager.cloudSongs.sorted { song1, song2 in
            let result: Bool
            switch sortColumn {
            case .name:
                result = song1.name.localizedStandardCompare(song2.name) == .orderedAscending
            case .artist:
                result = song1.artist.localizedStandardCompare(song2.artist) == .orderedAscending
            case .addTime:
                result = song1.addTime < song2.addTime
            }
            return sortOrder == .ascending ? result : !result
        }
    }
    
    private func performMatch() {
        guard let selectedId = selectedMusicItemId, !matchInputText.isEmpty else {
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
                    // 匹配成功后刷新云盘歌曲列表
                    loginManager.fetchCloudSongs()
                }
            }
        }
    }
    
    // 添加计算列宽的函数
    private func columnWidth(for minWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let totalMinWidth = coverColumnMinWidth + nameColumnMinWidth + artistColumnMinWidth + addTimeColumnMinWidth + statusColumnMinWidth
        let extraWidth = max(0, totalWidth - totalMinWidth)
        return minWidth + (minWidth / totalMinWidth) * extraWidth
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
            Button("搜索") {
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
    let statusWidth: CGFloat
    
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
            
                Text("未匹配")
                    .frame(width: statusWidth - 2 * columnPadding, alignment: .leading)
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

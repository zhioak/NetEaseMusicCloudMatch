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
        
        VStack(spacing: 0) {
            if !loginManager.isLoggedIn {
                LoginView(loginManager: loginManager)
            } else {
                // 主界面
                VStack(spacing: 10) {
                    // 用户信息和云盘容量
                    HStack {
                        if let avatar = loginManager.userAvatar {
                            Image(nsImage: avatar)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        }
                        Text("用户名: \(loginManager.username)")
                        Spacer()
                        Button("注销") {
                            loginManager.logout()
                        }
                    }
                    .padding(.horizontal)
                    
                    // 搜索栏
                    SearchBar(text: $searchText)
                    
                    // 音乐列表
                    VStack {
                        HStack {
                            SortableColumnHeader(title: SortColumn.name.rawValue, currentSort: $sortColumn, currentOrder: $sortOrder, column: .name)
                                .frame(width: 150, alignment: .leading)
                            SortableColumnHeader(title: SortColumn.artist.rawValue, currentSort: $sortColumn, currentOrder: $sortOrder, column: .artist)
                                .frame(width: 100, alignment: .leading)
                            SortableColumnHeader(title: SortColumn.addTime.rawValue, currentSort: $sortColumn, currentOrder: $sortOrder, column: .addTime)
                                .frame(width: 120, alignment: .leading)
                            Text("状态")
                                .font(.headline)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.2))
                        
                        List {
                            ForEach(Array(sortedSongs.enumerated()), id: \.element.id) { index, song in
                                CloudSongRow(song: song, isEven: index % 2 == 0, isSelected: song.id == selectedMusicItemId)
                                    .listRowInsets(EdgeInsets())
                                    .background(index % 2 == 0 ? Color(hex: "2A2A29") : Color(hex: "201F1E"))
                                    .onTapGesture {
                                        selectedMusicItemId = song.id
                                        // 移除这行，不再自动填充匹配关键词
                                        // matchInputText = "\(song.name) \(song.artist)"
                                    }
                            }
                        }
                        .onReceive(loginManager.$cloudSongs) { newValue in
                            print("云盘歌曲列表已更新，当前有 \(newValue.count) 首歌曲")
                        }
                    }
                    .frame(height: 250)
                    .listStyle(PlainListStyle())
                    
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
                            Text("请选择一首歌曲")
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
                        .disabled(selectedMusicItemId == nil || matchInputText.isEmpty || isMatching)
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 600)
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
}

struct SortableColumnHeader: View {
    let title: String
    @Binding var currentSort: SortColumn
    @Binding var currentOrder: SortOrder
    let column: SortColumn
    
    var body: some View {
        Button(action: {
            if currentSort == column {
                currentOrder = currentOrder == .ascending ? .descending : .ascending
            } else {
                currentSort = column
                currentOrder = .ascending
            }
        }) {
            HStack {
                Text(title)
                    .font(.headline)
                if currentSort == column {
                    Image(systemName: currentOrder == .ascending ? "arrow.up" : "arrow.down")
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 登录视图
struct LoginView: View {
    @ObservedObject var loginManager: LoginManager
    
    var body: some View {
        VStack {
            Text("请使用网易云音乐 App 扫描二维码登录")
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
                        Text("二维码已过")
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
    
    var body: some View {
        HStack {
            Text(song.name)
                .frame(width: 150, alignment: .leading)
                .lineLimit(1)
            Text(song.artist)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)
            Text(formatDate(song.addTime))
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
            Text("未匹配") // 这里可以根据实际情况显示匹配状态
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .cornerRadius(isSelected ? 4 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.blue, lineWidth: isSelected ? 2 : 0)
        )
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.2)
        } else {
            return isEven ? Color(hex: "2A2A29") : Color(hex: "201F1E")
        }
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

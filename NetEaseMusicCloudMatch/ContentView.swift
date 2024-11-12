import SwiftUI

// 排序列枚举 - 定义表格可排序的列
enum SortColumn: String {
    case name = "歌曲名"     // 按歌曲名排序
    case artist = "艺术家"   // 按艺术家排序
    case addTime = "上传时间" // 按上传时间排序
}

// 排序方向枚举 - 定义排序的方向
enum SortOrder {
    case ascending  // 升序
    case descending // 降序
}

// 设置列间距常量，用于保持UI布局的一致性
private let columnPadding: CGFloat = 8

// 日志记录结构体
struct MatchLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let isSuccess: Bool
}

// 主视图结构体
struct ContentView: View {
    // 状态管理
    @StateObject private var loginManager = LoginManager.shared  // 使用单例模式管理登录状态
    @State private var searchText = ""      // 搜索框的文本
    @State private var isMatching = false   // 是否正在进行匹配
    @State private var matchResult: String? // 匹配结果信息
    @State private var matchLogs: [MatchLogEntry] = []  // 新增日志数组
    
    var body: some View {
        // 使用GeometryReader来获取可用空间尺寸，实现响应式布局
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 根据登录状态显示不同的界面
                if !loginManager.isLoggedIn {
                    LoginView(loginManager: loginManager)  // 未登录显示登录视图
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
                        
                        // 音乐列表视图 - 使用双向绑定确保数据同步
                        CloudSongTableView(songs: Binding(
                            get: { self.loginManager.cloudSongs },
                            set: { self.loginManager.cloudSongs = $0 }
                        ), searchText: $searchText, performMatch: performMatch)
                            .frame(maxWidth: .infinity)
                            .frame(height: geometry.size.height * 0.65) // 将表格高度调整为窗口高度的65%
                        
                        // 终端风格的日志视图容器
                        VStack(spacing: 0) {
                            // 匹配状态指示器
                            if isMatching {
                                ProgressView()
                            }
                            
                            // 终端风格的日志视图
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(matchLogs) { log in
                                            HStack(spacing: 8) {
                                                // 时间戳
                                                Text(formatLogTime(log.timestamp))
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                
                                                // 状态图标
                                                Image(systemName: log.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                    .foregroundColor(log.isSuccess ? .green : .red)
                                                    .font(.system(size: 12))
                                                
                                                // 日志消息
                                                Text(log.message)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(log.isSuccess ? .primary : .red)
                                                
                                                Spacer()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .frame(maxWidth: .infinity)
                                            .background(log.id == matchLogs.last?.id ? Color.accentColor.opacity(0.1) : Color.clear)
                                            .cornerRadius(4)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: geometry.size.height * 0.35) // 调整为剩余高度
                                .background(Color.red)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        // 设置窗口最小尺寸，确保UI布局不会过于拥挤
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            // 视图出现时根据登录状态执行相应操作
            if loginManager.isLoggedIn {
                loginManager.fetchCloudSongs()
            } else {
                loginManager.startLoginProcess()
            }
        }
    }
    
    // 格式化日志时间
    private func formatLogTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 执行匹配操作的函数
    private func performMatch(cloudSongId: String, matchSongId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        // 验证输入
        guard !matchSongId.isEmpty else {
            let message = "请输入匹配ID"
            matchLogs.append(MatchLogEntry(timestamp: Date(), message: message, isSuccess: false))
            completion(false, message)
            return
        }
        
        // 获取当前歌曲名称
        let songName = loginManager.cloudSongs.first(where: { $0.id == cloudSongId })?.name ?? "未知歌曲"
        
        // 更新UI状态
        isMatching = true
        matchResult = nil
        
        // 调用匹配API
        loginManager.matchCloudSong(cloudSongId: cloudSongId, matchSongId: matchSongId) { success, message, updatedSong in
            DispatchQueue.main.async {
                isMatching = false
                let logMessage = "【\(songName)】 \(cloudSongId) → \(matchSongId) \(success ? "✅" : "❌️ \(message)")"
                matchLogs.append(MatchLogEntry(timestamp: Date(), message: logMessage, isSuccess: success))
                
                // 更新匹配结果显示
                if success, let song = updatedSong {
                    matchResult = "【\(songName)】 \(cloudSongId) → \(matchSongId) ✅"
                    // 更新歌曲信息
                    if let index = self.loginManager.cloudSongs.firstIndex(where: { $0.id == cloudSongId }) {
                        self.loginManager.cloudSongs[index] = song
                    }
                } else {
                    matchResult = "【\(songName)】 \(cloudSongId) → \(matchSongId) ❌️: \(message)" 
                }
                completion(success, message)
            }
        }
    }
}

// 可排序的列标题组件
struct SortableColumnHeader: View {
    let title: String                           // 列标题文本
    @Binding var currentSort: SortColumn        // 当前排序列
    @Binding var currentOrder: SortOrder        // 当前排序方向
    let column: SortColumn                      // 当前列类型
    let width: CGFloat                          // 列宽度
    
    var body: some View {
        // 点击切换排序方式的按钮
        Button(action: {
            // 如果点击当前排序列，则切换排序方向
            if currentSort == column {
                currentOrder = currentOrder == .ascending ? .descending : .ascending
            } else {
                // 如果点击其他列，则切换到该列并设置为升序
                currentSort = column
                currentOrder = .ascending
            }
        }) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                Spacer()
                // 显示排序方向指示器
                if currentSort == column {
                    Image(systemName: currentOrder == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .padding(.horizontal, columnPadding)
            .frame(width: width)
            .contentShape(Rectangle())  // 确保整个区域可点击
        }
        .buttonStyle(PlainButtonStyle())  // 使用朴素按钮样式
        .focusable(false)                 // 禁用焦点避免影响用户体验
    }
}

// 登录视图组件
struct LoginView: View {
    @ObservedObject var loginManager: LoginManager  // 登录管理器
    
    var body: some View {
        VStack {
            // 登录提示文本
            Text("请使用网易音乐 App 扫描二维码登录")
                .padding()
            
            // 二维码显示区域
            ZStack {
                // 显示二维码图片或加载提示
                if let image = loginManager.qrCodeImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        // 二维码过期时降低透明度
                        .opacity(loginManager.qrCodeStatus == .expired ? 0.5 : 1)
                } else {
                    Text("加载二维码中...")
                }
                
                // 二维码过期时显示的遮罩层
                if loginManager.qrCodeStatus == .expired {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("二维码过期")
                            .padding(.top)
                    }
                    .frame(width: 200, height: 200)
                    .background(Color.black.opacity(0.6))
                }
            }
            .frame(width: 200, height: 200)
            // 点击过期的二维码时重新获取
            .onTapGesture {
                if loginManager.qrCodeStatus == .expired {
                    loginManager.startLoginProcess()
                }
            }
        }
        // 视图出现时自动开始登录流程
        .onAppear {
            loginManager.startLoginProcess()
        }
    }
}

// 搜索栏组件
struct SearchBar: View {
    @Binding var text: String  // 搜索文本
    
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
    let id: String        // 唯一标识符
    let name: String      // 歌曲名称
    let artist: String    // 艺术家
    let matchStatus: String // 匹配状态
}

// 音乐项行视图组件
struct MusicItemRow: View {
    let item: MusicItem  // 音乐项数据
    
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

// 云盘歌曲行视图组件
struct CloudSongRow: View {
    let song: CloudSong           // 歌曲数据
    let isEven: Bool             // 是否为偶数行
    let isSelected: Bool         // 是否被选中
    let coverWidth: CGFloat      // 封面宽度
    let nameWidth: CGFloat       // 歌名列宽度
    let artistWidth: CGFloat     // 艺术家列宽度
    let addTimeWidth: CGFloat    // 添加时间列宽度
    let fileSizeWidth: CGFloat   // 文件大小列宽度
    let matchStatusWidth: CGFloat // 匹配状态列宽度
    
    @Environment(\.colorScheme) var colorScheme  // 当前颜色主题
    
    var body: some View {
        ZStack {
            // 背景层 - 根据行号显示交替背景色
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
                
                // 歌曲名称
                Text(song.name)
                    .frame(width: nameWidth - 2 * columnPadding, alignment: .leading)
                    .lineLimit(1)
                    .padding(.horizontal, columnPadding)
                
                // 艺术家名称
                Text(song.artist)
                    .frame(width: artistWidth - 2 * columnPadding, alignment: .leading)
                    .lineLimit(1)
                    .padding(.horizontal, columnPadding)
                
                // 添加时间
                Text(formatDate(song.addTime))
                    .frame(width: addTimeWidth - 2 * columnPadding, alignment: .leading)
                    .lineLimit(1)
                    .padding(.horizontal, columnPadding)
            
                // 文件大小
                Text(formatFileSize(song.fileSize))
                    .frame(width: fileSizeWidth - 2 * columnPadding, alignment: .trailing)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, columnPadding)
            
                // 匹配状态
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
        .frame(height: 30)  // 固定行高
    }
    
    // 计算背景颜色
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        }
        // 使用三元运算符简化重复代码
        return Color(nsColor: .alternatingContentBackgroundColors[isEven ? 0 : 1])
    }
    
    // 获取文本颜色
    private var textColor: Color {
        Color(nsColor: .labelColor)
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 格式化文件大小
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// View扩展 - 添加占位符功能
extension View {
    // 为任何View添加占位符的功能
    func placeholder<Content: View>(
        when shouldShow: Bool,        // 是否显示占位符
        alignment: Alignment = .leading, // 对齐方式
        @ViewBuilder placeholder: () -> Content) -> some View {  // 占位符内容构建器

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)  // 根据条件显示/隐藏占位符
            self
        }
    }
}

// 视觉效果视图 - 用于创建毛玻璃效果
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material     // 材质类型
    let blendingMode: NSVisualEffectView.BlendingMode  // 混合模式
    
    // 创建NSView
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    // 更新NSView
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// 云盘歌曲表格视图
struct CloudSongTableView: View {
    @Binding var songs: [CloudSong]           // 歌曲列表
    @Binding var searchText: String           // 搜索文本
    @State private var sortOrder = [KeyPathComparator(\CloudSong.addTime, order: .reverse)]  // 默认排序方式
    @State private var editingId: String?     // 当前正在编辑的歌曲ID
    @State private var tempEditId: String = "" // 临时存储编辑的ID
    @State private var selection: Set<String> = []  // 选中的歌曲ID集合
    let performMatch: (String, String, @escaping (Bool, String) -> Void) -> Void  // 修改这里的函数签名

    var body: some View {
        Table(filteredSongs, selection: $selection, sortOrder: $sortOrder) {
            // 序号列
            TableColumn("#", value: \.id) { song in
                Text(String(format: "%02d", filteredSongs.firstIndex(where: { $0.id == song.id })! + 1))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .width(20)

            // 可编辑的歌曲ID列
            TableColumn("歌曲ID", value: \.id) { song in
                ZStack {
                    if editingId == song.id {
                        EditableTextField(
                            text: $tempEditId,
                            song: song,
                            songs: $songs,
                            editingId: $editingId,
                            performMatch: performMatch,
                            onTab: selectNextRow,
                            onShiftTab: selectPreviousRow
                        )
                    } else {
                        Text(song.id)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .width(min: 50, ideal: 50)

            // 歌曲信息
            TableColumn("歌曲信息", value: \.name) { song in
                HStack(spacing: 10) {
                    // 封面图片
                    AsyncImage(url: URL(string: song.picUrl)) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 30, height: 30)
                    .cornerRadius(4)
                    
                    // 歌曲名和艺术家信息
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 140, ideal: 140)

            // 列
            TableColumn("专辑", value: \.album) { song in
                Text(song.album)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 100)

            // 上传时间列
            TableColumn("上传时间", value: \.addTime) { song in
                Text(formatDate(song.addTime))
            }
            .width(min: 80, ideal: 80)

            // 文件大小列
            TableColumn("文件大小", value: \.fileSize) { song in
                Text(formatFileSize(song.fileSize))
            }
            .width(min: 40, ideal: 40)

            // 时长列
            TableColumn("时长", value: \.duration) { song in
                Text(formatDuration(song.duration))
            }
            .width(min: 20, ideal: 20)
        }
        // 监听选择变化
        .onChange(of: selection) { newSelection in
            if let selectedId = newSelection.first {
                editingId = selectedId
                tempEditId = selectedId
            }
        }
        // 监听排序变化
        .onChange(of: sortOrder) { newValue in
            withAnimation {
                songs.sort { lhs, rhs in
                    for comparator in newValue {
                        switch comparator.compare(lhs, rhs) {
                        case .orderedAscending:
                            return true
                        case .orderedDescending:
                            return false
                        case .orderedSame:
                            continue
                        }
                    }
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

    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // 格式化文件大小
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    // 格式化时长
    private func formatDuration(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // 选择相邻行
    private func selectAdjacentRow(offset: Int) {
        if let currentId = editingId,
           let currentIndex = filteredSongs.firstIndex(where: { $0.id == currentId }),
           let newIndex = Optional(currentIndex + offset),
           newIndex >= 0 && newIndex < filteredSongs.count {
            let targetSong = filteredSongs[newIndex]
            editingId = targetSong.id
            tempEditId = targetSong.id
            selection = [targetSong.id]
        }
    }

    // 选择下一行
    private func selectNextRow() {
        selectAdjacentRow(offset: 1)
    }

    // 选择上一行
    private func selectPreviousRow() {
        selectAdjacentRow(offset: -1)
    }


}

// View扩展 - 用于安全处理onChange事件
extension View {
    // 处理不同版本的onChange事件
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

// 聚焦文本框组件 - 用于编辑歌曲ID
struct FocusedTextField: NSViewRepresentable {
    typealias NSViewType = NSTextField
    
    @Binding var text: String          // 绑定的文本值
    var onSubmit: () -> Void          // 提交回调
    var onTab: () -> Void            // Tab键回调
    var onShiftTab: () -> Void       // Shift+Tab回调
    
    // 创建NSTextField
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 12)
        
        // 自动聚焦和选中文本
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
            textField.selectText(nil)
        }
        
        return textField
    }
    
    // 更新NSTextField
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    // 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 协调器类 - 处理文本框的委托事件
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusedTextField
        
        init(_ parent: FocusedTextField) {
            self.parent = parent
        }
        
        // 处理文本变化
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        // 处理特殊盘事件
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                parent.onShiftTab()
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            return false
        }
    }
}

// 可编辑文本框组件
struct EditableTextField: View {
    @Binding var text: String                    
    let song: CloudSong                          
    @Binding var songs: [CloudSong]              
    @Binding var editingId: String?              
    let performMatch: (String, String, @escaping (Bool, String) -> Void) -> Void   // 修改这里的函数签名
    var onTab: () -> Void                       
    var onShiftTab: () -> Void                  
    
    var body: some View {
        FocusedTextField(text: $text, onSubmit: {
            performMatch(song.id, text) { success, _ in
                if success {
                    // 只在匹配成功时更新歌曲ID
                    if let index = songs.firstIndex(where: { $0.id == song.id }) {
                        songs[index].id = text
                    }
                }
                editingId = nil
            }
        }, onTab: onTab, onShiftTab: onShiftTab)
        .onAppear {
            text = song.id
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}




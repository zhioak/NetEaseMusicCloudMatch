import SwiftUI

struct LogView: View {
    let logs: [LogInfo]
    let onClear: () -> Void  // 添加清除回调
    
    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) { // 添加水平布局
                // 主日志内容
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(logs) { log in
                            LogInfoRow(
                                log: log,
                                isLatest: log.id == logs.last?.id
                            )
                            .id(log.id)
                        }
                        Color.clear
                            .frame(height: 0)
                            .id("bottom")
                    }
                    .frame(maxWidth: .infinity)
                    .onChange(of: logs.count) { _, _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .scrollIndicators(.visible)
                .padding(.bottom, 4)
                
                // 工具栏列
                VStack {
                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    
                    Spacer()
                }
                .frame(width: 30)
                .padding(.vertical, 4)
            }
        }
    }
}

// 更新 LogInfoRow
struct LogInfoRow: View {
    let log: LogInfo
    let isLatest: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 12))
                .frame(width: 16)
                   
            // 歌曲名 - 左对齐，固定宽度
            Text(log.songName)
                .foregroundColor(.blue)
                .font(.system(size: 12))
                .lineLimit(1)
            Text(log.songId)
                .font(.system(size: 12))
            if !log.matchSongId.isEmpty {    
                Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
                Text(log.matchSongId)
                    .font(.system(size: 12))
            }
            
            if !log.message.isEmpty {
                Text(":")
                    .font(.system(size: 12, weight: .bold))
                
                Text(log.message)
                    .font(.system(size: 12))
            }
            
            Spacer()
            
            // 添加固定宽度的时间戳列
            Text(formatTimestamp(log.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing) // 固定宽度
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.accentColor.opacity(isLatest ? 0.1 : 0))
        .cornerRadius(4)
    }
    
    // 格式化时间戳
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 添加状态图标计算属性
    private var statusIcon: String {
        switch log.status {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    // 添加状态颜色计算属性
    private var statusColor: Color {
        switch log.status {
        case .success:
            return .green
        case .error:
            return .red
        case .info:
            return .blue
        }
    }
}

// 更新预览
struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView(
            logs: [
                LogInfo(
                    songName: "测试歌曲",
                    songId: "123456",
                    matchSongId: "789012",
                    message: "",
                    status: .success
                ),
                LogInfo(
                    songName: "测试歌曲2",
                    songId: "345678",
                    matchSongId: "901234",
                    message: "匹配失败",
                    status: .error
                )
            ],
            onClear: {}  // 添加空的清除回调
        )
        .frame(height: 200)
    }
} 

import SwiftUI

struct LogView: View {
    let logs: [LogInfo]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logs) { log in
                        LogInfoRow(
                            log: log,
                            isLatest: log.id == logs.last?.id
                        )
                        .id(log.id)
                    }
                    // 添加一个空视图作为滚动锚点
                    Color.clear
                        .frame(height: 0)
                        .id("bottom")
                }
                .frame(maxWidth: .infinity)
                .onChange(of: logs.count) { _, _ in
                    // 使用 bottom 锚点进行滚动，并调整延迟时间
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
            
            // 添加时间戳显示
            Text(formatTimestamp(log.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
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
        LogView(logs: [
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
        ])
        .frame(height: 200)
    }
} 

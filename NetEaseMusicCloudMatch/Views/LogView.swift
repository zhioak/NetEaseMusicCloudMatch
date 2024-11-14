import SwiftUI

// 重命名为 LogEntry
struct LogEntry: Identifiable {
    let id = UUID()
    let songName: String      // 歌曲名
    let cloudSongId: String   // 云盘歌曲ID
    let matchSongId: String   // 匹配目标ID
    let message: String       // 其他信息
    let isSuccess: Bool
}

struct LogView: View {
    let logs: [LogEntry]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logs) { log in
                        LogEntryRow(
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

// 更新 LogEntryRow
struct LogEntryRow: View {
    let log: LogEntry
    let isLatest: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: log.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(log.isSuccess ? .green : .red)
                .font(.system(size: 12))
                .frame(width: 16)
                   
            // 歌曲名 - 左对齐，固定宽度
            Text(log.songName)
                .foregroundColor(.blue)
                .font(.system(size: 12))
                .lineLimit(1)
            Text(log.cloudSongId)
                .font(.system(size: 12))
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
            Text(log.matchSongId)
                .font(.system(size: 12))
            if !log.message.isEmpty {
                Text(":")
                    .font(.system(size: 12, weight: .bold))
                
                Text(log.message)
                    .font(.system(size: 12))
            }
        
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.accentColor.opacity(isLatest ? 0.1 : 0))
        .cornerRadius(4)
    }
}

// 更新预览
struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView(logs: [
            LogEntry(
                songName: "测试歌曲",
                cloudSongId: "123456",
                matchSongId: "789012",
                message: "",
                isSuccess: true
            ),
            LogEntry(
                songName: "测试歌曲2",
                cloudSongId: "345678",
                matchSongId: "901234",
                message: "匹配失败",
                isSuccess: false
            )
        ])
        .frame(height: 200)
    }
} 

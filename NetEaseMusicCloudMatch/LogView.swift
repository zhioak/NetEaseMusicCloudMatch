import SwiftUI

struct LogView: View {
    let logs: [MatchLogEntry]
    
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
                        .frame(height: 1)
                        .id("bottom")
                }
                .frame(maxWidth: .infinity)
                .onChange(of: logs.count) { _ in
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
            .background(Color(nsColor: .windowBackgroundColor))
            .scrollIndicators(.visible)
            .padding(.bottom, 4)
        }
    }
}

// 日志条目行视图
struct LogEntryRow: View {
    let log: MatchLogEntry
    let isLatest: Bool
    
    var body: some View {
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
        .background(Color.accentColor.opacity(isLatest ? 0.1 : 0))
        .cornerRadius(4)
    }
    
    // 格式化日志时间
    private func formatLogTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// 日志条目预览
struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView(logs: [
            MatchLogEntry(timestamp: Date(), message: "测试成功日志", isSuccess: true),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false),
            MatchLogEntry(timestamp: Date(), message: "测试失败日志", isSuccess: false)
        ])
        .frame(height: 200)
    }
} 

import SwiftUI

struct HeaderView: View {
    @ObservedObject var loginManager: LoginManager
    @Binding var searchText: String
    @StateObject private var songManager = CloudSongManager.shared
    
    var body: some View {
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
    }
}

#Preview {
    HeaderView(
        loginManager: LoginManager.shared,
        searchText: .constant("")
    )
} 
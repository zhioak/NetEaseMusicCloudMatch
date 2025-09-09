import SwiftUI

struct LoginView: View {
    @ObservedObject var loginManager: LoginManager  // 登录管理器
    @State private var cookieText: String = ""  // Cookie输入框的文本
    @State private var isLoggingIn: Bool = false  // 是否正在登录
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Cookie输入框
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $cookieText)
                    .frame(minHeight: 120, maxHeight: 200)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal)
            
            // 登录按钮
            Button(action: {
                loginWithCookie()
            }) {
                HStack {
                    if isLoggingIn {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isLoggingIn ? "登录中..." : "登录")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(cookieText.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(cookieText.isEmpty || isLoggingIn)
            .padding(.horizontal)
            
            // 状态提示
            if case .failed(let error) = loginManager.qrCodeStatus {
                Text("登录失败: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            } else if case .success = loginManager.qrCodeStatus {
                Text("登录成功!")
                    .foregroundColor(.green)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: 500)
        .padding()
    }
    
    private func loginWithCookie() {
        guard !cookieText.isEmpty else { return }
        
        isLoggingIn = true
        Task {
            await loginManager.loginWithCookie(cookieText)
            await MainActor.run {
                isLoggingIn = false
            }
        }
    }
}

// 预览提供者
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(loginManager: LoginManager.shared)
    }
} 
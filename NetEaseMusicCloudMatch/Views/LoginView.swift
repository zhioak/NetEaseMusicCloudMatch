import SwiftUI

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
                    Text("二维码已过期")
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

// 预览提供者
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(loginManager: LoginManager.shared)
    }
} 
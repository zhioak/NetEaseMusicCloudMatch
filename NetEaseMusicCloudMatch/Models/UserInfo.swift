import AppKit

struct UserInfo: Codable {
    let username: String
    let userId: String
    var avatarURL: URL?
    let token: String
    let loginTime: Date
    
    var avatar: NSImage?
    
    enum CodingKeys: String, CodingKey {
        case username
        case userId
        case avatarURL
        case token
        case loginTime
    }
} 
import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    // 添加调试开关
    static var isDebugMode = false
    
    private init() {}
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    enum NetworkError: Error {
        case invalidURL
        case noData
        case decodingError
        case serverError(Int)
        case unauthorized
        case unknown(String)
    }
    
    // 通用的网络请求方法
    func request(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        completion: @escaping (Result<([String: Any], HTTPURLResponse), NetworkError>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // 设置默认 headers
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 添加自定义 headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 处理请求参数
        if let parameters = parameters {
            switch method {
            case .get:
                // GET 请求参数添加到 URL
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = parameters.map { 
                    URLQueryItem(name: "\($0)", value: "\($1)")
                }
                request.url = components.url
            case .post, .put:
                // POST/PUT 请求参数放在 body 中
                let paramString = parameters.map { key, value in
                    let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    return "\(escapedKey)=\(escapedValue)"
                }.joined(separator: "&")
                request.httpBody = paramString.data(using: .utf8)
            default:
                break
            }
        }
        
        // 修改打印逻辑，增加调试开关判断
        if NetworkManager.isDebugMode {
            print("Request URL: \(request.url?.absoluteString ?? "")")
            print("Request Method: \(request.httpMethod ?? "")")
            print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
            if let body = request.httpBody {
                print("Request Body: \(String(data: body, encoding: .utf8) ?? "")")
            }
        }
        
        // 发起网络请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 错误处理
            if let error = error {
                completion(.failure(.unknown(error.localizedDescription)))
                return
            }
            
            // 修改响应信息打印，增加调试开关判断
            if NetworkManager.isDebugMode {
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response Status Code: \(httpResponse.statusCode)")
                    print("Response Headers: \(httpResponse.allHeaderFields)")
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown("Invalid response")))
                return
            }
            
            // 处理HTTP状态码
            switch httpResponse.statusCode {
            case 200...299:
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if NetworkManager.isDebugMode {
                            print("Response Data: \(json)")
                        }
                        completion(.success((json, httpResponse)))
                    } else {
                        completion(.failure(.decodingError))
                    }
                } catch {
                    if NetworkManager.isDebugMode {
                        print("JSON Parsing Error: \(error)")
                    }
                    completion(.failure(.decodingError))
                }
            case 401:
                completion(.failure(.unauthorized))
            default:
                completion(.failure(.serverError(httpResponse.statusCode)))
            }
        }.resume()
    }
    
    // GET 请求便捷方法
    func get(
        endpoint: String,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        completion: @escaping (Result<([String: Any], HTTPURLResponse), NetworkError>) -> Void
    ) {
        request(
            endpoint: endpoint,
            method: .get,
            parameters: parameters,
            headers: headers,
            completion: completion
        )
    }
    
    // POST 请求便捷方法
    func post(
        endpoint: String,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        completion: @escaping (Result<([String: Any], HTTPURLResponse), NetworkError>) -> Void
    ) {
        request(
            endpoint: endpoint,
            method: .post,
            parameters: parameters,
            headers: headers,
            completion: completion
        )
    }
    
    // 下载图片的方法
    func downloadImage(from url: URL, completion: @escaping (Result<Data, NetworkError>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.unknown(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            completion(.success(data))
        }.resume()
    }
} 
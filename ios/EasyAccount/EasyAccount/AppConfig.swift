import Foundation

enum AppConfig {
    /// 与 Web 端 `.env.development` 默认一致；可在登录页「连接设置」覆盖。
    static let defaultWsURL = "ws://127.0.0.1:8088"
    static let defaultHttpURL = "http://127.0.0.1:8088"
}

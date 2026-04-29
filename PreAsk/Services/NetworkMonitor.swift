import Foundation
import Combine
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected = false
    @Published var apiReachable = false
    @Published var isCheckingConnection = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.checkAPIReachability()
            }
        }
        monitor.start(queue: queue)
    }

    private func checkAPIReachability() {
        guard let url = URL(string: "https://ark.cn-beijing.volces.com") else {
            self.apiReachable = false
            self.isCheckingConnection = false
            return
        }

        let request = URLRequest(url: url, timeoutInterval: 3.0)
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.apiReachable = true
                } else {
                    self?.apiReachable = error == nil && self?.isConnected == true
                }
                self?.isCheckingConnection = false
            }
        }
        task.resume()
    }
}

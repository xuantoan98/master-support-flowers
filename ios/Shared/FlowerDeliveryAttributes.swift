import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct FlowerDeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let deliveryAt: Date
        let isFinished: Bool
    }

    let orderId: Int
}

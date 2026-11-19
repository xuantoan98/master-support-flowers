import ActivityKit
import Flutter
import Foundation

final class FlowerLiveActivityCoordinator {
    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            if call.method == "isAvailable" {
                result(false)
            } else if call.method == "sync" {
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
            return
        }

        switch call.method {
        case "isAvailable":
            result(ActivityAuthorizationInfo().areActivitiesEnabled)
        case "sync":
            guard let arguments = call.arguments as? [String: Any],
                  let rows = arguments["deliveries"] as? [[String: Any]] else {
                result(FlutterError(code: "invalid_data", message: "Invalid delivery list", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    try await sync(rows)
                    result(nil)
                } catch {
                    result(FlutterError(code: "activity_failed", message: error.localizedDescription, details: nil))
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.2, *)
    @MainActor
    private static func sync(_ rows: [[String: Any]]) async throws {
        var desired: [Int: Date] = [:]
        for row in rows {
            guard let orderId = row["orderId"] as? Int,
                  let milliseconds = row["deliveryAtEpochMillis"] as? NSNumber,
                  orderId > 0 else {
                throw LiveActivityError.invalidDelivery
            }
            desired[orderId] = Date(timeIntervalSince1970: milliseconds.doubleValue / 1000)
        }

        let existing = Activity<FlowerDeliveryAttributes>.activities
        for activity in existing {
            let orderId = activity.attributes.orderId
            guard let deliveryAt = desired.removeValue(forKey: orderId) else {
                let finished = FlowerDeliveryAttributes.ContentState(
                    deliveryAt: activity.content.state.deliveryAt,
                    isFinished: true
                )
                await activity.end(ActivityContent(state: finished, staleDate: nil), dismissalPolicy: .immediate)
                continue
            }
            let state = FlowerDeliveryAttributes.ContentState(deliveryAt: deliveryAt, isFinished: false)
            let staleDate = max(deliveryAt.addingTimeInterval(4 * 60 * 60), Date().addingTimeInterval(60 * 60))
            await activity.update(ActivityContent(state: state, staleDate: staleDate))
        }

        if !desired.isEmpty && !ActivityAuthorizationInfo().areActivitiesEnabled {
            throw LiveActivityError.notAuthorized
        }
        for (orderId, deliveryAt) in desired {
            let attributes = FlowerDeliveryAttributes(orderId: orderId)
            let state = FlowerDeliveryAttributes.ContentState(deliveryAt: deliveryAt, isFinished: false)
            let staleDate = max(deliveryAt.addingTimeInterval(4 * 60 * 60), Date().addingTimeInterval(60 * 60))
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleDate),
                pushType: nil
            )
        }
    }
}

private enum LiveActivityError: LocalizedError {
    case invalidDelivery
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .invalidDelivery: return "Thông tin đơn giao không hợp lệ"
        case .notAuthorized: return "Live Activity chưa được cho phép"
        }
    }
}

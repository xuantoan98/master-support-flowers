import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FlowerLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FlowerDeliveryWidget()
    }
}

struct FlowerDeliveryWidget: Widget {
    private let navy = Color(red: 0.14, green: 0.23, blue: 0.34)
    private let paleBlue = Color(red: 0.88, green: 0.94, blue: 0.98)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowerDeliveryAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "shippingbox.fill")
                    .font(.title2)
                    .foregroundColor(navy)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Đơn #\(context.attributes.orderId)")
                        .font(.headline)
                    Text(context.state.isFinished ? "Đã kết thúc" : (context.isStale ? "Cần kiểm tra" : "Đang giao"))
                        .font(.subheadline)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Giờ giao")
                        .font(.caption)
                    Text(context.state.deliveryAt, style: .time)
                        .font(.headline)
                }
            }
            .padding(16)
            .activityBackgroundTint(paleBlue)
            .activitySystemActionForegroundColor(navy)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Đơn #\(context.attributes.orderId)", systemImage: "shippingbox.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.deliveryAt, style: .time)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isFinished ? "Đã kết thúc" : (context.isStale ? "Cần kiểm tra · Sổ Hoa" : "Đang giao · Sổ Hoa"))
                        .font(.subheadline)
                }
            } compactLeading: {
                Image(systemName: "shippingbox.fill")
            } compactTrailing: {
                Text(context.state.deliveryAt, style: .time)
            } minimal: {
                Image(systemName: "shippingbox.fill")
            }
        }
    }
}

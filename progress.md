# Tiến độ xây dựng app quản lý đơn hoa

Cập nhật lần đầu: 16/11/2026. Tài liệu kế hoạch: [plan.md](plan.md). Trạng thái phản ánh những gì đã kiểm tra trong repo, không phải dự báo.

## Tổng quan

| Phase | Trạng thái | Bằng chứng / bước tiếp theo |
| --- | --- | --- |
| 0. Chốt phạm vi và nền dự án | Đang chuẩn bị | Đã đọc PDF 17 trang và rà codebase. Cần map màn chi tiết, chốt brand/iOS/Android/định nghĩa doanh thu, kiểm tra build offline và xử lý credential dependency. |
| 1. Dữ liệu, điều hướng, UI shell | Chưa bắt đầu | Chưa có DB/model đơn/khách/sản phẩm; Home còn placeholder. |
| 2. Tạo đơn và khách hàng | Chưa bắt đầu | Chưa có flow 4 bước, màn khách hàng hoặc nhập nhanh bằng OCR/nhận diện ảnh mẫu. |
| 3. Vận hành đơn, lịch, media | Chưa bắt đầu | Chưa có trạng thái đơn/lịch/ảnh nghiệp vụ. |
| 4. Hóa đơn, chia sẻ, VietQR | Chưa bắt đầu | `share_plus` có sẵn nhưng chưa có hóa đơn/QR. |
| 5. Nhắc việc, danh sách mua hoa | Chưa bắt đầu | Có Firebase Messaging cơ bản; chưa có local scheduling hoặc tổng hợp hoa. |
| 6. Widget, Live Activity iOS | Chưa bắt đầu | Chưa thấy WidgetKit/ActivityKit extension. |
| 7. Thống kê, hoàn thiện UX | Chưa bắt đầu | Chưa có thống kê nghiệp vụ. |
| 8. QA và phát hành v1 | Chưa bắt đầu | Chưa có `test/` hoặc `integration_test/`; chưa xác nhận build release. |
| 9. Flowie Pro sau release | Chưa bắt đầu | Có IAP wrapper trong boilerplate nhưng chưa có quyền lợi Pro; chờ v1 phát hành. |

## Đã kiểm tra

- PDF mô tả luồng tạo đơn 4 bước, lịch/danh sách/chi tiết đơn, trạng thái, ảnh, hóa đơn + VietQR, nhắc việc, widget/Live Activity, danh sách mua hoa, thống kê; trang 8 ghi màn thông tin khách chưa có trong bộ screenshot. Phase Pro được tài liệu đặt sau release.
- Repo là Flutter boilerplate; có `auto_route`, `flutter_bloc`, `get_it`/`injectable`, theme/l10n, splash/onboarding/settings, Firebase/ads/Adjust/IAP. `lib/src/presentation/home/home_screen.dart` hiện chỉ hiển thị Home và một quảng cáo.
- `SharedPreferencesManager` hiện chỉ lưu vài thiết lập; chưa có DB quan hệ/cục bộ cho nghiệp vụ. `NotificationService` dùng Firebase Messaging, không giải quyết nhắc đơn offline.
- Chưa chạy build/test ở lượt lập kế hoạch; các gate kỹ thuật vẫn mở. Worktree ban đầu sạch trước khi tạo hai file này.

## Quyết định cần chốt ở Phase 0

1. Tên/nhận diện app riêng và mức độ mô phỏng giao diện screenshot.
2. iOS là bản phát hành đầu; xác nhận Android đồng thời hay để sau.
3. Doanh thu tính theo ngày giao, ngày tạo hay ngày nhận tiền; quy tắc đơn hủy/hoàn tiền.
4. Nguồn triển khai VietQR và dữ liệu tài khoản ngân hàng; cách kiểm chứng QR.
5. Có cần backup/restore cục bộ trong v1 khi chưa có iCloud hay không.
6. Mức chi tiết được phép hiện trên widget/màn khóa.

## Nhật ký

| Ngày | Thay đổi | Kiểm chứng |
| --- | --- | --- |
| 16/11/2026 | Lập `plan.md` và `progress.md` dựa trên PDF và hiện trạng code. | Đọc nội dung PDF, xem các trang ảnh minh họa, rà cấu trúc và các file khởi tạo/chính của Flutter. |

## Quy tắc cập nhật

Khi bắt đầu một phase: đổi trạng thái thành `Đang làm`, ghi phạm vi đang xử lý. Khi hoàn thành: ghi commit/PR hoặc đường dẫn file chính, kết quả test và thiết bị đã kiểm tra, rồi mới đổi `Hoàn thành`. Nếu đổi phạm vi, cập nhật `plan.md` trước và ghi lý do trong nhật ký này.

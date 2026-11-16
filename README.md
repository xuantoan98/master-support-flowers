# Tiệm Hoa

Ứng dụng quản lý đơn hoa offline cho cửa hàng nhỏ. Đây là lát cắt đầu của kế hoạch trong [plan.md](plan.md); trạng thái từng phase ở [progress.md](progress.md).

## Chạy dự án

Yêu cầu Flutter SDK tương thích Dart >= 3.10 và Android SDK hoặc Xcode trên macOS.

```sh
flutter pub get
flutter analyze
flutter test
flutter run --flavor dev
flutter build apk --debug --flavor dev
```

`lib/main.dart` khởi động trực tiếp vào app offline. Màn chính có lịch tháng, danh sách đơn với tìm kiếm/lọc trạng thái/ngày giao, thống kê cơ bản và màn cá nhân. Nút **Tạo đơn** mở form 4 bước; ngày trên lịch được truyền vào form, bản nháp được lưu và khôi phục khi quay lại. Một đơn có thể chứa nhiều mẫu hoa và số lượng riêng. Màn **Mẫu hoa** có sẵn 10 mẫu với giá, định lượng và thumbnail; người dùng có thể chọn ảnh từ thư viện, hoặc để trống để app gán ngẫu nhiên một trong 6 ảnh hoa mặc định. Màn **Danh sách mua hoa** cộng định lượng của các đơn sắp giao theo hôm nay/ngày mai/7 ngày và lưu dấu đã mua. Đơn và khách được lưu trong SQLite trên thiết bị. Màn chi tiết cho phép sửa đơn, thêm/xóa ảnh, thu thêm/hoàn tiền và đổi trạng thái theo chuỗi; tiền đã thu khi sửa đơn được giữ theo lịch sử thanh toán.

Giao diện dùng bảng màu xanh cẩm tú cầu pastel và cặp font Playfair Display (tiêu đề), Be Vietnam Pro (nội dung) theo [hệ thống màu và kiểu chữ](he-thong-mau-sac-va-font-app-ban-hoa.md). Hai font được đóng gói trong app theo [giấy phép OFL](third_party/google_fonts/). Thẻ ảnh và bố cục tham chiếu từ nhánh hotel booking của `Best-Flutter-UI-Templates.zip` theo [giấy phép MIT](third_party/Best-Flutter-UI-Templates-LICENSE); logic và các màn nghiệp vụ vẫn là mã riêng của Tiệm Hoa.

## Cấu trúc đang dùng

- `lib/flower/domain`: model, trạng thái và quy tắc tiền đơn.
- `lib/flower/data`: SQLite schema v10, migration, repository và lưu ảnh vào thư mục app.
- `lib/flower/presentation`: giao diện và luồng tạo/xem đơn.
- `test`: test nghiệp vụ và lưu lại dữ liệu sau khi mở lại DB.

Boilerplate trước đây vẫn nằm trong `lib/src` và `lib/module` để tham khảo khi di chuyển chức năng. Chúng không còn nằm trong luồng chạy hoặc phân tích tĩnh của app mới. Các chức năng OCR, hóa đơn, nhắc việc, widget và Pro chưa được triển khai.

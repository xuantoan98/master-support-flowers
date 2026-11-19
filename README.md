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

`lib/main.dart` khởi động trực tiếp vào app offline. Màn chính có lịch tháng, danh sách đơn với tìm kiếm/lọc trạng thái/ngày giao, thống kê tuần/tháng/quý/năm và màn cá nhân. Nút **Tạo đơn** mở form 4 bước; ngày trên lịch được truyền vào form, bản nháp được lưu và khôi phục khi quay lại. Một đơn có thể chứa nhiều mẫu hoa và số lượng riêng. Màn **Mẫu hoa** có sẵn 10 mẫu với giá, định lượng và thumbnail; người dùng có thể chọn ảnh từ thư viện, hoặc để trống để app gán ngẫu nhiên một trong 6 ảnh hoa mặc định. Màn **Danh sách mua hoa** cộng định lượng của các đơn sắp giao theo hôm nay/ngày mai/7 ngày và lưu dấu đã mua. Đơn và khách được lưu trong SQLite trên thiết bị. Màn chi tiết cho phép sửa đơn, thêm/xóa ảnh, thu thêm/hoàn tiền và đổi trạng thái theo chuỗi; tiền đã thu khi sửa đơn được giữ theo lịch sử thanh toán. Từ màn chi tiết có thể xem và chia sẻ ảnh hóa đơn. Hồ sơ shop và ảnh QR ngân hàng do chủ shop chọn được lưu trên máy; app không tự tạo QR hay gán số tiền vào ảnh QR. Trong tab **Cá nhân**, chủ shop có thể bật nhắc việc sau khi cấp quyền: 1 giờ trước giao, 15 phút sau giờ giao nếu chưa hoàn tất, và 24 giờ sau giao nếu còn tiền chưa thu. App tính lại nhắc việc khi mở lại hoặc thay đổi đơn.

Thống kê tách **doanh thu đã giao** (tổng giá trị đơn hoàn tất theo ngày giao) khỏi **tiền thu ròng** (tiền nhận trừ tiền hoàn theo ngày giao dịch). Giá trị đơn và công nợ theo ngày giao của các đơn chưa hủy; sản phẩm bán chạy dựa trên số lượng trong đơn đã giao. Tiền thu và hoàn của đơn hủy vẫn hiện trong dòng tiền của kỳ để có thể đối soát.

Giao diện dùng bảng màu xanh cẩm tú cầu pastel và cặp font Nunito (tiêu đề), Be Vietnam Pro (nội dung) theo [hệ thống màu và kiểu chữ](he-thong-mau-sac-va-font-app-ban-hoa.md). Hai font được đóng gói trong app theo [giấy phép OFL](third_party/google_fonts/). Thẻ ảnh và bố cục tham chiếu từ nhánh hotel booking của `Best-Flutter-UI-Templates.zip` theo [giấy phép MIT](third_party/Best-Flutter-UI-Templates-LICENSE); logic và các màn nghiệp vụ vẫn là mã riêng của Tiệm Hoa.

Trên iPhone từ iOS 16.2, tab **Cá nhân** có công tắc Live Activity. Khi bật, tối đa ba đơn ở trạng thái **Đang giao** gần giờ giao nhất xuất hiện trên màn hình khóa và Dynamic Island (nếu máy hỗ trợ). App cập nhật giờ giao, kết thúc thẻ khi đơn đã giao/hủy hoặc khi tắt công tắc. Thẻ chỉ mang mã đơn và giờ giao; phần này cần build/kiểm thử bằng Xcode trên macOS trước phát hành.

## Cấu trúc đang dùng

- `lib/flower/domain`: model, trạng thái và quy tắc tiền đơn.
- `lib/flower/data`: SQLite schema v13, migration, repository, lưu ảnh và đặt lịch nhắc cục bộ.
- `lib/flower/presentation`: giao diện và luồng tạo/xem đơn.
- `test`: test nghiệp vụ và lưu lại dữ liệu sau khi mở lại DB.

Boilerplate trước đây vẫn nằm trong `lib/src` và `lib/module` để tham khảo khi di chuyển chức năng. Chúng không còn nằm trong luồng chạy hoặc phân tích tĩnh của app mới. Các chức năng OCR, widget tĩnh và Pro chưa được triển khai. iOS và việc nhận thông báo sau khởi động lại/đổi múi giờ còn cần kiểm tra trên thiết bị thật.

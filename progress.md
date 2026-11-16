# Tiến độ xây dựng app quản lý đơn hoa

Cập nhật lần đầu: 16/11/2026. Tài liệu kế hoạch: [plan.md](plan.md). Trạng thái phản ánh những gì đã kiểm tra trong repo, không phải dự báo.

## Tổng quan

| Phase | Trạng thái | Bằng chứng / bước tiếp theo |
| --- | --- | --- |
| 0. Chốt phạm vi và nền dự án | Đang làm | App offline chạy trên Redmi K30 5G (Android 10), tên tạm “Tiệm Hoa”; đã bỏ dependency chứa credential khỏi `pubspec.yaml` và gỡ Firebase/ads khỏi luồng native đang build. Còn quyết định sản phẩm và gate iOS simulator. |
| 1. Dữ liệu, điều hướng, UI shell | Đang làm | SQLite v10 cho đơn, khách, catalog với ảnh và 10 mẫu, ảnh đơn, dấu đã mua, payment ledger, bản nháp, lịch sử trạng thái và nhiều dòng sản phẩm; test migration v1/v2/v3/v6/v9. Shell 4 tab chạy trên Android thật. Còn backup, kiểm chứng iOS và kiểm thử nhánh lỗi khởi động trên thiết bị. |
| 2. Tạo đơn và khách hàng | Đang làm | Form 4 bước, khách vãng lai, gợi ý khách cũ, danh sách/chi tiết khách, khôi phục/xóa draft, nhiều mẫu và số lượng theo dòng, catalog hoa chính/phụ và bản chụp vào đơn. Chọn giờ giao bằng bánh xe cuộn, chỉ nhận thời điểm tương lai; tiền nhập được nhóm chữ số theo locale. Đã thử UI trên Redmi. Còn OCR/nhận diện ảnh và gate toàn luồng. |
| 3. Vận hành đơn, lịch, media | Hoàn thành trên Android | Đã kiểm chứng lịch qua tháng/năm, tìm kiếm/lọc, dashboard đối soát đơn hủy và ledger, chi tiết/sửa đơn, trạng thái, thu/hoàn, lịch sử chỉnh sửa, ảnh thư viện/camera lưu sau mở lại rồi xóa trên Redmi K30 5G. iOS cần kiểm chứng ở Phase 8; đổi giờ giao và nhắc cũ sẽ kiểm tra sau khi Phase 5 thêm notification. |
| 4. Hóa đơn, chia sẻ, VietQR | Chưa bắt đầu | Chưa có hóa đơn, QR hoặc luồng chia sẻ trong app đang chạy. |
| 5. Nhắc việc, danh sách mua hoa | Đang làm | Danh sách hôm nay/ngày mai/7 ngày cộng định lượng và lưu dấu đã mua, cảnh báo đơn thiếu định lượng; đã kiểm tra trên Android thật. Còn local notifications và kiểm thử đổi múi giờ/khởi động lại. |
| 6. Widget, Live Activity iOS | Chưa bắt đầu | Chưa thấy WidgetKit/ActivityKit extension. |
| 7. Thống kê, hoàn thiện UX | Chưa bắt đầu | Chưa có thống kê nghiệp vụ. |
| 8. QA và phát hành v1 | Chưa bắt đầu | Có 36 test và build Android debug; chưa có integration test iOS, release build, TestFlight hoặc QA phát hành. |
| 9. Flowie Pro sau release | Chưa bắt đầu | Có IAP wrapper trong boilerplate nhưng chưa có quyền lợi Pro; chờ v1 phát hành. |

## Đã kiểm tra

- PDF mô tả luồng tạo đơn 4 bước, lịch/danh sách/chi tiết đơn, trạng thái, ảnh, hóa đơn + VietQR, nhắc việc, widget/Live Activity, danh sách mua hoa, thống kê; trang 8 ghi màn thông tin khách chưa có trong bộ screenshot. Phase Pro được tài liệu đặt sau release.
- Repo là Flutter boilerplate; có `auto_route`, `flutter_bloc`, `get_it`/`injectable`, theme/l10n, splash/onboarding/settings, Firebase/ads/Adjust/IAP. `lib/src/presentation/home/home_screen.dart` hiện chỉ hiển thị Home và một quảng cáo.
- `SharedPreferencesManager` hiện chỉ lưu vài thiết lập; chưa có DB quan hệ/cục bộ cho nghiệp vụ. `NotificationService` dùng Firebase Messaging, không giải quyết nhắc đơn offline.
- Chưa chạy build/test ở lượt lập kế hoạch; các gate kỹ thuật vẫn mở. Worktree ban đầu sạch trước khi tạo hai file này.

## Giả định tạm để triển khai lát cắt đầu

- Dùng tên làm việc “Tiệm Hoa”; nhận diện phát hành chưa chốt.
- Giữ iOS là nền tảng phát hành đầu theo kế hoạch. Android chỉ dùng để kiểm tra kỹ thuật hiện tại.
- “Doanh thu dự kiến” là tổng giá trị đơn chưa hủy, kể cả chưa giao; “đã thu” là tiền cọc nhập lúc tạo đơn. Cần thay bằng payment ledger trước khi coi thống kê là hoàn chỉnh.
- Dữ liệu được lưu trên thiết bị. Chưa có backup/restore, vì vậy chưa đủ điều kiện phát hành v1.

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
| 16/11/2026 | Bổ sung stack công nghệ, kiến trúc và định hướng thẩm mỹ Flutter Material 3/Cupertino vào `plan.md`. | Đối chiếu `pubspec.yaml`, `light_theme.dart`, `palette.dart` và `app.dart`; các package mới vẫn ở trạng thái đề xuất. |
| 16/11/2026 | Bắt đầu app offline: thay entrypoint/dep cũ, thêm SQLite v1, shell 4 tab, tạo đơn 4 bước, chi tiết/trạng thái, test. | `flutter pub get`, `flutter analyze`, `flutter test` (3 test) và `flutter build apk --debug --flavor dev` pass. Chưa có iOS simulator trong môi trường Linux. |
| 16/11/2026 | Kiểm thử trên Redmi K30 5G (Android 10); thêm ledger, migration, khách hàng, bản nháp và quy tắc trạng thái. | `flutter analyze` sạch, `flutter test` 8 test pass; `flutter run --flavor dev -d 9d9af905` mở app. Đã xem lịch, đơn cũ, chi tiết, khách; xác nhận draft khôi phục/xóa trên máy, không sửa đơn cũ. iOS chưa kiểm chứng. |
| 16/11/2026 | Cold launch phát hiện DB v1 có bảng `payments` sẵn khiến migration báo lỗi; sửa migration chạy lại an toàn, thêm test schema tạo dở và màn khởi động có lỗi/thử lại. | Cài đè APK bằng `adb install -r`, mở sau `force-stop`: app hiển thị đơn cũ, khôi phục draft sau đóng hẳn app; đã xóa draft thử. Build Android debug pass. Chưa tạo lỗi DB có chủ đích trên thiết bị để thử nhánh lỗi UI. |
| 16/11/2026 | Thêm catalog mẫu hoa với định lượng chính/phụ, lưu snapshot sản phẩm vào đơn; thêm sửa đơn với ràng buộc tiền đã thu từ ledger, migration SQLite v4. | `flutter analyze` sạch, 11 test pass gồm catalog snapshot, sửa đơn và migration v3; build dev debug pass. Cài đè và cold launch trên Redmi K30 5G: đơn cũ vẫn hiển thị, catalog/form thêm mẫu và form sửa đơn mở đúng. Chưa lưu thay đổi vào đơn cũ trên thiết bị. |
| 16/11/2026 | Bổ sung tìm kiếm theo khách/số điện thoại/tên hoa/địa chỉ/mã đơn và lọc trạng thái/ngày giao trong danh sách đơn. | `flutter analyze` sạch, 12 test pass, build dev debug pass; cài đè và mở màn danh sách có bộ lọc trên Redmi K30 5G. |
| 16/11/2026 | Thêm ảnh đơn lưu trong thư mục app và metadata SQLite v5; danh sách mua hoa theo kỳ cùng dấu đã mua SQLite v6. Sửa lỗi refresh `setState` trả `Future` ở catalog/ảnh/danh sách mua hoa và vòng đời dialog thanh toán. | `flutter analyze` sạch, 17 test pass, build dev debug pass. Redmi K30 5G: tạo đơn thử từ mẫu có 12 cành, sửa phí giao 0→20.000 đ giữ cọc 50.000 đ, chọn ảnh qua Google Photos, cold launch thấy ảnh, xóa ảnh; danh sách ngày mai có 12 cành và đánh dấu được. Thử thu/hoàn 1.000 đ sau khi sửa lỗi dialog, không còn màn lỗi; hoàn hết cọc, hủy đơn thử và ẩn mẫu thử. Đơn cũ #1 không đổi. Camera và iOS chưa kiểm chứng. |
| 16/11/2026 | Thêm 6 ảnh hoa mặc định dạng thumbnail, gán ngẫu nhiên và lưu ổn định khi thêm mẫu không có ảnh; cho chọn ảnh từ thư viện. Nhập 10 mẫu catalog có giá/định lượng, migration SQLite v7/v8 cập nhật dữ liệu cũ và sửa ảnh theo tên mẫu. | `dart format` sạch, `flutter analyze` sạch, 19 test pass gồm seed/migration v6, build dev debug pass. Cài đè trên Redmi K30 5G; màn Mẫu hoa hiển thị 10 mẫu với ảnh, form thêm mẫu có tùy chọn ảnh và fallback, đơn cũ #1 vẫn hiện trên tổng quan. Chưa kiểm thử chọn ảnh catalog từ thư viện hoặc iOS. |
| 16/11/2026 | Hoàn thiện Phase 3 trên Android: tổng hợp dashboard theo tháng giao và loại đơn hủy, đồng bộ ngày chọn khi chuyển tháng/năm; khóa thu thêm sau hủy nhưng vẫn cho hoàn cọc, hiển thị số cần hoàn; ghi nhật ký trường đã sửa vào SQLite v9 và chi tiết đơn. | `dart format` sạch, `flutter analyze` sạch, 23 test pass, build dev debug pass. Redmi K30 5G: dashboard tháng 11 hiển thị 1 đơn/120.000 đ, tab Thống kê loại đơn thử đã hủy; chuyển lịch sang tháng 12 chọn 01/12; camera chụp ảnh vào đơn thử #2, ảnh còn sau cold launch, xóa thành công. Đơn cũ #1 còn nguyên. Chưa kiểm chứng iOS; reschedule nhắc phụ thuộc Phase 5. |
| 16/11/2026 | Chặn tạo đơn có giờ giao bằng hoặc trước thời điểm hiện tại đến giây; chặn dời giờ giao đơn cũ về quá khứ nhưng vẫn cho sửa đơn lịch sử nếu giữ nguyên giờ. Form giới hạn ngày và báo lỗi; repository kiểm tra lại trong giao dịch lưu. | `dart format` và `flutter analyze` sạch, 26 test pass gồm mốc ±1 giây, cập nhật đơn lịch sử và draft quá hạn; build dev debug pass, cài đè/cold launch trên Redmi K30 5G không có lỗi Flutter. |
| 16/11/2026 | Chuyển thông báo ngắn và lỗi nhập liệu sang toast dùng chung; thêm dấu `*` đỏ cho trường bắt buộc. Làm mờ ngày đã qua trong lịch và date picker; khóa nút Tạo đơn khi chọn ngày cũ, khóa Lưu đơn khi giờ giao hết hạn và cho quay lại chọn giờ. | `dart format` và `flutter analyze` sạch, 29 test pass; build dev debug và cài đè trên Redmi K30 5G. Đã xem ngày cũ/nút mờ, nhãn bắt buộc và toast trên máy; chỉnh vị trí toast để không che nút thao tác. |
| 16/11/2026 | Thay chọn ngày/giờ hai bước bằng bánh xe cuộn 24 giờ; cho thêm nhiều mẫu hoa hoặc sản phẩm thủ công, tăng giảm số lượng, tính giá/định lượng theo dòng; định dạng tiền khi nhập theo locale và migration SQLite v10 giữ đơn một sản phẩm cũ. | `dart format`, `flutter analyze` sạch; 33 test pass gồm luồng nhiều sản phẩm, tổng định lượng, formatter vi/en và migration v9. Build/cài đè dev debug trên Redmi K30 5G; đã mở form, chọn mẫu, xem số lượng và bộ chọn giờ trên máy; cold launch giữ hai đơn cũ. Đã xóa bản nháp dùng để kiểm thử. |
| 16/11/2026 | Đồng bộ ngày chọn ở lịch chính vào form tạo đơn, kể cả khi có bản nháp; tách chọn ngày và giờ thành hai thao tác liên tiếp. Bước giao hàng hiển thị riêng ngày và giờ, bộ chọn giờ chỉ còn hai cột 24 giờ. | `dart format`, `flutter analyze` sạch; 36 test pass gồm ngày lịch truyền vào form, khôi phục draft và thứ tự chọn ngày rồi giờ. Build/cài đè dev debug trên Redmi K30 5G; chọn 19/11 ở lịch, qua khách hàng và sản phẩm thấy 19/11 ở bước giao hàng. Đã mở hai bộ chọn và xóa bản nháp thử. |
| 16/11/2026 | Remake giao diện theo nhánh hotel booking của Best-Flutter-UI-Templates: màu mint, WorkSans, nền sáng, thẻ ảnh, điều hướng và form nhất quán trên lịch, đơn, thống kê, catalog, khách, danh sách mua hoa, chi tiết và tạo/sửa. Giữ nguyên repository và quy tắc nghiệp vụ. | `flutter analyze` sạch, 36 test pass, build/cài đè dev debug trên Redmi K30 5G. Đã xem trực tiếp lịch, danh sách đơn, hồ sơ, catalog và form sửa mẫu. Font và cách dùng template ghi trong README; bản quyền MIT được giữ ở `third_party/`. |
| 16/11/2026 | Thay lớp màu mint của template bằng hệ Xanh Pastel Cẩm Tú Cầu theo `bang-phoi-mau-app-ban-hoa-xanh-pastel.md` (Hướng 1): nền kem, thẻ xanh băng, xanh cẩm tú cầu cho vùng nổi bật, navy cho CTA/chữ, sage và đào cho trạng thái. Giữ nguyên bố cục template và logic. | `dart format`, `flutter analyze` sạch; 36 test pass; build/cài đè dev debug trên Redmi K30 5G. Đã xem lịch, CTA, navigation và danh sách đơn trên máy với màu mới. |
| 16/11/2026 | Chuyển kiểu chữ sang Playfair Display cho tiêu đề/tên hoa và Be Vietnam Pro cho nội dung, giá, CTA theo `he-thong-mau-sac-va-font-app-ban-hoa.md`; đóng gói font offline và giấy phép OFL. | `dart format`, `flutter analyze` sạch; 36 test pass; build/cài đè dev debug trên Redmi K30 5G. Đã xem lịch và danh sách đơn, dấu tiếng Việt hiển thị rõ, không thấy tràn chữ. |

## Quy tắc cập nhật

Khi bắt đầu một phase: đổi trạng thái thành `Đang làm`, ghi phạm vi đang xử lý. Khi hoàn thành: ghi commit/PR hoặc đường dẫn file chính, kết quả test và thiết bị đã kiểm tra, rồi mới đổi `Hoàn thành`. Nếu đổi phạm vi, cập nhật `plan.md` trước và ghi lý do trong nhật ký này.

# Kế hoạch xây dựng app quản lý đơn hoa theo tài liệu Flowie

Ngày lập: 16/11/2026. Nguồn yêu cầu sản phẩm: `Clone_app_Flowie_Quan_ly_don_hoa.pdf` (17 trang). Đây là kế hoạch triển khai, không phải trạng thái đã hoàn thành. Các câu mô tả tính năng trong PDF được dùng làm đầu vào sản phẩm; dòng yêu cầu dở dang ở trang 17 không được xem là chỉ dẫn thực thi bổ sung.

## 1. Mục tiêu và ranh giới

- App iPhone cho shop hoa nhỏ: tạo đơn nhanh, theo dõi lịch và trạng thái giao, biết tiền đã thu/còn phải thu, lập danh sách hoa cần mua, gửi hóa đơn kèm VietQR.
- Dữ liệu đơn và khách lưu trên thiết bị, không cần tài khoản hoặc máy chủ lưu đơn. Analytics/crash chỉ chứa sự kiện kỹ thuật ẩn danh, không gửi tên, số điện thoại, địa chỉ, ghi chú, hình ảnh hoặc nội dung đơn.
- Ưu tiên iOS vì tài liệu mô tả iPhone, iCloud, Face ID, Live Activity và Dynamic Island. Android trong repo là nền tảng sẵn có; quyết định phát hành Android cần chốt riêng ở Phase 0. Các chức năng iOS đặc thù phải có phương án hiển thị tương đương trong app khi thiết bị không hỗ trợ.
- Bản đầu gồm toàn bộ luồng lõi ở các Phase 1–7, kiểm thử và phát hành ở Phase 8. Flowie Pro (iCloud, Face ID, xuất Excel; gói tháng/năm/trọn đời và trial) là Phase 9 **sau khi bản đầu phát hành**, đúng thứ tự trong PDF.
- Dùng ảnh chụp trong PDF làm tham chiếu UX, không sao chép thương hiệu, biểu tượng, ảnh sản phẩm hay câu chữ có bản quyền khi phát hành.

## 2. Hiện trạng codebase và hướng kế thừa

| Thành phần | Hiện có | Việc cần làm |
| --- | --- | --- |
| Flutter | Flutter 3.41.9 theo README, `flutter_bloc`, `auto_route`, `get_it`/`injectable`, theme, l10n | Đổi tên/nhận diện app; dựng feature module cho orders, customers, catalog, calendar, shopping, statistics |
| Màn hình | Splash, onboarding, language, permission, settings; `HomeScreen` chỉ hiện chữ Home và quảng cáo | Thay Home bằng dashboard/lịch và bottom navigation; thêm tất cả màn nghiệp vụ |
| Lưu trữ | `SharedPreferencesManager`, `hydrated_bloc` cho trạng thái nhỏ | Thêm DB cục bộ có migration và query/index; lưu ảnh thành phẩm/mẫu/feedback dạng file trong app directory, DB giữ đường dẫn/metadata; backup/restore nếu phạm vi phát hành yêu cầu |
| Tích hợp | Firebase analytics/crash/remote config, ads, Adjust, IAP wrapper, Firebase Messaging, share_plus | Rà soát và tắt luồng quảng cáo/track không phù hợp; thông báo đơn dùng local scheduling; tái dùng share và IAP sau khi kiểm chứng cấu hình |
| Native iOS | Runner và cấu hình flavor có sẵn | Thêm extension WidgetKit/Live Activity, entitlement và App Group khi tới Phase 6; kiểm tra provisioning trên thiết bị thật |
| Chất lượng | Chưa thấy `test/` hoặc `integration_test/` | Thêm kiểm thử logic, persistence, widget/flow trọng yếu; CI cho analyze/test/build |

**Lưu ý kỹ thuật:** `pubspec.yaml` đang chứa URL dependency có token nhúng. Trước khi chia sẻ repo hoặc chạy CI, chuyển credential sang cơ chế secret/SSH hợp lệ và thu hồi token cũ. Không sao chép URL này vào tài liệu/issue/log.

## 3. Mô hình dữ liệu và quy tắc chung

- `ShopProfile`: tên shop, logo, thông tin chuyển khoản/VietQR, múi giờ, thiết lập thông báo.
- `Customer`: id, tên, điện thoại chuẩn hóa, ghi chú, số lần mua; gợi ý theo tên/số và cho phép khách vãng lai. Không nhập danh bạ tự động.
- `Product/FlowerItem`: tên mẫu, ảnh, danh sách hoa chính/phụ và số lượng/đơn vị; giữ bản chụp thông tin sản phẩm ở `OrderItem` để đơn cũ không đổi khi catalog sửa.
- `Order`: mã, customer snapshot, item, giá, phí ship, cọc, tổng, còn lại, ngày/giờ giao, địa chỉ/người nhận, trạng thái, ghi chú, timestamps. Số tiền lưu bằng số nguyên VND; `remaining = max(total - paid, 0)`, hỗ trợ nhiều lần thu và hoàn tiền bằng ledger thay vì chỉ một cờ “đã thanh toán”.
- `OrderStatus`: Mới → Đang làm → Chờ khách duyệt → Đang giao → Đã giao; có Hủy như trạng thái riêng để không cộng doanh thu/việc cần làm sai. Lưu lịch sử đổi trạng thái và thời điểm giao thực tế.
- `OrderMedia`, `Payment`, `Reminder`: metadata ảnh mẫu/thành phẩm/lúc giao/feedback, các giao dịch cọc/thu thêm, mốc nhắc trước giao/quá giờ/thu tiền. Định nghĩa chính sách xóa, sửa, timezone và đơn trùng ngay từ đầu.
- Tách repository/use case khỏi UI. DB và ảnh là nguồn dữ liệu chuẩn; Bloc/Cubit chỉ quản lý trạng thái màn hình. Viết migration từ schema v1 và kiểm tra mở lại dữ liệu sau nâng cấp.

## 4. Các phase triển khai

### Phase 0 — Chốt phạm vi và nền dự án

**Việc làm:** đối chiếu từng screenshot PDF (dashboard/lịch, danh sách đơn, chi tiết/trạng thái, khách, 4 bước tạo đơn, xác nhận, thống kê); lập map màn/luồng và design tokens; chốt tên/brand riêng, thiết bị iOS tối thiểu, phạm vi Android, cách xác định “doanh thu”, nguồn VietQR và chính sách backup. Rà soát startup vì hiện tại phụ thuộc Firebase/IAP/remote config; cấu hình chế độ local-first hoạt động ngay cả khi offline. Dọn tracking/ads khỏi các màn nghiệp vụ nếu không nằm trong sản phẩm. Kiểm tra build hiện trạng và credential dependency.

**Đầu ra:** bảng phạm vi có mockup/tiêu chí chấp nhận cho từng màn; quyết định kỹ thuật và privacy; app khởi động vào shell mới không cần mạng. **Gate:** build iOS dev trên simulator, mở app offline, các quyết định phạm vi được ghi lại.

### Phase 1 — Nền dữ liệu cục bộ, điều hướng và UI shell

**Việc làm:** DB, migration, repositories, file storage ảnh; model/validation cho shop, customer, product, order, payment; theme và l10n tiếng Việt; tab Lịch, Đơn hàng, Thống kê, Cá nhân, nút tạo đơn; màn empty/loading/error. Thay `HomeScreen` placeholder, mở route mới qua `AppRouter` và DI. Tạo dữ liệu demo chỉ cho dev flavor.

**Đầu ra:** shell tương ứng bố cục PDF, CRUD tầng dữ liệu, dữ liệu còn nguyên sau kill/relaunch. **Gate:** migration v1 chạy được; test tính tổng/cọc/còn lại và query theo ngày/trạng thái; kiểm tra không có nội dung đơn trong analytics.

### Phase 2 — Tạo đơn 4 bước và danh bạ khách

**Việc làm:** 1) Khách hàng: tên/số, khách cũ gợi ý, khách vãng lai; 2) Sản phẩm: mẫu/ảnh, tên, hoa chính/phụ, giá; 3) Giao hàng: ngày giờ, địa chỉ, người nhận, ghi chú; 4) Thanh toán: giá, ship, cọc, số còn lại. Thêm quét ảnh tin nhắn để OCR gợi ý tên/số và nhận diện ảnh mẫu để gợi ý tên/loại hoa. Ưu tiên xử lý trên thiết bị; nếu giải pháp nhận diện cần dịch vụ mạng thì phải chốt lại ranh giới riêng tư ở Phase 0 và chỉ gửi ảnh khi người dùng chủ động đồng ý. Mọi kết quả nhận diện đều phải cho sửa tay và luồng tạo đơn vẫn dùng được khi nhận diện thất bại/offline. Giữ draft khi chuyển bước/đóng app, kiểm tra dữ liệu, xác nhận trước khi lưu, chống lưu trùng khi chạm nhiều lần. Tạo màn danh sách/chi tiết khách dù PDF ghi một số màn chưa có.

**Đầu ra:** tạo/sửa/xem đơn hoàn chỉnh, gợi ý khách cũ, danh sách khách, nhập nhanh từ ảnh. **Gate:** đi hết 4 bước với đơn mới/khách cũ, thoát và tiếp tục draft, mở lại app thấy đơn đúng dữ liệu và số tiền; OCR/nhận diện gợi ý đúng trên bộ ảnh thử đại diện và cho chỉnh sửa khi sai.

### Phase 3 — Vận hành đơn, lịch và media

**Việc làm:** dashboard doanh thu tháng + số đơn + lịch tháng + đơn sắp tới; danh sách đơn lọc theo ngày/trạng thái/tìm kiếm; chi tiết đơn và đổi trạng thái một chạm theo quy tắc; lưu ảnh thành phẩm, ảnh giao, feedback; hoàn/hủy và nhật ký thay đổi. Xử lý sửa giờ giao sau khi đã đặt nhắc.

**Đầu ra:** shop biết hôm nay giao gì, đơn nào đang làm/chờ duyệt/đang giao. **Gate:** đổi trạng thái, thêm/xóa ảnh, lọc lịch qua tháng/năm; số lượng và tổng trên dashboard khớp dữ liệu mẫu.

### Phase 4 — Hóa đơn, chia sẻ và VietQR

**Việc làm:** hồ sơ shop, cấu hình tài khoản nhận tiền; render ảnh hóa đơn có shop, khách, sản phẩm, ngày giao, tổng/cọc/còn lại; tạo VietQR cho tiền cọc hoặc số còn lại dựa trên số tiền thực tế; share sheet iOS tới Zalo/Messenger/app khác. Bảo đảm ảnh chia sẻ không lộ ghi chú nội bộ và nội dung QR có thể kiểm tra trước khi gửi.

**Đầu ra:** ảnh hóa đơn rõ trên máy và khi chia sẻ, QR theo đúng số tiền. **Gate:** đối chiếu nội dung ảnh/QR với đơn mẫu, kiểm tra diacritics tiếng Việt và nhiều kích thước màn; thử chia sẻ trên thiết bị thật.

### Phase 5 — Nhắc việc và danh sách hoa cần mua

**Việc làm:** local notifications trước giờ giao, quá giờ, còn tiền chưa thu; cấp quyền vào thời điểm cần thiết; reschedule/cancel khi sửa/hủy/giao xong/đã thu đủ. Tổng hợp hoa theo hôm nay/ngày mai/7 ngày từ các đơn chưa hủy, có đơn vị/số lượng và khả năng đánh dấu đã mua; cảnh báo khi dòng sản phẩm thiếu định lượng.

**Đầu ra:** danh sách mua hoa và nhắc việc nhất quán với DB, hoạt động offline. **Gate:** đổi giờ giao/hủy/thu tiền không tạo nhắc cũ; test qua đổi múi giờ/khởi động lại và giới hạn notification iOS.

### Phase 6 — Widget và Live Activity iOS

**Việc làm:** WidgetKit cho màn chính/màn khóa hiển thị đơn sắp tới; App Group chia sẻ snapshot tối thiểu; Live Activity/Dynamic Island cho đơn đang giao trên máy hỗ trợ, cập nhật/kết thúc khi giao/hủy. Chỉ hiện thông tin nhạy cảm phù hợp trên màn khóa, có tùy chọn ẩn tên/địa chỉ.

**Đầu ra:** widget và Live Activity nhận đúng đơn, cập nhật khi dữ liệu thay đổi. **Gate:** chạy trên thiết bị iOS hỗ trợ và simulator phù hợp; kiểm tra cài mới, khởi động lại, đơn hủy, app ở background và quyền riêng tư màn khóa.

### Phase 7 — Thống kê và hoàn thiện trải nghiệm

**Việc làm:** tuần/tháng/quý/năm: doanh thu, số đơn, đã thu/còn phải thu; khách quay lại, sản phẩm bán chạy, ngày/buổi đông đơn. Định nghĩa rõ doanh thu theo ngày tạo hay ngày giao và áp dụng nhất quán; xử lý đơn hủy, hoàn tiền, đơn chưa giao, kỳ không có đơn. Hoàn thiện tìm kiếm, empty state, accessibility, l10n, hiệu năng danh sách/ảnh và cài đặt quyền riêng tư.

**Đầu ra:** số liệu có thể đối soát từ danh sách đơn và payment ledger. **Gate:** bộ dữ liệu chuẩn có đơn cọc, thu nhiều lần, hủy và hoàn tiền cho kết quả đúng ở mọi kỳ.

### Phase 8 — Kiểm thử, hardening và phát hành v1

**Việc làm:** test end-to-end tạo → xử lý → giao → thu tiền → thống kê; migration/backup ảnh, offline, permission denied, khôi phục app sau crash, hiệu năng và bộ nhớ. Kiểm tra App Store privacy labels, quyền ảnh/camera/thông báo, analytics không chứa PII, metadata/screenshots và TestFlight. Xóa/tắt cấu hình ads/attribution không dùng, thay brand placeholder; audit lại URL dependency có credential. Chốt crash-free và dữ liệu không mất trên thiết bị thử.

**Đầu ra:** bản iOS v1 phát hành. **Gate:** build release ký được, QA trên thiết bị thật, checklist store/privacy hoàn tất, không còn lỗi chặn luồng tạo/giao/thu đơn.

### Phase 9 — Flowie Pro, bắt đầu sau release v1

**Việc làm:** iCloud sync nhiều máy với conflict resolution và migration từ dữ liệu local; Face ID/Passcode khóa app; xuất Excel; entitlement IAP gói tháng/năm với trial 7 ngày và gói trọn đời, restore purchase, trạng thái offline và xử lý hết hạn. Thiết kế paywall sau khi các quyền lợi Pro thật sự hoạt động.

**Đầu ra:** bản Pro có đồng bộ và mua hàng đáng tin cậy. **Gate:** dữ liệu không nhân đôi/mất khi hai máy sửa cùng đơn; trial, mua, hủy, restore và lifetime kiểm thử bằng StoreKit sandbox.

## 5. Thứ tự phụ thuộc và cách cập nhật

`Phase 0 → 1 → 2 → 3`; Phase 4 và 5 có thể triển khai sau khi model đơn ổn định; Phase 6 cần Phase 3/5; Phase 7 cần ledger và trạng thái hoàn chỉnh; Phase 8 đóng mọi gate v1; Phase 9 chỉ khởi động sau release.

Mỗi phase chỉ chuyển `Hoàn thành` khi gate được chứng minh bằng test/thiết bị và ghi bằng chứng trong `progress.md`. Khi phát hiện khác biệt giữa screenshot và mô tả chữ, ghi quyết định tại Phase 0 hoặc mục “Quyết định” trong progress trước khi code. Không đánh dấu tính năng là hoàn thành chỉ vì đã có boilerplate, package hoặc màn hình tĩnh.

# Báo cáo đánh giá app Tiệm Hoa và kế hoạch theo phase

Ngày: 20/11/2026. Phạm vi: **chỉ tiệm hoa bán lẻ**; bán buôn sẽ là bản app riêng. Đánh giá dựa trên mã nguồn nhánh `develop` (`lib/flower/`) và ghi chép kiểm thử trong `progress.md`; chưa thử với chủ tiệm thật và chưa xem trực tiếp app chạy trên máy.

## 1. Tóm tắt

Mô hình: **bản cơ bản miễn phí** phải đủ để một tiệm bán lẻ chạy hằng ngày; **bản Pro trả phí** bán thêm sự an tâm (đồng bộ, bảo mật), số liệu kinh doanh, chăm sóc khách và thao tác ngày lễ.

App hiện đã đủ cho luồng **nhận đặt trước → làm → giao theo lịch → thu tiền**, nhưng còn thiếu 8 thứ người dùng miễn phí vẫn chờ đợi (bán tại quầy, đơn hoa tặng, thanh toán, an toàn dữ liệu). Chưa có chức năng Pro nào hoạt động; repo mới có lớp mua trong app (IAP) từ boilerplate.

Thứ tự làm:

| Phase | Nội dung | Gói | Kết thúc bằng |
| --- | --- | --- | --- |
| 1 | Bổ sung 8 chức năng còn thiếu | Miễn phí | Chạy thử với 1–2 tiệm thật |
| 2 | Cải thiện chức năng hiện có + UI/UX | Miễn phí | **Phát hành bản miễn phí** |
| 3 | Pro đợt 1: 14 chức năng + mua trong app | Pro | **Mở bán Pro** |
| 4 | Pro đợt 2: 4 chức năng | Pro | Cập nhật theo phản hồi người trả phí |
| 5 | Pro đợt 3: nhân viên, nhiều cửa hàng | Pro (có thể gói cao hơn) | Cần máy chủ + đăng nhập |

Nguyên tắc chung:

- Không giới hạn số đơn, số khách, số mẫu hoa ở bản miễn phí. Khóa Pro theo giá trị thêm, không theo số lượng.
- Mọi chức năng đang có (kể cả nhắc việc, Live Activity, thống kê cơ bản) giữ miễn phí; khóa lại thứ đã cho dùng sẽ gây phản ứng xấu.
- Hết hạn Pro không khóa dữ liệu đã nhập.

---

## 2. Kế hoạch theo phase

### Phase 1 — Bổ sung chức năng còn thiếu (miễn phí)

Mục tiêu: tiệm bán lẻ bán được mọi loại đơn phổ biến, không mất dữ liệu, không sai tiền.

- [x] **Chuẩn bị:** tách `lib/flower/presentation/flower_app.dart` (~3.400 dòng, chứa gần hết màn hình) thành file theo màn trước khi thêm chức năng.
- [x] **Sao lưu / khôi phục thủ công ra file** (lưu vào Drive, Zalo, máy tính). Mất hoặc đổi máy là mất sổ đơn; backup Android đang tắt. Bản tự động lên đám mây để Pro.
- [x] **Đơn hoa tặng:** người nhận (tên, SĐT) tách khỏi người đặt, lời thiệp / banner, ẩn danh người tặng. Hiện đơn chỉ có một tên, một SĐT; lời thiệp phải nhét vào ghi chú.
- [x] **Hình thức nhận** (giao tận nơi / khách tới lấy / mua tại quầy) + **màn Bán nhanh** một trang: chọn mẫu → số tiền → thu tiền → xong. Đơn lấy tại tiệm không cần địa chỉ, phí giao, trạng thái “Đang giao”.
- [x] **VietQR động** (số tiền còn lại + nội dung mã đơn) và **phương thức thanh toán** (tiền mặt / chuyển khoản / COD). Hiện QR là ảnh tĩnh, khách phải tự gõ số tiền.
- [x] **Trạng thái linh hoạt:** bỏ qua “Chờ duyệt” (theo cài đặt hoặc theo đơn), lùi trạng thái khi bấm nhầm, đơn tại quầy đi thẳng “Hoàn tất”. Hiện mọi đơn phải đi đủ 5 bước.
- [x] **Giảm giá / phụ thu theo đơn** (%, số tiền). Thiếu thì tổng tiền sai.
- [x] **Gọi / nhắn Zalo một chạm từ đơn**, gửi ảnh thành phẩm cho khách duyệt. Bước “Chờ duyệt” có sẵn nhưng chưa có cách gửi ảnh; trong code chưa có liên kết gọi điện.
- [x] **Sắp lại điều hướng + màn “Hôm nay”:** đổi tab “Cá nhân” thành “Cửa hàng”; màn chính mở ra đơn cần làm theo giờ, đơn chưa thu đủ, hoa cần mua; lịch tháng thành màn phụ. Hiện Khách hàng, Mẫu hoa, Danh sách mua hoa bị giấu trong tab “Cá nhân”.

**Trạng thái 20/11/2026:** đã code xong 9/9 mục, 104 test tự động đạt, build APK dev đạt (chi tiết trong `progress.md`). Còn lại là phần kiểm tra trên máy thật bên dưới.

**Điều kiện xong Phase 1:** test migration cho các trường mới; chạy thử 1 tuần với 1–2 chủ tiệm thật, ghi lại thao tác chậm / thiếu.

### Phase 2 — Cải thiện chức năng hiện có (miễn phí)

Mục tiêu: thao tác nhanh hơn lúc đông khách, đúng nhịp làm việc của tiệm, sẵn sàng phát hành.

- [ ] **Tạo đơn:** mặc định thông minh (phí giao hay dùng, giờ giao gần nhất); cho lưu sớm khi đủ dữ liệu; nút “Đặt lại như lần trước” từ lịch sử khách.
- [ ] **Giờ giao:** cho chọn khung giờ (sáng, trưa, chiều, tối); cho ghi bù đơn đã bán trong ngày mà quên nhập.
- [ ] **Thanh toán:** nút “Đã thu đủ” một chạm; gợi ý số tiền còn lại; cọc nhanh 50% / 100%.
- [ ] **Hóa đơn:** thêm ảnh sản phẩm (logo tiệm để Pro).
- [ ] **Mẫu hoa:** danh mục (bó, giỏ, hộp, kệ khai trương, hoa cưới, hoa tang), kích cỡ S/M/L, ẩn mẫu hết hoa, tìm kiếm.
- [ ] **Khách hàng:** tổng chi tiêu, công nợ còn lại, các địa chỉ giao đã dùng (nhãn khách để Pro).
- [ ] **Nhắc việc:** nhắc buổi tối “chuẩn bị đơn ngày mai”, nhắc sáng sớm đi chợ hoa kèm danh sách mua, nhắc 7 ngày trước dịp lễ lớn.
- [ ] **Chi tiết đơn:** chạm địa chỉ mở bản đồ (ô nhập đã có, màn chi tiết chưa có).
- [ ] **Vuốt đổi trạng thái:** gợi ý lần đầu + nút “Hoàn tác” trong toast.
- [ ] **Cỡ chữ:** 14 chỗ đang dùng cỡ 9–11, nâng lên tối thiểu 12–13; kiểm tra với cỡ chữ hệ thống lớn.
- [ ] **Thiết lập lần đầu:** wizard 3 bước — tên tiệm, tài khoản ngân hàng, chọn mẫu hoa gợi ý.
- [ ] **Việc phát hành còn mở trong `progress.md`:** keystore thật, mục P0 còn lại của `SECURITY_REPORT.md`, QA iOS, chính sách quyền riêng tư (Goong).

**Điều kiện xong Phase 2:** QA Android + iOS → **phát hành bản miễn phí**.

### Phase 3 — Pro đợt 1 (14 chức năng, không cần máy chủ riêng)

Mục tiêu: mở bán Pro với những thứ chủ tiệm sẵn sàng trả tiền.

Nền tảng mua hàng:

- [ ] Gói tháng / năm / trọn đời, dùng thử 7 ngày (theo `plan.md`); khôi phục giao dịch, xử lý hết hạn, trạng thái offline.
- [ ] Badge “Pro” cạnh chức năng + màn giới thiệu khi bấm vào; không bật paywall khi mở app hay giữa lúc tạo đơn.
- [ ] Gợi ý nâng cấp đúng lúc: sau 30 đơn (sao lưu tự động), 2 tuần trước dịp lễ lớn (giới hạn đơn, giá mùa lễ), cuối tháng (báo cáo lãi).

Chức năng:

- [ ] Sao lưu tự động hằng ngày lên iCloud / Google Drive.
- [ ] Đồng bộ nhiều máy của cùng một chủ (điện thoại + iPad).
- [ ] Khóa app bằng Face ID / vân tay / mã PIN.
- [ ] Giá vốn mẫu hoa, lãi gộp theo đơn / kỳ.
- [ ] Nguồn đơn và doanh thu theo kênh (Zalo, Facebook, điện thoại, vào tiệm).
- [ ] Báo cáo nâng cao: so sánh cùng dịp lễ năm trước, tỷ lệ hủy, giá trị đơn trung bình, khách chi tiêu nhiều nhất.
- [ ] Xuất Excel / PDF (đơn, doanh thu, sổ thu chi).
- [ ] Ngày kỷ niệm khách (sinh nhật, kỷ niệm cưới) + nhắc trước 3–7 ngày.
- [ ] Nhãn khách (VIP, hay hủy), ghi chú sở thích.
- [ ] Tin nhắn mẫu (xác nhận đơn, đã giao, chúc mừng) gửi nhanh qua Zalo.
- [ ] Giới hạn số đơn theo ngày / khung giờ, cảnh báo quá tải.
- [ ] Giá mùa lễ tự áp cho mẫu hoa theo ngày (14/2, 8/3, 20/10…).
- [ ] Quản lý shipper ngoài: phí thực trả, tiền COD shipper đang giữ, đối soát cuối ngày.
- [ ] Hóa đơn có logo, màu tiệm; bỏ dòng “Tạo bằng …”.

**Điều kiện xong Phase 3:** đồng bộ không nhân đôi / mất dữ liệu khi hai máy sửa cùng đơn; thử mua, dùng thử, hủy, khôi phục, trọn đời trên sandbox → **mở bán Pro**.

### Phase 4 — Pro đợt 2

- [ ] Tích điểm / thẻ thành viên.
- [ ] Danh sách mua hoa nâng cao: làm tròn theo bó (10/20 cành), cộng % hao hụt, gửi cho mối hàng.
- [ ] Phiếu giao cho shipper (địa chỉ, người nhận, COD, không giá) và in thiệp từ lời chúc trong đơn.
- [ ] Đọc ảnh chụp tin nhắn khách (OCR) để điền sẵn đơn.

**Điều kiện:** thứ tự trong phase theo phản hồi người dùng Pro sau Phase 3.

### Phase 5 — Pro đợt 3 (cần máy chủ)

- [ ] Máy chủ, đăng nhập tài khoản, di chuyển dữ liệu từ máy lên.
- [ ] Tài khoản nhân viên + phân quyền (thợ cắm không thấy doanh thu, shipper chỉ thấy đơn giao).
- [ ] Nhiều cửa hàng trong một tài khoản.

Chi phí vận hành lớn; nên cân nhắc tách thành gói cao hơn (ví dụ “Pro Team”) thay vì gộp vào Pro.

---

## 3. Chi tiết đánh giá

### 3.1 Chức năng hiện có

| Nhóm | Đang có | Đánh giá | Còn hở |
| --- | --- | --- | --- |
| Tạo đơn | 4 bước: khách → sản phẩm → giao → thanh toán; nhiều dòng, sản phẩm nhập tay; bản nháp tự lưu | Tốt | Không bán nhanh tại quầy, không nhân bản đơn |
| Khách hàng | Danh bạ, khách vãng lai, gợi ý khách cũ, lịch sử đơn | Khá | Một tên + một SĐT; không tách người đặt / người nhận |
| Mẫu hoa | Giá, ảnh, thành phần hoa chính/phụ | Khá | Không danh mục, không kích cỡ, không giá vốn |
| Lịch & đơn | Lịch tuần/tháng, lọc, tìm kiếm, chuông đơn cần chú ý, vuốt đổi trạng thái | Tốt | Không giới hạn số đơn/khung giờ ngày lễ |
| Trạng thái | Mới → Đang làm → Chờ duyệt → Đang giao → Đã giao / Hủy; lịch sử sửa | Khá | Bắt buộc đủ bước, không lùi được |
| Thanh toán | Cọc, thu thêm, hoàn tiền theo sổ giao dịch | Khá | Không phương thức, không giảm giá / phụ thu |
| Hóa đơn | Ảnh hóa đơn theo dòng sản phẩm + ảnh QR tĩnh, chia sẻ | Khá | QR không kèm số tiền; chưa có phiếu giao |
| Ảnh đơn | Thư viện/camera, lưu trong app | Tốt | Chưa có nút gửi ảnh cho khách duyệt |
| Mua hoa | Tổng hợp hoa cần mua hôm nay/ngày mai/7 ngày, đánh dấu đã mua | Tốt | Chưa làm tròn theo bó, chưa cộng hao hụt |
| Nhắc việc | Trước giờ giao, quá giờ, công nợ; Live Activity iOS | Tốt | Chưa nhắc dịp lễ, ngày kỷ niệm khách |
| Thống kê | Doanh thu, tiền thu ròng, công nợ, khách quay lại, mẫu bán chạy, ngày/buổi đông | Khá | Không lãi gộp, không theo nguồn đơn |
| Dữ liệu | SQLite trên máy; backup Android đang tắt | Yếu | Không sao lưu, không xuất file |

### 3.2 Đánh giá UI/UX

Giao diện đúng chất tiệm hoa và hiện đại; vấn đề chính là **kiến trúc điều hướng** và **tốc độ thao tác lúc đông khách**, không phải thẩm mỹ.

Điểm tốt:

- Bảng màu ấm (nền kem `#FBF7F2`, navy, xanh sage, hồng phấn), font Nunito + Be Vietnam Pro hiển thị tiếng Việt tốt; có dark mode, màu nhấn theo dịp lễ.
- Lịch dải tuần mở rộng thành tháng, badge số đơn / màu trạng thái, ngày quá hạn được cảnh báo.
- Vuốt thẻ đổi trạng thái, toast, thanh bước có icon, dấu `*` cho trường bắt buộc, bản nháp tự lưu.
- Nhập tiền tự định dạng, bánh xe chọn giờ, chọn khách từ danh bạ không cần quyền.

Cần sửa (đã đưa vào Phase 1–2):

| Mức | Vấn đề | Đề xuất | Phase |
| --- | --- | --- | --- |
| Cao | Tab “Cá nhân” giấu Khách hàng, Mẫu hoa, Danh sách mua hoa | Đổi thành “Cửa hàng”; đưa “Cần mua cho ngày mai” ra màn chính | 1 |
| Cao | Không có màn “Hôm nay” dạng việc cần làm | Màn chính: đơn theo giờ, đơn chưa thu đủ, hoa cần mua | 1 |
| Cao | Tạo đơn 4 bước quá dài khi khách đứng chờ / ngày lễ | Màn Bán nhanh 1 trang | 1 |
| Trung bình | Không gọi được khách từ màn đơn | Chạm SĐT để gọi / mở Zalo | 1 |
| Trung bình | 14 chỗ dùng cỡ chữ 9–11 | Tối thiểu 12–13 | 2 |
| Trung bình | Vuốt đổi trạng thái khó khám phá, dễ nhầm | Gợi ý lần đầu + Hoàn tác | 2 |
| Thấp | Chưa có hướng dẫn thiết lập tiệm lần đầu | Wizard 3 bước | 2 |
| Thấp | Chuỗi tiếng Việt viết cứng trong code | Chỉ cần xử lý nếu phát hành quốc tế | — |

### 3.3 Nhóm chức năng Pro (tổng hợp)

| Nhóm | Chức năng | Phase |
| --- | --- | --- |
| An tâm dữ liệu | Sao lưu đám mây tự động, đồng bộ nhiều máy, khóa app | 3 |
| Số liệu kinh doanh | Giá vốn & lãi gộp, nguồn đơn, báo cáo nâng cao, xuất Excel/PDF | 3 |
| Chăm sóc khách | Ngày kỷ niệm + nhắc, nhãn khách, tin nhắn mẫu | 3 |
| Chăm sóc khách | Tích điểm / thành viên | 4 |
| Vận hành ngày lễ | Giới hạn đơn, giá mùa lễ, shipper ngoài & COD | 3 |
| Vận hành ngày lễ | Danh sách mua hoa nâng cao | 4 |
| Thương hiệu | Hóa đơn có logo | 3 |
| Thương hiệu | Phiếu giao, in thiệp | 4 |
| Nhập đơn thông minh | Đọc ảnh tin nhắn (OCR) | 4 |
| Nhiều người | Nhân viên & phân quyền, nhiều cửa hàng | 5 |

Mức giá cụ thể chưa có trong tài liệu dự án. Nên phỏng vấn 3–5 chủ tiệm bán lẻ trước khi chốt chức năng nào vào Pro và mức giá.

# Kế hoạch: nút “Gọi ship” cho đơn giao tận nơi

Lập ngày 20/11/2026. Trạng thái: **chưa làm**, đang chờ duyệt. Đây là kế hoạch, không phải mô tả tính năng đã có.

## Bối cảnh

- App hiện chạy offline, không có máy chủ. Đơn đã có đủ thông tin để giao: người nhận (`contactName`, `contactPhone`), địa chỉ, giờ giao, số tiền còn lại (`remaining`), hình thức nhận (`fulfillment`).
- Hồ sơ shop (`ShopProfile`) có tên, SĐT và địa chỉ tiệm, dùng làm điểm lấy hàng.
- Đã có sẵn chia sẻ qua `share_plus` (gửi ảnh cho khách duyệt) và nút Gọi/Zalo (`contact_actions.dart`), nên mức 1 không cần thêm thư viện.

## Mức 1: soạn sẵn thông tin giao (bản miễn phí)

Không cần tài khoản đối tác hay API. Ước tính khoảng nửa ngày, gồm cả test.

### Hành vi

- Nút **“Gọi ship”** trong chi tiết đơn, chỉ hiện khi đơn là giao tận nơi và chưa ở trạng thái Đã giao hoặc Đã hủy.
- Bấm nút sẽ mở một bảng xem trước nội dung, ví dụ:

  ```
  ĐƠN GIAO HOA #12
  Lấy hàng: Tiệm Hoa Mai · 0901 234 567
  12 Nguyễn Trãi, Q.1, TP.HCM
  Giao đến: Chị Lan · 0912 345 678
  45 Lê Lợi, Q.3, TP.HCM
  Giao lúc: 14:30 · 20/11/2026
  Thu hộ (COD): 350.000đ
  Hàng: hoa tươi (Bó hồng 20 bông), dễ dập, giữ thẳng
  ```

- Hai nút trong bảng:
  - **Sao chép** để dán vào app Ahamove, Grab hay Lalamove.
  - **Gửi** mở bảng chia sẻ của máy (Zalo, Messenger…), hợp với tiệm thuê shipper tự do trong nhóm Zalo.
- Nếu đơn đã thu đủ, dòng COD ghi “Không thu tiền”.
- Nếu hồ sơ shop thiếu SĐT hoặc địa chỉ, bảng hiện nhắc “Thêm địa chỉ tiệm trong Hồ sơ shop” nhưng vẫn cho sao chép.

### Quyền riêng tư

- **Không** đưa vào: ghi chú nội bộ của đơn, lời thiệp, giá từng món.
- Đơn tặng có bật “ẩn tên người tặng” thì không ghi tên và SĐT người đặt.
- Đơn tặng không ẩn tên: thêm dòng “Không gặp người nhận, gọi người đặt: …” để shipper có số dự phòng.

### Việc cần làm

1. `lib/flower/domain/ship_request.dart`: hàm thuần `buildShipRequest(FlowerOrder, ShopProfile)` trả về đoạn văn bản, có định dạng tiền và ngày riêng (domain không phụ thuộc vào presentation).
2. `lib/flower/presentation/order_detail_screen.dart`: thêm nút và bảng xem trước (bottom sheet) có Sao chép / Gửi; đọc hồ sơ shop qua `repository.loadShopProfile()`.
3. Test `test/ship_request_test.dart`, gồm:
   - Đơn thường, đơn tặng, đơn tặng ẩn tên.
   - Đơn đã thu đủ (không COD).
   - Hồ sơ shop thiếu địa chỉ.
   - Ghi chú nội bộ và lời thiệp không lọt vào văn bản.
4. Test widget: nút chỉ hiện với đơn giao tận nơi đang hoạt động; không hiện với đơn khách tới lấy, tại quầy, đã giao, đã hủy.
5. Thử trên máy thật: sao chép rồi dán vào app Ahamove hoặc Grab, gửi qua Zalo.

### Hạn chế

- Chủ tiệm vẫn phải tự đặt trong app ship. Giá ship và trạng thái tài xế không tự cập nhật về đơn.
- Không mở thẳng app Ahamove, Grab hay Lalamove với thông tin điền sẵn, vì chưa tìm thấy liên kết công khai nào làm được việc này.

### Có thể thêm sau (chưa nằm trong phạm vi)

- Lưu đơn vị giao, phí ship thực trả và SĐT tài xế vào đơn (cần migration SQLite).
- Tự chuyển đơn sang “Đang giao” sau khi gửi cho shipper, có hỏi xác nhận.

## Mức 2: đặt ship thật qua API (để cho gói Pro)

Đặt đơn, xem giá và theo dõi tài xế ngay trong app.

### Các hãng

| Hãng | API | Điều kiện |
| --- | --- | --- |
| Ahamove | Có tài liệu công khai: ước tính phí (`/v1/order/estimated_fee`), tạo đơn, xem chi tiết, hủy đơn, webhook trạng thái, đơn nhiều điểm giao | Đăng ký tài khoản đối tác để có API key; môi trường thật phải xin riêng qua email |
| Lalamove | API v3 (v2 đã ngừng từ 04/2024), có Việt Nam. Lấy báo giá (`POST /v3/quotations`) rồi đặt đơn theo báo giá (`POST /v3/orders`); báo giá giữ 5 phút; ký request bằng HMAC SHA256 | Đăng ký qua Partner Portal, có khóa sandbox để thử |
| Grab Express | Không tìm thấy tài liệu API công khai | Có vẻ phải ký hợp đồng đối tác API riêng với Grab Vietnam |

### Vướng mắc chính

- **Cần máy chủ.** Không được nhúng API key vào app, vì ai cũng có thể lấy khóa ra từ file cài đặt (cùng loại rủi ro như các mục trong `SECURITY_REPORT.md`). Webhook trạng thái đơn cũng cần một địa chỉ máy chủ để nhận.
- Dữ liệu người nhận sẽ được gửi tới hãng ship, nên phải ghi vào chính sách quyền riêng tư.
- Cần đăng nhập hoặc định danh tiệm trên máy chủ, đối soát phí ship và xử lý đơn bị hủy hoặc không tìm được tài xế.

### Thứ tự đề xuất khi làm

1. Chọn một hãng trước (Ahamove: tài liệu tiếng Việt, đủ API cho giao trong nội thành).
2. Đăng ký tài khoản đối tác, thử trên staging.
3. Dựng máy chủ nhỏ: giữ khóa, gọi API ước tính phí và tạo đơn, nhận webhook.
4. Trong app: nút “Đặt Ahamove” hiện giá trước khi xác nhận, sau đó hiện trạng thái tài xế trong đơn.
5. Gắn vào gói Pro theo `bao-cao-danh-gia-app.md`.

## Nguồn

- [Ahamove Developers – giới thiệu](https://developers.ahamove.com/docs/introduction)
- [Ahamove – Ước tính phí đơn hàng](https://developers.ahamove.com/vi/docs/api-reference/master-data/estimate-order-fee)
- [Ahamove – Create Order](https://developers-stg.ahamove.com/en/docs/api-reference/order-apis/create-order)
- [Lalamove Developers](https://developers.lalamove.com/)
- [Lalamove API solutions (VN)](https://www.lalamove.com/en-vn/business/api-solutions)
- [GrabExpress Merchant Partner](https://www.grab.com/vn/express-merchant-partner/)

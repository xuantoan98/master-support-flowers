# Tiệm Hoa – Danh sách cải tiến UI màn hình Lịch

> Mục tiêu: đưa thông tin quan trọng nhất (đơn cần giao) lên màn hình đầu tiên, đồng thời làm giao diện hiện đại và đúng chất tiệm hoa hơn.

Mức ưu tiên: **P0** = làm ngay · **P1** = nên làm · **P2** = làm khi có thời gian

---

## 1. Lịch giao hàng (P0)

**Hiện tại:** Lịch tháng chiếm gần hết màn hình, danh sách "Đơn theo ngày" bị đẩy xuống dưới màn hình đầu tiên.

- [x] **P0** Mặc định hiển thị **dải tuần** (1 hàng 7 ngày), vuốt ngang để đổi tuần, kéo xuống (hoặc bấm nút) để mở rộng thành lịch tháng.
- [x] **P0** Đưa danh sách "Đơn theo ngày" lên ngay dưới lịch để thấy được mà không cần cuộn.
- [x] **P0** Phân biệt **"hôm nay"** (viền tròn) và **"ngày đang chọn"** (nền đậm). Hiện tại hai trạng thái trùng nhau.
- [x] **P1** Thay dấu chấm bằng **badge số đơn** ("2", "3") hoặc **chấm màu theo trạng thái**:
  - Chưa làm: xám/cam
  - Đang cắm: xanh dương
  - Đã giao: xanh lá
- [x] **P1** Ngày đã qua nhưng còn đơn chưa hoàn tất (ví dụ 17, 18) cần được làm nổi bật/cảnh báo, không để mờ như ngày trống.
- [x] **P1** Hỗ trợ vuốt ngang để chuyển tháng, ngoài 2 nút mũi tên.
- [x] **P2** Sửa định dạng tiêu đề tháng: `tháng 11 2026` → `Tháng 11, 2026`.

## 2. Nút "Tạo đơn" (FAB) (P0)

**Hiện tại:** Nút FAB mở rộng đè lên các ô ngày 27–30 của lịch.

- [x] **P0** Không để FAB che nội dung. Chọn một trong các cách:
  - FAB mở rộng **tự thu nhỏ thành icon "+"** khi cuộn xuống, hoặc
  - Đặt nút "+" vào **giữa thanh điều hướng dưới**, hoặc
  - Thêm padding dưới cho nội dung đủ để cuộn qua FAB.

## 3. Thẻ tổng quan (Doanh thu / Số đơn) (P1)

**Hiện tại:** 2 thẻ bằng nhau, icon lớn, chỉ có 1 con số, không có ngữ cảnh.

- [x] **P1** Thêm **so sánh với tháng trước**: ví dụ `↑ 12% so với T10`.
- [x] **P1** Tách doanh thu thành **"Đã thu" / "Còn lại"** kèm thanh tiến độ.
- [x] **P1** Thu nhỏ icon để con số là điểm nhấn chính.
- [x] **P2** Chuyển sang bố cục **bento**: 1 thẻ lớn (Doanh thu) + 2 thẻ nhỏ (Đơn trong tháng, Đơn hôm nay).
- [x] **P2** Thêm sparkline nhỏ thể hiện doanh thu theo tuần.

## 4. Header (P1)

**Hiện tại:** Dải xanh cố định "Tiệm Hoa" chiếm khoảng 10% chiều cao màn hình nhưng ít thông tin.

- [x] **P1** Bỏ dải màu riêng, dùng **large title** cùng nền với body, tự thu gọn khi cuộn.
- [x] **P1** Thêm **avatar** hoặc **chuông thông báo** ở góc phải.
- [x] **P2** Thêm lời chào theo thời gian: "Chào buổi sáng / chiều / tối 🌷".
- [x] **P2** Gộp tiêu đề: bỏ trùng lặp giữa "Tiệm Hoa" và "Tổng quan – Lịch giao tháng 11".

## 5. Màu sắc & nhận diện (P2)

**Hiện tại:** Tông xanh lạnh, an toàn nhưng chưa mang tinh thần tiệm hoa.

- [x] **P2** Thử bảng màu ấm hơn: **sage green, hồng phấn, kem**. Giữ **navy** cho nút hành động chính.
- [x] **P2** Đồng bộ màu header (đang là xanh) với nền body (đang là trắng ngà).
- [x] **P2** Màu nhấn theo mùa/dịp lễ: Tết, 14/2, 8/3, 20/10, 20/11.
- [x] **P2** Hỗ trợ **dark mode**.

## 6. Danh sách đơn (P1)

- [x] **P1** Thẻ đơn có **ảnh thumbnail bó hoa**, tên khách, giờ giao, trạng thái (chip màu).
- [x] **P1** Vuốt thẻ đơn để đổi nhanh trạng thái (ví dụ vuốt phải → "Đã giao").
- [x] **P2** **Empty state** có minh họa khi ngày không có đơn, kèm nút "Tạo đơn cho ngày này".

## 7. Chuyển động & cảm giác (P2)

- [x] **P2** Micro-animation khi chọn ngày (scale/fade) và khi chuyển tuần/tháng.
- [x] **P2** Haptic feedback khi tạo đơn thành công hoặc đổi trạng thái.
- [x] **P2** Skeleton loading thay cho spinner khi tải dữ liệu.

---

## Thứ tự triển khai đề xuất

1. Lịch dạng dải tuần + danh sách đơn lên màn hình đầu (mục 1)
2. Sửa FAB che lịch (mục 2)
3. Phân biệt hôm nay / ngày chọn, badge trạng thái (mục 1)
4. Thẻ tổng quan có so sánh và tiến độ (mục 3)
5. Header large title (mục 4)
6. Thẻ đơn có ảnh, vuốt đổi trạng thái (mục 6)
7. Màu sắc, dark mode, animation (mục 5, 7)

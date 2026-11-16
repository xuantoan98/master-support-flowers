# Hệ Thống Thiết Kế Màu Sắc & Kiểu Chữ (Color & Typography System) — App Bán Hoa Chủ Đạo Xanh Cẩm Tú Cầu

Tài liệu này tổng hợp quy chuẩn về màu sắc (tông xanh pastel cẩm tú cầu) và bộ font chữ tiếng Việt chuẩn dấu dành cho giao diện ứng dụng bán hoa (UI/UX Mobile App).

---

## Phần 1: Bảng Phối Màu (Color Palette)

### 1. Các sắc độ xanh cẩm tú cầu trong thiết kế
* **Xanh dương pastel (Sky Blue nhạt):** Màu xanh lam dịu mắt, tạo cảm giác nhẹ nhàng, thư thái và hiện đại.
* **Xanh tím nhạt (Periwinkle / Lavender Blue):** Tông xanh ánh tím nhẹ, phù hợp với hoa nghệ thuật, hoa nhập khẩu hoặc quà tặng lãng mạn.
* **Xanh bơ / Xanh xám dịu (Sage / Dusty Blue):** Tông xanh ngả lục nhẹ, hợp phong cách tự nhiên (botanical) và tối giản.

### 2. Nguyên tắc phân bổ tỷ lệ màu 60 - 30 - 10
Do ảnh sản phẩm hoa thường rất rực rỡ và đa sắc màu, giao diện app cần ưu tiên sự thoáng đãng để tôn vinh hình ảnh sản phẩm.

#### Màu nền (60%) — Giữ không gian sạch
* **Trắng ngà / Trắng kem (`#FAF9F6` hoặc `#FFFDF9`):** Tạo cảm giác ấm áp, tinh tế và sang trọng hơn trắng tinh (`#FFFFFF`).
* **Xanh băng siêu nhạt (`#F2F6FA`):** Dùng cho nền thẻ sản phẩm (product card) hoặc khu vực phân tách nội dung.

#### Màu chủ đạo (30%) — Xanh pastel cẩm tú cầu
Dùng cho thanh điều hướng (header), tag phân loại, khung nổi bật hoặc biểu tượng (icon).
* **Xanh dương pastel (`#A7C7E7` hoặc `#B6D0E2`):** Sắc xanh chủ đạo mang lại cảm giác tin cậy, dịu mắt.
* **Xanh lam ánh tím nhẹ (`#B8C4E6`):** Dùng làm màu chuyển sắc (gradient) nhẹ hoặc điểm nhấn phụ trợ.

#### Màu nhấn & chữ (10%) — Tạo tương phản và thúc đẩy thao tác
| Nhóm màu nhấn | Mã màu (HEX) | Vai trò trong UI | Cảm xúc thương hiệu |
| :--- | :--- | :--- | :--- |
| **Xanh Navy / Xanh than** | `#2C3E50` / `#1E3A5F` | Nút "Đặt hoa", "Thanh toán", tiêu đề chính. | Thanh lịch, chuyên nghiệp, độ tương phản cao. |
| **Xanh rêu đậm (Deep Sage)** | `#4A6B5D` | Nút CTA, biểu tượng giao hàng, trạng thái còn hàng. | Tự nhiên, gần gũi với cây lá. |
| **Hồng đào / San hô nhạt** | `#F4A4A4` / `#E88D72` | Nhãn giảm giá (Sale), icon yêu thích (Tim), quà tặng. | Ngọt ngào, nữ tính, gợi không khí lễ kỷ niệm. |
| **Xám than ấm** | `#333740` | Nội dung mô tả hoa, giá tiền, thông tin phụ. | Giảm mỏi mắt hơn so với chữ đen tuyền. |

### 3. Hai hướng phối màu thực tế cho app
* **Phong cách Tinh tế & Nghệ thuật (Boutique):** Nền trắng kem (`#FAF9F6`) + Xanh cẩm tú cầu (`#A7C7E7`) + Nút bấm Xanh Navy (`#243B53`). Giúp mọi tông hoa hiển thị chuẩn màu nhất.
* **Phong cách Ngọt ngào & Trẻ trung (Gift & Daily):** Nền trắng sáng (`#FFFFFF`) + Xanh pastel (`#B6D0E2`) + Điểm nhấn Hồng san hô (`#E88D72`) và Xanh lá bơ (`#A8C69F`). Phù hợp cho app đặt hoa sinh nhật, chúc mừng hàng ngày.

---

## Phần 2: Quy Chuẩn Kiểu Chữ Tiếng Việt (Typography System)

Tất cả các font được đề xuất đều miễn phí trên **Google Fonts** và hỗ trợ **100% dấu tiếng Việt**, đảm bảo không bị lỗi font hay dính dấu trên màn hình nhỏ.

### 1. Cặp font Tinh tế & Nghệ thuật (Hợp phong cách Boutique)
Kết hợp giữa font có chân (Serif) thanh lịch và font không chân (Sans-serif) hiện đại.
* **Font Tiêu đề (Tên bó hoa, Banner):** `Playfair Display` hoặc `Lora`. Nét thanh nét đậm mềm mại, dấu tiếng Việt tinh xảo.
* **Font Nội dung (Mô tả, Giá tiền, Nút bấm):** `Plus Jakarta Sans` hoặc `Be Vietnam Pro`. Khoảng cách chữ thoáng, hiển thị con số và giá tiền rõ nét.

### 2. Cặp font Hiện đại & Trẻ trung (Hợp phong cách Quà tặng hàng ngày)
Sử dụng hoàn toàn font không chân (Sans-serif) thân thiện, năng động.
* **Font Tiêu đề:** `Quicksand` hoặc `Nunito`. Đầu nét chữ bo tròn nhẹ nhàng, ngọt ngào.
* **Font Nội dung:** `Inter` hoặc `Be Vietnam Pro` (được tối ưu riêng cho dấu mũ tiếng Việt như ấ, ệ, ộ).

### 3. Bảng cấu hình kích thước chữ (Typography Scale — Mobile)

| Thành phần UI | Font gợi ý | Độ đậm (Weight) | Kích thước | Line-height |
| :--- | :--- | :--- | :--- | :--- |
| **Tên danh mục / Banner chính** | Playfair Display / Quicksand | Bold (700) | 24px – 28px | 1.25 – 1.3 |
| **Tên sản phẩm (Card hoa)** | Lora / Plus Jakarta Sans | SemiBold (600) | 16px – 18px | 1.35 |
| **Giá tiền** | Plus Jakarta Sans / Be Vietnam Pro | Bold (700) | 15px – 16px | 1.2 |
| **Mô tả chi tiết bó hoa** | Be Vietnam Pro / Inter | Regular (400) | 14px | 1.45 – 1.5 |
| **Nhãn nút bấm (CTA) & Tag** | Plus Jakarta Sans / Be Vietnam Pro | SemiBold (600) | 13px – 14px | 1.2 |

### 4. Lưu ý hiển thị chữ trên nền pastel
* **Độ tương phản:** Tránh đặt chữ màu trắng (`#FFFFFF`) trực tiếp lên nền xanh pastel (`#A7C7E7`). Nên dùng chữ màu **Xanh Navy đậm (`#243B53`)** hoặc **Xám than (`#333740`)** để đảm bảo tiêu chuẩn dễ đọc (WCAG).
* **Khoảng cách dòng:** Luôn giữ `line-height` từ **1.4 đến 1.5** cho đoạn văn bản tiếng Việt để các dấu thanh điệu không chạm vào nhau.

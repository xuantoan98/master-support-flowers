# Báo cáo bảo mật — Flower Orders (app quản lý đơn hoa offline)

- **Ngày rà soát:** 2026-11-19
- **Phạm vi:** branch `develop` (gồm cả thay đổi chưa commit): `lib/`, `android/`, `ios/`, `pubspec.yaml`, các file cấu hình được git track.
- **Cách làm:** đọc mã nguồn thủ công (static review). Chưa chạy pentest động trên thiết bị, chưa quét CVE dependency tự động.

## Tóm tắt

App chạy **offline hoàn toàn**: không gọi mạng, không backend, không đăng nhập. Vì vậy rủi ro chính **không** đến từ tấn công qua mạng. Rủi ro nằm ở:

1. **Dữ liệu nhạy cảm lưu trên máy** (tên/SĐT/địa chỉ khách, công nợ, số tài khoản ngân hàng, ảnh QR thanh toán) — không mã hoá, không khoá app, có thể bị sao lưu ra ngoài.
2. **Rác từ template cũ** (Firebase key, mã ads/IAP/Adjust) đang nằm trong git.
3. **Cấu hình build release** chưa an toàn (rơi về debug key, package name của template).

Phần đã làm tốt:
- Toàn bộ truy vấn SQL dùng tham số `?` / `whereArgs`, **không có SQL injection** (`lib/flower/data/order_repository.dart`).
- Tên file ảnh sinh bằng `Random.secure()` và có whitelist đuôi file.
- `PaymentQrStore.delete` có kiểm tra `p.isWithin`, nên không xoá được file nằm ngoài thư mục QR.
- Thông báo nhắc đơn và Live Activity chỉ hiện **mã đơn + giờ giao**, không lộ tên/SĐT khách trên màn hình khoá.
- Receiver của `flutter_local_notifications` để `exported="false"`.
- Bản release Android không có quyền `INTERNET`, vì quyền này chỉ khai báo trong manifest `debug`.

| # | Mức độ | Vấn đề |
|---|---|---|
| 1 | 🔴 Critical | Bản release có thể bị ký bằng **debug keystore** |
| 2 | 🔴 High | Firebase API key / OAuth client ID của template đang bị commit vào git |
| 3 | 🔴 High | Android cho phép backup (`allowBackup` mặc định true), dữ liệu khách và ngân hàng có thể bị trích xuất |
| 4 | 🔴 High | Ảnh QR thanh toán có thể bị tráo, không đối chiếu với số tài khoản |
| 5 | 🟠 Medium | Database SQLite và ảnh lưu **không mã hoá** |
| 6 | 🟠 Medium | Không có khoá app (PIN/sinh trắc học) |
| 7 | 🟠 Medium | Dữ liệu lộ qua ảnh chụp màn hình và ảnh xem trước của trình chuyển app |
| 8 | 🟠 Medium | Mã template chết (ads, IAP, Adjust, Remote Config) vẫn nằm trong `lib/` |
| 9 | 🟡 Low | `applicationId`/`namespace` vẫn là của template `com.vtn.global.base.flutter` |
| 10 | 🟡 Low | `NSLocalNetworkUsageDescription` ("for debugging") còn trong Info.plist release |
| 11 | 🟡 Low | Lưu đường dẫn ảnh **tuyệt đối** vào DB (QR, catalog) |
| 12 | 🟡 Low | `OrderMediaStore.fileFor` không kiểm tra path traversal |
| 13 | 🟡 Low | Ảnh QR chọn từ thư viện không giới hạn kích thước, chỉ kiểm tra đuôi file |
| 14 | 🟡 Low | File hoá đơn tạm do share_plus tạo không được dọn |
| 15 | ⚪ Info | Chưa bật obfuscate Dart; có file zip/thư mục lạ chưa track |

---

## 🔴 1. Bản release có thể bị ký bằng debug keystore — CRITICAL

**Vị trí:** `android/app/build.gradle`, khối `buildTypes.release`

```groovy
if (keystoreProperties['storeFile'] != null) {
    signingConfig signingConfigs.release
} else {
    signingConfig signingConfigs.debug   // ⚠️
}
```

**Rủi ro:** Nếu máy build/CI không có `key.properties`, APK/AAB release vẫn build thành công nhưng được ký bằng debug key, là khoá công khai và giống nhau trên mọi máy dev. Hậu quả:
- Bất kỳ ai cũng có thể ký một bản APK sửa đổi trùng chữ ký và cài đè lên bản thật (sideload), từ đó đọc được toàn bộ DB của người dùng.
- Nếu lỡ phát hành bản ký debug thì không thể cập nhật bằng key thật về sau.

**Cách sửa:** cho build release **fail** khi thiếu keystore.

```groovy
buildTypes {
    release {
        if (keystoreProperties['storeFile'] == null) {
            throw new GradleException("Thiếu android/key.properties — không build release bằng debug key")
        }
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

Nên dùng thêm **Play App Signing**.

---

## 🔴 2. Firebase API key / OAuth client ID bị commit — HIGH

**Vị trí (đang được git track, có từ commit `efb27b9`):**
- `android/app/src/google-services.json`, `android/app/src/dev/…`, `android/app/src/prod/…`
- `ios/Runner/GoogleService-Info.plist`, `ios/Runner/dev/…`, `ios/Runner/prod/…`

Các file này chứa `api_key` (`AIzaSy…`), `client_id` OAuth, project ID `fir-for-base-flutter` và `vtn-flutter-base`. Bundle ID ghi trong đó (`com.base.flutter.bloc`) cũng không khớp app hiện tại. **App flower không dùng Firebase**: `pubspec.yaml` không có package `firebase_*`.

**Rủi ro:** Firebase key không phải secret tuyệt đối, nhưng nếu project Firebase của template có Firestore/Storage/RTDB với rules lỏng, hoặc key không giới hạn API, người khác có thể dùng key đó để ghi/đọc dữ liệu, tiêu quota hoặc gửi spam qua FCM. Vì các file nằm trong git history, xoá file ở commit mới **không đủ**.

**Cách sửa:**
1. Xoá các file trên khỏi repo và thêm vào `.gitignore`:
   ```gitignore
   **/google-services.json
   **/GoogleService-Info.plist
   ```
2. Báo cho chủ project Firebase của template để **rotate hoặc giới hạn API key** (Google Cloud Console → Credentials → Application restrictions + API restrictions) và kiểm tra Security Rules.
3. Nếu repo đã hoặc sẽ public: dọn history bằng `git filter-repo --path <file> --invert-paths`.
4. Khi app thật cần Firebase, tạo project riêng và inject config qua CI secret, không commit.

---

## 🔴 3. Android cho phép backup dữ liệu nhạy cảm — HIGH

**Vị trí:** `android/app/src/main/AndroidManifest.xml`. Thẻ `<application>` không khai báo `android:allowBackup`, nên giá trị mặc định là `true`.

**Dữ liệu có thể bị lộ:** `flower_orders.db` (tên, SĐT, địa chỉ khách, lịch sử thanh toán, công nợ, số tài khoản và chủ tài khoản ngân hàng), thư mục `order_media/`, `payment_qr/`.

**Rủi ro:** Dữ liệu có thể bị lấy ra qua `adb backup` (trên máy cũ hoặc máy đã bật USB debugging), Auto Backup lên Google Drive, hoặc chuyển thiết bị (device-to-device). Tương tự trên iOS: `getDatabasesPath()` và `getApplicationDocumentsDirectory()` nằm trong `Documents/`, mặc định được đưa vào iCloud/iTunes backup.

**Cách sửa:**

`AndroidManifest.xml`:
```xml
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    android:dataExtractionRules="@xml/data_extraction_rules"
    ...>
```

`android/app/src/main/res/xml/data_extraction_rules.xml` (Android 12+):
```xml
<data-extraction-rules>
    <cloud-backup><exclude domain="root" path="."/><exclude domain="database" path="."/><exclude domain="file" path="."/></cloud-backup>
    <device-transfer><exclude domain="root" path="."/><exclude domain="database" path="."/><exclude domain="file" path="."/></device-transfer>
</data-extraction-rules>
```

iOS: đặt `NSURLIsExcludedFromBackupKey` cho DB và các thư mục ảnh. Cách khác là lưu vào `Library/Application Support` qua `getApplicationSupportDirectory()` rồi exclude.

> Lưu ý nghiệp vụ: tắt backup đồng nghĩa với việc mất máy là mất dữ liệu. Nên làm thêm tính năng **xuất/nhập backup có mật khẩu** (file mã hoá AES-GCM, khoá dẫn xuất từ mật khẩu bằng PBKDF2/Argon2) để chủ shop tự chủ động sao lưu.

---

## 🔴 4. Ảnh QR thanh toán có thể bị tráo — HIGH (rủi ro tài chính)

**Vị trí:** `lib/flower/presentation/shop_profile_screen.dart` (`pickQr`), `lib/flower/presentation/invoice_screen.dart` (hiển thị và chia sẻ QR), `lib/flower/data/payment_qr_store.dart`.

**Mô tả:** Hồ sơ shop lưu riêng `bank_bin`, `account_number`, `account_holder` (dạng text) và một **ảnh QR bất kỳ** chọn từ thư viện. Hoá đơn gửi cho khách in cả hai, nhưng app **không kiểm tra** ảnh QR có trỏ đúng số tài khoản đã nhập hay không.

**Kịch bản:** Nhân viên, người mượn máy, hoặc ai đó gửi ảnh QR "mới" qua Zalo đổi ảnh QR sang tài khoản khác. Khách quét QR trên hoá đơn và chuyển tiền sai người, trong khi dòng chữ STK trên hoá đơn vẫn đúng nên khó phát hiện. Không có khoá app (mục 6) nên việc đổi QR không cần xác thực.

**Cách sửa (chọn một hoặc kết hợp):**
1. **Tốt nhất:** bỏ upload ảnh, tự **sinh VietQR (chuẩn EMVCo/NAPAS)** từ `bankBin + accountNumber`, kèm số tiền còn nợ và nội dung `DH{orderId}`. Khi đó QR luôn khớp STK, khách cũng không phải tự gõ số tiền. Có thể render bằng `qr_flutter`, không cần mạng.
2. Nếu vẫn cho upload: decode ảnh QR (ví dụ `mobile_scanner.analyzeImage`), parse payload EMVCo và **so sánh** BIN + số tài khoản với hồ sơ. Không khớp thì từ chối lưu.
3. Yêu cầu xác thực (PIN/sinh trắc) trước khi sửa hồ sơ ngân hàng hoặc QR, và hiển thị cảnh báo "Thông tin nhận tiền vừa thay đổi" trên màn hình chính trong vài ngày sau đó.

---

## 🟠 5. Database và ảnh không mã hoá — MEDIUM

**Vị trí:** `lib/flower/data/order_repository.dart` (`openDatabase`, sqflite thường), các store ảnh.

**Rủi ro:** Trên máy đã root/jailbreak, qua backup (mục 3), hoặc qua công cụ forensic trên máy không khoá, kẻ tấn công đọc được ngay toàn bộ danh sách khách hàng và doanh thu dưới dạng plain text. Dữ liệu này là dữ liệu cá nhân theo **Nghị định 13/2023/NĐ-CP**, nên chủ shop có nghĩa vụ bảo vệ.

**Cách sửa:**
- Chuyển sang `sqflite_sqlcipher` (API gần như giống `sqflite`) và mở DB bằng password.
- Sinh khoá 256-bit ngẫu nhiên **một lần**, lưu bằng `flutter_secure_storage`:
  - iOS: Keychain, `accessibility: first_unlock_this_device`, không đồng bộ iCloud.
  - Android: Keystore (`encryptedSharedPreferences: true`).
- Viết migration: mở DB cũ, `ATTACH` DB mã hoá, `sqlcipher_export`, rồi xoá file cũ.
- iOS: đặt Data Protection `NSFileProtectionComplete` cho thư mục ảnh (entitlement `com.apple.developer.default-data-protection`). Lưu ý background notification không cần đọc DB nên dùng được.

---

## 🟠 6. Không có khoá app — MEDIUM

**Mô tả:** Mở app là vào thẳng được danh sách khách, công nợ, hồ sơ ngân hàng. Điện thoại của tiệm hoa thường được dùng chung giữa nhiều nhân viên hoặc để trên quầy.

**Cách sửa:**
- Thêm tuỳ chọn khoá bằng `local_auth` (Face ID / vân tay / PIN thiết bị), bật mặc định cho:
  - Mở app sau khi ở background quá N phút.
  - Vào **Hồ sơ shop** (sửa STK/QR), **xoá đơn**, **sửa thanh toán**.
- iOS: thêm `NSFaceIDUsageDescription` vào `Info.plist`.

---

## 🟠 7. Lộ dữ liệu qua ảnh chụp màn hình / app switcher — MEDIUM

**Mô tả:** Khi chuyển app, hệ điều hành lưu snapshot màn hình (danh sách khách, công nợ). Trên Android, app khác có quyền chụp màn hình hoặc ghi màn hình đều thấy được nội dung.

**Cách sửa:**
- Android: bật `FLAG_SECURE` (ít nhất ở màn hồ sơ shop và danh sách khách), qua `MainActivity` hoặc package `flutter_windowmanager_plus`.
  > Lưu ý: `FLAG_SECURE` sẽ chặn cả việc chủ shop tự chụp màn hình. Nên để thành tuỳ chọn, vì app đã có nút chia sẻ hoá đơn thay thế.
- iOS: trong `AppDelegate`, phủ một view che (blur/logo) ở `applicationWillResignActive` và gỡ ở `applicationDidBecomeActive`.

---

## 🟠 8. Mã template chết vẫn nằm trong repo — MEDIUM

**Vị trí:** `lib/src/**`, `lib/module/**` (admob, adjust, iap, remote_config, isolate…), `lib/app_initializer.dart`, `lib/flavors.dart`, `ios/Runner/Ads/**`, các rule ads/facebook/tensorflow trong `android/app/proguard-rules.pro`, `android/app/flavorizr.gradle`.

**Rủi ro:**
- Các file này import package không có trong `pubspec.yaml`, nên hiện **không được biên dịch**. Nhưng chỉ cần ai đó `import` nhầm hoặc thêm lại dependency là SDK quảng cáo/tracking (Adjust, AdMob, Facebook) sẽ vào app và **thu thập dữ liệu người dùng** mà chính sách quyền riêng tư không khai báo. Đây là rủi ro về compliance trên App Store/Play Store.
- Làm tăng bề mặt review: tool quét secret báo nhầm, người review dễ bỏ sót.

**Cách sửa:** xoá toàn bộ thư mục và file trên, dọn `proguard-rules.pro` chỉ giữ rule cần thiết, rồi chạy `flutter analyze` để đảm bảo sạch.

---

## 🟡 9. `applicationId` / `namespace` vẫn là của template — LOW

**Vị trí:** `android/app/build.gradle`: `applicationId "com.vtn.global.base.flutter"`. Ngoài ra còn 2 `MainActivity.kt` ở 2 package khác nhau.

**Rủi ro:** Trùng ID với các app khác dựng từ cùng template, dễ bị cài đè hoặc nhầm khi phát hành. Không thể publish lên Play nếu ID đã có người dùng.

**Cách sửa:** đổi sang ID riêng (ví dụ `vn.<company>.flowerorders`), xoá `MainActivity.kt` thừa (`dev/feichtinger/...`), đồng bộ bundle ID bên iOS.

---

## 🟡 10. Quyền Local Network còn trong Info.plist release — LOW

**Vị trí:** `ios/Runner/Info.plist`, key `NSLocalNetworkUsageDescription` với nội dung "…for debugging".

**Rủi ro:** App offline nhưng lại khai báo quyền mạng nội bộ. Reviewer của Apple có thể từ chối, và người dùng thấy đáng ngờ.

**Cách sửa:** chỉ thêm key này cho cấu hình Debug (Flutter tự xử lý khi chạy debug), hoặc xoá khỏi `Info.plist` chính.

---

## 🟡 11. Lưu đường dẫn ảnh tuyệt đối vào DB — LOW

**Vị trí:** `PaymentQrStore.save` và `CatalogImageStore.save` trả về `target.path` (đường dẫn tuyệt đối) và lưu vào `qr_image_path` / `image_path`. Riêng `OrderMediaStore` đã lưu đường dẫn tương đối, là cách đúng.

**Rủi ro:** Trên iOS, đường dẫn container (`/var/mobile/Containers/Data/Application/<UUID>/`) **thay đổi** sau khi cập nhật hoặc khôi phục app. Khi đó QR "biến mất", kiểm tra `p.isWithin` khi xoá bị sai, và file cũ bị bỏ lại. Đây chủ yếu là lỗi tin cậy, nhưng có ảnh hưởng tới tính toàn vẹn của chức năng thanh toán.

**Cách sửa:** chỉ lưu đường dẫn tương đối (`payment_qr/<file>`, `catalog_images/<file>`), ghép với `getApplicationDocumentsDirectory()` khi đọc, và viết migration chuyển các giá trị tuyệt đối cũ sang tương đối.

---

## 🟡 12. `OrderMediaStore.fileFor` không kiểm tra path traversal — LOW

**Vị trí:** `lib/flower/data/order_media_store.dart`

```dart
Future<File> fileFor(OrderMedia media) async {
  final root = await _root();
  return File(p.join(root.path, media.relativePath)); // relativePath lấy từ DB
}
```

**Rủi ro:** Hiện `relativePath` chỉ do app tự tạo nên chưa khai thác được. Nhưng khi có tính năng **nhập backup** (đề xuất ở mục 3), một file backup độc hại có thể chứa `../../...` hoặc đường dẫn tuyệt đối (`p.join` sẽ bỏ qua `root` nếu tham số sau là tuyệt đối). Khi đó hàm `delete()` sẽ xoá file tuỳ ý trong sandbox của app.

**Cách sửa:**
```dart
Future<File> fileFor(OrderMedia media) async {
  final root = await _root();
  final base = p.join(root.path, 'order_media');
  final full = p.normalize(p.join(root.path, media.relativePath));
  if (p.isAbsolute(media.relativePath) || !p.isWithin(base, full)) {
    throw ArgumentError('Đường dẫn ảnh không hợp lệ');
  }
  return File(full);
}
```
Áp dụng tương tự cho `image_path` của catalog.

---

## 🟡 13. Ảnh QR không giới hạn kích thước, chỉ kiểm tra đuôi file — LOW

**Vị trí:** `shop_profile_screen.dart`, chỗ gọi `ImagePicker().pickImage(source: ImageSource.gallery)`. Lệnh này không có `maxWidth`/`imageQuality`, trong khi ảnh đơn và catalog thì có.

**Rủi ro:** Ảnh rất lớn (ví dụ 50MP hoặc PNG nặng) có thể làm app chiếm nhiều bộ nhớ hoặc crash khi render hoá đơn với `pixelRatio: 3`. Việc kiểm tra loại file chỉ dựa trên đuôi, không dựa trên nội dung.

**Cách sửa:** thêm `maxWidth: 1200, imageQuality: 90`; kiểm tra magic bytes (PNG `89 50 4E 47`, JPEG `FF D8 FF`, WebP `RIFF....WEBP`) trước khi lưu; giới hạn dung lượng (ví dụ ≤ 5MB).

---

## 🟡 14. File hoá đơn tạm không được dọn — LOW

**Vị trí:** `invoice_screen.dart`. `XFile.fromData` + `SharePlus` ghi file PNG hoá đơn (có tên, SĐT, địa chỉ khách, QR) vào thư mục cache/tmp.

**Rủi ro:** Các ảnh hoá đơn chứa dữ liệu cá nhân tích tụ trong cache và nằm ngoài phạm vi mã hoá ở mục 5.

**Cách sửa:** tự ghi file vào `getTemporaryDirectory()` với tên ngẫu nhiên, share bằng `XFile(path)`, rồi xoá trong `finally` sau khi share xong (hoặc dọn thư mục khi app khởi động).

---

## ⚪ 15. Thông tin bổ sung — INFO

- **Obfuscate Dart:** build release bằng `flutter build apk|appbundle|ipa --obfuscate --split-debug-info=build/symbols` để gây khó khăn cho việc dịch ngược logic. Không commit thư mục symbols (`.gitignore` đã chặn `app.*.symbols`).
- **File chưa track:** `Best-Flutter-UI-Templates.zip`, `.agents/`, `assets/template/`. Kiểm tra license của template trước khi đưa asset vào app, và không commit file zip (thêm vào `.gitignore`).
- **Quyền `SCHEDULE_EXACT_ALARM`:** Play Store yêu cầu giải trình. Có thể dùng `setAndAllowWhileIdle` (không cần exact) vì nhắc trước 1 giờ không cần chính xác đến giây.
- **Dependency:** nên chạy `flutter pub outdated` định kỳ và bật Dependabot/Renovate cho `pubspec.yaml`.
- **Chính sách quyền riêng tư:** app lưu dữ liệu cá nhân của khách bên thứ ba, nên cần privacy policy khi lên store (bắt buộc với Play Data Safety và App Store Privacy Nutrition Label).

---

## Lộ trình sửa đề xuất

| Ưu tiên | Việc cần làm | Effort |
|---|---|---|
| P0 (trước khi phát hành) | #1 chặn debug signing · #2 xoá Firebase config + rotate key · #3 tắt backup · #9 đổi applicationId | ~0,5 ngày |
| P1 | #4 sinh VietQR từ STK thay vì upload ảnh · #8 xoá mã template chết · #10 · #13 | 1–2 ngày |
| P2 | #5 SQLCipher + secure storage + migration · #6 khoá app `local_auth` · #7 FLAG_SECURE/che snapshot | 2–3 ngày |
| P3 | #11 đường dẫn tương đối · #12 kiểm tra path · #14 dọn file tạm · #15 | ~1 ngày |

# Maclendar

Ứng dụng menu-bar macOS nhỏ giúp xem và tạo sự kiện Google Calendar.

Nội dung ngắn gọn

- Mục tiêu: chạy app từ source, cấu hình OAuth, tạo/sửa sự kiện.

Yêu cầu

- macOS 11 hoặc mới hơn
- Swift toolchain (swift 5.9+/Swift 6.x theo Package.swift)

Cấu hình OAuth (bắt buộc)

**Cho người dùng cuối (chạy từ .dmg):**

1. Tạo Google OAuth Client ID:
   - Vào https://console.cloud.google.com
   - Tạo dự án → Bật **Google Calendar API**
   - **Credentials** → **Create Credentials** → **OAuth Client ID**
   - Application type: **Desktop**
   - Copy **Client ID** và **Client Secret**

2. Tạo file `~/.env` trong home directory:

   ```bash
   cat > ~/.env << EOF
   GOOGLE_CLIENT_ID=<paste_client_id>
   GOOGLE_CLIENT_SECRET=<paste_client_secret>
   EOF
   ```

3. Chạy ứng dụng — nó sẽ tự tìm `~/.env`

**Cho nhà phát triển (chạy từ source):**

- Cách A (khuyến nghị): Tạo file `.env` từ mẫu:

  ```bash
  cp .env.example .env
  # Mở .env và điền Client ID + Secret
  swift build && swift run
  ```

- Cách B: Đặt biến môi trường:
  ```bash
  export GOOGLE_CLIENT_ID="<paste_client_id>"
  export GOOGLE_CLIENT_SECRET="<paste_client_secret>"
  swift run
  ```

**Lưu ý:** `.env` được thêm vào `.gitignore` để tránh lộ khoá.

Cài đặt & chạy

1. Mở terminal và chuyển vào thư mục dự án:

```bash
cd CalendarApp
```

2. Build và chạy:

```bash
swift build
swift run
```

3. (Tùy chọn) Dùng script dev để tự động rebuild khi có thay đổi:

```bash
./dev.sh
```

Sử dụng ứng dụng

- Sau khi chạy, biểu tượng ứng dụng xuất hiện trên menu bar. Click để mở popover.
- Nhấn nút "+" để tạo sự kiện mới; chọn sự kiện để xem/ sửa/ xóa.
- Lưu ý: phần Google Tasks tồn tại ở backend nhưng không hiển thị trên giao diện mặc định.

Debug / Thêm thông tin

- Nếu gặp lỗi "Missing OAuth credentials":
  - Kiểm tra file [.env](.env) hoặc biến môi trường GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET
  - Tham khảo hướng dẫn OAuth phía trên
- Nếu gặp lỗi "invalid_grant" khi login:
  - Kiểm tra Client ID / Secret có đúng không
  - Đảm bảo OAuth redirect URI chính xác (nếu cấu hình trên Google Cloud)
- Các phần chính của mã nguồn:
  - [Sources/CalendarApp/Core/Auth/AuthManager.swift](Sources/CalendarApp/Core/Auth/AuthManager.swift) — quản lý OAuth và token.
  - [Sources/CalendarApp/Core/Networking/CalendarService.swift](Sources/CalendarApp/Core/Networking/CalendarService.swift) — gọi Google Calendar API.
  - [Sources/CalendarApp/Modules/Calendar/Views/CalendarView.swift](Sources/CalendarApp/Modules/Calendar/Views/CalendarView.swift) — UI popover chính.

Đóng góp

- Mở PR cho các thay đổi; giữ secrets ngoài repo.

License

- Không có license mặc định — thêm file LICENSE nếu cần.

# Maclendar

# Maclendar

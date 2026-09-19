# Deploy React Dashboard lên Vercel

## Phạm vi

Vercel host phần `web-react`. Spring Boot, PostgreSQL và EMQX vẫn phải chạy trên máy chủ khác hoặc được đưa ra Internet bằng URL HTTPS an toàn. Trình duyệt mở website Vercel không thể truy cập backend trên `localhost` của máy phát triển.

## Thiết lập từ GitHub

1. Truy cập <https://vercel.com/new> và đăng nhập bằng GitHub.
2. Import repository `SiriusNoPro/DemoIoT_Nhom4`.
3. Đặt **Root Directory** là `web-react`.
4. Vercel sẽ nhận diện framework **Vite** từ `package.json` và `vercel.json`.
5. Trong **Environment Variables**, tạo:

   ```text
   VITE_API_URL=https://<backend-public>/api/v1
   ```

6. Chọn **Deploy**. Nếu thay đổi biến môi trường, redeploy để bản build mới nhận giá trị.

## Build settings

| Mục | Giá trị |
|---|---|
| Framework Preset | Vite |
| Root Directory | `web-react` |
| Install Command | `npm install` |
| Build Command | `npm run build` |
| Output Directory | `dist` |

`vercel.json` đã có rewrite về `index.html`, vì vậy các đường dẫn React như `/logs` không trả về 404 khi tải trực tiếp.

## Yêu cầu đối với backend

- Backend phải có URL `https://...`; trang Vercel dùng HTTPS nên trình duyệt sẽ chặn API HTTP do mixed content.
- Cho phép origin của website Vercel trong `CORS_ALLOWED_ORIGINS`, ví dụ `https://demo-iot-nhom4.vercel.app`.
- Backend phải kết nối được PostgreSQL và EMQX.
- ESP32 vẫn gửi MQTT tới broker mà backend đang dùng. Nếu backend và EMQX chuyển lên cloud, cập nhật broker trong firmware.

## Kiểm tra sau deploy

1. Mở `/` và đăng nhập bằng `operator / Operator@123`.
2. Tải trực tiếp `/logs` để kiểm tra SPA rewrite.
3. Kiểm tra thiết bị ONLINE và dữ liệu DHT22.
4. Bật/tắt LED và xác nhận ACKNOWLEDGED.

Nếu chỉ deploy frontend mà chưa có backend công khai, giao diện vẫn mở nhưng đăng nhập và dữ liệu IoT sẽ không hoạt động.

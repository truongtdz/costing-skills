# Review vòng 1

## Đã kiểm
Đã đọc COSTING.md (ebinventory). Đối chiếu các mục:
- Mục 7: hợp đồng ba trường. Diff thêm `referenceID` có `@JsonIgnore`, JSON vẫn ba trường theo lời khai của dev.
- Mục 8a: cỡ lô 200 đang thử nghiệm, ngưỡng leo thang khoá 5.000.
- Mục 8b: không cắt ngang chứng từ cha theo `ReferenceID`, lô được vượt cỡ.
- Mục 11: 76 test, bảng mã UT_073 – UT_076.

Đã đọc COSTING.md (ebqueue). Đối chiếu các mục:
- Mục 5a: chạy song song được vì lô không cắt ngang chứng từ cha.
- Mục 5b: đóng TaskLog khi đủ `batchTotal` lô. Kèm ba ràng buộc: không đóng sớm, đóng sau commit có tuần tự hoá, trạng thái lỗi nằm ngoài transaction bị rollback.

Đã đọc COSTING.md (ebwebbe). Đối chiếu các mục:
- Mục 1 cùng đoạn mới: store giữ `SUM` header.
- Mục 1a: chỉ tạo TaskLog.
- Mục 2: `ReferenceID` trỏ vào phiếu kho.

Đã đối chiếu thêm `update_InventoryCosting_TVP.sql:35-112` (danh sách header bị `SUM`), dòng 321-352 (lắp ráp) và dòng 400-463 (tổng tiền header).

Test: `JAVA_HOME=jdk-21.0.10.7 ./mvnw test` ở D:\_AppInventory\ebinventory → 76 test, 0 đỏ, BUILD SUCCESS. Chạy `./mvnw` với JAVA_HOME mặc định (JDK 17) thì enforcer chặn, không chạy được.

Diff:
- ebinventory: 10 file. Gồm `CostingResult`, `CostingServiceImpl`, `CostingResultSenderServiceImpl`; javadoc ở `CostingResultMessage`, `CostingResultSenderService`, `DwhRepositoryLedgerRow`; `COSTING.md`; `CostingResultSenderServiceImplTest` (chỉ thêm dòng). `ApplicationProperties` và `application-worker.yml` là thay đổi có sẵn từ trước.
- ebqueue: 8 file. Gồm `MqInternalCustomMessageHandlerInventoryCosting`, `RabbitMQMessageCustomInventoryCosting` (javadoc), `TaskLogRepository`, `TaskLogDetailRepository`, `COSTING.md`. `core-model.jar`, `application-dev.yml`, `application-prod.yml` là thay đổi có sẵn.
- ebwebbe: 4 file. Gồm `AsyncCalculateOWPriceServiceImpl` (bỏ tạo TaskLogDetail, phần comment COSTING_CODE còn nguyên) và `COSTING.md`. `core-model.jar`, `application-dev.yml` là thay đổi có sẵn.

## BLOCKING
- [B1] TaskLog vẫn có thể bị đóng sớm theo một đường khác: màn hình "Tiến trình dữ liệu" tự chuyển TaskLog sang hoàn thành khi mọi TaskLogDetail **đang có** đã xong. Đây đúng là điều 1 mục 5b ebqueue cấm, và trái tiêu chí "không được đóng sớm" trong task.md mục 2.
  - Trước đây ebwebbe tạo sẵn một TaskLogDetail, chỉ xong ở lô cuối, nên màn hình không gây đóng sớm.
  - Nay detail chỉ sinh khi lô tới. Lô 1 xong, lô 2 còn nằm trong queue (5 consumer bận với công ty khác) là đủ để màn hình gửi `update-status/{id}?status=2`.
  - Hệ quả dây chuyền:
    - `closeCostingAsSuccess` không còn khớp `Status IN (Waiting, InProgress)`, nên websocket "Done" không bao giờ được bắn.
    - Một lô sau đó lỗi thì `closeCostingAsFail` cũng không khớp, nên TaskLog **hiển thị hoàn thành dù có lô ghi lỗi**.
  - COSTING.md ebwebbe mục 1a chỉ nói chiều ngược lại (detail thừa làm TaskLog "chưa xong"), không nêu rủi ro này.
  - Bằng chứng:
    - D:\_AppAll\200133ebwebfe\src\main\webapp\app\tien-ich\tien-trinh-du-lieu\tien-trinh-du-lieu.component.ts:297-327 (`taskLogStatusCheck`, nhánh `allCompleted && item.status !== 2` → `updateStatusTaskLogById(item.id, 2)`). Hàm này tự chạy mỗi lần `loadAll` (dòng 272-278) và lặp lại mỗi 180 giây.
    - Cùng logic ở nút bấm: `tien-trinh-du-lieu.component.ts:652-682`.
    - Phía BE: D:\_AppAll\200133ebwebbe\src\main\java\vn\softdreams\ebweb\service\impl\TaskLogServiceImpl.java:362-363 (`detailCount == details.size()` → `updateStatus(2, ...)`).
    - Điều kiện đóng: D:\_AppAll\200133ebqueue\src\main\java\ebqueue\repository\TaskLogRepository.java, `closeCostingAsSuccess` / `closeCostingAsFail`, `tsl.Status IN (?4, ?5)`.
  - Cách sửa có thể phải chạm ebwebfe, repo không có trong task.md. Cần người dùng quyết phạm vi.
  - Checklist: 4 (mục 5b.1 ebqueue), 5 (còn đường khác tới cùng lỗi), 10 (COSTING.md ebwebbe 1a chưa mô tả đúng hệ thống).

## NON-BLOCKING
- [N1] Comment trong `application-dev.yml` và `application-prod.yml` của ebqueue (khối `rabbitmqinventorycosting`) vẫn ghi "Xử lý tuần tự một lô tại một thời điểm. Nhiều luồng song song sẽ … sinh deadlock, và làm lô mang cờ kết thúc đóng tiến trình…". Comment này mâu thuẫn với mục 5a/5b mới, và dev đang đặt `consumers: 5`. Hai file này được task.md liệt kê là thay đổi có sẵn; không xác định được ai thêm comment. Bằng chứng: `git -C D:/_AppAll/200133ebqueue diff cb28526 -- src/main/resources`.
- [N2] Hành vi "dòng kết quả không có `ReferenceID` được coi là một chứng từ riêng" (COSTING.md ebinventory 8b, nhánh `result.referenceID() == null` trong `splitByParentDocument`) không có test. Dữ liệu của UT_073 – UT_076 đều có `ReferenceID`. Checklist 16.
- [N3] `@JsonIgnore` trên `CostingResult.referenceID` chưa có test tự động. COSTING.md mục 7 và work.md đã tự ghi nhận; nếu annotation mất thì hợp đồng ba trường bị đổi mà bộ test không đỏ.
- [N4] `registerBatch` hoặc bước kiểm `batchIndex`/`batchTotal` ném lỗi thì bản tin bị nack vào DLQ, không có lệnh đóng TaskLog. TaskLog treo tới khi màn hình đánh lỗi do quá 6 giờ. Bằng chứng: `MqInternalCustomMessageHandlerInventoryCosting.handleMessage` (khối kiểm lô và `registerBatch` nằm ngoài try), `QueueListenerAppInternalInventoryCosting.onMessage` (catch → `basicNack(..., false, false)`). Dev đã nêu ở Lưu ý 2.

## Phản biện vòng trước (từ vòng 2)
Không áp dụng (vòng 1).

## Kiểm lời khai (mục C)
- Các dòng "Đã đọc COSTING.md":
  - Chế độ rule: ebinventory mục 7, 8 khớp nội dung gốc ở base; ebqueue mục 5 khớp nội dung cũ trong diff; ebwebbe mục 1, 2 khớp.
  - Chế độ code: 8b, 7, 11, 5a, 5b, 1a khớp. Lời khai gán "không chứng từ nào lớn hơn cỡ lô thì không lô nào vượt" cho 8a là hơi lệch, ý này nằm ở 8b, nhưng không sai nội dung.
  - tests.md: 8b, 8a, 7, 5, 11, 5b, 1a khớp.
- Có đủ dòng "Đã cập nhật COSTING.md" cho cả ba repo. Nội dung COSTING.md mới khớp code mới. Phần sai sót nằm ở B1.
- Test: không con số kỳ vọng cũ nào bị đổi (diff test chỉ có dòng thêm). 76/76 xanh, khớp lời khai.

## Không chắc
- `@JsonIgnore` (`com.fasterxml.jackson.annotation`) trên thành phần record có thật sự bị Jackson 3 bỏ qua khi serialize hay không. Tôi chưa tự kiểm, chỉ có lời khai của dev. Cần một test serialize bằng `JacksonJsonMessageConverter`.
- ebqueue có biên dịch được hay không. Tôi không chạy `compile` vì vai reviewer chỉ được chạy `./mvnw test`; repo không có `src/test`.
- `UPDATE` có điều kiện trên TaskLog đóng đúng một lần khi hai consumer chạy sát nhau. Điều này đúng với READ COMMITTED có khoá; nếu DB bật RCSI thì nên kiểm thực tế bằng TC-M4. Hành vi của `COUNT(DISTINCT Info)` trên `nvarchar(max)` cũng chưa chạy trên DB thật.
- Nếu ebinventory chạy lại cả lệnh tính giá trên cùng TaskLog (bản tin lệnh bị giao lại sau khi đã gửi một phần lô) và `batchTotal` khác lần đầu, `COUNT(DISTINCT Info)` có thể cộng lẫn mã lô của hai lần chạy. Chưa xác định được bản tin lệnh có thể bị giao lại trong thực tế hay không.

VERDICT: FAIL

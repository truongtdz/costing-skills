# Review vòng 2

## Đã kiểm
Đã đọc COSTING.md (ebinventory). Đối chiếu các mục:
- Mục 7: JSON gửi đi đúng ba trường. `referenceID` có `@JsonIgnore`, có UT_078 chặn.
- Mục 8a: cỡ lô 200 là giá trị thử nghiệm. Ngưỡng leo thang khoá là 5.000.
- Mục 8b: chia lô theo `ReferenceID`, không cắt ngang chứng từ, lô được vượt cỡ. Dòng không có `ReferenceID` thì tính là một chứng từ riêng. Kỳ rỗng vẫn gửi một bản tin với `batchTotal = 1`.
- Mục 11: 78 test, bảng mã UT_073 – UT_078.

Đã đọc COSTING.md (ebqueue). Đối chiếu các mục:
- Mục 5: một bản tin là một transaction, chạy nhiều consumer.
- Mục 5a: chạy song song chỉ an toàn khi lô không cắt chứng từ cha.
- Mục 5b: bốn điều. (1) Đếm theo `batchTotal`. (2) Đóng sau khi commit và có tuần tự hoá. (3) Trạng thái lỗi nằm ngoài transaction bị rollback. (4) Có đủ `batchTotal` detail ngay từ lô đầu tiên, dùng `UPDLOCK`. Đoạn "Cách hiện thực" khớp thứ tự trong code `MqInternalCustomMessageHandlerInventoryCosting.java:141-260`.

Đã đọc COSTING.md (ebwebbe). Đối chiếu các mục:
- Mục 1: store giữ cách `SUM` cho header.
- Mục 1a: chỉ tạo TaskLog. Có ghi rủi ro đóng sớm qua `TaskLogServiceImpl` và màn hình ebwebfe.

Test: `JAVA_HOME=jdk-21.0.10.7 ./mvnw test` ở D:\_AppInventory\ebinventory → 78 test, 0 đỏ, BUILD SUCCESS. Với JDK mặc định thì enforcer chặn, không chạy được.

Diff:
- ebinventory: 10 file.
  - Thay đổi của task: `CostingResult`, `CostingServiceImpl`, `CostingResultSenderServiceImpl`, javadoc ở 3 file, `COSTING.md`, `CostingResultSenderServiceImplTest` (chỉ thêm dòng, không đổi con số kỳ vọng cũ nào).
  - Có sẵn từ trước: `ApplicationProperties`, `application-worker.yml`.
- ebqueue: 8 file.
  - Thay đổi của task: handler, `RabbitMQMessageCustomInventoryCosting` (javadoc), `TaskLogRepository`, `TaskLogDetailRepository`, `COSTING.md`.
  - Có sẵn từ trước: `core-model.jar`, `application-dev.yml`, `application-prod.yml`.
- ebwebbe: 4 file.
  - Thay đổi của task: `AsyncCalculateOWPriceServiceImpl` (bỏ tạo TaskLogDetail, phần comment `COSTING_CODE` còn nguyên), `COSTING.md`.
  - Có sẵn từ trước: `core-model.jar`, `application-dev.yml`.
- ebwebfe: không có thay đổi của task. Trong working tree chỉ có `app-routing.module.ts` sửa từ 08/10, trước task.

Kiểm thêm:
- `Constants$StatusTask` trong `libs/core-model.jar` (javap): Waiting=0, InProgress=1, Success=2, Fail=3.
- DDL `TaskLogDetail`: `Exception` và `Info` đều là nvarchar(max). `TaskLog.Description` là nvarchar(512).
- `TransactionTemplate` dùng `transactionManager` @Primary (`DatabaseConfiguration.java:170-174`). Cùng EMF với `ebqueue.repository` (`DatabaseConfiguration.java:29`).
- Cả hai interface repository đều có `@Transactional`.
- `new CostingResult(` chỉ có ở một chỗ trong main (`CostingServiceImpl.java:199`), dùng 4 tham số.

## BLOCKING
Không có

## NON-BLOCKING
- [N1] Comment trong code ebwebbe đã lỗi thời so với phương án A. Comment ghi "ebqueue tạo một TaskLogDetail cho mỗi lô nhận được", nhưng thực tế ebqueue tạo đủ `batchTotal` detail ngay ở lô đầu. Bằng chứng: D:\_AppAll\200133ebwebbe\src\main\java\vn\softdreams\ebweb\service\impl\AsyncCalculateOWPriceServiceImpl.java:785-786, đối chiếu COSTING.md ebwebbe mục 1a.
- [N2] (giữ từ N1 vòng 1) Comment trong khối `rabbitmqinventorycosting` vẫn ghi "Xử lý tuần tự một lô…", mâu thuẫn mục 5a ebqueue.
  - Trong dev đang đặt `consumers: 5`, trong prod đang đặt `1`.
  - Theo task.md đây là thay đổi có sẵn, người dùng chưa trả lời, nên không chấm lỗi dev.
  - Bằng chứng: `git -C D:/_AppAll/200133ebqueue diff cb28526 -- src/main/resources/config/`.
- [N3] COSTING.md ebqueue dòng 106 dẫn tới `.claude/work/costing/20261016-lo-theo-chung-tu-cha/tests.md`. File này nằm ngoài repo và là tài liệu tạm của task, nên người đọc repo sau này sẽ không tìm thấy kịch bản TC-M2 – TC-M6.
- [N4] Constructor 3 tham số `CostingResult(String, int, BigDecimal)` (D:\_AppInventory\ebinventory\src\main\java\vn\softdreams\ebinventory\domain\dto\CostingResult.java:28) nằm trong code main, gán `referenceID = null`.
  - Hiện chỉ test dùng tới.
  - Nếu sau này code main dùng nó thì mỗi dòng bị coi là một chứng từ riêng, chứng từ cha có thể bị cắt mà không test nào đỏ: UT_073 – UT_077 chỉ đi qua `calculateByGroup`.
- [N5] Kịch bản TC-M1 trong tests.md dùng cột `TotalAmount`/`Amount` mà test-writer tự ghi là chưa kiểm. Người khác muốn chạy lại phải tự tra store trước. Checklist 17.

## Phản biện vòng trước (từ vòng 2)
- [B1 vòng 1] Đã sửa đúng.
  - `createMissingBatches` (`MqInternalCustomMessageHandlerInventoryCosting.java:165-180`) chạy trong `transactionTemplate.execute`. Nó khoá dòng TaskLog bằng `lockCostingTask` (`TaskLogRepository.java:70-77`, `WITH (UPDLOCK, ROWLOCK)`), rồi tạo đủ mã lô `1..batchTotal` còn thiếu ở trạng thái Waiting.
  - Lúc chưa có detail nào, hai đường tự đóng chỉ đánh lỗi khi quá 6 giờ, không đóng hoàn thành: `TaskLogServiceImpl.java:333-338`, `tien-trinh-du-lieu.component.ts:310-316`.
  - Khi đã có detail ở trạng thái 0/1 thì nhánh đóng hoàn thành không chạy: `TaskLogServiceImpl.java:345-347,362`, `component.ts:317-322`.
  - COSTING.md ebqueue 5b điều 4 và ebwebbe 1a đã mô tả đúng.
- [N1 vòng 1] Giữ nguyên là NON-BLOCKING (N2 ở trên). Dev bỏ qua đúng theo task.md.
- [N2 vòng 1] Đã sửa: có UT_077. Lời khai cài lỗi khớp với COSTING.md mục 11.
- [N3 vòng 1] Đã sửa: có UT_078. COSTING.md mục 7 đã cập nhật.
- [N4 vòng 1] Đã sửa: có `failTaskWithoutBatch` (`:186-206`), được gọi ở bước kiểm lô và khi `registerBatch` lỗi, trước khi ném lỗi.
- Mục "Không chắc" về `@JsonIgnore` dưới Jackson 3 vòng 1: đã giải quyết bằng UT_078 (xanh trong lần chạy của tôi).

## Kiểm lời khai (mục C)
- Các dòng "Đã đọc COSTING.md" vòng 2 của dev khớp nội dung file. Đó là ebqueue 5b (bốn điều, mã lô ở `Info`), ebwebbe 1a, ebinventory 7, 8b, 11.
- tests.md vòng 2 dẫn 8b, 7, 11, 5b, 1a, cũng khớp.
- Đủ dòng "Đã cập nhật COSTING.md" cho cả ba repo. Nội dung COSTING.md mới khớp code, và các ý cũ "cấm >1 consumer", "đóng theo `messageFinal`", "72/76 test" đã bị xoá.
- Lời khai "78 test xanh, không sửa test" khớp lần chạy của tôi và diff test.
- Lời khai javap `StatusTask` khớp lần tôi tự kiểm.

## Không chắc
- ebqueue có biên dịch được hay không. Dev khai `./mvnw -o -q compile` (JDK 11) exit 0. Tôi không chạy compile vì vai reviewer chỉ được chạy `./mvnw test`, và repo không có `src/test`.
- Chạy lại cùng TaskLog với `batchTotal` khác lần đầu: `COUNT(DISTINCT Info)` có thể cộng lẫn mã lô của hai lần chạy và đóng sớm (dev đã nêu ở Lưu ý 3). Cần xác định bản tin lệnh tính giá có thể bị giao lại sau khi ebinventory đã gửi một phần lô hay không.
- Lô đầu của TaskLog lớn tạo khoảng 1.000 dòng INSERT, mỗi dòng một lệnh, trong lúc giữ `UPDLOCK`. Các consumer khác của cùng TaskLog phải chờ. Chưa đo trên DB thật, cần kiểm khi chạy kiểm thử tải.
- Hành vi trên DB thật của `UPDATE` có điều kiện và `COUNT(DISTINCT)` trên nvarchar(max), nhất là khi DB bật RCSI. Cần chạy TC-M3, TC-M4, TC-M6.

VERDICT: PASS

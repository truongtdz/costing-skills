## Vòng 1 — chế độ rule
Đã đọc COSTING.md (ebinventory) — áp dụng mục 8: chia lô kết quả, `result-batch-size` có ràng buộc ngưỡng leo thang khoá 5.000; mục 7: hợp đồng ba trường với ebqueue (giữ nguyên, ReferenceID không gửi đi).
Đã đọc COSTING.md (ebqueue) — áp dụng mục 5: một bản tin một lô một transaction, cấm >1 consumer, đóng tiến trình theo `messageFinal` (bất biến bị đổi theo Quyết định của người dùng).
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1: thứ tự năm mục của store, mục 5 cộng tổng header bằng SUM sau cùng; mục 2: ReferenceID trỏ vào phiếu kho.

### Thay đổi
- D:\_AppInventory\ebinventory\COSTING.md: mục 8 tách thành 8a (kích thước lô; ghi giá trị hiện tại 200 thử nghiệm, chưa chốt, trước đó 2000; thêm triệu chứng khoá bảng đo 15/10) và 8b mới (mọi kết quả cùng `ReferenceID` đi chung một lô; bảng nghĩa ReferenceID theo TypeID; chứng từ lớn hơn lô thì lô được vượt cỡ; vì sao; triệu chứng deadlock 15/10; hợp đồng mục 7 không đổi; điểm chưa xác minh về lệnh lắp ráp).
- D:\_AppAll\200133ebqueue\COSTING.md: viết lại mục 5. Bỏ cấm >1 consumer, thay bằng 5a (song song chỉ an toàn khi lô không cắt chứng từ cha, dẫn về mục 8 ebinventory; bỏ điều kiện thì phải trả về 1 consumer; header tạm lệch được chấp nhận) và 5b (TaskLogDetail theo lô do ebqueue tạo, đóng TaskLog theo trạng thái lô, bỏ `messageFinal`, ba ràng buộc chống đóng sớm/bỏ sót).
- D:\_AppAll\200133ebwebbe\COSTING.md: thêm đoạn sau bảng mục 1 (vì sao giữ SUM ở mục 5 store là đúng, điều kiện phụ thuộc chia lô) và mục 1a mới (màn hình chỉ tạo TaskLog, không tạo TaskLogDetail).
- Lý do nghiệp vụ của việc đổi (theo task.md): khoá bảng ảnh hưởng toàn hệ thống; 1 consumer làm công ty lớn chặn hàng chờ (154 lô / 27 phút); 5 consumer với lô chia theo vị trí sinh deadlock do hai lô cùng chạm một chứng từ cha và đóng tiến trình sớm do `messageFinal`.

### Xử lý review (nếu có)
Không có file review.

### Kết quả test
Chế độ rule, không sửa code, không chạy test.

### COSTING.md
Đã cập nhật COSTING.md: ebinventory — mục 8 sửa (tách 8a, thêm 8b)
Đã cập nhật COSTING.md: ebqueue — mục 5 sửa (thêm 5a, 5b)
Đã cập nhật COSTING.md: ebwebbe — mục 1 thêm đoạn về SUM header, thêm mục 1a

### Lưu ý cho reviewer / người dùng
1. **Đóng tiến trình: tôi diễn giải "tất cả đã xong" là đủ `totalBatches` lô.** task.md ghi "kiểm tra các TaskLogDetail khác của cùng TaskLog: tất cả đã xong thì chuyển hoàn thành". Đọc theo chữ thì sai tiêu chí chấp nhận: TaskLogDetail chỉ sinh khi lô tới, lô 1 xong trước khi lô 2 được nhận là đóng sớm. Bản tin đã có sẵn `batchIndex`/`totalBatches` (ebinventory `CostingResultSenderServiceImpl.java:41-42`, ebqueue `RabbitMQMessageCustomInventoryCosting.java`) nên tôi ghi điều kiện là đủ `totalBatches` lô. Cần người dùng xác nhận.
2. Ràng buộc tuần tự hoá việc đóng TaskLog (5b.2), ghi trạng thái lỗi ngoài transaction bị rollback và chống trùng TaskLogDetail khi redelivery (5b.3) là suy ra để đạt tiêu chí "không đóng sớm, không bỏ sót", không phải nguyên văn người dùng. Cách hiện thực (khoá dòng hay update có điều kiện) để chế độ code chọn.
3. Store còn `SUM` trên `RSAssemblyDismantlement` và phiếu nhập thành phẩm 404 (`update_InventoryCosting_TVP.sql:319-352`). Chia theo `ReferenceID` dòng 414 chỉ bảo vệ lệnh lắp ráp nếu mỗi lệnh có đúng một phiếu xuất nguyên vật liệu. Chưa kiểm; đã ghi "chưa xác minh" ở mục 8b ebinventory.
4. task.md liệt kê 410, 412, 414, 415 nhưng không nhắc 413 (store xử lý 410 và 413 chung là phiếu xuất kho thủ công). Luật chia lô áp dụng đồng nhất theo `ReferenceID` nên 413 vẫn được bảo vệ. 412 không được tính giá (mục 4 ebinventory) nên không có trong kết quả.
5. Bản tin hiện mang `taskDetailID` do ebwebbe tạo. Khi ebwebbe thôi tạo TaskLogDetail thì trường này sẽ rỗng; ebinventory (`CostingResultSenderServiceImpl` truyền `source.taskDetailID()`) và ebqueue (`closeTaskLog` cập nhật theo nó) phải được sửa tương ứng ở chế độ code. Hợp đồng ba trường của phần tử kết quả (mục 7) không đổi.
6. Bảng ánh xạ test ở mục 11 ebinventory (dòng "8 Chia lô") chưa cập nhật vì test mới cho 8b chưa có; cập nhật ở vòng code khi test-writer đã thêm test.
7. `CostingResultSenderServiceImpl.java:28` có comment nói bản tin rỗng mang `messageFinal` để ebqueue đóng TaskLog; sau thay đổi comment này lỗi thời, cần sửa ở vòng code.

## Vòng 1 — chế độ code
Đã đọc COSTING.md (ebinventory) — áp dụng mục 8b: mọi kết quả cùng `ReferenceID` dòng sổ kho đi chung một bản tin, chứng từ lớn hơn `result-batch-size` thì lô được vượt cỡ, không cắt; mục 8a: không chứng từ nào lớn hơn cỡ lô thì không lô nào vượt; mục 7: hợp đồng JSON đúng ba trường, `ReferenceID` không gửi sang ebqueue; mục 11: so tiền bằng `isEqualByComparingTo`, cập nhật bảng mã test.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 5a: nhiều consumer song song, điều kiện là lô không cắt chứng từ cha; mục 5b: ebqueue tạo một TaskLogDetail mỗi lô, đóng TaskLog khi đủ `batchTotal` lô thành công hoặc có lô lỗi, không theo `messageFinal`; ba ràng buộc: đếm theo `batchTotal`, đóng sau commit và tuần tự hoá, trạng thái lỗi không nằm trong transaction bị rollback / không đếm trùng khi redelivery.
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1a: màn hình chỉ tạo TaskLog, không tạo TaskLogDetail; mục 1: store giữ `SUM` header (không sửa store).

### Thay đổi
ebinventory (D:\_AppInventory\ebinventory)
- `src/main/java/vn/softdreams/ebinventory/domain/dto/CostingResult.java`: thêm trường thứ tư `referenceID` đánh `@JsonIgnore` + constructor 3 tham số (referenceID = null) để test cũ và code cũ vẫn dựng được. Lý do: chỗ chia lô cần biết chứng từ cha mà không đổi hợp đồng JSON. Đã kiểm bằng `JacksonJsonMessageConverter` thật: JSON ra `[{"detailID":"D1","typeID":411,"mainUnitPrice":10}]`, không có referenceID.
- `src/main/java/vn/softdreams/ebinventory/service/impl/CostingServiceImpl.java`: `calculateByGroup` truyền `row.referenceID()` vào `CostingResult` (1 dòng).
- `src/main/java/vn/softdreams/ebinventory/rabbitmq/rabbitmqcosting/CostingResultSenderServiceImpl.java`: bỏ chia theo vị trí `subList`; thêm `splitByParentDocument` gom theo `ReferenceID` (LinkedHashMap, thứ tự xuất hiện đầu), xếp lần lượt từng chứng từ vào lô, thêm chứng từ mà vượt cỡ thì mở lô mới; chứng từ lớn hơn cỡ lô nằm một mình một lô vượt cỡ; dòng không có ReferenceID coi là chứng từ riêng. Kết quả rỗng vẫn gửi một bản tin rỗng `batchTotal = 1`. `batchIndex`, `batchTotal`, `messageFinal` giữ như cũ (messageFinal vẫn gửi, ebqueue không dùng nữa).
- `CostingResultMessage.java`, `CostingResultSenderService.java`, `DwhRepositoryLedgerRow.java`: chỉ sửa javadoc (batchTotal dùng để đóng TaskLog, messageFinal không còn dùng để đóng, taskDetailID thường null, referenceID dùng chia lô).
- Không đụng `ApplicationProperties.java`, `application-worker.yml` (giữ 200).

ebqueue (D:\_AppAll\200133ebqueue)
- `src/main/java/ebqueue/rabbitmqconfig/InventoryCosting/MqInternalCustomMessageHandlerInventoryCosting.java`: viết lại luồng: kiểm `taskID`/`batchIndex`/`batchTotal` (sai thì ném IllegalArgumentException → nack/DLQ); `registerBatch` tìm TaskLogDetail theo (TaskLogID, Info = `#TGXK-BQCK lô i/n`), chưa có thì INSERT trạng thái InProgress, có rồi (redelivery) thì dùng lại; gọi `updateVouchers` (transaction riêng như cũ); `finishBatch` ghi trạng thái lô (tự commit, ngoài transaction đã rollback) rồi gọi lệnh đóng có điều kiện; chỉ khi lệnh đóng có tác dụng mới báo websocket. Bỏ đường đóng qua queue `UpdateTaskLog` và cờ `messageFinal`. Mô tả lỗi cắt 512 ký tự trước khi ghi `TaskLog.Description`.
- `src/main/java/ebqueue/repository/TaskLogDetailRepository.java`: thêm `insertCostingBatch`, `findCostingBatchID`.
- `src/main/java/ebqueue/repository/TaskLogRepository.java`: thêm `closeCostingAsFail` (UPDATE ... WHERE Status IN (Waiting, InProgress)) và `closeCostingAsSuccess` (thêm NOT EXISTS detail lỗi và `COUNT(DISTINCT Info)` detail thành công ≥ `batchTotal`), trả số dòng bị đổi.
- `RabbitMQMessageCustomInventoryCosting.java`: chỉ sửa javadoc ba trường.
- Không đụng `libs/core-model.jar`, `application-dev.yml`, `application-prod.yml`.

ebwebbe (D:\_AppAll\200133ebwebbe)
- `src/main/java/vn/softdreams/ebweb/service/impl/AsyncCalculateOWPriceServiceImpl.java`: `handleCalculateToEbInventory` bỏ tạo TaskLogDetail và bỏ `setTaskDetailID`; sửa javadoc hai hàm. Phần comment `COSTING_CODE` dòng 705-707 giữ nguyên. Hai chỗ tạo TaskLogDetail khác trong file (luồng cũ, cập nhật số tích luỹ) không đụng.

Lý do 5b.2 đúng với lệnh UPDATE có điều kiện: mỗi consumer chỉ gọi lệnh đóng sau khi trạng thái lô của nó đã commit, nên lệnh đóng chạy sau cùng (theo thời gian) thấy mọi lô; điều kiện `Status IN (Waiting, InProgress)` trên dòng TaskLog (khoá X dòng) làm lệnh thứ hai không ghi đè.

### Xử lý review (nếu có)
Không có file review.

### Kết quả test
- `./mvnw test` (JAVA_HOME = jdk-21.0.10.7) ở D:\_AppInventory\ebinventory → Tests run: 76, Failures: 0, Errors: 0, BUILD SUCCESS. UT_073, UT_074, UT_075 từ đỏ thành xanh; 73 test cũ vẫn xanh.
- Cài lỗi để kiểm test phủ (đã hoàn nguyên): truyền `null` thay `row.referenceID()` → 3 test đỏ trong `CostingResultSenderServiceImplTest`; thay điều kiện mở lô mới bằng `if (false)` → 7 test đỏ (UT_073 và các test 8a UT_043/044/045/046/047/051).
- ebqueue: `./mvnw -o -q compile` (JDK 11) → biên dịch được, không lỗi. Repo không có `src/test`.
- ebwebbe: **không biên dịch** (chỉ xoá 5 dòng và sửa comment; `TaskLogDetail`, `taskLogDetailRepository` vẫn còn dùng ở chỗ khác trong file). Repo không có `src/test`.
- Kịch bản tay TC-M1 – TC-M5 trong tests.md chưa chạy (cần DB test).

### COSTING.md
Đã cập nhật COSTING.md: ebinventory — mục 7 thêm đoạn về trường `referenceID` `@JsonIgnore` (chưa có test chặn); mục 8b thêm đoạn cách chia và thay đoạn "Chưa xác minh" lắp ráp bằng dữ liệu kiểm 16/10 từ task.md; mục 11 sửa số test 76, thêm `UT_073`–`UT_076`, tách dòng 8 thành 8a/8b, ghi kết quả cài lỗi.
Đã cập nhật COSTING.md: ebqueue — mục 5b sửa `totalBatches` → `batchTotal` (đúng tên trường bản tin), thêm đoạn "Cách hiện thực" (mã lô ở `TaskLogDetail.Info`, handler không transactional, lệnh đóng có điều kiện, không qua queue UpdateTaskLog, cắt Description 512, lô shovel lại không mở lại TaskLog lỗi).
Đã cập nhật COSTING.md: ebwebbe — mục 1a sửa đoạn triệu chứng cho khớp hiện thực ebqueue (detail thừa không chặn đóng nhưng nằm chờ mãi) và ghi `taskDetailID` để trống.

### Lưu ý cho reviewer / người dùng
1. **Dùng cột `TaskLogDetail.Info` làm mã lô** là quyết định của tôi, không có trong task.md. Bảng không có cột số lô; thêm cột phải sửa schema (`dbchangelog_real`) và core-model nên tôi tránh. Nếu muốn cột riêng thì đổi `BATCH_INFO_FORMAT` và hai query.
2. Lô có `batchTotal`/`taskID` sai bị nack vào DLQ và TaskLog treo (chỉ có log). Bản tin từ ebinventory luôn có đủ nên chỉ xảy ra với bản tin hỏng.
3. Bản tin còn trong queue từ bản ebwebbe cũ (có TaskLogDetail do ebwebbe tạo): TaskLog vẫn đóng đúng theo `batchTotal`, nhưng detail cũ nằm Waiting mãi.
4. Code mới không chuyển TaskLog sang InProgress khi lô đầu tới (TaskLog ở Waiting cho tới khi đóng). Chưa xác định luồng cũ có làm việc này qua UpdateTaskLog hay không. `checkTGXK` coi Waiting và InProgress như nhau nên không ảnh hưởng chặn chạy trùng; giao diện có thể hiển thị "chờ" cho tới khi xong.
5. `handleCalculateToEbInventory` gán `taskLog.setCompanyID(rabbitMQMessage.getCompanyID())` với `rabbitMQMessage` vừa `new` — chưa kiểm constructor có tự điền companyID hay không; ngoài phạm vi, không sửa.
6. `@JsonIgnore` trên `CostingResult.referenceID` chưa có test tự động chặn (đề nghị test-writer thêm test serialize JSON cho mục 7).
7. `COUNT(DISTINCT Info)` trên cột `nvarchar(max)` — SQL Server cho phép, nhưng chưa chạy thật trên DB; TC-M3/TC-M4 sẽ kiểm.

## Vòng 2 — chế độ code
Đã đọc COSTING.md (ebqueue) — áp dụng mục 5b: đóng TaskLog khi đủ `batchTotal` lô thành công hoặc có lô lỗi, không theo `messageFinal`; điều 1 đếm theo `batchTotal`; điều 2 đóng sau commit, tuần tự hoá bằng `UPDATE` có điều kiện `Status IN (Waiting, InProgress)`; điều 3 trạng thái lỗi ngoài transaction bị rollback, redelivery không sinh detail thứ hai; mã lô ở `TaskLogDetail.Info`.
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1a: màn hình chỉ tạo TaskLog, TaskLogDetail do ebqueue tạo, `taskDetailID` để trống.
Đã đọc COSTING.md (ebinventory) — áp dụng mục 7: JSON đúng ba trường, `referenceID` `@JsonIgnore` ("chưa có test tự động chặn" — nay đã có UT_078); mục 8b: dòng không có `ReferenceID` là chứng từ riêng; mục 11: số test, bảng mã, bảng phủ.
Căn cứ: task.md mục *Quyết định của người dùng*, dòng "(Trả lời B1 vòng review 1) Chọn phương án A" và "Không thêm unique index/cột mới… chống trùng dựa vào bước khoá `UPDLOCK`".

### Thay đổi
ebqueue (D:\_AppAll\200133ebqueue)
- `src/main/java/ebqueue/rabbitmqconfig/InventoryCosting/MqInternalCustomMessageHandlerInventoryCosting.java`:
  - `registerBatch` viết lại theo phương án A: trong `transactionTemplate.execute` gọi `createMissingBatches` — khoá dòng TaskLog (`lockCostingTask`, `UPDLOCK, ROWLOCK`), đọc các `Info` đã có, INSERT những mã lô `#TGXK-BQCK lô i/n` (i = 1..batchTotal) còn thiếu ở trạng thái `Waiting`, commit. Sau đó tìm detail của chính lô, chuyển `InProgress` + `StartTime` (`updateStatusAndStartTime`, có sẵn). Không tìm thấy detail sau bước tạo thì ném `IllegalStateException` (không thể xảy ra nếu bước tạo đúng).
  - Thêm `failTaskWithoutBatch`: bản tin hỏng (kiểm `batchIndex`/`batchTotal`) hoặc `registerBatch` ném lỗi thì đóng TaskLog lỗi bằng `closeCostingAsFail` (có điều kiện trạng thái) và báo websocket nếu lệnh đóng có tác dụng, rồi vẫn ném lỗi gốc (nack → DLQ như cũ). Xử lý review N4.
  - Autowire `TransactionTemplate` (bean đã dùng ở `SaveInvoiceTaxServiceImpl`, `MergeAccountingObjectServiceImpl`; dùng `transactionManager` @Primary — cùng datasource định tuyến với repository TaskLog). Cập nhật javadoc class.
- `src/main/java/ebqueue/repository/TaskLogRepository.java`: thêm `lockCostingTask` (`SELECT tsl.ID AS ID FROM TaskLog tsl WITH (UPDLOCK, ROWLOCK) WHERE tsl.ID = ?1`).
- `src/main/java/ebqueue/repository/TaskLogDetailRepository.java`: `insertCostingBatch` bỏ cột `StartTime` (detail chờ chưa bắt đầu; StartTime ghi khi lô thật sự chạy); thêm `findInfosByTaskLogID`.
- Không đụng `libs/core-model.jar`, `application-dev.yml`, `application-prod.yml`.
- Đã kiểm `Constants.StatusTask` trong `libs/core-model.jar` (javap): Waiting = 0, InProgress = 1, Success = 2, Fail = 3 — khớp với số màn hình ebwebfe/`TaskLogServiceImpl` coi 0/1 là "đang chạy", nên detail chờ chặn được nhánh tự đóng.

Không sửa ebwebbe code, ebwebfe, ebinventory code.

Lập luận phương án A chặn B1:
- Màn hình (`tien-trinh-du-lieu.component.ts:297-327`) và `TaskLogServiceImpl.java:362-363` chỉ đóng hoàn thành khi mọi detail đang có = 2. Từ khi lô đầu tiên (bất kỳ số thứ tự) được ghi nhận, TaskLog có đủ `batchTotal` detail, lô chưa xong ở 0/1 → hai nhánh tự đóng không chạy. Trước khi lô đầu tới, TaskLog không có detail → hai nhánh đó chỉ đánh lỗi khi quá 6 giờ, không đóng hoàn thành.
- Hai consumer nhận hai lô đầu của cùng TaskLog: `UPDLOCK` giữ tới commit của `TransactionTemplate`, consumer sau đọc `Info` sau khi consumer trước commit → thấy đủ, không INSERT. Hai consumer khác TaskLog không chặn nhau (`ROWLOCK` trên dòng khác nhau).
- Khi mọi detail đã thành công thì màn hình có thể chuyển TaskLog sang 2 trước lệnh đóng của ebqueue (khe hở giữa `updateStatusDescriptionAndEndTime` và `closeCostingAsSuccess`, cùng một consumer, chạy liền nhau). Nếu xảy ra thì kết quả vẫn đúng (TaskLog hoàn thành khi đủ lô), chỉ mất websocket "Done" — xem Lưu ý 2.

### Xử lý review
- [B1] Đã sửa: theo phương án A người dùng chọn — xem mục Thay đổi. Không sửa ebwebfe (đúng quyết định). COSTING.md ebqueue 5b thêm điều 4 và đoạn hiện thực; ebwebbe 1a thêm đoạn về hai chỗ tự đóng theo "mọi detail đang có".
- [N1] Bỏ qua: comment khối `rabbitmqinventorycosting` trong `application-dev.yml`/`application-prod.yml` thuộc thay đổi có sẵn; task.md ghi rõ "người dùng chưa trả lời; vẫn coi là thay đổi có sẵn, không đụng tới".
- [N2] Không phải việc của dev: test-writer đã thêm UT_077 (vòng 2). Đã cập nhật COSTING.md mục 11.
- [N3] Không phải việc của dev: test-writer đã thêm UT_078 (vòng 2). Đã sửa câu "Chưa có test tự động" ở COSTING.md mục 7.
- [N4] Đã sửa (rẻ, đúng mục 5b — lô lỗi thì TaskLog lỗi): `failTaskWithoutBatch` đóng TaskLog lỗi trước khi ném lỗi vào DLQ. Bản tin không có `TaskID` thì vẫn không đóng được (không biết TaskLog nào).
- "Không chắc" về `@JsonIgnore` dưới Jackson 3: test-writer đã trả lời bằng UT_078 (xanh) và cài lỗi.

### Kết quả test
- `./mvnw test` (JAVA_HOME = `C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`) ở D:\_AppInventory\ebinventory → Tests run: 78, Failures: 0, Errors: 0, Skipped: 0, BUILD SUCCESS. Không sửa test.
- ebqueue: `./mvnw -o -q compile` (JDK 11.0.29) → exit 0, không lỗi. Repo không có `src/test`.
- Kịch bản tay TC-M1 – TC-M6 trong tests.md chưa chạy (cần DB test).

### COSTING.md
Đã cập nhật COSTING.md: ebqueue — mục 5b sửa (gạch đầu dòng 1: tạo đủ `batchTotal` detail từ lô đầu; "Ba điều" → "Bốn điều", sửa điều 1, thêm điều 4 kèm triệu chứng; đoạn "Cách hiện thực" thêm bước ghi nhận lô trong transaction ngắn có `UPDLOCK` và việc đóng lỗi khi bản tin hỏng/ghi nhận lô lỗi, sửa thứ tự xử lý, thêm TC-M6)
Đã cập nhật COSTING.md: ebwebbe — mục 1a sửa (ebqueue tạo đủ `batchTotal` detail từ lô đầu; thêm đoạn rủi ro đóng sớm do `TaskLogServiceImpl`/màn hình xét "mọi detail đang có")
Đã cập nhật COSTING.md: ebinventory — mục 7 sửa (UT_078 chặn `@JsonIgnore`), mục 11 sửa (78 test, bảng mã `UT_073` – `UT_078`, bảng phủ 7 và 8b, kết quả cài lỗi UT_077/UT_078)

### Lưu ý cho reviewer / người dùng
1. Lô tới đầu tiên của TaskLog lớn tạo `batchTotal` bản ghi trong một transaction (mỗi INSERT một lệnh; ví dụ ~1.000 bản ghi với 195.358 dòng / lô 200). Trong lúc đó các consumer khác của **cùng** TaskLog chờ `UPDLOCK`; consumer của TaskLog khác không bị chặn. Chưa đo thời gian trên DB thật.
2. Khe hở nhỏ: lô cuối ghi detail thành công rồi mới gọi lệnh đóng; nếu đúng lúc đó màn hình/`TaskLogServiceImpl` đã chuyển TaskLog sang 2 thì lệnh đóng ebqueue tác dụng 0 dòng, websocket "Done" không bắn (TaskLog vẫn đúng là hoàn thành). Tương tự với lô lỗi: màn hình có thể đánh lỗi trước và gọi `updateActiveDetailsStatus(3)` — chuyển mọi detail chờ/đang chạy sang 3; các lô còn lại vẫn ghi dữ liệu, detail của chúng sau đó bị ghi đè thành 2, TaskLog vẫn lỗi.
3. Điểm "Không chắc" của reviewer về chạy lại cùng TaskLog với `batchTotal` khác vẫn còn: detail của lần đầu (mã `i/n` cũ) còn nằm lại; lần sau tạo thêm mã `i/m`. `COUNT(DISTINCT Info)` của lần sau có thể cộng cả mã cũ đã thành công → đóng sớm. Chưa xác định bản tin lệnh có bị giao lại trong thực tế.
4. `UPDLOCK` chỉ có tác dụng tuần tự hoá vì `TransactionTemplate` dùng `transactionManager` @Primary — cùng EntityManager/datasource với `TaskLogRepository`. Đổi transaction manager hoặc gọi ngoài template là mất khoá (đã ghi ở COSTING.md ebqueue).

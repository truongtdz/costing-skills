## Vòng 1
Đã đọc COSTING.md (ebinventory) — áp dụng mục 8b: mọi kết quả cùng `ReferenceID` dòng sổ kho phải đi chung một bản tin, chia theo nhóm `ReferenceID` chứ không theo vị trí; nhóm lớn hơn `result-batch-size` thì lô chứa nó được vượt cỡ, không cắt; áp cho 411, 403, 410/412/414/415, 420/421/422. Mục 8a: cỡ lô là ràng buộc (ngưỡng leo thang khoá), nên khi không có chứng từ nào lớn hơn cỡ lô thì không lô nào được vượt. Mục 7: hợp đồng ba trường không đổi, `ReferenceID` không gửi sang ebqueue. Mục 5: hàng bán trả lại có hoá đơn gốc trong kỳ vẫn được gán giá (dùng để dựng dòng 403 có kết quả). Mục 11: mã test kế tiếp, so tiền bằng `isEqualByComparingTo`.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 5b: đóng TaskLog khi đủ `totalBatches` lô (trường `batchTotal` của bản tin), không theo `messageFinal`; đếm trùng lô khi redelivery hoặc hai lô cuối cùng bỏ qua việc đóng là vi phạm. Repo không có `src/test`.
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1a: màn hình chỉ tạo TaskLog, không tạo TaskLogDetail. Repo không có `src/test`.

Căn cứ đổi nghiệp vụ: task.md mục *Quyết định của người dùng* (đổi mục 8 ebinventory, mục 5 ebqueue); cả ba COSTING.md đã được sửa trong working tree trước vòng này (`git diff COSTING.md`).

### Test đã thêm/sửa
Cả bốn test đều trong `D:\_AppInventory\ebinventory\src\test\java\vn\softdreams\ebinventory\rabbitmq\rabbitmqcosting\CostingResultSenderServiceImplTest.java`. Chạy cả chuỗi `CostingQueueListener` → `CostingServiceImpl` thật → `CostingResultSenderServiceImpl` thật, chỉ giả lập `GoGatewayClient`, `EbWebClient`, `RabbitTemplate`; đầu vào là dòng sổ kho thô có `ReferenceID`. Mục đích: test không phụ thuộc cách dev đưa `ReferenceID` tới chỗ chia lô. Cỡ lô 10.
- `::parentDocument_linesScatteredByMaterial_sentInOneBatch` (UT_073) — 4 hoá đơn 411, mỗi hoá đơn 3 dòng VTHH A + 3 dòng VTHH B; kết quả ra theo nhóm VTHH nên các dòng của một hoá đơn nằm rải hai đầu danh sách. Kỳ vọng: 24 dòng gửi đúng một lần, không `ReferenceID` nào ở 2 lô, không lô nào quá 10 dòng — mục 8b, 8a.
- `::parentDocumentLargerThanBatchSize_notCut` (UT_074) — phiếu xuất 410 `PX-1` 25 dòng và `PX-2` 3 dòng. Kỳ vọng: cả 25 dòng `PX-1` nằm trong đúng một bản tin; lô vượt cỡ chỉ khi chứa chứng từ lớn hơn cỡ lô; 28 dòng gửi đúng một lần — mục 8b (đoạn "được phép vượt").
- `::transferAndSalesReturn_notCutAcrossBatches` (UT_075) — chuyển kho 420 `CK-1` (`ReferenceID` = RSTransfer.ID, có cả dòng nhập kho đến không được gán giá) và hàng bán trả lại 403 `TL-1` (hoá đơn gốc trong kỳ nên được gán giá), mỗi chứng từ 3 dòng A + 3 dòng B. Kỳ vọng: 12 dòng gửi một lần, `CK-1` và `TL-1` mỗi cái nằm trong một lô — mục 8b (bảng TypeID), mục 5.
- `::parentDocumentBatching_batchTotalMatchesMessageCount` (UT_076) — dữ liệu UT_073. Kỳ vọng: `batchIndex` chạy liền 1..n, mọi bản tin có `batchTotal` = n = số bản tin thật — mục 5b COSTING.md ebqueue (đóng khi đủ `totalBatches`). Test chặn, xanh trên code hiện tại.

Không sửa test cũ nào.

### Kết quả chạy
`./mvnw test` (JAVA_HOME = jdk-21.0.10.7) ở `D:\_AppInventory\ebinventory` → 76 test, 3 đỏ: UT_073, UT_074, UT_075. Cả ba đều đỏ ở `assertNoParentDocumentInTwoBatches` (một `ReferenceID` nằm ở 2 lô). Đúng triệu chứng của cách chia theo vị trí `subList` ở `CostingResultSenderServiceImpl.java:31-35`. 73 test còn lại xanh.
Test đỏ mong đợi (chờ dev sửa code): UT_073, UT_074, UT_075

### Kịch bản thủ công (nếu có)
ebqueue và ebwebbe không có `src/test`, nên không dựng framework test. Chạy trên DB test (EB99_GR2), ebinventory `result-batch-size` 200, ebqueue 5 consumer.

**TC-M1 — Không chứng từ cha nào bị ghi ở 2 lô (ebinventory → ebqueue)**
- Dữ liệu vào: một công ty có nhiều hoá đơn bán, mỗi hoá đơn nhiều mặt hàng; ít nhất một hoá đơn hoặc phiếu xuất có hơn 200 dòng tính giá; có chứng từ chuyển kho và hàng bán trả lại trong kỳ.
- Bước: chạy tính giá bình quân cuối kỳ cho kỳ đó.
- Mong đợi: log ebinventory `#TGXK-BQCK Gửi kết quả sang ebqueue: lô i/n, k dòng` có `n` không đổi giữa các lô; lô chứa chứng từ hơn 200 dòng được có k > 200, các lô khác k ≤ 200. Log ebqueue không có deadlock (`was deadlocked`).
- Đối chiếu: sau khi chạy xong, tổng tiền header phải khớp chi tiết, ví dụ phiếu kho:
```sql
SELECT
    rsi.ID          AS ID,
    rsi.TotalAmount AS TotalAmount,
    det.SumAmount   AS SumAmount
FROM RSInwardOutward rsi
INNER JOIN (
    SELECT
        rsd.RSInwardOutwardID AS RSInwardOutwardID,
        SUM(rsd.Amount)       AS SumAmount
    FROM RSInwardOutwardDetail rsd
    GROUP BY rsd.RSInwardOutwardID
) det ON det.RSInwardOutwardID = rsi.ID
WHERE rsi.CompanyID = :companyId
  AND rsi.PostedDate BETWEEN :fromDate AND :toDate
  AND rsi.TotalAmount <> det.SumAmount
```
Mong đợi 0 dòng. Tên cột tổng tiền (`TotalAmount`/`Amount`) phải đối chiếu lại với mục 5 của store `update_InventoryCosting_TVP.sql`; tôi chưa kiểm cột cụ thể. Làm tương tự cho `SAInvoice`, `SAReturn`, `RSTransfer`.

**TC-M2 — ebwebbe chỉ tạo TaskLog (mục 1a ebwebbe)**
- Bước: bấm tính giá trên màn hình, ghi lại `TaskLog.ID` mới.
- Mong đợi: ngay sau khi bấm, trước khi ebqueue nhận lô đầu, không có TaskLogDetail nào của TaskLog đó.
- Đối chiếu: `SELECT tld.ID AS ID, tld.Status AS Status FROM TaskLogDetail tld WHERE tld.TaskLogID = :taskLogId` → 0 dòng lúc mới tạo; sau khi xong có đúng `n` dòng (n = `batchTotal` trong log ebinventory).

**TC-M3 — Không đóng sớm khi nhiều consumer (mục 5b.1 ebqueue)**
- Dữ liệu vào: công ty ra ít nhất 10 lô.
- Bước: chạy tính giá; cứ 1 giây đọc trạng thái TaskLog và đếm TaskLogDetail đã xong.
- Mong đợi: TaskLog chỉ chuyển hoàn thành khi số TaskLogDetail hoàn thành = `batchTotal`; không lần đọc nào thấy TaskLog hoàn thành mà số lô xong < `batchTotal`.
- Đối chiếu: `SELECT tsl.Status AS Status, COUNT(tld.ID) AS DoneCount FROM TaskLog tsl LEFT JOIN TaskLogDetail tld ON tld.TaskLogID = tsl.ID AND tld.Status = :successStatus WHERE tsl.ID = :taskLogId GROUP BY tsl.Status`.

**TC-M4 — Không bỏ sót việc đóng (mục 5b.2 ebqueue)**
- Bước: chạy TC-M3 với 5 consumer trên ít nhất 3 công ty cùng lúc, lặp 5 lần.
- Mong đợi: mọi TaskLog kết thúc ở hoàn thành (hoặc lỗi nếu có lô lỗi), không TaskLog nào treo ở đang xử lý khi mọi TaskLogDetail đã xong.

**TC-M5 — Lô lỗi làm TaskLog lỗi, redelivery không đếm trùng (mục 5b.3 ebqueue)**
- Bước: gây lỗi cho một lô (ví dụ khoá tạm một header bằng `BEGIN TRAN; UPDATE ... WITH (TABLOCKX)` ở phiên khác cho tới khi lô đó timeout), sau đó nhả khoá.
- Mong đợi: TaskLogDetail của lô đó ở trạng thái lỗi (không mất do rollback), TaskLog chuyển lỗi; nếu bản tin bị giao lại thì số TaskLogDetail của TaskLog không vượt `batchTotal`.
- Đối chiếu: `SELECT COUNT(tld.ID) AS DetailCount FROM TaskLogDetail tld WHERE tld.TaskLogID = :taskLogId` ≤ `batchTotal`.

## Vòng 2
Xử lý review_1.md, các mục liên quan test: N2, N3, mục "Không chắc" về `@JsonIgnore` dưới Jackson 3, và B1 (phần kịch bản kiểm tay). N1, N4 không phải việc của test, không xử lý.

Đã đọc COSTING.md (ebinventory) — áp dụng mục 8b: dòng kết quả không có `ReferenceID` được coi là một chứng từ riêng (không có căn cứ để gom); mọi dòng cùng `ReferenceID` đi chung một bản tin, lô chỉ vượt cỡ khi tự một chứng từ lớn hơn cỡ lô. Mục 7: mỗi phần tử gửi sang ebqueue đúng ba trường `detailID`, `typeID`, `mainUnitPrice`; `referenceID` đánh `@JsonIgnore`, "chưa có test tự động chặn việc này". Mục 11: mã test kế tiếp sau `UT_076`; một test phủ một mục chỉ khi phá đúng bất biến đó thì test đỏ.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 5b: đếm theo `batchTotal`, không theo số `TaskLogDetail` đang có (điều 1); lệnh đóng là `UPDATE` có điều kiện `Status IN (Waiting, InProgress)`. Repo không có `src/test`.
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1a: màn hình chỉ tạo TaskLog, TaskLogDetail do ebqueue tạo. Repo không có `src/test`.
Căn cứ cho TC-M6: task.md mục *Quyết định của người dùng*, dòng "(Trả lời B1 vòng review 1) Chọn phương án A". Tại thời điểm viết, mục 5b COSTING.md ebqueue và mục 1a ebwebbe **chưa** mô tả phương án A (vẫn ghi "khi nhận một lô thì tạo một TaskLogDetail cho lô đó").

Không đổi con số kỳ vọng nào của test cũ.

### Test đã thêm/sửa
Cả hai test trong `D:\_AppInventory\ebinventory\src\test\java\vn\softdreams\ebinventory\rabbitmq\rabbitmqcosting\CostingResultSenderServiceImplTest.java`, chạy cả chuỗi listener → `CostingServiceImpl` thật → `CostingResultSenderServiceImpl` thật như UT_073 – UT_076, cỡ lô 10.
- `::resultWithoutReferenceID_treatedAsOwnDocument` (UT_077, review N2) — hoá đơn 411 `HD-1` 4 dòng VTHH A + 4 dòng VTHH B, kèm 6 dòng 410 mỗi VTHH có `ReferenceID` = null. Kỳ vọng: 20 dòng gửi đúng một lần; 8 dòng `HD-1` nằm trong đúng một bản tin; không bản tin nào quá 10 dòng (nếu 12 dòng không `ReferenceID` bị gom thành một chứng từ thì lô chứa nó thành 12 dòng) — mục 8b (câu "không có `ReferenceID` được coi là một chứng từ riêng"), 8a.
- `::resultJson_hasExactlyThreeFields_noReferenceID` (UT_078, review N3 và "Không chắc") — serialize mọi bản tin của dữ liệu UT_073 bằng đúng bean `RabbitMqCostingConfig.rabbitJsonMessageConverter()` (`JacksonJsonMessageConverter`, Jackson 3), đọc lại JSON. Kỳ vọng: trong bộ nhớ các dòng có `referenceID` khác null; trong JSON mỗi phần tử `data` có đúng ba trường `detailID`, `typeID`, `mainUnitPrice` — mục 7.

Kiểm bằng cài lỗi (trên bản sao repo trong scratchpad, không chạm code thật, đã xoá bản sao):
- Bỏ `@JsonIgnore` ở `CostingResult.referenceID` → UT_078 đỏ (1/78 đỏ). Trả lời mục "Không chắc" của review: với code hiện tại `@JsonIgnore` (`com.fasterxml.jackson.annotation`) trên thành phần record **có** tác dụng dưới Jackson 3 — UT_078 xanh.
- Bỏ nhánh `result.referenceID() == null` trong `splitByParentDocument` (dòng null gom chung theo khoá null của `LinkedHashMap`) → UT_077 đỏ, kèm UT_043 – UT_047, UT_051 đỏ (7/78). Nghĩa là nhánh này vốn đã bị test 8a cũ chặn gián tiếp (chúng dùng constructor 3 tham số, `referenceID` = null); UT_077 là test đầu tiên chặn trực tiếp qua dòng sổ kho thô.

Hai test là test chặn, xanh trên code hiện tại; không phải test tái hiện lỗi.

### Kết quả chạy
`./mvnw test` (JAVA_HOME = `C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`) ở `D:\_AppInventory\ebinventory` → Tests run: 78, Failures: 0, Errors: 0, BUILD SUCCESS. 0 đỏ.
Test đỏ mong đợi (chờ dev sửa code): không có.

COSTING.md ebinventory mục 7 (câu "Chưa có test tự động chặn việc này"), mục 11 (con số 76 test, bảng mã chưa có `UT_077` – `UT_078`, bảng phủ mục 7 và 8b) nay không còn đúng — dev cần cập nhật; test-writer không sửa COSTING.md.

### Kịch bản thủ công (nếu có)
**TC-M6 — Màn hình "Tiến trình dữ liệu" không đóng TaskLog sớm (review B1, phương án A trong task.md)**
- Dữ liệu vào: một công ty ra ít nhất 5 lô (`result-batch-size` 200 → hơn 800 dòng kết quả). Để lộ khe hở, làm chậm lô sau: chạy thêm tính giá của 2–3 công ty khác cùng lúc để 5 consumer bận, hoặc tạm dừng consumer ebqueue sau khi lô 1 được nhận.
- Bước:
  1. Bấm tính giá, ghi lại `TaskLog.ID`.
  2. Ngay khi log ebqueue báo nhận lô đầu tiên (bất kỳ `i/n`), đọc TaskLogDetail.
  3. Mở màn hình "Tiến trình dữ liệu" (ebwebfe, chạy `taskLogStatusCheck` khi `loadAll`), bấm tải lại vài lần trong lúc còn lô chưa xử lý; đồng thời gọi API danh sách TaskLog phía BE để `TaskLogServiceImpl` chạy nhánh `detailCount == details.size()`.
- Mong đợi:
  - Sau bước 2: TaskLog có đúng `n` TaskLogDetail (n = `batchTotal` trong log ebinventory), các lô chưa xử lý ở trạng thái chờ; không có mã lô `Info` trùng.
  - Sau bước 3: TaskLog vẫn ở trạng thái chờ/đang xử lý cho tới khi lô cuối cùng xong; không có lời gọi `update-status/{id}?status=2` nào làm đổi trạng thái khi còn detail chưa xong.
  - Khi xong: TaskLog hoàn thành do ebqueue đóng (log ebqueue có lệnh đóng tác dụng 1 dòng và có websocket "Done"); tổng số TaskLogDetail vẫn = `n`.
  - Biến thể lỗi: gây lỗi một lô (như TC-M5) trong lúc màn hình đang mở → TaskLog kết thúc ở **lỗi**, không hiển thị hoàn thành.
- Đối chiếu (chạy ở bước 2, bước 3 và khi xong):
```sql
SELECT
    tsl.ID                                                      AS ID,
    tsl.Status                                                  AS TaskStatus,
    COUNT(tld.ID)                                               AS DetailCount,
    COUNT(DISTINCT tld.Info)                                    AS BatchCodeCount,
    SUM(CASE WHEN tld.Status = :successStatus THEN 1 ELSE 0 END) AS DoneCount
FROM TaskLog tsl
LEFT JOIN TaskLogDetail tld ON tld.TaskLogID = tsl.ID
WHERE tsl.ID = :taskLogId
GROUP BY tsl.ID, tsl.Status
```
Mong đợi: ngay từ lô đầu `DetailCount = BatchCodeCount = n`; không lần đọc nào có `TaskStatus` = hoàn thành mà `DoneCount < n`. Giá trị `:successStatus` và mã trạng thái chờ phải lấy theo hằng số dev dùng trong `TaskLogDetailRepository`; tôi chưa kiểm con số cụ thể.

**TC-M2 (vòng 1) cần đổi mong đợi theo phương án A:** "trước khi ebqueue nhận lô đầu: 0 TaskLogDetail" vẫn đúng; "sau khi xong có đúng `n` dòng" nay phải đúng **ngay từ khi nhận lô đầu**, không chỉ lúc xong.

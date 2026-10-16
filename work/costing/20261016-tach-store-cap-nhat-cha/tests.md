## Vòng 1
Đã đọc COSTING.md (ebinventory) — áp dụng mục 7: hợp đồng bốn trường `detailID`, `typeID`, `mainUnitPrice`, `referenceID` (đổi 16/10/2026); `referenceID` lấy từ cùng dòng sổ kho với `detailID`, cùng quy ước byte GUID (mục 9); `UT_078` phải kiểm mỗi phần tử `data` đúng bốn trường. Mục 11: mã `UT_078` thuộc `CostingResultSenderServiceImplTest`; đổi kỳ vọng chỉ khi mục tương ứng đã sửa trước.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 1: `referenceID` đổ vào cột `ReferenceID` của `TVP_CostingResult` cùng cách xử lý byte như `detailID`; mục 5: trong transaction của lô gọi store con rồi store cha, cùng TVP, lô lỗi rollback cả hai; mục 5b: TaskLog đóng theo `batchTotal`. Repo không có `src/test` → kịch bản tay.
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1: store con chỉ ghi mục 1–3, store cha cộng `SUM ... GROUP BY` trên **mọi** dòng con trong DB, đi theo khoá chính không theo `CompanyID`, chạy sau store con cùng transaction; mục 2: bảng ánh xạ `ReferenceID` → chứng từ cha theo TypeID (411/403 qua `RSInwardOutwardID`); mục 8: lắp ráp/tháo dỡ sang store cha, dòng NVL lệnh chỉ chép cho dòng 414 trong TVP, tháo dỡ dùng đơn giá thô từ TVP; mục 9: store con bỏ sáu bảng tạm gom ID cha. Repo không có `src/test` → kịch bản tay.
Điều kiện rule-change: task.md có quyết định người dùng cho phép đổi kỳ vọng `UT_078`; mục 7 ebinventory đã được sửa trước (work.md vòng 1, chế độ rule).

### Test đã thêm/sửa
- `D:\_AppInventory\ebinventory\src\test\java\vn\softdreams\ebinventory\rabbitmq\rabbitmqcosting\CostingResultSenderServiceImplTest.java::resultJson_hasExactlyFourFields_referenceIDOfSameLedgerRow` (`UT_078`, sửa — trước là `resultJson_hasExactlyThreeFields_noReferenceID`) — serialize bằng đúng converter của ứng dụng (`RabbitMqCostingConfig.rabbitJsonMessageConverter`), kiểm: (1) mỗi phần tử `data` đúng bốn trường `detailID`, `typeID`, `mainUnitPrice`, `referenceID`; (2) `referenceID` trong JSON không rỗng và **bằng đúng** `ReferenceID` của dòng sổ kho mang cùng `detailID` (không biến đổi giá trị, không lấy nhầm dòng); (3) đủ 24 dòng được kiểm (4 hoá đơn × 2 VTHH × 3 dòng) để lô rỗng không làm test xanh giả. Kỳ vọng từ mục 7 (bốn trường, cùng dòng, cùng quy ước byte với `detailID`) và mục 9.

### Kết quả chạy
`./mvnw test` ở `D:\_AppInventory\ebinventory` với `JAVA_HOME` = JDK 21 (`C:\Program Files\Eclipse Adoptium\jdk-21.0.10.7-hotspot`; JAVA_HOME mặc định của máy là JDK 17, enforcer chặn) → 78 test, 1 đỏ: `CostingResultSenderServiceImplTest.resultJson_hasExactlyFourFields_referenceIDOfSameLedgerRow` (`UT_078`) — lô 1, phần tử JSON không có `referenceID` (do `@JsonIgnore` ở `CostingResult.referenceID`). 77 test còn lại xanh.
Test đỏ mong đợi (chờ dev sửa code): `UT_078` — dev bỏ `@JsonIgnore` ở `src/main/java/vn/softdreams/ebinventory/domain/dto/CostingResult.java` (javadoc ở đó còn ghi "ba trường").
Chưa kiểm được: vế (2) — so giá trị `referenceID` — chưa chạy tới vì test dừng ở vế (1). Sau khi dev sửa nên chạy lại; nếu xanh thì cài lỗi thử (ví dụ truyền `row.detailID()` vào vị trí `referenceID` ở `CostingServiceImpl`) để chứng minh vế (2) phủ được.

### Kịch bản thủ công (nếu có)
ebwebbe và ebqueue không có bộ test tự động. Chạy trên DB test (EB99_GR2 hoặc bản sao), **không** trên production. Tên store cha chưa có (dev đặt khi hiện thực) — dưới đây gọi là `<StoreCha>`, giả định nhận cùng `@data dbo.TVP_CostingResult` như store con.

Phương pháp đối chiếu chung "tiền không đổi" (task.md yêu cầu 5): trên cùng một dữ liệu, chạy store cũ và cặp store mới, mỗi lần trong `BEGIN TRAN ... ROLLBACK`, chụp kết quả vào **biến bảng** (biến bảng không bị rollback) rồi so `EXCEPT` hai chiều. Store cũ lấy từ base commit `c31c22d4` của ebwebbe (bản working tree đầu task), tạo tạm trên DB test dưới tên khác (ví dụ `update_InventoryCosting_TVP_OLD`), xoá sau khi kiểm. Nếu store cũ không biên dịch được với TYPE bốn cột thì chạy phần (a) trước khi deploy TYPE mới, lưu kết quả vào bảng thường tạm.

**TC-W1 — Tiền không đổi, hoá đơn bán (411) chỉ tính giá một phần vật tư** (ebwebbe mục 1 ràng buộc 2, mục 2 dòng 411; yêu cầu 5)
- Dữ liệu: một `SAInvoice` có 3 dòng chi tiết VTHH A, B, C; phiếu kho đi kèm `RSInwardOutwardID = R`. TVP chỉ chứa dòng A và B (`DetailID` = `SAInvoiceDetail.ID`, `TypeID` 411, `ReferenceID` = R, đơn giá thô nhiều chữ số thập phân, ví dụ 12345.6789012). Dòng C có `OWAmount` cũ khác 0.
- Bước: (a) chạy store cũ, chụp, rollback; (b) chạy store con rồi `<StoreCha>` trong cùng transaction, chụp, rollback.
- Mong đợi: `SAInvoice.TotalCapitalAmount` = `SUM(OWAmount)` của **cả A, B, C** (gồm giá cũ của C); `RSInwardOutWard(R).TotalAmount` = cùng tổng, `TotalAmountOriginal` = tổng / `ExchangeRate`; mọi cột (a) = (b).
- Đối chiếu (`TotalCapitalAmount` phải bằng `TongGiaVon`; lỗi đặc trưng: chỉ cộng dòng trong lô → thiếu tiền của C):
```sql
SELECT
    sai.ID                 AS ID,
    sai.TotalCapitalAmount AS TotalCapitalAmount,
    agg.TongGiaVon         AS TongGiaVon
FROM SAInvoice sai
CROSS APPLY (SELECT SUM(sad.OWAmount) AS TongGiaVon FROM SAInvoiceDetail sad WHERE sad.SAInvoiceID = sai.ID) agg
WHERE sai.RSInwardOutwardID = @R
```

**TC-W2 — Hàng bán trả lại (403)** (ebwebbe mục 2 dòng 403)
- Dữ liệu: `SAReturn` có `RSInwardOutwardID = R2`, 2 dòng; TVP chứa 1 dòng (`ReferenceID` = R2).
- Mong đợi: `SAReturn.TotalOWAmount` = `SUM(SAReturnDetail.OWAmount)` cả hai dòng; `RSInwardOutWard(R2).TotalAmount` = cùng tổng, `TotalAmountOriginal` = tổng / `ExchangeRate`; khớp store cũ. Lỗi đặc trưng: so `ReferenceID` với `SAReturn.ID` → header không đổi, không báo lỗi.

**TC-W3 — Phiếu xuất kho thủ công 410, 413** (ebwebbe mục 2)
- Dữ liệu: một phiếu 410 và một phiếu 413, mỗi phiếu 2 dòng; TVP chứa 1 dòng mỗi phiếu.
- Mong đợi: `RSInwardOutWard.TotalAmount` = `SUM(rsd.Amount)`, `TotalAmountOriginal` = `SUM(rsd.AmountOriginal)` trên mọi dòng của phiếu; khớp store cũ.

**TC-W4 — Chuyển kho 420, 421, 422** (ebwebbe mục 2)
- Dữ liệu: một `RSTransfer` mỗi loại, mỗi phiếu 2 dòng, TVP chứa 1 dòng; `ReferenceID` = `RSTransfer.ID`.
- Mong đợi: `RSTransfer.TotalAmount` = `TotalAmountOriginal` = `SUM(RSTransferDetail.OWAmount)` mọi dòng; khớp store cũ.

**TC-W5 — Lắp ráp 414 → 404** (ebwebbe mục 8)
- Dữ liệu: lệnh lắp ráp có 3 dòng NVL, phiếu xuất NVL P (`ReferenceID` = P), phiếu nhập thành phẩm; TVP chứa 2/3 dòng 414. Thêm một lệnh có số lượng thành phẩm = 0.
- Mong đợi (khớp store cũ): `RSAssemblyDismantlementDetail` chỉ đổi giá ở **2 dòng có trong TVP**, dòng thứ ba giữ nguyên; `RSAssemblyDismantlement.Amount` = tổng NVL **cả 3 dòng**; `UnitPrice` = Amount / số lượng thành phẩm (lệnh SL 0: `UnitPrice` NULL, không lỗi chia 0); dòng nhập thành phẩm trên `RSInwardOutWardDetail` lấy giá lệnh; tổng phiếu nhập thành phẩm chỉ cộng dòng thành phẩm; `RepositoryLedger` 404 và `GeneralLedger` dòng 404 được cập nhật.
- Đối chiếu: so biến bảng (a)/(b) trên `RSAssemblyDismantlement`, `RSAssemblyDismantlementDetail`, `RSInwardOutWardDetail`, `RSInwardOutWard`, `RepositoryLedger`, `GeneralLedger` lọc theo lệnh.

**TC-W6 — Tháo dỡ 415** (ebwebbe mục 8, điểm "đơn giá thô từ TVP")
- Dữ liệu: lệnh tháo dỡ; TVP dòng 415 đơn giá thô 10 chữ số thập phân (ví dụ 3333.3333333333), `Quantity` = 3.
- Mong đợi: `RSAssemblyDismantlement.UnitPrice` = đơn giá thô, `Amount` = `ROUND(3 * 3333.3333333333, @LamTronTienVN)`; khớp store cũ đến từng đồng. Lệch = store cha đọc lại `MainUnitPrice` đã lưu (đã bị làm tròn).

**TC-W7 — Store con không đụng header** (ebwebbe mục 1, mục 9)
- Bước: chỉ chạy store con với TVP của TC-W1..W5, không chạy `<StoreCha>`.
- Mong đợi: dòng chi tiết, sổ kho, sổ cái đổi; **mọi header** (`SAInvoice.TotalCapitalAmount`, `SAReturn.TotalOWAmount`, `RSInwardOutWard.TotalAmount`, `RSTransfer.TotalAmount`, `RSAssemblyDismantlement.Amount/UnitPrice`) giữ nguyên. Đọc mã store con: không còn sáu bảng tạm `#SAInvoiceUpdate`, `#SAReturnUpdate`, `#RSInwardOutWardUpdate`, `#RSTransferUpdate`, `#RSAssemblyUpdate`, `#RSInwardOutWardAssemblyUpdate`.

**TC-W8 — Store cha không đi theo `CompanyID`** (ebwebbe mục 1 ràng buộc 3)
- Bước: `SET STATISTICS IO ON; SET STATISTICS XML ON;` chạy `<StoreCha>` với lô 200 dòng 411/410 trên EB99_GR2.
- Mong đợi: câu cập nhật header **không** dùng `RSInwardOutward__index_company_id`; logical reads trên `RSInwardOutWard` cỡ số chứng từ trong lô, không còn hàng trăm nghìn như số đo 354.645 / 843.500 / 1.062.436 trong task.md.

**TC-W9 — Dòng TVP có `ReferenceID` NULL** (task.md: dữ liệu thật 0 dòng, chỉ yêu cầu không lỗi)
- Bước: thêm vào TVP một dòng 410 có `ReferenceID` NULL, chạy cặp store.
- Mong đợi: không lỗi; dòng chi tiết vẫn được ghi; header của phiếu đó không đổi (ebwebbe mục 1 đã ghi nhận).

**TC-W10 — Trình tự đổi TYPE** (ebwebbe bảng code; task.md yêu cầu 3)
- Bước: chạy script deploy trên DB test đang có store cũ.
- Mong đợi: không lỗi "Cannot drop type ... because it is being referenced"; sau deploy TYPE có 4 cột `DetailID`, `TypeID` (`int`, ebwebbe mục 5), `MainUnitPrice`, `ReferenceID`; ghi chú trong `TVP_CostingResult.sql` liệt kê cả hai store.
- Đối chiếu:
```sql
SELECT
    col.name AS ColumnName,
    typ.name AS TypeName
FROM sys.table_types ttt
INNER JOIN sys.columns col ON col.object_id = ttt.type_table_object_id
INNER JOIN sys.types typ ON typ.user_type_id = col.user_type_id
WHERE ttt.name = N'TVP_CostingResult'
```

**TC-Q1 — `referenceID` đi vào TVP đúng byte** (ebqueue mục 1)
- Bước: tính giá thật một kỳ nhỏ (1 hoá đơn 411, 1 chuyển kho 420), bật Extended Events `rpc_completed` bắt lệnh gọi store.
- Mong đợi: cột `ReferenceID` trong TVP = `RepositoryLedger.ReferenceID` của dòng có `DetailID` tương ứng (so GUID, không đảo byte); header hoá đơn và `RSTransfer` được cộng lại sau lô (câu SQL TC-W1 cho `TotalCapitalAmount = TongGiaVon`). Chi tiết đổi mà header không đổi = `referenceID` sai byte hoặc thiếu.

**TC-Q2 — Hai store cùng một transaction, lỗi store cha rollback cả con** (ebqueue mục 5; task.md yêu cầu 4)
- Chuẩn bị (DB test): trigger tạm `AFTER UPDATE` trên `SAInvoice` gọi `RAISERROR` khi `ID` = hoá đơn X.
- Bước: chụp `OWAmount`/`MainUnitPrice` mọi dòng của lô chứa X; tính giá kỳ đó.
- Mong đợi: lô chứa X lỗi; `SAInvoiceDetail`, `RepositoryLedger`, `GeneralLedger` của **mọi** dòng trong lô giữ giá cũ (store con cũng rollback); `TaskLogDetail` lô đó lỗi, `TaskLog` chuyển lỗi (ebqueue mục 5b); các lô khác vẫn ghi. Xoá trigger sau khi kiểm.

**TC-Q3 — Thứ tự con trước cha** (ebqueue mục 5)
- Bước: dữ liệu như TC-W1, tính giá thật qua queue.
- Mong đợi: sau lô, `TotalCapitalAmount` = tổng giá **mới** (câu SQL TC-W1 khớp). Khớp tổng giá cũ = store cha chạy trước store con.

**TC-Q4 — Hồi quy task trước** (task.md yêu cầu 6): chạy lại TC-M2 – TC-M6 trong `.claude/work/costing/20261016-lo-theo-chung-tu-cha/tests.md` (TaskLogDetail theo lô, `UPDLOCK`, đóng theo `batchTotal`, 5 consumer không deadlock).

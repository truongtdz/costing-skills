## Vòng 1 — chế độ rule
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1: thứ tự năm mục của store (sổ kho/sổ cái → chứng từ gốc → chi tiết sổ cái → lắp ráp → tổng header SUM), mục 2: ReferenceID trỏ phiếu kho, không trỏ chứng từ nghiệp vụ; mục 6: nhân đơn giá thô rồi ROUND; mục 8: lắp ráp giá thành phẩm dẫn xuất, tháo dỡ chỉ ghi lên lệnh; mục 9: bảng tạm có khoá chính khai đầu store.
Đã đọc COSTING.md (ebinventory) — áp dụng mục 7: hợp đồng ba trường, referenceID bị @JsonIgnore, UT_078 chặn; mục 8b: chia lô theo ReferenceID, bảng nghĩa ReferenceID theo TypeID; mục 9: GUID đảo byte ở biên; mục 11: UT_078.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 1: hợp đồng ba trường; mục 5: một lô một transaction; mục 5a: song song an toàn vì lô không cắt chứng từ cha.
Đối chiếu bất biến: các mục đổi đều nằm trong "Quyết định của người dùng" (ebwebbe mục 1 + mục liên quan lắp ráp/tổng header, ebinventory mục 7, ebqueue mục 1). ebwebbe mục 2 ("không join qua ReferenceID") được viết lại vì là mục định vị chứng từ cha cho tổng header; bài học cũ giữ nguyên (so ReferenceID với SAInvoice.ID/SAReturn.ID là sai, phải so với RSInwardOutwardID).

### Thay đổi
- D:\_AppAll\200133ebwebbe\COSTING.md:
  - Tiêu đề + bảng code: hai store (con/cha) dùng chung TVP; trình tự đổi TYPE phải xoá cả hai store. Tên file store cha để trống, ghi khi hiện thực.
  - Mục 1 viết lại: store con chỉ mục 1–3; store cha lấy tập ReferenceID → chứng từ cha → SUM GROUP BY từ mọi dòng con trong DB; lắp ráp trước tổng header trong store cha. Ba ràng buộc (con trước cha cùng transaction; cộng mọi dòng con trong DB; đi theo khoá chính, không CompanyID) mỗi cái có vì sao + triệu chứng. Lý do đổi kèm số logical reads EB99_GR2 16/10. Thêm rủi ro: dòng không có ReferenceID thì header không được cộng (khác store cũ), chưa kiểm DWH.
  - Mục 2 viết lại: bảng ánh xạ ReferenceID → chứng từ cha theo TypeID (411, 403, 410/413, 414/415, 420–422).
  - Mục 8 thêm: phần lắp ráp/tháo dỡ chuyển sang store cha, giữ thứ tự; hai điểm để tiền không đổi: dòng NVL lệnh chỉ chép cho dòng 414 trong TVP (như cũ); lệnh tháo dỡ dùng đơn giá thô từ TVP, không đọc lại MainUnitPrice đã lưu.
  - Mục 9 viết lại: bảng tạm có khoá chính cho cả hai store; store con bỏ sáu bảng tạm gom ID cha.
- D:\_AppInventory\ebinventory\COSTING.md:
  - Mục 7: hợp đồng bốn trường (thêm referenceID), lý do nghiệp vụ, ràng buộc cùng dòng/cùng quy ước byte với detailID, triệu chứng khi sai; UT_078 phải kiểm bốn trường.
  - Mục 8b: thêm 413 vào bảng ReferenceID (task.md nêu 410, 413 = phiếu kho); "store" → "store cha"; thêm ràng buộc khoá chia lô = khoá store cha; bỏ câu "hợp đồng ba trường không đổi"; dòng không ReferenceID thì header không được cộng.
  - Mục 11: bảng phủ UT_078 "bốn trường"; ghi chú kiểm cài lỗi của UT_078 áp cho kỳ vọng cũ, kỳ vọng mới chưa kiểm.
- D:\_AppAll\200133ebqueue\COSTING.md:
  - Mở đầu: ghi bởi hai store.
  - Mục 1: hợp đồng bốn trường; referenceID đổ vào cột ReferenceID của TVP cùng cách xử lý byte như detailID, triệu chứng khi sai.
  - Mục 5: gọi store con rồi store cha, cùng TVP, cùng transaction của lô (quyết định người dùng), vì sao + triệu chứng.
  - Mục 5a: "Store" → "Store cha", tìm chứng từ theo referenceID.

### Kết quả test
Chế độ rule, không sửa code, không chạy test. UT_078 (ebinventory) hiện vẫn kỳ vọng ba trường — test-writer cần đổi theo mục 7 mới.

### COSTING.md
Đã cập nhật COSTING.md: ebwebbe — sửa tiêu đề/bảng code, mục 1, 2, 8, 9
Đã cập nhật COSTING.md: ebinventory — sửa mục 7, 8b, 11 (chủ hợp đồng)
Đã cập nhật COSTING.md: ebqueue — sửa phần mở đầu, mục 1, 5, 5a (phía nhận hợp đồng)

### Điểm cần người dùng / reviewer xét
1. Dòng kết quả không có ReferenceID: store cha không cộng được header (store cũ thì có). Chưa kiểm DWH có dòng như vậy không — nếu có thì vi phạm yêu cầu 5 "kết quả tiền không đổi".
2. Tháo dỡ: đã ghi quy tắc dùng đơn giá thô từ TVP để giữ kết quả cũ; kiểu cột RSInwardOutWardDetail.MainUnitPrice chưa kiểm.
3. Dòng NVL lệnh lắp ráp: đã ghi giữ phạm vi "chỉ dòng 414 trong TVP" như cũ; mở rộng ra mọi dòng phiếu xuất là đổi hành vi, chưa có quyết định.

## Vòng 1 — chế độ code
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1: store con chỉ ghi mục 1–3; store cha cộng `GROUP BY` trên mọi dòng con trong DB, đi theo khoá không theo `CompanyID`, chạy sau store con cùng transaction; mục 2: ánh xạ `ReferenceID` → chứng từ cha (411/403 qua `RSInwardOutwardID`, 410/413/414/415 = phiếu kho, 420–422 = `RSTransfer.ID`); mục 6: nhân đơn giá thô rồi `ROUND`; mục 8: lắp ráp/tháo dỡ sang store cha, dòng NVL chỉ chép cho dòng 414 trong TVP, tháo dỡ dùng đơn giá thô từ TVP; mục 9: bảng tạm có khoá chính, store con bỏ sáu bảng tạm gom ID cha.
Đã đọc COSTING.md (ebinventory) — áp dụng mục 7: hợp đồng bốn trường, `referenceID` cùng dòng sổ kho và cùng quy ước byte với `detailID`; mục 11: `UT_078` kiểm bốn trường.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 1: `referenceID` đổ vào cột `ReferenceID` của TVP cùng cách xử lý byte như `detailID`; mục 5: trong transaction của lô gọi store con rồi store cha, cùng TVP.

### Thay đổi
- `D:\_AppInventory\ebinventory\src\main\java\vn\softdreams\ebinventory\domain\dto\CostingResult.java`: bỏ `@JsonIgnore` (và import) ở `referenceID`, sửa javadoc "ba trường" → bốn trường. Lý do: mục 7 hợp đồng bốn trường.
- `D:\_AppAll\200133ebqueue\src\main\java\ebqueue\rabbitmqconfig\InventoryCosting\CostingResultItem.java`: thêm `UUID referenceID` + getter/setter (bản mirror hợp đồng).
- `D:\_AppAll\200133ebqueue\src\main\java\ebqueue\repository\impl\InventoryCostingRepositoryImpl.java`: TVP thêm cột thứ tư `ReferenceID` (`Types.CHAR`, `toString()` y như `DetailID`, null → NULL); thêm `updateParentVouchers` gọi `{call update_InventoryCostingParent_TVP(?, ?)}` (TVP, `LamTronTienVN`), cùng khuôn với `updateVouchers`.
- `D:\_AppAll\200133ebqueue\src\main\java\ebqueue\repository\InventoryCostingRepository.java`: khai `updateParentVouchers`, sửa javadoc hai store.
- `D:\_AppAll\200133ebqueue\src\main\java\ebqueue\service\impl\InventoryCostingServiceImpl.java`: trong method `@Transactional` sẵn có gọi store con rồi store cha. Đã kiểm `DatabaseConfiguration`: `jdbcTemplate` dựng trên cùng bean `dataSource` với EMF của `JpaTransactionManager` → hai lần gọi chung connection/transaction.
- `D:\_AppAll\200133ebwebbe\dbchangelog_new\TVP_CostingResult.sql`: thêm cột `ReferenceID uniqueidentifier` (NULL được), danh sách store dùng TYPE thêm store cha. Trình tự deploy vẫn là: xoá cả hai store → xoá TYPE → tạo TYPE → tạo hai store (file không tự `DROP PROCEDURE`, giữ như cũ).
- `D:\_AppAll\200133ebwebbe\dbchangelog_new\stored_procedure\update_InventoryCostingParent_TVP.sql` (MỚI, CRLF như file store con):
  - `#CostingParent (ReferenceID, TypeID)` PK, bỏ dòng thiếu `ReferenceID`/`TypeID`; `#CostingAssembly (DetailID PK)` dòng 414/415 của lô.
  - Mục 1 lắp ráp/tháo dỡ: chép nguyên logic mục 4 store cũ (cùng thứ tự, cùng `CROSS APPLY` cho tổng NVL/tổng phiếu nhập thành phẩm, cùng `NULLIF`, tháo dỡ nhân đơn giá thô TVP rồi `ROUND`), chỉ bỏ `CompanyID`. Lệnh lắp ráp lấy từ dòng 414 của lô theo `DetailID` như store cũ (không qua phiếu xuất `ReferenceID`) — lý do ghi ở COSTING.md ebwebbe mục 8.
  - Mục 2 tổng header: thứ tự như store cũ (SAInvoice, SAReturn, phiếu kho 410/413/414/415, RSTransfer, phiếu kho của hoá đơn, phiếu kho của trả lại). Mỗi câu là `UPDATE ... INNER JOIN (SELECT ... GROUP BY)` mà tập dòng con được lọc từ `#CostingParent` trước khi `GROUP BY`; không `CompanyID`. Phiếu kho và chuyển kho lọc bằng `IN` để một phiếu có hai `TypeID` trong lô không bị cộng hai lần.
  - Kiểm cú pháp: `SET PARSEONLY ON` trên EB99_GR2 → không lỗi (chỉ parse, không tạo/chạy store).
- **`update_InventoryCosting_TVP.sql` (store con): CHƯA SỬA.** Lệnh xoá mục 4, 5 và sáu bảng tạm gom ID cha (xoá dòng 28–113 và 300–472 bằng `perl -i`) bị auto mode classifier từ chối; theo chỉ dẫn của lần từ chối, tôi không thử lại bằng công cụ khác. Hệ quả hiện tại: store con vẫn tính header + lắp ráp như cũ (có `CompanyID`), rồi store cha tính lại cùng giá trị trong cùng transaction → tiền đúng, nhưng phần đọc nặng chưa bỏ được và TC-W7, TC-W8 sẽ không đạt. Store con vẫn biên dịch được với TYPE bốn cột (chỉ đọc ba cột theo tên).

Kiểm dữ liệu metadata (chỉ đọc `sys.indexes`, `sys.columns`, EB99_GR2): `RSInwardOutWardDetail.MainUnitPrice` `decimal(25,10)` (= TVP); `RSAssemblyDismantlement.UnitPrice/Amount` `decimal(19,4)`; có index cho mọi đường đi header theo `ReferenceID` (`SAInvoice_RSInwardOutwardID_index`, `SAReturn_RSInwardOutwardID_index`, `idx_RSInwardOutwardDetail_RSInwardOutwardID`, `RSTransferDetail_RSTransferID_index`); không có index trên `RSAssemblyDismantlementID` ở `RSInwardOutWardDetail` và `RSAssemblyDismantlementDetail` (giống store cũ).

### Xử lý review
Không có file review ở vòng này.

### Kết quả test
`./mvnw test` ở `D:\_AppInventory\ebinventory` (JAVA_HOME = JDK 21) → Tests run: 78, Failures: 0, Errors: 0, BUILD SUCCESS (UT_078 xanh).
Cài lỗi theo gợi ý test-writer: truyền `row.detailID()` thay `row.referenceID()` ở `CostingServiceImpl.java:199` → 78 test, 5 đỏ, trong đó `UT_078` đỏ ở vế so giá trị `referenceID`; đã trả lại file y nguyên (`cmp` khớp bản sao lưu).
`./mvnw -o -q compile` ở `D:\_AppAll\200133ebqueue` → biên dịch xong (class mới 14:16). ebqueue/ebwebbe không có `src/test`; kịch bản tay TC-W1..W10, TC-Q1..Q4 trong `tests.md` chưa chạy (cần deploy TYPE + hai store lên DB test).

### COSTING.md
Đã cập nhật COSTING.md: ebwebbe — sửa bảng code (tên file store cha, tham số), mục 1 (thêm đoạn trạng thái store con chưa bỏ mục 4–5; ràng buộc 3 bổ sung bỏ `CompanyID` ở mọi câu + index đã kiểm; thêm ràng buộc 4 `GROUP BY` trên tập đã lọc, ràng buộc 5 lọc phiếu bằng `IN` chống cộng lặp; đoạn dòng thiếu `ReferenceID` cập nhật số liệu 0 dòng), mục 2 (dòng 414/415: lệnh tìm từ dòng của lô), mục 8 (lệnh tìm từ dòng 414/415 như store cũ + lý do; kiểu cột đã kiểm; index thiếu ở phần lắp ráp), mục 9 (`#CostingParent`, `#CostingAssembly`, trạng thái store con).
Đã cập nhật COSTING.md: ebqueue — sửa mục 5 (cách hiện thực hai lần gọi chung transaction và điều kiện để giữ được điều đó).
Đã cập nhật COSTING.md: ebinventory — sửa mục 8b (dòng thiếu `ReferenceID`: 0 dòng trên RepositoryLedger EB99_GR2), mục 11 (kỳ vọng bốn trường của `UT_078` đã kiểm bằng cài lỗi).

### Điểm cần người dùng / reviewer xét
1. **Cần quyền sửa `update_InventoryCosting_TVP.sql`** để bỏ dòng 28–113 (sáu bảng tạm gom ID cha) và 300–472 (mục 4, 5 và `DROP` sáu bảng tạm), giữ `DROP TABLE #CostingResult;`, `END;`, `GO`. Sau đó xoá đoạn "Trạng thái file store con" ở mục 1 và câu trạng thái ở mục 9 COSTING.md ebwebbe.
2. Thứ tự deploy giữa hai service: ebinventory gửi thêm `referenceID` — nếu ObjectMapper của ebqueue bật `FAIL_ON_UNKNOWN_PROPERTIES` thì phải deploy ebqueue trước (chưa kiểm cấu hình Jackson của ebqueue). ebqueue gọi store cha nên TYPE + store cha phải có trên DB trước khi deploy ebqueue.
3. Phần lắp ráp vẫn có câu có thể quét `RSInwardOutWardDetail`/`RSAssemblyDismantlementDetail` (thiếu index trên `RSAssemblyDismantlementID`) — như store cũ, ngoài phạm vi.

## Vòng 1 — chế độ code (tiếp, sau khi người dùng trả lời BLOCKED)
Đã đọc COSTING.md (ebwebbe) — áp dụng mục 1: store con chỉ ghi mục 1–3 (sổ kho/sổ cái → chứng từ gốc → chi tiết sổ cái), không cập nhật header, không lắp ráp/tháo dỡ, không gom ID cha; mục 9: store con không còn sáu bảng tạm gom ID cha.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 5: gọi store con rồi store cha cùng transaction (không đổi ở lần này).
Đã đọc COSTING.md (ebinventory) — áp dụng mục 7: hợp đồng bốn trường (không đổi ở lần này).
Căn cứ: task.md, Quyết định của người dùng (trả lời BLOCKED vòng code 1) cho phép xoá dòng 28–113 và 300–472 của store con.

### Thay đổi
- `D:\_AppAll\200133ebwebbe\dbchangelog_new\stored_procedure\update_InventoryCosting_TVP.sql`: đã đối chiếu số dòng trước khi xoá (dòng 28 bắt đầu ghi chú "Danh sách chứng từ cha...", 113 là dòng trống trước mục 1; dòng 300 bắt đầu mục 4, 472 là `DROP TABLE #RSTransferUpdate;`). Xoá dòng 28–113 (sáu bảng tạm `#SAInvoiceUpdate`, `#SAReturnUpdate`, `#RSInwardOutWardUpdate`, `#RSTransferUpdate`, `#RSAssemblyUpdate`, `#RSInwardOutWardAssemblyUpdate`) và 300–472 (mục 4 lắp ráp/tháo dỡ, mục 5 tổng header, sáu lệnh `DROP`). Giữ `DROP TABLE #CostingResult;`, `END;`, `GO`. File 475 → 216 dòng, CRLF 216/216. Không còn tham chiếu nào tới sáu bảng tạm (grep). Bản sao lưu trước khi xoá ở scratchpad phiên (`update_InventoryCosting_TVP.sql.bak`).
- Store con vẫn nhận `@CompanyID` và vẫn dùng nó ở mục 1, 3 (sổ kho, sổ cái, chi tiết sổ cái) — không thuộc phạm vi task (task chỉ nói bỏ gom ID cha và mục 4, 5).

### Xử lý review
Không có file review.

### Kết quả test
`./mvnw test` ở `D:\_AppInventory\ebinventory` (JAVA_HOME = JDK 21) → Tests run: 78, Failures: 0, Errors: 0, BUILD SUCCESS.
Store con: chưa kiểm cú pháp trên DB ở lần này (không có thông tin kết nối trong thư mục làm việc). Thay đổi chỉ là xoá nguyên khối câu lệnh độc lập; phần còn lại là khối đã chạy ở bản cũ. Kịch bản tay TC-W7 (store con không đụng header), TC-W8, TC-W1..W6, TC-Q1..Q4 trong tests.md chưa chạy — cần deploy TYPE + hai store lên DB test.

### COSTING.md
Đã cập nhật COSTING.md: ebwebbe — sửa mục 1 (xoá đoạn "Trạng thái file store con ... CHƯA bỏ", thay bằng câu triệu chứng nếu thêm lại việc của cha vào store con) và mục 9 (xoá câu trạng thái "chưa bỏ được").

### Điểm cần người dùng / reviewer xét
1. Trình tự deploy (giữ nguyên từ lượt trước): xoá cả hai store → xoá TYPE → tạo TYPE bốn cột → tạo store con, store cha → deploy ebqueue → deploy ebinventory. Deploy store con mới mà ebqueue chưa gọi store cha thì header và lắp ráp không được cập nhật.

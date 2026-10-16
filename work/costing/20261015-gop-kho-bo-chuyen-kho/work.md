## Vòng 1 — chế độ code
Đã đọc COSTING.md (ebinventory) — áp dụng mục 10: `byRepository = false` thì khoá nhóm `(MaterialGoodsID, null)`, mọi kho chung một đơn giá, chỉ gộp khi nhận đúng `false`; mục 1: đơn giá = (trị giá tồn đầu + trị giá nhập) / (SL tồn đầu + SL nhập); mục 4: chỉ 412, 230/231/232, 403 có luật riêng — chuyển kho chưa có luật; mục 11: test là định nghĩa của "đúng", không sửa test, chạy JDK 21.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 2: TypeID 420, 421, 422 cùng trỏ `RSTransferDetail.ID` (cả ba là chuyển kho); mục 1: hợp đồng ba trường không đổi.
Đã đọc COSTING.md (gogateway) — áp dụng mục 1: `ORDER BY MaterialGoodsID, RepositoryID, ...` nên khi gộp kho mọi dòng một vật tư vẫn liền nhau; không cần sửa gogateway.
Đã đọc COSTING.md (ebwebbe) — không có mục nào áp dụng; không sửa ebwebbe.

### Thay đổi
- `D:\_AppInventory\ebinventory\src\main\java\vn\softdreams\ebinventory\service\impl\CostingServiceImpl.java`:
  - `calculateByGroup` nhận thêm tham số `boolean byRepository` (truyền từ `calculate`, không tính lại cờ).
  - Thêm nhánh: `!byRepository && isTransfer(typeID)` thì bỏ dòng khỏi tổng nhập (cả dòng xuất kho đi lẫn dòng nhập kho đến), dòng có `mainOwQuantity != 0` vẫn đưa vào `pricedRows` để gán đơn giá bình quân. Nhánh đặt sau 412/403, trước "nhập thường".
  - Thêm `isTransfer(int)` dùng hằng `Constants.Type.CHUYEN_KHO`, `CHUYEN_KHO_GUI_DAI_LY`, `CHUYEN_KHO_CHUYEN_NOI_BO`.
  - Nguyên nhân gốc: code cũ coi dòng nhập kho đến (420/421/422) là nhập thường → mẫu số cộng thêm SL chuyển, tử số cộng trị giá cũ trên sổ của dòng chuyển kho (tự tham chiếu kết quả lần tính trước). Ở hiện trường: (400.000 + 90.000) / 25 = 19.600.
  - `byRepository = true/null`: hành vi chuyển kho không đổi.
- Hợp đồng gửi ebqueue không đổi (vẫn `detailID`, `typeID`, `mainUnitPrice`); chỉ gửi kết quả cho dòng xuất của chuyển kho, như trước đây.

### Kết quả test
`JAVA_HOME=".../jdk-21.0.10.7-hotspot" ./mvnw -q test` (ebinventory) → 70 test, 0 lỗi, 0 fail: CostingServiceImplTest 45/45, CostingResultSenderServiceImplTest 10/10, CostingQueueListenerTest 15/15. UT_068, UT_069, UT_070 từ đỏ thành xanh. (Stack trace trong log là log cố ý của các test listener báo lỗi, không phải test hỏng.)

### COSTING.md
Đã cập nhật COSTING.md: ebinventory — thêm mục 10a "Gộp kho thì bỏ chứng từ chuyển kho khỏi công thức (chốt 15/10/2026)" (X phải là Y, vì sao, triệu chứng thật 19.600/16.000, ghi rõ nhánh `byRepository = true` chưa được người dùng xác nhận); sửa mục 4 thêm dòng trỏ sang 10a; sửa mục 11: 67 → 70 test, thêm `UT_068` – `UT_070` vào bảng mã và bảng phủ (dòng "10a").
Không cập nhật COSTING.md của ebqueue/gogateway/ebwebbe vì không chạm hợp đồng hay code các repo đó.

### Lưu ý
- Chưa có test cho `byRepository = true` có chuyển kho: bỏ điều kiện `!byRepository` (tức bỏ chuyển kho cả khi tính riêng kho) có thể không làm đỏ test nào. Chưa kiểm bằng cài lỗi. Hành vi đúng ở nhánh này người dùng chưa chốt.
- Chưa chạy lại kiểm cài lỗi cho mục 10a (bảng mục 11 nói 17 lỗi đã kiểm ngày 13/10/2026, không bao gồm 10a).
- Mục 1 COSTING.md vẫn ghi "Tính riêng cho từng cặp (MaterialGoodsID, RepositoryID)" trong khi mục 10 cho phép gộp — lệch có từ trước, ngoài phạm vi, chưa sửa.
- Chưa kiểm đầu-cuối theo kịch bản thủ công trong tests.md (cần môi trường thật).

## Vòng 2 — chế độ code
Đã đọc COSTING.md (ebinventory) — áp dụng mục 10: `true`/`null` gom theo `(MaterialGoodsID, RepositoryID)`, `null` phải giữ cách tính riêng từng kho; mục 10a: gộp kho thì bỏ 420/421/422 khỏi tử số và mẫu số, dòng xuất vẫn được gán giá; `true` giữ cách cũ; mục 11: test "phủ" một mục chỉ khi cài lỗi đúng bất biến đó thì đỏ, test ghi nhận hiện trạng phải liệt kê riêng (tiền lệ UT_005, UT_033).

### Thay đổi
- Không sửa code. `CostingServiceImpl.java` giữ nguyên bản vòng 1; [B1] là thiếu test, đã được test-writer bổ sung UT_071, UT_072 (tests.md vòng 2).
- `D:\_AppInventory\ebinventory\COSTING.md`: xem mục COSTING.md bên dưới.

### Xử lý review (review_1.md)
- [B1] Đã sửa (phần thuộc dev): test-writer thêm UT_071 (`byRepository = true`) và UT_072 (`null`), đã kiểm cài lỗi xoá vế `!byRepository &&` → cả hai đỏ (X2 expected 20000 but was 30000). Dev cập nhật bảng phủ mục 11: dòng 10a thêm UT_071, UT_072 cho điều kiện "chỉ khi gộp kho"; ghi kết quả kiểm cài lỗi 15/10/2026; thêm UT_071, UT_072 vào danh sách test ghi nhận hiện trạng.
- [N1] Đã sửa: mục 10a tách "Triệu chứng thật" (chỉ còn 19.600) khỏi đoạn "Cơ chế (suy ra, không quan sát trực tiếp)": 90.000 ghi rõ là tính ngược từ 19.600 × 25 − 400.000; 16.000 ghi rõ là dựng lại trong UT_069, không phải số thấy ở hiện trường.
- [N2] Đã sửa: mục 1 đổi "Tính riêng cho từng cặp (MaterialGoodsID, RepositoryID)" thành "từng nhóm: cặp (MaterialGoodsID, RepositoryID) khi tính riêng từng kho, hoặc chỉ MaterialGoodsID khi gộp kho — xem mục 10". Rẻ, và để nguyên thì file mâu thuẫn với chính mục 10/10a mà vòng này vừa thêm.
- [N3] Đã sửa: câu "Mỗi bất biến ở trên đều có test khẳng định bằng số cụ thể" đổi thành có test bằng số cụ thể, trừ chỗ ghi rõ chưa có test (mục 5 `AutoOWAmountCal` NULL), kèm trỏ tới danh sách test ghi nhận hiện trạng. Câu cuối mục 10a đổi từ "chưa có test khẳng định" thành: người dùng chưa xác nhận là đúng nghiệp vụ, UT_071/UT_072 chỉ ghi nhận hiện trạng.
- Mục "Không chắc" của review (luồng cũ ebwebbe→ebqueue, tập kho bị lọc khi gộp, kịch bản thủ công): không thuộc phạm vi sửa ở vòng này, để người giao việc xác nhận; không sửa gì.

### Kết quả test
`JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-21.0.10.7-hotspot" ./mvnw test` (ebinventory) → Tests run: 72, Failures: 0, Errors: 0, Skipped: 0 (CostingServiceImplTest 47, CostingResultSenderServiceImplTest 10, CostingQueueListenerTest 15). BUILD SUCCESS.

### COSTING.md
Đã cập nhật COSTING.md: ebinventory — sửa mục 1 (nhóm theo cờ gộp kho), sửa mục 10a (tách triệu chứng quan sát khỏi số suy ra; nhánh true/null có UT_071/UT_072 ghi nhận hiện trạng), sửa mục 11 (70 → 72 test, bảng mã UT_068 – UT_072, bảng phủ 10a thêm UT_071/UT_072, ghi kết quả kiểm cài lỗi 15/10/2026, câu "mọi bất biến đều có test" cho khớp, danh sách test ghi nhận hiện trạng thêm UT_071/UT_072). File giữ CRLF.
Không cập nhật COSTING.md của ebqueue/gogateway/ebwebbe vì không chạm hợp đồng hay code các repo đó.

### Lưu ý
- Câu "UT_068 – UT_070 đỏ trên code trước bản sửa" trong mục 11 dựa vào kết quả test-writer vòng 1 (tests.md), không phải lần cài lỗi riêng xoá nhánh chuyển kho.

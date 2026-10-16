# Review vòng 1

## Đã kiểm
Đã đọc COSTING.md (ebinventory). Đối chiếu các mục:
- Mục 1: công thức bình quân; câu "tính riêng cho từng cặp (MaterialGoodsID, RepositoryID)".
- Mục 4: chỉ 412, 230/231/232, 403 có luật riêng. Diff thêm dòng trỏ sang 10a.
- Mục 7: hợp đồng gửi ebqueue gồm ba trường. Diff không đổi hợp đồng.
- Mục 10: chỉ gộp kho khi nhận đúng `false`; `null` giữ cách tính riêng từng kho.
- Mục 10a (mới): khi gộp kho thì bỏ 420/421/422 khỏi cả tử số lẫn mẫu số, dòng xuất vẫn được gán giá.
- Mục 11 (dòng 180): một test chỉ được coi là "phủ" một mục khi phá đúng bất biến của mục đó thì test đỏ.

Đã đọc COSTING.md (ebqueue):
- Mục 1: hợp đồng ba trường.
- Mục 2: 420/421/422 trỏ tới `RSTransferDetail.ID`.

Đã đọc COSTING.md (gogateway):
- Mục 1: `ORDER BY MaterialGoodsID, RepositoryID, ...`, nên khi gộp kho mọi dòng của một vật tư vẫn nằm liền nhau.

Đã đọc COSTING.md (ebwebbe):
- Mục 7: dòng xuất ghi `OWAmount`, dòng nhập ghi `IWAmount`.
- Đã đối chiếu thêm store `D:\_AppAll\200133ebwebbe\dbchangelog_new\stored_procedure\update_InventoryCosting_TVP.sql:121-139`. Store cập nhật `RepositoryLedger` bằng JOIN theo `DetailID`. Vì vậy chỉ gửi kết quả cho dòng xuất thì dòng nhập ở kho đến (cùng `DetailID`) cũng được ghi `IWAmount`. Việc code không đưa dòng nhập kho đến vào `pricedRows` là đúng.

Test: chạy `JAVA_HOME=jdk-21.0.10.7-hotspot ./mvnw test` ở `D:\_AppInventory\ebinventory` → 70 test, 0 đỏ (CostingServiceImplTest 45, CostingResultSenderServiceImplTest 10, CostingQueueListenerTest 15). BUILD SUCCESS. Chạy bằng JDK mặc định thì enforcer chặn vì không phải JDK 21; lần chạy đó không tính.

Diff:
- ebinventory: 4 file.
  - `COSTING.md`: thêm mục 10a, sửa mục 4 và mục 11.
  - `src/main/.../service/impl/CostingServiceImpl.java`: thêm tham số `byRepository` cho `calculateByGroup`, thêm nhánh `!byRepository && isTransfer(...)`, thêm hàm `isTransfer`.
  - `src/test/.../CostingServiceImplTest.java`: thêm UT_068 đến UT_070 và hàm `assertAllPricedAt`.
  - `src/test/.../CostingTestData.java`: thêm `transferOutward` và `transferInward`.
- ebwebbe, ebqueue, gogateway: HEAD trùng base. Không có thay đổi nào ngoài các file đã có sẵn từ trước mà task.md đã liệt kê.

## BLOCKING
- [B1] Không có test nào chặn việc phá điều kiện "chỉ khi gộp kho". Vì vậy bảng phủ ở mục 11 ghi "10a — UT_068 đến UT_070" là phủ không đủ, theo đúng định nghĩa phủ của chính COSTING.md.
  - Bằng chứng 1: cả ba test mới đều gọi `calculate(..., false)` (`CostingServiceImplTest.java:653-712`).
  - Bằng chứng 2: grep `CHUYEN_KHO|420|421|422|transfer` trong `src/test/java` chỉ ra ba test mới này. Không có test nào chứa dòng chuyển kho với `byRepository = true/null`.
  - Hệ quả: xoá vế `!byRepository &&` ở `CostingServiceImpl.java:173` thì cả 70 test vẫn xanh. Khi đó luồng mặc định (true/null) của mọi công ty sẽ bỏ dòng nhập kho đến ra khỏi nhóm của kho đến, tức đổi số liệu ngoài phạm vi task, mà mục 10 lại yêu cầu true/null phải giữ cách cũ.
  - COSTING.md `D:\_AppInventory\ebinventory\COSTING.md:180` định nghĩa "Một test phủ một mục chỉ khi phá đúng bất biến của mục đó thì test đỏ". Dòng 178 vẫn ghi 10a được UT_068 đến UT_070 phủ.
  - Dev đã tự thừa nhận trong mục Lưu ý của work.md là chưa kiểm bằng cài lỗi.
  - Cần một test ghi nhận hiện trạng nhánh true/null khi có chuyển kho, tiền lệ là UT_005 và UT_033 ở mục 11. Test đó khẳng định "bản sửa này không đổi kết quả tính riêng từng kho", không khẳng định nghiệp vụ nhánh true là đúng.
  - Checklist: 16, 1.

## NON-BLOCKING
- [N1] COSTING.md 10a (dòng 140) viết dưới tiêu đề "Triệu chứng thật" hai con số không quan sát được ở hiện trường:
  - "90.000 ở hiện trường": task.md chỉ ghi nhận 98.000 (sau lần chạy) và đơn giá 19.600. Con số 90.000 là tính ngược từ 19.600 × 25 − 400.000.
  - "Lần tính đầu ... ra 16.000": đây là con số suy ra (UT_069), không phải số đã thấy.
  - Nên ghi rõ đó là số suy ra, để người đọc sau không coi là dữ liệu đã quan sát.
- [N2] COSTING.md mục 1 (dòng 28) vẫn ghi "Tính riêng cho từng cặp (MaterialGoodsID, RepositoryID)", mâu thuẫn với mục 10 và 10a. Lệch này có từ trước, dev đã nêu.
- [N3] Dòng 155 của COSTING.md ghi "Mỗi bất biến ở trên đều có test khẳng định bằng số cụ thể", nhưng chính đoạn cuối mục 10a (dòng 142) ghi nhánh true "chưa có test khẳng định". Hai câu trái nhau trong cùng file.

## Phản biện vòng trước (từ vòng 2)
Không áp dụng (vòng 1).

## Không chắc
- Luồng cũ ebwebbe → ebqueue (proc tính giá cũ, dành cho công ty chưa bật FeatureToggle `COSTING_CODE`) có thể vẫn tính sai đúng như bug này khi gộp kho. Chưa kiểm proc cũ. Theo memory thì ebinventory là bản thay thế, nên có thể ngoài phạm vi. Cần người giao việc xác nhận còn công ty nào chạy luồng cũ hay không.
- Khi `byRepository = false`, code đúng chỉ khi ebwebbe gửi đủ mọi kho. Nếu tập kho bị lọc, dòng nhập kho đến từ một kho ngoài phạm vi là nhập thật nhưng vẫn bị bỏ. Mục 10 COSTING.md và `AsyncCalculateOWPriceServiceImpl.java:175,819` cho thấy lúc này lấy mọi kho, nhưng chưa lần tới chỗ dựng `repositoryIDs` để khẳng định chắc chắn.
- Kịch bản thủ công ở bước 3–5 của tests.md (dòng CK có thành tiền 100.000 ở cả kho đi lẫn kho đến, chạy lại lần hai không đổi) chưa được chạy trên môi trường thật. Cần chạy để xác nhận store ghi `IWAmount` cho dòng nhập kho đến như phân tích ở trên.

VERDICT: FAIL

## Vòng 1
Đã đọc COSTING.md (ebinventory) — áp dụng mục 10: `byRepository = false` thì khoá nhóm là `(MaterialGoodsID, null)`, mọi kho chung một đơn giá; mục 1: đơn giá = (trị giá tồn đầu + trị giá nhập) / (SL tồn đầu + SL nhập); mục 4: chỉ 412, 230/231/232, 403 có luật riêng — chuyển kho (420/421/422) **chưa có luật nào**, đây chính là chỗ thiếu; mục 11: mã test lấy kế tiếp (UT_068), so tiền bằng `isEqualByComparingTo`, chạy bằng JDK 21.
Đã đọc COSTING.md (ebqueue) — áp dụng mục 2: TypeID 420, 421, 422 cùng trỏ `RSTransferDetail.ID`, tức cả ba đều là chứng từ chuyển kho.
Đã đọc COSTING.md (gogateway) — áp dụng mục 1: `ORDER BY MaterialGoodsID, RepositoryID, ...` nên dữ liệu test xếp dòng K1 trước K2.
Đã đọc COSTING.md (ebwebbe) — không có mục nào áp dụng trực tiếp cho test này.

Căn cứ kỳ vọng: mục *Quyết định của người dùng* trong `task.md` (gộp kho thì bỏ chứng từ chuyển kho khỏi công thức, đơn giá đúng 20.000). COSTING.md ebinventory **chưa có** quy tắc này — dev phải bổ sung (kèm ngày 15/10/2026 và triệu chứng 19.600) và cập nhật bảng mục 11 (thêm UT_068 – UT_070, tổng số test 70).

### Test đã thêm/sửa
- `D:\_AppInventory\ebinventory\src\test\java\vn\softdreams\ebinventory\service\impl\CostingServiceImplTest.java::allRepositories_transferExcludedFromAverage` (UT_068) — tái hiện đúng kịch bản người dùng: nhập K1 10/100.000, nhập K2 10/300.000, CK 420 K1→K2 SL 5, dòng nhập kho đến mang sẵn 98.000 (như sổ chi tiết); `byRepository = false` → đơn giá CK1 = 20.000. Kỳ vọng: mục 1 + mục 10 + quyết định người dùng trong task.md.
- `...CostingServiceImplTest.java::allRepositories_transferWithoutAmount_unitPriceUnchanged` (UT_069) — cùng dữ liệu nhưng dòng chuyển kho chưa có trị giá (lần tính đầu), thêm phiếu xuất bán X1 (K1), X2 (K2): CK1, X1, X2 đều 20.000. Chặn cách sửa "chỉ đúng khi trị giá chuyển kho = 0" và khẳng định đơn giá không phụ thuộc trị giá đang nằm trên dòng chuyển kho. Kỳ vọng: như trên.
- `...CostingServiceImplTest.java::allRepositories_agentAndInternalTransfersExcludedFromAverage` (UT_070) — CK 421 (K1→K2, SL 5) và CK 422 (K2→K1, SL 3), cả hai bỏ khỏi công thức → 20.000. Kỳ vọng: quyết định người dùng + ebqueue mục 2 (420/421/422 đều là chuyển kho).
- `...CostingServiceImplTest.java::assertAllPricedAt` — hàm trợ giúp: DetailID phải có ít nhất một dòng kết quả và mọi dòng kết quả của nó cùng đơn giá (một DetailID chuyển kho sinh hai dòng sổ kho). Không khẳng định số dòng kết quả.
- `D:\_AppInventory\ebinventory\src\test\java\vn\softdreams\ebinventory\service\impl\CostingTestData.java::transferOutward`, `::transferInward` — dựng dòng xuất ở kho đi / dòng nhập ở kho đến của chứng từ chuyển kho, cùng DetailID.

### Kết quả chạy
`JAVA_HOME=jdk-21.0.10.7 ./mvnw test` (ebinventory) → 70 test, 3 đỏ, 67 test cũ xanh:
- UT_068 `allRepositories_transferExcludedFromAverage`: expected 20000, but was 19920
- UT_069 `allRepositories_transferWithoutAmount_unitPriceUnchanged`: expected 20000, but was 16000
- UT_070 `allRepositories_agentAndInternalTransfersExcludedFromAverage`: expected 20000, but was 19285.71428571429

Nguyên nhân thấy qua test: `CostingServiceImpl.calculateByGroup` (`src/main/java/vn/softdreams/ebinventory/service/impl/CostingServiceImpl.java:171-172`) cộng `mainIwQuantity`/`iwAmount` của dòng nhập kho đến (420/421/422) vào tổng nhập, trong khi dòng xuất kho đi không trừ ra. 19.600 ngoài hiện trường = (400.000 + 90.000) / 25, tức dòng nhập kho đến lúc đó mang 90.000 từ lần tính trước — đúng cơ chế này, chỉ khác trị giá còn trên sổ.

Test đỏ mong đợi (chờ dev sửa code): UT_068, UT_069, UT_070.

### Kịch bản thủ công (nếu có)
gogateway, ebqueue, ebwebbe không có bộ test tự động cho phần này; bug nằm ở ebinventory nên chỉ cần kiểm đầu-cuối một lần sau khi dev sửa:
1. Dữ liệu: mã hàng mới, PN 15/09/2026 kho K1 SL 10 GT 100.000; PN 05/10/2026 kho K2 SL 10 GT 300.000; CT chuyển kho 10/10/2026 K1→K2 SL 5.
2. Chạy TGXK bình quân cuối kỳ, kỳ 01/01/2026 – 31/10/2026, bỏ chọn "tính theo kho" (`byRepository = false`).
3. Mong đợi: sổ chi tiết VTHH dòng CK cả xuất (K1) lẫn nhập (K2) đơn giá 20.000, thành tiền 100.000.
4. Chạy TGXK lần hai cùng tham số: kết quả không đổi (20.000) — kiểm trị giá cũ trên dòng chuyển kho không còn ảnh hưởng.
5. Đối chiếu:
```sql
SELECT
    rlg.RepositoryID   AS RepositoryID,
    rlg.TypeID         AS TypeID,
    rlg.MainIWQuantity AS MainIWQuantity,
    rlg.MainOWQuantity AS MainOWQuantity,
    rlg.IWAmount       AS IWAmount,
    rlg.OWAmount       AS OWAmount
FROM RepositoryLedger rlg
WHERE rlg.CompanyID = :companyId
  AND rlg.MaterialGoodsID = :materialGoodsId
  AND rlg.TypeID IN (420, 421, 422)
```
Mong đợi: dòng xuất `OWAmount = 100000`, dòng nhập `IWAmount = 100000`.
6. Hồi quy: chạy lại cùng dữ liệu với "tính theo kho" (`byRepository = true`) — test này **không** khẳng định kỳ vọng cho trường hợp này vì task.md và COSTING.md chưa quy định; chỉ ghi lại kết quả để người dùng xác nhận.

## Vòng 2
Đã đọc COSTING.md (ebinventory) — áp dụng mục 10: `true`/`null` gom theo `(MaterialGoodsID, RepositoryID)`, `null` phải giữ cách tính riêng từng kho; mục 10a: luật bỏ 420/421/422 chỉ áp dụng khi `byRepository = false`, còn `true` thì dòng nhập kho đến cộng vào nhóm kho đến như phiếu nhập, dòng xuất kho đi được gán giá (hiện trạng, người dùng chưa xác nhận); mục 11: test "phủ" một mục chỉ khi cài lỗi đúng bất biến đó thì test đỏ, mã test lấy kế tiếp (UT_071), so tiền bằng `isEqualByComparingTo`, test ghi nhận hiện trạng phải nói rõ trong javadoc (tiền lệ UT_005, UT_033).

Xử lý review_1: chỉ mục [B1] (thiếu test chặn điều kiện "chỉ khi gộp kho"). [N1], [N2], [N3] là nội dung COSTING.md, thuộc phần dev.

### Test đã thêm/sửa
- `D:\_AppInventory\ebinventory\src\test\java\vn\softdreams\ebinventory\service\impl\CostingServiceImplTest.java::byRepository_transferInwardStillCountedAtDestination` (UT_071) — **ghi nhận hiện trạng**, `byRepository = true`: nhập K1 20/200.000, CK 420 K1→K2 SL 10 (dòng nhập kho đến mang 100.000), nhập K2 10/300.000, mỗi kho xuất bán 1. Kỳ vọng X1 = CK1 = 10.000 (200.000/20), X2 = 20.000 ((300.000+100.000)/20). Căn cứ: mục 10 (true giữ cách tính riêng từng kho) + đoạn cuối mục 10a (true giữ cách cũ). Javadoc ghi rõ không khẳng định nghiệp vụ đúng.
- `...CostingServiceImplTest.java::byRepositoryNull_transferInwardStillCountedAtDestination` (UT_072) — cùng dữ liệu, `byRepository = null`, cùng kỳ vọng. Căn cứ: mục 10 (null giữ cách tính riêng từng kho).
- `...CostingServiceImplTest.java::ledgerWithTransferBetweenRepositories`, `::assertPerRepositoryTransferUnchanged` — dữ liệu và kiểm tra dùng chung cho UT_071, UT_072.

### Kết quả chạy
`JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-21.0.10.7-hotspot" ./mvnw test` (ebinventory, code hiện tại đã có bản sửa của dev) → 72 test (CostingServiceImplTest 47, CostingResultSenderServiceImplTest 10, CostingQueueListenerTest 15), 0 đỏ.

Kiểm bằng cài lỗi (trên bản sao repo ở scratchpad, đã xoá sau khi chạy; không sửa code sản phẩm thật): xoá vế `!byRepository &&` tại `CostingServiceImpl.java:173` → 72 test, 2 đỏ: UT_071 và UT_072, cả hai `X2 expected 20000 but was 30000`. Tức UT_071/UT_072 phủ đúng điều kiện "chỉ khi gộp kho" của mục 10a.

Test đỏ mong đợi (chờ dev sửa code): không có. UT_071, UT_072 là test hồi quy, xanh trên code hiện tại là đúng.

Việc dev cần làm ở COSTING.md (ebinventory) mục 11 (không thuộc quyền test-writer): tổng số test 70 → 72; bảng mã thêm `UT_071` – `UT_072` thuộc `CostingServiceImplTest`; bảng phủ dòng 10a thêm `UT_071`, `UT_072`; danh sách test "ghi nhận hiện trạng" thêm UT_071, UT_072; sửa câu cuối mục 10a "chưa có test khẳng định" cho khớp (test chỉ ghi nhận hiện trạng, không khẳng định nghiệp vụ).

### Kịch bản thủ công (nếu có)
Không thay đổi so với vòng 1.

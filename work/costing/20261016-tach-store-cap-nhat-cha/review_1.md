# Review vòng 1

## Đã kiểm
Đã đọc COSTING.md (ebwebbe) — đối chiếu mục 1: store con chỉ làm mục 1–3, store cha cộng `GROUP BY` mọi dòng con trong DB, chạy sau store con trong cùng transaction, không lọc `CompanyID`, ràng buộc 4 (`GROUP BY` trên tập đã lọc) và 5 (lọc phiếu kho bằng `IN`); mục 2: ánh xạ `ReferenceID` sang chứng từ cha (411/403 qua `RSInwardOutwardID`); mục 6: nhân với đơn giá thô rồi mới `ROUND`; mục 8: lắp ráp/tháo dỡ chuyển sang store cha, dòng NVL chỉ chép cho dòng 414 có trong TVP, tháo dỡ lấy đơn giá thô từ TVP; mục 9: bảng tạm có khoá chính, store con bỏ sáu bảng tạm.
Đã đọc COSTING.md (ebinventory) — đối chiếu mục 7: hợp đồng bốn trường, `referenceID` lấy từ cùng dòng sổ kho với `detailID`; mục 8b: khoá chia lô và khoá store cha cùng là `ReferenceID`; mục 9: quy ước byte GUID; mục 11: 78 test, `UT_078` kiểm bốn trường.
Đã đọc COSTING.md (ebqueue) — đối chiếu mục 1: `referenceID` đổ vào cột `ReferenceID` của TVP, xử lý byte giống `detailID`; mục 5: gọi store con rồi store cha trong một `@Transactional`, chung transaction nhờ `jdbcTemplate` dùng cùng bean `dataSource`; mục 5a.
Test: `JAVA_HOME=jdk-21.0.10.7 ./mvnw test` ở `D:\_AppInventory\ebinventory` → 78 test, 0 đỏ, BUILD SUCCESS. Với JDK mặc định (17), enforcer chặn trước khi chạy test.
Diff (đã trừ phần có trong `baseline/*.diff`):
- ebwebbe: 4 file — `COSTING.md`, `dbchangelog_new/TVP_CostingResult.sql`, `dbchangelog_new/stored_procedure/update_InventoryCosting_TVP.sql` (xoá sáu bảng tạm gom ID cha, mục 4, mục 5), `dbchangelog_new/stored_procedure/update_InventoryCostingParent_TVP.sql` (file mới, chưa track).
- ebinventory: 3 file — `COSTING.md`, `domain/dto/CostingResult.java` (bỏ `@JsonIgnore`), `CostingResultSenderServiceImplTest.java` (`UT_078`).
- ebqueue: 5 file — `COSTING.md`, `CostingResultItem.java`, `InventoryCostingRepository.java`, `InventoryCostingRepositoryImpl.java`, `InventoryCostingServiceImpl.java`.
- gogateway: task.md ghi không sửa; tôi không kiểm repo này.

Đối chiếu store cha với các khối đã xoá ở store con (bản base c31c22d4):
- Phần lắp ráp/tháo dỡ giữ đúng thứ tự và cùng câu lệnh, chỉ bỏ `CompanyID`. Đơn giá tháo dỡ lấy từ `#CostingAssembly` (TVP).
- Tổng header giữ thứ tự cũ.
- Ánh xạ: 411/403 đi qua `RSInwardOutwardID`; 410/413/414/415 và 420–422 lọc bằng `IN`.
- Thứ tự cột TVP khớp nhau ở Java (`InventoryCostingRepositoryImpl.buildCostingResultTVP`) và ở TYPE (`TVP_CostingResult.sql:15-21`).
- `DatabaseConfiguration` có `@Configuration`, và `jdbcTemplate()` gọi `dataSource()` (dòng 146-147), nên dùng cùng bean với EMF của `JpaTransactionManager`. Hai store chung một transaction.
- Chưa chạy trên DB nên chưa chứng minh được tiền không đổi (xem Không chắc).

## BLOCKING
Không có

## NON-BLOCKING
- [N1] COSTING.md ebwebbe mục 1 ràng buộc 3 viết "kể cả sổ kho/sổ cái dòng 404 (đi theo `DetailID`, có index)". Danh sách index đã kiểm ngay sau câu đó và phần "Kiểm dữ liệu metadata" trong work.md đều không có index nào trên `RepositoryLedger.DetailID` hay `GeneralLedger.DetailID`. Câu "có index" hiện không có nguồn. Store cũ có `rgl.CompanyID = @CompanyID` / `glg.CompanyID = @CompanyID`; store cha bỏ điều kiện này (`update_InventoryCostingParent_TVP.sql:140-160`). Nếu index thật sự là `(CompanyID, DetailID)` thì hai câu 404 có thể quét toàn bảng. Đề nghị kiểm `sys.indexes`, rồi sửa câu trong COSTING.md cho đúng số liệu thật.
- [N2] Thứ tự deploy (work.md đã nêu): DB đổi TYPE sang bốn cột thì ebqueue cũ (TVP ba cột, `InventoryCostingRepositoryImpl` bản base) gọi store sẽ lỗi. Store con mới đã deploy mà ebqueue chưa gọi store cha thì header và lắp ráp không được cập nhật. Chiều ngược lại an toàn: `CommonService.getObjectMapper()` đặt `FAIL_ON_UNKNOWN_PROPERTIES = false` (`ebqueue/rabbitmqconfig/CommonService.java:44`), nên ebinventory mới gửi tới ebqueue cũ không lỗi parse. Câu hỏi mở ở work.md mục "Điểm cần xét" 2 đã có câu trả lời này. Thứ tự deploy chưa được ghi vào COSTING.md ebwebbe/ebqueue mà chỉ có trong work.md.
- [N3] tests.md vẫn gọi store cha là `<StoreCha>`, trong khi tên thật là `update_InventoryCostingParent_TVP`.

## Phản biện vòng trước (từ vòng 2)
Không áp dụng (vòng 1).

## Không chắc
- Yêu cầu 5 của task (tiền không đổi) chưa được kiểm bằng chạy thật: TC-W1..W10 và TC-Q1..Q4 đều chưa chạy (work.md, "Kết quả test" lượt cuối). Sau lần xoá khối, store con chưa được parse trên DB; tôi đọc lại toàn file (216 dòng) và không thấy lỗi cú pháp. Cần chạy ít nhất TC-W1, W2, W5, W6 (so `EXCEPT` với store cũ) và TC-W10 trên DB test.
- Ánh xạ `ReferenceID` cho 403 và 410/413/414/415 chỉ dựa trên xác nhận của người dùng. Mẫu 20.000 dòng chỉ kiểm 411 và 420–422 (COSTING.md ebinventory mục 8b). Nếu có dòng 403 mà `RepositoryLedger.ReferenceID` không trùng `SAReturn.RSInwardOutwardID`, hoặc dòng 410/414/415 mà `ReferenceID` khác `RSInwardOutWardDetail.RSInwardOutwardID`, thì store cũ vẫn cộng header còn store mới bỏ qua, không báo lỗi. Cần đếm trên EB99_GR2: số dòng `RepositoryLedger` 403 có `ReferenceID NOT IN (SELECT RSInwardOutwardID FROM SAReturn)`, và số dòng 410/413/414/415 join `RSInwardOutWardDetail` theo `DetailID` mà `ReferenceID <> rsd.RSInwardOutwardID`.
- COSTING.md ebinventory mục 11 ghi lời khai cài lỗi `row.detailID()` thay cho `row.referenceID()` làm `UT_078` đỏ (work.md: 5 đỏ). Tôi không sửa file nên không tự cài lỗi để kiểm lại được. Đọc code test (`CostingResultSenderServiceImplTest.java:353-376`) thì vế so `referenceByDetail.get(detailID)` sẽ đỏ trong tình huống đó.

VERDICT: PASS

# Task

## Yêu cầu
Tách việc cập nhật chứng từ cha ra khỏi store `update_InventoryCosting_TVP` (tính giá xuất kho bình quân cuối kỳ, luồng ebinventory → ebqueue). Nguyên văn ý người dùng: "Hiện tại cái bước update cha rất rối. Nên cái tôi mong muốn ấy là tách ra … sau khi update update_InventoryCosting_TVP, mình đã chia con theo cha rồi thì tất cả con thay đổi đã save rồi, chỉ cần select lên + save lại tổng theo con thôi, ID thì được truyền từ referenceID rồi."

Thiết kế đã thống nhất:
1. `update_InventoryCosting_TVP` **chỉ cập nhật dòng con**: sổ kho, sổ cái, chi tiết chứng từ (mục 1, 2, 3 hiện tại). Bỏ toàn bộ phần gom ID cha (các bảng tạm `#SAInvoiceUpdate`, `#SAReturnUpdate`, `#RSInwardOutWardUpdate`, `#RSTransferUpdate`, `#RSAssemblyUpdate`, `#RSInwardOutWardAssemblyUpdate`) và phần tính tổng/lắp ráp (mục 4, 5 hiện tại).
2. Thêm **một store mới chỉ cập nhật chứng từ cha**. Store này nhận các `ReferenceID` của lô, đọc lại toàn bộ dòng con của các chứng từ cha đó trong DB (con của lô đã được lưu ở bước 1), tính tổng bằng `GROUP BY` và lưu. Đi thẳng từ ID cha theo khoá chính, không để `CompanyID` dẫn đường.
   - Tổng phải cộng **mọi dòng con của chứng từ cha trong DB**, không chỉ dòng có trong lô (trường hợp chỉ tính giá một phần vật tư của chứng từ).
   - Phần lắp ráp/tháo dỡ (mục 4 hiện tại: dòng NVL lệnh lắp ráp, tổng NVL → giá thành phẩm, dòng nhập thành phẩm trên phiếu kho, tổng phiếu nhập thành phẩm, sổ kho 404, sổ cái, lệnh tháo dỡ) chuyển sang store cha, giữ nguyên quy tắc nghiệp vụ.
   - Ánh xạ `ReferenceID` → chứng từ cha (đã kiểm dữ liệu ở task trước):
     - 411: `ReferenceID` = phiếu kho; hoá đơn là `SAInvoice` có `RSInwardOutwardID = ReferenceID` (1-1). Cập nhật tổng hoá đơn và tổng phiếu kho đi kèm hoá đơn.
     - 403: `ReferenceID` = phiếu kho; `SAReturn` có `RSInwardOutwardID = ReferenceID` (người dùng xác nhận 1-1). Cập nhật tổng hàng bán trả lại và phiếu kho đi kèm.
     - 410, 413: `ReferenceID` = phiếu kho `RSInwardOutward`.
     - 414, 415: `ReferenceID` = phiếu xuất kho của lệnh lắp ráp/tháo dỡ (mỗi lệnh đúng một phiếu xuất, dữ liệu kiểm 16/10: 0 lệnh có hơn một phiếu xuất).
     - 420, 421, 422: `ReferenceID` = `RSTransfer.ID`.
3. **Truyền `ReferenceID` sang ebqueue**: thêm trường `referenceID` vào bản tin kết quả (bỏ `@JsonIgnore` ở ebinventory), thêm cột `ReferenceID` vào `TVP_CostingResult`; cả hai store dùng chung một TVP. Đổi TYPE phải theo trình tự: xoá store đang dùng TYPE → xoá TYPE → tạo lại TYPE → tạo lại store (ghi chú sẵn trong `TVP_CostingResult.sql`).
4. **Hai store chạy trong cùng một transaction của lô** ở ebqueue: lô lỗi thì cả con lẫn cha rollback cùng nhau.
5. Kết quả tiền (đơn giá, thành tiền, tổng header, giá thành phẩm lắp ráp) **không đổi** so với hiện tại cho cùng dữ liệu.
6. Giữ nguyên các phần đã làm ở task trước: chia lô theo chứng từ cha (ebinventory), TaskLogDetail theo lô + khoá `UPDLOCK` + đóng TaskLog theo `batchTotal` (ebqueue), ebwebbe chỉ tạo TaskLog.

## Loại việc
rule-change

## Repo
- ebwebbe: D:\_AppAll\200133ebwebbe — base: c31c22d4b445c61981c5af2bb3bb205ba82fc829 (branch features/truongtd/tgxk)
- ebinventory: D:\_AppInventory\ebinventory — base: 27109e2e130bf8c6add1291e9a93e7f5b200c0a0 (branch prod)
- ebqueue: D:\_AppAll\200133ebqueue — base: cb28526f908203ce5792fd23f80acff91e6865f6 (branch features/truongtd/tgxk)
- gogateway: không sửa.

**Mốc so sánh:** working tree của cả ba repo đang chứa thay đổi CHƯA COMMIT của task trước `20261016-lo-theo-chung-tu-cha` (đã PASS review) cùng các thay đổi có sẵn của người dùng. Diff tại thời điểm bắt đầu task này đã lưu ở `baseline/ebinventory.diff`, `baseline/ebqueue.diff`, `baseline/ebwebbe.diff` trong thư mục làm việc. Phần thuộc task này = diff hiện tại so với base commit, trừ đi nội dung các file baseline.

Thay đổi có sẵn KHÔNG thuộc task, không được đụng tới hay hoàn tác:
- ebinventory: `application-worker.yml`, `ApplicationProperties.java` (`result-batch-size` 200).
- ebqueue: `libs/core-model.jar`, `application-dev.yml`, `application-prod.yml`.
- ebwebbe: `libs/core-model.jar`, `application-dev.yml`, phần comment kiểm cờ `COSTING_CODE` trong `AsyncCalculateOWPriceServiceImpl.java`.

## Triệu chứng / dữ liệu tái hiện
- Kế hoạch thực thi trong cache (EB99_GR2, 16/10/2026) của store hiện tại: ba câu `UPDATE rsi` cập nhật tổng phiếu kho đọc trung bình 354.645 / 843.500 / 1.062.436 logical reads mỗi lần chạy, đi qua index `RSInwardOutward__index_company_id` do điều kiện `WHERE rsi.CompanyID = @CompanyID`. `UPDATE sai` (tổng hoá đơn) đọc ~43.081.
- Người dùng đánh giá phần cập nhật chứng từ cha trong store hiện tại "rất rối" (gom ID cha qua 6 bảng tạm rồi `CROSS APPLY SUM`).

## Quyết định của người dùng
- Đồng ý thêm `referenceID` vào bản tin và cột `ReferenceID` vào `TVP_CostingResult` (đổi hợp đồng ebinventory ↔ ebqueue; chủ sở hữu ebinventory, sửa cả hai phía).
- Hai store chạy cùng một transaction của lô.
- Chấp nhận đổi các mục COSTING.md: ebwebbe mục 1 (thứ tự năm mục của store → tách thành store con và store cha), cùng các mục liên quan tới lắp ráp/tổng tiền header; ebinventory mục 7 và ebqueue mục 1 (hợp đồng ba trường → thêm `referenceID`). Lý do: phần cập nhật chứng từ cha rối và nặng (đọc theo `CompanyID`); lô đã chia theo chứng từ cha nên có thể tính tổng theo `ReferenceID` sau khi lưu con.
- (Dữ liệu, kiểm EB99_GR2 ngày 16/10/2026, trả lời lưu ý 2 vòng rule 1) `RepositoryLedger` các TypeID 403, 410, 411, 412, 414, 415, 420, 421, 422 (tổng ~2,15 triệu dòng; không có dòng 413): số dòng `ReferenceID IS NULL` = **0** ở mọi loại. Dòng kết quả thiếu `ReferenceID` không có trong dữ liệu thực tế; store cha không cần xử lý riêng ngoài việc không lỗi.
- (Trả lời BLOCKED vòng code 1) Người dùng **đồng ý** sửa `D:\_AppAll\200133ebwebbe\dbchangelog_new\stored_procedure\update_InventoryCosting_TVP.sql`: bỏ dòng 28–113 (sáu bảng tạm gom ID cha) và dòng 300–472 (mục 4, 5 cũ cùng các lệnh `DROP` của sáu bảng tạm), giữ lại `DROP TABLE #CostingResult;`, `END;`, `GO`.
- Test UT_078 (chặn `referenceID` lộ ra JSON) phải đổi kỳ vọng theo hợp đồng mới — được phép vì mục 7 ebinventory được sửa trước.

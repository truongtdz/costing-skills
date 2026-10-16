# Task

## Yêu cầu
Fix bug: Kho / TGXK không riêng kho sai giá CT Chuyển kho.

Các bước tái hiện (nguyên văn người dùng):
1. Tạo PN 15/09: K1, SL=10, GT=100.000; PN 05/10: K2, SL=10, GT=300.000
2. Tạo CT CK 10/10: K1→K2, SL=5
3. TGXK không riêng kho

(PN = phiếu nhập, SL = số lượng, GT = giá trị, CT = chứng từ, CK = chuyển kho)

"Hiện tại tính đang ra 19,6 được nhận định là sai."

Trả lời ở bước 0 (nguyên văn người dùng):
- "Tính giá không riêng kho tức là gộp kho ấy" (cờ `byRepository = false`).
- "Thì nghiệp vụ nó phải là bỏ các chứng từ là chuyển kho đi."
- "Giá 20000 là đúng."
- "Bạn đang đoán thì khả năng trong tài liệu nghiệp vụ đang k có hãy cập nhập vào nghiệp vụ nếu thật sự chưa có."
- Về con số 19,6: "Cái này nó đang tính sai."

## Loại việc
bug

## Repo
- ebwebbe: D:\_AppAll\200133ebwebbe — base: c31c22d4b445c61981c5af2bb3bb205ba82fc829 (branch features/truongtd/tgxk)
- ebqueue: D:\_AppAll\200133ebqueue — base: cb28526f908203ce5792fd23f80acff91e6865f6 (branch features/truongtd/tgxk)
- ebinventory: D:\_AppInventory\ebinventory — base: 1a9050b5fdc9bd6cec24f7a68a1b71d6381eea10 (branch prod)
- gogateway: D:\_AppInventory\gogateway — base: 8b2394f18bc6a8043c8c9834fc93127a7e9eac8f (branch features/truongtd/tgxk)

Working tree có sẵn thay đổi chưa commit, KHÔNG thuộc task này, không được đụng tới:
- ebwebbe: libs/core-model.jar, src/main/resources/config/application-dev.yml
- ebqueue: libs/core-model.jar, src/main/resources/config/application-dev.yml, src/main/resources/config/application-prod.yml
- gogateway: CLAUDE.md

## Triệu chứng / dữ liệu tái hiện
Sổ chi tiết vật liệu, dụng cụ, sản phẩm, hàng hoá — từ 01/01/2026 đến 13/10/2026, mã hàng tgxk004 (test TGXK kho), sau khi TGXK không riêng kho:

Kho 111:
- NK057-yentest 15/09/2026 Nhập kho: SL 10, đơn giá 10.000, thành tiền 100.000
- CK003 13/10/2026 Chuyển kho (xuất): SL 5, đơn giá 19.600, thành tiền 98.000

Kho 111333:
- NK058-yentest 01/10/2026 Nhập kho: SL 10, đơn giá 30.000, thành tiền 300.000
- CK003 13/10/2026 Chuyển kho (nhập): SL 5, đơn giá 19.600, thành tiền 98.000

Kết quả hiện tại: đơn giá CK003 = 19.600 (sai).
Kết quả đúng: 20.000 = (100.000 + 300.000) / (10 + 10) — khi gộp kho, chứng từ chuyển kho bị loại khỏi tính toán.

## Quyết định của người dùng
- Nghiệp vụ: khi tính giá gộp kho (`byRepository = false`), bỏ các chứng từ chuyển kho khỏi tính toán đơn giá bình quân. Đơn giá đúng của ví dụ trên là 20.000.
- Nếu COSTING.md chưa có quy tắc này thì phải bổ sung.

<%@ page pageEncoding="UTF-8" %>
<%--
  商品卡片 —— 前台列表页和详情页的「同类商品」共用这一份

  使用前提：当前作用域里有个变量 it（一个 StoreItem）。
  因为 <%@ include %> 是编译期文本展开，被包含进来的代码就活在
  外层 <c:forEach> 的作用域里，所以直接写 ${it} 就能取到。

  为什么抽成一个文件？
  /mall 列表和详情页下方的推荐位长得完全一样。
  复制两份的话，以后改卡片样式就得改两处 —— 漏一处就不一致了。
--%>
<div class="m-card">
    <a href="${ctx}/mall/item?id=${it.id}">
        <%-- 有图显示图，没图退回「首字色块」。
             为什么留着色块不干脆删掉？
             因为后台新增商品时图片是可选项 —— 没传图不该让前台露出一片空白，
             给个带商品名首字的色块，至少还看得出这是件商品。

             ${not empty it.image} 里 empty 是「运算符」（前缀用法），
             这是合法的；坑 9 踩的是 ${page.empty} 那种「点后面跟 empty」，
             那种才会解析失败。同一段 EL 里两种写法差别很大，别记混。

             图片地址直接拼、不做 URL 转义，是因为文件名由 Uploads 生成，
             只有字母数字，不存在需要转义的字符。 --%>
        <c:choose>
            <c:when test="${not empty it.image}">
                <div class="m-thumb m-thumb-img">
                    <img src="${ctx}/img?name=${it.image}" alt="${it.name}">
                </div>
            </c:when>
            <c:otherwise>
                <div class="m-thumb">${it.initial}</div>
            </c:otherwise>
        </c:choose>
    </a>

    <div class="m-card-body">
        <a class="m-name" href="${ctx}/mall/item?id=${it.id}">${it.name}</a>
        <div class="m-meta">${it.brand} · ${it.category}</div>

        <div class="m-price-row">
            <span class="m-price"><i>¥</i>${it.priceText}</span>
            <c:choose>
                <c:when test="${it.stock <= 0}">
                    <span class="m-stock-out">已售罄</span>
                </c:when>
                <c:when test="${it.stock < lowStockLine}">
                    <span class="m-stock-warn">仅剩 ${it.stock} 件</span>
                </c:when>
            </c:choose>
        </div>

        <div class="m-card-act">
            <form method="post" action="${ctx}/mall/cart/add">
                <input type="hidden" name="id" value="${it.id}">
                <input type="hidden" name="qty" value="1">
                <%-- 加完回哪个页面：backUrl 由 layout-head.jsp 按「当前页面 + 查询串」算好。
                     这里用 c:out 是为了把查询串里的 & 转成 &amp;，
                     HTML 里属性值中出现裸 & 虽然浏览器大多能忍，但不合法。 --%>
                <input type="hidden" name="back" value="<c:out value='${backUrl}'/>">
                <button type="submit" class="m-btn m-btn-primary m-btn-block"
                        ${it.stock <= 0 ? 'disabled' : ''}>加入购物车</button>
            </form>
        </div>
    </div>
</div>

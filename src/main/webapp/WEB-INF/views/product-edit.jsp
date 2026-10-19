<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="isEdit" value="${formMode eq 'edit'}"/>
<c:set var="pageTitle" value="${isEdit ? '编辑商品' : '新增商品'}"/>
<c:set var="active" value="product"/>
<%@ include file="/WEB-INF/views/common/layout-head.jsp" %>

<div class="page-head">
    <div>
        <h1>${isEdit ? '编辑商品' : '新增商品'}</h1>
        <p class="desc">${isEdit ? '改完点保存就生效' : '带星号的是必填项'}</p>
    </div>
    <a class="btn btn-ghost" href="${ctx}/product/list">返回列表</a>
</div>

<%@ include file="/WEB-INF/views/common/flash.jsp" %>

<div class="card" style="max-width:740px">
    <div class="card-body">
        <%--
            新增和编辑共用一个表单：
            标题、按钮文字靠 isEdit 切换，action 也跟着变
            （地址不同，AuthFilter 才能只凭路径判断该查 prod:add 还是 prod:upd）
        --%>
        <%--
            enctype 必须改成 multipart/form-data —— 它决定浏览器怎么编码请求体。

            默认的 application/x-www-form-urlencoded 只擅长「键=值」用 & 连起来，
            塞不进二进制内容：选了图片也只会传过来一个文件名，文件本身丢了。

            multipart 则把请求体切成若干「段」（part），
            每段有自己的名字和类型，文件单独占一段。
            服务端靠 ProductFormServlet 上那行 @MultipartConfig 来接收。
        --%>
        <form method="post" enctype="multipart/form-data"
              action="${ctx}${isEdit ? '/product/edit' : '/product/add'}">

            <c:if test="${isEdit}">
                <input type="hidden" name="id" value="${item.id}">
            </c:if>

            <div class="form-grid">

                <div class="form-row span2">
                    <label>商品图片</label>

                    <%-- 编辑且已有图时，先把现在的图摆出来给人看 --%>
                    <c:if test="${isEdit and not empty item.image}">
                        <div class="img-now">
                            <img src="${ctx}/img?name=${item.image}" alt="${item.name}">
                            <label class="img-del">
                                <input type="checkbox" name="removeImage" value="1">
                                删掉这张图
                            </label>
                        </div>
                    </c:if>

                    <%-- accept 只是给浏览器的建议（帮用户过滤一下文件选择框），
                         完全挡不住有心人 —— 服务端照样要自己校验一遍。
                         前端限制是体验，不是安全。 --%>
                    <input type="file" name="imageFile" accept="image/*">

                    <div class="help">
                        支持 jpg / png / gif / webp / bmp，单张不超过 ${maxImageMB}MB。可以留空。
                        <c:if test="${isEdit}">
                            <br>选了新图就会替换掉现在的图（那种情况下「删掉这张图」自动作废）。
                        </c:if>
                    </div>
                </div>

                <div class="form-row">
                    <label>商品名称 <span class="req">*</span></label>
                    <input type="text" name="name" value="${item.name}" required maxlength="30">
                    <div class="help">名称不能和已有商品重复</div>
                </div>

                <div class="form-row">
                    <label>单价（元） <span class="req">*</span></label>
                    <input type="text" name="price" value="${isEdit ? item.priceText : ''}"
                           required placeholder="例如 99.00">
                </div>

                <div class="form-row">
                    <label>分类</label>
                    <select name="category">
                        <option value="">未分类</option>
                        <c:forEach var="cn" items="${catOptions}">
                            <option value="${cn}"${cn eq item.category ? ' selected' : ''}>${cn}</option>
                        </c:forEach>
                    </select>
                    <div class="help">下拉项来自「分类管理」，那里没有的不会出现在这里</div>
                </div>

                <div class="form-row">
                    <label>品牌</label>

                    <%--
                        「其他」这条路要解决的是一个来回的问题：
                        编辑一件老商品时，它的品牌名可能压根不在下拉里 ——
                        比如品牌管理里被删过，或者是上个版本手输进去的。
                        那时候必须自动落到「其他」上、并把手输框亮出来。
                        否则一进编辑页就显示成「无品牌」，随手一保存，
                        原来的品牌就被冲没了 —— 数据静默丢失，最难查的那种。

                        下面几行干的就是「算一下这个商品的品牌在不在下拉里」。
                    --%>
                    <c:set var="brandInList" value="${false}"/>
                    <c:forEach var="bn" items="${brandOptions}">
                        <c:if test="${bn eq item.brand}">
                            <c:set var="brandInList" value="${true}"/>
                        </c:if>
                    </c:forEach>
                    <c:set var="useOtherBrand" value="${not empty item.brand and not brandInList}"/>

                    <!-- 下拉永远不 disable：真禁掉的话，用户一旦落到「其他」状态，
                         就再也切不回具体品牌了，等于把路走死 -->
                    <select name="brandPick" id="brandPick" data-other="${brandOther}">
                        <option value="">无品牌</option>
                        <c:forEach var="bn" items="${brandOptions}">
                            <option value="<c:out value='${bn}'/>"${bn eq item.brand ? ' selected' : ''}><c:out value="${bn}"/></option>
                        </c:forEach>
                        <option value="${brandOther}"${useOtherBrand ? ' selected' : ''}>其他（自己输入）</option>
                    </select>

                    <%--
                        手输框默认是 disabled 的。
                        被禁用的表单控件浏览器根本不往请求里放 ——
                        于是「下拉」和「手输」永远只有一个值能到服务端，
                        服务端也就不必靠猜。JS 只在选中「其他」时把 disabled 摘掉。
                    --%>
                    <input type="text" name="brandCustom" id="brandCustom"
                           value="<c:out value='${useOtherBrand ? item.brand : ""}'/>"
                           maxlength="${brandNameMax}" placeholder="例如：小米"
                           class="brand-custom"${useOtherBrand ? '' : ' disabled'}>

                    <div class="help">
                        下拉里没有的品牌，选「其他（自己输入）」自己写一个，保存时会自动加进品牌库
                    </div>
                </div>

                <div class="form-row">
                    <label>库存（件） <span class="req">*</span></label>
                    <input type="text" name="stock" value="${isEdit ? item.stock : ''}"
                           required placeholder="例如 100">
                    <div class="help">库存低于 ${lowStockLine} 件会在工作台提醒补货</div>
                </div>
            </div>

            <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                    ${isEdit ? '保存修改' : '确认新增'}
                </button>
                <a class="btn btn-ghost" href="${ctx}/product/list">取消</a>
            </div>
        </form>
    </div>
</div>

<%--
    品牌那块的小联动（选「其他」时亮出手输框）。
    必须放在 layout-foot 之前 —— 那个片段里已经把 </body></html> 收掉了。

    单独放成 .js 文件而不是内联 <script>，是为了让浏览器能缓存它，
    也让「页面结构」和「行为」各归各位。
    （AuthFilter 的白名单里早就留了 /js，不用再动权限。）
--%>
<script src="${ctx}/js/product-edit.js"></script>

<%@ include file="/WEB-INF/views/common/layout-foot.jsp" %>

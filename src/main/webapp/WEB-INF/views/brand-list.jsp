<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="pageTitle" value="品牌管理"/>
<c:set var="active" value="brand"/>
<%@ include file="/WEB-INF/views/common/layout-head.jsp" %>

<div class="page-head">
    <div>
        <h1>品牌管理</h1>
        <p class="desc">品牌被商品引用时不能删除，先把那些商品的品牌改掉</p>
    </div>
</div>

<%@ include file="/WEB-INF/views/common/flash.jsp" %>

<c:if test="${can['brand:add']}">
    <div class="card">
        <div class="card-head">
            <h2>新增品牌</h2>
        </div>
        <div class="card-body">
            <form class="filters" method="post" action="${ctx}/brand/add">
                <div class="f wide">
                    <label>品牌名称</label>
                    <input type="text" name="name" required maxlength="20" placeholder="例如：联想">
                </div>
                <div class="f wide">
                    <label>备注</label>
                    <input type="text" name="remark" maxlength="50" placeholder="例如：中国 · 电脑">
                </div>
                <button type="submit" class="btn btn-primary">添加</button>
            </form>
        </div>
    </div>
</c:if>

<div class="card">
    <div class="card-head">
        <h2>全部品牌</h2>
        <span style="font-size:12.5px;color:#94a3b8">改完直接点保存</span>
    </div>

    <c:choose>
        <c:when test="${empty brands}">
            <div class="empty">还没有任何品牌</div>
        </c:when>
        <c:otherwise>
            <table class="tbl">
                <thead>
                <tr>
                    <th style="width:70px">编号</th>
                    <th style="width:26%">名称</th>
                    <th>备注</th>
                    <th class="num" style="width:90px">商品数</th>
                    <th class="col-act">操作</th>
                </tr>
                </thead>
                <tbody>
                <c:forEach var="brd" items="${brands}">
                    <tr>
                        <td class="muted">
                            <form id="bf-${brd.id}" method="post" action="${ctx}/brand/update">
                                <input type="hidden" name="id" value="${brd.id}">
                            </form>
                            ${brd.id}
                        </td>

                        <td>
                            <input form="bf-${brd.id}" class="inline-edit" type="text"
                                   name="name" value="${brd.name}"${can['brand:upd'] ? '' : ' readonly'}>
                        </td>

                        <td>
                            <input form="bf-${brd.id}" class="inline-edit" type="text"
                                   name="remark" value="${brd.remark}"${can['brand:upd'] ? '' : ' readonly'}>
                        </td>

                        <td class="num">${counts[brd.id]}</td>

                        <td class="col-act">
                            <div class="row-actions">
                                <c:if test="${can['brand:upd']}">
                                    <button form="bf-${brd.id}" class="btn btn-ghost btn-sm">保存</button>
                                </c:if>

                                <c:if test="${can['brand:del']}">
                                    <c:choose>
                                        <c:when test="${counts[brd.id] gt 0}">
                                            <span class="badge badge-warn"
                                                  title="还有商品在用这个品牌">被占用</span>
                                        </c:when>
                                        <c:otherwise>
                                            <form method="post" action="${ctx}/brand/delete"
                                                  style="display:inline">
                                                <input type="hidden" name="id" value="${brd.id}">
                                                <button class="btn btn-danger btn-sm"
                                                        onclick="return confirm('确定删除这个品牌吗？')">删除</button>
                                            </form>
                                        </c:otherwise>
                                    </c:choose>
                                </c:if>
                            </div>
                        </td>
                    </tr>
                </c:forEach>
                </tbody>
            </table>
        </c:otherwise>
    </c:choose>
</div>

<%@ include file="/WEB-INF/views/common/layout-foot.jsp" %>

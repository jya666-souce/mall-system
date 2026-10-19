<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="pageTitle" value="分类管理"/>
<c:set var="active" value="category"/>
<%@ include file="/WEB-INF/views/common/layout-head.jsp" %>

<div class="page-head">
    <div>
        <h1>分类管理</h1>
        <p class="desc">分类被商品引用时不能删除，先把那些商品的分类改掉</p>
    </div>
</div>

<%@ include file="/WEB-INF/views/common/flash.jsp" %>

<c:if test="${can['cat:add']}">
    <div class="card">
        <div class="card-head">
            <h2>新增分类</h2>
        </div>
        <div class="card-body">
            <form class="filters" method="post" action="${ctx}/category/add">
                <div class="f wide">
                    <label>分类名称</label>
                    <input type="text" name="name" required maxlength="20" placeholder="例如：图书">
                </div>
                <div class="f wide">
                    <label>备注</label>
                    <input type="text" name="remark" maxlength="50" placeholder="可留空">
                </div>
                <button type="submit" class="btn btn-primary">添加</button>
            </form>
        </div>
    </div>
</c:if>

<div class="card">
    <div class="card-head">
        <h2>全部分类</h2>
        <span style="font-size:12.5px;color:#94a3b8">改完直接点保存</span>
    </div>

    <c:choose>
        <c:when test="${empty categories}">
            <div class="empty">还没有任何分类</div>
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
                <c:forEach var="cat" items="${categories}">
                    <tr>
                        <%--
                            行内编辑的关键点：
                            输入框用 form="cf-3" 这个属性挂到下面那个 form 上。
                            为什么要绕这一下？因为表格里不能直接套 <form>（非法 HTML），
                            而行内又需要「保存/删除」两个不同的提交目标，
                            所以每个动作各自一个 form，输入框用 form 属性认领。
                        --%>
                        <td class="muted">
                            <form id="cf-${cat.id}" method="post" action="${ctx}/category/update">
                                <input type="hidden" name="id" value="${cat.id}">
                            </form>
                            ${cat.id}
                        </td>

                        <td>
                            <input form="cf-${cat.id}" class="inline-edit" type="text"
                                   name="name" value="${cat.name}"${can['cat:upd'] ? '' : ' readonly'}>
                        </td>

                        <td>
                            <input form="cf-${cat.id}" class="inline-edit" type="text"
                                   name="remark" value="${cat.remark}"${can['cat:upd'] ? '' : ' readonly'}>
                        </td>

                        <td class="num">${counts[cat.id]}</td>

                        <td class="col-act">
                            <div class="row-actions">
                                <c:if test="${can['cat:upd']}">
                                    <button form="cf-${cat.id}" class="btn btn-ghost btn-sm">保存</button>
                                </c:if>

                                <c:if test="${can['cat:del']}">
                                    <c:choose>
                                        <c:when test="${counts[cat.id] gt 0}">
                                            <span class="badge badge-warn"
                                                  title="还有商品在用这个分类">被占用</span>
                                        </c:when>
                                        <c:otherwise>
                                            <form method="post" action="${ctx}/category/delete"
                                                  style="display:inline">
                                                <input type="hidden" name="id" value="${cat.id}">
                                                <button class="btn btn-danger btn-sm"
                                                        onclick="return confirm('确定删除这个分类吗？')">删除</button>
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

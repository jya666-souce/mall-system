<%-- 片段文件必须自己声明 pageEncoding，否则里面的中文会被按 ISO-8859-1 读 --%>
<%@ page pageEncoding="UTF-8" %>
<%--
  操作结果提示条
  flashOk / flashErr 是 Servlet 塞进 session 的「一次性消息」，
  显示完就被取走了（见各 Servlet 里的 takeFlash 调用）
--%>
<c:if test="${not empty flashOk}">
    <div class="flash flash-ok">${flashOk}</div>
</c:if>
<c:if test="${not empty flashErr}">
    <div class="flash flash-err">${flashErr}</div>
</c:if>

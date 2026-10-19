package com.cn.web;

import com.cn.Role;
import com.cn.User;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/**
 * 权限过滤器：所有请求先过这里，再进 Servlet
 *
 * @WebFilter("/*") 里的 /* 是「拦下所有请求」，包括静态资源。
 *
 * 它干四件事：
 *   ① 统一设 UTF-8 编码（必须在取参数之前，否则中文乱码）
 *   ② 静态资源、登录页直接放行
 *   ③ 没登录的 → 踢回登录页
 *   ④ 已登录的 → 看这次请求需要的权限 code 在不在他的权限列表里
 *
 * 为什么用 Filter 而不是在每个 Servlet 里写 if？
 *   Filter 是「横切」的，所有请求都必经。
 *   权限判断集中在一处，新增功能时只要改 requiredCode() 一行，
 *   不会漏掉某个 Servlet 忘记校验。
 *
 * 一个刻意的 URL 设计（见笔记坑 6）：
 *   新增和修改拆成 /product/add 与 /product/update 两个地址，
 *   这样这里只看路径就能判断该查哪个权限，不必去读请求体里的隐藏字段 ——
 *   而读请求体正好会踩到「编码必须在第一行设置」的坑。
 *
 * @author 靳迎奥
 */
@WebFilter("/*")
public class AuthFilter implements Filter {

    /** 白名单：这些路径不登录也能访问 */
    private static final Set<String> WHITE_LIST = Set.of(
            "/login", "/logout", "/css", "/js", "/favicon.ico",
            // 商品图片。前台游客要看得见图，图片本身也不是机密。
            // 放进白名单是安全的：能取到的只有 uploadDir 里那几个
            // 随机命名的文件，ImageServlet 那边还有一道路径校验。
            "/img"
    );

    @Override
    public void init(FilterConfig filterConfig) {
        // 无需初始化
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse resp = (HttpServletResponse) response;

        /* ---- ① 编码必须在这里设 ----
           浏览器 POST 上来的表单默认按 ISO-8859-1 解码。
           一旦有人调用 getParameter()，Tomcat 就会把请求体解析掉并用当时的编码，
           之后再 setCharacterEncoding 就晚了、无效了。
           所以放在过滤器的第一行，抢在所有 getParameter 之前。 */
        req.setCharacterEncoding("UTF-8");
        resp.setCharacterEncoding("UTF-8");

        String ctx = req.getContextPath();
        // 去掉上下文路径，拿到纯路径，比如 /shop/product/list → /product/list
        String path = req.getRequestURI().substring(ctx.length());
        // 顺手把末尾多余的斜杠去掉，/category/ 和 /category 视作同一个
        if (path.length() > 1 && path.endsWith("/")) {
            path = path.substring(0, path.length() - 1);
        }

        // ② 白名单直接放行
        if (isWhite(path)) {
            chain.doFilter(request, response);
            return;
        }

        // ③ 登录校验
        //    前台商城 /mall/* 是例外：游客也能逛、也能加购物车，
        //    所以未登录时不把他踢走，让他继续往下走。
        //    「下单」「我的订单」这几个必须登录的，由 Servlet 自己拦 ——
        //    它们要的不是某个权限码，而是「你是谁」，判断依据不一样。
        //
        //    应用根路径 "/" 也一样放行：它只是个 302 到 /mall 的跳板，是商城的大门。
        //    不放行的话，游客敲 http://localhost:8080/shop/ 会先撞见登录页 ——
        //    跟「前台不登录也能逛」自相矛盾，而且他连去的路都没有。
        HttpSession session = req.getSession(false);
        User user = (session == null) ? null : (User) session.getAttribute("user");

        boolean openDoor = isMall(path) || path.equals("/");
        if (user == null && !openDoor) {
            // 顺便记住原本想去哪，登录完直接送回那个页面，而不是一律丢进工作台
            String back = path;
            if (req.getQueryString() != null && !req.getQueryString().isEmpty()) {
                back = back + "?" + req.getQueryString();
            }
            resp.sendRedirect(ctx + "/login?redirect=" + URLEncoder.encode(back, StandardCharsets.UTF_8));
            return;
        }

        DataStore store = DataStore.get();
        Role role = (user == null) ? null : store.roleOf(user);
        Set<String> codes = (user == null) ? Set.of() : store.permCodesOf(user);

        /* 把权限集合额外转成一个「查表用的 Map」：
           集合在 EL 里想判断某个元素得写成 ${permCodes.contains('prod:add')}，
           EL 方法调用对版本有要求；换成 Map 之后页面上直接写 ${can['prod:add']}，
           不存在时取值是 null，c:if 会当成 false，稳当得多。 */
        Map<String, Boolean> can = new HashMap<>();
        for (String code : codes) {
            can.put(code, Boolean.TRUE);
        }

        req.setAttribute("can", can);
        req.setAttribute("permCodes", codes);
        req.setAttribute("roleName", role == null ? "-" : role.getName());
        req.setAttribute("currentUser", user);
        req.setAttribute("userInitial", user == null ? "?" : initialOf(user));
        req.setAttribute("ctx", ctx);
        // 当前路径（不含上下文）——前台页面拼「登录后回到这儿」的链接要用它
        req.setAttribute("here", path);

        // ④ 权限校验
        String needed = requiredCode(path);
        if (needed != null && !codes.contains(needed)) {
            req.setAttribute("neededPerm", needed);
            resp.setStatus(HttpServletResponse.SC_FORBIDDEN);
            req.getRequestDispatcher("/WEB-INF/views/403.jsp").forward(req, resp);
            return;
        }

        chain.doFilter(request, response);
    }

    private boolean isWhite(String path) {
        for (String w : WHITE_LIST) {
            if (path.equals(w) || path.startsWith(w + "/")) {
                return true;
            }
        }
        return false;
    }

    /**
     * 是不是前台商城的路径
     *
     * /mall 和 /mall/xxx 都算。
     *
     * 为什么不让前台也走 WHITE_LIST？两者含义不同：
     *   白名单  = 连「你是谁」都不用管（登录页、静态资源），放行就完事
     *   前台商城 = 不登录也能逛，但如果你登录了，页面得知道你是谁 ——
     *              顶栏要显示用户名、购物车角标、我的订单入口
     * 所以前台不能走白名单那条捷径，它得继续往下走完属性注入那一段。
     */
    private boolean isMall(String path) {
        return path.equals("/mall") || path.startsWith("/mall/");
    }

    /**
     * 路径 → 这次请求需要的权限 code
     * 返回 null 表示「只要登录就行，不挑权限」
     *
     * 这里就是整个系统的权限总表 ——
     * 想给某个功能加权限，只改这一处就够了。
     */
    private String requiredCode(String path) {
        switch (path) {
            case "/dashboard":
                return DataStore.PERM_DASH;

            case "/product/list":
                return DataStore.PERM_LIST;
            case "/product/add":
                return DataStore.PERM_ADD;      // 新增表单和提交都用这个
            case "/product/edit":
                return DataStore.PERM_UPD;      // 打开编辑表单
            case "/product/update":
                return DataStore.PERM_UPD;      // 提交修改
            case "/product/delete":
                return DataStore.PERM_DEL;

            case "/category":
                return DataStore.PERM_CAT_LIST;
            case "/category/add":
                return DataStore.PERM_CAT_ADD;
            case "/category/update":
                return DataStore.PERM_CAT_UPD;
            case "/category/delete":
                return DataStore.PERM_CAT_DEL;

            case "/brand":
                return DataStore.PERM_BRD_LIST;
            case "/brand/add":
                return DataStore.PERM_BRD_ADD;
            case "/brand/update":
                return DataStore.PERM_BRD_UPD;
            case "/brand/delete":
                return DataStore.PERM_BRD_DEL;

            /* 订单：前台下单不走这里（前台只看登录状态，不看权限码），
               下面两条是给后台管理员的 */
            case "/order":
                return DataStore.PERM_ORDER_LIST;
            case "/order/status":
                return DataStore.PERM_ORDER_UPD;

            default:
                return null;
        }
    }

    /** 头像里显示名字的第一个字 */
    private static String initialOf(User u) {
        String name = u.getName();
        if (name == null || name.isEmpty()) {
            return "?";
        }
        return name.substring(0, 1);
    }

    @Override
    public void destroy() {
        // 无需释放
    }
}

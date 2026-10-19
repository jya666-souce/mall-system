package com.cn.web;

import com.cn.Cart;
import com.cn.User;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

/**
 * 登录 Servlet
 *
 * @WebServlet("/login") 相当于以前在 web.xml 里写：
 *   &lt;servlet&gt;&lt;servlet-name&gt;LoginServlet&lt;/servlet-name&gt;
 *           &lt;servlet-class&gt;com.cn.web.LoginServlet&lt;/servlet-class&gt;&lt;/servlet&gt;
 *   &lt;servlet-mapping&gt;&lt;servlet-name&gt;LoginServlet&lt;/servlet-name&gt;
 *                    &lt;url-pattern&gt;/login&lt;/url-pattern&gt;&lt;/servlet-mapping&gt;
 * 一个注解顶 6 行 XML。
 *
 * 注意这里的路径 "/login" 是相对"应用上下文"的。
 * 部署成 shop.war 后，应用上下文是 /shop，
 * 所以浏览器里完整地址是 http://localhost:8080/shop/login
 *
 * 这一版多了两件事：
 *   ① ?redirect= —— 被拦下来的用户登录完应该回原来那个页面，
 *      而不是被丢进某个固定页面。所以要「从哪来，回哪去」，且必须做站内校验。
 *   ② 购物车迁移 —— 登录要换 session，换了购物车就没了，得先捞出来再放回去。
 *
 * 没带 redirect 时默认落到哪：**前台商城 /mall**。
 *   以前是后台工作台 /dashboard —— 那会儿整个应用只有后台一张脸，
 *   登录完当然是进后台。现在商城才是对外的门面，登录完先把人送到顾客
 *   该待的地方；要管理后台，商城顶栏有「后台管理」的入口。
 *
 *   顺带一提：这次改动之所以只动了一个常量，是因为「登录后去哪」这件事
 *   从一开始就被抽成了 safeRedirect() 一个方法、有且只有一个默认值。
 *   要是当初写成散在各处的 sendRedirect("/dashboard")，现在就得满地找了。
 *
 * @author 靳迎奥
 */
@WebServlet("/login")
public class LoginServlet extends HttpServlet {

    /** GET：单纯打开登录页 */
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        // 已经登录过的就不用再登一次，直接送去该去的地方
        HttpSession session = req.getSession(false);
        if (session != null && session.getAttribute("user") != null) {
            resp.sendRedirect(req.getContextPath() + safeRedirect(req));
            return;
        }

        // 把目的地带着走 —— 页面里用隐藏域再交回来
        req.setAttribute("redirect", safeRedirect(req));
        req.getRequestDispatcher("/WEB-INF/views/login.jsp").forward(req, resp);
    }

    /** POST：提交账号密码 */
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        String username = Params.trim(req.getParameter("username"));
        String password = Params.trim(req.getParameter("password"));

        // 先区分「没填」和「填错了」。
        // 不区分的话，用户密码框空着点登录，看到的是"用户名或密码错误"，
        // 会误以为账号有问题，其实是漏填了 —— 提示要说清楚到底哪儿不对。
        String error = null;
        if (username.isEmpty()) {
            error = "请输入用户名";
        } else if (password.isEmpty()) {
            error = "请输入密码";
        }

        // 两个都填了，才去查账号（省一次无意义的查找）
        User user = null;
        if (error == null) {
            user = DataStore.get().login(username, password);
            if (user == null) {
                error = "用户名或密码错误";
            }
        }

        if (user == null) {
            // 登录失败：不能重定向，否则用户看不到错误提示。
            // 用 forward 把错误信息带回登录页
            req.setAttribute("error", error);
            req.setAttribute("username", username);
            req.setAttribute("redirect", safeRedirect(req));   // 目的地别弄丢
            req.getRequestDispatcher("/WEB-INF/views/login.jsp").forward(req, resp);
            return;
        }

        /* ---- 登录成功 ---- */

        // 换一个新 session，防「会话固定攻击」（session fixation）：
        // 攻击者先想办法让你带着他的 sessionId 浏览，等你一登录，
        // 那个 id 对应的 session 里就有了你的身份，他也就不用猜密码了。
        // 换掉 session 这个动作，顺手破掉这招。
        //
        // 但换 session 会把里面存的东西全清掉 —— 包括游客加购的购物车。
        // 于是就撞出一个很别扭的场景：
        //   游客挑好东西 → 点结算 → 被弹去登录 → 登录成功换了新 session
        //   → 购物车空了 → 回到结算页，发现车没了
        // 所以这里要先把购物车捞出来，换完再放回去。
        // 「换 session 前先把想留的数据捞出来」是这类场景的固定套路。
        HttpSession old = req.getSession(false);
        Cart cart = (old == null) ? null : (Cart) old.getAttribute("cart");
        if (old != null) {
            old.invalidate();
        }
        HttpSession session = req.getSession(true);
        session.setAttribute("user", user);
        if (cart != null) {
            session.setAttribute("cart", cart);
        }

        // 重定向而不是 forward：
        // forward 的话浏览器地址栏还停在 /login，用户按 F5 会重复提交表单。
        //
        // 落到哪由 redirect 决定：
        //   自己主动来登录页的 → 没有 redirect → 前台商城 /mall
        //   被某个页面拦下来弹过来的 → 接着回原来那个页面
        resp.sendRedirect(req.getContextPath() + safeRedirect(req));
    }

    /**
     * 登录成功后往哪跳
     *
     * 默认是前台商城（/mall）。如果是从别的页面被弹过来的，
     * 地址栏会带着 ?redirect=/mall/order/checkout 之类的路径，这里就把他送回去。
     *
     * 为什么默认是商城而不是后台：这个应用的对外门面是商城，
     * 登录完先送到顾客该待的地方。后台仍然在 /dashboard，
     * 商城顶栏有「后台管理」入口，主动要去的人点一下就行。
     *
     * redirect 的值来自地址栏，用户能随便改，所以必须过一遍站内路径校验 ——
     * 不校验就是「开放重定向」漏洞（登录完被送去钓鱼站）。
     * 校验规则和原因都写在 Params.safePath() 里，保持一致。
     */
    private String safeRedirect(HttpServletRequest req) {
        return Params.safePath(req.getParameter("redirect"), "/mall");
    }
}

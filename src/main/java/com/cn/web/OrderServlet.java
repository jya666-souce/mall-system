package com.cn.web;

import com.cn.Cart;
import com.cn.CartLine;
import com.cn.Order;
import com.cn.User;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * 结算下单 + 我的订单
 *
 *   GET  /mall/order/checkout   结算确认页
 *   POST /mall/order/checkout   提交订单
 *   GET  /mall/order/list       我的订单
 *   POST /mall/order/cancel     取消自己的订单
 *
 * 这四个是前台里**必须登录**的部分。
 *
 * 为什么不交给 AuthFilter 统一拦掉？
 *   因为 AuthFilter 的判断依据是「权限码」，而这几个要的是「你是谁」——
 *   顾客不需要持有「下单」这个权限码，他登录了就该能下单。
 *   两套判断塞进同一个 switch，往后会越来越难读。
 *   所以这个项目的规矩是：**权限码管后台，登录状态管前台**。
 *
 * @author 靳迎奥
 */
@WebServlet({"/mall/order/checkout", "/mall/order/list", "/mall/order/cancel"})
public class OrderServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        String path = req.getServletPath();
        User user = currentUser(req);
        if (user == null) {
            toLogin(req, resp, path);
            return;
        }

        DataStore store = DataStore.get();

        /* ---- 我的订单 ---- */
        if ("/mall/order/list".equals(path)) {
            req.setAttribute("orders", store.ordersOf(user.getId()));
            Flash.take(req);
            req.getRequestDispatcher("/WEB-INF/views/mall/orders.jsp").forward(req, resp);
            return;
        }

        /* ---- 结算确认页（GET /mall/order/checkout）---- */
        Cart cart = CartService.peek(req.getSession(false));
        List<CartLine> lines = CartService.lines(cart, store);

        if (lines.isEmpty()) {
            // 车是空的就没有结算的意义，直接轰回购物车
            Flash.err(req, "购物车是空的，先挑几件商品吧");
            resp.sendRedirect(req.getContextPath() + "/mall/cart");
            return;
        }

        req.setAttribute("lines", lines);
        req.setAttribute("cartTotal", CartService.totalText(lines));
        req.setAttribute("cartProblem", CartService.hasProblem(lines));
        // 收货人先填登录名，省得每次手打
        req.setAttribute("receiver", user.getName());

        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/mall/checkout.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        String path = req.getServletPath();
        User user = currentUser(req);
        if (user == null) {
            toLogin(req, resp, path);
            return;
        }

        DataStore store = DataStore.get();

        /* ---- 取消订单 ---- */
        if ("/mall/order/cancel".equals(path)) {
            Long id = Params.toLong(req.getParameter("id"));
            Order o = store.getOrder(id);

            // 关键的一句：只能取消自己的单。
            // 不校验的话，把地址栏里的 id 一改就能取消别人的订单 ——
            // 这类「只改了个编号就看到了别人的数据」的漏洞叫水平越权，
            // 是真实系统里很常见的一类事故。
            if (o == null || !o.getUserId().equals(user.getId())) {
                Flash.err(req, "订单不存在");
            } else if (!o.isCancelable()) {
                Flash.err(req, "订单已经是「" + o.getStatus() + "」，不能取消了");
            } else {
                Flash.report(req,
                        store.updateOrderStatus(id, Order.STATUS_CANCELED),
                        "订单已取消，库存已退回");
            }
            resp.sendRedirect(req.getContextPath() + "/mall/order/list");
            return;
        }

        /* ---- 提交订单（POST /mall/order/checkout）---- */
        String receiver = Params.trim(req.getParameter("receiver"));
        String phone    = Params.trim(req.getParameter("phone"));
        String address  = Params.trim(req.getParameter("address"));

        Cart cart = CartService.peek(req.getSession(false));
        List<CartLine> lines = CartService.lines(cart, store);

        // 真正的下单：校验库存 + 扣库存 + 建订单，全在 DataStore 里加锁完成
        String err = store.placeOrder(user, lines, receiver, phone, address);

        if (err != null) {
            // 失败时把用户填过的收货信息原样带回去，别让他重打一遍。
            // 这里不能 redirect（会丢表单），用 forward
            req.setAttribute("err", err);
            req.setAttribute("lines", lines);
            req.setAttribute("cartTotal", CartService.totalText(lines));
            req.setAttribute("cartProblem", CartService.hasProblem(lines));
            req.setAttribute("receiver", receiver);
            req.setAttribute("phone", phone);
            req.setAttribute("address", address);
            req.getRequestDispatcher("/WEB-INF/views/mall/checkout.jsp").forward(req, resp);
            return;
        }

        // 成功了才清空购物车 —— 失败就清空，顾客填的信息白填、东西还得重新挑
        if (cart != null) {
            cart.clear();
        }
        Flash.ok(req, "下单成功，我们已经开始备货了");
        resp.sendRedirect(req.getContextPath() + "/mall/order/list");
    }

    /** 从 session 里取当前登录用户，没登录返回 null */
    private User currentUser(HttpServletRequest req) {
        HttpSession s = req.getSession(false);
        return s == null ? null : (User) s.getAttribute("user");
    }

    /**
     * 没登录 → 弹去登录页，并记住办完事回来接着办
     *
     * 登录成功后 LoginServlet 会读 ?redirect= 把人送回来，
     * 所以这个参数必须做站内校验（见 Params.safePath）。
     */
    private void toLogin(HttpServletRequest req, HttpServletResponse resp, String back)
            throws IOException {
        // 取消订单是 POST，登录后 GET 回来没有意义（参数丢了），
        // 退回订单列表让他重新点一下
        String target = "/mall/order/cancel".equals(back) ? "/mall/order/list" : back;
        target = Params.safePath(target, "/mall");

        resp.sendRedirect(req.getContextPath() + "/login?redirect="
                + URLEncoder.encode(target, StandardCharsets.UTF_8));
    }
}

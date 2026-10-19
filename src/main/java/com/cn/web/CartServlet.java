package com.cn.web;

import com.cn.Cart;
import com.cn.CartLine;
import com.cn.StoreItem;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

/**
 * 购物车
 *
 * 一个 Servlet 管五个地址，靠 getServletPath() 分辨：
 *   GET  /mall/cart         看购物车
 *   POST /mall/cart/add     加入
 *   POST /mall/cart/set     改数量
 *   POST /mall/cart/remove  删掉一行
 *   POST /mall/cart/clear   清空
 *
 * 为什么增删改一律用 POST？
 *   GET 在 HTTP 里的语义是「只读、可以随便重放」。
 *   用 GET 做删除，浏览器预加载、爬虫抓取、用户按 F5，
 *   都可能顺手把东西删了 —— 这叫「用 GET 做副作用」，是个经典错误。
 *   规矩很简单：看东西用 GET，改东西用 POST。
 *
 * 为什么每个写操作完都 redirect？
 *   和后台那套一样，PRG（Post-Redirect-Get）：
 *   改完立刻跳走，用户按 F5 顶多是重新打开一次页面，
 *   不会把「加入购物车」又提交一遍。
 *
 * 购物车放 session、不放 DataStore ——
 *   因为它是「这个浏览器的临时清单」，不是全站共享的数据。
 *   放 session 还有个好处：没登录的游客也能加购。
 *
 *   ⚠️ 但别忘了 LoginServlet 里那句 old.invalidate()：
 *      登录成功会换一个新 session（防会话固定攻击），
 *      换的时候购物车会被一起清掉 ——
 *      所以那边专门写了「先把 cart 捞出来、换完再放回去」。
 *      两处要连起来看才完整。这也说明一件事：
 *      「数据存在哪」和「它的生命周期」是绑在一起的。
 *
 * @author 靳迎奥
 */
@WebServlet({"/mall/cart", "/mall/cart/add", "/mall/cart/set",
        "/mall/cart/remove", "/mall/cart/clear"})
public class CartServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        show(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        DataStore store = DataStore.get();
        Cart cart = CartService.of(req.getSession(true));

        switch (req.getServletPath()) {

            case "/mall/cart/add": {
                Long id = Params.toLong(req.getParameter("id"));
                int qty = Params.toInt(req.getParameter("qty"), 1);
                StoreItem item = store.getById(id);

                if (item == null) {
                    Flash.err(req, "商品不存在或已下架");
                } else if (qty <= 0) {
                    Flash.err(req, "数量至少是 1");
                } else {
                    // 先算加完之后总共几件，能不能过库存这道坎。
                    // 这里也要拦：不然顾客把 999 件加进车，
                    // 一路点到结算才被拒，体验很差
                    int already = cart.getLines().getOrDefault(id, 0);
                    if (already + qty > item.getStock()) {
                        Flash.err(req, "【" + item.getName() + "】库存只剩 "
                                + item.getStock() + " 件，购物车里已经有 " + already + " 件了");
                    } else {
                        cart.add(id, qty);
                        Flash.ok(req, "已加入购物车：" + item.getName() + " × " + qty);
                    }
                }

                // 回到按钮所在的那个页面（列表页 / 详情页），默认回购物车
                resp.sendRedirect(req.getContextPath()
                        + Params.safePath(req.getParameter("back"), "/mall/cart"));
                return;
            }

            case "/mall/cart/set": {
                Long id = Params.toLong(req.getParameter("id"));
                int qty = Params.toInt(req.getParameter("qty"), 1);
                StoreItem item = store.getById(id);

                if (item != null && qty > item.getStock()) {
                    Flash.err(req, "【" + item.getName() + "】库存只剩 " + item.getStock() + " 件");
                } else if (qty <= 0) {
                    // 数量改成 0 等于删掉这一行，符合直觉
                    cart.remove(id);
                } else {
                    cart.set(id, qty);
                    Flash.ok(req, "数量已更新");
                }
                resp.sendRedirect(req.getContextPath() + "/mall/cart");
                return;
            }

            case "/mall/cart/remove": {
                cart.remove(Params.toLong(req.getParameter("id")));
                Flash.ok(req, "已从购物车移除");
                resp.sendRedirect(req.getContextPath() + "/mall/cart");
                return;
            }

            case "/mall/cart/clear": {
                cart.clear();
                Flash.ok(req, "购物车已清空");
                resp.sendRedirect(req.getContextPath() + "/mall/cart");
                return;
            }

            default:
                show(req, resp);
        }
    }

    /** 打开购物车页面 */
    private void show(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        DataStore store = DataStore.get();

        // 只看一眼的场合用 peek，不创建 ——
        // 否则一个纯路过的游客也会被塞一个空购物车进 session
        Cart cart = CartService.peek(req.getSession(false));
        List<CartLine> lines = CartService.lines(cart, store);

        // 有几行是「已下架 / 超库存」的，页面上给一句汇总提示
        int bad = 0;
        for (CartLine l : lines) {
            if (l.isBad()) {
                bad++;
            }
        }

        req.setAttribute("lines", lines);
        req.setAttribute("cartTotal", CartService.totalText(lines));
        req.setAttribute("cartProblem", CartService.hasProblem(lines));
        req.setAttribute("badCount", bad);

        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/mall/cart.jsp").forward(req, resp);
    }
}

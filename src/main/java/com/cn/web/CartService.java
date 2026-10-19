package com.cn.web;

import com.cn.Cart;
import com.cn.CartLine;

import jakarta.servlet.http.HttpSession;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 购物车的小管家
 *
 * 为什么单独抽一个类，而不是塞进某个 Servlet 里？
 *   因为「把购物车展开成能显示的行」这件事，前台好几个页面都要用：
 *   商品列表页、购物车页、结算页、下单那一步。
 *   写在 Servlet 里就得复制四份，改一处漏三处。
 *
 * 它只负责「读和算」，不碰数据 ——
 * 真正扣库存、生成订单在 DataStore 里，因为那部分必须和库存锁在一起。
 *
 * @author 靳迎奥
 */
public final class CartService {

    private CartService() {
    }

    /**
     * 从 session 里取购物车，没有就建一个
     *
     * 注意：只要调用过它，session 里就一定有 cart 对象。
     * 所以「顶栏角标」这种只读的地方要用 peek()，
     * 否则一个纯路过的游客也会被塞一个空购物车（多占内存，也容易误解）。
     */
    public static Cart of(HttpSession session) {
        Cart cart = (Cart) session.getAttribute("cart");
        if (cart == null) {
            cart = new Cart();
            session.setAttribute("cart", cart);
        }
        return cart;
    }

    /** 取购物车但不创建，可能返回 null */
    public static Cart peek(HttpSession session) {
        return session == null ? null : (Cart) session.getAttribute("cart");
    }

    /**
     * 把购物车展开成可以显示的行
     *
     * 关键动作是「拿编号去商品表里换回商品」——
     * 换不到就说明商品被后台删了，CartLine 会把 item 置成 null，
     * 页面据此显示「已下架」并拦住结算。
     */
    public static List<CartLine> lines(Cart cart, DataStore store) {
        List<CartLine> out = new ArrayList<>();
        if (cart == null) {
            return out;
        }
        for (Map.Entry<Long, Integer> e : cart.getLines().entrySet()) {
            out.add(new CartLine(e.getKey(), e.getValue(), store.getById(e.getKey())));
        }
        return out;
    }

    /** 合计：只算还在架上的商品 */
    public static double total(List<CartLine> lines) {
        double sum = 0;
        for (CartLine l : lines) {
            sum += l.getSubtotal();
        }
        return sum;
    }

    /** 合计的两位小数字符串，页面直接显示 */
    public static String totalText(List<CartLine> lines) {
        return String.format("%.2f", total(lines));
    }

    /** 有没有「已下架 / 超库存」这种会卡住结算的行 */
    public static boolean hasProblem(List<CartLine> lines) {
        for (CartLine l : lines) {
            if (l.isBad()) {
                return true;
            }
        }
        return false;
    }
}

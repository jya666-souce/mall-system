package com.cn;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 购物车 —— 存在 session 里，一个浏览器一份
 *
 * 它和 Order 最大的区别，也是这一节最值得琢磨的地方：
 *   购物车只记「商品编号 + 数量」，单价库存都等显示时现查
 *     → 后台改了价，购物车里的金额立刻跟着变
 *   订单存的是下单那一刻的快照
 *     → 后台改价影响不到历史订单
 *
 * 为什么容器用 LinkedHashMap？
 *   加购顺序就是显示顺序。用户看到的第一行永远是他先加的那个，
 *   不会因为哈希重排而跳来跳去。
 *
 * 为什么每个方法都加 synchronized？
 *   同一个浏览器的多个请求（比如快速连点两次「加入购物车」）
 *   可能被 Tomcat 分到不同线程，而它们操作的是同一个 Cart 对象。
 *   和 DataStore 是同一个道理。
 *
 * @author 靳迎奥
 */
public class Cart {

    /** 商品编号 → 数量 */
    private final Map<Long, Integer> lines = new LinkedHashMap<>();

    /** 加购：本来没有就放进去，已经有了就累加 */
    public synchronized void add(Long itemId, int qty) {
        if (itemId == null || qty <= 0) {
            return;
        }
        lines.merge(itemId, qty, Integer::sum);
    }

    /** 直接改成指定数量；传 0 或负数等于删掉这一行 */
    public synchronized void set(Long itemId, int qty) {
        if (itemId == null) {
            return;
        }
        if (qty <= 0) {
            lines.remove(itemId);
        } else {
            lines.put(itemId, qty);
        }
    }

    public synchronized void remove(Long itemId) {
        if (itemId != null) {
            lines.remove(itemId);
        }
    }

    public synchronized void clear() {
        lines.clear();
    }

    /** 顶栏角标上的数字：所有行数量加起来 */
    public synchronized int getCount() {
        int sum = 0;
        for (int q : lines.values()) {
            sum += q;
        }
        return sum;
    }

    public synchronized boolean isEmpty() {
        return lines.isEmpty();
    }

    /** 明细行的「编号 → 数量」，给 CartService 展开成可显示的行走 */
    public synchronized Map<Long, Integer> getLines() {
        return new LinkedHashMap<>(lines);
    }
}

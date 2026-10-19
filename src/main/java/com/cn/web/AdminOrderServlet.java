package com.cn.web;

import com.cn.Order;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 后台订单管理
 *
 *   GET  /order          订单列表（权限 order:list）
 *   POST /order/status   改状态：发货 / 完成 / 取消（权限 order:upd）
 *
 * 前台和后台在这里接上了：
 *   顾客在前台 /mall 下单 → 订单落进 DataStore → 管理员在这里看到并处理。
 *   这就是「一个系统两拨人用」最直观的样子。
 *
 * 权限由 AuthFilter 统一把关（requiredCode() 里那两行），
 * 所以这个类里一行 if 判断都看不到 —— 能执行到这儿，说明权限早过了。
 * 判断集中在一处的好处就是：读业务代码时不用被权限逻辑打断。
 *
 * @author 靳迎奥
 */
@WebServlet({"/order", "/order/status"})
public class AdminOrderServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        DataStore store = DataStore.get();
        List<Order> all = store.allOrders();

        // 各状态几单：先按状态表铺底（0 单的状态也要显示出来），再累加
        Map<String, Integer> byStatus = new LinkedHashMap<>();
        for (String s : Order.statusList()) {
            byStatus.put(s, 0);
        }
        for (Order o : all) {
            byStatus.merge(o.getStatus(), 1, Integer::sum);
        }

        // 上方标签点一下按状态过滤，不点就是全部
        String status = Params.trim(req.getParameter("status"));
        List<Order> shown = new ArrayList<>();
        for (Order o : all) {
            if (status.isEmpty() || status.equals(o.getStatus())) {
                shown.add(o);
            }
        }

        req.setAttribute("orders", shown);
        req.setAttribute("byStatus", byStatus);
        req.setAttribute("countAll", all.size());
        req.setAttribute("status", status);          // 回填，标签高亮用
        req.setAttribute("statusOptions", Order.statusList());

        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/order-list.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        Long id = Params.toLong(req.getParameter("id"));
        String status = Params.trim(req.getParameter("status"));

        // 状态机校验（能不能这么改）全在 DataStore 里，
        // 这里只是把结果翻译成一句提示
        String err = DataStore.get().updateOrderStatus(id, status);
        Flash.report(req, err, "订单状态已更新为「" + status + "」");

        resp.sendRedirect(req.getContextPath() + "/order");
    }
}

package com.cn.web;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import com.cn.Brand;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 品牌管理：列表 + 新增 + 修改 + 删除
 *
 * 结构和 CategoryServlet 一模一样 —— 连注释都只改了几个词。
 * 这不是偷懒：两个模块的业务动作完全相同（都是「名字 + 备注」的字典表），
 * 强行抽象成一个大而全的泛型基类，反而更难读。
 * 真要减少重复，等第三个同类模块出现时再说。
 *
 *   GET  /brand          → 列表
 *   POST /brand/add      → 新增
 *   POST /brand/update   → 修改
 *   POST /brand/delete   → 删除
 *
 * @author 靳迎奥
 */
@WebServlet({"/brand", "/brand/add", "/brand/update", "/brand/delete"})
public class BrandServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        showList(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {

        Long id         = Params.toLong(req.getParameter("id"));
        String name     = Params.trim(req.getParameter("name"));
        String remark   = Params.trim(req.getParameter("remark"));
        DataStore store = DataStore.get();

        switch (req.getServletPath()) {
            case "/brand/add":
                Flash.report(req, store.addBrand(name, remark),
                        "已新增品牌【" + name + "】");
                break;

            case "/brand/update":
                Flash.report(req, store.updateBrand(id, name, remark),
                        "已修改品牌【" + name + "】");
                break;

            case "/brand/delete":
                Flash.report(req, store.deleteBrand(id), "已删除品牌");
                break;

            default:
                Flash.err(req, "不认识的操作");
        }

        resp.sendRedirect(req.getContextPath() + "/brand");
    }

    private void showList(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        DataStore store = DataStore.get();
        List<Brand> list = store.allBrandList();

        // 每个品牌下有几件商品：页面要显示，也解释了「为什么这个删不掉」
        Map<Long, Integer> counts = new LinkedHashMap<>();
        for (Brand b : list) {
            counts.put(b.getId(), store.countByBrand(b.getName()));
        }

        req.setAttribute("brands", list);
        req.setAttribute("counts", counts);
        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/brand-list.jsp").forward(req, resp);
    }
}

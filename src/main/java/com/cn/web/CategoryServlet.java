package com.cn.web;

import com.cn.Category;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 分类管理：列表 + 新增 + 修改 + 删除，一个类管完
 *
 * @WebServlet 挂了四个地址，靠 req.getServletPath() 知道这次是哪个动作
 * （对于精确映射，getServletPath() 返回的就是匹配上的那个路径）：
 *
 *   GET  /category          → 列表
 *   POST /category/add      → 新增
 *   POST /category/update   → 修改
 *   POST /category/delete   → 删除
 *
 * 四个地址对应四个权限 code，权限判断全在 AuthFilter 里，
 * 所以这里一行 if 权限的代码都不用写 —— 能走进来说明已经有权限了。
 *
 * 页面上是「行内编辑」：输入框平时看着像纯文本，直接改完点保存就提交。
 * 这样不用为编辑单独做一个页面。
 *
 * @author 靳迎奥
 */
@WebServlet({"/category", "/category/add", "/category/update", "/category/delete"})
public class CategoryServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        showList(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {

        Long id        = Params.toLong(req.getParameter("id"));
        String name    = Params.trim(req.getParameter("name"));
        String remark  = Params.trim(req.getParameter("remark"));
        DataStore store = DataStore.get();

        switch (req.getServletPath()) {
            case "/category/add":
                Flash.report(req, store.addCategory(name, remark),
                        "已新增分类【" + name + "】");
                break;

            case "/category/update":
                Flash.report(req, store.updateCategory(id, name, remark),
                        "已修改分类【" + name + "】");
                break;

            case "/category/delete":
                Flash.report(req, store.deleteCategory(id), "已删除分类");
                break;

            default:
                Flash.err(req, "不认识的操作");
        }

        // 处理完一律重定向回列表（PRG：避免用户按 F5 重复提交）
        resp.sendRedirect(req.getContextPath() + "/category");
    }

    private void showList(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        DataStore store = DataStore.get();
        List<Category> list = store.allCategoryList();

        /* 每个分类下有几件商品。
           页面上要显示，用户也能一眼看出「这个分类为什么删不掉」。
           这里先算好挂到 request 上，JSP 里写 ${counts[cat.id]} 取值 ——
           页面里是拿不到 DataStore 的，数据必须在 Servlet 这一层准备好。 */
        Map<Long, Integer> counts = new LinkedHashMap<>();
        for (Category c : list) {
            counts.put(c.getId(), store.countByCategory(c.getName()));
        }

        req.setAttribute("categories", list);
        req.setAttribute("counts", counts);
        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/category-list.jsp").forward(req, resp);
    }
}

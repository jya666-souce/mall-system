package com.cn.web;

import com.cn.StoreItem;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Part;

import java.io.IOException;

/**
 * 商品表单：新增和编辑共用一套页面
 *
 * @WebServlet 一次挂两个地址，靠 req.getServletPath() 区分是哪一种：
 *
 *   GET  /product/add   → 空白表单
 *   GET  /product/edit  → 带数据的表单（?id=3）
 *   POST /product/add   → 提交新增
 *   POST /product/edit  → 提交修改
 *
 * 为什么新增和修改共用一个 JSP？
 *   两者字段完全一样，只有「标题」和「提交到哪」不同 ——
 *   页面里用一个 formMode 变量区分就够了，写两遍纯属复制粘贴。
 *
 * 权限在 AuthFilter 里按路径分开了：
 *   /product/add  → prod:add
 *   /product/edit → prod:upd
 * 所以能进新增页的人不一定能进编辑页，反之亦然。
 *
 * 表单因为要传图片，enctype 换成了 multipart/form-data，
 * 所以这个类上加了一行 @MultipartConfig —— 详见下面那段注释。
 *
 * @author 靳迎奥
 */
@WebServlet({"/product/add", "/product/edit"})
@MultipartConfig(
        /* 多大以内留在内存里，超过了就先落临时文件。
           512KB 是折中：小图标全程在内存里，快；
           几 MB 的大图不会一直占着堆内存，避免并发上传把内存吃光。 */
        fileSizeThreshold = 512 * 1024,
        /* 单个文件上限。超了 Tomcat 会抛 IllegalStateException，
           而不是让它默默写满磁盘。 */
        maxFileSize = 3 * 1024 * 1024,
        /* 整个请求的上限 = 图片 + 名称/价格/分类那几个文本字段。
           留出一倍余量，免得因为几个字段把合法的图误伤掉。 */
        maxRequestSize = 6 * 1024 * 1024
)
public class ProductFormServlet extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/product-edit.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        DataStore store = DataStore.get();
        boolean editing = "/product/edit".equals(req.getServletPath());

        if (editing) {
            Long id = Params.toLong(req.getParameter("id"));
            StoreItem it = store.getById(id);
            if (it == null) {
                Flash.err(req, "编号 " + req.getParameter("id") + " 的商品不存在");
                resp.sendRedirect(req.getContextPath() + "/product/list");
                return;
            }
            req.setAttribute("item", it);
        }

        req.setAttribute("formMode", editing ? "edit" : "add");
        req.setAttribute("catOptions", store.allCategories());
        req.setAttribute("brandOptions", store.allBrands());
        req.setAttribute("lowStockLine", DataStore.LOW_STOCK);
        req.setAttribute("maxImageMB", Uploads.MAX_BYTES / 1024 / 1024);

        // 品牌那两个常量传给页面，省得 JSP 和 JS 里各硬写一遍字符串
        // （写两遍就有写歪的机会，歪了就是「选了其他却没生效」）
        req.setAttribute("brandNameMax", DataStore.BRAND_NAME_MAX);
        req.setAttribute("brandOther", DataStore.BRAND_OTHER);

        Flash.take(req);
        req.getRequestDispatcher(VIEW).forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        boolean editing = "/product/edit".equals(req.getServletPath());

        /* ---------------------------------------------------------------
           取参数的这一段必须整个包在 try 里，原因是这么回事：

           表单是 multipart/form-data，请求体里混着文本字段和文件。
           容器是什么时候去解析这坨请求体的？—— 第一次调用
           getParameter() 或 getPart() 的那一刻（懒解析）。

           也就是说，图片一旦超过 maxFileSize，异常不是从 getPart()
           抛出来的，而是从**第一行 getParameter("id")** 就炸了。

           只把 getPart() 包起来是不够的 —— 那样异常会从上面漏出去，
           用户看到的是一张 500 错误页，而不是「图片太大」这句人话。
           --------------------------------------------------------------- */
        Long id = null;
        String name = "";
        String category = "";
        /* 品牌由两个控件共同决定，所以这里也留两个变量：
             brandPick  —— 下拉框的值：具体品牌名，或者哨兵 DataStore.BRAND_OTHER
             brandTyped —— 选了「其他」之后手输的那个名字 */
        String brandPick = "";
        String brandTyped = "";
        double price = -1;
        int stock = -1;
        boolean removeImage = false;
        Part filePart = null;

        long maxMB = Uploads.MAX_BYTES / 1024 / 1024;

        try {
            id          = Params.toLong(req.getParameter("id"));
            name        = Params.trim(req.getParameter("name"));
            category    = Params.trim(req.getParameter("category"));
            brandPick   = Params.trim(req.getParameter("brandPick"));
            brandTyped  = Params.trim(req.getParameter("brandCustom"));
            price       = Params.toDouble(req.getParameter("price"), -1);
            stock       = Params.toInt(req.getParameter("stock"), -1);
            removeImage = "1".equals(req.getParameter("removeImage"));

            /* 只有真的是 multipart 请求，才去取文件 —— 为什么非得判这一下？

               表单的 enctype 换成 multipart 之后，这个接口等于要同时伺候两种请求：
                 · 浏览器发来的 multipart/form-data（带图）
                 · 脚本或老调用方发来的 application/x-www-form-urlencoded（不带图）

               对第二种请求调 getPart()，Tomcat 会直接抛 ServletException。
               于是「只改个价格、不碰图片」这么一个完全正常的请求反而报错。

               判一下 contentType，两种都能用：
               服务器端宽松一点，比强行要求所有调用方都改一遍要划算。

               regionMatches(true, ...) 是「忽略大小写比较前缀」，
               用它而不是 toLowerCase() 是为了躲开土耳其语 locale 那种
               把 I 转成 ı 的怪毛病。 */
            String ct = req.getContentType();
            if (ct != null && ct.regionMatches(true, 0, "multipart/", 0, 10)) {
                filePart = req.getPart("imageFile");
            }
        } catch (IllegalStateException e) {
            // Tomcat 用它表示「某个 part 超过了 maxFileSize / maxRequestSize」
            backWithError(req, resp, editing, id, "图片太大了，请压到 " + maxMB + "MB 以内再传");
            return;
        } catch (ServletException e) {
            // 请求体不是合法的 multipart（比如被中途截断了）
            backWithError(req, resp, editing, id, "上传的内容读不出来，请重试一次");
            return;
        }

        // 价格和库存必须是非负数 —— 参数被手改成负数时要拦下来，
        // 不然会存进去一个「-5 件库存」这种没意义的数据
        if (price < 0) {
            backWithError(req, resp, editing, id, "价格必须是不小于 0 的数字");
            return;
        }
        if (stock < 0) {
            backWithError(req, resp, editing, id, "库存必须是不小于 0 的整数");
            return;
        }

        /* ---- 把两个品牌控件合成一个值 ----
           规则就一句话：下拉选的是「其他」，就用手输的那个名字；否则用下拉的。

           为什么非得在服务端判这一次，不让页面上的 JS 把值拼好再提交？
           因为 JS 只负责「好看」—— 选中「其他」时把输入框亮出来。
           真正的规则必须落在服务端：不然把 select 的 value 手动一改，
           就能塞进任意名字，前端那道约束等于不存在。 */
        String brand;
        if (DataStore.BRAND_OTHER.equals(brandPick)) {
            brand = brandTyped;
            if (brand.isEmpty()) {
                backWithError(req, resp, editing, id, "选了「其他」，记得把品牌名填上");
                return;
            }
        } else {
            brand = brandPick;
        }

        /* 品牌名本身合不合法（长度、非法字符）先在这里判掉。
           放到后面判就晚了 —— 商品可能已经存进去了、品牌却没登记成，
           留下「商品上挂着这个品牌、品牌表里却查不到」的悬空状态。 */
        if (!brand.isEmpty()) {
            String badBrand = DataStore.checkBrandName(brand);
            if (badBrand != null) {
                backWithError(req, resp, editing, id, badBrand);
                return;
            }
        }

        DataStore store = DataStore.get();

        // 先记下改动前的图片名。待会儿要靠它判断「旧图是不是真的被换掉了」
        StoreItem before = editing ? store.getById(id) : null;
        String oldImage = (before == null) ? null : before.getImage();

        /* ---- 存新图，放在改数据之前 ----
           顺序很重要：先存文件、再改数据。
           万一存图失败（格式不对、磁盘满），数据还一个字没动，退回表单页很干净。
           反过来先改数据再存图的话，就会出现「商品已保存但图片没存上」的中间状态。 */
        String newImage = null;
        if (filePart != null && filePart.getSize() > 0) {
            try {
                newImage = Uploads.save(getServletContext(), filePart);
            } catch (Uploads.UploadException e) {
                // message 就是给用户看的原话，直接透传
                backWithError(req, resp, editing, id, e.getMessage());
                return;
            } catch (IOException e) {
                backWithError(req, resp, editing, id, "图片保存失败，请稍后再试");
                return;
            }
        }

        String err = editing
                ? store.update(id, name, category, brand, price, stock, newImage, removeImage)
                : store.add(name, category, brand, price, stock, newImage);

        if (err != null) {
            /* 数据没存成（比如商品重名），刚才落盘的那张新图就没人引用了 ——
               立刻删掉，不然磁盘上会慢慢堆一堆孤儿文件。 */
            Uploads.delete(getServletContext(), newImage);
            backWithError(req, resp, editing, id, err);
            return;
        }

        /* ---- 数据改成功了，这时候才轮到清理旧图 ----
           为什么用「旧图名 ≠ 最终图名」来判断，而不是直接删旧图？
           因为用户可能只是改了价格，图片压根没动 ——
           那种情况下 oldImage 和最终值是一样的，不能删。 */
        StoreItem after = editing ? store.getById(id) : null;
        String finalImage = (after == null) ? newImage : after.getImage();
        if (oldImage != null && !oldImage.equals(finalImage)) {
            Uploads.delete(getServletContext(), oldImage);
        }

        /* 到这一步商品是真的存住了，可以放心把新品牌登记进品牌表。
           顺序为什么不能反？先登记品牌、再存商品的话，
           商品万一因为重名没存上，品牌库里就多出一个没人引用的名字 ——
           跟图片那边「先落盘还是先改数据」是同一类问题。 */
        String brandTip = "";
        if (!brand.isEmpty() && store.ensureBrand(brand)) {
            brandTip = "，品牌【" + brand + "】也一并加进了品牌库";
        }

        String tip = (newImage != null ? "（含新图片）" : "") + brandTip;
        Flash.ok(req, (editing ? "已修改商品【" : "已新增商品【") + name + "】" + tip);
        resp.sendRedirect(req.getContextPath() + "/product/list");
    }

    /** 出错就退回表单页，把提示带上（走重定向，避免 F5 重复提交） */
    private void backWithError(HttpServletRequest req, HttpServletResponse resp,
                               boolean editing, Long id, String msg) throws IOException {
        Flash.err(req, msg);
        String ctx = req.getContextPath();

        if (editing && id != null) {
            resp.sendRedirect(ctx + "/product/edit?id=" + id);
        } else if (editing) {
            resp.sendRedirect(ctx + "/product/list");
        } else {
            resp.sendRedirect(ctx + "/product/add");
        }
    }
}

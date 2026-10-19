package com.cn.web;

import com.cn.Brand;
import com.cn.CartLine;
import com.cn.Category;
import com.cn.Order;
import com.cn.OrderItem;
import com.cn.Permission;
import com.cn.Role;
import com.cn.StoreItem;
import com.cn.User;
import com.cn.UserRole;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 数据层：内存仓储（单例）
 *
 * 和控制台版最大的区别 —— 线程安全。
 *   控制台版只有一个 main 线程，怎么存都不会出问题；
 *   Servlet 是多线程的：Tomcat 每来一个请求就开一个线程，
 *   几十个请求同时读写同一份数据，用 HashMap / HashSet 会出问题
 *   （并发扩容时可能死循环、也可能丢数据）。
 *   所以容器全部换成 ConcurrentHashMap 系列。
 *
 * 商品仍然保留「一份数据存三个容器」的设计：
 *   itemSet      遍历 + 去重
 *   itemById     按编号查，O(1)
 *   itemByName   按名称查 + 判重
 * 分类、品牌各两个容器（按 id、按名称）。
 *
 * @author 靳迎奥
 */
public final class DataStore {

    /* ==================== 权限 code ==================== */
    /* 菜单级：进得去这个页面 */
    public static final String PERM_DASH     = "dash:view";

    public static final String PERM_LIST     = "prod:list";
    public static final String PERM_CAT_LIST = "cat:list";
    public static final String PERM_BRD_LIST = "brand:list";

    /* 按钮级：进得去页面，还得看能不能按那几个按钮 */
    public static final String PERM_FIND = "prod:find";
    public static final String PERM_ADD  = "prod:add";
    public static final String PERM_UPD  = "prod:upd";
    public static final String PERM_DEL  = "prod:del";
    public static final String PERM_SORT = "prod:sort";

    public static final String PERM_CAT_ADD = "cat:add";
    public static final String PERM_CAT_UPD = "cat:upd";
    public static final String PERM_CAT_DEL = "cat:del";

    public static final String PERM_BRD_ADD = "brand:add";
    public static final String PERM_BRD_UPD = "brand:upd";
    public static final String PERM_BRD_DEL = "brand:del";

    /* 订单：只有后台需要权限；前台下单只要有登录就行，不看权限码 */
    public static final String PERM_ORDER_LIST = "order:list";
    public static final String PERM_ORDER_UPD  = "order:upd";

    /* ==================== 其他常量 ==================== */

    /** 库存低于这个数就算「需要补货」 */
    public static final int LOW_STOCK = 50;

    /** 后台列表默认每页几条 */
    public static final int PAGE_SIZE = 8;

    /** 前台商城的商品网格，默认每页几件（卡片比表格占地方，所以少一点） */
    public static final int MALL_PAGE_SIZE = 12;

    /* ==================== 单例 ==================== */
    private static final DataStore INSTANCE = new DataStore();

    public static DataStore get() {
        return INSTANCE;
    }

    /* ==================== 存储容器（全部线程安全） ==================== */
    private final Set<StoreItem> itemSet = ConcurrentHashMap.newKeySet();
    private final Map<Long, StoreItem> itemById = new ConcurrentHashMap<>();
    private final Map<String, StoreItem> itemByName = new ConcurrentHashMap<>();

    private final Map<Long, Category> categoryById = new ConcurrentHashMap<>();
    private final Map<String, Category> categoryByName = new ConcurrentHashMap<>();

    private final Map<Long, Brand> brandById = new ConcurrentHashMap<>();
    private final Map<String, Brand> brandByName = new ConcurrentHashMap<>();

    private final Map<String, User> userByName = new ConcurrentHashMap<>();
    private final Map<Long, Role> roleById = new ConcurrentHashMap<>();

    /** 订单：每下一单就往这里加一条，之后的查询都走它 */
    private final Map<Long, Order> orderById = new ConcurrentHashMap<>();

    /** 发号器：用 AtomicLong 保证多线程下编号不重复 */
    private final AtomicLong idSeq = new AtomicLong(0);
    private final AtomicLong catSeq = new AtomicLong(0);
    private final AtomicLong brdSeq = new AtomicLong(0);
    private final AtomicLong orderSeq = new AtomicLong(0);

    private DataStore() {
        initRoles();
        initUsers();
        initCategories();
        initBrands();
        initProducts();
    }

    /* ==================== 初始化：角色 + 权限 ==================== */

    /**
     * 权限表是「菜单 + 按钮」两层：
     *   type = 0 菜单，侧边栏据此决定这一项显不显示
     *   type = 1 按钮，列表页据此决定「编辑/删除」按钮显不显示
     * pId 指向所属的菜单权限 id。
     */
    private void initRoles() {
        Permission pDash  = new Permission(1L,  PERM_DASH,     "工作台",   0, 0L);
        Permission pList  = new Permission(2L,  PERM_LIST,     "商品列表", 0, 0L);
        Permission pCat   = new Permission(3L,  PERM_CAT_LIST, "分类管理", 0, 0L);
        Permission pBrd   = new Permission(4L,  PERM_BRD_LIST, "品牌管理", 0, 0L);

        Permission pFind  = new Permission(5L,  PERM_FIND, "商品查询", 1, 2L);
        Permission pSort  = new Permission(6L,  PERM_SORT, "商品排序", 1, 2L);
        Permission pAdd   = new Permission(7L,  PERM_ADD,  "新增商品", 1, 2L);
        Permission pUpd   = new Permission(8L,  PERM_UPD,  "修改商品", 1, 2L);
        Permission pDel   = new Permission(9L,  PERM_DEL,  "删除商品", 1, 2L);

        Permission pCatAdd = new Permission(10L, PERM_CAT_ADD, "新增分类", 1, 3L);
        Permission pCatUpd = new Permission(11L, PERM_CAT_UPD, "修改分类", 1, 3L);
        Permission pCatDel = new Permission(12L, PERM_CAT_DEL, "删除分类", 1, 3L);

        Permission pBrdAdd = new Permission(13L, PERM_BRD_ADD, "新增品牌", 1, 4L);
        Permission pBrdUpd = new Permission(14L, PERM_BRD_UPD, "修改品牌", 1, 4L);
        Permission pBrdDel = new Permission(15L, PERM_BRD_DEL, "删除品牌", 1, 4L);

        Permission pOrder    = new Permission(16L, PERM_ORDER_LIST, "订单管理", 0, 0L);
        Permission pOrderUpd = new Permission(17L, PERM_ORDER_UPD,  "处理订单", 1, 16L);

        List<Permission> adminPerms = new ArrayList<>();
        Collections.addAll(adminPerms,
                pDash, pList, pCat, pBrd, pOrder,
                pFind, pSort, pAdd, pUpd, pDel,
                pCatAdd, pCatUpd, pCatDel,
                pBrdAdd, pBrdUpd, pBrdDel,
                pOrderUpd);

        // 普通用户：菜单进得去，查询和排序能用，但一个写按钮都没有。
        // 顺手也给了「订单管理」——他在后台是只读看客，
        // 但拿同一套账号去前台又能正常下单（前台下单不需要权限码，登录就行）
        List<Permission> userPerms = new ArrayList<>();
        Collections.addAll(userPerms, pDash, pList, pCat, pBrd, pFind, pSort, pOrder);

        Role admin = new Role();
        admin.setId(1L);
        admin.setName("admin");
        admin.setPerms(adminPerms);

        Role user = new Role();
        user.setId(2L);
        user.setName("user");
        user.setPerms(userPerms);

        roleById.put(admin.getId(), admin);
        roleById.put(user.getId(), user);
    }

    /* ==================== 初始化：登录账号 ==================== */

    private void initUsers() {
        userByName.put("admin", buildUser(1L, "管理员", "admin", 1L));
        userByName.put("user", buildUser(2L, "普通用户", "user", 2L));
    }

    private User buildUser(Long userId, String name, String username, Long roleId) {
        UserRole ur = new UserRole();
        ur.setId(userId);
        ur.setUserId(userId);
        ur.setRoleId(roleId);

        User u = new User();
        u.setId(userId);
        u.setName(name);
        u.setUsername(username);
        u.setPassword("123456");
        u.setUserRole(ur);
        return u;
    }

    /* ==================== 初始化：分类 / 品牌 ==================== */

    private void initCategories() {
        addCategory("食品", "休闲零食、饮料、生鲜");
        addCategory("数码", "电脑外设、影音、智能设备");
        addCategory("服饰", "男女服装、鞋靴");
        addCategory("家居", "厨具、日用品、家纺");
    }

    private void initBrands() {
        addBrand("可口可乐", "美国 · 饮料");
        addBrand("乐事", "美国 · 休闲食品");
        addBrand("罗技", "瑞士 · 电脑外设");
        addBrand("索尼", "日本 · 消费电子");
        addBrand("耐克", "美国 · 运动");
        addBrand("优衣库", "日本 · 服饰");
        addBrand("膳魔师", "德国 · 保温器具");
        addBrand("小米", "中国 · 智能硬件");
    }

    /* ==================== 初始化：8 条商品 ==================== */

    private void initProducts() {
        Object[][] data = {
                //   名称        分类     品牌       单价     库存
                {"可乐",     "食品", "可口可乐",  3.50,  200},
                {"薯片",     "食品", "乐事",      8.80,  120},
                {"机械键盘", "数码", "罗技",    399.00,   35},
                {"蓝牙耳机", "数码", "索尼",    899.00,   18},
                {"运动鞋",   "服饰", "耐克",    629.00,   42},
                {"纯棉T恤",  "服饰", "优衣库",   99.00,  150},
                {"保温杯",   "家居", "膳魔师",  259.00,   76},
                {"台灯",     "家居", "小米",    169.00,   90},
        };
        for (Object[] row : data) {
            add((String) row[0], (String) row[1], (String) row[2],
                    (Double) row[3], (Integer) row[4]);
        }
    }

    /* ==================== 登录与权限 ==================== */

    /** 登录：按用户名 O(1) 定位，再比对密码 */
    public User login(String username, String password) {
        if (username == null || password == null) return null;
        User u = userByName.get(username.trim());
        if (u == null) return null;
        return password.equals(u.getPassword()) ? u : null;
    }

    /** 按角色 id 取角色 */
    public Role roleOf(User user) {
        if (user == null || user.getUserRole() == null) return null;
        return roleById.get(user.getUserRole().getRoleId());
    }

    /** 取当前用户的权限 code 集合，JSP 里用它决定按钮显不显示 */
    public Set<String> permCodesOf(User user) {
        Set<String> codes = new HashSet<>();
        Role role = roleOf(user);
        if (role == null || role.getPerms() == null) return codes;
        for (Permission p : role.getPerms()) {
            codes.add(p.getCode());
        }
        return codes;
    }

    /** 判断当前用户有没有某个权限 */
    public boolean hasPerm(User user, String code) {
        return code != null && permCodesOf(user).contains(code);
    }

    /* ==================== 商品查询 ==================== */

    /** 按编号查，O(1) */
    public StoreItem getById(Long id) {
        return id == null ? null : itemById.get(id);
    }

    /** 按名称查，O(1)，用于判重 */
    public StoreItem getByName(String name) {
        return name == null ? null : itemByName.get(name.trim());
    }

    /** 商品总数 */
    public int count() {
        return itemById.size();
    }

    /**
     * 组合查询 + 排序（不带分页，分页在 page() 里切）
     *
     * @param keyword  名称 / 分类 / 品牌 的模糊关键字，可为空
     * @param category 分类精确匹配，可为空
     * @param brand    品牌精确匹配，可为空
     * @param min      价格下限，可为 null
     * @param max      价格上限，可为 null
     * @param sort     排序：priceDesc / priceAsc / stockDesc，为空则按编号
     */
    public List<StoreItem> query(String keyword, String category, String brand,
                                 Double min, Double max, String sort) {
        String kw = trimOrEmpty(keyword);
        String cat = trimOrEmpty(category);
        String brd = trimOrEmpty(brand);

        List<StoreItem> list = new ArrayList<>();
        for (StoreItem it : itemSet) {           // 遍历用 Set
            if (!kw.isEmpty()
                    && !contains(it.getName(), kw)
                    && !contains(it.getCategory(), kw)
                    && !contains(it.getBrand(), kw)) {
                continue;
            }
            if (!cat.isEmpty() && !cat.equals(it.getCategory())) {
                continue;
            }
            if (!brd.isEmpty() && !brd.equals(it.getBrand())) {
                continue;
            }
            if (min != null && it.getPrice() < min) continue;
            if (max != null && it.getPrice() > max) continue;
            list.add(it);
        }

        // 排序：Set 转成 List 之后才能排
        if ("priceAsc".equals(sort)) {
            Collections.sort(list, StoreItem.BY_PRICE_ASC);
        } else if ("stockDesc".equals(sort)) {
            Collections.sort(list, StoreItem.BY_STOCK_DESC);
        } else if ("priceDesc".equals(sort)) {
            Collections.sort(list);            // 用 compareTo，价格从高到低
        } else {
            Collections.sort(list, Comparator.comparing(StoreItem::getId));
        }
        return list;
    }

    /** 组合查询 + 分页 */
    public Page<StoreItem> page(String keyword, String category, String brand,
                                Double min, Double max, String sort, int pageNo, int size) {
        return Page.of(query(keyword, category, brand, min, max, sort), pageNo, size);
    }

    /* ==================== 商品增删改 ==================== */

    /**
     * 新增商品（不带图片）
     *
     * 留着这个 5 参版本是给 initProducts() 用的 ——
     * 内置那 8 件商品本来就没图，让初始化代码一行都不用改。
     */
    public synchronized String add(String name, String category, String brand,
                                   double price, int stock) {
        return add(name, category, brand, price, stock, null);
    }

    /**
     * 新增商品（带图片）
     *
     * @param image 图片文件名；没传图就是 null
     * @return null 表示成功，否则返回错误提示
     */
    public synchronized String add(String name, String category, String brand,
                                   double price, int stock, String image) {
        String n = trimOrEmpty(name);
        if (n.isEmpty()) return "商品名称不能为空";
        if (itemByName.containsKey(n)) return "商品名称【" + n + "】已存在";

        long id = idSeq.incrementAndGet();
        StoreItem it = new StoreItem(id, n, trimOrEmpty(category), trimOrEmpty(brand), price, stock);
        it.setImage(image);

        itemSet.add(it);
        itemById.put(id, it);
        itemByName.put(n, it);
        return null;
    }

    /**
     * 修改商品
     *
     * 图片字段是「三态」，不是简单覆盖 —— 这是表单里最容易做错的地方：
     *
     *   newImage != null     → 传了新图，换掉
     *   removeImage 为 true  → 没传新图、但勾了「删除图片」，清空
     *   两个都没有            → 保持原样（用户只是改了价格而已）
     *
     * 如果图省事写成 it.setImage(newImage)，会出什么事？
     *   用户每次改价格，图片都会被顺手抹掉 ——
     *   因为表单里没选文件的时候 newImage 就是 null，
     *   直接 set 等于「没传新图 = 把图删了」。
     *
     * @param newImage    新图文件名；null 表示这次没上传
     * @param removeImage 是否勾选了「删除图片」
     * @return null 表示成功，否则返回错误提示
     */
    public synchronized String update(Long id, String name, String category, String brand,
                                      double price, int stock,
                                      String newImage, boolean removeImage) {
        if (id == null) return "缺少商品编号";
        StoreItem it = itemById.get(id);
        if (it == null) return "编号 " + id + " 的商品不存在";

        String n = trimOrEmpty(name);
        if (n.isEmpty()) return "商品名称不能为空";

        // 改了名字的话，名称索引要跟着搬（三容器同步的关键）
        if (!n.equals(it.getName())) {
            if (itemByName.containsKey(n)) return "商品名称【" + n + "】已被其他商品占用";
            itemByName.remove(it.getName());
            it.setName(n);
            itemByName.put(n, it);
        }
        it.setCategory(trimOrEmpty(category));
        it.setBrand(trimOrEmpty(brand));
        it.setPrice(price);
        it.setStock(stock);

        if (newImage != null) {
            it.setImage(newImage);
        } else if (removeImage) {
            it.setImage(null);
        }
        return null;
    }

    /**
     * 删除商品
     *
     * @return null 表示成功，否则返回错误提示
     */
    public synchronized String delete(Long id) {
        if (id == null) return "缺少商品编号";
        StoreItem it = itemById.get(id);
        if (it == null) return "编号 " + id + " 的商品不存在";

        itemSet.remove(it);
        itemById.remove(id);
        itemByName.remove(it.getName());
        return null;
    }

    /**
     * 批量删除
     *
     * @return 「成功 n 条」这样的提示
     */
    public synchronized String deleteAll(List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return "没有勾选任何商品";
        }
        int ok = 0;
        for (Long id : ids) {
            if (delete(id) == null) ok++;
        }
        return "已删除 " + ok + " 条商品";
    }

    /* ==================== 分类 ==================== */

    /** 分类列表，按 id 排序 */
    public List<Category> allCategoryList() {
        List<Category> list = new ArrayList<>(categoryById.values());
        list.sort(Comparator.comparing(Category::getId));
        return list;
    }

    /** 分类名列表，给下拉框用 */
    public List<String> allCategories() {
        List<String> names = new ArrayList<>();
        for (Category c : allCategoryList()) {
            names.add(c.getName());
        }
        return names;
    }

    public Category getCategory(Long id) {
        return id == null ? null : categoryById.get(id);
    }

    public int countCategories() {
        return categoryById.size();
    }

    /** @return null 成功，否则错误提示 */
    public synchronized String addCategory(String name, String remark) {
        String n = trimOrEmpty(name);
        if (n.isEmpty()) return "分类名称不能为空";
        if (categoryByName.containsKey(n)) return "分类【" + n + "】已存在";

        long id = catSeq.incrementAndGet();
        Category c = new Category(id, n, trimOrEmpty(remark));
        categoryById.put(id, c);
        categoryByName.put(n, c);
        return null;
    }

    /** @return null 成功，否则错误提示 */
    public synchronized String updateCategory(Long id, String name, String remark) {
        Category c = getCategory(id);
        if (c == null) return "分类不存在";

        String n = trimOrEmpty(name);
        if (n.isEmpty()) return "分类名称不能为空";

        if (!n.equals(c.getName())) {
            if (categoryByName.containsKey(n)) return "分类【" + n + "】已存在";

            String old = c.getName();
            categoryByName.remove(old);
            renameCategoryInItems(old, n);   // 商品里存的是名字，得一起改
            c.setName(n);
            categoryByName.put(n, c);
        }
        c.setRemark(trimOrEmpty(remark));
        return null;
    }

    /** 分类下还有商品就不让删，否则商品会挂在一个不存在的分类上 */
    public synchronized String deleteCategory(Long id) {
        Category c = getCategory(id);
        if (c == null) return "分类不存在";

        int used = countByCategory(c.getName());
        if (used > 0) {
            return "还有 " + used + " 件商品属于这个分类，先改掉它们再删";
        }
        categoryById.remove(id);
        categoryByName.remove(c.getName());
        return null;
    }

    private void renameCategoryInItems(String oldName, String newName) {
        for (StoreItem it : itemSet) {
            if (oldName.equals(it.getCategory())) {
                it.setCategory(newName);
            }
        }
    }

    /** 某个分类下有几件商品 —— 分类列表页要显示，删除前也要拿它做拦截 */
    public int countByCategory(String category) {
        int n = 0;
        for (StoreItem it : itemSet) {
            if (category.equals(it.getCategory())) n++;
        }
        return n;
    }

    /* ==================== 品牌 ==================== */

    /** 品牌名长度上限，和品牌管理页表单上的 maxlength 保持一致 */
    public static final int BRAND_NAME_MAX = 20;

    /**
     * 「其他」这个选项在下拉里对应的值。
     *
     * 它不是任何真实品牌名，只是一个信号：「我选的是自己输入那条路」。
     * 单独拎成常量、而不是在 JSP 和 Servlet 里各写一遍字符串，
     * 是因为这两个地方必须永远一致 —— 一边改了另一边没改，
     * 提交上来的值就没人认得，表现为「选了其他却没生效」。
     */
    public static final String BRAND_OTHER = "__other__";

    /**
     * 校验品牌名，合法返回 null，否则返回一句能给用户看的错误提示。
     *
     * 为什么抽成 static 方法？—— 现在有两个地方会新增品牌：
     *   1. 品牌管理页那个「新增品牌」
     *   2. 商品表单里选了「其他」之后手输的名字
     * 两处规则必须一模一样，否则会出现「商品表单能存进去的名字，
     * 到了品牌管理页反而改不动」这种自相矛盾的状态。
     *
     * 顺带把 < > " ' 挡在门外：品牌名会直接显示在前后台页面上，
     * 与其指望每个输出点都记得转义，不如从源头不让它出现。
     * （该转义的地方照样转，这条只是多一层保险。）
     */
    public static String checkBrandName(String name) {
        String n = trimOrEmpty(name);
        if (n.isEmpty()) return "品牌名称不能为空";
        if (n.length() > BRAND_NAME_MAX) return "品牌名称最多 " + BRAND_NAME_MAX + " 个字";

        // 保留字不能当品牌名：真有个品牌叫 __other__ 的话，
        // 「选了其他」和「选了那个品牌」就分不清了
        if (BRAND_OTHER.equals(n)) return "这个名字不能用";

        for (int i = 0; i < n.length(); i++) {
            char ch = n.charAt(i);
            if (ch == '<' || ch == '>' || ch == '"' || ch == '\'') {
                return "品牌名称里不能有 < > \" ' 这几个符号";
            }
        }
        return null;
    }

    public List<Brand> allBrandList() {
        List<Brand> list = new ArrayList<>(brandById.values());
        list.sort(Comparator.comparing(Brand::getId));
        return list;
    }

    public List<String> allBrands() {
        List<String> names = new ArrayList<>();
        for (Brand b : allBrandList()) {
            names.add(b.getName());
        }
        return names;
    }

    public Brand getBrand(Long id) {
        return id == null ? null : brandById.get(id);
    }

    public int countBrands() {
        return brandById.size();
    }

    /** @return null 成功，否则错误提示 */
    public synchronized String addBrand(String name, String remark) {
        String n = trimOrEmpty(name);

        // 空值、超长、非法字符统一交给 checkBrandName 判，
        // 这样它和商品表单那边的规矩永远是一条
        String bad = checkBrandName(n);
        if (bad != null) return bad;

        if (brandByName.containsKey(n)) return "品牌【" + n + "】已存在";

        long id = brdSeq.incrementAndGet();
        Brand b = new Brand(id, n, trimOrEmpty(remark));
        brandById.put(id, b);
        brandByName.put(n, b);
        return null;
    }

    /**
     * 确保品牌表里有这个名字，没有就顺手登记一个。
     *
     * 给商品表单的「其他」用。为什么非要走这一步？
     * 因为品牌下拉的选项来自品牌表（allBrands 就是遍历 brandById 得来的），
     * 手输的品牌如果不登记，立刻会出现两个别扭的地方 ——
     *   1. 商品列表和前台商城的「品牌」筛选里没有它，那批商品筛不出来
     *   2. 品牌管理页看不到它，既写不了备注明，也统计不到商品数
     * 所以「只要用户手输了，它就是一个品牌」。
     *
     * 注意调用时机：必须在商品真的保存成功之后再调。
     * 反过来的话，商品因为重名没存上，品牌库里却多了一个没人用的名字。
     *
     * @return true = 这次真的新建了；false = 早就有了（或者名字是空的）
     */
    public synchronized boolean ensureBrand(String name) {
        String n = trimOrEmpty(name);
        if (n.isEmpty() || brandByName.containsKey(n)) return false;

        long id = brdSeq.incrementAndGet();
        Brand b = new Brand(id, n, "商品表单里手输的");
        brandById.put(id, b);
        brandByName.put(n, b);
        return true;
    }

    /** @return null 成功，否则错误提示 */
    public synchronized String updateBrand(Long id, String name, String remark) {
        Brand b = getBrand(id);
        if (b == null) return "品牌不存在";

        String n = trimOrEmpty(name);
        if (n.isEmpty()) return "品牌名称不能为空";

        if (!n.equals(b.getName())) {
            if (brandByName.containsKey(n)) return "品牌【" + n + "】已存在";

            String old = b.getName();
            brandByName.remove(old);
            renameBrandInItems(old, n);
            b.setName(n);
            brandByName.put(n, b);
        }
        b.setRemark(trimOrEmpty(remark));
        return null;
    }

    public synchronized String deleteBrand(Long id) {
        Brand b = getBrand(id);
        if (b == null) return "品牌不存在";

        int used = countByBrand(b.getName());
        if (used > 0) {
            return "还有 " + used + " 件商品属于这个品牌，先改掉它们再删";
        }
        brandById.remove(id);
        brandByName.remove(b.getName());
        return null;
    }

    private void renameBrandInItems(String oldName, String newName) {
        for (StoreItem it : itemSet) {
            if (oldName.equals(it.getBrand())) {
                it.setBrand(newName);
            }
        }
    }

    /** 某个品牌下有几件商品 */
    public int countByBrand(String brand) {
        int n = 0;
        for (StoreItem it : itemSet) {
            if (brand.equals(it.getBrand())) n++;
        }
        return n;
    }

    /* ==================== 订单 ==================== */

    /**
     * 下单：整体校验 → 扣库存 → 生成订单
     *
     * 整个方法挂了 synchronized，因为它动的是「库存」这个共享资源。
     * 不加会出什么事？两个人同时买最后一件：
     *   A 线程读到库存 1 → 判断够
     *   B 线程也读到库存 1 → 也判断够
     *   两人各扣一次 → 库存变成 -1，卖出去两件
     * 这就是「超卖」。
     *
     * 关键是校验和扣减必须在同一把锁里 ——
     * 如果先不加锁地校验、再进锁扣减，中间那段空隙照样能钻进来。
     *
     * @param lines 购物车明细（已经和商品关联过）
     * @return null 表示成功，否则是错误提示
     */
    public synchronized String placeOrder(User user, List<CartLine> lines,
                                          String receiver, String phone, String address) {
        if (user == null) {
            return "请先登录再下单";
        }
        if (lines == null || lines.isEmpty()) {
            return "购物车是空的，先挑几件商品吧";
        }
        if (trimOrEmpty(receiver).isEmpty()) {
            return "请填写收货人姓名";
        }
        if (trimOrEmpty(phone).isEmpty()) {
            return "请填写联系电话";
        }
        if (trimOrEmpty(address).isEmpty()) {
            return "请填写收货地址";
        }

        // ① 先整体过一遍，确认全部买得了
        //    为什么不边校验边扣？因为扣到第三件才发现库存不够，
        //    前两件已经扣掉了，还得再还回去 —— 麻烦，而且容易漏。
        //    先全检查、再全扣，逻辑干净得多。
        for (CartLine l : lines) {
            if (l.isMissing()) {
                return "购物车里有商品已经下架了，请先移除它";
            }
            if (l.getQty() <= 0) {
                return "商品数量不合法";
            }
            if (l.getQty() > l.getItem().getStock()) {
                return "【" + l.getItem().getName() + "】库存只剩 "
                        + l.getItem().getStock() + " 件，请调整数量";
            }
        }

        // ② 校验全过，再统一扣库存
        for (CartLine l : lines) {
            StoreItem it = l.getItem();
            it.setStock(it.getStock() - l.getQty());
        }

        // ③ 生成订单：商品信息存快照，不存引用
        long id = orderSeq.incrementAndGet();
        Order o = new Order();
        o.setId(id);
        o.setOrderNo(genOrderNo(id));
        o.setUserId(user.getId());
        o.setUsername(user.getUsername());
        o.setReceiver(trimOrEmpty(receiver));
        o.setPhone(trimOrEmpty(phone));
        o.setAddress(trimOrEmpty(address));
        o.setStatus(Order.STATUS_PENDING);
        o.setCreateTime(nowText());

        List<OrderItem> rows = new ArrayList<>();
        double total = 0;
        for (CartLine l : lines) {
            StoreItem it = l.getItem();
            OrderItem oi = new OrderItem(it.getId(), it.getName(), it.getPrice(), l.getQty());
            rows.add(oi);
            total += oi.getSubtotal();
        }
        o.setItems(rows);
        o.setTotal(total);

        orderById.put(id, o);
        return null;
    }

    /** 某个用户自己的订单，新的排前面 */
    public List<Order> ordersOf(Long userId) {
        List<Order> list = new ArrayList<>();
        for (Order o : orderById.values()) {
            if (Objects.equals(o.getUserId(), userId)) {
                list.add(o);
            }
        }
        list.sort(Comparator.comparing(Order::getId).reversed());
        return list;
    }

    /** 全部订单，新的排前面（后台用） */
    public List<Order> allOrders() {
        List<Order> list = new ArrayList<>(orderById.values());
        list.sort(Comparator.comparing(Order::getId).reversed());
        return list;
    }

    public Order getOrder(Long id) {
        return id == null ? null : orderById.get(id);
    }

    public int countOrders() {
        return orderById.size();
    }

    /**
     * 改订单状态（后台处理订单用）
     *
     * 取消要回滚库存，所以这里也必须 synchronized ——
     * 否则「取消」和「下单」可能同时改同一个商品的库存，件数就还错了。
     *
     * @return null 成功，否则错误提示
     */
    public synchronized String updateOrderStatus(Long id, String status) {
        Order o = getOrder(id);
        if (o == null) {
            return "订单不存在";
        }
        if (o.isFinal()) {
            return "订单已经是「" + o.getStatus() + "」，不能再改";
        }
        if (Order.STATUS_CANCELED.equals(status)) {
            restock(o);                             // 取消 → 把货还回库存
        } else if (Order.STATUS_DONE.equals(status)) {
            if (!o.isCompletable()) {
                return "还没发货，不能直接标记完成";
            }
        } else if (!Order.STATUS_SHIPPED.equals(status)) {
            return "不认识的状态：" + status;
        }

        o.setStatus(status);
        return null;
    }

    /**
     * 把订单里的商品按数量退回库存
     *
     * 商品可能已经被后台删掉了 —— 那种就跳过。
     * 这里故意不报错：取消订单本身是成功的，
     * 为了一件已经不存在的商品让整个取消失败，不合理。
     */
    private void restock(Order o) {
        for (OrderItem oi : o.getItems()) {
            StoreItem it = itemById.get(oi.getItemId());
            if (it != null) {
                it.setStock(it.getStock() + oi.getQty());
            }
        }
    }

    /** 订单号：日期 + 4 位流水，形如 202609220001 */
    private String genOrderNo(long id) {
        return new SimpleDateFormat("yyyyMMdd").format(new Date()) + String.format("%04d", id);
    }

    /** 下单时间存成字符串，页面上直接显示，不用再格式化一遍 */
    private String nowText() {
        return new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());
    }

    /* ==================== 工作台统计 ==================== */

    /** 库存总量 */
    public int totalStock() {
        int sum = 0;
        for (StoreItem it : itemSet) {
            sum += it.getStock();
        }
        return sum;
    }

    /** 库存总价值（单价 × 库存 累加） */
    public double totalValue() {
        double sum = 0;
        for (StoreItem it : itemSet) {
            sum += it.getPrice() * it.getStock();
        }
        return sum;
    }

    /** 库存告急的商品，库存少的排前面 */
    public List<StoreItem> lowStockItems() {
        List<StoreItem> list = new ArrayList<>();
        for (StoreItem it : itemSet) {
            if (it.getStock() < LOW_STOCK) {
                list.add(it);
            }
        }
        list.sort(Comparator.comparingInt(StoreItem::getStock));
        return list;
    }

    /** 分类分布：每个分类下有几件商品 */
    public List<Stat> categoryStats() {
        Map<String, Integer> map = new LinkedHashMap<>();
        for (Category c : allCategoryList()) {
            map.put(c.getName(), 0);        // 先按分类表铺底，没有商品的分类也显示出来
        }
        for (StoreItem it : itemSet) {
            String key = trimOrEmpty(it.getCategory());
            if (key.isEmpty()) key = "未分类";
            map.merge(key, 1, Integer::sum);
        }
        return toStats(map);
    }

    /** 品牌分布：每个品牌下有几件商品 */
    public List<Stat> brandStats() {
        Map<String, Integer> map = new LinkedHashMap<>();
        for (Brand b : allBrandList()) {
            map.put(b.getName(), 0);
        }
        for (StoreItem it : itemSet) {
            String key = trimOrEmpty(it.getBrand());
            if (key.isEmpty()) key = "无品牌";
            map.merge(key, 1, Integer::sum);
        }
        return toStats(map);
    }

    /**
     * 把「名字 → 数量」转成带百分比的统计项列表
     * percent 是相对最大值的比例，条形图直接用
     */
    private static List<Stat> toStats(Map<String, Integer> map) {
        int max = 0;
        for (int v : map.values()) {
            max = Math.max(max, v);
        }
        List<Stat> list = new ArrayList<>();
        for (Map.Entry<String, Integer> e : map.entrySet()) {
            int percent = (max == 0) ? 0 : (int) Math.round(e.getValue() * 100.0 / max);
            list.add(new Stat(e.getKey(), e.getValue(), percent));
        }
        return list;
    }

    /* ==================== 小工具 ==================== */

    private static String trimOrEmpty(String s) {
        return s == null ? "" : s.trim();
    }

    private static boolean contains(String src, String kw) {
        return src != null && src.contains(kw);
    }
}

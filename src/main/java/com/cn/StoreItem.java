package com.cn;

import java.util.Comparator;
import java.util.Objects;


public class StoreItem implements Comparable<StoreItem> {
    private Long id;
    private String name;
    private String category;     // 分类：食品、数码、服饰……
    private String brand;        // 品牌
    private double price;
    private int stock;           // 库存
    /**
     * 商品图片的「文件名」，没图就是 null
     *
     * 只存文件名（比如 "3f9a1c2b7e4d5061.png"），不存完整路径，也不存 URL：
     *   存路径 → 以后图片换个盘就得改所有数据
     *   存 URL  → 域名一换、http 换 https，历史数据全废
     *   存文件名 → 页面按 ${ctx}/img?name=${it.image} 自己拼，最灵活
     *
     * 顺带说一句：这里存的永远是 Uploads 生成的那个随机名，
     * 绝不会是用户上传时的原始文件名 —— 原因见 Uploads.randomName()。
     */
    private String image;

    public static final Comparator<StoreItem> BY_PRICE_ASC =
            new Comparator<StoreItem>() {
                @Override
                public int compare(StoreItem a, StoreItem b) {
                    return Double.compare(a.price, b.price);
                }
            };

    public static final Comparator<StoreItem> BY_STOCK_DESC =
            new Comparator<StoreItem>() {
                @Override
                public int compare(StoreItem a, StoreItem b) {
                    return Integer.compare(b.stock, a.stock);
                }
            };

    public StoreItem() {
    }

    public StoreItem(Long id, String name, String category,
                     String brand, double price, int stock) {
        this.id = id;
        this.name = name;
        this.category = category;
        this.brand = brand;
        this.price = price;
        this.stock = stock;
    }

    @Override
    public int compareTo(StoreItem o) {
        return Double.compare(o.price, this.price);
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getBrand() {
        return brand;
    }

    public void setBrand(String brand) {
        this.brand = brand;
    }

    public double getPrice() {
        return price;
    }

    /**
     * 价格显示文本：固定两位小数（3.5 → "3.50"）
     *
     * 为什么不直接在 JSP 里用 &lt;fmt:formatNumber&gt;？
     *   实测 JSTL 3.0.1 的 fmt 标签在 Tomcat 11 上属性会失效 ——
     *   minFractionDigits / maxFractionDigits / pattern 全被忽略，
     *   value="12.3" 原样输出成 "12.3"，而不是 "12.30"。
     *   （根因是 JSTL 3.0 面向 EL 5.0 编译，Tomcat 11 用的是 EL 6.0）
     *   所以格式化放在 Java 侧做，最稳，也最好调试。
     *
     * 方法名 getPriceText → JSP 里写 ${it.priceText}
     */
    public String getPriceText() {
        return String.format("%.2f", price);
    }

    /**
     * 商品名第一个字 —— 前台卡片拿它当占位图
     *
     * 为什么不直接在 JSP 里写 ${fn:substring(it.name, 0, 1)}？
     *   能用，但这个项目在 JSTL 上已经踩过一次坑了
     *   （JSTL 3.0 面向 EL 5.0 编译，Tomcat 11 用的是 EL 6.0，fmt 标签属性会失效）。
     *   「取一个字符」这种小事放 Java 侧最省心，也最好调试。
     *   名字为空就给个问号，别让页面出现一个空色块。
     */
    public String getInitial() {
        if (name == null || name.isEmpty()) {
            return "?";
        }
        return name.substring(0, 1);
    }

    public void setPrice(double price) {
        this.price = price;
    }

    public int getStock() {
        return stock;
    }

    public void setStock(int stock) {
        this.stock = stock;
    }

    /** 图片文件名，没图返回 null */
    public String getImage() {
        return image;
    }

    public void setImage(String image) {
        this.image = image;
    }

    /**
     * 格式化输出：列表里一行显示一个商品
     */
    public String toRow() {
        return String.format("编号:%-3d %-10s | 分类:%-6s | 品牌:%-8s | 单价:￥%-8.2f | 库存:%-4d",
                id, name, category, brand, price, stock);
    }

    @Override
    public String toString() {
        return "StoreItem{" +
                "id=" + id +
                ", name='" + name + '\'' +
                ", category='" + category + '\'' +
                ", brand='" + brand + '\'' +
                ", price=" + price +
                ", stock=" + stock +
                '}';
    }

    /**
     * 按 id 判等：HashSet/HashMap 去重依据
     */
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        StoreItem that = (StoreItem) o;
        return Objects.equals(id, that.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }
}

package com.cn;

/**
 * 购物车明细行 —— 纯粹为显示服务
 *
 * 为什么不把 Map&lt;Long,Integer&gt; 直接丢给 JSP？
 *   页面上要显示商品名、单价、小计，这些都在 StoreItem 里，
 *   得先「关联」一下才能算出来。这种关联写在 JSP 里又丑又容易错，
 *   所以在 Java 侧拼好再交给页面。
 *
 * item 可能是 null —— 商品被后台删了，但购物车里还留着那个编号。
 * 这种情况必须显式显示出来并在结算时拦住，
 * 不能让用户一路点到「提交订单」才看到报错。
 *
 * @author 靳迎奥
 */
public class CartLine {

    private final Long itemId;
    private final int qty;
    private final StoreItem item;   // 可能为 null（商品已下架）

    public CartLine(Long itemId, int qty, StoreItem item) {
        this.itemId = itemId;
        this.qty = qty;
        this.item = item;
    }

    public Long getItemId() {
        return itemId;
    }

    public int getQty() {
        return qty;
    }

    public StoreItem getItem() {
        return item;
    }

    /** 商品还在不在（被后台删掉就是 false） */
    public boolean isMissing() {
        return item == null;
    }

    /** 想买的数量超过现库存了？ */
    public boolean isOverStock() {
        return item != null && qty > item.getStock();
    }

    /** this 这一行有没有问题 —— 有问题就不让结算 */
    public boolean isBad() {
        return isMissing() || isOverStock();
    }

    /* ---- 下面几个是给 JSP 直接取的便利属性，省得页面上写三目运算 ---- */

    public String getName() {
        return item == null ? "（商品已下架）" : item.getName();
    }

    /** 占位色块上那个字；商品已经没了就给个问号 */
    public String getInitial() {
        return item == null ? "?" : item.getInitial();
    }

    /**
     * 商品图片文件名；商品已经没了就返回 null
     *
     * 为什么不直接让页面写 ${l.item.image}？
     *   因为 item 可以是 null，EL 取 null 的属性会得到 null 而不是报错，
     *   但页面里就多出一堆「先判 item 再判 image」的嵌套判断。
     *   把判空收在 Java 这一侧，页面只写一句 ${not empty l.image} 就行。
     */
    public String getImage() {
        return item == null ? null : item.getImage();
    }

    public String getCategory() {
        return item == null ? "" : item.getCategory();
    }

    public String getBrand() {
        return item == null ? "" : item.getBrand();
    }

    public String getPriceText() {
        return item == null ? "0.00" : item.getPriceText();
    }

    /** 小计 = 单价 × 数量；商品没了就算 0 */
    public double getSubtotal() {
        return item == null ? 0 : item.getPrice() * qty;
    }

    public String getSubtotalText() {
        return String.format("%.2f", getSubtotal());
    }
}

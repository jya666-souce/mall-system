package com.cn;

/**
 * 订单明细行 —— 下单那一刻的商品快照
 *
 * 注意这里存的是 name 和 price 的**副本**，而不是「商品编号 + 现查」。
 * 为什么？
 *   后台明天把「机械键盘」从 399 调到 299，
 *   昨天那张订单必须还是 399 —— 当时真收了这么多钱。
 *   如果订单只存编号、显示时现查商品，历史订单的金额就会跟着变，账就乱了。
 *
 * 这个「快照」和购物车那个「实时」正好是一对反例，
 * 放在一起看能想明白：什么时候该存副本，什么时候该存引用。
 *
 * @author 靳迎奥
 */
public class OrderItem {

    private Long itemId;
    private String name;
    private double price;   // 下单时的单价
    private int qty;

    public OrderItem() {
    }

    public OrderItem(Long itemId, String name, double price, int qty) {
        this.itemId = itemId;
        this.name = name;
        this.price = price;
        this.qty = qty;
    }

    /** 小计 = 快照单价 × 数量 */
    public double getSubtotal() {
        return price * qty;
    }

    public String getSubtotalText() {
        return String.format("%.2f", getSubtotal());
    }

    public String getPriceText() {
        return String.format("%.2f", price);
    }

    public Long getItemId() {
        return itemId;
    }

    public void setItemId(Long itemId) {
        this.itemId = itemId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public double getPrice() {
        return price;
    }

    public void setPrice(double price) {
        this.price = price;
    }

    public int getQty() {
        return qty;
    }

    public void setQty(int qty) {
        this.qty = qty;
    }
}

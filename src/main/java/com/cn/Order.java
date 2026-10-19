package com.cn;

import java.util.ArrayList;
import java.util.List;

/**
 * 订单
 *
 * 状态只有四个，而且流转是单向的：
 *
 *     待发货 ──发货──▶ 已发货 ──完成──▶ 已完成
 *        │
 *        └──取消──▶ 已取消
 *
 * 「已完成」和「已取消」是终态，进去了就不能再改。
 * 取消会把库存还回去 —— 所以取消和下单必须互斥，
 * 两个方法在 DataStore 里都挂了 synchronized。
 *
 * 为什么状态用常量字符串而不是 int 枚举？
 *   因为要直接显示在页面上。用 int 的话每次都得再翻译一遍，
 *   这里数据量小、状态固定，字符串更省事也更好读。
 *
 * @author 靳迎奥
 */
public class Order {

    public static final String STATUS_PENDING  = "待发货";
    public static final String STATUS_SHIPPED  = "已发货";
    public static final String STATUS_DONE     = "已完成";
    public static final String STATUS_CANCELED = "已取消";

    /** 状态清单，后台的下拉框用它铺选项 */
    public static List<String> statusList() {
        List<String> list = new ArrayList<>();
        list.add(STATUS_PENDING);
        list.add(STATUS_SHIPPED);
        list.add(STATUS_DONE);
        list.add(STATUS_CANCELED);
        return list;
    }

    private Long id;
    private String orderNo;     // 订单号，形如 202609220001
    private Long userId;
    private String username;    // 下单人的登录名，后台列表要显示
    private String receiver;    // 收货人
    private String phone;
    private String address;
    private double total;
    private String status = STATUS_PENDING;
    private String createTime;
    private List<OrderItem> items = new ArrayList<>();

    /** 这张单总共几件（不是几行） */
    public int getItemCount() {
        int n = 0;
        for (OrderItem it : items) {
            n += it.getQty();
        }
        return n;
    }

    public String getTotalText() {
        return String.format("%.2f", total);
    }

    /* ==================== 状态开关 ====================
       判断逻辑写在 Java 里只有一份，
       页面直接写 ${order.cancelable}、${order.shippable}，
       不用在 JSP 里堆 c:if 比字符串。 */

    /** 只有「待发货」能取消 */
    public boolean isCancelable() {
        return STATUS_PENDING.equals(status);
    }

    /** 只有「待发货」能发货 */
    public boolean isShippable() {
        return STATUS_PENDING.equals(status);
    }

    /** 只有「已发货」能标记完成 */
    public boolean isCompletable() {
        return STATUS_SHIPPED.equals(status);
    }

    /** 终态：已完成 / 已取消 */
    public boolean isFinal() {
        return STATUS_DONE.equals(status) || STATUS_CANCELED.equals(status);
    }

    /** 给状态标签配个颜色类名，页面上 class="badge badge-${order.statusClass}" */
    public String getStatusClass() {
        if (STATUS_PENDING.equals(status)) {
            return "warn";
        }
        if (STATUS_SHIPPED.equals(status)) {
            return "info";
        }
        if (STATUS_DONE.equals(status)) {
            return "ok";
        }
        return "gray";
    }

    /* ==================== getter / setter ==================== */

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getOrderNo() {
        return orderNo;
    }

    public void setOrderNo(String orderNo) {
        this.orderNo = orderNo;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getReceiver() {
        return receiver;
    }

    public void setReceiver(String receiver) {
        this.receiver = receiver;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public double getTotal() {
        return total;
    }

    public void setTotal(double total) {
        this.total = total;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getCreateTime() {
        return createTime;
    }

    public void setCreateTime(String createTime) {
        this.createTime = createTime;
    }

    public List<OrderItem> getItems() {
        return items;
    }

    public void setItems(List<OrderItem> items) {
        this.items = items == null ? new ArrayList<>() : items;
    }
}

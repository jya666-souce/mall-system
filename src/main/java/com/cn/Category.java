package com.cn;

import java.util.Objects;

/**
 * 商品分类
 *
 * 这里做的是「加字段」，不是「改签名」 ——
 * 老构造器 Category(String) 被 Shop.java 用着，必须原样保留，否则那个类编译不过。
 *
 * 一个要心里有数的设计取舍：
 *   商品里存的分类仍然是「名字」这个字符串，而不是分类 id。
 *   改成 id 关联要连带改 StoreItem、JSP、所有查询条件，动静太大。
 *   代价就是改分类名的时候，得遍历商品把旧名字一起改掉
 *   （见 DataStore.updateCategory）。
 *   真实项目里应该老老实实用 id 做外键 —— 这里的做法是为了控制改动面。
 *
 * @author 靳迎奥
 */
public class Category {

    private Long id;
    private String name;
    private String remark;   // 备注

    /** 老构造器：Shop.java 在用，不能删 */
    public Category(String name) {
        this.name = name;
    }

    public Category(Long id, String name, String remark) {
        this.id = id;
        this.name = name;
        this.remark = remark;
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

    public String getRemark() {
        return remark;
    }

    public void setRemark(String remark) {
        this.remark = remark;
    }

    /** 下拉框里直接 ${cat} 就会调用它 */
    @Override
    public String toString() {
        return name;
    }

    /**
     * 按 id 判等；id 都为空时退化成按名字比。
     * 这样既能在 Set/Map 里正确去重，也不会让 Shop.java 里那个
     * 没有 id 的临时对象行为诡异。
     */
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Category c = (Category) o;
        if (id != null && c.id != null) return id.equals(c.id);
        return Objects.equals(name, c.name);
    }

    @Override
    public int hashCode() {
        return id != null ? Objects.hash(id) : Objects.hash(name);
    }
}

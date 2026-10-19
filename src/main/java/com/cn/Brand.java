package com.cn;

import java.util.Objects;

/**
 * 商品品牌
 *
 * 和 Category 一样：只加字段，保留老构造器 Brand(String) —— Shop.java 在用。
 *
 * @author 靳迎奥
 */
public class Brand {

    private Long id;
    private String name;
    private String remark;   // 备注，比如「瑞士 · 电脑外设」

    /** 老构造器：Shop.java 在用，不能删 */
    public Brand(String name) {
        this.name = name;
    }

    public Brand(Long id, String name, String remark) {
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

    @Override
    public String toString() {
        return name;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Brand b = (Brand) o;
        if (id != null && b.id != null) return id.equals(b.id);
        return Objects.equals(name, b.name);
    }

    @Override
    public int hashCode() {
        return id != null ? Objects.hash(id) : Objects.hash(name);
    }
}

package com.cn;

import java.util.Objects;

/**
 * 权限：菜单/按钮
 * - code 用 final 修饰：权限标识一旦确定不可改（体现 final 关键字）
 * - 重写 equals/hashCode，基于 code（业务唯一标识）
 */
public class Permission {
    private Long id;
    private final String code;   // 权限标识：不可变
    private String name;
    private int type;            // 0:菜单  1:按钮
    private Long pId;

    public Permission(Long id, String code, String name, int type, Long pId) {
        this.id = id;
        this.code = code;
        this.name = name;
        this.type = type;
        this.pId = pId;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getCode() {
        return code;
    }
    // code 没有 setter，构造后不可变

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getType() {
        return type;
    }

    public void setType(int type) {
        this.type = type;
    }

    public Long getpId() {
        return pId;
    }

    public void setpId(Long pId) {
        this.pId = pId;
    }

    /**
     * 按 code 判等：code 是 final 业务唯一标识
     */
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Permission that = (Permission) o;
        return Objects.equals(code, that.code);
    }

    /**
     * hashCode 与 equals 一致：基于 code
     */
    @Override
    public int hashCode() {
        return Objects.hash(code);
    }
}

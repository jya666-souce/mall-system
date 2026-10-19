package com.cn;

import java.util.List;
import java.util.Objects;

public class Role {
    private Long id;
    private String name;
    private List<Permission> perms;

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

    public List<Permission> getPerms() {
        return perms;
    }

    public void setPerms(List<Permission> perms) {
        this.perms = perms;
    }

    /**
     * 按 id 判等
     */
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Role role = (Role) o;
        return Objects.equals(getId(), role.getId());
    }

    @Override
    public int hashCode() {
        return Objects.hash(getId());
    }
}

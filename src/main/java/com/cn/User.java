package com.cn;

import java.util.Objects;

public class User extends Person {
    private String username;
    private String password;
    private UserRole userRole;

    public User() {
    }

    public User(Long id, String name) {
        super(id, name);
    }

    @Override
    public void introduce() {
        System.out.println("系统用户：" + getName() + "（账号：" + username + "）");
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public UserRole getUserRole() {
        return userRole;
    }

    public void setUserRole(UserRole userRole) {
        this.userRole = userRole;
    }

    /**
     * 按 id 判等
     */
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        User user = (User) o;
        return Objects.equals(getId(), user.getId());
    }

    @Override
    public int hashCode() {
        return Objects.hash(getId());
    }
}

<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" %>
<%@ page import="java.net.URLEncoder" %>
<%
    // 获取当前用户名(如果存在)，用于显示在退出消息中
    String username = (String) session.getAttribute("username");
    
    // 清除用户名 Cookie
    Cookie usernameCookie = new Cookie("username", "");
    usernameCookie.setMaxAge(0); // 设置为0表示立即删除
    usernameCookie.setPath(request.getContextPath().length() > 0 ? request.getContextPath() : "/"); // 确保路径匹配
    response.addCookie(usernameCookie);
    
    // 清除会话中的所有属性
    session.invalidate();
    
    // 构建成功消息
    String message = "您已成功退出系统";
    if (username != null && !username.trim().isEmpty()) {
        message = "再见，" + username + "！您已成功退出系统。";
    }
    
    // 重定向到登录页面，并传递成功消息
    response.sendRedirect("login.jsp?message=" + URLEncoder.encode(message, "UTF-8"));
%>

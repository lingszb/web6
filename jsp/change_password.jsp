<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" %>
<%@ page import="java.net.URLDecoder" %> 
<%
    // 设置请求字符编码为UTF-8，防止获取参数时出现乱码
    request.setCharacterEncoding("UTF-8");
    
    // 获取并解码错误消息参数
    String errorMessage = request.getParameter("error");
    if (errorMessage != null) {
        try {
            errorMessage = URLDecoder.decode(errorMessage, "UTF-8");
        } catch (Exception e) {
            // 静默处理解码错误
            errorMessage = "显示消息时出错";
        }
    }
    
    // 获取并解码信息消息参数
    String infoMessage = request.getParameter("info");
    if (infoMessage != null) {
        try {
            infoMessage = URLDecoder.decode(infoMessage, "UTF-8");
        } catch (Exception e) {
            // 静默处理解码错误
            infoMessage = "显示消息时出错";
        }
    }
    
    // 如果用户已登录，尝试从会话中获取用户名
    String loggedInUsername = (String) session.getAttribute("username");
%>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>修改密码 - 用户管理系统</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <div class="password-container">
        <h2>修改密码</h2>
        
        <% if (errorMessage != null && !errorMessage.isEmpty()) { %>
            <p class="error-message"><%= errorMessage %></p>
        <% } %>
        
        <% if (infoMessage != null && !infoMessage.isEmpty()) { %>
            <p class="info-message"><%= infoMessage %></p>
        <% } %>
        
        <form action="change_password_action.jsp" method="post">
            <div class="form-group">
                <label for="username">用户名:</label>
                <input type="text" id="username" name="username" value="<%= loggedInUsername != null ? loggedInUsername : "" %>" <%= loggedInUsername != null ? "readonly" : "" %> required>
            </div>
            <div class="form-group">
                <label for="oldPassword">当前密码:</label>
                <input type="password" id="oldPassword" name="oldPassword" required>
            </div>
            <div class="form-group">
                <label for="newPassword">新密码:</label>
                <input type="password" id="newPassword" name="newPassword" required>
            </div>
            <div class="form-group">
                <label for="confirmPassword">确认新密码:</label>
                <input type="password" id="confirmPassword" name="confirmPassword" required>
            </div>
            <button type="submit">修改密码</button>
        </form>
        
        <div class="login-link">
            <a href="login.jsp">返回登录</a>
            <% if (loggedInUsername != null) { %>
                &nbsp;|&nbsp;<a href="welcome.jsp">返回个人主页</a>
            <% } %>
        </div>
    </div>
</body>
</html>

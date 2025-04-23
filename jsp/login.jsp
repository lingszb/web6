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

    // 获取并解码提示消息参数
    String infoMessage = request.getParameter("message");
    if (infoMessage != null) {
        try {
            infoMessage = URLDecoder.decode(infoMessage, "UTF-8");
        } catch (Exception e) {
            // 静默处理解码错误
            infoMessage = "显示消息时出错";
        }
    }
%>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>用户登录</title>
    <link rel="stylesheet" href="css/style.css">
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background-color: #f5f5f5;
            margin: 0;
            font-family: Arial, sans-serif;
        }
        .login-container {
            background-color: #ffffff;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            width: 90%;
            max-width: 400px;
        }
        h2 {
            text-align: center;
            color: #333;
            margin-bottom: 20px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #555;
        }
        .form-group input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        .submit-btn {
            width: 100%;
            padding: 12px;
            background-color: #007bff;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            font-weight: bold;
            transition: background-color 0.3s;
        }
        .submit-btn:hover {
            background-color: #0056b3;
        }
        .message {
            margin: 15px 0;
            padding: 10px;
            border-radius: 4px;
            text-align: center;
        }
        .error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .info {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        /* 添加与其他页面一致的错误和信息消息样式 */
        .error-message {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
            margin: 15px 0;
            padding: 10px;
            border-radius: 4px;
            text-align: center;
        }
        .info-message {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
            margin: 15px 0;
            padding: 10px;
            border-radius: 4px;
            text-align: center;
        }
        /* 添加注册链接样式 */
        .register-link {
            margin-top: 15px;
            text-align: center;
            font-size: 0.9em;
        }
        .register-link a {
            color: #007bff;
            text-decoration: none;
        }
        .register-link a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <h2>用户登录</h2>
        
        <% if (errorMessage != null) { %>
        <div class="message error">
            <%= errorMessage %>
        </div>
        <% } %>
        
        <% if (infoMessage != null) { %>
        <div class="message info">
            <%= infoMessage %>
        </div>
        <% } %>
        
       
        
        <form action="login_action.jsp" method="post">
            <div class="form-group">
                <label for="username">用户名</label>
                <input type="text" id="username" name="username" required>
            </div>
            
            <div class="form-group">
                <label for="password">密码</label>
                <input type="password" id="password" name="password" required>
            </div>
            
            <button type="submit" class="submit-btn">登录</button>
        </form>

        <div class="register-link">
            没有账号? <a href="register.jsp">立即注册</a>
            &nbsp;|&nbsp;
            <a href="change_password.jsp">忘记密码?</a>
        </div>

         <div class="message" style="background-color: #e2f0fb; color: #0c5460; border: 1px solid #bee5eb;">
            <i>提示：本系统cookie仅保存3天，过期后请重新输入用户名及密码重新验证登录！</i>
        </div>
        
    </div>
</body>
</html>

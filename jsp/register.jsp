<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" %> 
<%@ page import="java.net.URLDecoder" %>
<% 
    // 设置请求字符编码为UTF-8，防止获取参数时出现乱码
    request.setCharacterEncoding("UTF-8");
    
    // 从URL参数获取错误或成功信息并解码
    String errorMessage = request.getParameter("error");
    if (errorMessage != null) {
        try {
            errorMessage = URLDecoder.decode(errorMessage, "UTF-8");
        } catch (Exception e) {
            // 静默处理解码错误
            errorMessage = "显示错误信息时出错";
        }
    }
    
    String successMessage = request.getParameter("success");
    if (successMessage != null) {
        try {
            successMessage = URLDecoder.decode(successMessage, "UTF-8");
        } catch (Exception e) {
            // 静默处理解码错误
            successMessage = "显示成功信息时出错";
        }
    }
%>
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>用户注册</title>
    <link rel="stylesheet" href="css/style.css" />
    <%-- 重用相同的样式表 --%>
    <style>
      /* 如有需要的微调 */
      .login-container {
        /* 重用登录容器样式 */
        max-width: 450px;
        /* 略宽一些以适应确认密码 */
      }

      .back-link {
        margin-top: 15px;
        font-size: 0.9em;
      }

      .back-link a {
        color: #007bff;
        text-decoration: none;
      }

      .back-link a:hover {
        text-decoration: underline;
      }
    </style>
  </head>

  <body>
    <div class="login-container">
      <%-- 重用登录容器类 --%>
      <h2>用户注册</h2>

      <% if (errorMessage !=null && !errorMessage.isEmpty()) { %>
      <p class="error-message"><%= errorMessage %></p>
      <% } %> 
      <%-- 显示成功信息（如果存在）--%> 
      <% if (successMessage !=null && !successMessage.isEmpty()) { %>
      <p class="info-message"><%= successMessage %></p>
      <% } %> 
      <form action="register_action.jsp" method="post">
        <div class="form-group">
          <label for="username">用户名:</label>
          <input type="text" id="username" name="username" required />
        </div>
        <div class="form-group">
          <label for="password">密码:</label>
          <input type="password" id="password" name="password" required />
        </div>
        <div class="form-group">
          <label for="confirmPassword">确认密码:</label>
          <input
            type="password"
            id="confirmPassword"
            name="confirmPassword"
            required
          />
        </div>
        <button type="submit">注册</button>
      </form>

      <div class="back-link">已有账户? <a href="login.jsp">返回登录</a></div>
    </div>
  </body>
</html>

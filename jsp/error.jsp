<%@ page contentType="text/html;charset=UTF-8" language="java" isErrorPage="true" %>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>页面未找到</title>
    <link rel="stylesheet" href="../css/style.css">
    <style>
        .error-container {
            background-color: #ffffff;
            padding: 30px 40px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
            text-align: center;
            width: 90%;
            max-width: 600px;
            margin: 20px auto;
        }
        
        .error-icon {
            font-size: 60px;
            color: #e74c3c;
            margin-bottom: 20px;
        }
        
        .error-title {
            font-size: 24px;
            color: #333;
            margin-bottom: 15px;
        }
        
        .error-message {
            color: #555;
            margin-bottom: 25px;
        }
        
        .link-home {
            display: inline-block;
            padding: 10px 20px;
            background-color: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            transition: background-color 0.3s;
        }
        
        .link-home:hover {
            background-color: #2980b9;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="error-icon">&#9888;</div>
        <h1 class="error-title">页面未找到</h1>
        <p class="error-message">很抱歉，您请求的页面不存在或已被移动。</p>
        <a href="${pageContext.request.contextPath}/jsp/login.jsp" class="link-home">返回登录页面</a>
    </div>
</body>
</html>

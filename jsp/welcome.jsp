<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.Collections" %>
<%@ page import="java.time.LocalDateTime" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
<%@ page import="java.time.format.DateTimeParseException" %>
<%@ page import="java.time.format.FormatStyle" %>
<%@ page import="java.util.Locale" %>
<%@ page import="java.net.URLEncoder" %>
<%
    // 1. 安全检查：确保用户已登录
    String username = (String) session.getAttribute("username");
    if (username == null || username.trim().isEmpty()) {
        // 未登录，重定向到登录页面并显示错误信息
        response.sendRedirect("login.jsp?error=" + URLEncoder.encode("请先登录。", "UTF-8"));
        return; // 立即停止处理此页面
    }

    // 2. 从会话中获取登录历史记录
    // login_action.jsp 应已将历史记录(List<String>)放入会话中
    @SuppressWarnings("unchecked") // 抑制将Object转换为List<String>的警告
    List<String> loginHistory = (List<String>) session.getAttribute("loginHistory");

    // 如果会话中找不到历史记录，则初始化一个空列表（防御性编程）
    if (loginHistory == null) {
        loginHistory = Collections.emptyList(); // 使用不可变空列表
        System.err.println("[欢迎页] 未在会话中找到用户的登录历史: " + username);
        // 可选择稍后在HTML中向用户显示消息
    }

    // 3. 准备用于显示的日期格式化程序
    // 使用中国区域设置获取适当的日期/时间格式（例如：YYYY年M月D日 下午H:mm:ss）
    DateTimeFormatter displayFormatter = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM).withLocale(Locale.CHINA);
    DateTimeFormatter isoParser = DateTimeFormatter.ISO_LOCAL_DATE_TIME; // 用于解析存储格式的解析器
%>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>欢迎</title>
    <link rel="stylesheet" href="css/style.css"> <%-- 链接到共享样式表 --%>
    <style>
        /* 欢迎页面的特定样式 */
        body {
            display: flex;
            justify-content: center;
            align-items: flex-start; /* Align container to the top */
            padding-top: 50px;
            min-height: calc(100vh - 50px); /* Ensure body takes height */
        }
        .welcome-container {
            background-color: #ffffff;
            padding: 30px 40px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
            text-align: center;
            width: 90%; /* Responsive width */
            max-width: 600px; /* Max width for larger screens */
            margin: 20px;
        }
        .welcome-container h2 {
            color: #333;
            margin-bottom: 20px;
            word-wrap: break-word; /* Ensure long usernames wrap */
        }
        .welcome-container p {
            color: #555;
            margin-bottom: 15px;
        }
        .history-section {
            margin-top: 25px;
        }
        .history-list {
            list-style: none;
            padding: 0;
            margin-top: 10px;
            text-align: left;
            max-height: 300px; /* Limit height and enable scrolling */
            overflow-y: auto;
            border: 1px solid #e0e0e0;
            border-radius: 4px;
            padding: 15px;
            background-color: #f9f9f9;
        }
        .history-list li {
            background-color: #ffffff;
            margin-bottom: 10px;
            padding: 10px 15px;
            border-radius: 4px;
            border-left: 4px solid #007bff;
            font-size: 0.95em;
            color: #444;
            box-shadow: 0 1px 3px rgba(0,0,0,0.05);
        }
        .history-list li.error {
            border-left-color: #dc3545; /* Red border for errors */
            color: #721c24;
            background-color: #f8d7da;
        }
        .no-history {
            color: #6c757d;
            font-style: italic;
        }
        .logout-link {
            display: inline-block;
            margin-top: 30px;
            padding: 10px 20px;
            background-color: #dc3545; /* Red color for logout */
            color: #ffffff;
            text-decoration: none;
            font-weight: bold;
            border-radius: 4px;
            transition: background-color 0.3s ease;
        }
        .logout-link:hover {
            background-color: #c82333; /* Darker red on hover */
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="welcome-container">
        <h2>欢迎您, <%= username %>!</h2>

        <div class="history-section">
            <p>这是您最近的登录记录:</p>

            <%-- 检查登录历史列表是否为空 --%>
            <% if (loginHistory.isEmpty()) { %>
                <p class="no-history"><i>暂无登录记录。</i></p>
            <% } else { %>
                <ul class="history-list">
                    <%-- 遍历登录历史记录字符串 --%>
                    <% for (String loginTimeStr : loginHistory) {
                        String displayString;
                        boolean parseError = false;
                        try {
                            // 解析存储的ISO格式字符串
                            LocalDateTime loginTime = LocalDateTime.parse(loginTimeStr, isoParser);
                            // 使用区域特定的格式化器进行显示
                            displayString = loginTime.format(displayFormatter);
                        } catch (DateTimeParseException e) {
                            // 如果解析失败，显示原始字符串并附带错误说明
                            displayString = loginTimeStr + " (无法解析日期格式)";
                            parseError = true;
                            System.err.println("[欢迎页] 无法解析登录历史日期: " + loginTimeStr + " - " + e.getMessage());
                        } catch (Exception e) {
                            // 捕获处理过程中的任何其他意外错误
                            displayString = loginTimeStr + " (处理时发生错误)";
                            parseError = true;
                            System.err.println("[欢迎页] 处理登录历史日期时发生意外错误: " + loginTimeStr + " - " + e.getMessage());
                        }
                    %>
                        <%-- 输出列表项，如果解析失败则添加'error'类 --%>
                        <li class="<%= parseError ? "error" : "" %>"><%= displayString %></li>
                    <% } // 循环结束 %>
                </ul>
            <% } // else块结束 %>
        </div> <%-- 历史部分结束 --%>

        <%-- 添加修改密码和登出链接 --%>
        <div style="margin-top: 30px;">
            <a href="logout.jsp" class="logout-link">退出登录</a>
        </div>

    </div> <%-- 欢迎容器结束 --%>
</body>
</html>

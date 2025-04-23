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
<%@ page import="javax.servlet.http.Cookie" %>
<%
    // 1. 安全检查：确保用户已登录
    String username = (String) session.getAttribute("username");
    if (username == null || username.trim().isEmpty()) {
        // 未登录，重定向到登录页面并显示错误信息
        response.sendRedirect("login.jsp?error=" + URLEncoder.encode("请先登录。", "UTF-8"));
        return; // 立即停止处理此页面
    }

    // 检查是否存在记住我的Cookie并计算真实过期时间
    Cookie[] cookies = request.getCookies();
    boolean hasRememberMeCookie = false;
    String cookieExpiryInfo = "";
    
    if (cookies != null) {
        for (Cookie cookie : cookies) {
            if ("username".equals(cookie.getName())) {
                hasRememberMeCookie = true;
                
                // 从session中获取Cookie设置时间（如果存在）
                String cookieSetTimeStr = (String) session.getAttribute("cookie_set_time");
                String cookieMaxAgeStr = (String) session.getAttribute("cookie_max_age");
                
                if (cookieSetTimeStr != null && cookieMaxAgeStr != null) {
                    try {
                        long cookieSetTime = Long.parseLong(cookieSetTimeStr);
                        int originalMaxAge = Integer.parseInt(cookieMaxAgeStr);
                        
                        // 计算当前时间与Cookie设置时间的差值（秒）
                        long elapsedSeconds = (System.currentTimeMillis() - cookieSetTime) / 1000;
                        
                        // 计算剩余时间（秒）
                        long remainingSeconds = originalMaxAge - elapsedSeconds;
                        
                        if (remainingSeconds > 0) {
                            // 计算剩余天数、小时数和分钟数
                            int days = (int)(remainingSeconds / (24 * 60 * 60));
                            int hours = (int)((remainingSeconds % (24 * 60 * 60)) / (60 * 60));
                            int minutes = (int)((remainingSeconds % (60 * 60)) / 60);
                            
                            // 拼接到期信息
                            if (days > 0) {
                                cookieExpiryInfo = "您的自动登录将在 " + days + " 天 " + hours + " 小时 " + minutes + " 分钟后到期";
                            } else if (hours > 0) {
                                cookieExpiryInfo = "您的自动登录将在 " + hours + " 小时 " + minutes + " 分钟后到期";
                            } else {
                                cookieExpiryInfo = "您的自动登录将在 " + minutes + " 分钟后到期";
                            }
                        } else {
                            cookieExpiryInfo = "您的自动登录已过期，请重新登录以启用此功能";
                        }
                    } catch (NumberFormatException e) {
                        cookieExpiryInfo = "自动登录功能已启用（剩余时间未知）";
                    }
                } else {
                    cookieExpiryInfo = "自动登录功能已启用（3天内有效）";
                }
                break;
            }
        }
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
    <link rel="stylesheet" href="../css/style.css">
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
            margin-top: 15px;
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
        .password-link {
            display: inline-block;
            margin-top: 15px;
            margin-right: 10px;
            padding: 10px 20px;
            background-color: #28a745; /* Green color for password change */
            color: #ffffff;
            text-decoration: none;
            font-weight: bold;
            border-radius: 4px;
            transition: background-color 0.3s ease;
        }
        .password-link:hover {
            background-color: #218838; /* Darker green on hover */
            text-decoration: none;
        }
        .action-buttons {
            display: flex;
            justify-content: center;
            gap: 15px;
            margin-top: 30px;
        }
        /* Cookie提示样式 */
        .cookie-info {
            margin: 15px auto;
            padding: 10px 15px;
            background-color: #e2f0fb;
            color: #0c5460;
            border: 1px solid #bee5eb;
            border-radius: 4px;
            font-size: 0.9em;
            max-width: 80%;
            text-align: center;
        }
        /* Cookie说明链接样式 */
        .cookie-explanation-link {
            display: inline-block;
            margin-top: 5px;
            font-size: 0.85em;
            color: #0275d8;
            text-decoration: underline;
            cursor: pointer;
        }
        .cookie-explanation-link:hover {
            color: #014c8c;
        }
        
        /* 公告面板样式 */
        .announcement-panel {
            margin: 20px auto;
            border: 1px solid #d1ecf1;
            border-radius: 8px;
            overflow: hidden;
            background-color: #f8f9fa;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
            max-width: 95%;
        }
        .announcement-header {
            background-color: #d1ecf1;
            color: #0c5460;
            padding: 12px 20px;
            font-weight: bold;
            font-size: 1.1em;
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: pointer;
        }
        .announcement-header:hover {
            background-color: #c3e6ef;
        }
        .announcement-content {
            display: none;
            padding: 20px;
            background-color: #fff;
            border-top: 1px solid #d1ecf1;
        }
        .announcement-section {
            margin-bottom: 20px;
            border-bottom: 1px solid #eee;
            padding-bottom: 15px;
        }
        .announcement-section:last-child {
            border-bottom: none;
            margin-bottom: 0;
        }
        .announcement-panel h2 {
            color: #2c3e50;
            font-size: 1.3em;
            margin-bottom: 15px;
            text-align: left;
        }
        .announcement-panel h3 {
            font-size: 1.1em;
            margin: 12px 0 8px 0;
            color: #444;
            text-align: left;
        }
        .announcement-panel ul {
            padding-left: 25px;
            text-align: left;
        }
        .announcement-panel li {
            margin-bottom: 6px;
            line-height: 1.5;
            text-align: left;
            background-color: transparent;
            border-left: none;
            box-shadow: none;
            padding: 0;
        }
        .announcement-panel p {
            text-align: left;
        }
        .code-block {
            background-color: #f8f9fa;
            border: 1px solid #e1e4e8;
            border-radius: 4px;
            padding: 12px;
            margin: 10px 0;
            font-family: monospace;
            white-space: pre-wrap;
            overflow-x: auto;
            text-align: left;
        }
        .toggle-icon {
            transition: transform 0.3s;
        }
    </style>
</head>
<body>
    <div class="welcome-container">
        <h2>欢迎您, <%= username %>!</h2>

        <% if (hasRememberMeCookie && !cookieExpiryInfo.isEmpty()) { %>
        <div class="cookie-info">
            <i class="far fa-clock"></i> <%= cookieExpiryInfo %>
        </div>
        <!-- 公告形式的Cookie解释 -->
        <div class="announcement-panel" id="cookieAnnouncement">
            <div class="announcement-header" onclick="toggleAnnouncement()">
                <span>Cookie详细说明</span>
                <span class="toggle-icon">▼</span>
            </div>
            <div class="announcement-content" id="announcementContent">
                <div class="announcement-section">
                    <h2>1. 持久化Cookie vs Session</h2>
                    <ul>
                        <li>项目使用的是持久化Cookie，而非session cookie</li>
                        <li>设置了明确的过期时间（3天），存储在用户硬盘上</li>
                        <li>Session仅在浏览器打开期间有效，而这里的Cookie在浏览器关闭后仍然有效</li>
                    </ul>
                </div>
        
                <div class="announcement-section">
                    <h2>2. Cookie的设置方式</h2>
                    <p>当用户登录并勾选"记住我"时：</p>
                    <div class="code-block">Cookie userCookie = new Cookie("username", username);
                        userCookie.setMaxAge(COOKIE_MAX_AGE_SECONDS); // 3天的秒数
                        userCookie.setPath(request.getContextPath() + "/");
                        response.addCookie(userCookie);</div>
                </div>
        
                <div class="announcement-section">
                    <h2>3. 双重验证机制</h2>
                    <ul>
                        <li>Cookie本身有3天的过期时间（浏览器端控制）</li>
                        <li>服务器额外验证最后登录时间是否在3天内（服务器端控制）</li>
                    </ul>
                </div>
        
                <div class="announcement-section">
                    <h2>4. Cookie的获取与验证流程</h2>
                    <h3>获取Cookie过程：</h3>
                    <ul>
                        <li>每次用户访问系统时，login_action.jsp 会检查请求中的所有Cookie</li>
                        <li>通过 request.getCookies() 获取所有Cookie数组</li>
                        <li>遍历数组查找名为"username"的Cookie</li>
                    </ul>
                    <div class="code-block">Cookie[] cookies = request.getCookies();
                        String usernameFromCookie = null;
                        if (cookies != null) {
                        for (Cookie cookie : cookies) {
                        if ("username".equals(cookie.getName()) && cookie.getValue() != null) {
                        usernameFromCookie = cookie.getValue();
                        break;
                        }
                        }
                        }</div>
        
                    <h3>验证过程：</h3>
                    <ul>
                        <li>找到username Cookie后，系统不会直接信任它</li>
                        <li>会调用isLastLoginWithinDays方法验证该用户最后登录时间是否在有效期内</li>
                        <li>系统会在WEB-INF/users.xml中查找并验证用户的最后登录时间</li>
                        <li>只有当两重验证（Cookie未过期 + 最后登录时间在3天内）都通过时，才允许自动登录</li>
                    </ul>
                </div>
        
                <div class="announcement-section">
                    <h2>5. Cookie过期与更新机制</h2>
                    <ul>
                        <li><strong>自然过期：</strong>Cookie到达setMaxAge设定的时间后自动失效</li>
                        <li><strong>手动过期：</strong>用户点击"退出登录"时，系统会主动使Cookie过期</li>
                        <li><strong>更新机制：</strong>每次通过Cookie成功自动登录后，系统会更新users.xml中的最后登录时间记录，但不会重置Cookie本身的过期时间</li>
                        <li>用户修改密码后，Cookie会被强制过期，确保安全性</li>
                    </ul>
                </div>
        
                <div class="announcement-section">
                    <h2>6. 安全措施</h2>
                    <ul>
                        <li>密码不存储在Cookie中，只存储用户名</li>
                        <li>每次通过Cookie自动登录时，都会更新最后登录时间</li>
                        <li>修改密码后自动清除Cookie，强制重新登录</li>
                        <li>只有当用户明确勾选"记住我"选项时才会设置Cookie</li>
                    </ul>
                </div>
            </div>
        </div>
        <% } %>

       

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
        <div class="action-buttons">
            <a href="change_password.jsp" class="password-link">修改密码</a>
            <a href="logout.jsp" class="logout-link">退出登录</a>
        </div>

    </div> <%-- 欢迎容器结束 --%>
    
    <!-- 添加JavaScript代码 -->
    <script>
        // 切换公告面板显示/隐藏
        function toggleAnnouncement() {
            var content = document.getElementById('announcementContent');
            var icon = document.querySelector('.toggle-icon');
            
            if (content.style.display === 'block') {
                content.style.display = 'none';
                icon.style.transform = 'rotate(0deg)';
            } else {
                content.style.display = 'block';
                icon.style.transform = 'rotate(180deg)';
            }
        }
    </script>
</body>
</html>

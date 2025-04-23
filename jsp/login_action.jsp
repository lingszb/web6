<%@ page contentType="text/html;charset=UTF-8" language="java" trimDirectiveWhitespaces="true" %>
<%@ page import="java.io.*, java.nio.file.*, java.time.*, java.time.format.*, java.time.temporal.*, java.util.*, java.security.*, javax.xml.parsers.*, javax.xml.transform.*, javax.xml.transform.dom.*, javax.xml.transform.stream.*, org.w3c.dom.*, org.xml.sax.*, java.net.URLEncoder" %>
<%! // --- 声明区块：辅助方法和常量 ---

    // --- 常量 ---
    private static final String XML_FILE_PATH_RELATIVE = "/WEB-INF/users.xml";
    private static final DateTimeFormatter DATE_TIME_FORMATTER = DateTimeFormatter.ISO_LOCAL_DATE_TIME;
    private static final Object fileLock = new Object(); // 文件访问同步锁

    // --- XML文件处理 ---

    /** 获取用户XML文件的绝对路径 */
    private String getXmlFilePath(HttpServletRequest request) {
        return request.getServletContext().getRealPath(XML_FILE_PATH_RELATIVE);
    }

    /** 从指定路径加载XML文档，如果不存在则创建 */
    private Document loadDocument(String xmlPath) throws ParserConfigurationException, SAXException, IOException {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        // 安全处理设置
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
        factory.setExpandEntityReferences(false);
        DocumentBuilder builder = factory.newDocumentBuilder();
        File xmlFile = new File(xmlPath);

        if (!xmlFile.exists()) { // 如果未找到文件则创建初始XML
            Document doc = builder.newDocument();
            Element rootElement = doc.createElement("users");
            doc.appendChild(rootElement);
            try {
                saveDocument(doc, xmlPath); // 保存新创建的结构
            } catch (TransformerException e) {
                throw new IOException("创建初始XML文件失败", e);
            }
            return doc;
        }

        // 加载已存在的XML
        try (InputStream is = Files.newInputStream(Paths.get(xmlPath))) {
            return builder.parse(is);
        }
    }

    /** 将XML文档保存到指定路径 */
    private void saveDocument(Document doc, String xmlPath) throws TransformerException, IOException {
        TransformerFactory transformerFactory = TransformerFactory.newInstance();
        // 安全处理设置
        transformerFactory.setAttribute(javax.xml.XMLConstants.ACCESS_EXTERNAL_DTD, "");
        transformerFactory.setAttribute(javax.xml.XMLConstants.ACCESS_EXTERNAL_STYLESHEET, "");
        Transformer transformer = transformerFactory.newTransformer();
        transformer.setOutputProperty(OutputKeys.INDENT, "yes");
        transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "2");
        transformer.setOutputProperty(OutputKeys.ENCODING, "UTF-8");

        DOMSource source = new DOMSource(doc);
        File file = new File(xmlPath);
        File parentDir = file.getParentFile();
        if (parentDir != null && !parentDir.exists()) {
            parentDir.mkdirs(); // 确保父目录存在
        }

        try (OutputStream os = Files.newOutputStream(Paths.get(xmlPath))) {
            StreamResult result = new StreamResult(os);
            transformer.transform(source, result);
        }
    }

    // --- XML节点操作 ---

    /** 通过用户名查找用户元素 */
    private Element findUserNode(Document doc, String username) {
        if (username == null || username.trim().isEmpty()) return null;
        NodeList userNodes = doc.getElementsByTagName("user");
        for (int i = 0; i < userNodes.getLength(); i++) {
            Node userNode = userNodes.item(i);
            if (userNode.getNodeType() == Node.ELEMENT_NODE) {
                Element userElement = (Element) userNode;
                String currentUsername = getElementTextContent(userElement, "username");
                if (username.equals(currentUsername)) {
                    return userElement;
                }
            }
        }
        return null; // 未找到用户
    }

    /** 获取特定子元素的文本内容 */
    private String getElementTextContent(Element parentElement, String tagName) {
        NodeList nodes = parentElement.getElementsByTagName(tagName);
        return (nodes.getLength() > 0 && nodes.item(0) != null) ? nodes.item(0).getTextContent() : null;
    }

    /** 设置特定子元素的文本内容，如果需要则创建元素 */
    private void setElementTextContent(Document doc, Element parentElement, String tagName, String textContent) {
        NodeList nodes = parentElement.getElementsByTagName(tagName);
        Element element;
        if (nodes.getLength() > 0) {
            element = (Element) nodes.item(0);
        } else {
            element = doc.createElement(tagName);
            parentElement.appendChild(element);
        }
        element.setTextContent(textContent != null ? textContent : ""); // 确保内容非空
    }

    // --- 密码哈希和验证 ---

    /** 使用SHA-256哈希密码 */
    private String hashPassword(String password) {
        if (password == null || password.isEmpty()) return null;
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] encodedhash = digest.digest(password.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder(2 * encodedhash.length);
            for (byte b : encodedhash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            // 记录错误 - SHA-256在标准Java环境中应该始终可用
            System.err.println("致命错误: SHA-256算法不可用! " + e.getMessage());
            throw new RuntimeException("SHA-256算法不可用", e);
        }
    }

    /** 验证输入密码与存储的SHA-256哈希值 */
    private boolean verifyPassword(String inputPassword, String storedHash) {
        if (inputPassword == null || storedHash == null || storedHash.isEmpty()) return false;
        String inputHash = hashPassword(inputPassword);
        return storedHash.equals(inputHash);
    }

    // --- 用户认证和信息 ---

    /** 根据XML文件验证用户凭据 */
    private boolean verifyUserXml(HttpServletRequest request, String username, String password) {
        if (username == null || username.trim().isEmpty() || password == null) {
            return false; // 基本验证
        }
        synchronized (fileLock) {
            try {
                String xmlPath = getXmlFilePath(request);
                Document doc = loadDocument(xmlPath);
                Element userElement = findUserNode(doc, username);
                if (userElement != null) {
                    String storedHash = getElementTextContent(userElement, "passwordHash");
                    return verifyPassword(password, storedHash);
                }
            } catch (Exception e) {
                System.err.println("验证用户 '" + username + "' 时出错: " + e.getMessage());
                e.printStackTrace(); // 记录详细错误
            }
            return false; // 用户未找到或发生错误
        }
    }

    /** 检查用户最后登录是否在指定天数内 */
    private boolean isLastLoginWithinDays(HttpServletRequest request, String username, int days) {
         if (username == null || username.trim().isEmpty() || days < 0) return false;
         synchronized (fileLock) {
            try {
                String xmlPath = getXmlFilePath(request);
                Document doc = loadDocument(xmlPath);
                Element userElement = findUserNode(doc, username);
                if (userElement != null) {
                    String lastLoginStr = getElementTextContent(userElement, "lastLogin");
                    if (lastLoginStr != null && !lastLoginStr.isEmpty()) {
                        LocalDateTime lastLoginTime = LocalDateTime.parse(lastLoginStr, DATE_TIME_FORMATTER);
                        LocalDateTime cutoffTime = LocalDateTime.now().minusDays(days);
                        // 检查最后登录是否在截止时间之后
                        return lastLoginTime.isAfter(cutoffTime);
                    }
                }
            } catch (DateTimeParseException dtpe) {
                 System.err.println("解析用户 '" + username + "' 的最后登录日期时出错: " + dtpe.getMessage());
            } catch (Exception e) {
                System.err.println("检查用户 '" + username + "' 的最后登录时出错: " + e.getMessage());
                 e.printStackTrace();
            }
            return false; // 未找到有效的最后登录或发生错误
        }
    }

    /** 更新用户的最后登录时间并在XML中添加登录历史记录 */
    private boolean updateUserLoginInfoXml(HttpServletRequest request, String username) {
        if (username == null || username.trim().isEmpty()) return false;
        synchronized (fileLock) {
            try {
                String xmlPath = getXmlFilePath(request);
                Document doc = loadDocument(xmlPath);
                Element userElement = findUserNode(doc, username);
                if (userElement != null) {
                    LocalDateTime now = LocalDateTime.now();
                    String nowStr = now.format(DATE_TIME_FORMATTER);

                    // 更新lastLogin
                    setElementTextContent(doc, userElement, "lastLogin", nowStr);

                    // 更新loginHistory
                    NodeList historyNodes = userElement.getElementsByTagName("loginHistory");
                    Element historyElement;
                    if (historyNodes.getLength() > 0) {
                        historyElement = (Element) historyNodes.item(0);
                    } else {
                        historyElement = doc.createElement("loginHistory");
                        userElement.appendChild(historyElement);
                    }
                    Element loginElement = doc.createElement("login");
                    loginElement.setTextContent(nowStr);
                    historyElement.appendChild(loginElement);

                    saveDocument(doc, xmlPath);
                    return true;
                }
            } catch (Exception e) {
                System.err.println("更新用户 '" + username + "' 的登录信息时出错: " + e.getMessage());
                 e.printStackTrace();
            }
            return false; // 未找到用户或发生错误
        }
    }

    /** 从XML中检索用户的登录历史，降序排序 */
    public List<String> getLoginHistoryXml(HttpServletRequest request, String username) {
        List<String> history = new ArrayList<>();
        if (username == null || username.trim().isEmpty()) return history;
         synchronized (fileLock) {
            try {
                String xmlPath = getXmlFilePath(request);
                Document doc = loadDocument(xmlPath);
                Element userElement = findUserNode(doc, username);
                if (userElement != null) {
                    NodeList historyNodes = userElement.getElementsByTagName("loginHistory");
                    if (historyNodes.getLength() > 0) {
                        Element historyElement = (Element) historyNodes.item(0);
                        NodeList loginNodes = historyElement.getElementsByTagName("login");
                        for (int i = 0; i < loginNodes.getLength(); i++) {
                            if (loginNodes.item(i) != null && loginNodes.item(i).getTextContent() != null) {
                                history.add(loginNodes.item(i).getTextContent());
                            }
                        }
                        // 降序排序（最近的在前）
                        Collections.sort(history, Collections.reverseOrder());
                    }
                }
            } catch (Exception e) {
                System.err.println("获取用户 '" + username + "' 的登录历史时出错: " + e.getMessage());
                 e.printStackTrace();
            }
        }
        return history;
    }

     /** 清除用户名cookie。需要request对象获取上下文路径 */
    private void clearUsernameCookie(HttpServletRequest request, HttpServletResponse response) {
        Cookie userCookie = new Cookie("username", null); // 将值设为null
        userCookie.setMaxAge(0); // 立即过期
        userCookie.setPath(request.getContextPath() + "/"); // 匹配设置时使用的路径
        response.addCookie(userCookie);
    }

    /** 向XML文件添加新用户（用于初始化/测试） */
    public boolean addUserXml(HttpServletRequest request, String username, String password) {
        if (username == null || username.trim().isEmpty() || password == null || password.isEmpty()) {
             System.err.println("尝试添加用户名或密码为空的用户。");
             return false;
        }
        synchronized (fileLock) {
            try {
                String xmlPath = getXmlFilePath(request);
                Document doc = loadDocument(xmlPath);
                if (findUserNode(doc, username) != null) {
                    System.err.println("用户 '" + username + "' 已存在。");
                    return false; // 用户已存在
                }
                Element root = doc.getDocumentElement();
                if (root == null) { // 如果loadDocument正确工作，不应该发生
                     throw new IOException("未找到XML根元素'users'。");
                }
                Element userElement = doc.createElement("user");
                setElementTextContent(doc, userElement, "username", username);
                setElementTextContent(doc, userElement, "passwordHash", hashPassword(password));
                setElementTextContent(doc, userElement, "lastLogin", ""); // 初始为空
                userElement.appendChild(doc.createElement("loginHistory")); // 添加空的历史容器
                root.appendChild(userElement);
                saveDocument(doc, xmlPath);
                System.out.println("[JSP] 用户 '" + username + "' 添加成功。");
                return true;
            } catch (Exception e) {
                 System.err.println("添加用户 '" + username + "' 时出错: " + e.getMessage());
                 e.printStackTrace();
                return false;
            }
        }
    }

%>
<% // --- 脚本块：主请求处理逻辑 ---

    // --- Cookie常量 ---
    final int COOKIE_MAX_AGE_DAYS = 3;
    final int COOKIE_MAX_AGE_SECONDS = COOKIE_MAX_AGE_DAYS * 24 * 60 * 60;
    
    // 设置响应编码为UTF-8，确保中文正确显示
    response.setCharacterEncoding("UTF-8");

    String action = request.getMethod(); // "GET" 或 "POST"
    String redirectUrl = null; // 重定向URL

    // --- 1. 处理GET请求（主要用于基于Cookie的自动登录） ---
    if ("GET".equalsIgnoreCase(action)) {
        Cookie[] cookies = request.getCookies();
        String usernameFromCookie = null;
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if ("username".equals(cookie.getName()) && cookie.getValue() != null && !cookie.getValue().isEmpty()) {
                    usernameFromCookie = cookie.getValue();
                    break;
                }
            }
        }

        if (usernameFromCookie != null) {
            // 找到用户名cookie，检查是否仍有效（基于最后登录时间）
            if (isLastLoginWithinDays(request, usernameFromCookie, COOKIE_MAX_AGE_DAYS)) {
                // Cookie有效，执行自动登录
                if (updateUserLoginInfoXml(request, usernameFromCookie)) { // 更新最后登录时间
                    session.setAttribute("username", usernameFromCookie);
                    // 获取并存储登录历史到会话中
                    List<String> history = getLoginHistoryXml(request, usernameFromCookie);
                    session.setAttribute("loginHistory", history);
                    System.out.println("[JSP] 用户 '" + usernameFromCookie + "' 通过有效cookie自动登录。");
                    redirectUrl = "welcome.jsp";
                } else {
                    // 如果用户存在，这不应该发生，但为防御起见进行处理
                    System.err.println("[JSP] 更新cookie用户 '" + usernameFromCookie + "' 的登录信息失败。清除cookie。");
                    clearUsernameCookie(request, response);
                    redirectUrl = "login.jsp?error=" + URLEncoder.encode("自动登录失败，请重试。", "UTF-8");
                }
            } else {
                // 找到cookie但已过期（基于最后登录时间）
                System.out.println("[JSP] 用户 '" + usernameFromCookie + "' 的cookie已过期或无效。清除cookie。");
                clearUsernameCookie(request, response);
                redirectUrl = "login.jsp?info=" + URLEncoder.encode("登录已过期，请重新输入。", "UTF-8");
            }
        } else {
            // 未找到有效的用户名cookie，或直接通过GET访问无cookie
            // 重定向到登录页面（防止通过GET直接访问login_action.jsp）
             System.out.println("[JSP] 没有有效cookie的GET请求到login_action.jsp。重定向到登录页面。");
             redirectUrl = "login.jsp";
        }
    }

    // --- 2. 处理POST请求（表单提交） ---
    else if ("POST".equalsIgnoreCase(action)) {
        // 设置请求编码为UTF-8，确保接收表单数据正确
        request.setCharacterEncoding("UTF-8");
        
        String username = request.getParameter("username");
        String password = request.getParameter("password");
        boolean rememberMe = "true".equals(request.getParameter("rememberMe")); // 复选框选中值为"true"

        // 基本输入验证
        if (username == null || username.trim().isEmpty() || password == null || password.isEmpty()) {
            System.out.println("[JSP] 尝试使用空用户名或密码登录。");
            redirectUrl = "login.jsp?error=" + URLEncoder.encode("用户名和密码不能为空。", "UTF-8");
        } else {
            // --- 初始化/添加测试用户（如需要，首次运行时取消注释） ---
            // if (findUserNode(loadDocument(getXmlFilePath(request)), "test") == null) {
            //     addUserXml(request, "test", "password");
            // }
            // --- 测试用户初始化结束 ---

            // 根据XML验证凭据
            if (verifyUserXml(request, username, password)) {
                // 登录成功
                System.out.println("[JSP] 用户 '" + username + "' 登录成功。");
                if (updateUserLoginInfoXml(request, username)) { // 更新最后登录时间和历史
                    session.setAttribute("username", username);
                    // 获取并存储登录历史到会话中
                    List<String> history = getLoginHistoryXml(request, username);
                    session.setAttribute("loginHistory", history);

                    // 如果用户选择了"记住我"，设置Cookie
                    if (rememberMe) {  // 修复：布尔基本类型不需要null检查和equals方法
                        Cookie userCookie = new Cookie("username", username);
                        userCookie.setMaxAge(COOKIE_MAX_AGE_SECONDS);
                        
                        // 确保路径正确，这样Cookie对整个应用都有效
                        userCookie.setPath(request.getContextPath().length() > 0 ? request.getContextPath() : "/");
                        
                        response.addCookie(userCookie);
                        
                        // 在会话中保存Cookie设置时间和最大存活时间
                        session.setAttribute("cookie_set_time", String.valueOf(System.currentTimeMillis()));
                        session.setAttribute("cookie_max_age", String.valueOf(COOKIE_MAX_AGE_SECONDS));
                    }

                    redirectUrl = "welcome.jsp"; // 重定向到欢迎页面
                } else {
                    // 如果验证通过，这不应该发生，但为防御起见进行处理
                    System.err.println("[JSP] 验证成功后更新用户 '" + username + "' 的登录信息失败。");
                    redirectUrl = "login.jsp?error=" + URLEncoder.encode("登录时发生内部错误，请稍后重试。", "UTF-8");
                }
            } else {
                // 登录失败
                System.out.println("[JSP] 用户 '" + username + "' 登录失败。");
                redirectUrl = "login.jsp?error=" + URLEncoder.encode("用户名或密码错误。", "UTF-8");
            }
        }
    }

    // --- 3. 执行重定向（如果URL已设置） ---
    if (redirectUrl != null) {
        response.sendRedirect(redirectUrl);
        // 重要提示：sendRedirect之后不应有进一步处理或输出。
        // if/else块内的'return'语句处理特定情况，
        // 但这个最终重定向覆盖了一般流程。
    } else {
        // 当前逻辑下不应发生，但作为回退，重定向到登录页面
        System.err.println("[JSP] login_action.jsp在未设置重定向URL的情况下到达结尾。回退到登录页面。");
        response.sendRedirect("login.jsp?error=" + URLEncoder.encode("无效的操作。", "UTF-8"));
    }

    // --- 重要提示：确保<% ... %>标签外没有空格或内容 ---

%>

<%-- Cookie保存3天的验证机制说明:

1. Cookie设置：
   当用户勾选"记住我"时，在login_action.jsp中设置Cookie:
   
   if (rememberMe) {
       Cookie userCookie = new Cookie("username", username);
       userCookie.setMaxAge(COOKIE_MAX_AGE_SECONDS); // 3天的秒数
       userCookie.setPath(request.getContextPath() + "/");
       response.addCookie(userCookie);
   }

2. 验证机制:
   当用户访问系统时，在login_action.jsp的GET请求处理中:
   a. 从请求中获取所有Cookie
   b. 查找名为"username"的Cookie
   c. 如果找到，从XML文件中验证该用户的最后登录时间是否在3天内:
   
   if (isLastLoginWithinDays(request, usernameFromCookie, COOKIE_MAX_AGE_DAYS))
   
3. 验证时间逻辑:
   isLastLoginWithinDays方法检查用户的最后登录时间是否在指定天数内:
   
   LocalDateTime lastLoginTime = LocalDateTime.parse(lastLoginStr, DATE_TIME_FORMATTER);
   LocalDateTime cutoffTime = LocalDateTime.now().minusDays(days);
   return lastLoginTime.isAfter(cutoffTime);
   
   这确保了即使Cookie尚未过期，如果用户超过3天未登录，系统也不会自动登录。

4. 双重保障机制:
   - Cookie本身设置3天后过期 (浏览器端)
   - 服务器端额外验证最后登录时间是否在3天内 (服务器端)
   
   这种双重验证确保了即使用户修改了本地Cookie的过期时间，系统仍然会通过服务器端验证确保安全。
--%>

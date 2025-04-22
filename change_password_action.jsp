<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" %>
<%@ page import="java.io.*, java.nio.file.*, java.time.*, java.time.format.*, java.util.*, java.security.*, javax.xml.parsers.*, javax.xml.transform.*, javax.xml.transform.dom.*, javax.xml.transform.stream.*, org.w3c.dom.*, org.xml.sax.*, java.net.URLEncoder" %>
<%! // --- 声明块：辅助方法 ---

    // --- 常量 ---
    private static final String XML_FILE_PATH_RELATIVE = "/WEB-INF/users.xml";
    private static final Object fileLock = new Object(); // 文件访问同步锁

    // --- XML文件处理 ---
    
    /** 获取用户XML文件的绝对路径 */
    private String getXmlFilePath(HttpServletRequest request) {
        return request.getServletContext().getRealPath(XML_FILE_PATH_RELATIVE);
    }

    /** 从指定路径加载XML文档 */
    private Document loadDocument(String xmlPath) throws ParserConfigurationException, SAXException, IOException {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        // 安全处理设置
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
        factory.setExpandEntityReferences(false);
        DocumentBuilder builder = factory.newDocumentBuilder();
        File xmlFile = new File(xmlPath);

        if (!xmlFile.exists()) {
            return null; // 文件不存在则返回null
        }
        try (InputStream is = Files.newInputStream(Paths.get(xmlPath))) {
            return builder.parse(is);
        }
    }
    
    /** 将XML文档保存到指定路径 */
    private void saveDocument(Document doc, String xmlPath) throws TransformerException, IOException {
        TransformerFactory transformerFactory = TransformerFactory.newInstance();
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
            parentDir.mkdirs();
        }
        try (OutputStream os = Files.newOutputStream(Paths.get(xmlPath))) {
            StreamResult result = new StreamResult(os);
            transformer.transform(source, result);
        }
    }
    
    // --- 用户操作 ---
    
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
        return null;
    }

    /** 获取特定子元素的文本内容 */
    private String getElementTextContent(Element parentElement, String tagName) {
        NodeList nodes = parentElement.getElementsByTagName(tagName);
        return (nodes.getLength() > 0 && nodes.item(0) != null) ? nodes.item(0).getTextContent() : null;
    }
    
    /** 设置特定子元素的文本内容，如有必要则创建它 */
    private void setElementTextContent(Document doc, Element parentElement, String tagName, String textContent) {
        NodeList nodes = parentElement.getElementsByTagName(tagName);
        Element element;
        if (nodes.getLength() > 0) {
            element = (Element) nodes.item(0);
        } else {
            element = doc.createElement(tagName);
            parentElement.appendChild(element);
        }
        element.setTextContent(textContent != null ? textContent : "");
    }
    
    // --- 密码哈希与验证 ---
    
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
            System.err.println("致命错误: SHA-256算法不可用! " + e.getMessage());
            throw new RuntimeException("SHA-256算法不可用", e);
        }
    }
    
    /** 验证密码是否匹配 */
    private boolean verifyPassword(String inputPassword, String storedHash) {
        if (inputPassword == null || storedHash == null || storedHash.isEmpty()) return false;
        String inputHash = hashPassword(inputPassword);
        return storedHash.equals(inputHash);
    }
    
    /** 更新用户密码 */
    private boolean updateUserPassword(HttpServletRequest request, String username, String oldPassword, String newPassword) {
        if (username == null || username.trim().isEmpty() || 
            oldPassword == null || oldPassword.isEmpty() || 
            newPassword == null || newPassword.isEmpty()) {
            return false;
        }
        
        synchronized (fileLock) {
            try {
                String usersPath = getXmlFilePath(request);
                Document usersDoc = loadDocument(usersPath);
                if (usersDoc == null) return false;
                
                Element userElement = findUserNode(usersDoc, username);
                if (userElement == null) return false;
                
                // 验证原密码
                String storedHash = getElementTextContent(userElement, "passwordHash");
                if (!verifyPassword(oldPassword, storedHash)) {
                    return false; // 原密码不匹配
                }
                
                // 更新密码哈希
                setElementTextContent(usersDoc, userElement, "passwordHash", hashPassword(newPassword));
                
                // 保存更新的文档
                saveDocument(usersDoc, usersPath);
                
                return true;
            } catch (Exception e) {
                System.err.println("[修改密码] 更新用户 '" + username + "' 的密码时出错: " + e.getMessage());
                e.printStackTrace();
                return false;
            }
        }
    }
%>
<% // --- 脚本块：主处理逻辑 ---
    
    // 设置请求和响应编码为UTF-8
    request.setCharacterEncoding("UTF-8");
    response.setCharacterEncoding("UTF-8");
    
    String username = request.getParameter("username");
    String oldPassword = request.getParameter("oldPassword");
    String newPassword = request.getParameter("newPassword");
    String confirmPassword = request.getParameter("confirmPassword");
    
    // 基本验证
    if (username == null || username.trim().isEmpty()) {
        response.sendRedirect("change_password.jsp?error=" + URLEncoder.encode("请输入用户名。", "UTF-8"));
        return;
    }
    
    if (oldPassword == null || oldPassword.isEmpty()) {
        response.sendRedirect("change_password.jsp?error=" + URLEncoder.encode("请输入当前密码。", "UTF-8"));
        return;
    }
    
    if (newPassword == null || newPassword.isEmpty() || confirmPassword == null || confirmPassword.isEmpty()) {
        response.sendRedirect("change_password.jsp?error=" + URLEncoder.encode("请填写所有密码字段。", "UTF-8"));
        return;
    }
    
    if (!newPassword.equals(confirmPassword)) {
        response.sendRedirect("change_password.jsp?error=" + URLEncoder.encode("两次输入的新密码不匹配。", "UTF-8"));
        return;
    }
    
    if (oldPassword.equals(newPassword)) {
        response.sendRedirect("change_password.jsp?error=" + URLEncoder.encode("新密码不能与当前密码相同。", "UTF-8"));
        return;
    }
    
    // 更新用户密码
    boolean passwordUpdated = updateUserPassword(request, username.trim(), oldPassword, newPassword);
    if (!passwordUpdated) {
        response.sendRedirect("change_password.jsp?error=" + URLEncoder.encode("密码修改失败：用户名或当前密码不正确。", "UTF-8"));
        return;
    }
    
    // 如果用户当前已登录且正在修改自己的密码，则清除会话和Cookie
    String loggedInUsername = (String) session.getAttribute("username");
    if (loggedInUsername != null && loggedInUsername.equals(username.trim())) {
        // 清除会话
        session.invalidate();
        
        // 清除Cookie
        Cookie userCookie = new Cookie("username", null);
        userCookie.setMaxAge(0);
        userCookie.setPath(request.getContextPath() + "/");
        response.addCookie(userCookie);
    }
    
    // 重定向到登录页面，显示成功消息
    response.sendRedirect("login.jsp?message=" + URLEncoder.encode("密码已成功修改，请使用新密码登录。", "UTF-8"));
%>

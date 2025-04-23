<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" %>
<%@ page import="java.io.*, java.nio.file.*, java.time.*, java.time.format.*, java.util.*, java.security.*, javax.xml.parsers.*, javax.xml.transform.*, javax.xml.transform.dom.*, javax.xml.transform.stream.*, org.w3c.dom.*, org.xml.sax.*, java.net.URLEncoder" %>
<%! // --- 声明块：复制的辅助方法（理想情况下重构为工具类） ---

    // --- 常量 ---
    private static final String XML_FILE_PATH_RELATIVE = "/WEB-INF/users.xml";
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

        if (!xmlFile.exists()) {
            Document doc = builder.newDocument();
            Element rootElement = doc.createElement("users");
            doc.appendChild(rootElement);
            try {
                saveDocument(doc, xmlPath);
            } catch (TransformerException e) {
                throw new IOException("创建初始XML文件失败", e);
            }
            return doc;
        }
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
            parentDir.mkdirs();
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

    // --- 密码哈希 ---

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

    // --- 用户添加逻辑 ---

    /** 向XML文件添加新用户。成功返回true，否则返回false */
    public boolean addUserXml(HttpServletRequest request, String username, String password) {
        // 基本验证已在脚本中完成，但再次检查非空
        if (username == null || username.trim().isEmpty() || password == null || password.isEmpty()) {
             System.err.println("[注册操作] 尝试添加空用户名或密码的用户。");
             return false;
        }

        synchronized (fileLock) {
            try {
                String xmlPath = getXmlFilePath(request);
                Document doc = loadDocument(xmlPath);

                // 检查用户是否已存在
                if (findUserNode(doc, username) != null) {
                    System.err.println("[注册操作] 注册失败: 用户 '" + username + "' 已存在。");
                    return false; // 表示用户已存在
                }

                Element root = doc.getDocumentElement();
                if (root == null) {
                     throw new IOException("未找到XML根元素'users'。");
                }

                // 创建新用户元素
                Element userElement = doc.createElement("user");
                setElementTextContent(doc, userElement, "username", username);
                setElementTextContent(doc, userElement, "passwordHash", hashPassword(password)); // 哈希密码
                setElementTextContent(doc, userElement, "lastLogin", ""); // 初始化lastLogin
                userElement.appendChild(doc.createElement("loginHistory")); // 添加空历史记录

                root.appendChild(userElement);
                saveDocument(doc, xmlPath);
                System.out.println("[注册操作] 用户 '" + username + "' 注册成功。");
                return true; // 成功
            } catch (Exception e) {
                 System.err.println("[注册操作] 添加用户 '" + username + "' 时出错: " + e.getMessage());
                 e.printStackTrace();
                return false; // 表示由于错误而失败
            }
        }
    }

%>
<% // --- 脚本块：主注册处理逻辑 ---

    // 设置请求编码为UTF-8，确保接收表单数据正确
    request.setCharacterEncoding("UTF-8");
    // 设置响应编码为UTF-8，确保输出不会乱码
    response.setCharacterEncoding("UTF-8");
    
    String username = request.getParameter("username");
    String password = request.getParameter("password");
    String confirmPassword = request.getParameter("confirmPassword");
    String redirectPage = null;
    String message = null;
    boolean error = true; // 初始假设有错误

    // 1. 输入验证
    if (username == null || username.trim().isEmpty() ||
        password == null || password.isEmpty() ||
        confirmPassword == null || confirmPassword.isEmpty()) {
        message = "所有字段均为必填项。";
        redirectPage = "register.jsp";
    } else if (!password.equals(confirmPassword)) {
        message = "两次输入的密码不匹配。";
        redirectPage = "register.jsp";
    } else {
        // 2. 尝试添加用户
        try {
            if (addUserXml(request, username.trim(), password)) {
                // 注册成功
                message = "恭喜您，注册成功！请使用您的新账号和密码登录。";
                redirectPage = "login.jsp"; // 成功后重定向到登录页面
                error = false; // 表示成功
            } else {
                // addUserXml返回false，可能用户已存在或文件错误
                message = "注册失败：用户名 '" + username.trim() + "' 可能已被占用，或发生内部错误。";
                redirectPage = "register.jsp";
            }
        } catch (Exception e) {
            // 捕获addUserXml调用期间的意外错误
            System.err.println("[注册操作] 注册过程中发生意外异常: " + e.getMessage());
            e.printStackTrace();
            message = "注册过程中发生意外错误，请稍后重试。";
            redirectPage = "register.jsp";
        }
    }

    // 3. 带消息重定向
    String paramName = error ? "error" : "success"; // 成功时使用'success'
    response.sendRedirect(redirectPage + "?" + paramName + "=" + URLEncoder.encode(message, "UTF-8"));

%>
<%-- 重要：确保<% ... %>标签外没有空白或内容 --%>

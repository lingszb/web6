<%@ page contentType="text/html;charset=UTF-8" language="java" trimDirectiveWhitespaces="true" %>
<%@ page import="java.io.*, java.nio.file.*, java.time.*, java.time.format.*, java.time.temporal.*, java.util.*, java.security.*, javax.xml.parsers.*, javax.xml.transform.*, javax.xml.transform.dom.*, javax.xml.transform.stream.*, org.w3c.dom.*, org.xml.sax.*, java.net.URLEncoder" %>
<%! // --- Declaration Block: Helper Methods and Constants ---

    // --- Constants ---
    private static final String XML_FILE_PATH_RELATIVE = "/WEB-INF/users.xml";
    private static final DateTimeFormatter DATE_TIME_FORMATTER = DateTimeFormatter.ISO_LOCAL_DATE_TIME;
    private static final Object fileLock = new Object(); // Synchronization lock for file access

    // --- XML File Handling ---

    /** Gets the absolute path to the users XML file. */
    private String getXmlFilePath(HttpServletRequest request) {
        return request.getServletContext().getRealPath(XML_FILE_PATH_RELATIVE);
    }

    /** Loads the XML document from the specified path, creating it if it doesn't exist. */
    private Document loadDocument(String xmlPath) throws ParserConfigurationException, SAXException, IOException {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        // Secure processing settings
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
        factory.setExpandEntityReferences(false);
        DocumentBuilder builder = factory.newDocumentBuilder();
        File xmlFile = new File(xmlPath);

        if (!xmlFile.exists()) { // Create initial XML if not found
            Document doc = builder.newDocument();
            Element rootElement = doc.createElement("users");
            doc.appendChild(rootElement);
            try {
                saveDocument(doc, xmlPath); // Save the newly created structure
            } catch (TransformerException e) {
                throw new IOException("Failed to create initial XML file", e);
            }
            return doc;
        }

        // Load existing XML
        try (InputStream is = Files.newInputStream(Paths.get(xmlPath))) {
            return builder.parse(is);
        }
    }

    /** Saves the XML document to the specified path. */
    private void saveDocument(Document doc, String xmlPath) throws TransformerException, IOException {
        TransformerFactory transformerFactory = TransformerFactory.newInstance();
        // Secure processing settings
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
            parentDir.mkdirs(); // Ensure parent directory exists
        }

        try (OutputStream os = Files.newOutputStream(Paths.get(xmlPath))) {
            StreamResult result = new StreamResult(os);
            transformer.transform(source, result);
        }
    }

    // --- XML Node Manipulation ---

    /** Finds a user element by username. */
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
        return null; // User not found
    }

    /** Gets the text content of a specific child element. */
    private String getElementTextContent(Element parentElement, String tagName) {
        NodeList nodes = parentElement.getElementsByTagName(tagName);
        return (nodes.getLength() > 0 && nodes.item(0) != null) ? nodes.item(0).getTextContent() : null;
    }

    /** Sets the text content of a specific child element, creating it if necessary. */
    private void setElementTextContent(Document doc, Element parentElement, String tagName, String textContent) {
        NodeList nodes = parentElement.getElementsByTagName(tagName);
        Element element;
        if (nodes.getLength() > 0) {
            element = (Element) nodes.item(0);
        } else {
            element = doc.createElement(tagName);
            parentElement.appendChild(element);
        }
        element.setTextContent(textContent != null ? textContent : ""); // Ensure non-null content
    }

    // --- Password Hashing and Verification ---

    /** Hashes a password using SHA-256. */
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
            // Log error - SHA-256 should always be available in standard Java environments
            System.err.println("FATAL: SHA-256 algorithm not available! " + e.getMessage());
            throw new RuntimeException("SHA-256 algorithm not available", e);
        }
    }

    /** Verifies an input password against a stored SHA-256 hash. */
    private boolean verifyPassword(String inputPassword, String storedHash) {
        if (inputPassword == null || storedHash == null || storedHash.isEmpty()) return false;
        String inputHash = hashPassword(inputPassword);
        return storedHash.equals(inputHash);
    }

    // --- User Authentication and Information ---

    /** Verifies user credentials against the XML file. */
    private boolean verifyUserXml(HttpServletRequest request, String username, String password) {
        if (username == null || username.trim().isEmpty() || password == null) {
            return false; // Basic validation
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
                System.err.println("Error verifying user '" + username + "': " + e.getMessage());
                e.printStackTrace(); // Log detailed error
            }
            return false; // User not found or error occurred
        }
    }

    /** Checks if the user's last login was within the specified number of days. */
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
                        // Check if last login is *after* the cutoff time
                        return lastLoginTime.isAfter(cutoffTime);
                    }
                }
            } catch (DateTimeParseException dtpe) {
                 System.err.println("Error parsing last login date for user '" + username + "': " + dtpe.getMessage());
            } catch (Exception e) {
                System.err.println("Error checking last login for user '" + username + "': " + e.getMessage());
                 e.printStackTrace();
            }
            return false; // No valid last login found or error occurred
        }
    }

    /** Updates the user's last login time and adds an entry to the login history in the XML. */
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

                    // Update lastLogin
                    setElementTextContent(doc, userElement, "lastLogin", nowStr);

                    // Update loginHistory
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
                System.err.println("Error updating login info for user '" + username + "': " + e.getMessage());
                 e.printStackTrace();
            }
            return false; // User not found or error occurred
        }
    }

    /** Retrieves the login history for a user from the XML, sorted descending. */
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
                        // Sort descending (most recent first)
                        Collections.sort(history, Collections.reverseOrder());
                    }
                }
            } catch (Exception e) {
                System.err.println("Error getting login history for user '" + username + "': " + e.getMessage());
                 e.printStackTrace();
            }
        }
        return history;
    }

     /** Clears the username cookie. Requires request object for context path. */
    private void clearUsernameCookie(HttpServletRequest request, HttpServletResponse response) {
        Cookie userCookie = new Cookie("username", null); // Set value to null
        userCookie.setMaxAge(0); // Expire immediately
        userCookie.setPath(request.getContextPath() + "/"); // Match the path used when setting
        response.addCookie(userCookie);
    }

    /** Adds a new user to the XML file (useful for initialization/testing). */
    public boolean addUserXml(HttpServletRequest request, String username, String password) {
        if (username == null || username.trim().isEmpty() || password == null || password.isEmpty()) {
             System.err.println("Attempted to add user with empty username or password.");
             return false;
        }
        synchronized (fileLock) {
            try {
                String xmlPath = getXmlFilePath(request);
                Document doc = loadDocument(xmlPath);
                if (findUserNode(doc, username) != null) {
                    System.err.println("User '" + username + "' already exists.");
                    return false; // User already exists
                }
                Element root = doc.getDocumentElement();
                if (root == null) { // Should not happen if loadDocument works correctly
                     throw new IOException("XML root element 'users' not found.");
                }
                Element userElement = doc.createElement("user");
                setElementTextContent(doc, userElement, "username", username);
                setElementTextContent(doc, userElement, "passwordHash", hashPassword(password));
                setElementTextContent(doc, userElement, "lastLogin", ""); // Initially empty
                userElement.appendChild(doc.createElement("loginHistory")); // Add empty history container
                root.appendChild(userElement);
                saveDocument(doc, xmlPath);
                System.out.println("[JSP] User '" + username + "' added successfully.");
                return true;
            } catch (Exception e) {
                 System.err.println("Error adding user '" + username + "': " + e.getMessage());
                 e.printStackTrace();
                return false;
            }
        }
    }

%>
<% // --- Scriptlet Block: Main Request Processing Logic ---

    // --- Constants for Cookie ---
    final int COOKIE_MAX_AGE_DAYS = 3;
    final int COOKIE_MAX_AGE_SECONDS = COOKIE_MAX_AGE_DAYS * 24 * 60 * 60;
    
    // 设置响应编码为UTF-8，确保中文正确显示
    response.setCharacterEncoding("UTF-8");

    String action = request.getMethod(); // "GET" or "POST"
    String redirectUrl = null; // URL to redirect to

    // --- 1. Handle GET Requests (Primarily for Cookie-based Auto-Login) ---
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
            // Found username cookie, check if it's still valid (based on last login time)
            if (isLastLoginWithinDays(request, usernameFromCookie, COOKIE_MAX_AGE_DAYS)) {
                // Cookie is valid, perform auto-login
                if (updateUserLoginInfoXml(request, usernameFromCookie)) { // Update last login time
                    session.setAttribute("username", usernameFromCookie);
                    // Fetch and store login history in session
                    List<String> history = getLoginHistoryXml(request, usernameFromCookie);
                    session.setAttribute("loginHistory", history);
                    System.out.println("[JSP] User '" + usernameFromCookie + "' auto-logged in via valid cookie.");
                    redirectUrl = "welcome.jsp";
                } else {
                    // Should not happen if user exists, but handle defensively
                    System.err.println("[JSP] Failed to update login info for cookie user '" + usernameFromCookie + "'. Clearing cookie.");
                    clearUsernameCookie(request, response);
                    redirectUrl = "login.jsp?error=" + URLEncoder.encode("自动登录失败，请重试。", "UTF-8");
                }
            } else {
                // Cookie found but expired (based on last login time)
                System.out.println("[JSP] Cookie for user '" + usernameFromCookie + "' expired or invalid. Clearing cookie.");
                clearUsernameCookie(request, response);
                redirectUrl = "login.jsp?info=" + URLEncoder.encode("登录已过期，请重新输入。", "UTF-8");
            }
        } else {
            // No valid username cookie found, or direct GET access without cookie
            // Redirect to login page (prevents direct access to login_action.jsp via GET)
             System.out.println("[JSP] GET request to login_action.jsp without valid cookie. Redirecting to login page.");
             redirectUrl = "login.jsp";
        }
    }

    // --- 2. Handle POST Requests (Form Submission) ---
    else if ("POST".equalsIgnoreCase(action)) {
        // 设置请求编码为UTF-8，确保接收表单数据正确
        request.setCharacterEncoding("UTF-8");
        
        String username = request.getParameter("username");
        String password = request.getParameter("password");
        boolean rememberMe = "true".equals(request.getParameter("rememberMe")); // Checkbox value is "true" if checked

        // Basic Input Validation
        if (username == null || username.trim().isEmpty() || password == null || password.isEmpty()) {
            System.out.println("[JSP] Login attempt with empty username or password.");
            redirectUrl = "login.jsp?error=" + URLEncoder.encode("用户名和密码不能为空。", "UTF-8");
        } else {
            // --- Initialize/Add Test User (Uncomment for first run if needed) ---
            // if (findUserNode(loadDocument(getXmlFilePath(request)), "test") == null) {
            //     addUserXml(request, "test", "password");
            // }
            // --- End Test User Init ---

            // Verify credentials against XML
            if (verifyUserXml(request, username, password)) {
                // Login Successful
                System.out.println("[JSP] User '" + username + "' login successful.");
                if (updateUserLoginInfoXml(request, username)) { // Update last login time and history
                    session.setAttribute("username", username);
                    // Fetch and store login history in session
                    List<String> history = getLoginHistoryXml(request, username);
                    session.setAttribute("loginHistory", history);

                    // Handle "Remember Me" cookie
                    if (rememberMe) {
                        Cookie userCookie = new Cookie("username", username);
                        userCookie.setMaxAge(COOKIE_MAX_AGE_SECONDS);
                        userCookie.setPath(request.getContextPath() + "/"); // Set path for context root
                        response.addCookie(userCookie);
                        System.out.println("[JSP] 'Remember Me' cookie set for user '" + username + "'.");
                    } else {
                        clearUsernameCookie(request, response); // Clear any existing cookie if not remembered
                        System.out.println("[JSP] 'Remember Me' not checked for user '" + username + "'. Cookie cleared (if existed).");
                    }
                    redirectUrl = "welcome.jsp"; // Redirect to welcome page
                } else {
                     // Should not happen if verification passed, but handle defensively
                    System.err.println("[JSP] Failed to update login info for user '" + username + "' after successful verification.");
                    redirectUrl = "login.jsp?error=" + URLEncoder.encode("登录时发生内部错误，请稍后重试。", "UTF-8");
                }
            } else {
                // Login Failed
                System.out.println("[JSP] Login failed for user '" + username + "'.");
                redirectUrl = "login.jsp?error=" + URLEncoder.encode("用户名或密码错误。", "UTF-8");
            }
        }
    }

    // --- 3. Perform Redirect (if URL is set) ---
    if (redirectUrl != null) {
        response.sendRedirect(redirectUrl);
        // IMPORTANT: No further processing or output should happen after sendRedirect.
        // The 'return' statements within the if/else blocks handle this for specific cases,
        // but having this final redirect covers the general flow.
    } else {
        // Should not happen with current logic, but as a fallback, redirect to login
        System.err.println("[JSP] login_action.jsp reached end without setting a redirect URL. Fallback to login page.");
        response.sendRedirect("login.jsp?error=" + URLEncoder.encode("无效的操作。", "UTF-8"));
    }

    // --- IMPORTANT: Ensure no whitespace or content outside <% ... %> tags ---

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

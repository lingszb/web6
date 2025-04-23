<%@ page contentType="text/html;charset=UTF-8" language="java" pageEncoding="UTF-8" %>
<%@ page import="java.io.*" %>
<%@ page import="java.util.*" %>
<%@ page import="javax.xml.parsers.*" %>
<%@ page import="org.w3c.dom.*" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="java.text.ParseException" %>

<%
    // 1. 检查会话中是否已有用户登录信息
    String sessionUsername = (String) session.getAttribute("username");
    if (sessionUsername != null && !sessionUsername.isEmpty()) {
        // 用户已登录，直接重定向到欢迎页面
        response.sendRedirect("jsp/welcome.jsp");
        return;
    }
    
    // 2. 检查Cookie中是否有username
    Cookie[] cookies = request.getCookies();
    String cookieUsername = null;
    
    if (cookies != null) {
        for (Cookie cookie : cookies) {
            if ("username".equals(cookie.getName())) {
                cookieUsername = cookie.getValue();
                break;
            }
        }
    }
    
    // 3. 如果找到username Cookie，验证它的有效性
    System.out.println("[DEBUG] 找到Cookie username: " + cookieUsername);
    if (cookieUsername != null && !cookieUsername.isEmpty()) {
        try {
            // 用户文件路径
            String usersFilePath = application.getRealPath("/WEB-INF/users.xml");
            File usersFile = new File(usersFilePath);
            
            if (usersFile.exists()) {
                DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
                DocumentBuilder docBuilder = docFactory.newDocumentBuilder(); // 修复：正确声明DocumentBuilder变量
                Document doc = docBuilder.parse(usersFile);
                doc.getDocumentElement().normalize();
                
                NodeList userNodes = doc.getElementsByTagName("user");
                boolean isValidUser = false;
                
                // 当前时间
                SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS");
                Date currentDate = new Date();
                String currentTime = dateFormat.format(currentDate);
                
                // 遍历所有用户节点寻找匹配的用户名
                for (int i = 0; i < userNodes.getLength(); i++) {
                    Node userNode = userNodes.item(i);
                    
                    if (userNode.getNodeType() == Node.ELEMENT_NODE) {
                        Element userElement = (Element) userNode;
                        
                        String xmlUsername = userElement.getElementsByTagName("username").item(0).getTextContent();
                        
                        // 如果找到匹配的用户名，检查最后登录时间
                        if (cookieUsername.equals(xmlUsername)) {
                            isValidUser = true;
                            
                            NodeList lastLoginNodes = userElement.getElementsByTagName("lastLogin");
                            
                            // 如果有最后登录时间，计算是否在3天内
                            if (lastLoginNodes.getLength() > 0) {
                                String lastLoginStr = lastLoginNodes.item(0).getTextContent();
                                
                                try {
                                    System.out.println("[DEBUG] 最后登录时间: " + lastLoginStr);
                                    // 移除可能的毫秒小数点后的多余位数
                                    if (lastLoginStr.contains(".")) {
                                        lastLoginStr = lastLoginStr.replaceAll("(\\.\\d{3})\\d*", "$1");
                                    }
                                    Date lastLoginDate = dateFormat.parse(lastLoginStr);
                                    long diffMillis = currentDate.getTime() - lastLoginDate.getTime();
                                    long diffDays = diffMillis / (24 * 60 * 60 * 1000);
                                    System.out.println("[DEBUG] 距离上次登录天数: " + diffDays);
                                    
                                    // 更新最后登录时间
                                    lastLoginNodes.item(0).setTextContent(currentTime);
                                    
                                    // 如果上次登录在3天内，自动登录
                                    if (diffDays < 3) {
                                        // 保存更新后的XML
                                        javax.xml.transform.TransformerFactory transformerFactory = 
                                            javax.xml.transform.TransformerFactory.newInstance();
                                        javax.xml.transform.Transformer transformer = transformerFactory.newTransformer();
                                        transformer.setOutputProperty(javax.xml.transform.OutputKeys.INDENT, "yes");
                                        javax.xml.transform.dom.DOMSource source = 
                                            new javax.xml.transform.dom.DOMSource(doc);
                                        javax.xml.transform.stream.StreamResult result = 
                                            new javax.xml.transform.stream.StreamResult(usersFile);
                                        transformer.transform(source, result);
                                        
                                        // 设置会话中的用户名
                                        session.setAttribute("username", cookieUsername);
                                        
                                        // 在会话中保存Cookie原始设置时间，用于欢迎页面显示
                                        final int COOKIE_MAX_AGE_SECONDS = 3 * 24 * 60 * 60; // 3天的秒数
                                        
                                        // 计算Cookie首次设置时间（现在减去已经过去的时间）
                                        long cookieSetTime = System.currentTimeMillis() - diffMillis;
                                        
                                        session.setAttribute("cookie_set_time", String.valueOf(cookieSetTime));
                                        session.setAttribute("cookie_max_age", String.valueOf(COOKIE_MAX_AGE_SECONDS));
                                        
                                        // 获取或创建登录历史记录
                                        List<String> loginHistory = new ArrayList<>();
                                        
                                        // 检查XML中是否已有登录历史记录
                                        NodeList loginHistoryNodes = userElement.getElementsByTagName("loginHistory");
                                        if (loginHistoryNodes.getLength() > 0) {
                                            // 读取已有的登录历史
                                            Element loginHistoryElement = (Element) loginHistoryNodes.item(0);
                                            NodeList entries = loginHistoryElement.getElementsByTagName("entry");
                                            for (int j = 0; j < entries.getLength(); j++) {
                                                loginHistory.add(entries.item(j).getTextContent());
                                            }
                                        } else {
                                            // 如果没有登录历史节点，创建一个
                                            Element loginHistoryElement = doc.createElement("loginHistory");
                                            userElement.appendChild(loginHistoryElement);
                                        }
                                        
                                        // 添加当前登录时间（ISO格式）
                                        SimpleDateFormat isoFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS");
                                        String currentLoginTime = isoFormat.format(currentDate);
                                        loginHistory.add(currentLoginTime);
                                        
                                        // 更新XML中的登录历史
                                        Element loginHistoryElement = null;
                                        NodeList historyNodeList = userElement.getElementsByTagName("loginHistory");
                                        if (historyNodeList.getLength() > 0) {
                                            loginHistoryElement = (Element) historyNodeList.item(0);
                                            // 清除旧记录
                                            while (loginHistoryElement.hasChildNodes()) {
                                                loginHistoryElement.removeChild(loginHistoryElement.getFirstChild());
                                            }
                                        } else {
                                            loginHistoryElement = doc.createElement("loginHistory");
                                            userElement.appendChild(loginHistoryElement);
                                        }
                                        
                                        // 添加历史记录到XML
                                        for (String entry : loginHistory) {
                                            Element entryElement = doc.createElement("entry");
                                            entryElement.setTextContent(entry);
                                            loginHistoryElement.appendChild(entryElement);
                                        }
                                        
                                        session.setAttribute("loginHistory", loginHistory);
                                        
                                        // 重定向到欢迎页面
                                        response.sendRedirect("jsp/welcome.jsp");
                                        return;
                                    }
                                } catch (ParseException e) {
                                    // 如果解析日期出错，不进行自动登录
                                    System.err.println("解析登录日期失败: " + e.getMessage());
                                }
                            } else {
                                // 如果没有最后登录时间，创建一个
                                Element lastLoginElement = doc.createElement("lastLogin");
                                lastLoginElement.setTextContent(currentTime);
                                userElement.appendChild(lastLoginElement);
                                
                                // 保存更新后的XML
                                javax.xml.transform.TransformerFactory transformerFactory = 
                                    javax.xml.transform.TransformerFactory.newInstance();
                                javax.xml.transform.Transformer transformer = transformerFactory.newTransformer();
                                transformer.setOutputProperty(javax.xml.transform.OutputKeys.INDENT, "yes");
                                javax.xml.transform.dom.DOMSource source = 
                                    new javax.xml.transform.dom.DOMSource(doc);
                                javax.xml.transform.stream.StreamResult result = 
                                    new javax.xml.transform.stream.StreamResult(usersFile);
                                transformer.transform(source, result);
                            }
                            
                            break;
                        }
                    }
                }
                
                // 如果用户名有效但登录过期或失败
                if (isValidUser) {
                    // 清除Cookie
                    Cookie clearCookie = new Cookie("username", "");
                    clearCookie.setMaxAge(0);
                    clearCookie.setPath(request.getContextPath() + "/");
                    response.addCookie(clearCookie);
                }
            }
        } catch (Exception e) {
            System.err.println("自动登录处理失败: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    // 4. 如果没有找到Cookie或Cookie无效，重定向到登录页面
    response.sendRedirect("jsp/login.jsp");
%>

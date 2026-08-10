<%@ page import="java.sql.*" %>
<%@ page import="javax.servlet.http.HttpSession" %>
<%@ page import="org.mindrot.jbcrypt.BCrypt" %>

<%
    // ============================================================
    // LOGIN PAGE
    // ============================================================

    // If already logged in, redirect to students page
    String loggedInUser = (String) session.getAttribute("username");

    if (loggedInUser != null) {
        response.sendRedirect("viewstudents.jsp");
        return;
    }

    String loginError = null;
    String action = request.getParameter("action");

    if ("login".equals(action)) {

        String username = request.getParameter("username");
        String password = request.getParameter("password");

        // --------------------------------------------------------
        // Validate input
        // --------------------------------------------------------

        if (username == null || username.trim().isEmpty()
                || password == null || password.isEmpty()) {

            loginError = "Username and password are required.";

        } else {

            username = username.trim().toLowerCase();

            // ----------------------------------------------------
            // Rate limiting / account lockout
            // ----------------------------------------------------

            String lockKey = "lock_" + username;
            String countKey = "fail_" + username;
            String timeKey = "failtime_" + username;

            Long lockUntil =
                (Long) application.getAttribute(lockKey);

            if (lockUntil != null
                    && System.currentTimeMillis() < lockUntil) {

                loginError =
                    "Account temporarily locked. Try again in 15 minutes.";

                auditLog(
                    application,
                    "anon",
                    request.getRemoteAddr(),
                    "LOGIN_BLOCKED",
                    "username=" + username
                );

            } else {

                // ------------------------------------------------
                // Database connection
                // ------------------------------------------------

                String url =
                    "jdbc:mysql://localhost:3306/universitydb"
                    + "?useSSL=false"
                    + "&allowPublicKeyRetrieval=true"
                    + "&serverTimezone=UTC";

                Connection conn = null;
                PreparedStatement ps = null;
                ResultSet rs = null;

                try {

                    Class.forName("com.mysql.cj.jdbc.Driver");

                    conn = DriverManager.getConnection(
                        url,
                        "root",
                        "root123"
                    );

                    // ------------------------------------------------
                    // Parameterized query
                    // ------------------------------------------------

                    ps = conn.prepareStatement(
                        "SELECT pw_hash, role " +
                        "FROM users " +
                        "WHERE username = ?"
                    );

                    ps.setString(1, username);

                    rs = ps.executeQuery();

                    boolean matched = false;
                    String role = null;

                    // ------------------------------------------------
                    // Check user
                    // ------------------------------------------------

                    if (rs.next()) {

                        String storedHash =
                            rs.getString("pw_hash");

                        role =
                            rs.getString("role");

                        // ------------------------------------------------
                        // BCrypt password verification
                        // ------------------------------------------------

                        try {

                            matched =
                                BCrypt.checkpw(
                                    password,
                                    storedHash
                                );

                        } catch (Exception bcryptException) {

                            // Do not expose BCrypt/database details
                            matched = false;
                        }
                    }

                    // ------------------------------------------------
                    // Successful login
                    // ------------------------------------------------

                    if (matched) {

                        // Prevent session fixation
                        session.invalidate();

                        HttpSession newSession =
                            request.getSession(true);

                        newSession.setAttribute(
                            "username",
                            username
                        );

                        newSession.setAttribute(
                            "role",
                            role
                        );

                        newSession.setAttribute(
                            "loginTime",
                            System.currentTimeMillis()
                        );

                        // 15 minute session timeout
                        newSession.setMaxInactiveInterval(
                            15 * 60
                        );

                        // Reset failed-login counters
                        application.removeAttribute(countKey);
                        application.removeAttribute(timeKey);
                        application.removeAttribute(lockKey);

                        // Audit successful login
                        auditLog(
                            application,
                            username,
                            request.getRemoteAddr(),
                            "LOGIN_OK",
                            ""
                        );

                        response.sendRedirect(
                            "viewstudents.jsp"
                        );

                        return;

                    } else {

                        // ------------------------------------------------
                        // Failed login
                        // ------------------------------------------------

                        loginError =
                            "Invalid credentials.";

                        Integer failCount =
                            (Integer) application.getAttribute(
                                countKey
                            );

                        if (failCount == null) {
                            failCount = 0;
                        }

                        failCount++;

                        application.setAttribute(
                            countKey,
                            failCount
                        );

                        application.setAttribute(
                            timeKey,
                            System.currentTimeMillis()
                        );

                        // Lock after 5 failed attempts
                        if (failCount >= 5) {

                            long lockUntilTime =
                                System.currentTimeMillis()
                                + (15 * 60 * 1000L);

                            application.setAttribute(
                                lockKey,
                                lockUntilTime
                            );

                            application.setAttribute(
                                countKey,
                                0
                            );

                            auditLog(
                                application,
                                "system",
                                request.getRemoteAddr(),
                                "ACCOUNT_LOCKED",
                                "username=" + username
                            );
                        }

                        auditLog(
                            application,
                            "anon",
                            request.getRemoteAddr(),
                            "LOGIN_FAIL",
                            "username=" + username
                        );
                    }

                } catch (Exception ex) {

                    // Do not expose internal exception details
                    auditLog(
                        application,
                        "system",
                        request.getRemoteAddr(),
                        "INTERNAL_ERROR",
                        "login"
                    );

                    loginError =
                        "Login unavailable. Please try again later.";

                } finally {

                    if (rs != null) {
                        try {
                            rs.close();
                        } catch (Exception ignored) {
                        }
                    }

                    if (ps != null) {
                        try {
                            ps.close();
                        } catch (Exception ignored) {
                        }
                    }

                    if (conn != null) {
                        try {
                            conn.close();
                        } catch (Exception ignored) {
                        }
                    }
                }
            }
        }
    }
%>

<!DOCTYPE html>
<html>
<head>

    <meta charset="UTF-8">

    <title>Login</title>

    <style>

        body {
            font-family: Arial, sans-serif;
            background: #f4f4f4;
            margin: 0;
            padding: 0;
        }

        .login-container {
            width: 350px;
            margin: 100px auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.15);
        }

        h2 {
            text-align: center;
            margin-bottom: 25px;
        }

        label {
            display: block;
            margin-bottom: 6px;
            font-weight: bold;
        }

        input[type="text"],
        input[type="password"] {
            width: 100%;
            padding: 10px;
            margin-bottom: 18px;
            box-sizing: border-box;
            border: 1px solid #ccc;
            border-radius: 4px;
        }

        input[type="submit"] {
            width: 100%;
            padding: 11px;
            border: none;
            border-radius: 4px;
            background: #333;
            color: white;
            cursor: pointer;
        }

        input[type="submit"]:hover {
            background: #555;
        }

        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 10px;
            margin-bottom: 18px;
            border-radius: 4px;
        }

    </style>

</head>

<body>

<div class="login-container">

    <h2>Login</h2>

    <% if (loginError != null) { %>

        <div class="error">
            <%= loginError %>
        </div>

    <% } %>

    <form method="post" action="login.jsp">

        <input
            type="hidden"
            name="action"
            value="login"
        >

        <label for="username">
            Username
        </label>

        <input
            type="text"
            id="username"
            name="username"
            maxlength="50"
            autocomplete="username"
            required
        >

        <label for="password">
            Password
        </label>

        <input
            type="password"
            id="password"
            name="password"
            autocomplete="current-password"
            required
        >

        <input
            type="submit"
            value="Login"
        >

    </form>

</div>

</body>
</html>

<%!
    // ============================================================
    // SECURITY AUDIT LOG
    // ============================================================

    void auditLog(
        javax.servlet.ServletContext app,
        String user,
        String ip,
        String action,
        String detail
    ) {

        java.io.File logFile =
            new java.io.File(
                app.getRealPath("/")
                + "security_audit.log"
            );

        java.io.PrintWriter pw = null;

        try {

            pw = new java.io.PrintWriter(
                new java.io.FileWriter(
                    logFile,
                    true
                )
            );

            String ts =
                new java.text.SimpleDateFormat(
                    "yyyy-MM-dd'T'HH:mm:ss'Z'"
                ).format(
                    new java.util.Date()
                );

            pw.printf(
                "%s user=%s ip=%s action=%s %s%n",
                ts,
                user,
                ip,
                action,
                detail
            );

        } catch (Exception ignored) {

            // Never expose audit logging errors to users

        } finally {

            if (pw != null) {
                pw.close();
            }
        }
    }
%>
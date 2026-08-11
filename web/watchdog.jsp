<%@ page import="java.sql.*, java.util.Date" %>
<%@ include file="_secutil.jspf" %>
<%
    // SECGUIDE-8 / SEC2: only safety_officer and admin may access watchdog
    if (!_isSafety) {
        secAudit(application, _secUser, request.getRemoteAddr(),
                 "AUTHZ_DENY", "action=watchdog");
        response.sendError(403, "Not authorised");
        return;
    }

    Class.forName("com.mysql.cj.jdbc.Driver");

    String primaryUrl = "jdbc:mysql://localhost:3306/universitydb"
                      + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    String backupUrl = "jdbc:mysql://localhost:3306/universitydb_backup"
                     + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    String user = "root";
    String password = "root123";

    boolean primaryUp = false;
    boolean backupUp = false;
    
    // Set 2-second timeout
    DriverManager.setLoginTimeout(2);
    
    // Check Primary DB
    try (Connection conn = DriverManager.getConnection(primaryUrl, user, password)) {
        try (Statement stmt = conn.createStatement()) {
            try (ResultSet rs = stmt.executeQuery("SELECT 1")) {
                if (rs.next()) {
                    primaryUp = true;
                }
            }
        }
    } catch (Exception e) {
        primaryUp = false;
    }
    
    // Check Backup DB
    try (Connection conn = DriverManager.getConnection(backupUrl, user, password)) {
        try (Statement stmt = conn.createStatement()) {
            try (ResultSet rs = stmt.executeQuery("SELECT 1")) {
                if (rs.next()) {
                    backupUp = true;
                }
            }
        }
    } catch (Exception e) {
        backupUp = false;
    }

    // State management
    Integer failures = (Integer) application.getAttribute("watchdog_failures");
    if (failures == null) failures = 0;
    
    String state = (String) application.getAttribute("watchdog_state");
    if (state == null) state = "UP";
    
    String oldState = state;

    if (primaryUp) {
        failures = 0;
        if ("DOWN".equals(state)) {
            state = "RECOVERING";
        } else {
            state = "UP";
        }
    } else {
        failures++;
        if (failures >= 3) {
            state = "DOWN";
        }
    }

    application.setAttribute("watchdog_failures", failures);
    application.setAttribute("watchdog_state", state);

    if (!state.equals(oldState)) {
        secAudit(application, _secUser, request.getRemoteAddr(), "WATCHDOG_STATE_CHANGE", "State changed from " + oldState + " to " + state);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>Server Watchdog</title>
    <meta http-equiv="refresh" content="10">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 80%; margin-top: 20px; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #ddd; }
        .btn { padding: 8px 16px; margin: 10px 0; text-decoration: none; display: inline-block; background-color: #f0f0f0; border: 1px solid #ccc; color: black; }
        .green { color: green; font-weight: bold; }
        .red { color: red; font-weight: bold; }
        .orange { color: orange; font-weight: bold; }
    </style>
</head>
<body>
    <h2>System Health Watchdog</h2>
    
    <p>Current System State: 
        <span class="<%= state.equals("UP") ? "green" : (state.equals("DOWN") ? "red" : "orange") %>">
            <%= esc(state) %>
        </span>
    </p>
    
    <table>
        <tr>
            <th>Component</th>
            <th>Status</th>
        </tr>
        <tr>
            <td>Primary Database</td>
            <td class="<%= primaryUp ? "green" : "red" %>"><%= primaryUp ? "UP" : "DOWN" %></td>
        </tr>
        <tr>
            <td>Backup Database</td>
            <td class="<%= backupUp ? "green" : "red" %>"><%= backupUp ? "UP" : "DOWN" %></td>
        </tr>
        <tr>
            <td>Consecutive Failures</td>
            <td><%= failures %></td>
        </tr>
        <tr>
            <td>Last Check</td>
            <td><%= new Date().toString() %></td>
        </tr>
    </table>
    
    <br>
    <a href="watchdog.jsp" class="btn">Refresh</a>
    <a href="monitor.jsp" class="btn">Back to Monitor</a>
</body>
</html>

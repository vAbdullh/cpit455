<%@ page import="java.sql.*" %>
<%@ include file="_secutil.jspf" %>
<%
    // SECGUIDE-8 / SEC2: only safety_officer and admin may access monitor
    if (!_isSafety) {
        secAudit(application, _secUser, request.getRemoteAddr(),
                 "AUTHZ_DENY", "action=monitor");
        response.sendError(403, "Not authorised");
        return;
    }

    String safetyAction = request.getParameter("action");
    if ("reset_safety".equals(safetyAction)) {
        // SEC4 / SECGUIDE-5: log every safety-flag change with user identity
        secAudit(application, _secUser, request.getRemoteAddr(),
                 "SAFETY_FLAG_CHANGE", "new_value=false");
        application.setAttribute("safety_suspended", false);
        out.println("<h4 style='color:green;'>Safety Monitor Reset: System is now ACTIVE.</h4>");
    }

    Boolean safetySuspended = (Boolean) application.getAttribute("safety_suspended");
    if (safetySuspended == null) safetySuspended = false;
%>
<html><head>
    <title>Self-Monitoring Check</title>
    <style>
        table { border-collapse:collapse; width:80%; }
        th, td { border:1px solid black; padding:8px; text-align:center; }
        th { background-color:#ddd; }
    </style>
</head><body>
<h2>Self-Monitoring &amp; Safety Control</h2>
<p>Signed in as: <strong><%= esc(_secUser) %></strong> (role: <em><%= esc(_secRole) %></em>)
   | <a href="logout.jsp">Logout</a></p>

<div style="background:#f8fafc;border:1px solid #cbd5e1;padding:15px;border-radius:5px;margin-bottom:20px;">
    <h3>Safety Monitor Status</h3>
    <p>System Status:
    <% if (safetySuspended) { %>
        <strong style="color:red;">SUSPENDED 🔴</strong>
        <form method="POST" action="monitor.jsp" style="display:inline;margin-left:15px;">
            <input type="hidden" name="action" value="reset_safety">
            <input type="submit" value="Reset Safety Suspension"
                   style="background:#10b981;color:#fff;border:none;padding:6px 12px;border-radius:4px;cursor:pointer;font-weight:bold;">
        </form>
    <% } else { %>
        <strong style="color:green;">ACTIVE 🟢</strong>
    <% } %>
    </p>
    <h4>Safety Hazard Log</h4>
    <div style="background:#1e293b;color:#f8fafc;padding:12px;border-radius:4px;font-family:monospace;font-size:.9rem;max-height:150px;overflow-y:auto;">
    <%
        String logPath = application.getRealPath("/") + "safety_hazard.log";
        java.io.File logFile = new java.io.File(logPath);
        if (logFile.exists()) {
            java.io.BufferedReader logReader = null;
            try {
                logReader = new java.io.BufferedReader(new java.io.FileReader(logFile));
                String line; int lineCount = 0;
                while ((line = logReader.readLine()) != null) {
                    out.println(esc(line) + "<br>");  // SECGUIDE-7: escape log output
                    lineCount++;
                }
                if (lineCount == 0) out.println("Safety hazard log is empty.");
            } catch (Exception ex) {
                out.println("Error reading log file."); // SECGUIDE-3: no detail
            } finally {
                if (logReader != null) try { logReader.close(); } catch (Exception ignored) {}
            }
        } else {
            out.println("No safety hazards logged yet.");
        }
    %>
    </div>
</div>

<h3>Self-Monitoring Consistency Check</h3>
<%
    String url = "jdbc:mysql://localhost:3306/universitydb"
               + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    Connection conn = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(url, "root", "root123");
        PreparedStatement s1 = conn.prepareStatement("SELECT COUNT(*) FROM student");
        ResultSet r1 = s1.executeQuery(); r1.next();
        int byTable = r1.getInt(1); r1.close(); s1.close();

        PreparedStatement s2 = conn.prepareStatement(
            "SELECT (SELECT COUNT(*) FROM audit_log WHERE action='INSERT') - "
          + "(SELECT COUNT(*) FROM audit_log WHERE action='DELETE')");
        ResultSet r2 = s2.executeQuery(); r2.next();
        int byAudit = r2.getInt(1); r2.close(); s2.close();

        if (byTable != byAudit) {
            out.println("<h3 style='color:red;'>CONSISTENCY FAILURE: table="
                        + byTable + " audit=" + byAudit + "</h3>");
        } else {
            out.println("<h3 style='color:green;'>Consistent: " + byTable + " students</h3>");
        }
%>
<br><h3>Audit Logs (DB)</h3>
<table>
    <thead><tr><th>Log ID</th><th>Action</th><th>Student ID</th><th>Action Time</th></tr></thead>
    <tbody>
<%
        PreparedStatement sLogs = conn.prepareStatement(
            "SELECT log_id, action, student_id, action_time FROM audit_log ORDER BY log_id DESC");
        ResultSet rLogs = sLogs.executeQuery();
        while (rLogs.next()) {
%>
        <tr>
            <td><%= rLogs.getInt("log_id") %></td>
            <td><%= esc(rLogs.getString("action")) %></td>
            <td><%= rLogs.getInt("student_id") %></td>
            <td><%= esc(String.valueOf(rLogs.getTimestamp("action_time"))) %></td>
        </tr>
<%
        }
        rLogs.close(); sLogs.close();
    } catch (Exception e) {
        out.println("<p>Error retrieving audit logs.</p>");  // SECGUIDE-3
        secAudit(application, _secUser, request.getRemoteAddr(),
                 "INTERNAL_ERROR", "monitor");
    } finally {
        if (conn != null) try { conn.close(); } catch (Exception ignored) {}
    }
%>
    </tbody>
</table>
<br><a href="viewstudents.jsp">Back to Students</a>
 | <a href="watchdog.jsp">Server Watchdog</a>
 | <a href="integrity.jsp">Integrity Checker</a>
</body></html>
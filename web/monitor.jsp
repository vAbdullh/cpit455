<%@ page import="java.sql.*" %>
<html>
<head>
    <title>Self-Monitoring Check</title>
    <style>
        table {
            border-collapse: collapse;
            width: 80%;
        }
        th, td {
            border: 1px solid black;
            padding: 8px;
            text-align: center;
        }
        th {
            background-color: #ddd;
        }
    </style>
</head>
<body>
    <h2>Self-Monitoring & Safety Control</h2>
    
    <%
        String safetyAction = request.getParameter("action");
        if ("reset_safety".equals(safetyAction)) {
            application.setAttribute("safety_suspended", false);
            out.println("<h4 style='color:green;'>Safety Monitor Reset: System is now ACTIVE.</h4>");
        }
        
        Boolean safetySuspended = (Boolean) application.getAttribute("safety_suspended");
        if (safetySuspended == null) safetySuspended = false;
    %>

    <div style="background-color:#f8fafc; border:1px solid #cbd5e1; padding:15px; border-radius:5px; margin-bottom:20px;">
        <h3>Safety Monitor Status</h3>
        <p>
            System Status: 
            <% if (safetySuspended) { %>
                <strong style="color:red; font-size:1.1rem;">SUSPENDED 🔴</strong> (Awaiting Reset)
                <form method="POST" action="monitor.jsp" style="display:inline; margin-left:15px;">
                    <input type="hidden" name="action" value="reset_safety">
                    <input type="submit" value="Reset Safety Suspension" style="background-color:#10b981; color:white; border:none; padding:6px 12px; border-radius:4px; cursor:pointer; font-weight:bold;">
                </form>
            <% } else { %>
                <strong style="color:green; font-size:1.1rem;">ACTIVE 🟢</strong> (Operational)
            <% } %>
        </p>
        
        <h4>Safety Hazard Log (safety_hazard.log)</h4>
        <div style="background-color:#1e293b; color:#f8fafc; padding:12px; border-radius:4px; font-family:monospace; font-size:0.9rem; max-height:150px; overflow-y:auto; border:1px solid #475569;">
            <%
                String logPath = application.getRealPath("/") + "safety_hazard.log";
                java.io.File logFile = new java.io.File(logPath);
                if (logFile.exists()) {
                    java.io.BufferedReader logReader = null;
                    try {
                        logReader = new java.io.BufferedReader(new java.io.FileReader(logFile));
                        String line;
                        int lineCount = 0;
                        while ((line = logReader.readLine()) != null) {
                            out.println(line + "<br>");
                            lineCount++;
                        }
                        if (lineCount == 0) {
                            out.println("Safety hazard log is empty.");
                        }
                    } catch (Exception ex) {
                        out.println("Error reading log file: " + ex.getMessage());
                    } finally {
                        if (logReader != null) {
                            try { logReader.close(); } catch (Exception ignored) {}
                        }
                    }
                } else {
                    out.println("No safety hazards logged yet. System is clean.");
                }
            %>
        </div>
    </div>

    <h3>Self-Monitoring Consistency Check</h3>
    <%
    String url = "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    String user = "root";
    String password = "root123";
    Connection conn = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(url, user, password);

        // 1. Consistency Check
        Statement s1 = conn.createStatement();
        ResultSet r1 = s1.executeQuery("SELECT COUNT(*) FROM student");
        r1.next();
        int byTable = r1.getInt(1);
        r1.close();
        s1.close();

        Statement s2 = conn.createStatement();
        ResultSet r2 = s2.executeQuery(
            "SELECT (SELECT COUNT(*) FROM audit_log WHERE action='INSERT') - " +
            "(SELECT COUNT(*) FROM audit_log WHERE action='DELETE')"
        );
        r2.next();
        int byAudit = r2.getInt(1);
        r2.close();
        s2.close();

        if (byTable != byAudit) {
            out.println("<h3 style='color:red;'>CONSISTENCY FAILURE: student table has "
            + byTable + " rows, but audit_log implies " + byAudit + "</h3>");
        } else {
            out.println("<h3 style='color:green;'>Consistent: both methods report "
            + byTable + " students</h3>");
        }

        // 2. Display audit_log records
%>
    <br>
    <h3>Audit Logs</h3>
    <table>
        <thead>
            <tr>
                <th>Log ID</th>
                <th>Action</th>
                <th>Student ID</th>
                <th>Action Time</th>
            </tr>
        </thead>
        <tbody>
<%
        Statement sLogs = conn.createStatement();
        ResultSet rLogs = sLogs.executeQuery("SELECT log_id, action, student_id, action_time FROM audit_log ORDER BY log_id DESC");
        while (rLogs.next()) {
%>
            <tr>
                <td><%= rLogs.getInt("log_id") %></td>
                <td><%= rLogs.getString("action") %></td>
                <td><%= rLogs.getInt("student_id") %></td>
                <td><%= rLogs.getTimestamp("action_time") %></td>
            </tr>
<%
        }
        rLogs.close();
        sLogs.close();

    } catch (Exception e) {
%>
            <tr>
                <td colspan="4">Error retrieving audit logs: <%= e.getMessage() %></td>
            </tr>
<%
    } finally {
        if (conn != null) {
            try {
                conn.close();
            } catch (SQLException ignored) {}
        }
    }
%>
        </tbody>
    </table>
    <br>
    <a href="viewstudents.jsp">Back to Students</a>
</body>
</html>
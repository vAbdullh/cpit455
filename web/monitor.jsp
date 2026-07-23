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
    <h2>Self-Monitoring Consistency Check</h2>
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
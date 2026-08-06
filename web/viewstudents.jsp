<%@ page import="java.sql.*" %>

<!DOCTYPE html>
<html>
    <head>
        <title>View Students</title>

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

        .low-gpa {
            color: red;
        }
    </style>
    </head>

    <body>

        <h2>Student List</h2>

        <%
    Boolean safetySuspended = (Boolean) application.getAttribute("safety_suspended");
    if (safetySuspended == null) safetySuspended = false;

    int currentOccupancy = 0;
    String urlCount = "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    String backupUrlCount = "jdbc:mysql://localhost:3306/universitydb_backup?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    String userCount = "root";
    String passwordCount = "root123";
    Connection connCount = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        try {
            connCount = DriverManager.getConnection(urlCount, userCount, passwordCount);
        } catch (Exception e) {
            connCount = DriverManager.getConnection(backupUrlCount, userCount, passwordCount);
        }
        Statement s = connCount.createStatement();
        ResultSet r = s.executeQuery("SELECT COUNT(*) FROM student");
        if (r.next()) {
            currentOccupancy = r.getInt(1);
        }
        r.close();
        s.close();
    } catch (Exception e) {
        currentOccupancy = 20;
        // Safe fallback
    } finally {
        if (connCount != null) {
            try {
                connCount.close();
            } catch (Exception se) {
            }
        }
    }

%>

        <%
    if (safetySuspended) {

%>
        <div style="background-color:#fee2e2; border:1px solid #ef4444; color:#991b1b; padding:15px; border-radius:5px; margin-bottom:15px;">
            <strong>⚠️ Safety Alert:</strong> System is currently safety-suspended due to a safety violation (e.g., attempt to enroll without safety training or exceeding capacity).
            New registrations are blocked. <a href="monitor.jsp" style="color:#b91c1c; font-weight:bold; text-decoration:underline;">Go to Safety Monitor & Reset</a>
        </div>
        <% } %>

        <div style="background-color:#f3f4f6; border:1px solid #d1d5db; padding:10px 15px; border-radius:5px; margin-bottom:20px; display:inline-block;">
            Room Occupancy: <strong><%= currentOccupancy %></strong> / 20
            <%
    if (currentOccupancy >= 20) {

%>
            <span style="color:#b91c1c; font-weight:bold;">[ROOM IS FULL]</span>
            <%

    } else {

%>
            <span style="color:#15803d;">[SAFE]</span>
            <% } %>
        </div>

        <br>

        <form method="GET" action="viewstudents.jsp">
            Search Name:
            <input type="text" name="search" value="<%= request.getParameter("search") != null ? request.getParameter("search") : "" %>">
            <input type="submit" value="Search">
        </form>

        <br>

        <table>

            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>GPA</th>
            </tr>

            <%
    String search = request.getParameter("search");

    String primaryUrl =
    "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";

    String backupUrl =
    "jdbc:mysql://localhost:3306/universitydb_backup?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";

    String user = "root";
    String password = "root123";

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;

    boolean usingBackup = false;

    try {

        Class.forName("com.mysql.cj.jdbc.Driver");

        try {

            // Try PRIMARY database
            conn = DriverManager.getConnection(primaryUrl, user, password);

            String sql;

            if (search != null && !search.trim().isEmpty()) {
                sql = "SELECT * FROM student WHERE name LIKE ?";
                ps = conn.prepareStatement(sql);
                ps.setString(1, "%" + search + "%");
            } else {
                sql = "SELECT * FROM student";
                ps = conn.prepareStatement(sql);
            }

            rs = ps.executeQuery();

        } catch (Exception primaryError) {

            // If anything fails, switch to BACKUP database
            usingBackup = true;

            try {
                if (conn != null) conn.close();
            } catch (Exception ignored) {
            }

            conn = DriverManager.getConnection(backupUrl, user, password);

            String sql;

            if (search != null && !search.trim().isEmpty()) {
                sql = "SELECT * FROM student WHERE name LIKE ?";
                ps = conn.prepareStatement(sql);
                ps.setString(1, "%" + search + "%");
            } else {
                sql = "SELECT * FROM student";
                ps = conn.prepareStatement(sql);
            }

            rs = ps.executeQuery();
        }

        if (usingBackup) {
            out.println("<p><b>Using BACKUP database</b></p>");
        } else {
            out.println("<p><b>Using PRIMARY database</b></p>");
        }

        while (rs.next()) {

            double gpa = rs.getDouble("gpa");

%>

            <tr>

                <td><%= rs.getInt("student_id") %></td>

                <td><%= rs.getString("name") %></td>

                <td><%= rs.getString("email") %></td>

                <td class="<%= gpa < 3.50 ? "low-gpa" : "" %>">
                    <%= gpa %>
                </td>

            </tr>

            <%

    }

    } catch (Exception e) {

        out.println("<tr><td colspan='4'>");
        out.println("<b>Error:</b> " + e.getMessage());
        out.println("</td></tr>");

    } finally {

        try {
            if (rs != null) rs.close();
        } catch (Exception ignored) {
        }

        try {
            if (ps != null) ps.close();
        } catch (Exception ignored) {
        }

        try {
            if (conn != null) conn.close();
        } catch (Exception ignored) {
        }
    }

%>

        </table>

        <br>

        <a href="addstudent.jsp">
            Add New Student
        </a>
        |
        <a href="monitor.jsp">
            Self-Monitoring & Safety Control
        </a>

    </body>
</html>
<%@ page import="java.sql.*" %>
<html>
    <head><title>Delete Student</title></head>
    <body>
        <h2>Delete Result</h2>
        <%
    String idParam = request.getParameter("id");
    String error = null;
    int id = 0;

    if (idParam == null || idParam.trim().isEmpty()) {
        error = "Student ID is required";
    } else {
        try {
            id = Integer.parseInt(idParam.trim());
            if (id <= 0) error = "Student ID must be positive";
        } catch (Exception e) {
            error = "Student ID must be a number";
        }
    }

    if (error != null) {
        out.println("<h3>Rejected: " + error + "</h3>");
    } else {
        Boolean safetySuspended = (Boolean) application.getAttribute("safety_suspended");
        if (safetySuspended != null && safetySuspended) {
            out.println("<p style='color:orange;'><strong>Notice:</strong> System is currently safety-suspended. Deletions are permitted as safety-recovering operations to reduce room occupancy.</p>");
        }

        String url = "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
        String user = "root";
        String password = "root123";
        Connection conn = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            conn = DriverManager.getConnection(url, user, password);
            conn.setAutoCommit(false);

            PreparedStatement ps = conn.prepareStatement("DELETE FROM student WHERE student_id=?");
            ps.setInt(1, id);
            int result = ps.executeUpdate();
            ps.close();

            if (result > 0) {
                PreparedStatement ps2 = conn.prepareStatement(
                "INSERT INTO audit_log(action, student_id) VALUES (?, ?)");
                ps2.setString(1, "DELETE");
                ps2.setInt(2, id);
                ps2.executeUpdate();
                ps2.close();
                conn.commit();
                out.println("<h3>Student deleted successfully</h3>");
            } else {
                conn.rollback();
                out.println("<h3>Student not found</h3>");
            }
        } catch (Exception e) {
            if (conn != null) {
                try {
                    conn.rollback();
                } catch (SQLException se) {
                }
            }
            out.println("<h3>Error: " + e.getMessage() + "</h3>");
        } finally {
            if (conn != null) {
                try {
                    conn.setAutoCommit(true);
                    conn.close();
                } catch (SQLException se) {
                }
            }
        }
    }

%>
        <br>
        <a href="viewstudents.jsp">Back to Students</a>
    </body>
</html>
<%@ page import="java.sql.*" %>
<html>
    <head><title>Delete Student</title></head>
    <body>
        <h2>Delete Result</h2>
        <%
    String idParam = request.getParameter("id");
    String error = null;
    int id = 0;

    // ---- FR-1 Checking layer: validate BEFORE any DB code ----
    if (idParam == null || idParam.trim().isEmpty()) {
        error = "Student ID is required";
    } else {
        try {
            id = Integer.parseInt(idParam.trim());
            if (id <= 0) error = "Student ID must be positive";
        } catch (NumberFormatException e) {
            error = "Student ID must be a number";
        }
    }

    if (error != null) {
        out.println("<h3>Rejected: " + error + "</h3>");
    } else {
        String url = "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
        String user = "root";
        String password = "root123";
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            Connection conn = DriverManager.getConnection(url, user, password);
            String sql = "DELETE FROM student WHERE student_id=?";
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setInt(1, id);
            int result = ps.executeUpdate();
            if (result > 0) {
                out.println("<h3>Student deleted successfully</h3>");
            } else {
                out.println("<h3>Student not found</h3>");
            }
            ps.close();
            conn.close();
        } catch (Exception e) {
            out.println("<h3>Error: " + e.getMessage() + "</h3>");
        }
    }

%>
        <br>
        <a href="viewstudents.jsp">Back to Students</a>
    </body>
</html>
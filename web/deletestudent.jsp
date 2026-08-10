<%@ page import="java.sql.*" %>
<%@ include file="_secutil.jspf" %>
<%
    // SECGUIDE-8 / SEC2: only admin / student_admin may delete
    if (!_isAdminOp) {
        secAudit(application, _secUser, request.getRemoteAddr(),
                 "AUTHZ_DENY", "action=deletestudent");
        response.sendError(403, "Not authorised");
        return;
    }

    String idParam = request.getParameter("id");
    String error   = null;
    int    id      = 0;

    // SECGUIDE-7 / SEC3: validate student_id format
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
%>
<html><head><title>Delete Student</title></head><body>
<h2>Delete Result</h2>
<p>Signed in as: <strong><%= esc(_secUser) %></strong> | <a href="logout.jsp">Logout</a></p>
<%
    if (error != null) {
        out.println("<h3>Rejected: " + esc(error) + "</h3>");
    } else {
        String url = "jdbc:mysql://localhost:3306/universitydb"
                   + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
        Connection conn = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            conn = DriverManager.getConnection(url, "root", "root123");
            conn.setAutoCommit(false);
            // SECGUIDE-7: parameterised delete
            PreparedStatement ps = conn.prepareStatement(
                "DELETE FROM student WHERE student_id = ?");
            ps.setInt(1, id);
            int result = ps.executeUpdate();
            ps.close();
            if (result > 0) {
                PreparedStatement ps2 = conn.prepareStatement(
                    "INSERT INTO audit_log(action, student_id) VALUES (?, ?)");
                ps2.setString(1, "DELETE"); ps2.setInt(2, id);
                ps2.executeUpdate(); ps2.close();
                conn.commit();
                // SEC4: audit the deletion with user identity and IP
                secAudit(application, _secUser, request.getRemoteAddr(),
                         "STUDENT_DELETE", "student_id=" + id);
                out.println("<h3>Student deleted successfully</h3>");
            } else {
                conn.rollback();
                out.println("<h3>Student not found</h3>");
            }
        } catch (Exception e) {
            if (conn != null) try { conn.rollback(); } catch (Exception ignored) {}
            // SECGUIDE-3: suppress raw error
            secAudit(application, _secUser, request.getRemoteAddr(),
                     "INTERNAL_ERROR", "deletestudent");
            out.println("<h3>An error occurred. Please try again.</h3>");
        } finally {
            if (conn != null)
                try { conn.setAutoCommit(true); conn.close(); } catch (Exception ignored) {}
        }
    }
%>
<br><a href="viewstudents.jsp">Back to Students</a>
</body></html>
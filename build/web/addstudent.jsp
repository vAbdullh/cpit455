<%@ page import="java.sql.*" %>
<%@ include file="_secutil.jspf" %>
<%
    // SECGUIDE-8 / SEC2: only student_admin and admin may add students
    if (!_isAdminOp) {
        secAudit(application, _secUser, request.getRemoteAddr(),
                 "AUTHZ_DENY", "action=addstudent");
        response.sendRedirect("viewstudents.jsp");
        return;
    }

    Boolean safetySuspended = (Boolean) application.getAttribute("safety_suspended");
    if (safetySuspended == null) safetySuspended = false;

    int currentOccupancy = 0;
    Connection conn = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        String dbUrl = "jdbc:mysql://localhost:3306/universitydb"
                     + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
        conn = DriverManager.getConnection(dbUrl, "root", "root123");
        PreparedStatement s = conn.prepareStatement("SELECT COUNT(*) FROM student");
        ResultSet r = s.executeQuery();
        if (r.next()) currentOccupancy = r.getInt(1);
        r.close(); s.close();
    } catch (Exception e) {
        currentOccupancy = 20;
    } finally {
        if (conn != null) try { conn.close(); } catch (Exception ignored) {}
    }
    boolean isFull    = currentOccupancy >= 20;
    boolean cannotAdd = safetySuspended || isFull;
%>
<!DOCTYPE html>
<html lang="en">
    <head><title>Add Student</title></head>
    <body>
        <h2>Add New Student</h2>
        <p>Signed in as: <strong><%= esc(_secUser) %></strong> | <a href="logout.jsp">Logout</a></p>
        <p>Current Occupancy: <strong><%= currentOccupancy %></strong> / 20</p>
        <% if (safetySuspended) { %>
            <h3 style="color:red;">WARNING: System suspended. Cannot register new students.</h3>
        <% } else if (isFull) { %>
            <h3 style="color:red;">WARNING: Maximum room capacity (20) reached.</h3>
        <% } %>
        <form action="insertstudent.jsp" method="POST">
            Name: <input type="text" name="name" required <%= cannotAdd ? "disabled" : "" %>><br><br>
            Email: <input type="email" name="email" required <%= cannotAdd ? "disabled" : "" %>><br><br>
            GPA: <input type="number" step="0.01" name="gpa" required <%= cannotAdd ? "disabled" : "" %>><br><br>
            Safety Training:
            <label><input type="checkbox" name="safety_training" value="true" <%= cannotAdd ? "disabled" : "" %>>
            Has completed safety training</label><br><br>
            <input type="submit" value="Add Student" <%= cannotAdd ? "disabled" : "" %>>
        </form>
        <br><a href="viewstudents.jsp">Back to Students</a>
    </body>
</html>
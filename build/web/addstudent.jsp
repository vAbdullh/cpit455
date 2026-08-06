<%@ page import="java.sql.*" %>
<%
    Boolean safetySuspended = (Boolean) application.getAttribute("safety_suspended");
    if (safetySuspended == null) safetySuspended = false;

    int currentOccupancy = 0;
    String url = "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    String backupUrl = "jdbc:mysql://localhost:3306/universitydb_backup?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    String user = "root";
    String password = "root123";
    Connection conn = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        try {
            conn = DriverManager.getConnection(url, user, password);
        } catch (Exception e) {
            conn = DriverManager.getConnection(backupUrl, user, password);
        }
        Statement s = conn.createStatement();
        ResultSet r = s.executeQuery("SELECT COUNT(*) FROM student");
        if (r.next()) {
            currentOccupancy = r.getInt(1);
        }
        r.close();
        s.close();
    } catch (Exception e) {
        // Guarded compute: default to safe limit on error
        currentOccupancy = 20;
    } finally {
        if (conn != null) {
            try { conn.close(); } catch (Exception se) {}
        }
    }
    
    boolean isFull = currentOccupancy >= 20;
    boolean cannotAdd = safetySuspended || isFull;
%>
<!DOCTYPE html>
<html>
    <head>
        <title>Add Student</title>
    </head>

    <body>

        <h2>Add New Student</h2>
        
        <p>Current Occupancy: <strong><%= currentOccupancy %></strong> / 20</p>

        <% if (safetySuspended) { %>
            <h3 style="color:red;">WARNING: System suspended awaiting reset. Cannot register new students.</h3>
        <% } else if (isFull) { %>
            <h3 style="color:red;">WARNING: Maximum room capacity (20) reached. Cannot register new students.</h3>
        <% } %>

        <form action="insertstudent.jsp" method="POST">

            Name:
            <input type="text" name="name" required <%= cannotAdd ? "disabled" : "" %>>
            <br><br>

            Email:
            <input type="email" name="email" required <%= cannotAdd ? "disabled" : "" %>>
            <br><br>

            GPA:
            <input type="number" step="0.01" name="gpa" required <%= cannotAdd ? "disabled" : "" %>>
            <br><br>

            Safety Training:
            <label>
                <input type="checkbox" name="safety_training" value="true" <%= cannotAdd ? "disabled" : "" %>>
                Has completed safety training
            </label>
            <br><br>

            <input type="submit" value="Add Student" <%= cannotAdd ? "disabled" : "" %>>

        </form>
        
        <br>
        <a href="viewstudents.jsp">Back to Students</a>
    </body>
</html>
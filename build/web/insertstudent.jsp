<%@ page import="java.sql.*" %>
<html>
<head><title>Add Student Result</title></head>
<body>
<h2>Add Student Result</h2>
<%
String name = request.getParameter("name");
String email = request.getParameter("email");
String gpaParam = request.getParameter("gpa");

// ---- FR-1 Checking layer: validate BEFORE any DB code ----
String error = null;
double gpa = 0;

if (name == null || !name.trim().matches("^[a-zA-Z ]{2,50}$")) {
    error = "Name must be 2-50 letters only";
} else if (email == null || !email.matches("^[\\w.+-]+@[\\w-]+(\\.[\\w-]+)*\\.[a-zA-Z]{2,}$")) {
    error = "Invalid email format";
} else {
    try {
        gpa = Double.parseDouble(gpaParam);
        if (gpa < 0.0 || gpa > 4.0) {
            error = "GPA must be between 0.0 and 4.0";
        }
    } catch (Exception e) {
        error = "GPA must be a valid number";
    }
}

if (error != null) {
    out.println("<h3>Rejected: " + error + "</h3>");
} else {
    // ---- validation passed, now safe to write to DB ----
    String url = "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    String user = "root";
    String password = "root123";
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        Connection conn = DriverManager.getConnection(url, user, password);
        String sql = "INSERT INTO student(name, email, gpa) VALUES (?, ?, ?)";
        PreparedStatement ps = conn.prepareStatement(sql);
        ps.setString(1, name.trim());
        ps.setString(2, email);
        ps.setDouble(3, gpa);
        ps.executeUpdate();
        ps.close();
        conn.close();
        out.println("<h3>Student added successfully</h3>");
    } catch (Exception e) {
        out.println("<h3>Error: " + e.getMessage() + "</h3>");
    }
}
%>
<br>
<a href="viewstudents.jsp">Back to Students</a>
</body>
</html>
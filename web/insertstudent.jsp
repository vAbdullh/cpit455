<%@ page import="java.sql.*" %>
<html>
    <head><title>Add Student Result</title></head>
    <body>
        <h2>Add Student Result</h2>
        <%
    String name = request.getParameter("name");
    String email = request.getParameter("email");
    String gpaParam = request.getParameter("gpa");

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
        String url = "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
        String user = "root";
        String password = "root123";
        Connection conn = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            conn = DriverManager.getConnection(url, user, password);
            conn.setAutoCommit(false);

            // ---- Protection System: independent, simple guard ----
            boolean permitted = true;
            String vetoReason = null;

            if (gpa < 0.0 || gpa > 4.0) {
                permitted = false;
                vetoReason = "GPA out of bounds";
            }

            if (permitted) {
                PreparedStatement dupCheck = conn.prepareStatement(
                "SELECT COUNT(*) FROM student WHERE email = ?");
                dupCheck.setString(1, email);
                ResultSet dupRs = dupCheck.executeQuery();
                dupRs.next();
                if (dupRs.getInt(1) > 0) {
                    permitted = false;
                    vetoReason = "Duplicate email - student already registered";
                }
                dupRs.close();
                dupCheck.close();
            }

            if (!permitted) {
                conn.rollback();
                out.println("<h3>Vetoed by protection system: " + vetoReason + "</h3>");
            } else {
                PreparedStatement ps1 = conn.prepareStatement(
                "INSERT INTO student(name, email, gpa) VALUES (?, ?, ?)",
                Statement.RETURN_GENERATED_KEYS);
                ps1.setString(1, name.trim());
                ps1.setString(2, email);
                ps1.setDouble(3, gpa);
                ps1.executeUpdate();

                ResultSet keys = ps1.getGeneratedKeys();
                int newId = 0;
                if (keys.next()) {
                    newId = keys.getInt(1);
                }
                keys.close();
                ps1.close();

                PreparedStatement ps2 = conn.prepareStatement(
                "INSERT INTO audit_log(action, student_id) VALUES (?, ?)");
                ps2.setString(1, "INSERT");
                ps2.setInt(2, newId);
                ps2.executeUpdate();
                ps2.close();

                conn.commit();
                out.println("<h3>Student added successfully</h3>");
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
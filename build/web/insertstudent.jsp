<%@ page import="java.sql.*" %>
<%@ include file="_secutil.jspf" %>
<%
    // SECGUIDE-8 / SEC2: role check – only admin / student_admin may insert
    if (!_isAdminOp) {
        secAudit(application, _secUser, request.getRemoteAddr(),
                 "AUTHZ_DENY", "action=insertstudent");
        response.sendError(403, "Not authorised");
        return;
    }

    String name     = request.getParameter("name");
    String email    = request.getParameter("email");
    String gpaParam = request.getParameter("gpa");
    String error    = null;
    double gpa      = 0;

    // SECGUIDE-7 / SEC3: validate every input against a specified format
    if (name == null || !name.trim().matches("^[a-zA-Z ]{2,50}$")) {
        error = "Name must be 2-50 letters only";
    } else if (email == null || !email.matches("^[\\w.+-]+@[\\w-]+(\\.[\\w-]+)*\\.[a-zA-Z]{2,}$")) {
        error = "Invalid email format";
    } else {
        try {
            gpa = Double.parseDouble(gpaParam);
            if (gpa < 0.0 || gpa > 4.0) error = "GPA must be between 0.0 and 4.0";
        } catch (Exception e) {
            error = "GPA must be a valid number";
        }
    }

    if (error != null) {
        out.println("<h3>Rejected: " + esc(error) + "</h3>");
    } else {
        Boolean safetySuspended = (Boolean) application.getAttribute("safety_suspended");
        if (safetySuspended != null && safetySuspended) {
            out.println("<h3 style='color:red;'>System suspended awaiting reset</h3>");
            out.println("<br><a href='viewstudents.jsp'>Back</a>");
            return;
        }
        String url = "jdbc:mysql://localhost:3306/universitydb"
                   + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
        Connection conn = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            conn = DriverManager.getConnection(url, "root", "root123");
            conn.setAutoCommit(false);

            boolean permitted  = true;
            String  vetoReason = null;
            if (gpa < 0.0 || gpa > 4.0) { permitted = false; vetoReason = "GPA out of bounds"; }

            if (permitted) {
                // SECGUIDE-7: parameterised duplicate-email check
                PreparedStatement dupCheck =
                    conn.prepareStatement("SELECT COUNT(*) FROM student WHERE email = ?");
                dupCheck.setString(1, email);
                ResultSet dupRs = dupCheck.executeQuery();
                dupRs.next();
                if (dupRs.getInt(1) > 0) { permitted = false; vetoReason = "Duplicate email"; }
                dupRs.close(); dupCheck.close();
            }

            int currentOccupancy = 20;
            try {
                PreparedStatement occCheck =
                    conn.prepareStatement("SELECT COUNT(*) FROM student");
                ResultSet occRs = occCheck.executeQuery();
                if (occRs.next()) currentOccupancy = occRs.getInt(1);
                occRs.close(); occCheck.close();
            } catch (Exception ignored) {}

            boolean hasTraining    = "true".equals(request.getParameter("safety_training"));
            boolean safetyViolation = false;
            String  alarmReason     = null;
            if (!hasTraining) { safetyViolation = true; alarmReason = "No safety training"; }
            else if (currentOccupancy >= 20) { safetyViolation = true; alarmReason = "Room capacity exceeded"; }

            if (safetyViolation) {
                application.setAttribute("safety_suspended", true);
                // SEC4: log safety event with user identity and IP
                secAudit(application, _secUser, request.getRemoteAddr(),
                         "SAFETY_ALARM", "email=" + email + " reason=" + alarmReason);
                conn.rollback();
                out.println("<h3 style='color:red;'>VETOED BY SAFETY MONITOR: " + esc(alarmReason) + "</h3>");
            } else if (!permitted) {
                conn.rollback();
                out.println("<h3>Vetoed by protection system: " + esc(vetoReason) + "</h3>");
            } else {
                // SECGUIDE-7: parameterised INSERT – no concatenation
                PreparedStatement ps1 = conn.prepareStatement(
                    "INSERT INTO student(name, email, gpa) VALUES (?, ?, ?)",
                    Statement.RETURN_GENERATED_KEYS);
                ps1.setString(1, name.trim());
                ps1.setString(2, email);
                ps1.setDouble(3, gpa);
                ps1.executeUpdate();
                ResultSet keys = ps1.getGeneratedKeys();
                int newId = 0;
                if (keys.next()) newId = keys.getInt(1);
                keys.close(); ps1.close();

                PreparedStatement ps2 = conn.prepareStatement(
                    "INSERT INTO audit_log(action, student_id) VALUES (?, ?)");
                ps2.setString(1, "INSERT");
                ps2.setInt(2, newId);
                ps2.executeUpdate(); ps2.close();

                conn.commit();
                // SEC4: audit with user identity
                secAudit(application, _secUser, request.getRemoteAddr(),
                         "STUDENT_INSERT", "student_id=" + newId + " email=" + email);
                out.println("<h3>Student added successfully</h3>");
            }
        } catch (Exception e) {
            if (conn != null) try { conn.rollback(); } catch (Exception ignored) {}
            // SECGUIDE-3: no raw error to client
            secAudit(application, _secUser, request.getRemoteAddr(),
                     "INTERNAL_ERROR", "insertstudent");
            out.println("<h3>An error occurred. Please try again.</h3>");
        } finally {
            if (conn != null) try { conn.setAutoCommit(true); conn.close(); } catch (Exception ignored) {}
        }
    }
%>
<br><a href="viewstudents.jsp">Back to Students</a>
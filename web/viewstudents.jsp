<%@ page import="java.sql.*" %>
<%@ include file="_secutil.jspf" %>

<!DOCTYPE html>
<html>

<head>

    <meta charset="UTF-8">

    <title>Student List</title>

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
        // ========================================================
        // SAFETY STATUS
        // ========================================================

        Boolean safetySuspended =
            (Boolean) application.getAttribute(
                "safety_suspended"
            );

        if (safetySuspended == null) {
            safetySuspended = Boolean.FALSE;
        }


        // ========================================================
        // ROOM OCCUPANCY
        // ========================================================

        int currentOccupancy = 0;

        String urlCount =
            "jdbc:mysql://localhost:3306/universitydb"
            + "?useSSL=false"
            + "&allowPublicKeyRetrieval=true"
            + "&serverTimezone=UTC";

        String backupUrlCount =
            "jdbc:mysql://localhost:3306/universitydb_backup"
            + "?useSSL=false"
            + "&allowPublicKeyRetrieval=true"
            + "&serverTimezone=UTC";

        String userCount = "root";
        String passwordCount = "root123";

        Connection connCount = null;
        PreparedStatement sCount = null;
        ResultSet rCount = null;

        try {

            Class.forName(
                "com.mysql.cj.jdbc.Driver"
            );

            try {

                connCount =
                    DriverManager.getConnection(
                        urlCount,
                        userCount,
                        passwordCount
                    );

            } catch (Exception primaryError) {

                connCount =
                    DriverManager.getConnection(
                        backupUrlCount,
                        userCount,
                        passwordCount
                    );
            }

            sCount =
                connCount.prepareStatement(
                    "SELECT COUNT(*) FROM student"
                );

            rCount =
                sCount.executeQuery();

            if (rCount.next()) {

                currentOccupancy =
                    rCount.getInt(1);
            }

        } catch (Exception e) {

            // Safe fallback
            currentOccupancy = 20;

            secAudit(
                application,
                _secUser,
                request.getRemoteAddr(),
                "INTERNAL_ERROR",
                "occupancy"
            );

        } finally {

            if (rCount != null) {
                try {
                    rCount.close();
                } catch (Exception ignored) {
                }
            }

            if (sCount != null) {
                try {
                    sCount.close();
                } catch (Exception ignored) {
                }
            }

            if (connCount != null) {
                try {
                    connCount.close();
                } catch (Exception ignored) {
                }
            }
        }
    %>


    <% if (safetySuspended.booleanValue()) { %>

        <p>
            ⚠️ Safety Alert: System is currently
            safety-suspended due to a safety violation
            (e.g., attempt to enroll without safety
            training or exceeding capacity).
            New registrations are blocked.

            <% if (_isSafety) { %>

                <br>

                <a href="monitor.jsp">
                    Go to Safety Monitor &amp; Reset
                </a>

            <% } %>

        </p>

    <% } %>


    <div style="
        background-color:#f3f4f6;
        border:1px solid #d1d5db;
        padding:10px 15px;
        border-radius:5px;
        margin-bottom:20px;
        display:inline-block;
    ">

        Room Occupancy:

        <strong>
            <%= currentOccupancy %>
        </strong>

        / 20

        <%
            if (currentOccupancy >= 20) {
        %>

            <span style="color:red;font-weight:bold;">
                [ROOM IS FULL]
            </span>

        <%
            } else {
        %>

            <span style="color:green;">
                [SAFE]
            </span>

        <%
            }
        %>

    </div>


    <br>


    <!-- ========================================================
         SEARCH
         ======================================================== -->

    <form
        method="GET"
        action="viewstudents.jsp"
    >

        Search Name:

        <input
            type="text"
            name="search"
            maxlength="100"
            value="<%= esc(request.getParameter("search")) %>"
        >

        <input
            type="submit"
            value="Search"
        >

    </form>


    <br>


    <table>

        <tr>

            <th>
                ID
            </th>

            <th>
                Name
            </th>

            <% if (_isAdminOp || _isSafety) { %>

                <th>
                    Email
                </th>

            <% } %>

            <th>
                GPA
            </th>

        </tr>


        <%
            // ====================================================
            // STUDENT DATABASE
            // ====================================================

            String search =
                request.getParameter("search");

            String primaryUrl =
                "jdbc:mysql://localhost:3306/universitydb"
                + "?useSSL=false"
                + "&allowPublicKeyRetrieval=true"
                + "&serverTimezone=UTC";

            String backupUrl =
                "jdbc:mysql://localhost:3306/universitydb_backup"
                + "?useSSL=false"
                + "&allowPublicKeyRetrieval=true"
                + "&serverTimezone=UTC";

            String user = "root";
            String password = "root123";

            Connection conn = null;
            PreparedStatement ps = null;
            ResultSet rs = null;

            boolean usingBackup = false;

            try {

                Class.forName(
                    "com.mysql.cj.jdbc.Driver"
                );


                // =================================================
                // PRIMARY DATABASE
                // =================================================

                try {

                    conn =
                        DriverManager.getConnection(
                            primaryUrl,
                            user,
                            password
                        );

                    if (search != null
                            && !search.trim().isEmpty()) {

                        ps =
                            conn.prepareStatement(
                                "SELECT * FROM student "
                                + "WHERE name LIKE ?"
                            );

                        ps.setString(
                            1,
                            "%" + search.trim() + "%"
                        );

                    } else {

                        ps =
                            conn.prepareStatement(
                                "SELECT * FROM student"
                            );
                    }

                    rs =
                        ps.executeQuery();


                } catch (Exception primaryError) {

                    // =============================================
                    // BACKUP DATABASE
                    // =============================================

                    usingBackup = true;

                    try {

                        if (rs != null) {
                            rs.close();
                        }

                    } catch (Exception ignored) {
                    }

                    try {

                        if (ps != null) {
                            ps.close();
                        }

                    } catch (Exception ignored) {
                    }

                    try {

                        if (conn != null) {
                            conn.close();
                        }

                    } catch (Exception ignored) {
                    }


                    conn =
                        DriverManager.getConnection(
                            backupUrl,
                            user,
                            password
                        );


                    if (search != null
                            && !search.trim().isEmpty()) {

                        ps =
                            conn.prepareStatement(
                                "SELECT * FROM student "
                                + "WHERE name LIKE ?"
                            );

                        ps.setString(
                            1,
                            "%" + search.trim() + "%"
                        );

                    } else {

                        ps =
                            conn.prepareStatement(
                                "SELECT * FROM student"
                            );
                    }

                    rs =
                        ps.executeQuery();
                }


                // =================================================
                // DATABASE STATUS
                // =================================================

                if (usingBackup) {

                    out.println(
                        "<p><b>Using BACKUP database</b></p>"
                    );

                } else {

                    out.println(
                        "<p><b>Using PRIMARY database</b></p>"
                    );
                }


                // =================================================
                // STUDENTS
                // =================================================

                boolean foundStudents = false;

                while (rs.next()) {

                    foundStudents = true;

                    double gpa =
                        rs.getDouble("gpa");

        %>


        <tr>

            <td>
                <%= rs.getInt("student_id") %>
            </td>


            <td>
                <%= esc(
                    rs.getString("name")
                ) %>
            </td>


            <% if (_isAdminOp || _isSafety) { %>

                <td>
                    <%= esc(
                        rs.getString("email")
                    ) %>
                </td>

            <% } %>


            <td
                class="<%= gpa < 3.50 ? "low-gpa" : "" %>"
            >
                <%= gpa %>
            </td>

        </tr>


        <%

                }


                // =================================================
                // NO RESULTS
                // =================================================

                if (!foundStudents) {

        %>

        <tr>

            <td
                colspan="<%= (_isAdminOp || _isSafety) ? 4 : 3 %>"
            >
                No students found.
            </td>

        </tr>

        <%

                }

            } catch (Exception e) {

                // Do not expose exception details to browser.

                secAudit(
                    application,
                    _secUser,
                    request.getRemoteAddr(),
                    "INTERNAL_ERROR",
                    "viewstudents"
                );

        %>

        <tr>

            <td
                colspan="<%= (_isAdminOp || _isSafety) ? 4 : 3 %>"
            >
                <b>
                    Error retrieving students.
                </b>
            </td>

        </tr>

        <%

            } finally {

                try {

                    if (rs != null) {
                        rs.close();
                    }

                } catch (Exception ignored) {
                }


                try {

                    if (ps != null) {
                        ps.close();
                    }

                } catch (Exception ignored) {
                }


                try {

                    if (conn != null) {
                        conn.close();
                    }

                } catch (Exception ignored) {
                }
            }
        %>

    </table>


    <br>


    <% if (_isAdminOp) { %>

        <a href="addstudent.jsp">
            Add New Student
        </a>

    <% } %>


    <% if (_isAdminOp && _isSafety) { %>

        |

    <% } %>


    <% if (_isSafety) { %>

        <a href="monitor.jsp">
            Self-Monitoring &amp; Safety Control
        </a>

    <% } %>


    <%

        // Only show logout if authenticated.
        if (_secUser != null) {

    %>

        |

        <a href="logout.jsp">
            Logout
        </a>

    <%

        }

    %>

</body>

</html>
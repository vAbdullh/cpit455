<%@ page import="java.sql.*, java.util.*, java.text.SimpleDateFormat" %>
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
            boolean isDegraded = false;

            // List to hold student data for caching and display
            List<Map<String,String>> studentRows = new ArrayList<>();

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
                // STUDENTS — read from DB and cache in session
                // =================================================

                while (rs.next()) {
                    Map<String,String> row = new HashMap<>();
                    row.put("student_id", String.valueOf(rs.getInt("student_id")));
                    row.put("name", rs.getString("name"));
                    row.put("email", rs.getString("email"));
                    row.put("gpa", String.valueOf(rs.getDouble("gpa")));
                    studentRows.add(row);
                }

                // ================================================
                // CACHE: store critical summary in session (Task 5)
                // Only cache when NOT searching (full dataset)
                // ================================================
                if (search == null || search.trim().isEmpty()) {
                    session.setAttribute("cached_students", studentRows);
                    session.setAttribute("cache_time", System.currentTimeMillis());
                }


            } catch (Exception e) {

                // =================================================
                // DEGRADED MODE (Task 5): both DBs unavailable
                // Serve from session-scoped local cache
                // =================================================

                secAudit(
                    application,
                    _secUser,
                    request.getRemoteAddr(),
                    "DEGRADED_MODE",
                    "viewstudents — serving from local cache"
                );

                List<Map<String,String>> cached =
                    (List<Map<String,String>>) session.getAttribute("cached_students");
                Long cacheTime = (Long) session.getAttribute("cache_time");

                if (cached != null && cacheTime != null) {
                    isDegraded = true;
                    studentRows = cached;

                    // Mark watchdog state as DOWN
                    application.setAttribute("watchdog_state", "DOWN");
                }

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


            // =====================================================
            // DEGRADED MODE BANNER (Task 5 resilience rule)
            // Data MUST be visibly marked as degraded with its age
            // =====================================================
            if (isDegraded) {
                Long cacheTime = (Long) session.getAttribute("cache_time");
                long ageMs = System.currentTimeMillis() - cacheTime;
                long ageSec = ageMs / 1000;
                String ageText;
                if (ageSec < 60) ageText = ageSec + " seconds";
                else if (ageSec < 3600) ageText = (ageSec / 60) + " minutes";
                else ageText = String.format("%.1f hours", ageSec / 3600.0);
        %>

        <div style="background:#f8d7da;color:#721c24;padding:15px;border:2px solid #c00;margin-bottom:15px;border-radius:4px;width:80%;box-sizing:border-box;">
            <strong>⚠️ DEGRADED MODE</strong><br>
            Both primary and backup databases are unavailable.<br>
            Showing <strong>cached data</strong> from <strong><%= ageText %> ago</strong>.<br>
            This data may not reflect recent changes. Non-critical services are suspended.
        </div>

        <%
            }


            // =====================================================
            // RENDER STUDENT ROWS (from DB or cache)
            // =====================================================

            if (studentRows.isEmpty()) {
        %>

        <tr>
            <td
                colspan="<%= (_isAdminOp || _isSafety) ? 4 : 3 %>"
            >
                <%= isDegraded ? "No cached data available." : "No students found." %>
            </td>
        </tr>

        <%
            } else {
                for (Map<String,String> row : studentRows) {
                    double gpa = Double.parseDouble(row.get("gpa"));
        %>

        <tr>

            <td>
                <%= esc(row.get("student_id")) %>
            </td>

            <td>
                <%= esc(row.get("name")) %>
            </td>

            <% if ((_isAdminOp || _isSafety) && !isDegraded) { %>

                <td>
                    <%= esc(row.get("email")) %>
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
            }
        %>

    </table>


    <br>


    <% if (_isAdminOp && !isDegraded) { %>

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
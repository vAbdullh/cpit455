<%@ page import="java.sql.*, java.util.*, java.security.MessageDigest, java.nio.charset.StandardCharsets" %>
<%@ include file="_secutil.jspf" %>

<%!
    public String calculateChecksum(int id, String name, String email, double gpa) {
        try {
            String data =
                "CPIT455_SECRET"
                + id + "|"
                + (name == null ? "" : name) + "|"
                + (email == null ? "" : email) + "|"
                + gpa;

            MessageDigest digest =
                MessageDigest.getInstance("SHA-256");

            byte[] hash =
                digest.digest(data.getBytes(StandardCharsets.UTF_8));

            StringBuilder hexString =
                new StringBuilder(2 * hash.length);

            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);

                if (hex.length() == 1) {
                    hexString.append('0');
                }

                hexString.append(hex);
            }

            return hexString.toString();

        } catch (Exception e) {
            return null;
        }
    }
%>

<%
    /*
     * Only authorised safety users can access this page.
     */
    if (!_isSafety) {
        secAudit(
            application,
            _secUser,
            request.getRemoteAddr(),
            "AUTHZ_DENY",
            "action=integrity"
        );

        response.sendError(403, "Not authorised");
        return;
    }

    Class.forName("com.mysql.cj.jdbc.Driver");

    String dbUrl =
        "jdbc:mysql://localhost:3306/universitydb"
        + "?useSSL=false"
        + "&allowPublicKeyRetrieval=true"
        + "&serverTimezone=UTC";

    String user = "root";
    String password = "root123";

    String actionParam = request.getParameter("action");

    if (actionParam == null) {
        actionParam = "verify";
    }

    int recordsChecked = 0;
    int corruptedRecords = 0;
    int updatedRecords = 0;

    List<Map<String, String>> results =
        new ArrayList<Map<String, String>>();

    Connection conn = null;

    try {

        conn = DriverManager.getConnection(
            dbUrl,
            user,
            password
        );

        /*
         * Check whether the checksum column exists.
         */
        boolean hasChecksum = false;

        ResultSet columnRs = null;

        try {
            columnRs = conn.getMetaData().getColumns(
                null,
                null,
                "student",
                "checksum"
            );

            if (columnRs.next()) {
                hasChecksum = true;
            }

        } finally {
            if (columnRs != null) {
                columnRs.close();
            }
        }

        /*
         * Create checksum column if necessary.
         */
        if (!hasChecksum) {

            Statement stmt = null;

            try {
                stmt = conn.createStatement();

                stmt.executeUpdate(
                    "ALTER TABLE student "
                    + "ADD COLUMN checksum VARCHAR(64) DEFAULT NULL"
                );

            } finally {
                if (stmt != null) {
                    stmt.close();
                }
            }
        }

        /*
         * Recompute all checksums.
         */
        if ("recompute".equals(actionParam)) {

            String selectSql =
                "SELECT student_id, name, email, gpa FROM student";

            String updateSql =
                "UPDATE student "
                + "SET checksum = ? "
                + "WHERE student_id = ?";

            Statement stmt = null;
            ResultSet rs = null;
            PreparedStatement pstmt = null;

            try {

                stmt = conn.createStatement();
                rs = stmt.executeQuery(selectSql);

                pstmt = conn.prepareStatement(updateSql);

                while (rs.next()) {

                    int id =
                        rs.getInt("student_id");

                    String name =
                        rs.getString("name");

                    String email =
                        rs.getString("email");

                    double gpa =
                        rs.getDouble("gpa");

                    String checksum =
                        calculateChecksum(
                            id,
                            name,
                            email,
                            gpa
                        );

                    pstmt.setString(
                        1,
                        checksum
                    );

                    pstmt.setInt(
                        2,
                        id
                    );

                    pstmt.addBatch();

                    updatedRecords++;
                }

                pstmt.executeBatch();

            } finally {

                if (rs != null) {
                    rs.close();
                }

                if (stmt != null) {
                    stmt.close();
                }

                if (pstmt != null) {
                    pstmt.close();
                }
            }

            conn.commit();

            secAudit(
                application,
                _secUser,
                request.getRemoteAddr(),
                "INTEGRITY_RECOMPUTE",
                "Recomputed checksums for "
                + updatedRecords
                + " records"
            );

        } else {

            /*
             * Verify all records.
             */
            String sql =
                "SELECT student_id, name, email, gpa, checksum "
                + "FROM student";

            Statement stmt = null;
            ResultSet rs = null;

            try {

                stmt = conn.createStatement();

                rs = stmt.executeQuery(sql);

                while (rs.next()) {

                    int id =
                        rs.getInt("student_id");

                    String name =
                        rs.getString("name");

                    String email =
                        rs.getString("email");

                    double gpa =
                        rs.getDouble("gpa");

                    String stored =
                        rs.getString("checksum");

                    String expected =
                        calculateChecksum(
                            id,
                            name,
                            email,
                            gpa
                        );

                    boolean ok =
                        expected != null
                        && expected.equals(stored);

                    recordsChecked++;

                    if (!ok) {
                        corruptedRecords++;
                    }

                    Map<String, String> row =
                        new HashMap<String, String>();

                    row.put(
                        "id",
                        String.valueOf(id)
                    );

                    row.put(
                        "name",
                        name
                    );

                    if (stored == null) {
                        row.put(
                            "stored",
                            "NULL"
                        );
                    } else if (stored.length() > 16) {
                        row.put(
                            "stored",
                            stored.substring(0, 16) + "..."
                        );
                    } else {
                        row.put(
                            "stored",
                            stored
                        );
                    }

                    if (expected == null) {
                        row.put(
                            "expected",
                            "NULL"
                        );
                    } else if (expected.length() > 16) {
                        row.put(
                            "expected",
                            expected.substring(0, 16) + "..."
                        );
                    } else {
                        row.put(
                            "expected",
                            expected
                        );
                    }

                    row.put(
                        "status",
                        ok ? "OK" : "CORRUPTED"
                    );

                    results.add(row);
                }

            } finally {

                if (rs != null) {
                    rs.close();
                }

                if (stmt != null) {
                    stmt.close();
                }
            }

            secAudit(
                application,
                _secUser,
                request.getRemoteAddr(),
                "INTEGRITY_CHECK",
                "Checked="
                + recordsChecked
                + " corrupted="
                + corruptedRecords
            );
        }

    } catch (Exception e) {

        secAudit(
            application,
            _secUser,
            request.getRemoteAddr(),
            "INTERNAL_ERROR",
            "integrity"
        );

    } finally {

        if (conn != null) {
            try {
                conn.close();
            } catch (Exception e) {
                // Ignore close error
            }
        }
    }
%>

<!DOCTYPE html>

<html>

<head>

    <title>Database Integrity Checker</title>

    <style>

        body {
            font-family: Arial, sans-serif;
            margin: 20px;
        }

        table {
            border-collapse: collapse;
            width: 80%;
            margin-top: 20px;
        }

        th,
        td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }

        th {
            background-color: #ddd;
        }

        .btn {
            padding: 8px 16px;
            margin: 10px 5px 10px 0;
            text-decoration: none;
            display: inline-block;
            background-color: #f0f0f0;
            border: 1px solid #ccc;
            color: black;
            cursor: pointer;
        }

        .green {
            color: green;
            font-weight: bold;
        }

        .red {
            color: red;
            font-weight: bold;
        }

        .banner-success {
            background-color: #d4edda;
            color: #155724;
            padding: 15px;
            margin-bottom: 20px;
            border: 1px solid #c3e6cb;
            border-radius: 4px;
            width: 80%;
            box-sizing: border-box;
        }

        .banner-error {
            background-color: #f8d7da;
            color: #721c24;
            padding: 15px;
            margin-bottom: 20px;
            border: 1px solid #f5c6cb;
            border-radius: 4px;
            width: 80%;
            box-sizing: border-box;
        }

    </style>

</head>

<body>

    <h2>Database Integrity Checker</h2>

    <form method="get" action="integrity.jsp">

        <button
            type="submit"
            name="action"
            value="verify"
            class="btn">
            Verify Integrity
        </button>

        <button
            type="submit"
            name="action"
            value="recompute"
            class="btn">
            Recompute All Checksums
        </button>

        <a
            href="monitor.jsp"
            class="btn">
            Back to Monitor
        </a>

    </form>

    <% if ("recompute".equals(actionParam)) { %>

        <div class="banner-success">

            Successfully recomputed and stored checksums for
            <%= updatedRecords %> records.

        </div>

    <% } else { %>

        <% if (corruptedRecords > 0) { %>

            <div class="banner-error">

                WARNING: Integrity check failed!
                <%= corruptedRecords %>
                out of
                <%= recordsChecked %>
                records are corrupted.

            </div>

        <% } else if (recordsChecked > 0) { %>

            <div class="banner-success">

                SUCCESS: All
                <%= recordsChecked %>
                records passed integrity verification.

            </div>

        <% } %>


        <table>

            <tr>

                <th>Student ID</th>
                <th>Name</th>
                <th>Stored Checksum</th>
                <th>Expected Checksum</th>
                <th>Status</th>

            </tr>

            <% for (Map<String, String> row : results) { %>

                <tr>

                    <td>
                        <%= esc(row.get("id")) %>
                    </td>

                    <td>
                        <%= esc(row.get("name")) %>
                    </td>

                    <td>
                        <tt>
                            <%= esc(row.get("stored")) %>
                        </tt>
                    </td>

                    <td>
                        <tt>
                            <%= esc(row.get("expected")) %>
                        </tt>
                    </td>

                    <td class="<%= "OK".equals(row.get("status"))
                        ? "green"
                        : "red" %>">

                        <%= esc(row.get("status")) %>

                    </td>

                </tr>

            <% } %>

        </table>

    <% } %>

</body>

</html>
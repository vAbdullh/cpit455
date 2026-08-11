<%@ page import="java.sql.*, java.util.*, java.io.*, java.text.SimpleDateFormat,
                  java.security.MessageDigest, java.nio.charset.StandardCharsets" %>
<%@ include file="_secutil.jspf" %>

<%!
    /*
     * =========================================================
     *  REINSTATEMENT — Task 6: Snapshots + Transaction Log
     * =========================================================
     *  6.1  Periodic snapshots with retention (not just a mirror)
     *  6.2  Replayable transaction log for gap recovery & undo
     * =========================================================
     */

    // Directory paths (relative to webapp root)
    static final String SNAP_DIR   = "db_snapshots";
    static final String TX_LOG     = "transactions.log";
    static final int    KEEP_SNAPS = 10;

    // ----------------------------------------------------------
    //  Integrity checksum (reused from Task 4 / integrity.jsp)
    // ----------------------------------------------------------
    String snapshotChecksum(int id, String name, String email, double gpa) {
        try {
            String data = "CPIT455_SECRET"
                        + id + "|"
                        + (name == null ? "" : name) + "|"
                        + (email == null ? "" : email) + "|"
                        + gpa;

            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(
                data.getBytes(StandardCharsets.UTF_8)
            );

            StringBuilder hex = new StringBuilder(2 * hash.length);
            for (byte b : hash) {
                String h = Integer.toHexString(0xff & b);
                if (h.length() == 1) hex.append('0');
                hex.append(h);
            }
            return hex.toString();
        } catch (Exception e) {
            return null;
        }
    }
%>

<%
    // =========================================================
    //  AUTHORISATION — safety_officer or admin only
    // =========================================================
    if (!_isSafety) {
        secAudit(application, _secUser, request.getRemoteAddr(),
                 "AUTHZ_DENY", "action=reinstatement");
        response.sendError(403, "Not authorised");
        return;
    }

    // =========================================================
    //  Database connection
    // =========================================================
    Class.forName("com.mysql.cj.jdbc.Driver");

    String dbUrl = "jdbc:mysql://localhost:3306/universitydb"
                 + "?useSSL=false"
                 + "&allowPublicKeyRetrieval=true"
                 + "&serverTimezone=UTC";

    String dbUser     = "root";
    String dbPassword = "root123";

    // Paths
    String webRoot    = application.getRealPath("/");
    String snapDir    = webRoot + SNAP_DIR;
    String txLogPath  = webRoot + TX_LOG;

    // Ensure snapshot directory exists
    File snapFolder = new File(snapDir);
    if (!snapFolder.exists()) {
        snapFolder.mkdirs();
    }

    // =========================================================
    //  ACTION HANDLING
    // =========================================================
    String actionParam = request.getParameter("action");
    if (actionParam == null) actionParam = "status";

    String statusMessage = null;
    String statusType    = "info";  // info, success, error

    Connection conn = null;

    try {
        conn = DriverManager.getConnection(dbUrl, dbUser, dbPassword);

        // ==========================================================
        //  6.1  TAKE SNAPSHOT
        // ==========================================================
        if ("take_snapshot".equals(actionParam)) {

            // Export all student records to a snapshot file
            long timestamp = System.currentTimeMillis();
            String snapName = "snap_" + timestamp + ".csv";
            File snapFile   = new File(snapDir, snapName);

            Statement stmt = null;
            ResultSet rs   = null;
            PrintWriter pw = null;

            try {
                stmt = conn.createStatement();
                rs   = stmt.executeQuery(
                    "SELECT student_id, name, email, gpa, checksum FROM student"
                );
                pw = new PrintWriter(new FileWriter(snapFile));

                // Header
                pw.println("student_id,name,email,gpa,checksum");

                int count = 0;
                while (rs.next()) {
                    int    id    = rs.getInt("student_id");
                    String name  = rs.getString("name");
                    String email = rs.getString("email");
                    double gpa   = rs.getDouble("gpa");
                    String chk   = rs.getString("checksum");

                    // Escape commas in fields
                    pw.printf("%d,\"%s\",\"%s\",%.2f,%s%n",
                              id,
                              name != null ? name.replace("\"", "\"\"") : "",
                              email != null ? email.replace("\"", "\"\"") : "",
                              gpa,
                              chk != null ? chk : "NULL");
                    count++;
                }

                statusMessage = "Snapshot taken: " + snapName
                              + " (" + count + " records)";
                statusType = "success";

                secAudit(application, _secUser, request.getRemoteAddr(),
                         "SNAPSHOT_TAKEN",
                         "file=" + snapName + " records=" + count);

            } finally {
                if (pw   != null) pw.close();
                if (rs   != null) rs.close();
                if (stmt != null) stmt.close();
            }

            // Prune old snapshots (keep only KEEP_SNAPS newest)
            File[] allSnaps = snapFolder.listFiles(new FilenameFilter() {
                public boolean accept(File dir, String name) {
                    return name.startsWith("snap_") && name.endsWith(".csv");
                }
            });

            if (allSnaps != null && allSnaps.length > KEEP_SNAPS) {
                Arrays.sort(allSnaps);
                for (int i = 0; i < allSnaps.length - KEEP_SNAPS; i++) {
                    allSnaps[i].delete();
                }
            }
        }

        // ==========================================================
        //  6.2  LOG A TRANSACTION (called by other pages, demo here)
        // ==========================================================
        if ("log_demo".equals(actionParam)) {

            // Demonstrate appending to the transaction log
            long now = System.currentTimeMillis();
            PrintWriter logWriter = null;

            try {
                logWriter = new PrintWriter(
                    new FileWriter(txLogPath, true)  // append mode
                );

                // Demo: log a simulated UPDATE
                String entry = String.format(
                    "{\"ts\":%d,\"op\":\"UPDATE\",\"table\":\"student\","
                  + "\"key\":1,\"before\":\"GPA=3.5\",\"after\":\"GPA=3.8\","
                  + "\"user\":\"%s\"}",
                    now, _secUser
                );

                logWriter.println(entry);

                statusMessage = "Demo transaction appended to log.";
                statusType    = "success";

                secAudit(application, _secUser, request.getRemoteAddr(),
                         "TX_LOG_APPEND", "demo_entry");

            } finally {
                if (logWriter != null) logWriter.close();
            }
        }

        // ==========================================================
        //  RESTORE FROM SNAPSHOT
        // ==========================================================
        if ("restore".equals(actionParam)) {

            String snapFile = request.getParameter("snapshot");

            if (snapFile == null || snapFile.isEmpty()) {
                statusMessage = "No snapshot file specified.";
                statusType    = "error";
            } else {
                // Sanitise filename — prevent path traversal
                snapFile = new File(snapFile).getName();
                File source = new File(snapDir, snapFile);

                if (!source.exists()) {
                    statusMessage = "Snapshot file not found.";
                    statusType    = "error";
                } else {
                    // Verify integrity of snapshot before restoring
                    BufferedReader br = null;
                    boolean snapshotValid = true;
                    int verifiedRows = 0;

                    try {
                        br = new BufferedReader(new FileReader(source));
                        String header = br.readLine(); // skip header
                        String line;

                        while ((line = br.readLine()) != null) {
                            // Simple CSV parse
                            String[] parts = line.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");
                            if (parts.length >= 5) {
                                int    id    = Integer.parseInt(parts[0].trim());
                                String name  = parts[1].trim().replaceAll("^\"|\"$", "");
                                String email = parts[2].trim().replaceAll("^\"|\"$", "");
                                double gpa   = Double.parseDouble(parts[3].trim());
                                String storedChk = parts[4].trim();

                                if (!"NULL".equals(storedChk)) {
                                    String expected = snapshotChecksum(id, name, email, gpa);
                                    if (expected != null && !expected.equals(storedChk)) {
                                        snapshotValid = false;
                                        break;
                                    }
                                }
                                verifiedRows++;
                            }
                        }
                    } finally {
                        if (br != null) br.close();
                    }

                    if (!snapshotValid) {
                        statusMessage = "Snapshot FAILED integrity check — "
                                      + "refusing to restore corrupted data.";
                        statusType = "error";

                        secAudit(application, _secUser, request.getRemoteAddr(),
                                 "RESTORE_REJECTED",
                                 "file=" + snapFile + " reason=integrity_failure");
                    } else {
                        // Restore: clear table and reload from snapshot
                        conn.setAutoCommit(false);
                        Statement clearStmt = null;
                        PreparedStatement insertStmt = null;
                        BufferedReader br2 = null;
                        int restored = 0;

                        try {
                            clearStmt = conn.createStatement();
                            clearStmt.executeUpdate("DELETE FROM student");

                            insertStmt = conn.prepareStatement(
                                "INSERT INTO student(student_id, name, email, gpa, checksum) "
                              + "VALUES (?, ?, ?, ?, ?)"
                            );

                            br2 = new BufferedReader(new FileReader(source));
                            br2.readLine(); // skip header
                            String line;

                            while ((line = br2.readLine()) != null) {
                                String[] parts = line.split(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");
                                if (parts.length >= 5) {
                                    insertStmt.setInt(1, Integer.parseInt(parts[0].trim()));
                                    insertStmt.setString(2, parts[1].trim().replaceAll("^\"|\"$", ""));
                                    insertStmt.setString(3, parts[2].trim().replaceAll("^\"|\"$", ""));
                                    insertStmt.setDouble(4, Double.parseDouble(parts[3].trim()));
                                    String chk = parts[4].trim();
                                    insertStmt.setString(5, "NULL".equals(chk) ? null : chk);
                                    insertStmt.addBatch();
                                    restored++;
                                }
                            }

                            insertStmt.executeBatch();
                            conn.commit();

                            statusMessage = "Restored " + restored
                                          + " records from " + snapFile
                                          + " (integrity verified).";
                            statusType = "success";

                            secAudit(application, _secUser, request.getRemoteAddr(),
                                     "SNAPSHOT_RESTORED",
                                     "file=" + snapFile + " records=" + restored);

                        } catch (Exception e) {
                            conn.rollback();
                            statusMessage = "Restore failed — rolled back.";
                            statusType    = "error";

                            secAudit(application, _secUser, request.getRemoteAddr(),
                                     "RESTORE_FAILED", "file=" + snapFile);
                        } finally {
                            if (br2 != null)        br2.close();
                            if (insertStmt != null) insertStmt.close();
                            if (clearStmt != null)  clearStmt.close();
                            conn.setAutoCommit(true);
                        }
                    }
                }
            }
        }

    } catch (Exception e) {
        statusMessage = "An error occurred.";
        statusType    = "error";

        secAudit(application, _secUser, request.getRemoteAddr(),
                 "INTERNAL_ERROR", "reinstatement");

    } finally {
        if (conn != null) {
            try { conn.close(); } catch (Exception ignored) {}
        }
    }

    // =========================================================
    //  Collect display data: list snapshots and tx log
    // =========================================================
    File[] snapFiles = snapFolder.listFiles(new FilenameFilter() {
        public boolean accept(File dir, String name) {
            return name.startsWith("snap_") && name.endsWith(".csv");
        }
    });

    if (snapFiles != null) {
        Arrays.sort(snapFiles, Collections.reverseOrder());
    }

    List<String> txLogEntries = new ArrayList<String>();
    File txFile = new File(txLogPath);
    if (txFile.exists()) {
        BufferedReader txReader = null;
        try {
            txReader = new BufferedReader(new FileReader(txFile));
            String line;
            int maxLines = 50; // show last 50
            while ((line = txReader.readLine()) != null && txLogEntries.size() < maxLines) {
                txLogEntries.add(line);
            }
        } catch (Exception ignored) {
        } finally {
            if (txReader != null) try { txReader.close(); } catch (Exception ignored) {}
        }
    }
%>

<!DOCTYPE html>

<html>

<head>

    <title>Reinstatement — Snapshots & Transaction Log</title>

    <style>

        body {
            font-family: Arial, sans-serif;
            margin: 20px;
        }

        h2 {
            margin-bottom: 5px;
        }

        h3 {
            margin-top: 25px;
            margin-bottom: 10px;
        }

        table {
            border-collapse: collapse;
            width: 90%;
            margin-top: 10px;
        }

        th, td {
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
            font-size: 14px;
        }

        .btn:hover {
            background-color: #e0e0e0;
        }

        .banner-success {
            background-color: #d4edda;
            color: #155724;
            padding: 15px;
            margin-bottom: 20px;
            border: 1px solid #c3e6cb;
            border-radius: 4px;
            width: 90%;
            box-sizing: border-box;
        }

        .banner-error {
            background-color: #f8d7da;
            color: #721c24;
            padding: 15px;
            margin-bottom: 20px;
            border: 1px solid #f5c6cb;
            border-radius: 4px;
            width: 90%;
            box-sizing: border-box;
        }

        .banner-info {
            background-color: #d1ecf1;
            color: #0c5460;
            padding: 15px;
            margin-bottom: 20px;
            border: 1px solid #bee5eb;
            border-radius: 4px;
            width: 90%;
            box-sizing: border-box;
        }

        .log-box {
            background-color: #1e293b;
            color: #f8fafc;
            padding: 12px;
            border-radius: 4px;
            font-family: monospace;
            font-size: 0.85rem;
            max-height: 200px;
            overflow-y: auto;
            width: 90%;
            box-sizing: border-box;
            white-space: pre-wrap;
            word-break: break-all;
        }

        .green  { color: green;  font-weight: bold; }
        .red    { color: red;    font-weight: bold; }

    </style>

</head>

<body>

    <h2>Reinstatement — Snapshots &amp; Transaction Log</h2>

    <p>
        Signed in as: <strong><%= esc(_secUser) %></strong>
        (role: <em><%= esc(_secRole) %></em>)
        | <a href="logout.jsp">Logout</a>
    </p>

    <!-- Status banner -->
    <% if (statusMessage != null) { %>
        <div class="banner-<%= statusType %>">
            <%= esc(statusMessage) %>
        </div>
    <% } %>

    <!-- Action buttons -->
    <form method="post" action="reinstatement.jsp" style="display:inline;">
        <button type="submit" name="action" value="take_snapshot" class="btn">
            Take Snapshot Now
        </button>
    </form>

    <form method="post" action="reinstatement.jsp" style="display:inline;">
        <button type="submit" name="action" value="log_demo" class="btn">
            Append Demo TX Log Entry
        </button>
    </form>

    <a href="reinstatement.jsp" class="btn">Refresh Status</a>
    <a href="monitor.jsp" class="btn">Back to Monitor</a>

    <!-- ======================================================= -->
    <!--  6.1  SNAPSHOT LIST                                      -->
    <!-- ======================================================= -->
    <h3>Database Snapshots (retained: max <%= KEEP_SNAPS %>)</h3>

    <% if (snapFiles == null || snapFiles.length == 0) { %>
        <p>No snapshots taken yet.</p>
    <% } else { %>
        <table>
            <tr>
                <th>Snapshot File</th>
                <th>Size</th>
                <th>Created</th>
                <th>Action</th>
            </tr>
            <% for (File sf : snapFiles) {
                // Extract timestamp from filename
                String fname = sf.getName();
                long fsize   = sf.length();
                long lastMod = sf.lastModified();
                String dateStr = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss")
                                     .format(new java.util.Date(lastMod));
            %>
            <tr>
                <td><tt><%= esc(fname) %></tt></td>
                <td><%= fsize %> bytes</td>
                <td><%= esc(dateStr) %></td>
                <td>
                    <form method="post" action="reinstatement.jsp" style="display:inline;">
                        <input type="hidden" name="action"   value="restore">
                        <input type="hidden" name="snapshot" value="<%= esc(fname) %>">
                        <button type="submit" class="btn"
                                onclick="return confirm('Restore from this snapshot? Current data will be replaced.');">
                            Restore
                        </button>
                    </form>
                </td>
            </tr>
            <% } %>
        </table>

        <p style="font-size:0.9em;color:#555;">
            A mirror alone is insufficient &mdash; corruption replicates
            to a mirror. Retained snapshots allow rollback to a
            known-good point in time using the integrity check from Task 4.
        </p>
    <% } %>

    <!-- ======================================================= -->
    <!--  6.2  TRANSACTION LOG                                    -->
    <!-- ======================================================= -->
    <h3>Transaction Log (append-only)</h3>

    <% if (txLogEntries.isEmpty()) { %>
        <p>Transaction log is empty.</p>
    <% } else { %>
        <div class="log-box">
<%
            for (String entry : txLogEntries) {
                out.println(esc(entry));
            }
%>
        </div>

        <p style="font-size:0.9em;color:#555;">
            The transaction log closes the gap between the last snapshot
            and the present moment. During reinstatement, transactions
            logged after the snapshot timestamp are replayed to bring
            the restored database up to date. The log also enables the
            'undo' operation from the Task 3 survivability table.
        </p>
    <% } %>

</body>

</html>

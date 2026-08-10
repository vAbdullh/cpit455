<%
    // SECGUIDE-3: invalidate session completely on logout
    String user = (String) session.getAttribute("username");
    session.invalidate();

    // SECGUIDE-5: audit the logout event
    java.io.File logFile = new java.io.File(
        application.getRealPath("/") + "security_audit.log");
    java.io.PrintWriter pw = null;
    try {
        pw = new java.io.PrintWriter(new java.io.FileWriter(logFile, true));
        String ts = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'")
                        .format(new java.util.Date());
        pw.printf("%s  user=%s  ip=%s  action=LOGOUT  %n",
                  ts, (user != null ? user : "unknown"), request.getRemoteAddr());
    } catch (Exception ignored) {
    } finally {
        if (pw != null) pw.close();
    }

    response.sendRedirect("login.jsp");
%>

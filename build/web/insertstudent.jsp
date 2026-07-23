<%@ page import="java.sql.*" %>

<!DOCTYPE html>
<html>
<head>
    <title>View Students</title>

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


<form method="GET" action="viewstudents.jsp">

    Search Name:
    <input type="text" name="search">

    <input type="submit" value="Search">

</form>

<br>


<table>

<tr>
    <th>ID</th>
    <th>Name</th>
    <th>Email</th>
    <th>GPA</th>
    <th>Action</th>
</tr>


<%

String search = request.getParameter("search");

String url = "jdbc:mysql://localhost:3306/universitydb?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
String user = "root";
String password = "root123";


try {

    Class.forName("com.mysql.cj.jdbc.Driver");

    Connection conn = DriverManager.getConnection(url,user,password);


    String sql;

    PreparedStatement ps;


    if(search != null && !search.isEmpty()) {

        sql = "SELECT * FROM student WHERE name LIKE ?";

        ps = conn.prepareStatement(sql);

        ps.setString(1, "%" + search + "%");

    } else {

        sql = "SELECT * FROM student";

        ps = conn.prepareStatement(sql);

    }


    ResultSet rs = ps.executeQuery();


    while(rs.next()) {

        double gpa = rs.getDouble("gpa");

%>


<tr>

<td>
<%= rs.getInt("student_id") %>
</td>


<td>
<%= rs.getString("name") %>
</td>


<td>
<%= rs.getString("email") %>
</td>


<td class="<%= gpa < 3.50 ? "low-gpa" : "" %>">

<%= gpa %>

</td>


<td>

<a href="deletestudent.jsp?id=<%=rs.getInt("student_id")%>"
   onclick="return confirm('Delete this student?');">

Delete

</a>

</td>


</tr>


<%

    }


    rs.close();
    ps.close();
    conn.close();


} catch(Exception e) {

    out.println("<h3>Error: "+e.getMessage()+"</h3>");

}

%>


</table>


<br>

<a href="addstudent.jsp">
Add New Student
</a>


</body>
</html>
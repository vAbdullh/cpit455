<!DOCTYPE html>
<html>
    <head>
        <title>Add Student</title>
    </head>

    <body>

        <h2>Add New Student</h2>

        <form action="insertstudent.jsp" method="POST">

            Name:
            <input type="text" name="name" required>
            <br><br>

            Email:
            <input type="email" name="email" required>
            <br><br>

            GPA:
            <input type="number" step="0.01" name="gpa" required>
            <br><br>

            <input type="submit" value="Add Student">

        </form>

    </body>
</html>
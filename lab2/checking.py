import requests

# Base URL for the JSP web app
BASE_URL = "http://localhost:8080/StudentWebApp/"

# Test 1: delete with non-numeric id
print("--- Test 1: Delete with non-numeric ID ---")
r = requests.get(f"{BASE_URL}/deletestudent.jsp", params={"id": "abc"})
print("Status:", r.status_code)
print(r.text.strip())
print()

# Test 2: delete with empty id
print("--- Test 2: Delete with empty ID ---")
r = requests.get(f"{BASE_URL}/deletestudent.jsp", params={"id": ""})
print("Status:", r.status_code)
print(r.text.strip())
print()

# Test 3: delete with negative id
print("--- Test 3: Delete with negative ID ---")
r = requests.get(f"{BASE_URL}/deletestudent.jsp", params={"id": "-5"})
print("Status:", r.status_code)
print(r.text.strip())
print()

# Test 4: add student with invalid GPA
print("--- Test 4: Add student with invalid GPA ---")
r = requests.post(f"{BASE_URL}/insertstudent.jsp", data={
    "name": "Test Student",
    "email": "test@example.com",
    "gpa": "9.9"
})
print("Status:", r.status_code)
print(r.text.strip())
print()

# Test 5: add student with invalid email
print("--- Test 5: Add student with invalid email ---")
r = requests.post(f"{BASE_URL}/insertstudent.jsp", data={
    "name": "Test Student",
    "email": "notanemail",
    "gpa": "3.5"
})
print("Status:", r.status_code)
print(r.text.strip())
print()

# Test 6: valid add student (should succeed)
print("--- Test 6: Valid add student ---")
r = requests.post(f"{BASE_URL}/insertstudent.jsp", data={
    "name": "Sara Ahmed",
    "email": "sara@kau.edu.sa",
    "gpa": "3.5"
})
print("Status:", r.status_code)
print(r.text.strip())
print()
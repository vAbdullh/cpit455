import requests

BASE_URL = "http://localhost:8080/StudentWebApp/"


print("--- Test 1: Failed transaction rollback ---")

r = requests.post(
    f"{BASE_URL}/insertstudent.jsp",
    data={
        "name": "Rollback Test",
        "email": "rollback@test.com",
        "gpa": "3.5",
        "fail": "true"
    }
)

print("Status:", r.status_code)
print(r.text.strip())
print()



print("--- Test 2: Valid transaction ---")

r = requests.post(
    f"{BASE_URL}/insertstudent.jsp",
    data={
        "name": "Normal Student",
        "email": "normal@test.com",
        "gpa": "3.5"
    }
)

print("Status:", r.status_code)
print(r.text.strip())
print()
import requests
import json

BASE_URL = 'http://127.0.0.1:5000/api'

def test_api():
    # 1. Login
    login_data = {'username': 'testuser', 'password': 'password'}
    # Try logging in, if fail, register first
    try:
        resp = requests.post(f'{BASE_URL}/auth/login', json=login_data)
        if resp.status_code != 200:
            print("Login failed, trying to register...")
            requests.post(f'{BASE_URL}/auth/register', json={
                'username': 'testuser',
                'password': 'password',
                'email': 'test@example.com',
                'student_id': '123456'
            })
            resp = requests.post(f'{BASE_URL}/auth/login', json=login_data)
    except Exception as e:
        print(f"Connection failed: {e}")
        return

    if resp.status_code != 200:
        print(f"Login failed: {resp.text}")
        return

    token = resp.json().get('access_token')
    headers = {'Authorization': f'Bearer {token}'}

    # 2. Get Tasks (Assuming project_id=1 exists, or we need to find one)
    # Let's list teams first to find a project
    teams_resp = requests.get(f'{BASE_URL}/teams', headers=headers)
    if teams_resp.status_code != 200:
        print("Failed to get teams")
        return
    
    teams = teams_resp.json()
    project_id = None
    if teams:
        team_id = teams[0]['id']
        # Get team details to find projects
        team_detail = requests.get(f'{BASE_URL}/teams/{team_id}', headers=headers).json()
        if team_detail.get('projects'):
            project_id = team_detail['projects'][0]['id']
    
    if not project_id:
        print("No project found to test")
        return

    print(f"Testing with Project ID: {project_id}")
    
    # 3. Get Tasks
    tasks_resp = requests.get(f'{BASE_URL}/tasks?project_id={project_id}&fetch_all=true', headers=headers)
    print("Tasks Response Code:", tasks_resp.status_code)
    tasks = tasks_resp.json()
    print("Tasks Count:", len(tasks))
    if len(tasks) > 0:
        print("First Task Sample:", json.dumps(tasks[0], indent=2, ensure_ascii=False))

if __name__ == '__main__':
    test_api()

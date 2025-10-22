from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)

# In-memory database for employees
employees = [
    {"id": 1, "name": "John Doe", "position": "Software Engineer", "department": "IT", "salary": 75000, "email": "john@company.com"},
    {"id": 2, "name": "Jane Smith", "position": "HR Manager", "department": "HR", "salary": 65000, "email": "jane@company.com"},
    {"id": 3, "name": "Bob Johnson", "position": "DevOps Engineer", "department": "IT", "salary": 80000, "email": "bob@company.com"},
    {"id": 4, "name": "Alice Williams", "position": "Product Manager", "department": "Product", "salary": 90000, "email": "alice@company.com"},
]

next_id = 5

@app.route('/')
def index():
    """Root endpoint - API info"""
    return jsonify({
        "service": "Employee Management API",
        "version": "1.0",
        "timestamp": datetime.now().isoformat(),
        "endpoints": {
            "health": "GET /health",
            "list_employees": "GET /api/employees",
            "get_employee": "GET /api/employees/<id>",
            "create_employee": "POST /api/employees",
            "update_employee": "PUT /api/employees/<id>",
            "delete_employee": "DELETE /api/employees/<id>"
        }
    })

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "service": "Employee Management System",
        "timestamp": datetime.now().isoformat()
    })

@app.route('/api/employees', methods=['GET'])
def get_employees():
    return jsonify(employees)

@app.route('/api/employees/<int:emp_id>', methods=['GET'])
def get_employee(emp_id):
    employee = next((emp for emp in employees if emp['id'] == emp_id), None)
    if employee:
        return jsonify(employee)
    return jsonify({"error": "Employee not found"}), 404

@app.route('/api/employees', methods=['POST'])
def add_employee():
    global next_id
    data = request.get_json()
    
    new_employee = {
        "id": next_id,
        "name": data.get('name'),
        "position": data.get('position'),
        "department": data.get('department'),
        "salary": data.get('salary'),
        "email": data.get('email')
    }
    
    employees.append(new_employee)
    next_id += 1
    
    return jsonify(new_employee), 201

@app.route('/api/employees/<int:emp_id>', methods=['PUT'])
def update_employee(emp_id):
    employee = next((emp for emp in employees if emp['id'] == emp_id), None)
    if not employee:
        return jsonify({"error": "Employee not found"}), 404
    
    data = request.get_json()
    employee.update({
        "name": data.get('name', employee['name']),
        "position": data.get('position', employee['position']),
        "department": data.get('department', employee['department']),
        "salary": data.get('salary', employee['salary']),
        "email": data.get('email', employee['email'])
    })
    
    return jsonify(employee)

@app.route('/api/employees/<int:emp_id>', methods=['DELETE'])
def delete_employee(emp_id):
    global employees
    employee = next((emp for emp in employees if emp['id'] == emp_id), None)
    if not employee:
        return jsonify({"error": "Employee not found"}), 404
    
    employees = [emp for emp in employees if emp['id'] != emp_id]
    return jsonify({"message": "Employee deleted successfully"})

if __name__ == '__main__':
    print("=" * 50)
    print("Employee Management System Server")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=True)

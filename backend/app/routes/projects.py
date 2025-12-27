from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import Project, TeamMember
from app import db
from datetime import datetime

bp = Blueprint('projects', __name__)

@bp.route('', methods=['GET'])
@jwt_required()
def get_projects():
    current_user_id = get_jwt_identity()
    team_id = request.args.get('team_id')
    
    if not team_id:
        return jsonify({'message': 'Team ID required'}), 400
        
    # Check if user is member of team
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    projects = Project.query.filter_by(team_id=team_id).all()
    
    result = []
    for project in projects:
        result.append({
            'id': project.id,
            'name': project.name,
            'description': project.description,
            'status': project.status,
            'start_date': project.start_date.isoformat() if project.start_date else None,
            'end_date': project.end_date.isoformat() if project.end_date else None,
            'created_by': project.created_by,
            'created_at': project.created_at
        })
    return jsonify(result), 200

@bp.route('', methods=['POST'])
@jwt_required()
def create_project():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    team_id = data.get('team_id')
    name = data.get('name')
    description = data.get('description')
    start_date = data.get('start_date')
    end_date = data.get('end_date')
    
    if not team_id or not name:
        return jsonify({'message': 'Team ID and Name required'}), 400
        
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    project = Project(
        team_id=team_id,
        name=name,
        description=description,
        created_by=current_user_id
    )
    
    if start_date:
        project.start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
    if end_date:
        project.end_date = datetime.strptime(end_date, '%Y-%m-%d').date()
        
    db.session.add(project)
    db.session.commit()
    
    return jsonify({'message': 'Project created successfully', 'id': project.id}), 201

@bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_project(id):
    current_user_id = get_jwt_identity()
    project = Project.query.get_or_404(id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    return jsonify({
        'id': project.id,
        'team_id': project.team_id,
        'name': project.name,
        'description': project.description,
        'status': project.status,
        'start_date': project.start_date.isoformat() if project.start_date else None,
        'end_date': project.end_date.isoformat() if project.end_date else None,
        'created_by': project.created_by,
        'created_at': project.created_at
    }), 200

@bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_project(id):
    current_user_id = get_jwt_identity()
    project = Project.query.get_or_404(id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    data = request.get_json()
    project.name = data.get('name', project.name)
    project.description = data.get('description', project.description)
    project.status = data.get('status', project.status)
    
    if 'start_date' in data:
        project.start_date = datetime.strptime(data['start_date'], '%Y-%m-%d').date() if data['start_date'] else None
    if 'end_date' in data:
        project.end_date = datetime.strptime(data['end_date'], '%Y-%m-%d').date() if data['end_date'] else None
        
    db.session.commit()
    return jsonify({'message': 'Project updated successfully'}), 200

@bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_project(id):
    current_user_id = get_jwt_identity()
    project = Project.query.get_or_404(id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    # Check if user is creator or team admin (if we had admins)
    # Flat structure: "管理项目: 所有成员". But deleting? 
    # Design doc: "删除项目" is listed in "项目管理模块" -> "项目归档/删除".
    # Assume any member can delete for now or just creator. Let's stick to any member for flat structure unless specified.
    
    db.session.delete(project)
    db.session.commit()
    
    return jsonify({'message': 'Project deleted successfully'}), 200

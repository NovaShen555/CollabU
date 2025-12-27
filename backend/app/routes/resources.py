from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import TeamResource, TeamMember, Team
from app import db

bp = Blueprint('resources', __name__)

@bp.route('', methods=['GET'])
@jwt_required()
def get_resources():
    current_user_id = get_jwt_identity()
    team_id = request.args.get('team_id')
    
    if not team_id:
        return jsonify({'message': 'Team ID required'}), 400
        
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    resources = TeamResource.query.filter_by(team_id=team_id).order_by(TeamResource.created_at.desc()).all()
    
    result = []
    for r in resources:
        result.append({
            'id': r.id,
            'title': r.title,
            'content': r.content,
            'created_at': r.created_at.isoformat(),
            'updated_at': r.updated_at.isoformat()
        })
    return jsonify(result), 200

@bp.route('', methods=['POST'])
@jwt_required()
def create_resource():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    team_id = data.get('team_id')
    title = data.get('title')
    content = data.get('content')
    
    if not team_id or not title:
        return jsonify({'message': 'Team ID and Title required'}), 400
        
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    resource = TeamResource(
        team_id=team_id,
        user_id=current_user_id,
        title=title,
        content=content
    )
    db.session.add(resource)
    db.session.commit()
    
    return jsonify({'id': resource.id, 'message': 'Resource created successfully'}), 201

@bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_resource(id):
    current_user_id = get_jwt_identity()
    resource = TeamResource.query.get_or_404(id)
    
    if not TeamMember.query.filter_by(team_id=resource.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    return jsonify({
        'id': resource.id,
        'team_id': resource.team_id,
        'title': resource.title,
        'content': resource.content,
        'created_at': resource.created_at.isoformat(),
        'updated_at': resource.updated_at.isoformat()
    }), 200

@bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_resource(id):
    current_user_id = get_jwt_identity()
    resource = TeamResource.query.get_or_404(id)
    
    if not TeamMember.query.filter_by(team_id=resource.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    # Optional: Check if user is creator? Or allow any member to edit?
    # Let's allow any member to edit for "Wiki" style, or creator only?
    # User requirement: "Resource Sharing". Usually creator or admin.
    # Let's stick to creator for now, or maybe admin.
    # Simplified: Creator only or Team Creator.
    
    team = Team.query.get(resource.team_id)
    if resource.user_id != int(current_user_id) and team.creator_id != int(current_user_id):
         return jsonify({'message': 'Only creator can edit'}), 403
    
    data = request.get_json()
    if 'title' in data:
        resource.title = data['title']
    if 'content' in data:
        resource.content = data['content']
        
    db.session.commit()
    return jsonify({'message': 'Resource updated successfully'}), 200

@bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_resource(id):
    current_user_id = get_jwt_identity()
    resource = TeamResource.query.get_or_404(id)
    
    team = Team.query.get(resource.team_id)
    if resource.user_id != int(current_user_id) and team.creator_id != int(current_user_id):
         return jsonify({'message': 'Only creator can delete'}), 403
         
    db.session.delete(resource)
    db.session.commit()
    
    return jsonify({'message': 'Resource deleted successfully'}), 200

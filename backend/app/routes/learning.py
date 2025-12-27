from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import LearningProgress, TeamMember, User
from app import db
from datetime import datetime

bp = Blueprint('learning', __name__)

@bp.route('/team/<int:team_id>', methods=['GET'])
@jwt_required()
def get_team_learning_progress(team_id):
    current_user_id = int(get_jwt_identity())
    
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    # Get all progress entries for this team
    # Maybe we want the latest progress for each user?
    # Or just a list of all updates?
    # "所有组员可以描述学习进度与查看他人的学习进度" -> implying a list or latest status.
    # Let's return all entries ordered by date desc, so frontend can display a feed or filter.
    
    progress_list = LearningProgress.query.filter_by(team_id=team_id).order_by(LearningProgress.created_at.desc()).all()
    
    result = []
    for p in progress_list:
        result.append({
            'id': p.id,
            'user_id': p.user_id,
            'user_name': p.user.username if p.user else 'Unknown',
            'user_avatar': p.user.avatar if p.user else None,
            'content': p.content,
            'progress': p.progress,
            'created_at': p.created_at.isoformat()
        })
        
    return jsonify(result), 200

@bp.route('', methods=['POST'])
@jwt_required()
def update_learning_progress():
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    
    team_id = data.get('team_id')
    content = data.get('content')
    progress = data.get('progress', 0)
    
    if not team_id or not content:
        return jsonify({'message': 'Team ID and Content are required'}), 400
        
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    # Create new entry (log style)
    entry = LearningProgress(
        team_id=team_id,
        user_id=current_user_id,
        content=content,
        progress=progress
    )
    
    db.session.add(entry)
    db.session.commit()
    
    return jsonify({
        'id': entry.id,
        'message': 'Learning progress updated successfully',
        'created_at': entry.created_at.isoformat()
    }), 201

@bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_learning_entry(id):
    current_user_id = int(get_jwt_identity())
    entry = LearningProgress.query.get_or_404(id)
    
    if entry.user_id != current_user_id:
        return jsonify({'message': 'Permission denied'}), 403
        
    data = request.get_json()
    entry.content = data.get('content', entry.content)
    
    db.session.commit()
    return jsonify({'message': 'Updated successfully'})

@bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_learning_entry(id):
    current_user_id = int(get_jwt_identity())
    entry = LearningProgress.query.get_or_404(id)
    
    if entry.user_id != current_user_id:
        return jsonify({'message': 'Permission denied'}), 403
        
    db.session.delete(entry)
    db.session.commit()
    return jsonify({'message': 'Deleted successfully'})

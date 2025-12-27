from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import TimelineEvent, TeamMember, File
from app import db
from datetime import datetime

bp = Blueprint('timeline', __name__)

@bp.route('/team/<int:team_id>', methods=['GET'])
@jwt_required()
def get_team_timeline(team_id):
    current_user_id = int(get_jwt_identity())
    
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    events = TimelineEvent.query.filter_by(team_id=team_id).order_by(TimelineEvent.event_date.desc()).all()
    
    result = []
    for event in events:
        files = []
        for f in event.files:
            files.append({
                'id': f.id,
                'uid': f.uid,
                'filename': f.filename,
                'url': f'/api/files/{f.uid}'
            })
            
        result.append({
            'id': event.id,
            'title': event.title,
            'description': event.description,
            'event_date': event.event_date.isoformat() if event.event_date else None,
            'created_at': event.created_at.isoformat(),
            'created_by': event.created_by,
            'creator_name': event.creator.username if event.creator else 'Unknown',
            'creator_avatar': event.creator.avatar if event.creator else None,
            'files': files
        })
        
    return jsonify(result), 200

@bp.route('', methods=['POST'])
@jwt_required()
def create_timeline_event():
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    
    team_id = data.get('team_id')
    title = data.get('title')
    description = data.get('description')
    event_date_str = data.get('event_date')
    
    if not team_id or not title:
        return jsonify({'message': 'Team ID and Title are required'}), 400
        
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    event_date = datetime.utcnow()
    if event_date_str:
        try:
            # Try parsing ISO format, or date only
            if 'T' in event_date_str:
                event_date = datetime.fromisoformat(event_date_str.replace('Z', '+00:00'))
            else:
                event_date = datetime.strptime(event_date_str, '%Y-%m-%d')
        except ValueError:
            pass # Use current time if parse fails
            
    event = TimelineEvent(
        team_id=team_id,
        created_by=current_user_id,
        title=title,
        description=description,
        event_date=event_date
    )
    
    db.session.add(event)
    db.session.commit()
    
    return jsonify({
        'id': event.id,
        'message': 'Timeline event created successfully'
    }), 201

@bp.route('/<int:event_id>', methods=['PUT'])
@jwt_required()
def update_timeline_event(event_id):
    current_user_id = int(get_jwt_identity())
    event = TimelineEvent.query.get_or_404(event_id)
    
    if not TeamMember.query.filter_by(team_id=event.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    # Check permission
    if event.created_by != current_user_id:
        return jsonify({'message': 'Only creator can edit this event'}), 403
        
    data = request.get_json()
    event.title = data.get('title', event.title)
    event.description = data.get('description', event.description)
    
    event_date_str = data.get('event_date')
    if event_date_str:
        try:
            if 'T' in event_date_str:
                event.event_date = datetime.fromisoformat(event_date_str.replace('Z', '+00:00'))
            else:
                event.event_date = datetime.strptime(event_date_str, '%Y-%m-%d')
        except ValueError:
            pass
            
    db.session.commit()
    return jsonify({'message': 'Timeline event updated successfully'}), 200

@bp.route('/<int:event_id>', methods=['DELETE'])
@jwt_required()
def delete_timeline_event(event_id):
    current_user_id = int(get_jwt_identity())
    event = TimelineEvent.query.get_or_404(event_id)
    
    if not TeamMember.query.filter_by(team_id=event.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    # Check permission (creator or team admin?)
    # For now, let's allow creator.
    if event.created_by != current_user_id:
        return jsonify({'message': 'Only creator can delete this event'}), 403
        
    db.session.delete(event)
    db.session.commit()
    
    return jsonify({'message': 'Event deleted successfully'}), 200

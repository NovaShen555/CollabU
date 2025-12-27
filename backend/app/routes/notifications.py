from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import Notification
from app import db

bp = Blueprint('notifications', __name__)

@bp.route('', methods=['GET'])
@jwt_required()
def get_notifications():
    current_user_id = get_jwt_identity()
    notifications = Notification.query.filter_by(user_id=current_user_id).order_by(Notification.created_at.desc()).all()
    
    result = []
    for notif in notifications:
        result.append({
            'id': notif.id,
            'type': notif.type,
            'content': notif.content,
            'related_id': notif.related_id,
            'is_read': notif.is_read,
            'created_at': notif.created_at.isoformat()
        })
    return jsonify(result), 200

@bp.route('/<int:id>/read', methods=['PUT'])
@jwt_required()
def mark_read(id):
    current_user_id = get_jwt_identity()
    notif = Notification.query.get_or_404(id)
    
    # Ensure current_user_id is int for comparison if needed, 
    # though usually identity from JWT is string, but db id is int.
    # Check type of current_user_id
    try:
        current_user_id = int(current_user_id)
    except ValueError:
        pass # Should be int convertible

    if notif.user_id != current_user_id:
        return jsonify({'message': 'Access denied'}), 403
        
    notif.is_read = True
    db.session.commit()
    
    return jsonify({'message': 'Marked as read'}), 200

@bp.route('/read-all', methods=['PUT'])
@jwt_required()
def mark_all_read():
    current_user_id = get_jwt_identity()
    Notification.query.filter_by(user_id=current_user_id, is_read=False).update({'is_read': True})
    db.session.commit()
    
    return jsonify({'message': 'All marked as read'}), 200

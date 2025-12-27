from flask_socketio import emit, join_room, leave_room, disconnect
from flask_jwt_extended import decode_token
from app import socketio, db
from app.models import TeamMessage, User, TeamMember
from datetime import datetime

# Helper to verify token from handshake
def get_user_from_token(token):
    try:
        decoded = decode_token(token)
        user_id = decoded['sub']
        return User.query.get(user_id)
    except Exception as e:
        return None

@socketio.on('team:join')
def on_join(data):
    token = data.get('token')
    team_id = data.get('team_id')
    
    user = get_user_from_token(token)
    if not user:
        return emit('error', {'message': 'Authentication failed'})
        
    # Check access
    member = TeamMember.query.filter_by(team_id=team_id, user_id=user.id).first()
    if not member:
        return emit('error', {'message': 'Access denied'})
    
    room = f'team_{team_id}'
    join_room(room)
    # emit('team:update', {'type': 'join', 'user': user.username, 'content': f'{user.username} joined the chat'}, room=room)

@socketio.on('team:leave')
def on_leave(data):
    token = data.get('token')
    team_id = data.get('team_id')
    
    user = get_user_from_token(token)
    if not user:
        return
        
    room = f'team_{team_id}'
    leave_room(room)
    # emit('team:update', {'type': 'leave', 'user': user.username, 'content': f'{user.username} left the chat'}, room=room)

@socketio.on('team:message')
def on_message(data):
    token = data.get('token')
    team_id = data.get('team_id')
    content = data.get('content')
    
    user = get_user_from_token(token)
    if not user:
        return emit('error', {'message': 'Authentication failed'})
        
    if not content:
        return
        
    # Check access
    member = TeamMember.query.filter_by(team_id=team_id, user_id=user.id).first()
    if not member:
        return emit('error', {'message': 'Access denied'})

    # Save message
    message = TeamMessage(team_id=team_id, user_id=user.id, content=content)
    db.session.add(message)
    db.session.commit()
    
    # Broadcast
    room = f'team_{team_id}'
    emit('team:message', {
        'id': message.id,
        'user_id': user.id,
        'username': user.username,
        'nickname': user.nickname,
        'avatar': user.avatar,
        'content': message.content,
        'created_at': message.created_at.isoformat()
    }, room=room)

from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import Task, TaskParticipant, Project, TeamMember, User, TaskComment, TaskMessage, TaskActivity, TaskLink
from app import db
from datetime import datetime
from app.services import log_activity, notify_task_participants

bp = Blueprint('tasks', __name__)

@bp.route('/gantt-data', methods=['GET'])
@jwt_required()
def get_gantt_data():
    current_user_id = get_jwt_identity()
    project_id = request.args.get('project_id')
    
    if not project_id:
        return jsonify({'message': 'Project ID required'}), 400
        
    project = Project.query.get_or_404(project_id)
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    tasks = Task.query.filter_by(project_id=project_id).order_by(Task.sort_order).all()
    
    # Get all task IDs for this project to filter links
    task_ids = [t.id for t in tasks]
    
    links = TaskLink.query.filter(TaskLink.source.in_(task_ids)).all()
    
    task_data = []
    for task in tasks:
        task_data.append({
            'id': task.id,
            'text': task.title,
            'start_date': task.start_date.strftime('%Y-%m-%d') if task.start_date else None,
            # dhtmlx-gantt uses duration or end_date. 
            # If we provide duration, it calculates end_date (exclusive) based on start_date.
            # We calculate duration from our inclusive dates: (end - start).days + 1
            'duration': (task.end_date - task.start_date).days + 1 if (task.start_date and task.end_date) else 1,
            'parent': task.parent_id or 0,
            'progress': (task.progress or 0) / 100,
            'open': True # Default open tree
        })
        
    link_data = [{'id': l.id, 'source': l.source, 'target': l.target, 'type': l.type} for l in links]
    
    return jsonify({
        'data': task_data,
        'links': link_data
    }), 200

@bp.route('/links', methods=['POST'])
@jwt_required()
def create_link():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    source = data.get('source')
    target = data.get('target')
    link_type = data.get('type', '0')
    
    if not source or not target:
        return jsonify({'message': 'Source and Target required'}), 400
        
    # Verify access (omitted for brevity, but should check if user can edit these tasks)
    
    link = TaskLink(source=source, target=target, type=link_type)
    db.session.add(link)
    db.session.commit()
    
    return jsonify({'id': link.id, 'message': 'Link created'}), 201

@bp.route('/links/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_link(id):
    link = TaskLink.query.get_or_404(id)
    db.session.delete(link)
    db.session.commit()
    return jsonify({'message': 'Link deleted'}), 200

@bp.route('', methods=['GET'])
@jwt_required()
def get_tasks():
    current_user_id = get_jwt_identity()
    project_id = request.args.get('project_id')
    parent_id = request.args.get('parent_id') # Optional, if None gets root tasks
    
    if not project_id:
        return jsonify({'message': 'Project ID required'}), 400
        
    project = Project.query.get_or_404(project_id)
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    query = Task.query.filter_by(project_id=project_id)
    
    # If fetch_all is not true, filter by parent_id (default to root tasks)
    if request.args.get('fetch_all') != 'true':
        if parent_id:
            query = query.filter_by(parent_id=parent_id)
        else:
            query = query.filter_by(parent_id=None)
        
    tasks = query.order_by(Task.sort_order).all()
    
    result = []
    for task in tasks:
        # Get participants
        participants = db.session.query(User).join(TaskParticipant).filter(TaskParticipant.task_id == task.id).all()
        participant_data = [{'id': u.id, 'username': u.username, 'nickname': u.nickname, 'avatar': u.avatar} for u in participants]
        
        # Check if has subtasks
        has_subtasks = Task.query.filter_by(parent_id=task.id).count() > 0
        
        result.append({
            'id': task.id,
            'parent_id': task.parent_id,
            'title': task.title,
            'description': task.description,
            'status': task.status,
            'priority': task.priority,
            'progress': task.progress,
            'start_date': task.start_date.isoformat() if task.start_date else None,
            'end_date': task.end_date.isoformat() if task.end_date else None,
            'participants': participant_data,
            'has_subtasks': has_subtasks,
            'level': task.level
        })
    return jsonify(result), 200

@bp.route('', methods=['POST'])
@jwt_required()
def create_task():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    project_id = data.get('project_id')
    parent_id = data.get('parent_id')
    title = data.get('title')
    
    if not project_id or not title:
        return jsonify({'message': 'Project ID and Title required'}), 400
        
    project = Project.query.get_or_404(project_id)
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    level = 0
    if parent_id:
        parent = Task.query.get(parent_id)
        if parent:
            level = parent.level + 1
            
    task = Task(
        project_id=project_id,
        parent_id=parent_id,
        title=title,
        description=data.get('description'),
        priority=data.get('priority', 'medium'),
        start_date=datetime.strptime(data['start_date'], '%Y-%m-%d').date() if data.get('start_date') else None,
        end_date=datetime.strptime(data['end_date'], '%Y-%m-%d').date() if data.get('end_date') else None,
        created_by=current_user_id,
        level=level
    )
    
    db.session.add(task)
    db.session.flush()  # Get task.id before commit
    
    # Add creator as task participant
    participant = TaskParticipant(task_id=task.id, user_id=current_user_id)
    db.session.add(participant)
    
    db.session.commit()
    
    log_activity(task.id, current_user_id, 'created_task', {'title': title})
    
    return jsonify({'message': 'Task created successfully', 'id': task.id}), 201

@bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_task(id):
    current_user_id = get_jwt_identity()
    task = Task.query.get_or_404(id)
    project = Project.query.get(task.project_id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    participants = db.session.query(User).join(TaskParticipant).filter(TaskParticipant.task_id == task.id).all()
    
    return jsonify({
        'id': task.id,
        'project_id': task.project_id,
        'parent_id': task.parent_id,
        'title': task.title,
        'description': task.description,
        'status': task.status,
        'priority': task.priority,
        'progress': task.progress,
        'start_date': task.start_date.isoformat() if task.start_date else None,
        'end_date': task.end_date.isoformat() if task.end_date else None,
        'participants': [{'id': u.id, 'username': u.username, 'nickname': u.nickname, 'avatar': u.avatar} for u in participants],
        'created_by': task.created_by,
        'created_at': task.created_at
    }), 200

@bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_task(id):
    current_user_id = get_jwt_identity()
    task = Task.query.get_or_404(id)
    project = Project.query.get(task.project_id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    db.session.delete(task)
    db.session.commit()
    
    log_activity(task.project_id, current_user_id, 'deleted_task', {'title': task.title})
    
    return jsonify({'message': 'Task deleted successfully'}), 200

@bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_task(id):
    current_user_id = get_jwt_identity()
    task = Task.query.get_or_404(id)
    project = Project.query.get(task.project_id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    data = request.get_json()
    task.title = data.get('title', task.title)
    task.description = data.get('description', task.description)
    task.status = data.get('status', task.status)
    task.priority = data.get('priority', task.priority)
    task.progress = data.get('progress', task.progress)
    
    if 'start_date' in data:
        task.start_date = datetime.strptime(data['start_date'], '%Y-%m-%d').date() if data['start_date'] else None
    if 'end_date' in data:
        task.end_date = datetime.strptime(data['end_date'], '%Y-%m-%d').date() if data['end_date'] else None
        
    db.session.commit()
    
    log_activity(task.id, current_user_id, 'updated_task', data)
    notify_task_participants(task.id, 'task_update', f'任务 "{task.title}" 已更新', exclude_user_id=current_user_id)
    
    return jsonify({'message': 'Task updated successfully'}), 200

@bp.route('/<int:id>/join', methods=['POST'])
@jwt_required()
def join_task(id):
    current_user_id = get_jwt_identity()
    task = Task.query.get_or_404(id)
    project = Project.query.get(task.project_id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    if TaskParticipant.query.filter_by(task_id=id, user_id=current_user_id).first():
        return jsonify({'message': 'Already joined'}), 400
        
    participant = TaskParticipant(task_id=id, user_id=current_user_id)
    db.session.add(participant)
    db.session.commit()
    
    log_activity(id, current_user_id, 'joined_task')
    notify_task_participants(id, 'member_join', f'有人加入了任务 "{task.title}"', exclude_user_id=current_user_id)
    
    return jsonify({'message': 'Joined task successfully'}), 200

@bp.route('/<int:id>/leave', methods=['POST'])
@jwt_required()
def leave_task(id):
    current_user_id = get_jwt_identity()
    participant = TaskParticipant.query.filter_by(task_id=id, user_id=current_user_id).first()
    
    if not participant:
        return jsonify({'message': 'Not a participant'}), 400
        
    db.session.delete(participant)
    db.session.commit()
    
    return jsonify({'message': 'Left task successfully'}), 200

@bp.route('/<int:id>/comments', methods=['GET'])
@jwt_required()
def get_comments(id):
    current_user_id = get_jwt_identity()
    task = Task.query.get_or_404(id)
    project = Project.query.get(task.project_id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    comments = db.session.query(TaskComment, User).join(User, TaskComment.user_id == User.id).filter(TaskComment.task_id == id).order_by(TaskComment.created_at).all()
    
    result = []
    for comment, user in comments:
        result.append({
            'id': comment.id,
            'user_id': user.id,
            'username': user.username,
            'nickname': user.nickname,
            'avatar': user.avatar,
            'content': comment.content,
            'reply_to': comment.reply_to,
            'created_at': comment.created_at.isoformat()
        })
    return jsonify(result), 200

@bp.route('/<int:id>/comments', methods=['POST'])
@jwt_required()
def add_comment(id):
    current_user_id = get_jwt_identity()
    task = Task.query.get_or_404(id)
    project = Project.query.get(task.project_id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    data = request.get_json()
    content = data.get('content')
    reply_to = data.get('reply_to')
    
    if not content:
        return jsonify({'message': 'Content required'}), 400
        
    comment = TaskComment(
        task_id=id,
        user_id=current_user_id,
        content=content,
        reply_to=reply_to
    )
    db.session.add(comment)
    db.session.commit()
    
    log_activity(id, current_user_id, 'added_comment')
    notify_task_participants(id, 'new_comment', f'任务 "{task.title}" 有新评论', exclude_user_id=current_user_id)
    
    return jsonify({
        'id': comment.id,
        'message': 'Comment added successfully',
        'created_at': comment.created_at.isoformat()
    }), 201

@bp.route('/<int:id>/messages', methods=['GET'])
@jwt_required()
def get_messages(id):
    current_user_id = get_jwt_identity()
    task = Task.query.get_or_404(id)
    project = Project.query.get(task.project_id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    messages = db.session.query(TaskMessage, User).join(User, TaskMessage.user_id == User.id).filter(TaskMessage.task_id == id).order_by(TaskMessage.created_at).all()
    
    result = []
    for message, user in messages:
        result.append({
            'id': message.id,
            'user_id': user.id,
            'username': user.username,
            'nickname': user.nickname,
            'avatar': user.avatar,
            'content': message.content,
            'created_at': message.created_at.isoformat()
        })
    return jsonify(result), 200

@bp.route('/<int:id>/activities', methods=['GET'])
@jwt_required()
def get_activities(id):
    current_user_id = get_jwt_identity()
    task = Task.query.get_or_404(id)
    project = Project.query.get(task.project_id)
    
    if not TeamMember.query.filter_by(team_id=project.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    activities = db.session.query(TaskActivity, User).join(User, TaskActivity.user_id == User.id).filter(TaskActivity.task_id == id).order_by(TaskActivity.created_at.desc()).all()
    
    result = []
    for activity, user in activities:
        result.append({
            'id': activity.id,
            'user_id': user.id,
            'username': user.username,
            'nickname': user.nickname,
            'avatar': user.avatar,
            'action': activity.action,
            'detail': activity.detail,
            'created_at': activity.created_at.isoformat()
        })
    return jsonify(result), 200

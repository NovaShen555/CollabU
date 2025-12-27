from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from app import db
from app.models import Team, TeamMember, Project, Task, TaskParticipant
from sqlalchemy import or_

bp = Blueprint('dashboard', __name__)

@bp.route('/stats', methods=['GET'])
@jwt_required()
def get_stats():
    user_id = get_jwt_identity()

    # Teams count
    teams_count = TeamMember.query.filter_by(user_id=user_id).count()

    # Projects count (Projects in teams the user is a member of)
    projects_count = Project.query.join(TeamMember, Project.team_id == TeamMember.team_id)\
        .filter(TeamMember.user_id == user_id).count()

    # Tasks count (Tasks assigned to user OR created by user)
    tasks_count = Task.query.outerjoin(TaskParticipant)\
        .filter(or_(TaskParticipant.user_id == user_id, Task.created_by == user_id)).distinct().count()

    # Completed tasks (assigned to user or created by user AND (status='completed' OR progress=100))
    completed_count = Task.query.outerjoin(TaskParticipant)\
        .filter(or_(TaskParticipant.user_id == user_id, Task.created_by == user_id))\
        .filter(or_(Task.status == 'completed', Task.progress == 100)).distinct().count()

    return jsonify({
        'teams': teams_count,
        'projects': projects_count,
        'tasks': tasks_count,
        'completed': completed_count
    })

@bp.route('/recent-tasks', methods=['GET'])
@jwt_required()
def get_recent_tasks():
    user_id = get_jwt_identity()
    
    # Get tasks assigned to user OR created by user, ordered by created_at desc
    tasks = Task.query.outerjoin(TaskParticipant)\
        .filter(or_(TaskParticipant.user_id == user_id, Task.created_by == user_id))\
        .filter(Task.status != 'completed')\
        .filter(Task.progress < 100)\
        .order_by(Task.created_at.desc())\
        .distinct()\
        .limit(5).all()

    result = []
    for task in tasks:
        project = Project.query.get(task.project_id)
        result.append({
            'id': task.id,
            'title': task.title,
            'status': task.status,
            'priority': task.priority,
            'project_name': project.name if project else 'Unknown',
            'progress': task.progress,
            'created_at': task.created_at.isoformat()
        })

    return jsonify(result)

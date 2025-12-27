from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import Team, TeamMember, User, Project, Task, TeamMessage
from app import db
import uuid

bp = Blueprint('teams', __name__)

@bp.route('', methods=['GET'])
@jwt_required()
def get_teams():
    current_user_id = get_jwt_identity()
    # Get teams where user is a member
    memberships = TeamMember.query.filter_by(user_id=current_user_id).all()
    team_ids = [m.team_id for m in memberships]
    teams = Team.query.filter(Team.id.in_(team_ids)).all()
    
    result = []
    for team in teams:
        result.append({
            'id': team.id,
            'name': team.name,
            'description': team.description,
            'avatar': team.avatar,
            'creator_id': team.creator_id,
            'created_at': team.created_at
        })
    return jsonify(result), 200

@bp.route('', methods=['POST'])
@jwt_required()
def create_team():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    name = data.get('name')
    description = data.get('description')
    
    if not name:
        return jsonify({'message': 'Team name is required'}), 400
        
    # Generate unique invite code
    invite_code = str(uuid.uuid4())[:8]
    
    team = Team(name=name, description=description, creator_id=current_user_id, invite_code=invite_code)
    db.session.add(team)
    db.session.commit()
    
    # Add creator as member
    member = TeamMember(team_id=team.id, user_id=current_user_id, role='creator')
    db.session.add(member)
    db.session.commit()
    
    return jsonify({
        'id': team.id,
        'name': team.name,
        'invite_code': team.invite_code,
        'message': 'Team created successfully'
    }), 201

@bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_team(id):
    current_user_id = get_jwt_identity()
    team = Team.query.get_or_404(id)
    
    # Check if user is member
    if not TeamMember.query.filter_by(team_id=id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    return jsonify({
        'id': team.id,
        'name': team.name,
        'description': team.description,
        'avatar': team.avatar,
        'invite_code': team.invite_code,
        'creator_id': team.creator_id,
        'created_at': team.created_at
    }), 200

@bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_team(id):
    current_user_id = get_jwt_identity()
    team = Team.query.get_or_404(id)
    
    # Only members can update (flat structure), or restrict to creator/admin?
    # Design doc says: "管理项目: 所有成员", "编辑团队信息" implies similar?
    # Design doc for Team Management: "编辑团队信息" -> doesn't explicitly restrict.
    # But usually creating invite code/dissolving is restricted.
    # Let's allow any member for now based on "Flat management" but maybe creator only for critical things.
    # Design Doc 3.2: "编辑团队信息" isn't assigned. But "解散团队" is "创建者".
    # Let's assume any member can edit info for now to follow "Flat".
    
    if not TeamMember.query.filter_by(team_id=id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    data = request.get_json()
    team.name = data.get('name', team.name)
    team.description = data.get('description', team.description)
    team.avatar = data.get('avatar', team.avatar)
    
    db.session.commit()
    return jsonify({'message': 'Team updated successfully'}), 200

@bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_team(id):
    current_user_id = get_jwt_identity()
    team = Team.query.get_or_404(id)
    
    if team.creator_id != current_user_id:
        return jsonify({'message': 'Only creator can dissolve team'}), 403
        
    # Delete members first (cascade usually handles this if configured, but manual for safety)
    TeamMember.query.filter_by(team_id=id).delete()
    db.session.delete(team)
    db.session.commit()
    
    return jsonify({'message': 'Team dissolved successfully'}), 200

@bp.route('/<int:id>/members', methods=['GET'])
@jwt_required()
def get_members(id):
    current_user_id = get_jwt_identity()
    if not TeamMember.query.filter_by(team_id=id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    members = db.session.query(TeamMember, User).join(User, TeamMember.user_id == User.id).filter(TeamMember.team_id == id).all()
    
    result = []
    for tm, user in members:
        result.append({
            'user_id': user.id,
            'username': user.username,
            'nickname': user.nickname,
            'avatar': user.avatar,
            'role': tm.role,
            'joined_at': tm.joined_at
        })
    return jsonify(result), 200

@bp.route('/<int:id>/invite', methods=['POST'])
@jwt_required()
def generate_invite(id):
    current_user_id = get_jwt_identity()
    if not TeamMember.query.filter_by(team_id=id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    team = Team.query.get(id)
    # Regenerate invite code
    team.invite_code = str(uuid.uuid4())[:8]
    db.session.commit()
    
    return jsonify({'invite_code': team.invite_code}), 200

@bp.route('/join', methods=['POST'])
@jwt_required()
def join_team():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    invite_code = data.get('invite_code')
    
    if not invite_code:
        return jsonify({'message': 'Invite code required'}), 400
        
    team = Team.query.filter_by(invite_code=invite_code).first()
    if not team:
        return jsonify({'message': 'Invalid invite code'}), 404
        
    if TeamMember.query.filter_by(team_id=team.id, user_id=current_user_id).first():
        return jsonify({'message': 'Already a member'}), 400
        
    member = TeamMember(team_id=team.id, user_id=current_user_id, role='member')
    db.session.add(member)
    db.session.commit()
    
    return jsonify({'message': 'Joined team successfully', 'team_id': team.id}), 200

@bp.route('/<int:id>/leave', methods=['POST'])
@jwt_required()
def leave_team(id):
    current_user_id = get_jwt_identity()
    member = TeamMember.query.filter_by(team_id=id, user_id=current_user_id).first()
    
    if not member:
        return jsonify({'message': 'Not a member'}), 400
        
    team = Team.query.get(id)
    if team.creator_id == current_user_id:
        # Creator cannot leave, must dissolve or transfer (transfer not implemented yet)
        return jsonify({'message': 'Creator cannot leave team. Dissolve it instead.'}), 400
        
    db.session.delete(member)
    db.session.commit()
    
    return jsonify({'message': 'Left team successfully'}), 200

@bp.route('/<int:id>/messages', methods=['GET'])
@jwt_required()
def get_team_messages(id):
    current_user_id = get_jwt_identity()
    if not TeamMember.query.filter_by(team_id=id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    messages = TeamMessage.query.filter_by(team_id=id).order_by(TeamMessage.created_at.asc()).all()
    
    result = []
    for msg in messages:
        user = msg.user
        result.append({
            'id': msg.id,
            'user_id': msg.user_id,
            'username': user.username,
            'nickname': user.nickname,
            'avatar': user.avatar,
            'content': msg.content,
            'created_at': msg.created_at.isoformat()
        })
    return jsonify(result), 200

@bp.route('/<int:id>/tasks', methods=['GET'])
@jwt_required()
def get_team_tasks(id):
    current_user_id = get_jwt_identity()
    if not TeamMember.query.filter_by(team_id=id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    # Get all projects for this team
    projects = Project.query.filter_by(team_id=id).all()
    project_ids = [p.id for p in projects]
    
    if not project_ids:
        return jsonify([]), 200
        
    # Get all tasks for these projects
    tasks = Task.query.filter(Task.project_id.in_(project_ids)).all()
    
    result = []
    for task in tasks:
        # Only include tasks with start/end dates for calendar
        if task.start_date and task.end_date:
            result.append({
                'id': task.id,
                'title': task.title,
                'project_id': task.project_id,
                'start_date': task.start_date.isoformat(),
                'end_date': task.end_date.isoformat(),
                'status': task.status,
                'priority': task.priority
            })
            
    return jsonify(result), 200


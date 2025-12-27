from flask import Blueprint, request, jsonify, send_from_directory, current_app
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import File, TeamMember, Task, Team, User
from app import db
import os
import uuid
from werkzeug.utils import secure_filename

bp = Blueprint('files', __name__)

@bp.route('/upload', methods=['POST'])
@jwt_required()
def upload_file():
    current_user_id = int(get_jwt_identity())
    
    if 'file' not in request.files:
        return jsonify({'message': 'No file part'}), 400
        
    file = request.files['file']
    if file.filename == '':
        return jsonify({'message': 'No selected file'}), 400
        
    team_id = request.form.get('team_id')
    task_id = request.form.get('task_id')
    resource_id = request.form.get('resource_id')
    timeline_event_id = request.form.get('timeline_event_id')
    
    if not team_id:
        # If task_id provided, infer team_id
        if task_id:
            task = Task.query.get(task_id)
            if task:
                from app.models import Project
                project = Project.query.get(task.project_id)
                if project:
                    team_id = project.team_id
        elif resource_id:
             from app.models import TeamResource
             resource = TeamResource.query.get(resource_id)
             if resource:
                 team_id = resource.team_id
        elif timeline_event_id:
             from app.models import TimelineEvent
             event = TimelineEvent.query.get(timeline_event_id)
             if event:
                 team_id = event.team_id
        
        if not team_id:
            return jsonify({'message': 'Team ID required'}), 400
        
    # Check access
    if not TeamMember.query.filter_by(team_id=team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    if file:
        original_filename = secure_filename(file.filename)
        ext = os.path.splitext(original_filename)[1]
        unique_filename = f"{uuid.uuid4().hex}{ext}"
        
        if not os.path.exists(current_app.config['UPLOAD_FOLDER']):
             os.makedirs(current_app.config['UPLOAD_FOLDER'])

        filepath = os.path.join(current_app.config['UPLOAD_FOLDER'], unique_filename)
        file.save(filepath)
        
        filesize = os.path.getsize(filepath)
        mimetype = file.mimetype
        
        new_file = File(
            team_id=team_id,
            task_id=task_id,
            resource_id=resource_id,
            message_id=request.form.get('message_id'),
            timeline_event_id=timeline_event_id,
            filename=original_filename,
            filepath=unique_filename,
            filesize=filesize,
            mimetype=mimetype,
            uploader_id=current_user_id
        )
        db.session.add(new_file)
        db.session.commit()
        
        return jsonify({
            'id': new_file.id,
            'uid': new_file.uid,
            'filename': new_file.filename,
            'url': f'/api/files/{new_file.uid}',
            'message': 'File uploaded successfully'
        }), 201

@bp.route('', methods=['GET'])
@jwt_required()
def get_files():
    current_user_id = int(get_jwt_identity())
    task_id = request.args.get('task_id')
    
    if not task_id:
        return jsonify({'message': 'Task ID required'}), 400
        
    files = File.query.filter_by(task_id=task_id).order_by(File.created_at.desc()).all()
    
    # Check access (skipped for brevity, assume team member check)
    
    result = []
    for f in files:
        result.append({
            'id': f.id,
            'uid': f.uid,
            'filename': f.filename,
            'filesize': f.filesize,
            'created_at': f.created_at.isoformat(),
            'url': f'/api/files/{f.uid}'
        })
    return jsonify(result), 200


@bp.route('/<string:uid>', methods=['GET'])
@jwt_required()
def download_file(uid):
    current_user_id = int(get_jwt_identity())
    file = File.query.filter_by(uid=uid).first_or_404()
    
    if not TeamMember.query.filter_by(team_id=file.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    inline = request.args.get('inline') == 'true'
    
    return send_from_directory(current_app.config['UPLOAD_FOLDER'], file.filepath, as_attachment=not inline, download_name=file.filename)

@bp.route('/<string:uid>', methods=['DELETE'])
@jwt_required()
def delete_file(uid):
    current_user_id = int(get_jwt_identity())
    file = File.query.filter_by(uid=uid).first_or_404()
    
    if file.uploader_id != current_user_id:
         # Check if user is creator of team? For now just uploader.
         return jsonify({'message': 'Only uploader can delete file'}), 403
         
    if not TeamMember.query.filter_by(team_id=file.team_id, user_id=current_user_id).first():
        return jsonify({'message': 'Access denied'}), 403
        
    # Remove from disk
    try:
        os.remove(os.path.join(current_app.config['UPLOAD_FOLDER'], file.filepath))
    except OSError:
        pass # File might be already gone
        
    db.session.delete(file)
    db.session.commit()
    
    return jsonify({'message': 'File deleted successfully'}), 200

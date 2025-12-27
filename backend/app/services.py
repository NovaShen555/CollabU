from app.models import Notification, TaskActivity, TaskParticipant, User, Task
from app import db

def create_notification(user_id, type, content, related_id=None):
    notif = Notification(
        user_id=user_id,
        type=type,
        content=content,
        related_id=related_id
    )
    db.session.add(notif)
    db.session.commit()

def log_activity(task_id, user_id, action, detail=None):
    activity = TaskActivity(
        task_id=task_id,
        user_id=user_id,
        action=action,
        detail=detail
    )
    db.session.add(activity)
    db.session.commit()

def notify_task_participants(task_id, type, content, exclude_user_id=None):
    participants = TaskParticipant.query.filter_by(task_id=task_id).all()
    for p in participants:
        if p.user_id != exclude_user_id:
            create_notification(p.user_id, type, content, related_id=task_id)

def get_task_participants_ids(task_id):
    participants = TaskParticipant.query.filter_by(task_id=task_id).all()
    return [p.user_id for p in participants]

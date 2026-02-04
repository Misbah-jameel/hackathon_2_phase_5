from typing import List, Optional, Tuple, Literal
from datetime import datetime
from sqlmodel import Session, select
from rapidfuzz import fuzz, process

from ..models.task import Task


# Type alias for match result type
MatchType = Literal["exact", "fuzzy", "ambiguous", "none"]


class TaskService:
    """Service for task CRUD operations."""

    # Fuzzy matching thresholds
    FUZZY_THRESHOLD = 80  # Minimum score to consider a match
    CONFIDENT_THRESHOLD = 95  # Score for auto-selection without disambiguation

    @staticmethod
    def get_tasks_by_user(session: Session, user_id: str) -> List[Task]:
        """Get all tasks for a user."""
        statement = select(Task).where(Task.user_id == user_id).order_by(Task.created_at.desc())
        return list(session.exec(statement).all())

    @staticmethod
    def get_task_by_id(session: Session, task_id: str, user_id: str) -> Optional[Task]:
        """Get a task by ID (must belong to user)."""
        statement = select(Task).where(Task.id == task_id, Task.user_id == user_id)
        return session.exec(statement).first()

    @staticmethod
    def get_task_by_title(session: Session, title: str, user_id: str) -> Optional[Task]:
        """
        Get a task by title (case-insensitive exact match only).
        For fuzzy matching with disambiguation, use find_task_by_title() instead.
        """
        from sqlalchemy import func
        statement = select(Task).where(
            func.lower(Task.title) == title.lower(),
            Task.user_id == user_id
        )
        return session.exec(statement).first()

    @staticmethod
    def find_task_by_title(
        session: Session,
        title: str,
        user_id: str,
    ) -> Tuple[MatchType, Optional[Task], List[Task]]:
        """
        Find a task by title using fuzzy matching with disambiguation support.

        Returns:
            Tuple of (match_type, matched_task, candidate_list):
            - ("exact", task, []) - Exact case-insensitive match found
            - ("fuzzy", task, []) - Single confident fuzzy match (>95%)
            - ("ambiguous", None, [tasks...]) - Multiple matches need disambiguation
            - ("none", None, []) - No matches found
        """
        search_title = title.strip().lower()

        # Get all user tasks
        all_tasks = TaskService.get_tasks_by_user(session, user_id)
        if not all_tasks:
            return ("none", None, [])

        # Check for exact match first (case-insensitive)
        for task in all_tasks:
            if task.title.lower() == search_title:
                return ("exact", task, [])

        # Build list of (task, title) for fuzzy matching
        task_titles = [(task, task.title) for task in all_tasks]

        # Use rapidfuzz to find best matches
        matches = []
        for task, task_title in task_titles:
            # Use token_set_ratio for better partial matching
            score = fuzz.token_set_ratio(search_title, task_title.lower())
            if score >= TaskService.FUZZY_THRESHOLD:
                matches.append((task, score))

        if not matches:
            return ("none", None, [])

        # Sort by score descending
        matches.sort(key=lambda x: x[1], reverse=True)

        # If best match is very confident and significantly better than second best
        best_task, best_score = matches[0]
        if best_score >= TaskService.CONFIDENT_THRESHOLD:
            # Check if there's another match close to this score
            if len(matches) == 1 or matches[1][1] < best_score - 10:
                return ("fuzzy", best_task, [])

        # Multiple ambiguous matches - return top candidates for disambiguation
        candidates = [task for task, score in matches[:5]]  # Top 5 candidates
        return ("ambiguous", None, candidates)

    @staticmethod
    def create_task(
        session: Session,
        user_id: str,
        title: str,
        description: Optional[str] = None,
    ) -> Task:
        """Create a new task."""
        task = Task(
            title=title,
            description=description,
            user_id=user_id,
        )
        session.add(task)
        session.commit()
        session.refresh(task)
        return task

    @staticmethod
    def update_task(
        session: Session,
        task: Task,
        title: Optional[str] = None,
        description: Optional[str] = None,
        completed: Optional[bool] = None,
    ) -> Task:
        """Update a task."""
        if title is not None:
            task.title = title
        if description is not None:
            task.description = description
        if completed is not None:
            task.completed = completed
        task.updated_at = datetime.utcnow()
        session.add(task)
        session.commit()
        session.refresh(task)
        return task

    @staticmethod
    def delete_task(session: Session, task: Task) -> None:
        """Delete a task."""
        session.delete(task)
        session.commit()

    @staticmethod
    def toggle_task(session: Session, task: Task) -> Task:
        """Toggle a task's completion status."""
        task.completed = not task.completed
        task.updated_at = datetime.utcnow()
        session.add(task)
        session.commit()
        session.refresh(task)
        return task

    @staticmethod
    def get_pending_tasks(session: Session, user_id: str) -> List[Task]:
        """Get all pending (incomplete) tasks for a user."""
        statement = select(Task).where(
            Task.user_id == user_id,
            Task.completed == False
        ).order_by(Task.created_at.desc())
        return list(session.exec(statement).all())

    @staticmethod
    def get_completed_tasks(session: Session, user_id: str) -> List[Task]:
        """Get all completed tasks for a user."""
        statement = select(Task).where(
            Task.user_id == user_id,
            Task.completed == True
        ).order_by(Task.created_at.desc())
        return list(session.exec(statement).all())

"""
Chatbot Service - AI-Powered Task Management

This service uses Claude AI for natural language understanding with
fallback to regex pattern matching when API key is not configured.

Features:
- AI-powered intent detection via Anthropic Claude API
- Fuzzy task matching with disambiguation
- Context-aware task operations
"""

import re
import json
import logging
from typing import Optional, Dict, Any, List, Tuple
from sqlmodel import Session

from .task_service import TaskService
from ..schemas.chatbot import ChatbotResponse
from ..config import settings

logger = logging.getLogger(__name__)


class ChatbotService:
    """Service for processing natural language commands."""

    # Intent patterns (fallback when AI is not available)
    PATTERNS = {
        "add": [
            r"add\s+task[:\s]+(.+)",
            r"create[:\s]+(.+)",
            r"new\s+task[:\s]+(.+)",
            r"add[:\s]+(.+)",
        ],
        "list": [
            r"show\s+(all\s+)?tasks?",
            r"list\s+(all\s+)?tasks?",
            r"my\s+tasks?",
            r"show\s+pending(\s+tasks?)?",
            r"show\s+completed(\s+tasks?)?",
            r"pending\s+tasks?",
            r"completed\s+tasks?",
            r"what.*tasks",
        ],
        "complete": [
            r"complete[:\s]+(.+)",
            r"mark\s+done[:\s]+(.+)",
            r"finish[:\s]+(.+)",
            r"done[:\s]+(.+)",
        ],
        "delete": [
            r"delete[:\s]+(.+)",
            r"remove[:\s]+(.+)",
        ],
        "help": [
            r"^help$",
            r"^\?$",
            r"commands?",
            r"what\s+can\s+you\s+do",
        ],
        "greeting": [
            r"^hi$",
            r"^hello$",
            r"^hey$",
            r"^howdy$",
            r"^hola$",
            r"^yo$",
            r"^sup$",
            r"^greetings$",
            r"^good\s+(morning|afternoon|evening|day)",
            r"^hi\s+there",
            r"^hello\s+there",
            r"^hey\s+there",
            r"^what'?s\s+up",
            r"^how\s+are\s+you",
            r"^how'?s\s+it\s+going",
        ],
    }

    HELP_MESSAGE = """I can help you manage your tasks! Try these commands:

**Add tasks:**
- "Add task: Buy groceries"
- "Create: Review documents"

**View tasks:**
- "Show my tasks"
- "Show pending tasks"
- "Show completed tasks"

**Complete tasks:**
- "Complete: Buy groceries"
- "Mark done: Review documents"

**Delete tasks:**
- "Delete: Old task"
- "Remove: Cancelled item"

**Get help:**
- "Help" or "?"
"""

    # AI prompt for intent detection
    AI_INTENT_PROMPT = """You are a task management assistant. Analyze the user's message and extract their intent.

Return a JSON object with:
- "intent": one of "add", "list", "complete", "delete", "help", "greeting", or "unknown"
- "param": the task title or filter if applicable (null if not applicable)
- "filter": for list intent only - "pending", "completed", or "all"

Examples:
- "add buy milk" -> {{"intent": "add", "param": "buy milk", "filter": null}}
- "show my pending tasks" -> {{"intent": "list", "param": null, "filter": "pending"}}
- "mark done groceries" -> {{"intent": "complete", "param": "groceries", "filter": null}}
- "delete old task" -> {{"intent": "delete", "param": "old task", "filter": null}}
- "help" -> {{"intent": "help", "param": null, "filter": null}}
- "hi" -> {{"intent": "greeting", "param": null, "filter": null}}
- "hello there" -> {{"intent": "greeting", "param": null, "filter": null}}
- "good morning" -> {{"intent": "greeting", "param": null, "filter": null}}
- "how are you" -> {{"intent": "greeting", "param": null, "filter": null}}

User message: {message}

Respond with only the JSON object, no other text."""

    @classmethod
    def detect_intent_with_ai(cls, message: str) -> Tuple[str, Optional[str], Optional[str]]:
        """
        Use Claude AI to detect intent from natural language.

        Returns:
            Tuple of (intent, param, filter)
        """
        if not settings.has_anthropic_key:
            # Fall back to regex if no API key
            intent, param = cls.detect_intent(message)
            return intent, param, None

        try:
            import anthropic

            client = anthropic.Anthropic(api_key=settings.anthropic_api_key)

            response = client.messages.create(
                model=settings.anthropic_model,
                max_tokens=150,
                messages=[
                    {
                        "role": "user",
                        "content": cls.AI_INTENT_PROMPT.format(message=message),
                    }
                ],
            )

            # Parse the JSON response
            response_text = response.content[0].text.strip()
            # Handle potential markdown code blocks
            if response_text.startswith("```"):
                response_text = response_text.split("```")[1]
                if response_text.startswith("json"):
                    response_text = response_text[4:]
                response_text = response_text.strip()

            result = json.loads(response_text)

            intent = result.get("intent", "unknown")
            param = result.get("param")
            filter_type = result.get("filter")

            # Validate intent
            valid_intents = {"add", "list", "complete", "delete", "help", "greeting", "unknown"}
            if intent not in valid_intents:
                intent = "unknown"

            return intent, param, filter_type

        except json.JSONDecodeError as e:
            logger.warning(f"Failed to parse AI response as JSON: {e}")
            # Fall back to regex
            intent, param = cls.detect_intent(message)
            return intent, param, None
        except Exception as e:
            logger.warning(f"AI intent detection failed: {e}")
            # Fall back to regex
            intent, param = cls.detect_intent(message)
            return intent, param, None

    @classmethod
    def detect_intent(cls, message: str) -> Tuple[str, Optional[str]]:
        """Detect the intent and extract any parameters from the message using regex."""
        message_lower = message.lower().strip()

        for intent, patterns in cls.PATTERNS.items():
            for pattern in patterns:
                match = re.search(pattern, message_lower, re.IGNORECASE)
                if match:
                    # Extract captured group if exists
                    param = match.group(1).strip() if match.lastindex else None
                    return intent, param

        return "unknown", None

    @classmethod
    def process_message(
        cls,
        session: Session,
        user_id: str,
        message: str,
    ) -> ChatbotResponse:
        """Process a natural language message and execute the appropriate action."""
        # Try AI-powered intent detection first, fall back to regex
        intent, param, filter_type = cls.detect_intent_with_ai(message)

        if intent == "help":
            return cls._handle_help()
        elif intent == "greeting":
            return cls._handle_greeting()
        elif intent == "add":
            return cls._handle_add(session, user_id, param)
        elif intent == "list":
            return cls._handle_list(session, user_id, message, filter_type)
        elif intent == "complete":
            return cls._handle_complete(session, user_id, param)
        elif intent == "delete":
            return cls._handle_delete(session, user_id, param)
        else:
            return cls._handle_unknown()

    @classmethod
    def _handle_greeting(cls) -> ChatbotResponse:
        """Handle greeting intent."""
        return ChatbotResponse(
            message="Hello! I'm Misbah's assistant. How can I help you today?",
            intent="greeting",
            success=True,
            suggestions=["Show my tasks", "Add task: ", "Help"],
        )

    @classmethod
    def _handle_help(cls) -> ChatbotResponse:
        """Handle help intent."""
        return ChatbotResponse(
            message=cls.HELP_MESSAGE,
            intent="help",
            success=True,
            suggestions=["Show my tasks", "Add task: ", "Help"],
        )

    @classmethod
    def _handle_add(
        cls,
        session: Session,
        user_id: str,
        task_title: Optional[str],
    ) -> ChatbotResponse:
        """Handle add task intent."""
        if not task_title:
            return ChatbotResponse(
                message="Please specify a task title. Example: 'Add task: Buy groceries'",
                intent="add",
                success=False,
                suggestions=["Add task: Buy groceries", "Add task: Review documents"],
            )

        task = TaskService.create_task(session, user_id, task_title)

        return ChatbotResponse(
            message=f"Task '{task.title}' created!",
            intent="add",
            success=True,
            data={
                "id": task.id,
                "title": task.title,
                "completed": task.completed,
            },
            suggestions=["Show my tasks", "Add another task", "Complete: " + task.title],
        )

    @classmethod
    def _handle_list(
        cls,
        session: Session,
        user_id: str,
        message: str,
        filter_type: Optional[str] = None,
    ) -> ChatbotResponse:
        """Handle list tasks intent."""
        # Use AI-provided filter if available, otherwise parse from message
        if filter_type is None:
            message_lower = message.lower()
            if "pending" in message_lower:
                filter_type = "pending"
            elif "completed" in message_lower:
                filter_type = "completed"
            else:
                filter_type = "all"

        if filter_type == "pending":
            tasks = TaskService.get_pending_tasks(session, user_id)
        elif filter_type == "completed":
            tasks = TaskService.get_completed_tasks(session, user_id)
        else:
            tasks = TaskService.get_tasks_by_user(session, user_id)

        if not tasks:
            return ChatbotResponse(
                message=f"No {filter_type} tasks found.",
                intent="list",
                success=True,
                suggestions=["Add task: ", "Show all tasks"],
            )

        task_list = []
        for task in tasks[:10]:  # Limit to 10 tasks
            status = "[x]" if task.completed else "[ ]"
            task_list.append(f"{status} {task.title}")

        task_str = "\n".join(task_list)
        count_msg = f" (showing 10 of {len(tasks)})" if len(tasks) > 10 else ""

        return ChatbotResponse(
            message=f"Your {filter_type} tasks{count_msg}:\n\n{task_str}",
            intent="list",
            success=True,
            data=[{"id": t.id, "title": t.title, "completed": t.completed} for t in tasks[:10]],
            suggestions=["Show pending tasks", "Show completed tasks", "Add task: "],
        )

    @classmethod
    def _handle_complete(
        cls,
        session: Session,
        user_id: str,
        task_title: Optional[str],
    ) -> ChatbotResponse:
        """Handle complete task intent with fuzzy matching."""
        if not task_title:
            return ChatbotResponse(
                message="Please specify which task to complete. Example: 'Complete: Buy groceries'",
                intent="complete",
                success=False,
                suggestions=["Show my tasks", "Complete: "],
            )

        # Use fuzzy matching
        match_type, task, candidates = TaskService.find_task_by_title(
            session, task_title, user_id
        )

        if match_type == "none":
            return ChatbotResponse(
                message=f"Couldn't find a task matching '{task_title}'.",
                intent="complete",
                success=False,
                suggestions=["Show my tasks", "Add task: " + task_title],
            )

        if match_type == "ambiguous":
            # Multiple matches - ask user to be more specific
            task_names = [f"• {t.title}" for t in candidates]
            return ChatbotResponse(
                message=f"Multiple tasks match '{task_title}'. Please be more specific:\n\n" + "\n".join(task_names),
                intent="complete",
                success=False,
                data={"candidates": [{"id": t.id, "title": t.title} for t in candidates]},
                suggestions=[f"Complete: {candidates[0].title}"] if candidates else ["Show my tasks"],
            )

        # Exact or confident fuzzy match
        if task.completed:
            return ChatbotResponse(
                message=f"Task '{task.title}' is already completed!",
                intent="complete",
                success=True,
                data={"id": task.id, "title": task.title, "completed": task.completed},
                suggestions=["Show my tasks", "Delete: " + task.title],
            )

        TaskService.update_task(session, task, completed=True)

        return ChatbotResponse(
            message=f"Task '{task.title}' marked as complete!",
            intent="complete",
            success=True,
            data={"id": task.id, "title": task.title, "completed": True},
            suggestions=["Show my tasks", "Show pending tasks", "Add task: "],
        )

    @classmethod
    def _handle_delete(
        cls,
        session: Session,
        user_id: str,
        task_title: Optional[str],
    ) -> ChatbotResponse:
        """Handle delete task intent with fuzzy matching."""
        if not task_title:
            return ChatbotResponse(
                message="Please specify which task to delete. Example: 'Delete: Buy groceries'",
                intent="delete",
                success=False,
                suggestions=["Show my tasks", "Delete: "],
            )

        # Use fuzzy matching
        match_type, task, candidates = TaskService.find_task_by_title(
            session, task_title, user_id
        )

        if match_type == "none":
            return ChatbotResponse(
                message=f"Couldn't find a task matching '{task_title}'.",
                intent="delete",
                success=False,
                suggestions=["Show my tasks"],
            )

        if match_type == "ambiguous":
            # Multiple matches - ask user to be more specific
            task_names = [f"• {t.title}" for t in candidates]
            return ChatbotResponse(
                message=f"Multiple tasks match '{task_title}'. Please be more specific:\n\n" + "\n".join(task_names),
                intent="delete",
                success=False,
                data={"candidates": [{"id": t.id, "title": t.title} for t in candidates]},
                suggestions=[f"Delete: {candidates[0].title}"] if candidates else ["Show my tasks"],
            )

        # Exact or confident fuzzy match
        title = task.title
        TaskService.delete_task(session, task)

        return ChatbotResponse(
            message=f"Task '{title}' deleted!",
            intent="delete",
            success=True,
            suggestions=["Show my tasks", "Add task: "],
        )

    @classmethod
    def _handle_unknown(cls) -> ChatbotResponse:
        """Handle unknown intent."""
        return ChatbotResponse(
            message="I didn't understand that. Try 'Help' to see what I can do!",
            intent="unknown",
            success=False,
            suggestions=["Help", "Show my tasks", "Add task: "],
        )

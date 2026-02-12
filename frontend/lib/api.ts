import {
  API_BASE_URL,
  API_ENDPOINTS,
  HTTP_STATUS,
  ERROR_MESSAGES,
} from './constants';
import {
  mockLogin,
  mockSignup,
  mockLogout,
  mockGetMe,
  mockGetTasks,
  mockGetTask,
  mockCreateTask,
  mockUpdateTask,
  mockDeleteTask,
  mockToggleTask,
  setMockCurrentUser,
} from './mock-api';
import type {
  Task,
  CreateTaskInput,
  UpdateTaskInput,
  TaskQueryParams,
  User,
  LoginInput,
  SignupInput,
  AuthResponse,
  ApiResult,
  ChatbotResponse,
} from '@/types';

// Enable mock mode for development without backend
const USE_MOCK_API = process.env.NEXT_PUBLIC_USE_MOCK_API === 'true';

// ============ Token Management ============
let accessToken: string | null = null;

export function setAccessToken(token: string | null): void {
  accessToken = token;
}

export function getAccessToken(): string | null {
  return accessToken;
}

// ============ Base Fetch Function ============
async function fetchApi<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<ApiResult<T>> {
  const url = API_BASE_URL + endpoint;
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  // Add authorization header if token exists
  if (accessToken) {
    (headers as Record<string, string>)['Authorization'] = 'Bearer ' + accessToken;
  }

  try {
    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (response.status === HTTP_STATUS.UNAUTHORIZED) {
      setAccessToken(null);
      return {
        error: {
          message: ERROR_MESSAGES.UNAUTHORIZED,
          code: 'UNAUTHORIZED',
        },
      };
    }

    if (response.status === HTTP_STATUS.NO_CONTENT) {
      return { data: null as T };
    }

    const data = await response.json();

    if (!response.ok) {
      return {
        error: {
          message: data.message || data.detail || ERROR_MESSAGES.GENERIC_ERROR,
          code: data.code || 'HTTP_' + response.status,
        },
      };
    }

    return { data };
  } catch (error) {
    console.error('API Error:', error);
    return {
      error: {
        message: ERROR_MESSAGES.NETWORK_ERROR,
        code: 'NETWORK_ERROR',
      },
    };
  }
}

// ============ Auth API ============
export async function login(input: LoginInput): Promise<ApiResult<AuthResponse>> {
  if (USE_MOCK_API) {
    const result = await mockLogin(input);
    if ('data' in result && result.data) {
      setAccessToken(result.data.token);
      setMockCurrentUser(result.data.user);
    }
    return result;
  }

  const result = await fetchApi<AuthResponse>(API_ENDPOINTS.LOGIN, {
    method: 'POST',
    body: JSON.stringify(input),
  });

  if ('data' in result && result.data) {
    setAccessToken(result.data.token);
  }

  return result;
}

export async function signup(input: SignupInput): Promise<ApiResult<AuthResponse>> {
  if (USE_MOCK_API) {
    const result = await mockSignup(input);
    if ('data' in result && result.data) {
      setAccessToken(result.data.token);
      setMockCurrentUser(result.data.user);
    }
    return result;
  }

  const result = await fetchApi<AuthResponse>(API_ENDPOINTS.SIGNUP, {
    method: 'POST',
    body: JSON.stringify(input),
  });

  if ('data' in result && result.data) {
    setAccessToken(result.data.token);
  }

  return result;
}

export async function logout(): Promise<ApiResult<null>> {
  if (USE_MOCK_API) {
    setAccessToken(null);
    setMockCurrentUser(null);
    return mockLogout();
  }

  const result = await fetchApi<null>(API_ENDPOINTS.LOGOUT, {
    method: 'POST',
  });

  setAccessToken(null);
  return result;
}

export async function getMe(): Promise<ApiResult<User>> {
  if (USE_MOCK_API) {
    return mockGetMe();
  }
  return fetchApi<User>(API_ENDPOINTS.ME);
}

// ============ Tasks API ============
export async function getTasks(params?: TaskQueryParams): Promise<ApiResult<Task[]>> {
  if (USE_MOCK_API) {
    return mockGetTasks();
  }

  // Build query string from params
  let queryString = '';
  if (params) {
    const searchParams = new URLSearchParams();
    if (params.search) searchParams.set('search', params.search);
    if (params.priority) searchParams.set('priority', params.priority);
    if (params.tags) searchParams.set('tags', params.tags);
    if (params.status) searchParams.set('status', params.status);
    if (params.due_before) searchParams.set('due_before', params.due_before);
    if (params.due_after) searchParams.set('due_after', params.due_after);
    if (params.sort_by) searchParams.set('sort_by', params.sort_by);
    if (params.sort_order) searchParams.set('sort_order', params.sort_order);
    if (params.page) searchParams.set('page', params.page.toString());
    if (params.page_size) searchParams.set('page_size', params.page_size.toString());
    const qs = searchParams.toString();
    if (qs) queryString = '?' + qs;
  }

  return fetchApi<Task[]>(API_ENDPOINTS.TASKS + queryString);
}

export async function getTask(id: string): Promise<ApiResult<Task>> {
  if (USE_MOCK_API) {
    return mockGetTask(id);
  }
  return fetchApi<Task>(API_ENDPOINTS.TASK(id));
}

export async function createTask(input: CreateTaskInput): Promise<ApiResult<Task>> {
  if (USE_MOCK_API) {
    return mockCreateTask(input);
  }
  return fetchApi<Task>(API_ENDPOINTS.TASKS, {
    method: 'POST',
    body: JSON.stringify(input),
  });
}

export async function updateTask(
  id: string,
  input: UpdateTaskInput
): Promise<ApiResult<Task>> {
  if (USE_MOCK_API) {
    return mockUpdateTask(id, input);
  }
  return fetchApi<Task>(API_ENDPOINTS.TASK(id), {
    method: 'PATCH',
    body: JSON.stringify(input),
  });
}

export async function deleteTask(id: string): Promise<ApiResult<null>> {
  if (USE_MOCK_API) {
    return mockDeleteTask(id);
  }
  return fetchApi<null>(API_ENDPOINTS.TASK(id), {
    method: 'DELETE',
  });
}

export async function toggleTask(id: string): Promise<ApiResult<Task>> {
  if (USE_MOCK_API) {
    return mockToggleTask(id);
  }
  return fetchApi<Task>(API_ENDPOINTS.TASK_TOGGLE(id), {
    method: 'PATCH',
  });
}

// ============ Chatbot API ============
export async function sendChatMessage(message: string): Promise<ApiResult<ChatbotResponse>> {
  if (USE_MOCK_API) {
    // Mock chatbot response for development
    return mockChatbotResponse(message);
  }
  return fetchApi<ChatbotResponse>(API_ENDPOINTS.CHATBOT, {
    method: 'POST',
    body: JSON.stringify({ message }),
  });
}

// Mock chatbot response for development
function mockChatbotResponse(message: string): Promise<ApiResult<ChatbotResponse>> {
  const lowerMessage = message.toLowerCase();

  let response: ChatbotResponse;

  if (lowerMessage.includes('help') || lowerMessage === '?') {
    response = {
      message: `I can help you manage your tasks! Try these commands:

**Add tasks:**
- "Add task: Buy groceries"
- "Create: Review documents"

**View tasks:**
- "Show my tasks"
- "Show pending tasks"

**Complete tasks:**
- "Complete: Buy groceries"

**Delete tasks:**
- "Delete: Old task"`,
      intent: 'help',
      success: true,
      suggestions: ['Show my tasks', 'Add task: ', 'Help'],
    };
  } else if (lowerMessage.includes('add') || lowerMessage.includes('create')) {
    const taskMatch = message.match(/(?:add|create)(?:\s+task)?[:\s]+(.+)/i);
    const taskTitle = taskMatch && taskMatch[1] ? taskMatch[1].trim() : 'New Task';
    response = {
      message: `Task '${taskTitle}' created! (Mock mode)`,
      intent: 'add',
      success: true,
      data: { id: Date.now().toString(), title: taskTitle, completed: false },
      suggestions: ['Show my tasks', 'Add another task'],
    };
  } else if (lowerMessage.includes('show') || lowerMessage.includes('list') || lowerMessage.includes('my tasks')) {
    response = {
      message: 'In mock mode, tasks are managed locally. Check the Tasks page to see your tasks.',
      intent: 'list',
      success: true,
      suggestions: ['Add task: ', 'Help'],
    };
  } else if (lowerMessage.includes('complete') || lowerMessage.includes('done')) {
    response = {
      message: 'To complete a task in mock mode, use the checkbox on the Tasks page.',
      intent: 'complete',
      success: true,
      suggestions: ['Show my tasks', 'Add task: '],
    };
  } else if (lowerMessage.includes('delete') || lowerMessage.includes('remove')) {
    response = {
      message: 'To delete a task in mock mode, use the delete button on the Tasks page.',
      intent: 'delete',
      success: true,
      suggestions: ['Show my tasks', 'Add task: '],
    };
  } else {
    response = {
      message: "I didn't understand that. Try 'Help' to see what I can do!",
      intent: 'unknown',
      success: false,
      suggestions: ['Help', 'Show my tasks', 'Add task: '],
    };
  }

  return Promise.resolve({ data: response });
}

// ============ Helper Functions ============
export function isApiError<T>(result: ApiResult<T>): result is { error: { message: string; code: string } } {
  return 'error' in result && result.error !== undefined;
}

export function isApiSuccess<T>(result: ApiResult<T>): result is { data: T } {
  return 'data' in result && !('error' in result && result.error !== undefined);
}

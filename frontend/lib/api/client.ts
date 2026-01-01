import axios, { AxiosError, AxiosInstance } from 'axios';
import type {
  User,
  LoginRequest,
  RegisterRequest,
  AuthResponse,
  GitHubRepo,
  GitHubUser,
  GitHubConfigureRequest,
  HealthResponse,
  APIError,
} from '@/types';

// API URL now points to Next.js API routes (same origin, no CORS)
// Next.js routes will proxy to backend internally
const API_URL = '/api';

// Create axios instance with default config
const apiClient: AxiosInstance = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // Important for httpOnly cookies
});

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError<APIError>) => {
    const apiError: APIError = {
      detail: error.response?.data?.detail || error.message || 'An error occurred',
      status: error.response?.status,
    };
    return Promise.reject(apiError);
  }
);

// Auth API (paths updated to match Next.js API routes)
export const authAPI = {
  register: async (data: RegisterRequest): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>('/auth/register', data);
    return response.data;
  },

  login: async (data: LoginRequest): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>('/auth/login', data);
    return response.data;
  },

  logout: async (): Promise<void> => {
    await apiClient.post('/auth/logout');
  },

  getCurrentUser: async (): Promise<User> => {
    const response = await apiClient.get<User>('/auth/me');
    return response.data;
  },
};

// GitHub API (paths updated to match Next.js API routes)
export const githubAPI = {
  configure: async (token: string): Promise<{ message: string }> => {
    const data: GitHubConfigureRequest = { github_token: token };
    const response = await apiClient.post('/github/configure', data);
    return response.data;
  },

  getRepositories: async (): Promise<GitHubRepo[]> => {
    const response = await apiClient.get<GitHubRepo[]>('/github/repos');
    return response.data;
  },

  getUser: async (): Promise<GitHubUser> => {
    const response = await apiClient.get<GitHubUser>('/github/user');
    return response.data;
  },
};

// Health API (path updated to match Next.js API route)
export const healthAPI = {
  check: async (): Promise<HealthResponse> => {
    const response = await apiClient.get<HealthResponse>('/health/ready');
    return response.data;
  },
};

export default apiClient;

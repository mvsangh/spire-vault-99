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

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

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

// Auth API
export const authAPI = {
  register: async (data: RegisterRequest): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>('/api/v1/auth/register', data);
    return response.data;
  },

  login: async (data: LoginRequest): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>('/api/v1/auth/login', data);
    return response.data;
  },

  logout: async (): Promise<void> => {
    await apiClient.post('/api/v1/auth/logout');
  },

  getCurrentUser: async (): Promise<User> => {
    const response = await apiClient.get<User>('/api/v1/auth/me');
    return response.data;
  },
};

// GitHub API
export const githubAPI = {
  configure: async (token: string): Promise<{ message: string }> => {
    const data: GitHubConfigureRequest = { token };
    const response = await apiClient.post('/api/v1/github/configure', data);
    return response.data;
  },

  getRepositories: async (): Promise<GitHubRepo[]> => {
    const response = await apiClient.get<GitHubRepo[]>('/api/v1/github/repos');
    return response.data;
  },

  getUser: async (): Promise<GitHubUser> => {
    const response = await apiClient.get<GitHubUser>('/api/v1/github/user');
    return response.data;
  },
};

// Health API
export const healthAPI = {
  check: async (): Promise<HealthResponse> => {
    const response = await apiClient.get<HealthResponse>('/api/v1/health/ready');
    return response.data;
  },
};

export default apiClient;

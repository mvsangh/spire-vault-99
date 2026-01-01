// User types
export interface User {
  id: number;
  username: string;
  email?: string;
  created_at?: string;
}

// Auth types
export interface LoginRequest {
  username: string;
  password: string;
}

export interface RegisterRequest {
  username: string;
  email?: string;
  password: string;
}

export interface AuthResponse {
  message: string;
  user?: User;
}

// GitHub types
export interface GitHubRepo {
  id: number;
  name: string;
  full_name: string;
  description: string | null;
  html_url: string;
  stargazers_count: number;
  language: string | null;
  updated_at: string;
}

export interface GitHubUser {
  login: string;
  id: number;
  avatar_url: string;
  name: string | null;
  bio: string | null;
  public_repos: number;
  followers: number;
  following: number;
}

export interface GitHubConfigureRequest {
  github_token: string;
}

// Health check types
export interface HealthResponse {
  status: string;
  version: string;
  spire: string;
  vault: string;
  database: string;
}

// API Error types
export interface APIError {
  detail: string;
  status?: number;
}

// Base types aligned with Rails backend

export type VisibilityType = "private" | "link" | "public";

export type CollaboratorRole = "viewer" | "editor";

export interface User {
  id: number;
  email: string;
  created_at: string;
  updated_at: string;
}

export interface Note {
  id: number;
  title: string;
  owner_id: number;
  head_version_id: number | null;
  visibility: VisibilityType;
  created_at: string;
  updated_at: string;
  owner?: Pick<User, "id" | "email">;
  head_version?: Version;
}

export interface Version {
  id: number;
  note_id: number;
  author_id: number;
  parent_version_id: number | null;
  summary: string;
  content: string;
  created_at: string;
  author?: Pick<User, "id" | "email">;
}

export interface Collaborator {
  id: number;
  note_id: number;
  user_id: number;
  role: CollaboratorRole;
  created_at: string;
  updated_at: string;
  user?: Pick<User, "id" | "email">;
}

export interface ApiError {
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  per_page: number;
}

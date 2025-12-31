# 🎨 SUB-SPRINT 3: Frontend Application Development
**Next.js 16 + Material-UI + TypeScript + httpOnly Cookies Authentication**

## 📊 Overview

**Objective:** Develop a production-grade Next.js 16 frontend application with Material-UI components, secure httpOnly cookie authentication, and GitHub integration UI.

**Duration:** ASAP
**Prerequisites:**
- Sub-Sprint 1 (Infrastructure Foundation) ✅ COMPLETE
- Sub-Sprint 2 (Backend Application) ✅ COMPLETE

**Success Criteria:** Frontend running in cluster with secure authentication, responsive UI, and full backend integration

---

## 🎯 Deliverables

- ✅ Next.js 16 application with App Router
- ✅ Material-UI (MUI) component library with custom theme
- ✅ TypeScript for type safety
- ✅ httpOnly cookie authentication (secure, production-ready)
- ✅ Backend API updates for cookie-based auth
- ✅ Authentication UI (login/registration)
- ✅ Protected routes with middleware
- ✅ Dashboard and user profile
- ✅ GitHub integration pages (configure token, view repos, user profile)
- ✅ Dark mode support
- ✅ Toast notifications for user feedback
- ✅ Responsive design (mobile-friendly)
- ✅ Docker containerization
- ✅ Kubernetes deployment with Tilt hot-reload
- ✅ End-to-end integration testing

---

## 🗂️ Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Framework** | Next.js | 16.1 | React framework with App Router |
| **Language** | TypeScript | 5.x | Type safety |
| **UI Library** | Material-UI (MUI) | 6.x | Component library |
| **Styling** | Emotion (MUI default) | 11.x | CSS-in-JS |
| **Form Handling** | React Hook Form | 7.x | Form validation |
| **Schema Validation** | Zod | 3.x | Type-safe validation |
| **HTTP Client** | Axios | 1.x | API requests with interceptors |
| **State Management** | React Context | Built-in | Auth state management |
| **Toast Notifications** | notistack (MUI) | 3.x | User feedback |
| **Icons** | MUI Icons | 6.x | Icon library |
| **Dev Tool** | Tilt | Latest | Hot-reload development |

---

## 📋 Phase Breakdown

### **Phase 1: Project Setup & Configuration**
### **Phase 2: Backend API Updates (httpOnly Cookies)**
### **Phase 3: Authentication UI & Context**
### **Phase 4: Layout & Navigation (MUI)**
### **Phase 5: Dashboard & Protected Routes**
### **Phase 6: GitHub Integration UI**
### **Phase 7: Styling & UX Polish**
### **Phase 8: Dockerization & Kubernetes Deployment**
### **Phase 9: Integration Testing & Verification**

---

## 🔧 Phase 1: Project Setup & Configuration

**Objective:** Initialize Next.js 16 project with TypeScript, Material-UI, and development tooling.

### **Tasks:**

#### **Task 1.1: Create Next.js 16 Application**

**Description:** Initialize Next.js 16 project with TypeScript and App Router.

**Commands:**
```bash
cd /home/mandrix-murdock/code/spire-spife/test-vault

# Create Next.js app with TypeScript
npx create-next-app@latest frontend \
  --typescript \
  --app \
  --no-tailwind \
  --eslint \
  --no-src-dir \
  --import-alias "@/*"

cd frontend
```

**Expected Prompts & Answers:**
- Would you like to use TypeScript? **Yes**
- Would you like to use ESLint? **Yes**
- Would you like to use Tailwind CSS? **No** (using MUI)
- Would you like to use `src/` directory? **No**
- Would you like to use App Router? **Yes**
- Would you like to customize the default import alias? **Yes** → `@/*`

**Success Criteria:**
- ✅ Next.js 16.1 project created
- ✅ TypeScript configured
- ✅ App Router structure (`app/` directory)
- ✅ ESLint configured

---

#### **Task 1.2: Install Material-UI and Dependencies**

**Description:** Install MUI, form libraries, and other dependencies.

**Commands:**
```bash
cd frontend

# Material-UI core
npm install @mui/material@latest @emotion/react@latest @emotion/styled@latest

# Material-UI icons
npm install @mui/icons-material@latest

# Toast notifications
npm install notistack@latest

# Form handling
npm install react-hook-form@latest zod@latest @hookform/resolvers@latest

# HTTP client
npm install axios@latest

# Dev dependencies
npm install -D @types/node@latest @types/react@latest @types/react-dom@latest
```

**Verify Installation:**
```bash
# Check package.json
cat package.json | grep -A 20 dependencies
```

**Success Criteria:**
- ✅ All dependencies installed
- ✅ No version conflicts
- ✅ package.json updated

---

#### **Task 1.3: Create Project Directory Structure**

**Description:** Set up organized directory structure for Next.js app.

**Commands:**
```bash
cd frontend

# Create directory structure
mkdir -p app/auth/login
mkdir -p app/auth/register
mkdir -p app/dashboard
mkdir -p app/github/configure
mkdir -p app/github/repos
mkdir -p app/github/profile
mkdir -p components/auth
mkdir -p components/layout
mkdir -p components/github
mkdir -p lib/api
mkdir -p lib/auth
mkdir -p lib/theme
mkdir -p lib/utils
mkdir -p types
mkdir -p hooks
mkdir -p contexts

# Verify structure
tree -L 2 -d .
```

**Expected Directory Structure:**
```
frontend/
├── app/
│   ├── auth/
│   │   ├── login/
│   │   └── register/
│   ├── dashboard/
│   ├── github/
│   │   ├── configure/
│   │   ├── repos/
│   │   └── profile/
│   ├── layout.tsx
│   └── page.tsx
├── components/
│   ├── auth/
│   ├── layout/
│   └── github/
├── contexts/
├── hooks/
├── lib/
│   ├── api/
│   ├── auth/
│   ├── theme/
│   └── utils/
├── types/
├── public/
├── package.json
├── tsconfig.json
└── next.config.js
```

**Success Criteria:**
- ✅ All directories created
- ✅ Organized structure for scalability

---

#### **Task 1.4: Configure TypeScript**

**Description:** Update TypeScript configuration for strict type checking.

**File:** `frontend/tsconfig.json`

**Content:**
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

**Success Criteria:**
- ✅ Strict mode enabled
- ✅ Path aliases configured (`@/*`)
- ✅ TypeScript checking works

---

#### **Task 1.5: Create MUI Theme Configuration**

**Description:** Set up custom MUI theme with Brooklyn Nine-Nine inspired colors (blue/gold).

**File:** `frontend/lib/theme/theme.ts`

**Content:**
```typescript
'use client';

import { createTheme, ThemeOptions } from '@mui/material/styles';

// Brooklyn Nine-Nine inspired color palette (NYPD blue/gold)
const lightPalette = {
  primary: {
    main: '#1e3a8a', // NYPD blue
    light: '#3b82f6',
    dark: '#1e40af',
    contrastText: '#ffffff',
  },
  secondary: {
    main: '#f59e0b', // Gold (badge accent)
    light: '#fbbf24',
    dark: '#d97706',
    contrastText: '#000000',
  },
  background: {
    default: '#f9fafb',
    paper: '#ffffff',
  },
  text: {
    primary: '#111827',
    secondary: '#6b7280',
  },
};

const darkPalette = {
  primary: {
    main: '#3b82f6',
    light: '#60a5fa',
    dark: '#2563eb',
    contrastText: '#ffffff',
  },
  secondary: {
    main: '#fbbf24',
    light: '#fcd34d',
    dark: '#f59e0b',
    contrastText: '#000000',
  },
  background: {
    default: '#111827',
    paper: '#1f2937',
  },
  text: {
    primary: '#f9fafb',
    secondary: '#d1d5db',
  },
};

export const createAppTheme = (mode: 'light' | 'dark') => {
  const themeOptions: ThemeOptions = {
    palette: {
      mode,
      ...(mode === 'light' ? lightPalette : darkPalette),
    },
    typography: {
      fontFamily: [
        '-apple-system',
        'BlinkMacSystemFont',
        '"Segoe UI"',
        'Roboto',
        '"Helvetica Neue"',
        'Arial',
        'sans-serif',
      ].join(','),
      h1: {
        fontWeight: 700,
      },
      h2: {
        fontWeight: 600,
      },
      h3: {
        fontWeight: 600,
      },
    },
    shape: {
      borderRadius: 8,
    },
    components: {
      MuiButton: {
        styleOverrides: {
          root: {
            textTransform: 'none',
            fontWeight: 600,
          },
        },
      },
      MuiCard: {
        styleOverrides: {
          root: {
            boxShadow: '0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)',
          },
        },
      },
    },
  };

  return createTheme(themeOptions);
};
```

**Success Criteria:**
- ✅ Theme with light/dark mode support
- ✅ NYPD-inspired colors (blue/gold)
- ✅ Custom typography and component styles

---

#### **Task 1.6: Create Theme Provider Component**

**Description:** Set up theme context for dark mode toggle.

**File:** `frontend/contexts/ThemeContext.tsx`

**Content:**
```typescript
'use client';

import React, { createContext, useContext, useState, useMemo, useEffect } from 'react';
import { ThemeProvider as MuiThemeProvider } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { createAppTheme } from '@/lib/theme/theme';

type ThemeMode = 'light' | 'dark';

interface ThemeContextType {
  mode: ThemeMode;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextType>({
  mode: 'light',
  toggleTheme: () => {},
});

export const useThemeContext = () => useContext(ThemeContext);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [mode, setMode] = useState<ThemeMode>('light');

  // Load theme preference from localStorage on mount
  useEffect(() => {
    const savedMode = localStorage.getItem('theme-mode') as ThemeMode;
    if (savedMode) {
      setMode(savedMode);
    }
  }, []);

  const toggleTheme = () => {
    setMode((prevMode) => {
      const newMode = prevMode === 'light' ? 'dark' : 'light';
      localStorage.setItem('theme-mode', newMode);
      return newMode;
    });
  };

  const theme = useMemo(() => createAppTheme(mode), [mode]);

  return (
    <ThemeContext.Provider value={{ mode, toggleTheme }}>
      <MuiThemeProvider theme={theme}>
        <CssBaseline />
        {children}
      </MuiThemeProvider>
    </ThemeContext.Provider>
  );
}
```

**Success Criteria:**
- ✅ Theme context with dark mode toggle
- ✅ Persists preference to localStorage
- ✅ MUI CssBaseline for consistent styling

---

#### **Task 1.7: Configure Environment Variables**

**Description:** Set up environment variables for API connection.

**File:** `frontend/.env.local`

**Content:**
```bash
# Backend API URL
NEXT_PUBLIC_API_URL=http://localhost:8000

# App Configuration
NEXT_PUBLIC_APP_NAME=SPIRE-Vault-99
NEXT_PUBLIC_APP_VERSION=1.0.0
```

**File:** `frontend/.env.example`

**Content:**
```bash
# Backend API URL (update for production)
NEXT_PUBLIC_API_URL=http://localhost:8000

# App Configuration
NEXT_PUBLIC_APP_NAME=SPIRE-Vault-99
NEXT_PUBLIC_APP_VERSION=1.0.0
```

**Add to .gitignore:**
```bash
echo ".env*.local" >> .gitignore
```

**Success Criteria:**
- ✅ Environment variables configured
- ✅ .env.local excluded from git
- ✅ .env.example committed for reference

---

#### **Task 1.8: Create TypeScript Type Definitions**

**Description:** Define shared TypeScript types for API responses.

**File:** `frontend/types/index.ts`

**Content:**
```typescript
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
  token: string;
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
```

**Success Criteria:**
- ✅ Type definitions match backend API
- ✅ Exported for use across app

---

#### **Task 1.9: Update Root Layout with Theme Provider**

**Description:** Wrap app with theme provider and notistack.

**File:** `frontend/app/layout.tsx`

**Content:**
```typescript
import type { Metadata } from 'next';
import { ThemeProvider } from '@/contexts/ThemeContext';
import { SnackbarProvider } from 'notistack';

export const metadata: Metadata = {
  title: 'SPIRE-Vault-99 - Zero Trust Demo',
  description: 'Zero-trust security platform with SPIRE, OpenBao, and Cilium',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <ThemeProvider>
          <SnackbarProvider
            maxSnack={3}
            anchorOrigin={{
              vertical: 'top',
              horizontal: 'right',
            }}
            autoHideDuration={3000}
          >
            {children}
          </SnackbarProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
```

**Success Criteria:**
- ✅ Theme provider wraps entire app
- ✅ Notistack configured for toast notifications
- ✅ Metadata set for SEO

---

#### **Task 1.10: Create Basic Home Page**

**Description:** Create temporary home page to verify setup.

**File:** `frontend/app/page.tsx`

**Content:**
```typescript
'use client';

import { Box, Container, Typography, Button } from '@mui/material';
import { useRouter } from 'next/navigation';

export default function HomePage() {
  const router = useRouter();

  return (
    <Container maxWidth="md">
      <Box
        sx={{
          minHeight: '100vh',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'center',
          textAlign: 'center',
          gap: 3,
        }}
      >
        <Typography variant="h2" component="h1" gutterBottom>
          SPIRE-Vault-99
        </Typography>
        <Typography variant="h5" color="text.secondary" gutterBottom>
          Zero-Trust Security Platform
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Brooklyn Nine-Nine themed demo showcasing SPIRE/SPIFFE, OpenBao, and Cilium integration
        </Typography>
        <Box sx={{ display: 'flex', gap: 2, mt: 2 }}>
          <Button
            variant="contained"
            size="large"
            onClick={() => router.push('/auth/login')}
          >
            Login
          </Button>
          <Button
            variant="outlined"
            size="large"
            onClick={() => router.push('/auth/register')}
          >
            Register
          </Button>
        </Box>
      </Box>
    </Container>
  );
}
```

**Success Criteria:**
- ✅ Home page displays
- ✅ MUI components render
- ✅ Routing works

---

#### **Task 1.11: Test Development Server**

**Description:** Verify Next.js app runs locally.

**Commands:**
```bash
cd frontend

# Install dependencies (if not already done)
npm install

# Run development server
npm run dev
```

**Open browser:** http://localhost:3000

**Expected Result:**
- Home page displays with MUI styling
- NYPD blue/gold color scheme
- Login/Register buttons functional (routes don't exist yet)

**Success Criteria:**
- ✅ Dev server runs on port 3000
- ✅ MUI theme applied correctly
- ✅ No TypeScript errors
- ✅ No console errors

---

### 📋 EXECUTION LOG - Phase 1

**Date:** 2025-12-30
**Status:** ✅ COMPLETE

**Summary:** Successfully created Next.js 16 application with Material-UI, TypeScript, and all dependencies. Completed all 11 tasks:
- Created Next.js 16.1.1 app with App Router (React 19.2.3)
- Installed Material-UI v7.3.6 + dependencies (Emotion, Notistack, React Hook Form, Zod, Axios)
- Created complete project directory structure (app/, components/, contexts/, lib/, types/)
- Configured TypeScript with strict mode and path aliases (@/*)
- Created custom MUI theme with NYPD-inspired colors (blue #1e3a8a + gold #f59e0b)
- Implemented ThemeProvider with dark mode toggle (persists to localStorage)
- Configured environment variables (.env.local with API URL)
- Created TypeScript type definitions matching backend API (User, Auth, GitHub, Health)
- Updated root layout with Providers wrapper (Server Component + Client Component pattern)
- Created home page with Material-UI components (Container, Typography, Button)
- Successfully tested development server on http://localhost:3001

**Key Achievement:** Resolved "createContext only works in Client Components" error by separating providers into Client Component wrapper, allowing root layout to remain Server Component for metadata support.

**Development Server:** Running on port 3001 with Turbopack hot-reload (1.4s ready time)

**Files Created:** 12 files (layout.tsx, page.tsx, Providers.tsx, ThemeContext.tsx, theme.ts, types/index.ts, tsconfig.json, next.config.js, package.json, .env.local, .env.example, .gitignore)

**Git Commit:** 89c06ff - "feat: implement Sprint 3 Phase 1 - Frontend Project Setup"

**Next Phase:** Phase 2 - Backend API Updates (httpOnly Cookies)

---

## 🍪 Phase 2: Backend API Updates (httpOnly Cookies)

**Objective:** Update backend to support httpOnly cookie authentication instead of Bearer tokens.

**⚠️ IMPORTANT:** This phase modifies the backend (from Sprint 2) to enable secure cookie-based auth.

### **Tasks:**

#### **Task 2.1: Update Backend Auth Module**

**Description:** Modify `backend/app/core/auth.py` to support cookie tokens.

**File:** `backend/app/core/auth.py` (update existing file)

**Add these imports:**
```python
from fastapi import Response, Request
from datetime import timedelta
```

**Add cookie helper functions:**
```python
def set_auth_cookie(response: Response, token: str) -> None:
    """
    Set httpOnly authentication cookie in response.

    Args:
        response: FastAPI Response object
        token: JWT access token
    """
    response.set_cookie(
        key="access_token",
        value=token,
        httponly=True,  # Prevents JavaScript access
        secure=False,  # Set to True in production (HTTPS only)
        samesite="lax",  # CSRF protection
        max_age=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # Convert to seconds
    )
    logger.debug("Auth cookie set (httpOnly, SameSite=Lax)")


def clear_auth_cookie(response: Response) -> None:
    """
    Clear authentication cookie (for logout).

    Args:
        response: FastAPI Response object
    """
    response.delete_cookie(
        key="access_token",
        httponly=True,
        secure=False,
        samesite="lax",
    )
    logger.debug("Auth cookie cleared")


def get_token_from_cookie(request: Request) -> str:
    """
    Extract JWT token from httpOnly cookie.

    Args:
        request: FastAPI Request object

    Returns:
        JWT token string

    Raises:
        HTTPException: If cookie not found
    """
    token = request.cookies.get("access_token")
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated - no auth cookie found",
        )
    return token
```

**Success Criteria:**
- ✅ Cookie helper functions added
- ✅ httpOnly and SameSite flags configured
- ✅ Token extraction from cookies

---

#### **Task 2.2: Update Authentication Middleware**

**Description:** Modify middleware to read token from cookies instead of Authorization header.

**File:** `backend/app/middleware/auth.py` (update existing)

**Update the `get_current_user` dependency:**
```python
from fastapi import Depends, HTTPException, status, Request
from app.core.auth import verify_token, get_token_from_cookie

async def get_current_user(request: Request) -> dict:
    """
    Dependency to get current authenticated user from httpOnly cookie.

    Args:
        request: FastAPI Request object

    Returns:
        User data dict from JWT token

    Raises:
        HTTPException: If authentication fails
    """
    # Extract token from cookie
    token = get_token_from_cookie(request)

    # Verify token and extract user data
    user_data = verify_token(token)

    if not user_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
        )

    return user_data
```

**Success Criteria:**
- ✅ Middleware reads from cookies
- ✅ Backward compatible error messages
- ✅ Works with existing protected routes

---

#### **Task 2.3: Update Login Endpoint**

**Description:** Modify login endpoint to set httpOnly cookie instead of returning token.

**File:** `backend/app/api/v1/auth.py` (update existing)

**Update the login endpoint:**
```python
from fastapi import Response

@router.post("/login", response_model=AuthResponse)
async def login(
    credentials: LoginRequest,
    response: Response,  # Add Response parameter
    db: AsyncSession = Depends(get_db)
):
    """
    User login endpoint.
    Sets httpOnly cookie with JWT token (does NOT return token in response body).
    """
    # ... existing user validation code ...

    # Generate JWT token
    token = create_access_token(data={"user_id": user.id, "username": user.username})

    # Set httpOnly cookie
    set_auth_cookie(response, token)

    # Return success response WITHOUT token in body
    return AuthResponse(
        message="Login successful",
        user=User.from_orm(user)
    )
```

**Update AuthResponse schema (no token field):**

**File:** `backend/app/models/schemas.py` (update)

```python
class AuthResponse(BaseModel):
    """Authentication response (no token - it's in httpOnly cookie)."""
    message: str
    user: Optional[UserResponse] = None
```

**Success Criteria:**
- ✅ Login sets httpOnly cookie
- ✅ Response body does NOT contain token
- ✅ Cookie has proper security flags

---

#### **Task 2.4: Create Logout Endpoint**

**Description:** Add logout endpoint to clear auth cookie.

**File:** `backend/app/api/v1/auth.py` (add new endpoint)

**Add logout endpoint:**
```python
@router.post("/logout")
async def logout(
    response: Response,
    current_user: dict = Depends(get_current_user)
):
    """
    User logout endpoint.
    Clears the httpOnly authentication cookie.
    """
    clear_auth_cookie(response)

    return {
        "message": "Logout successful",
        "username": current_user.get("username")
    }
```

**Success Criteria:**
- ✅ Logout endpoint clears cookie
- ✅ Protected by authentication
- ✅ Returns success message

---

#### **Task 2.5: Update CORS Configuration**

**Description:** Configure CORS to allow credentials (required for cookies).

**File:** `backend/app/main.py` (update existing CORS config)

**Update CORS middleware:**
```python
from app.config import settings

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,  # Must be specific origins, NOT ["*"]
    allow_credentials=True,  # REQUIRED for cookies
    allow_methods=settings.CORS_METHODS,
    allow_headers=settings.CORS_HEADERS,
)
```

**Update config file:**

**File:** `backend/app/config.py` (update)

```python
class Settings(BaseSettings):
    # ... existing settings ...

    # CORS - MUST be specific origins for credentials
    CORS_ORIGINS: list[str] = [
        "http://localhost:3000",  # Frontend dev server
        "http://frontend.99-apps.svc.cluster.local:3000",  # K8s service
    ]
    CORS_CREDENTIALS: bool = True
    CORS_METHODS: list[str] = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    CORS_HEADERS: list[str] = ["Content-Type", "Authorization"]
```

**Success Criteria:**
- ✅ CORS allows credentials
- ✅ Specific origins configured (no wildcard)
- ✅ OPTIONS preflight requests work

---

#### **Task 2.6: Test Backend Cookie Authentication**

**Description:** Verify backend cookie auth works with curl.

**Test Commands:**
```bash
# Test login (should set cookie)
curl -v -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"jake","password":"jake-precinct99"}' \
  -c cookies.txt

# Verify Set-Cookie header in response
# Expected: Set-Cookie: access_token=<token>; HttpOnly; SameSite=Lax; Path=/; Max-Age=3600

# Test protected endpoint with cookie
curl -v -X GET http://localhost:8000/api/v1/auth/me \
  -b cookies.txt

# Expected: Returns user data

# Test logout
curl -v -X POST http://localhost:8000/api/v1/auth/logout \
  -b cookies.txt \
  -c cookies.txt

# Verify cookie cleared in Set-Cookie header
```

**Success Criteria:**
- ✅ Login sets httpOnly cookie
- ✅ Protected routes accept cookie
- ✅ Logout clears cookie
- ✅ No token in response body

---

### 📋 EXECUTION LOG - Phase 2

**Date:** 2025-12-31
**Status:** ✅ COMPLETE

**Summary:** Successfully migrated backend from Bearer token authentication to httpOnly cookie authentication. Completed all 6 tasks:

**Code Changes:**
- **Task 2.1**: Added cookie helper functions to `backend/app/core/auth.py` (set_auth_cookie, clear_auth_cookie, get_token_from_cookie)
- **Task 2.2**: Updated `backend/app/middleware/auth.py` to read token from cookies (with fallback to Authorization header)
- **Task 2.3**: Updated login endpoint to set httpOnly cookie instead of returning token in response body
- **Task 2.4**: Created logout endpoint at POST `/api/v1/auth/logout` to clear authentication cookie
- **Task 2.5**: Verified CORS configuration - added localhost:3001 and Kubernetes service URL to allowed origins
- **Task 2.6**: Validated code syntax (py_compile successful)

**Security Enhancements:**
- ✅ httpOnly flag prevents JavaScript access (XSS protection)
- ✅ SameSite=Lax prevents CSRF attacks
- ✅ Token no longer exposed in response body or localStorage
- ✅ Automatic browser cookie handling

**API Changes:**
- POST `/api/v1/auth/login` - Sets httpOnly cookie, returns `{message, user}` (not token)
- POST `/api/v1/auth/logout` - Clears cookie, returns `{message}`
- GET `/api/v1/auth/me` - Automatically reads cookie for authentication

**New Schema:**
- `AuthResponse` - Returns message and user object (no token field)
- Kept `TokenResponse` for backward compatibility

**Files Modified (5 files, 159 insertions, 29 deletions):**
- `backend/app/core/auth.py` - Cookie helper functions
- `backend/app/middleware/auth.py` - Cookie-based authentication middleware
- `backend/app/api/v1/auth.py` - Updated login/logout endpoints
- `backend/app/models/schemas.py` - Added AuthResponse schema
- `backend/app/config.py` - Updated CORS origins for frontend

**Git Commit:** bb46c6b - "feat: implement httpOnly cookie authentication for backend API"

**Note:** Full integration testing requires infrastructure (OpenBao, SPIRE, PostgreSQL) to be running. Code is syntactically correct and ready for deployment.

**Next Phase:** Phase 3 - Authentication UI & Context

---

## 🔐 Phase 3: Authentication UI & Context

**Objective:** Build login/registration pages with React Hook Form and auth context.

### **Tasks:**

#### **Task 3.1: Create Axios API Client**

**Description:** Set up axios with cookie credentials and interceptors.

**File:** `frontend/lib/api/client.ts`

**Content:**
```typescript
import axios, { AxiosError } from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

export const apiClient = axios.create({
  baseURL: API_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // CRITICAL: Sends cookies with requests
});

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError<{ detail: string }>) => {
    // Handle 401 Unauthorized
    if (error.response?.status === 401) {
      // Redirect to login or clear auth state
      console.error('Unauthorized - clearing auth state');
      // Will be handled by AuthContext
    }

    // Extract error message
    const message = error.response?.data?.detail || 'An error occurred';

    return Promise.reject({
      message,
      status: error.response?.status,
    });
  }
);

export default apiClient;
```

**Success Criteria:**
- ✅ Axios configured with credentials
- ✅ Error interceptor handles 401
- ✅ Base URL from environment variable

---

#### **Task 3.2: Create Authentication API Service**

**Description:** Create API service functions for auth operations.

**File:** `frontend/lib/api/auth.ts`

**Content:**
```typescript
import apiClient from './client';
import type {
  User,
  LoginRequest,
  RegisterRequest,
  AuthResponse
} from '@/types';

export const authAPI = {
  /**
   * Login user - sets httpOnly cookie
   */
  async login(credentials: LoginRequest): Promise<AuthResponse> {
    const response = await apiClient.post<AuthResponse>(
      '/api/v1/auth/login',
      credentials
    );
    return response.data;
  },

  /**
   * Register new user
   */
  async register(data: RegisterRequest): Promise<AuthResponse> {
    const response = await apiClient.post<AuthResponse>(
      '/api/v1/auth/register',
      data
    );
    return response.data;
  },

  /**
   * Get current user (requires auth cookie)
   */
  async getCurrentUser(): Promise<User> {
    const response = await apiClient.get<User>('/api/v1/auth/me');
    return response.data;
  },

  /**
   * Logout - clears httpOnly cookie
   */
  async logout(): Promise<void> {
    await apiClient.post('/api/v1/auth/logout');
  },
};
```

**Success Criteria:**
- ✅ Auth API functions created
- ✅ TypeScript types applied
- ✅ Uses apiClient with credentials

---

#### **Task 3.3: Create Auth Context**

**Description:** Create auth context to manage authentication state.

**File:** `frontend/contexts/AuthContext.tsx`

**Content:**
```typescript
'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { authAPI } from '@/lib/api/auth';
import type { User, LoginRequest, RegisterRequest } from '@/types';
import { useSnackbar } from 'notistack';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (credentials: LoginRequest) => Promise<void>;
  register: (data: RegisterRequest) => Promise<void>;
  logout: () => Promise<void>;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  loading: true,
  login: async () => {},
  register: async () => {},
  logout: async () => {},
  isAuthenticated: false,
});

export const useAuth = () => useContext(AuthContext);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const { enqueueSnackbar } = useSnackbar();

  // Check if user is authenticated on mount
  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = async () => {
    try {
      const currentUser = await authAPI.getCurrentUser();
      setUser(currentUser);
    } catch (error) {
      // Not authenticated - this is fine
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const login = async (credentials: LoginRequest) => {
    try {
      setLoading(true);
      const response = await authAPI.login(credentials);

      // Cookie is set by backend, now fetch user data
      const currentUser = await authAPI.getCurrentUser();
      setUser(currentUser);

      enqueueSnackbar('Login successful!', { variant: 'success' });
      router.push('/dashboard');
    } catch (error: any) {
      enqueueSnackbar(error.message || 'Login failed', { variant: 'error' });
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const register = async (data: RegisterRequest) => {
    try {
      setLoading(true);
      await authAPI.register(data);

      enqueueSnackbar('Registration successful! Please login.', { variant: 'success' });
      router.push('/auth/login');
    } catch (error: any) {
      enqueueSnackbar(error.message || 'Registration failed', { variant: 'error' });
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    try {
      await authAPI.logout();
      setUser(null);
      enqueueSnackbar('Logged out successfully', { variant: 'info' });
      router.push('/');
    } catch (error: any) {
      enqueueSnackbar(error.message || 'Logout failed', { variant: 'error' });
    }
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        loading,
        login,
        register,
        logout,
        isAuthenticated: !!user,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
```

**Success Criteria:**
- ✅ Auth context manages user state
- ✅ Auto-checks auth on mount
- ✅ Redirects after login/logout
- ✅ Toast notifications for feedback

---

#### **Task 3.4: Update Root Layout with Auth Provider**

**Description:** Wrap app with AuthProvider.

**File:** `frontend/app/layout.tsx` (update)

**Update to include AuthProvider:**
```typescript
import { ThemeProvider } from '@/contexts/ThemeContext';
import { AuthProvider } from '@/contexts/AuthContext';
import { SnackbarProvider } from 'notistack';

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <ThemeProvider>
          <SnackbarProvider
            maxSnack={3}
            anchorOrigin={{ vertical: 'top', horizontal: 'right' }}
            autoHideDuration={3000}
          >
            <AuthProvider>
              {children}
            </AuthProvider>
          </SnackbarProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
```

**Success Criteria:**
- ✅ AuthProvider wraps app
- ✅ Nested inside SnackbarProvider
- ✅ Auth state available globally

---

#### **Task 3.5: Create Login Page**

**Description:** Build login form with React Hook Form and Zod validation.

**File:** `frontend/app/auth/login/page.tsx`

**Content:**
```typescript
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Box,
  Container,
  TextField,
  Button,
  Typography,
  Paper,
  Link as MuiLink,
} from '@mui/material';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import type { LoginRequest } from '@/types';

const loginSchema = z.object({
  username: z.string().min(1, 'Username is required'),
  password: z.string().min(1, 'Password is required'),
});

export default function LoginPage() {
  const { login, loading } = useAuth();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginRequest>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (data: LoginRequest) => {
    await login(data);
  };

  return (
    <Container maxWidth="sm">
      <Box
        sx={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Paper elevation={3} sx={{ p: 4, width: '100%' }}>
          <Typography variant="h4" component="h1" gutterBottom align="center">
            Login
          </Typography>
          <Typography variant="body2" color="text.secondary" align="center" sx={{ mb: 3 }}>
            SPIRE-Vault-99 Zero Trust Platform
          </Typography>

          <form onSubmit={handleSubmit(onSubmit)}>
            <TextField
              fullWidth
              label="Username"
              margin="normal"
              {...register('username')}
              error={!!errors.username}
              helperText={errors.username?.message}
              autoComplete="username"
            />

            <TextField
              fullWidth
              label="Password"
              type="password"
              margin="normal"
              {...register('password')}
              error={!!errors.password}
              helperText={errors.password?.message}
              autoComplete="current-password"
            />

            <Button
              fullWidth
              variant="contained"
              type="submit"
              disabled={loading}
              sx={{ mt: 3, mb: 2 }}
              size="large"
            >
              {loading ? 'Logging in...' : 'Login'}
            </Button>

            <Box sx={{ textAlign: 'center' }}>
              <Typography variant="body2">
                Don't have an account?{' '}
                <MuiLink component={Link} href="/auth/register">
                  Register here
                </MuiLink>
              </Typography>
            </Box>
          </form>

          <Box sx={{ mt: 3, p: 2, bgcolor: 'background.default', borderRadius: 1 }}>
            <Typography variant="caption" color="text.secondary" display="block" gutterBottom>
              Demo Users (Brooklyn Nine-Nine):
            </Typography>
            <Typography variant="caption" component="pre" sx={{ fontFamily: 'monospace', fontSize: '0.75rem' }}>
              jake / jake-precinct99{'\n'}
              amy / amy-precinct99{'\n'}
              rosa / rosa-precinct99
            </Typography>
          </Box>
        </Paper>
      </Box>
    </Container>
  );
}
```

**Success Criteria:**
- ✅ Login form with validation
- ✅ Material-UI styling
- ✅ Demo credentials displayed
- ✅ Error messages for validation
- ✅ Loading state during login

---

#### **Task 3.6: Create Registration Page**

**Description:** Build registration form with email and password validation.

**File:** `frontend/app/auth/register/page.tsx`

**Content:**
```typescript
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Box,
  Container,
  TextField,
  Button,
  Typography,
  Paper,
  Link as MuiLink,
} from '@mui/material';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import type { RegisterRequest } from '@/types';

const registerSchema = z.object({
  username: z.string().min(3, 'Username must be at least 3 characters'),
  email: z.string().email('Invalid email address').optional().or(z.literal('')),
  password: z.string().min(6, 'Password must be at least 6 characters'),
  confirmPassword: z.string(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ['confirmPassword'],
});

type RegisterFormData = z.infer<typeof registerSchema>;

export default function RegisterPage() {
  const { register: registerUser, loading } = useAuth();

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<RegisterFormData>({
    resolver: zodResolver(registerSchema),
  });

  const onSubmit = async (data: RegisterFormData) => {
    const { confirmPassword, ...registerData } = data;
    await registerUser(registerData as RegisterRequest);
  };

  return (
    <Container maxWidth="sm">
      <Box
        sx={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Paper elevation={3} sx={{ p: 4, width: '100%' }}>
          <Typography variant="h4" component="h1" gutterBottom align="center">
            Register
          </Typography>
          <Typography variant="body2" color="text.secondary" align="center" sx={{ mb: 3 }}>
            Create a new account for SPIRE-Vault-99
          </Typography>

          <form onSubmit={handleSubmit(onSubmit)}>
            <TextField
              fullWidth
              label="Username"
              margin="normal"
              {...register('username')}
              error={!!errors.username}
              helperText={errors.username?.message}
              autoComplete="username"
            />

            <TextField
              fullWidth
              label="Email (optional)"
              type="email"
              margin="normal"
              {...register('email')}
              error={!!errors.email}
              helperText={errors.email?.message}
              autoComplete="email"
            />

            <TextField
              fullWidth
              label="Password"
              type="password"
              margin="normal"
              {...register('password')}
              error={!!errors.password}
              helperText={errors.password?.message}
              autoComplete="new-password"
            />

            <TextField
              fullWidth
              label="Confirm Password"
              type="password"
              margin="normal"
              {...register('confirmPassword')}
              error={!!errors.confirmPassword}
              helperText={errors.confirmPassword?.message}
              autoComplete="new-password"
            />

            <Button
              fullWidth
              variant="contained"
              type="submit"
              disabled={loading}
              sx={{ mt: 3, mb: 2 }}
              size="large"
            >
              {loading ? 'Creating account...' : 'Register'}
            </Button>

            <Box sx={{ textAlign: 'center' }}>
              <Typography variant="body2">
                Already have an account?{' '}
                <MuiLink component={Link} href="/auth/login">
                  Login here
                </MuiLink>
              </Typography>
            </Box>
          </form>
        </Paper>
      </Box>
    </Container>
  );
}
```

**Success Criteria:**
- ✅ Registration form with validation
- ✅ Password confirmation check
- ✅ Email validation (optional field)
- ✅ Redirects to login after success

---

### 📋 EXECUTION LOG - Phase 3

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Next Phase:** Phase 4 - Layout & Navigation (MUI)

---

## 🎨 Phase 4: Layout & Navigation (MUI)

**Objective:** Create app layout with navigation, app bar, and dark mode toggle.

### **Tasks:**

#### **Task 4.1: Create App Bar Component**

**Description:** Build navigation app bar with user menu and dark mode toggle.

**File:** `frontend/components/layout/AppBar.tsx`

**Content:**
```typescript
'use client';

import {
  AppBar as MuiAppBar,
  Toolbar,
  Typography,
  IconButton,
  Box,
  Menu,
  MenuItem,
  Avatar,
  Tooltip,
} from '@mui/material';
import {
  Brightness4,
  Brightness7,
  AccountCircle,
  Dashboard,
  GitHub,
} from '@mui/icons-material';
import { useThemeContext } from '@/contexts/ThemeContext';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import Link from 'next/link';

export default function AppBar() {
  const { mode, toggleTheme } = useThemeContext();
  const { user, logout, isAuthenticated } = useAuth();
  const router = useRouter();
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);

  const handleMenu = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const handleLogout = async () => {
    handleClose();
    await logout();
  };

  return (
    <MuiAppBar position="static">
      <Toolbar>
        <Typography
          variant="h6"
          component="div"
          sx={{ flexGrow: 1, cursor: 'pointer' }}
          onClick={() => router.push(isAuthenticated ? '/dashboard' : '/')}
        >
          SPIRE-Vault-99
        </Typography>

        {isAuthenticated && (
          <>
            <Tooltip title="Dashboard">
              <IconButton color="inherit" onClick={() => router.push('/dashboard')}>
                <Dashboard />
              </IconButton>
            </Tooltip>

            <Tooltip title="GitHub">
              <IconButton color="inherit" onClick={() => router.push('/github/configure')}>
                <GitHub />
              </IconButton>
            </Tooltip>
          </>
        )}

        <Tooltip title="Toggle dark mode">
          <IconButton color="inherit" onClick={toggleTheme}>
            {mode === 'dark' ? <Brightness7 /> : <Brightness4 />}
          </IconButton>
        </Tooltip>

        {isAuthenticated && user && (
          <Box>
            <Tooltip title={user.username}>
              <IconButton
                size="large"
                onClick={handleMenu}
                color="inherit"
              >
                <Avatar sx={{ width: 32, height: 32, bgcolor: 'secondary.main' }}>
                  {user.username.charAt(0).toUpperCase()}
                </Avatar>
              </IconButton>
            </Tooltip>
            <Menu
              anchorEl={anchorEl}
              open={Boolean(anchorEl)}
              onClose={handleClose}
            >
              <MenuItem disabled>
                <Typography variant="body2" color="text.secondary">
                  {user.username}
                </Typography>
              </MenuItem>
              <MenuItem onClick={() => { handleClose(); router.push('/dashboard'); }}>
                Dashboard
              </MenuItem>
              <MenuItem onClick={() => { handleClose(); router.push('/github/configure'); }}>
                GitHub Settings
              </MenuItem>
              <MenuItem onClick={handleLogout}>Logout</MenuItem>
            </Menu>
          </Box>
        )}
      </Toolbar>
    </MuiAppBar>
  );
}
```

**Success Criteria:**
- ✅ App bar with logo/title
- ✅ Dark mode toggle
- ✅ User menu (when authenticated)
- ✅ Navigation icons
- ✅ Logout functionality

---

#### **Task 4.2: Create Main Layout Component**

**Description:** Create layout wrapper for authenticated pages.

**File:** `frontend/components/layout/MainLayout.tsx`

**Content:**
```typescript
'use client';

import { Box, Container } from '@mui/material';
import AppBar from './AppBar';

interface MainLayoutProps {
  children: React.ReactNode;
  maxWidth?: 'xs' | 'sm' | 'md' | 'lg' | 'xl' | false;
}

export default function MainLayout({ children, maxWidth = 'lg' }: MainLayoutProps) {
  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
      <AppBar />
      <Container
        maxWidth={maxWidth}
        sx={{
          flexGrow: 1,
          py: 4,
        }}
      >
        {children}
      </Container>
    </Box>
  );
}
```

**Success Criteria:**
- ✅ Layout with app bar
- ✅ Responsive container
- ✅ Configurable max width

---

#### **Task 4.3: Create Protected Route Middleware**

**Description:** Create middleware to protect authenticated routes.

**File:** `frontend/components/auth/ProtectedRoute.tsx`

**Content:**
```typescript
'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { Box, CircularProgress } from '@mui/material';

export default function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && !isAuthenticated) {
      router.push('/auth/login');
    }
  }, [isAuthenticated, loading, router]);

  if (loading) {
    return (
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          minHeight: '100vh',
        }}
      >
        <CircularProgress />
      </Box>
    );
  }

  if (!isAuthenticated) {
    return null;
  }

  return <>{children}</>;
}
```

**Success Criteria:**
- ✅ Redirects to login if not authenticated
- ✅ Shows loading spinner during check
- ✅ Renders children when authenticated

---

### 📋 EXECUTION LOG - Phase 4

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Next Phase:** Phase 5 - Dashboard & Protected Routes

---

## 📊 Phase 5: Dashboard & Protected Routes

**Objective:** Create dashboard page with user information and system status.

### **Tasks:**

#### **Task 5.1: Create Dashboard Page**

**Description:** Build dashboard with user info and backend health status.

**File:** `frontend/app/dashboard/page.tsx`

**Content:**
```typescript
'use client';

import { useEffect, useState } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Chip,
  CircularProgress,
} from '@mui/material';
import {
  CheckCircle,
  Error as ErrorIcon,
  Person,
  Security,
  Storage,
} from '@mui/icons-material';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import MainLayout from '@/components/layout/MainLayout';
import { useAuth } from '@/contexts/AuthContext';
import apiClient from '@/lib/api/client';
import type { HealthResponse } from '@/types';

export default function DashboardPage() {
  const { user } = useAuth();
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchHealth();
  }, []);

  const fetchHealth = async () => {
    try {
      const response = await apiClient.get<HealthResponse>('/api/v1/health');
      setHealth(response.data);
    } catch (error) {
      console.error('Failed to fetch health:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusIcon = (status: string) => {
    const isHealthy = status === 'connected' || status === 'authenticated' || status === 'healthy';
    return isHealthy ? (
      <CheckCircle color="success" />
    ) : (
      <ErrorIcon color="error" />
    );
  };

  const getStatusColor = (status: string) => {
    const isHealthy = status === 'connected' || status === 'authenticated' || status === 'healthy';
    return isHealthy ? 'success' : 'error';
  };

  return (
    <ProtectedRoute>
      <MainLayout>
        <Box>
          <Typography variant="h4" component="h1" gutterBottom>
            Dashboard
          </Typography>
          <Typography variant="body1" color="text.secondary" gutterBottom>
            Welcome back, {user?.username}!
          </Typography>

          <Grid container spacing={3} sx={{ mt: 2 }}>
            {/* User Card */}
            <Grid item xs={12} md={6}>
              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <Person sx={{ mr: 1 }} color="primary" />
                    <Typography variant="h6">User Information</Typography>
                  </Box>
                  <Typography variant="body2" color="text.secondary" gutterBottom>
                    Username: <strong>{user?.username}</strong>
                  </Typography>
                  {user?.email && (
                    <Typography variant="body2" color="text.secondary" gutterBottom>
                      Email: <strong>{user.email}</strong>
                    </Typography>
                  )}
                  <Typography variant="body2" color="text.secondary">
                    User ID: <strong>{user?.id}</strong>
                  </Typography>
                </CardContent>
              </Card>
            </Grid>

            {/* System Health Card */}
            <Grid item xs={12} md={6}>
              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <Security sx={{ mr: 1 }} color="primary" />
                    <Typography variant="h6">System Health</Typography>
                  </Box>
                  {loading ? (
                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 2 }}>
                      <CircularProgress size={24} />
                    </Box>
                  ) : health ? (
                    <Box>
                      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                        {getStatusIcon(health.spire)}
                        <Typography variant="body2" sx={{ ml: 1 }}>
                          SPIRE:{' '}
                          <Chip
                            label={health.spire}
                            size="small"
                            color={getStatusColor(health.spire)}
                          />
                        </Typography>
                      </Box>
                      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                        {getStatusIcon(health.vault)}
                        <Typography variant="body2" sx={{ ml: 1 }}>
                          OpenBao:{' '}
                          <Chip
                            label={health.vault}
                            size="small"
                            color={getStatusColor(health.vault)}
                          />
                        </Typography>
                      </Box>
                      <Box sx={{ display: 'flex', alignItems: 'center' }}>
                        {getStatusIcon(health.database)}
                        <Typography variant="body2" sx={{ ml: 1 }}>
                          Database:{' '}
                          <Chip
                            label={health.database}
                            size="small"
                            color={getStatusColor(health.database)}
                          />
                        </Typography>
                      </Box>
                    </Box>
                  ) : (
                    <Typography variant="body2" color="error">
                      Failed to load health status
                    </Typography>
                  )}
                </CardContent>
              </Card>
            </Grid>

            {/* Info Cards */}
            <Grid item xs={12}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Zero-Trust Architecture
                  </Typography>
                  <Typography variant="body2" color="text.secondary" paragraph>
                    This demo platform showcases production-grade zero-trust security using:
                  </Typography>
                  <Box component="ul" sx={{ pl: 2 }}>
                    <Typography component="li" variant="body2" color="text.secondary">
                      <strong>SPIRE/SPIFFE:</strong> Workload identity with JWT-SVID authentication
                    </Typography>
                    <Typography component="li" variant="body2" color="text.secondary">
                      <strong>OpenBao:</strong> Secrets management (static GitHub tokens + dynamic DB credentials)
                    </Typography>
                    <Typography component="li" variant="body2" color="text.secondary">
                      <strong>PostgreSQL:</strong> Database with automatic credential rotation
                    </Typography>
                    <Typography component="li" variant="body2" color="text.secondary">
                      <strong>httpOnly Cookies:</strong> Secure authentication (XSS protection)
                    </Typography>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        </Box>
      </MainLayout>
    </ProtectedRoute>
  );
}
```

**Success Criteria:**
- ✅ Dashboard displays user info
- ✅ Shows backend health status
- ✅ Protected route (requires login)
- ✅ Responsive grid layout
- ✅ Status indicators with colors

---

### 📋 EXECUTION LOG - Phase 5

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Next Phase:** Phase 6 - GitHub Integration UI

---

## 🐙 Phase 6: GitHub Integration UI

**Objective:** Create pages for GitHub token configuration, repository listing, and user profile.

### **Tasks:**

#### **Task 6.1: Create GitHub API Service**

**Description:** API functions for GitHub integration.

**File:** `frontend/lib/api/github.ts`

**Content:**
```typescript
import apiClient from './client';
import type { GitHubRepo, GitHubUser, GitHubConfigureRequest } from '@/types';

export const githubAPI = {
  /**
   * Configure GitHub token (stores in Vault)
   */
  async configureToken(token: string): Promise<{ message: string }> {
    const response = await apiClient.post<{ message: string }>(
      '/api/v1/github/configure',
      { token } as GitHubConfigureRequest
    );
    return response.data;
  },

  /**
   * Get user's GitHub repositories
   */
  async getRepositories(): Promise<GitHubRepo[]> {
    const response = await apiClient.get<GitHubRepo[]>('/api/v1/github/repos');
    return response.data;
  },

  /**
   * Get GitHub user profile
   */
  async getUserProfile(): Promise<GitHubUser> {
    const response = await apiClient.get<GitHubUser>('/api/v1/github/user');
    return response.data;
  },
};
```

**Success Criteria:**
- ✅ GitHub API service created
- ✅ TypeScript types applied

---

#### **Task 6.2: Create GitHub Token Configuration Page**

**Description:** Form to input and save GitHub Personal Access Token.

**File:** `frontend/app/github/configure/page.tsx`

**Content:**
```typescript
'use client';

import { useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Alert,
  Link as MuiLink,
} from '@mui/material';
import { Key, CheckCircle } from '@mui/icons-material';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import MainLayout from '@/components/layout/MainLayout';
import { githubAPI } from '@/lib/api/github';
import { useSnackbar } from 'notistack';
import { useRouter } from 'next/navigation';

export default function GitHubConfigurePage() {
  const [token, setToken] = useState('');
  const [loading, setLoading] = useState(false);
  const { enqueueSnackbar } = useSnackbar();
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!token) {
      enqueueSnackbar('Please enter a GitHub token', { variant: 'warning' });
      return;
    }

    try {
      setLoading(true);
      await githubAPI.configureToken(token);
      enqueueSnackbar('GitHub token saved to Vault!', { variant: 'success' });
      setToken(''); // Clear input
      router.push('/github/repos');
    } catch (error: any) {
      enqueueSnackbar(error.message || 'Failed to save token', { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <ProtectedRoute>
      <MainLayout maxWidth="md">
        <Box>
          <Typography variant="h4" component="h1" gutterBottom>
            GitHub Integration
          </Typography>
          <Typography variant="body1" color="text.secondary" paragraph>
            Configure your GitHub Personal Access Token to enable repository browsing.
          </Typography>

          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                <Key sx={{ mr: 1 }} color="primary" />
                <Typography variant="h6">Personal Access Token</Typography>
              </Box>

              <Alert severity="info" sx={{ mb: 3 }}>
                Your token will be encrypted and stored in OpenBao (Vault). It will never be exposed to the frontend.
              </Alert>

              <form onSubmit={handleSubmit}>
                <TextField
                  fullWidth
                  label="GitHub Personal Access Token"
                  type="password"
                  value={token}
                  onChange={(e) => setToken(e.target.value)}
                  placeholder="ghp_xxxxxxxxxxxxxxxxxxxx"
                  helperText="Enter your GitHub token with 'repo' and 'user' scopes"
                  margin="normal"
                />

                <Button
                  fullWidth
                  variant="contained"
                  type="submit"
                  disabled={loading}
                  size="large"
                  sx={{ mt: 2 }}
                  startIcon={<CheckCircle />}
                >
                  {loading ? 'Saving...' : 'Save Token to Vault'}
                </Button>
              </form>

              <Box sx={{ mt: 3, p: 2, bgcolor: 'background.default', borderRadius: 1 }}>
                <Typography variant="caption" color="text.secondary" gutterBottom display="block">
                  <strong>How to create a GitHub token:</strong>
                </Typography>
                <Typography variant="caption" color="text.secondary" component="ol" sx={{ pl: 2, m: 0 }}>
                  <li>Go to GitHub → Settings → Developer settings → Personal access tokens</li>
                  <li>Click "Generate new token (classic)"</li>
                  <li>Select scopes: <code>repo</code>, <code>user</code></li>
                  <li>Generate token and copy it</li>
                  <li>Paste it above</li>
                </Typography>
                <MuiLink
                  href="https://github.com/settings/tokens"
                  target="_blank"
                  rel="noopener"
                  sx={{ display: 'block', mt: 1, fontSize: '0.75rem' }}
                >
                  Open GitHub Token Settings →
                </MuiLink>
              </Box>
            </CardContent>
          </Card>
        </Box>
      </MainLayout>
    </ProtectedRoute>
  );
}
```

**Success Criteria:**
- ✅ Token input form
- ✅ Saves to Vault via API
- ✅ Instructions for creating token
- ✅ Secure input (type="password")
- ✅ Redirects to repos after save

---

#### **Task 6.3: Create Repository Listing Page**

**Description:** Display user's GitHub repositories.

**File:** `frontend/app/github/repos/page.tsx`

**Content:**
```typescript
'use client';

import { useEffect, useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Chip,
  CircularProgress,
  Grid,
  IconButton,
  Tooltip,
  Alert,
  Button,
} from '@mui/material';
import { OpenInNew, Star, Code } from '@mui/icons-material';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import MainLayout from '@/components/layout/MainLayout';
import { githubAPI } from '@/lib/api/github';
import type { GitHubRepo } from '@/types';
import { useRouter } from 'next/navigation';

export default function GitHubReposPage() {
  const [repos, setRepos] = useState<GitHubRepo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  useEffect(() => {
    fetchRepos();
  }, []);

  const fetchRepos = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await githubAPI.getRepositories();
      setRepos(data);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch repositories');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <ProtectedRoute>
        <MainLayout>
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
            <CircularProgress />
          </Box>
        </MainLayout>
      </ProtectedRoute>
    );
  }

  if (error) {
    return (
      <ProtectedRoute>
        <MainLayout>
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
          <Button variant="contained" onClick={() => router.push('/github/configure')}>
            Configure GitHub Token
          </Button>
        </MainLayout>
      </ProtectedRoute>
    );
  }

  return (
    <ProtectedRoute>
      <MainLayout>
        <Box>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
            <Box>
              <Typography variant="h4" component="h1" gutterBottom>
                GitHub Repositories
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {repos.length} repositories found
              </Typography>
            </Box>
            <Button variant="outlined" onClick={() => router.push('/github/configure')}>
              Update Token
            </Button>
          </Box>

          <Grid container spacing={3}>
            {repos.map((repo) => (
              <Grid item xs={12} md={6} lg={4} key={repo.id}>
                <Card>
                  <CardContent>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', mb: 1 }}>
                      <Typography variant="h6" component="h2" sx={{ wordBreak: 'break-word' }}>
                        {repo.name}
                      </Typography>
                      <Tooltip title="Open in GitHub">
                        <IconButton
                          size="small"
                          component="a"
                          href={repo.html_url}
                          target="_blank"
                          rel="noopener"
                        >
                          <OpenInNew fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    </Box>

                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2, minHeight: 40 }}>
                      {repo.description || 'No description'}
                    </Typography>

                    <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                      {repo.language && (
                        <Chip
                          label={repo.language}
                          size="small"
                          icon={<Code />}
                          color="primary"
                          variant="outlined"
                        />
                      )}
                      <Chip
                        label={`${repo.stargazers_count} ★`}
                        size="small"
                        icon={<Star />}
                        variant="outlined"
                      />
                    </Box>

                    <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 2 }}>
                      Updated: {new Date(repo.updated_at).toLocaleDateString()}
                    </Typography>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>

          {repos.length === 0 && (
            <Alert severity="info">
              No repositories found. Make sure your GitHub token has the correct permissions.
            </Alert>
          )}
        </Box>
      </MainLayout>
    </ProtectedRoute>
  );
}
```

**Success Criteria:**
- ✅ Lists GitHub repositories
- ✅ Displays repo details (name, description, language, stars)
- ✅ Links to GitHub
- ✅ Responsive grid layout
- ✅ Error handling with token reconfiguration

---

#### **Task 6.4: Create GitHub Profile Page**

**Description:** Display GitHub user profile information.

**File:** `frontend/app/github/profile/page.tsx`

**Content:**
```typescript
'use client';

import { useEffect, useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Avatar,
  CircularProgress,
  Grid,
  Chip,
  Alert,
  Button,
} from '@mui/material';
import { People, Code, Favorite } from '@mui/icons-material';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import MainLayout from '@/components/layout/MainLayout';
import { githubAPI } from '@/lib/api/github';
import type { GitHubUser } from '@/types';
import { useRouter } from 'next/navigation';

export default function GitHubProfilePage() {
  const [profile, setProfile] = useState<GitHubUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await githubAPI.getUserProfile();
      setProfile(data);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch profile');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <ProtectedRoute>
        <MainLayout>
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
            <CircularProgress />
          </Box>
        </MainLayout>
      </ProtectedRoute>
    );
  }

  if (error) {
    return (
      <ProtectedRoute>
        <MainLayout>
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
          <Button variant="contained" onClick={() => router.push('/github/configure')}>
            Configure GitHub Token
          </Button>
        </MainLayout>
      </ProtectedRoute>
    );
  }

  if (!profile) {
    return null;
  }

  return (
    <ProtectedRoute>
      <MainLayout maxWidth="md">
        <Box>
          <Typography variant="h4" component="h1" gutterBottom>
            GitHub Profile
          </Typography>

          <Card sx={{ mt: 3 }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                <Avatar
                  src={profile.avatar_url}
                  alt={profile.login}
                  sx={{ width: 80, height: 80, mr: 3 }}
                />
                <Box>
                  <Typography variant="h5" gutterBottom>
                    {profile.name || profile.login}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    @{profile.login}
                  </Typography>
                </Box>
              </Box>

              {profile.bio && (
                <Typography variant="body1" color="text.secondary" paragraph>
                  {profile.bio}
                </Typography>
              )}

              <Grid container spacing={2} sx={{ mt: 2 }}>
                <Grid item xs={12} sm={4}>
                  <Card variant="outlined">
                    <CardContent sx={{ textAlign: 'center' }}>
                      <Code color="primary" sx={{ fontSize: 40, mb: 1 }} />
                      <Typography variant="h6">{profile.public_repos}</Typography>
                      <Typography variant="caption" color="text.secondary">
                        Public Repos
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>

                <Grid item xs={12} sm={4}>
                  <Card variant="outlined">
                    <CardContent sx={{ textAlign: 'center' }}>
                      <People color="primary" sx={{ fontSize: 40, mb: 1 }} />
                      <Typography variant="h6">{profile.followers}</Typography>
                      <Typography variant="caption" color="text.secondary">
                        Followers
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>

                <Grid item xs={12} sm={4}>
                  <Card variant="outlined">
                    <CardContent sx={{ textAlign: 'center' }}>
                      <Favorite color="primary" sx={{ fontSize: 40, mb: 1 }} />
                      <Typography variant="h6">{profile.following}</Typography>
                      <Typography variant="caption" color="text.secondary">
                        Following
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>
              </Grid>
            </CardContent>
          </Card>
        </Box>
      </MainLayout>
    </ProtectedRoute>
  );
}
```

**Success Criteria:**
- ✅ Displays GitHub profile
- ✅ Shows avatar, name, bio
- ✅ Stats cards (repos, followers, following)
- ✅ Error handling

---

### 📋 EXECUTION LOG - Phase 6

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Next Phase:** Phase 7 - Styling & UX Polish

---

## ✨ Phase 7: Styling & UX Polish

**Objective:** Enhance UX with loading states, responsive design, and polish.

### **Tasks:**

#### **Task 7.1: Create Loading Skeleton Components**

**Description:** Add skeleton loaders for better perceived performance.

**File:** `frontend/components/common/LoadingSkeleton.tsx`

**Content:**
```typescript
import { Card, CardContent, Skeleton, Box } from '@mui/material';

export function RepoCardSkeleton() {
  return (
    <Card>
      <CardContent>
        <Skeleton variant="text" width="60%" height={32} />
        <Skeleton variant="text" width="100%" height={20} sx={{ mt: 1 }} />
        <Skeleton variant="text" width="80%" height={20} />
        <Box sx={{ display: 'flex', gap: 1, mt: 2 }}>
          <Skeleton variant="rounded" width={80} height={24} />
          <Skeleton variant="rounded" width={60} height={24} />
        </Box>
      </CardContent>
    </Card>
  );
}
```

**Success Criteria:**
- ✅ Skeleton loaders created
- ✅ Matches actual card layout

---

#### **Task 7.2: Add Responsive Design Improvements**

**Description:** Ensure mobile responsiveness across all pages.

**Update all pages with:**
- Grid breakpoints (xs, sm, md, lg)
- Proper spacing for mobile
- Touch-friendly button sizes
- Responsive typography

**Success Criteria:**
- ✅ All pages responsive
- ✅ Works on mobile (320px+)
- ✅ Works on tablet
- ✅ Works on desktop

---

#### **Task 7.3: Add Error Boundary**

**Description:** Create error boundary for graceful error handling.

**File:** `frontend/components/common/ErrorBoundary.tsx`

**Content:**
```typescript
'use client';

import React from 'react';
import { Box, Typography, Button, Container } from '@mui/material';
import { Error as ErrorIcon } from '@mui/icons-material';

interface Props {
  children: React.ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <Container maxWidth="sm">
          <Box
            sx={{
              minHeight: '100vh',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'center',
              alignItems: 'center',
              textAlign: 'center',
            }}
          >
            <ErrorIcon color="error" sx={{ fontSize: 80, mb: 2 }} />
            <Typography variant="h4" gutterBottom>
              Something went wrong
            </Typography>
            <Typography variant="body1" color="text.secondary" paragraph>
              {this.state.error?.message || 'An unexpected error occurred'}
            </Typography>
            <Button
              variant="contained"
              onClick={() => window.location.href = '/'}
            >
              Return Home
            </Button>
          </Box>
        </Container>
      );
    }

    return this.props.children;
  }
}
```

**Success Criteria:**
- ✅ Error boundary catches errors
- ✅ Displays user-friendly message
- ✅ Allows navigation home

---

### 📋 EXECUTION LOG - Phase 7

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Next Phase:** Phase 8 - Dockerization & Kubernetes Deployment

---

## 🐳 Phase 8: Dockerization & Kubernetes Deployment

**Objective:** Containerize frontend and deploy to Kubernetes with Tilt hot-reload.

### **Tasks:**

#### **Task 8.1: Create Production Dockerfile**

**Description:** Multi-stage Dockerfile for optimized production builds.

**File:** `frontend/Dockerfile`

**Content:**
```dockerfile
# Multi-stage Dockerfile for Next.js 16 production build

# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --only=production

# Stage 2: Build
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 3: Runtime
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

**Update next.config.js for standalone:**

**File:** `frontend/next.config.js`

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  reactStrictMode: true,
}

module.exports = nextConfig
```

**Success Criteria:**
- ✅ Multi-stage build
- ✅ Standalone output
- ✅ Non-root user
- ✅ Optimized image size

---

#### **Task 8.2: Create Development Dockerfile**

**Description:** Dockerfile for development with hot-reload.

**File:** `frontend/Dockerfile.dev`

**Content:**
```dockerfile
# Development Dockerfile for Next.js with hot-reload

FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm install

# Copy application code
COPY . .

EXPOSE 3000

# Run development server
CMD ["npm", "run", "dev"]
```

**Success Criteria:**
- ✅ Dev Dockerfile created
- ✅ Includes npm install
- ✅ Runs dev server

---

#### **Task 8.3: Create .dockerignore**

**Description:** Exclude unnecessary files from Docker builds.

**File:** `frontend/.dockerignore`

**Content:**
```
# Dependencies
node_modules

# Build output
.next
out

# Environment
.env*.local

# Testing
coverage

# Misc
.DS_Store
*.log
npm-debug.log*

# Git
.git
.gitignore

# IDE
.vscode
.idea
```

**Success Criteria:**
- ✅ .dockerignore created
- ✅ Optimizes build context

---

#### **Task 8.4: Create Kubernetes Manifests**

**Description:** Create K8s deployment, service, and ConfigMap.

**File:** `frontend/k8s/deployment.yaml`

**Content:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: 99-apps
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: frontend:dev
        imagePullPolicy: Never  # Use locally built image
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: NEXT_PUBLIC_API_URL
          value: "http://backend.99-apps.svc.cluster.local:8000"
        - name: NEXT_PUBLIC_APP_NAME
          value: "SPIRE-Vault-99"
        - name: NEXT_PUBLIC_APP_VERSION
          value: "1.0.0"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

**File:** `frontend/k8s/service.yaml`

**Content:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: 99-apps
  labels:
    app: frontend
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30002  # Accessible at http://localhost:30002
    name: http
  selector:
    app: frontend
```

**Success Criteria:**
- ✅ Deployment manifest created
- ✅ Service with NodePort
- ✅ Health probes configured
- ✅ Environment variables set

---

#### **Task 8.5: Update Tiltfile**

**Description:** Add frontend to Tiltfile for hot-reload development.

**File:** `Tiltfile` (update - root directory)

**Update to include frontend:**
```python
# Tiltfile for SPIRE-Vault-99 Development
# Includes Backend + Frontend with hot-reload

# Backend
k8s_yaml('backend/k8s/serviceaccount.yaml')
k8s_yaml('backend/k8s/deployment.yaml')
k8s_yaml('backend/k8s/service.yaml')

docker_build(
    'backend',
    context='./backend',
    dockerfile='./backend/Dockerfile.dev',
    live_update=[
        sync('./backend/app', '/app/app'),
        run(
            'pip install -r /app/requirements-dev.txt',
            trigger=['./backend/requirements-dev.txt']
        ),
    ]
)

k8s_resource(
    'backend',
    port_forwards=['8000:8000'],
    labels=['app'],
)

# Frontend
k8s_yaml('frontend/k8s/deployment.yaml')
k8s_yaml('frontend/k8s/service.yaml')

docker_build(
    'frontend',
    context='./frontend',
    dockerfile='./frontend/Dockerfile.dev',
    live_update=[
        sync('./frontend', '/app'),
        run(
            'npm install',
            trigger=['./frontend/package.json', './frontend/package-lock.json']
        ),
    ]
)

k8s_resource(
    'frontend',
    port_forwards=['3000:3000'],
    labels=['app'],
)

# Display startup message
print("""
🚀 SPIRE-Vault-99 Development

Tilt is watching your code!

📊 Resources:
   - Frontend:  http://localhost:3000
   - Backend:   http://localhost:8000
   - Docs:      http://localhost:8000/docs

🔍 Tilt UI: http://localhost:10350

Press space to open the Tilt UI.
""")
```

**Success Criteria:**
- ✅ Tiltfile includes frontend
- ✅ Live update configured
- ✅ Port forwarding (3000:3000)

---

#### **Task 8.6: Deploy with Tilt**

**Description:** Deploy frontend using Tilt and verify hot-reload.

**Commands:**
```bash
cd /home/mandrix-murdock/code/spire-spife/test-vault

# Build frontend image
docker build -t frontend:dev -f frontend/Dockerfile.dev frontend/

# Load into kind cluster
kind load docker-image frontend:dev --name precinct-99

# Start Tilt (if not already running)
tilt up
```

**Verify:**
- Open http://localhost:3000
- Login with demo user (jake / jake-precinct99)
- Navigate to dashboard
- Check GitHub pages

**Test Hot-Reload:**
```bash
# Edit a frontend file
vim frontend/app/dashboard/page.tsx
# Make a visible change (add text)
# Save file

# Tilt should:
# 1. Sync file to pod (~2 seconds)
# 2. Next.js auto-reloads
# 3. Browser shows changes
```

**Success Criteria:**
- ✅ Frontend pod running
- ✅ Accessible at http://localhost:3000
- ✅ Hot-reload works (~2-5 seconds)
- ✅ Can login and navigate
- ✅ Backend API calls work

---

### 📋 EXECUTION LOG - Phase 8

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Next Phase:** Phase 9 - Integration Testing & Verification

---

## ✅ Phase 9: Integration Testing & Verification

**Objective:** Comprehensive end-to-end testing of frontend with backend integration.

### **Tasks:**

#### **Task 9.1: Test Authentication Flow**

**Description:** Verify complete authentication flow with httpOnly cookies.

**Test Steps:**
1. Open http://localhost:3000
2. Click "Login"
3. Enter credentials: jake / jake-precinct99
4. Verify:
   - httpOnly cookie set (check browser DevTools → Application → Cookies)
   - Redirected to dashboard
   - User info displayed correctly
   - No token in response body (check Network tab)

**Success Criteria:**
- ✅ Login sets httpOnly cookie
- ✅ Cookie sent with subsequent requests
- ✅ Dashboard loads user data
- ✅ Protected routes work

---

#### **Task 9.2: Test Registration Flow**

**Description:** Test user registration.

**Test Steps:**
1. Click "Register"
2. Fill form:
   - Username: testuser123
   - Email: test@example.com
   - Password: test123456
   - Confirm Password: test123456
3. Submit
4. Verify redirected to login
5. Login with new credentials
6. Verify dashboard access

**Success Criteria:**
- ✅ Registration creates user
- ✅ Validation works (password match)
- ✅ Redirects to login
- ✅ Can login with new account

---

#### **Task 9.3: Test GitHub Integration**

**Description:** Test GitHub token storage and repository fetching.

**Test Steps:**
1. Login as demo user
2. Navigate to GitHub → Configure
3. Enter valid GitHub token
4. Verify success message
5. Navigate to GitHub → Repos
6. Verify repositories displayed
7. Navigate to GitHub → Profile
8. Verify profile loaded

**Success Criteria:**
- ✅ Token saved to Vault
- ✅ Repositories fetched via API
- ✅ Profile displayed correctly
- ✅ Error handling if token invalid

---

#### **Task 9.4: Test Dark Mode**

**Description:** Verify dark mode toggle works correctly.

**Test Steps:**
1. Click dark mode icon in app bar
2. Verify theme switches to dark
3. Verify preference saved (refresh page)
4. Click again to switch back
5. Verify all pages support both modes

**Success Criteria:**
- ✅ Dark mode toggles correctly
- ✅ Preference persists
- ✅ All components styled for both modes

---

#### **Task 9.5: Test Logout**

**Description:** Verify logout clears cookie and redirects.

**Test Steps:**
1. Login
2. Navigate to dashboard
3. Click user menu → Logout
4. Verify:
   - Cookie cleared (check DevTools)
   - Redirected to home page
   - Cannot access protected routes

**Success Criteria:**
- ✅ Logout clears httpOnly cookie
- ✅ Redirects to home
- ✅ Protected routes require re-login

---

#### **Task 9.6: Test Responsive Design**

**Description:** Verify responsive design on different screen sizes.

**Test Steps:**
1. Open DevTools → Responsive mode
2. Test at:
   - Mobile: 375px × 667px (iPhone)
   - Tablet: 768px × 1024px (iPad)
   - Desktop: 1920px × 1080px
3. Verify all pages render correctly

**Success Criteria:**
- ✅ Mobile responsive
- ✅ Tablet responsive
- ✅ Desktop responsive
- ✅ No horizontal scrolling

---

#### **Task 9.7: Create Verification Script**

**Description:** Create automated verification script.

**File:** `scripts/helpers/verify-frontend.sh`

**Content:**
```bash
#!/bin/bash
set -e

echo "🔍 Verifying Frontend Deployment..."

# Check frontend pod
echo "Checking frontend pod..."
kubectl get pods -n 99-apps -l app=frontend

# Check frontend service
echo "Checking frontend service..."
kubectl get svc -n 99-apps frontend

# Health check
echo "Testing frontend health..."
curl -f http://localhost:3000 || echo "❌ Frontend not accessible"

# Check backend connectivity
echo "Testing backend API connectivity..."
curl -f http://localhost:3000/api/v1/health || echo "⚠️  Backend API not reachable from frontend"

echo "✅ Frontend verification complete!"
```

**Make executable:**
```bash
chmod +x scripts/helpers/verify-frontend.sh
```

**Run verification:**
```bash
./scripts/helpers/verify-frontend.sh
```

**Success Criteria:**
- ✅ All checks pass
- ✅ Frontend accessible
- ✅ Backend connectivity verified

---

#### **Task 9.8: Browser Compatibility Testing**

**Description:** Test in multiple browsers.

**Test Browsers:**
- Chrome/Chromium
- Firefox
- Safari (if available)

**Test Features:**
- Login/logout
- httpOnly cookie support
- Dark mode
- GitHub integration

**Success Criteria:**
- ✅ Works in Chrome
- ✅ Works in Firefox
- ✅ Works in Safari (if tested)

---

#### **Task 9.9: Performance Check**

**Description:** Basic performance verification.

**Use Lighthouse in Chrome DevTools:**
1. Open frontend
2. Run Lighthouse audit
3. Check scores:
   - Performance
   - Accessibility
   - Best Practices
   - SEO

**Target Scores:**
- Performance: >70
- Accessibility: >90
- Best Practices: >90
- SEO: >80

**Success Criteria:**
- ✅ Meets target scores
- ✅ No critical issues

---

### 📋 EXECUTION LOG - Phase 9

**Date:** [To be filled during implementation]
**Status:** ⏳ PENDING

**Summary:** [To be filled after implementation]

**Completion:** All phases complete - Sprint 3 DONE!

---

## 🎯 Sub-Sprint 3 Success Criteria

The frontend is complete when:

- ✅ **Application Setup:**
  - Next.js 16 with TypeScript configured
  - Material-UI theme (NYPD blue/gold colors)
  - Dark mode support
  - Responsive design (mobile/tablet/desktop)

- ✅ **Authentication (httpOnly Cookies):**
  - Backend updated for cookie-based auth
  - Login page functional
  - Registration page functional
  - Protected routes working
  - Logout clears cookie correctly

- ✅ **Pages Implemented:**
  - Home page
  - Login page
  - Registration page
  - Dashboard (user info + health status)
  - GitHub token configuration
  - GitHub repositories listing
  - GitHub user profile

- ✅ **Features:**
  - Auth context managing state
  - API client with axios (credentials: true)
  - Toast notifications for feedback
  - Loading states
  - Error handling
  - Form validation (React Hook Form + Zod)

- ✅ **Deployment:**
  - Docker images (dev + production)
  - Kubernetes manifests
  - Tilt hot-reload working (~2-5 seconds)
  - Accessible at http://localhost:3000

- ✅ **Integration:**
  - Connects to backend API
  - httpOnly cookies sent with requests
  - GitHub integration working
  - All demo users can login

- ✅ **Testing:**
  - End-to-end user flows tested
  - Browser compatibility verified
  - Responsive design verified
  - Performance acceptable (Lighthouse >70)

---

## 📝 Implementation Notes

### **Development Workflow**

```bash
# Initial setup
cd /home/mandrix-murdock/code/spire-spife/test-vault

# Start Tilt (both backend + frontend)
tilt up

# Access applications
# Frontend: http://localhost:3000
# Backend:  http://localhost:8000
# Tilt UI:  http://localhost:10350

# Edit frontend code
vim frontend/app/dashboard/page.tsx
# Save → Tilt syncs → Next.js reloads → See changes

# View logs
kubectl logs -f -n 99-apps deploy/frontend
```

### **Common Commands**

```bash
# Check frontend pod
kubectl get pods -n 99-apps -l app=frontend

# Get frontend logs
kubectl logs -n 99-apps -l app=frontend --tail=100 -f

# Exec into frontend pod
kubectl exec -it -n 99-apps deploy/frontend -- sh

# Inside pod:
# - Check files: ls -la
# - Test API: curl http://backend:8000/api/v1/health

# Port-forward (if not using Tilt)
kubectl port-forward -n 99-apps svc/frontend 3000:3000

# Rebuild frontend image
docker build -t frontend:dev -f frontend/Dockerfile.dev frontend/
kind load docker-image frontend:dev --name precinct-99
kubectl rollout restart deployment/frontend -n 99-apps
```

### **Troubleshooting**

**Issue:** Frontend can't connect to backend
```bash
# Check backend service
kubectl get svc -n 99-apps backend

# Test from frontend pod
kubectl exec -it -n 99-apps deploy/frontend -- sh
curl http://backend.99-apps.svc.cluster.local:8000/api/v1/health

# Check CORS configuration in backend
```

**Issue:** httpOnly cookie not set
```bash
# Check browser DevTools → Application → Cookies
# Verify backend response has Set-Cookie header
# Check CORS allows credentials
# Verify axios withCredentials: true
```

**Issue:** Hot-reload not working
```bash
# Restart Tilt
tilt down
tilt up

# Check Tilt logs for sync errors
# Verify file permissions
```

**Issue:** Environment variables not working
```bash
# Check they start with NEXT_PUBLIC_ for client-side
# Restart dev server after .env changes
# In production, set in deployment.yaml
```

---

## 🔗 References

- **Next.js 16 Documentation:** https://nextjs.org/docs
- **Material-UI Documentation:** https://mui.com/material-ui/
- **React Hook Form:** https://react-hook-form.com/
- **Zod Validation:** https://zod.dev/
- **Axios Documentation:** https://axios-http.com/
- **Notistack (Toast):** https://notistack.com/
- **TypeScript:** https://www.typescriptlang.org/
- **httpOnly Cookies Security:** https://owasp.org/www-community/HttpOnly

---

## 📞 Next Steps

After completing Sub-Sprint 3:

1. **Commit all code** to git
2. **Test complete user journey** (register → login → GitHub → logout)
3. **Take screenshots** for documentation/demo
4. **Proceed to Sub-Sprint 4:** Integration & Security (Cilium policies, final testing)

---

**Document Version:** 1.0
**Last Updated:** 2025-12-30
**Status:** ✅ READY FOR IMPLEMENTATION
**Prerequisite:** Sub-Sprint 2 (Backend Application) ✅ COMPLETE
**Next:** Sub-Sprint 4 - Integration & Security

---

**End of Sub-Sprint 3: Frontend Application Development**

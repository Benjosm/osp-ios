# OSP - Open Source Panopticon

**A truth verification platform for capturing and verifying media with cryptographic trust scoring.**

OSP (Open Source Panopticon) enables users to document real-world events through timestamped, geolocated media with verifiable trust metrics. This repository serves as the root project structure containing all components of the system.

---

## 🧩 Project Overview

OSP is a production-ready "truth verification platform" where users capture images or videos via mobile apps. These media files are immediately tagged with cryptographic metadata (capture time, location, orientation), and assigned a **trust score** based on upload latency.

### ✅ Core Features

- **Mobile Capture** (iOS & Android):
  - User authentication via Apple ID (iOS) or Google (Android)
  - Camera flow: capture → attach metadata → upload
  - Local storage of media before/during upload
  - Post-upload confirmation with trust score

- **Web Platform**:
  - Public content browsing without login
  - Interactive map-based search (Leaflet + OpenStreetMap)
  - Filter by geographic region, date/time range
  - Comment on public content, delete own posts
  - Account sign-in (same as mobile), sign-out, deletion

- **Backend (FastAPI)**:
  - RESTful API with full OpenAPI documentation
  - JWT-based authentication and authorization
  - Trust score calculation: `max(0, 100 - minutes_since_capture)`
  - Media validation and secure storage abstraction
  - SQLite in dev → PostgreSQL in production (schema-compatible)

---

## 🏗️ Architecture

### System Layout

```
osp-project/
├── osp-backend/        # FastAPI server
├── osp-web/            # Static frontend (HTML + JS)
├── osp-android/        # Android app (Jetpack Compose)
├── osp-ios/            # iOS app (SwiftUI, multiplatform template)
└── README.md           # This file
```

### Tech Stack

| Component       | Technology                          |
|----------------|-------------------------------------|
| Backend        | Python 3.10, FastAPI, SQLAlchemy    |
| Database       | SQLite (dev), PostgreSQL (prod)     |
| Auth           | JWT (Apple/Google ID token verified)|
| Web Frontend   | Vanilla JS, Leaflet.js, HTML/CSS    |
| Mobile         | Native iOS (Swift) & Android (Kotlin) |
| Storage        | Local filesystem (dev), S3 (prod-ready) |
| Build Tool     | Poetry (backend)                    |

---

## 🚀 Development Setup

### Prerequisites

- Python 3.10+
- Poetry (`pip install poetry`)
- Node.js (for web development)
- Xcode and Android Studio (for mobile builds)

---

### Backend Setup (`osp-backend/`)

```bash
cd osp-backend

# Install dependencies
poetry install --no-root

# Upgrade database schema
alembic upgrade head

# Run server
poetry run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The API will be available at: `http://localhost:8000`  
OpenAPI docs: `http://localhost:8000/docs`

#### Environment Variables (`.env`)
```env
DATABASE_URL=sqlite+aiosqlite:///./osp.db
SECRET_KEY=your-super-secret-jwt-signing-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7
AUTH_PROVIDER=mock  # "mock" (dev), "firebase" (prod)
```

> ⚠️ In production, always generate a strong `SECRET_KEY`.

---

### Web Frontend (`osp-web/`)

Hosted locally using Python's built-in server:

```bash
cd osp-web
python3 -m http.server 8001 --directory public
```

Visit: `http://localhost:8001`

- Uses **Leaflet.js** from CDN for map rendering
- Tiles from **OpenStreetMap**
- Search filters: date range + coordinates
- JWT authentication via `/api/v1/auth` endpoint

---

### Mobile Apps

- **iOS (`osp-ios/`)**: SwiftUI-based, supports Apple Sign-In
- **Android (`osp-android/`)**: Jetpack Compose, supports Google Sign-In

> 📌 **Note**: Emulation not required. Unit testing only.  
> Account creation allowed only on mobile; web supports login/logout/delete.

---

## 🔐 Security

### Authentication Flow

1. User signs in via Apple/Google → Gets ID token
2. Token sent to `POST /api/v1/auth/signin`
3. Backend validates token (mocked in dev)
4. Returns JWT access + refresh tokens
5. Subsequent requests use `Authorization: Bearer <token>`

### Authorization Rules

| Scope         | Allowed Actions                         |
|--------------|----------------------------------------|
| `user:own`   | Delete own media, comment on any       |
| Anonymous     | View public media & comments           |

Protected endpoints use FastAPI `Depends(get_current_user)`.

### Input & File Security

- All inputs validated via **Pydantic models**
- Geo fields: `lat ∈ [-90,90]`, `lng ∈ [-180,180]`
- Media types: `image/jpeg`, `video/mp4`
- Max size: 100MB
- Stored under UUID v4 filenames to prevent path injection

---

## 🧮 Trust Score Calculation

The trustworthiness of each piece of media is calculated as:

```python
trust_score = max(0, 100 - (upload_time - capture_time).total_seconds() / 60)
```

### Scoring Examples

| Delay After Capture | Trust Score |
|---------------------|-----------|
| 0 minutes           | 100       |
| 30 minutes          | 70        |
| 50 minutes          | 50        |
| 2 hours             | 0         |

This discourages delayed uploads and incentivizes real-time documentation.

> 🔇 *Digital watermarking (Digimark) is currently skipped as per project plan.*

---

## 🗂️ Database Schema (SQLite / PostgreSQL)

```sql
-- Table: users
id UUID PRIMARY KEY
provider_subject_id TEXT UNIQUE NOT NULL
provider TEXT -- 'apple' or 'google'
created_at DATETIME

-- Table: media
id UUID PRIMARY KEY
user_id UUID REFERENCES users(id)
capture_time DATETIME NOT NULL
upload_time DATETIME DEFAULT NOW
lat FLOAT NOT NULL
lng FLOAT NOT NULL
orientation TEXT -- 'portrait', 'landscape'
file_path TEXT NOT NULL
file_type TEXT -- 'image/jpeg', 'video/mp4'
trust_score INTEGER NOT NULL
deleted BOOLEAN DEFAULT FALSE

-- Table: comments
id UUID PRIMARY KEY
media_id UUID REFERENCES media(id)
user_id UUID REFERENCES users(id)
text TEXT NOT NULL
created_at DATETIME DEFAULT NOW
```

Migrations managed via **Alembic**.

---

## 🧪 Testing

Run backend test suite:

```bash
cd osp-backend
poetry run pytest
```

Includes:
- Unit tests: trust score logic, validation, storage
- Integration tests: API endpoints with mocked auth
- Security tests: 401 on invalid/missing tokens

Web tests: manual verification of map loading and search filters.

---

## 🔄 Development vs Production

| Feature               | Development                     | Production Ready Path               |
|----------------------|----------------------------------|--------------------------------------|
| Auth Provider        | Mock (validates "MOCK_TOKEN")   | Firebase Auth                        |
| Media Storage        | Local filesystem (`storage/`)   | AWS S3 (via `S3Storage` class)       |
| Database             | SQLite file                     | AWS RDS PostgreSQL                   |
| Map Tiles            | Mocked/Cached OSM tiles         | Direct OSM or TileServer             |
| Hosting              | Local Uvicorn + Python server   | Docker + AWS ECS / EC2               |

Abstractions allow zero-code changes during transition.

---

## 🧩 Modules (Backend)

| Module                     | Purpose                                 |
|----------------------------|-----------------------------------------|
| `app.services.trust`       | Calculate trust score                   |
| `app.core.storage`         | Abstract media storage (local/S3)       |
| `app.api.v1.endpoints.media`| Upload, get, delete media with metadata |
| `app.services.auth`        | Handle OAuth provider token validation  |
| `app.db.models`            | SQLAlchemy ORM definitions              |

---

## 🛠️ Build & Run

### Full Local Execution

1. Start backend:
   ```bash
   cd osp-backend && poetry run uvicorn app.main:app --port 8000
   ```

2. Serve frontend:
   ```bash
   cd osp-web && python3 -m http.server 8001 --directory public
   ```

3. Access web UI: [http://localhost:8001](http://localhost:8001)  
4. Use mobile apps or curl to upload media.

### Sample Upload (curl)

```bash
curl -X POST "http://localhost:8000/api/v1/media/upload" \
  -H "Authorization: Bearer YOUR_JWT" \
  -F "file=@photo.jpg" \
  -F "capture_time=2023-10-05T12:00:00Z" \
  -F "lat=40.7128" \
  -F "lng=-74.0060" \
  -F "orientation=portrait"
```

Expected response:
```json
{
  "media_id": "a1b2c3d4...",
  "trust_score": 98,
  "upload_time": "2023-10-05T12:02:00Z"
}
```

---

## ✅ Completion Criteria

This project is **100% complete** when:

- [x] Mobile capture → upload → confirmation flow works
- [x] Web displays interactive map with search filters
- [x] Trust score returned correctly based on delay
- [x] All backend tests pass (`pytest`)
- [x] JWT protection enforces access control
- [x] DB schema matches requirements
- [x] Fully functional local simulation (mocked auth/storage)

> ✅ Final manual check: Web loads map, backend returns health check.

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.

---

## 🙌 Contributing

Contributions welcome! Please open an issue or PR for:
- Feature enhancements
- Bug fixes
- Mobile UX improvements
- Accessibility or i18n

Ensure tests pass and follow existing patterns.

---

## 📬 Contact

For questions or collaboration, open a GitHub issue or reach out via project maintainers.

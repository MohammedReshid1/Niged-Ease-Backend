# Niged Ease Backend

This repository contains the backend services for the Niged Ease platform, a modular system designed for retail and business management. The backend is organized as a monorepo with multiple Django-based microservices, each responsible for a specific domain such as core business logic, user management, and notifications.

---

## Project Structure

```
.
├── core_service/
│   ├── clothings/
│   ├── companies/
│   ├── core_auth/
│   ├── financials/
│   ├── inventory/
│   ├── predictions/
│   ├── reports/
│   ├── transactions/
│   ├── manage.py
│   ├── requirements.txt
│   └── ...
├── notification_service/
│   ├── notification_service/
│   ├── notifications/
│   ├── manage.py
│   └── requirements.txt
├── user_management_service/
│   ├── user_management/
│   ├── users/
│   ├── manage.py
│   ├── requirements.txt
│   └── ...
├── README.MD
└── ...
```

---

## Services Overview

### 1. Core Service (`core_service/`)
- **Purpose:** Main business logic, including sales, purchases, inventory, financials, and reporting.
- **Key Apps:**
  - `clothings`: Manages clothing collections and seasons.
  - `companies`: Handles company, store, and subscription plan management.
  - `financials`: Manages expenses, receivables, payables, and payments.
  - `inventory`: Product and stock management.
  - `predictions`: Analytics and forecasting.
  - `reports`: Generates various business reports (sales, inventory, financial, customer, product performance, profit, revenue, purchase).
  - `transactions`: Handles sales, purchases, customers, suppliers, and payment modes.

### 2. Notification Service (`notification_service/`)
- **Purpose:** Handles notifications (email, SMS, etc.) for the platform.
- **Key Apps:** 
  - `notification_service`: Core logic for notifications.
  - `notifications`: Notification models and logic.

### 3. User Management Service (`user_management_service/`)
- **Purpose:** Manages users, roles, permissions, authentication, and activity logs.
- **Key Apps:**
  - `user_management`: Core user management logic.
  - `users`: User, role, permission, and authentication models.

---

## Key Features

- **Multi-tenancy:** Supports multiple companies and stores.
- **Role-Based Access Control:** Fine-grained user permissions and roles.
- **Comprehensive Reporting:** Sales, inventory, financial, customer, product, profit, revenue, and purchase reports.
- **Financial Management:** Handles expenses, receivables, payables, and payment tracking.
- **Inventory Management:** Product, stock, and low/out-of-stock tracking.
- **Notification System:** Decoupled notification microservice for scalability.
- **API Documentation:** Uses DRF Spectacular and/or drf-yasg for OpenAPI schema and docs.

---

## Setup & Installation

### Prerequisites
- Python 3.10+
- PostgreSQL (recommended for production)
- Docker (optional, for containerized deployment)

### 1. Clone the Repository
```sh
git clone <repo-url>
cd niged-ease-backend
```

### 2. Install Dependencies
Each service has its own `requirements.txt`. For example, to install for `core_service`:
```sh
cd core_service
pip install -r requirements.txt
```
Repeat for `notification_service` and `user_management_service` as needed.

### 3. Environment Variables
- Copy `.env.example` to `.env` in each service and configure as needed.

### 4. Database Migrations
Run migrations for each service:
```sh
python manage.py migrate
```

### 5. Run the Development Server
```sh
python manage.py runserver
```
Repeat for each service on different ports if running locally.

---

## API Endpoints

- **Core Service:** `/api/` (various endpoints for companies, stores, transactions, reports, etc.)
- **User Management:** `/api/users/`, `/api/auth/`, etc.
- **Notification Service:** `/api/notifications/`

API documentation is available via Swagger or Redoc at `/docs/` or `/swagger/` (depending on service and configuration).

---

## Testing

Run tests for each service:
```sh
python manage.py test
```

---

## Docker Support

Each service contains a `Dockerfile` for containerized deployment. Example:
```sh
docker build -t niged-core-service core_service/
docker run -p 8000:8000 niged-core-service
```



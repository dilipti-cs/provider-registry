# Provider Registry Application

A React-based healthcare provider registry application built with Medplum (FHIR R4 compliant headless EHR). This application enables management of:
- Healthcare Provider Organizations
- Practitioners (doctors, nurses, therapists)
- Practitioner-Organization relationships (PractitionerRoles)
- Patients and their connections to providers

## Features

- **Organization Management**: Register and manage healthcare organizations (hospitals, clinics, practices)
- **Practitioner Management**: Register individual healthcare providers with qualifications
- **Role Assignment**: Link practitioners to organizations using FHIR PractitionerRole resources
- **Patient Management**: Register patients and connect them to providers and organizations
- **Dashboard**: View real-time statistics of all resources
- **FHIR R4 Compliant**: Follows HL7 FHIR R4 standards and Da Vinci PDEX Plan Network Guide

## Tech Stack

- **Frontend**: React 18.3.1 + TypeScript 5.9.3
- **UI Library**: Mantine v7
- **FHIR Client**: @medplum/react + @medplum/core
- **Backend**: Medplum Server (FHIR R4 API)
- **Database**: PostgreSQL 16
- **Cache**: Redis 7
- **Build Tool**: Vite 6

## Prerequisites

- **Docker** and **Docker Compose** (for full stack deployment)
- **Node.js 20+** and **npm** (for local development)
- **Git** (for version control)

## Quick Start with Docker

The easiest way to run the entire stack (PostgreSQL, Redis, Medplum Server, and Provider Registry) is using Docker Compose:

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd provider-registry
```

### 2. Start All Services

```bash
docker-compose up -d
```

This will start:
- **PostgreSQL** on port 5432
- **Redis** on port 6379
- **Medplum Server** on port 8103
- **Provider Registry** on port 3001

### 3. Initialize Medplum (First Time Only)

On first run, you need to create the database schema and an admin user.

#### Option A: Using Medplum CLI (Recommended)

```bash
# Install Medplum CLI
npm install -g @medplum/cli

# Initialize database schema
docker exec -it medplum-server npx medplum db:migrate

# Create super admin user
docker exec -it medplum-server npx medplum create-super-admin \
  --email admin@example.com \
  --password Admin123! \
  --firstName Admin \
  --lastName User
```

#### Option B: Using Docker Exec

```bash
# Access the Medplum server container
docker exec -it medplum-server sh

# Inside the container
npx medplum db:migrate
npx medplum create-super-admin \
  --email admin@example.com \
  --password Admin123! \
  --firstName Admin \
  --lastName User

exit
```

### 4. Access the Application

Open your browser and navigate to:
- **Provider Registry**: http://localhost:3001
- **Medplum Server API**: http://localhost:8103

Login with the credentials you created:
- Email: `admin@example.com`
- Password: `Admin123!`

## Local Development Setup

If you want to run the frontend in development mode while using Docker for backend services:

### 1. Start Backend Services Only

```bash
# Start only PostgreSQL, Redis, and Medplum Server
docker-compose up -d postgres redis medplum-server
```

### 2. Install Frontend Dependencies

```bash
npm install
```

### 3. Run Development Server

```bash
npm run dev
```

The application will start on http://localhost:5173 (Vite default port).

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize if needed:

```bash
cp .env.example .env
```

Key variables:
- `VITE_MEDPLUM_BASE_URL`: Medplum server URL (default: http://localhost:8103)
- `POSTGRES_USER`: PostgreSQL username (default: medplum)
- `POSTGRES_PASSWORD`: PostgreSQL password (default: medplum)
- `POSTGRES_DB`: Database name (default: medplum)

### Medplum Server Configuration

The Medplum server is configured in `docker-compose.yml` with the following environment variables:
- **DATABASE_HOST**: postgres
- **DATABASE_PORT**: 5432
- **DATABASE_NAME**: medplum
- **DATABASE_USERNAME**: medplum
- **DATABASE_PASSWORD**: medplum
- **REDIS_HOST**: redis
- **BASE_URL**: http://localhost:8103

**Important**: Ensure PostgreSQL credentials match between the database service and Medplum server configuration in `docker-compose.yml`.

## Usage

### 1. Login
- Navigate to http://localhost:3001
- Login with your Medplum credentials
- If you haven't created a user yet, use the Medplum app at http://localhost:3000 to register

### 2. Register an Organization
- Click "Organizations" in the sidebar
- Click "New Organization"
- Fill in organization details:
  - Name (required)
  - Type (Healthcare Provider, Department, etc.)
  - Contact information (phone, email)
  - Address
- Click Submit

### 3. Register a Practitioner
- Click "Practitioners" in the sidebar
- Click "New Practitioner"
- Fill in practitioner details:
  - Name (prefix, given names, family name)
  - Gender
  - Birth date
  - Contact information
  - Qualifications (MD, RN, DO, etc.)
- Click Submit

### 4. Assign Practitioner to Organization
- Click "Roles" in the sidebar
- Click "Assign New Role"
- Select a practitioner from the dropdown
- Select an organization from the dropdown
- Choose a role (Physician, Nurse, etc.)
- Click "Assign Role"

**Important**: This creates a PractitionerRole resource, which is the correct FHIR pattern for linking practitioners to organizations. Each practitioner can have multiple roles across different organizations.

### 5. Register a Patient
- Click "Patients" in the sidebar
- Click "New Patient"
- Fill in patient demographics:
  - Name
  - Gender
  - Birth date
  - Contact information
- Link to providers:
  - **Managing Organization**: The organization managing patient care
  - **General Practitioner**: Select a **PractitionerRole** (not direct Practitioner!)
- Click Submit

**Important**: Patients should reference PractitionerRole (not Practitioner directly) in their generalPractitioner field. This preserves the context of which organization the practitioner is working for.

## Project Structure

```
provider-registry/
├── src/
│   ├── components/
│   │   ├── layout/
│   │   │   └── AppLayout.tsx          # Main layout with navigation
│   │   ├── organizations/
│   │   │   ├── OrganizationList.tsx   # List organizations
│   │   │   └── OrganizationForm.tsx   # Create/edit organization
│   │   ├── practitioners/
│   │   │   ├── PractitionerList.tsx   # List practitioners
│   │   │   └── PractitionerForm.tsx   # Create/edit practitioner
│   │   ├── roles/
│   │   │   ├── RoleList.tsx           # List practitioner roles
│   │   │   └── RoleAssignment.tsx     # Assign practitioner to org
│   │   └── patients/
│   │       ├── PatientList.tsx        # List patients
│   │       └── PatientForm.tsx        # Create/edit patient
│   ├── pages/
│   │   ├── LoginPage.tsx              # Login form
│   │   └── Dashboard.tsx              # Dashboard with statistics
│   ├── App.tsx                        # Root component with routes
│   └── main.tsx                       # Entry point with MedplumProvider
├── index.html                         # HTML template
├── vite.config.ts                     # Vite configuration
├── tsconfig.json                      # TypeScript configuration
└── package.json                       # Dependencies and scripts
```

## FHIR Data Model

### Organization
- Represents healthcare facilities, clinics, hospitals, departments
- Can have hierarchical relationships via `partOf`
- Uses standard organization types from HL7 terminology

### Practitioner
- Represents individual healthcare providers
- **One Practitioner resource per person** (regardless of how many orgs they work for)
- Contains demographics, qualifications, contact info

### PractitionerRole (Critical Linking Resource)
- Links Practitioner to Organization
- **One PractitionerRole per organization assignment**
- Contains role code (Physician, Nurse, etc.) and specialty
- This is the resource that Patients should reference!

### Patient
- Patient demographics and contact information
- `managingOrganization`: Reference to Organization
- `generalPractitioner`: Array of References to **PractitionerRole** (not Practitioner!)

## API Endpoints Used

All endpoints are at `http://localhost:8103/fhir/R4/`:

- `POST /Organization` - Create organization
- `GET /Organization?name=XYZ` - Search organizations
- `PUT /Organization/{id}` - Update organization
- `POST /Practitioner` - Create practitioner
- `GET /Practitioner?name=Smith` - Search practitioners
- `POST /PractitionerRole` - Assign practitioner to organization
- `GET /PractitionerRole?organization=Organization/123` - Get roles for org
- `POST /Patient` - Create patient
- `GET /Patient?name=Johnson` - Search patients

## Key Components from @medplum/react

- `<MedplumProvider>` - Provides MedplumClient context
- `<ResourceForm>` - Auto-generates forms based on FHIR resource schemas
- `<ReferenceInput>` - Searchable dropdown for FHIR resource references
- `useMedplum()` - Hook to access MedplumClient
- `useMedplumProfile()` - Hook to get current user profile

## Best Practices Followed

1. **FHIR R4 Compliance**: All resources follow FHIR R4 specifications
2. **Da Vinci PDEX Pattern**: PractitionerRole as linking resource (industry standard)
3. **One Practitioner Resource**: Each person has only one Practitioner resource
4. **Multiple PractitionerRoles**: One role per organization assignment
5. **Patient References PractitionerRole**: Not direct Practitioner references
6. **Standard Terminologies**: SNOMED CT for roles/specialties, HL7 for organization types

## Building for Production

```bash
npm run build
```

The built files will be in the `dist/` directory, ready for deployment to static hosting (Vercel, Netlify, S3, etc.).

## Available Scripts

### Development

```bash
npm run dev          # Start Vite dev server
npm run build        # Build for production
npm run preview      # Preview production build
```

### Docker

```bash
docker-compose up -d              # Start all services
docker-compose down               # Stop all services
docker-compose logs -f            # View logs
docker-compose restart            # Restart all services
docker-compose ps                 # View service status
```

## Known Issues & Limitations

### Session Persistence

Currently, sessions do **not** persist across browser refresh. Users must re-login after refreshing the page. This is a known limitation in the development environment. Attempts to enable localStorage-based persistence have resulted in authentication failures.

**Workaround**: Keep the browser tab open or re-login when needed.

## Troubleshooting

### Login Issues

If you encounter "invalid credentials" errors:

1. Clear browser localStorage:
   ```javascript
   // In browser console
   localStorage.clear()
   ```

2. Verify Medplum server is running:
   ```bash
   curl http://localhost:8103/healthcheck
   ```

3. Check PostgreSQL credentials match in `docker-compose.yml`:
   - `POSTGRES_PASSWORD` (postgres service)
   - `DATABASE_PASSWORD` (medplum-server service)

### Database Connection Errors

If Medplum server fails to connect to PostgreSQL:

1. Ensure PostgreSQL is healthy:
   ```bash
   docker-compose ps postgres
   ```

2. Check PostgreSQL logs:
   ```bash
   docker-compose logs postgres
   ```

3. Verify database credentials in `.env` and `docker-compose.yml`

### Dashboard Shows Zero

If the dashboard statistics show zero but you have data:

1. Check browser console for errors
2. Verify Medplum server is accessible at http://localhost:8103
3. Ensure you're logged in (check for 401 errors in network tab)
4. Try manually refreshing stats by clicking "Refresh Stats" button

### Port Conflicts

If services fail to start due to port conflicts:

1. Check what's using the port:
   ```bash
   # Windows
   netstat -ano | findstr :8103

   # Linux/Mac
   lsof -i :8103
   ```

2. Either stop the conflicting service or change ports in `docker-compose.yml`

### Cannot connect to Medplum server
- Ensure Medplum server is running at http://localhost:8103
- Check that docker-compose services are up: `docker-compose ps`

### Authentication errors
- Make sure you have a user account in Medplum
- Try logging out and logging back in
- Check browser console for detailed error messages

### CORS errors
- The Medplum server should be configured to allow requests from localhost:3001
- Check Medplum server configuration

## Future Enhancements

- Bulk import (CSV/Excel)
- Advanced search with filters
- Patient care team management
- Document attachments
- Reporting and analytics
- Mobile responsive improvements
- Real-time updates via WebSocket

## Production Deployment

For production deployment:

1. Update `docker-compose.yml`:
   - Change default passwords
   - Update `BASE_URL` and `ISSUER` to your domain
   - Configure proper volumes for data persistence

2. Use a reverse proxy (nginx/traefik) for SSL/TLS

3. Enable authentication tokens with proper expiration

4. Configure backup strategy for PostgreSQL

5. Set up monitoring and logging

6. Use secrets management (e.g., Docker secrets, HashiCorp Vault)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Reference

- Design Document: `DESIGN.md`
- Medplum Documentation: https://www.medplum.com/docs
- FHIR R4 Specification: https://hl7.org/fhir/R4/
- Da Vinci PDEX Plan Network Guide: http://hl7.org/fhir/us/davinci-pdex-plan-net/

## Acknowledgments

- Built with [Medplum](https://www.medplum.com/) - Open source healthcare platform
- UI components from [Mantine](https://mantine.dev/)
- Follows [HL7 FHIR R4](https://hl7.org/fhir/R4/) standards
- Aligned with [Da Vinci PDEX Plan Network IG](https://build.fhir.org/ig/HL7/davinci-pdex-plan-net/)

## Deploying to Google Cloud Platform (GCP)

This application is ready to deploy to GCP using Google Kubernetes Engine (GKE). We provide complete infrastructure-as-code and deployment automation.

### Quick GCP Deployment

```bash
# 1. Setup GCP infrastructure with Terraform
./scripts/setup-infrastructure.sh

# 2. Deploy the application
./scripts/deploy.sh

# 3. Initialize Medplum (first time only)
./scripts/init-medplum.sh
```

### What's Included for GCP Deployment

- **Kubernetes manifests** (k8s/) - Complete K8s configuration for all services
- **Terraform scripts** (terraform/) - Infrastructure as Code for GKE cluster
- **Cloud Build** (cloudbuild.yaml) - CI/CD pipeline configuration
- **Deployment scripts** (scripts/) - Automated deployment and management
- **Complete documentation** (GCP_DEPLOYMENT.md) - Step-by-step deployment guide

### GCP Architecture

The deployment creates:
- **GKE Cluster**: Autoscaling Kubernetes cluster
- **Load Balancer**: HTTPS ingress with managed SSL certificates
- **Cloud SQL** (optional): Managed PostgreSQL for production
- **Container Registry**: Docker image storage
- **Cloud Build**: Automated CI/CD pipeline

### Prerequisites for GCP Deployment

1. Google Cloud account with billing enabled
2. `gcloud` CLI installed and authenticated
3. `kubectl` installed
4. `terraform` installed (for infrastructure setup)

### Estimated GCP Costs

- **Development**: ~$30/month (1 e2-medium node, no load balancer)
- **Production**: ~$160-200/month (2+ e2-standard-4 nodes, load balancer)

See [GCP_DEPLOYMENT.md](./GCP_DEPLOYMENT.md) for detailed deployment instructions.

---

## License

ISC

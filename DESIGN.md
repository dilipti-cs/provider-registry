# Provider & Patient Registration Application - Design Document

## 1. Overview

A React-based front-end application that interfaces with the locally running Medplum (headless EHR) instance to register and manage:
- Provider Organizations (hospitals, clinics, practices)
- Individual Practitioners (doctors, nurses, therapists)
- Patients and their connections to providers

## 2. Tech Stack

### Frontend Framework
- **React 18.3.1** with TypeScript 5.9.3
- **@medplum/react** - Pre-built FHIR-aware React components
- **@medplum/core** - MedplumClient, FHIR utilities, TypeScript types
- **@mantine/core v7** - UI component library (used by Medplum)
- **@mantine/hooks** - React hooks utilities
- **@mantine/notifications** - Toast notifications
- **react-router-dom v6** - Client-side routing

### Backend/API
- **Medplum Server** at http://localhost:8103
- **FHIR R4 RESTful API** at http://localhost:8103/fhir/R4/
- **OAuth 2.0** authentication with Bearer tokens

### Key Dependencies
```json
{
  "@medplum/core": "^3.2.21",
  "@medplum/react": "^3.2.21",
  "@mantine/core": "^7.13.5",
  "@mantine/hooks": "^7.13.5",
  "@mantine/notifications": "^7.13.5",
  "react": "^18.3.1",
  "react-router-dom": "^6.28.0",
  "typescript": "^5.9.3"
}
```

## 3. FHIR Data Model

### Organization Resource
```typescript
{
  resourceType: "Organization",
  id: "org-123",
  name: "City General Hospital",
  type: [{
    coding: [{
      system: "http://terminology.hl7.org/CodeSystem/organization-type",
      code: "prov",  // healthcare provider, dept, ins, pay, edu, reli, govt, etc.
      display: "Healthcare Provider"
    }]
  }],
  active: true,
  partOf: { reference: "Organization/parent-org" },  // For hierarchies
  telecom: [
    { system: "phone", value: "(555) 123-4567" },
    { system: "email", value: "contact@citygen.org" }
  ],
  address: [{
    line: ["123 Main St"],
    city: "Boston",
    state: "MA",
    postalCode: "02101",
    country: "USA"
  }]
}
```

### Practitioner Resource
```typescript
{
  resourceType: "Practitioner",
  id: "prac-456",
  name: [{
    family: "Smith",
    given: ["John", "Michael"],
    prefix: ["Dr."]
  }],
  active: true,
  gender: "male",
  birthDate: "1980-05-15",
  telecom: [
    { system: "email", value: "jsmith@citygen.org" },
    { system: "phone", value: "(555) 987-6543" }
  ],
  address: [{ /* ... */ }],
  qualification: [{
    code: {
      coding: [{
        system: "http://terminology.hl7.org/CodeSystem/v2-0360",
        code: "MD",
        display: "Doctor of Medicine"
      }]
    },
    issuer: { display: "Harvard Medical School" },
    period: { start: "2008-06-01" }
  }]
}
```

### PractitionerRole Resource (Critical Linking Resource)
```typescript
{
  resourceType: "PractitionerRole",
  id: "role-789",
  active: true,
  practitioner: { reference: "Practitioner/prac-456" },
  organization: { reference: "Organization/org-123" },
  code: [{
    coding: [{
      system: "http://snomed.info/sct",
      code: "309343006",  // Physician, 224571005: Nurse, etc.
      display: "Physician"
    }]
  }],
  specialty: [{
    coding: [{
      system: "http://snomed.info/sct",
      code: "394579002",
      display: "Cardiology"
    }]
  }],
  location: [{ reference: "Location/loc-001" }],
  telecom: [{ system: "phone", value: "(555) 111-2222", use: "work" }],
  availableTime: [/* scheduling info */],
  notAvailable: [/* exceptions */]
}
```

**Important Note**: Each Practitioner should have ONE Practitioner resource but MULTIPLE PractitionerRole resources (one per organization they work for).

### Patient Resource
```typescript
{
  resourceType: "Patient",
  id: "pat-101",
  name: [{
    family: "Johnson",
    given: ["Emily", "Rose"]
  }],
  active: true,
  gender: "female",
  birthDate: "1995-08-22",
  telecom: [
    { system: "phone", value: "(555) 234-5678", use: "mobile" },
    { system: "email", value: "ejohnson@email.com" }
  ],
  address: [{ /* ... */ }],
  maritalStatus: { /* ... */ },
  contact: [{ /* emergency contacts */ }],
  generalPractitioner: [
    { reference: "PractitionerRole/role-789" }  // Should reference PractitionerRole, not Practitioner!
  ],
  managingOrganization: { reference: "Organization/org-123" }
}
```

## 4. Standards and Best Practices

### FHIR Best Practices
- Always use References for linking resources (not embedded resources)
- Use standard code systems (SNOMED CT, LOINC, ICD-10, etc.)
- Validate resources against FHIR profiles before submission
- Use FHIR search parameters for efficient querying
- Implement proper error handling for OperationOutcome responses

### Da Vinci PDEX Plan Network Guide Alignment
This design follows the Da Vinci PDEX Plan Network Implementation Guide for provider directories:
- Organizations represent healthcare facilities and networks
- PractitionerRole is the central linking resource (not direct Practitioner → Organization)
- Each practitioner-organization relationship = one PractitionerRole
- Patients reference PractitionerRole (not Practitioner) in generalPractitioner field
- Use of standard terminologies (SNOMED CT for roles/specialties)

---

**Document Version**: 1.0
**Last Updated**: 2025-10-14
**Medplum Version**: 3.2.21
**FHIR Version**: R4 (4.0.1)

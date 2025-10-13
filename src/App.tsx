import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useMedplum } from '@medplum/react';
import { useState, useEffect } from 'react';
import AppLayout from './components/layout/AppLayout';
import LoginPage from './pages/LoginPage';
import Dashboard from './pages/Dashboard';
import OrganizationList from './components/organizations/OrganizationList';
import OrganizationForm from './components/organizations/OrganizationForm';
import PractitionerList from './components/practitioners/PractitionerList';
import PractitionerForm from './components/practitioners/PractitionerForm';
import RoleList from './components/roles/RoleList';
import RoleAssignment from './components/roles/RoleAssignment';
import PatientList from './components/patients/PatientList';
import PatientForm from './components/patients/PatientForm';

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const medplum = useMedplum();
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const profile = await medplum.getProfile();
        setIsAuthenticated(!!profile);
      } catch {
        setIsAuthenticated(false);
      }
    };
    checkAuth();
  }, [medplum]);

  if (isAuthenticated === null) {
    return <div>Loading...</div>;
  }

  return isAuthenticated ? <>{children}</> : <Navigate to="/login" />;
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />

        <Route
          path="/"
          element={
            <PrivateRoute>
              <AppLayout />
            </PrivateRoute>
          }
        >
          <Route index element={<Dashboard />} />

          {/* Organization routes */}
          <Route path="organizations" element={<OrganizationList />} />
          <Route path="organizations/new" element={<OrganizationForm />} />
          <Route path="organizations/:id/edit" element={<OrganizationForm />} />

          {/* Practitioner routes */}
          <Route path="practitioners" element={<PractitionerList />} />
          <Route path="practitioners/new" element={<PractitionerForm />} />
          <Route path="practitioners/:id/edit" element={<PractitionerForm />} />

          {/* Role routes */}
          <Route path="roles" element={<RoleList />} />
          <Route path="roles/new" element={<RoleAssignment />} />

          {/* Patient routes */}
          <Route path="patients" element={<PatientList />} />
          <Route path="patients/new" element={<PatientForm />} />
          <Route path="patients/:id/edit" element={<PatientForm />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;

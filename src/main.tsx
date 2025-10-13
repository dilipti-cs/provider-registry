import React from 'react';
import ReactDOM from 'react-dom/client';
import { MantineProvider } from '@mantine/core';
import { Notifications } from '@mantine/notifications';
import { MedplumClient } from '@medplum/core';
import { MedplumProvider } from '@medplum/react';
import App from './App';
import '@mantine/core/styles.css';
import '@mantine/notifications/styles.css';

// Initialize Medplum client pointing to local server
const medplum = new MedplumClient({
  baseUrl: 'http://localhost:8103',
  onUnauthenticated: () => {
    // Redirect to login when session expires
    if (window.location.pathname !== '/login') {
      window.location.href = '/login';
    }
  },
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <MedplumProvider medplum={medplum}>
      <MantineProvider>
        <Notifications position="top-right" />
        <App />
      </MantineProvider>
    </MedplumProvider>
  </React.StrictMode>
);

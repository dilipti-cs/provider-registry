import { Outlet, Link, useNavigate } from 'react-router-dom';
import { AppShell, Burger, Group, NavLink, Title, Button, Text } from '@mantine/core';
import { useDisclosure } from '@mantine/hooks';
import {
  IconBuilding,
  IconStethoscope,
  IconUsers,
  IconClipboardList,
  IconLogout,
  IconHome,
} from '@tabler/icons-react';
import { useMedplum, useMedplumProfile } from '@medplum/react';
import { notifications } from '@mantine/notifications';

export default function AppLayout() {
  const [opened, { toggle }] = useDisclosure();
  const medplum = useMedplum();
  const profile = useMedplumProfile();
  const navigate = useNavigate();

  const handleLogout = () => {
    medplum.signOut();
    notifications.show({
      title: 'Success',
      message: 'Logged out successfully',
      color: 'blue',
    });
    navigate('/login');
  };

  // Debug logging
  console.log('AppLayout rendered, profile:', profile);
  console.log('Navbar opened state:', opened);

  // Get display name from profile
  const getProfileName = () => {
    if (!profile) return 'User';
    if ('name' in profile && profile.name && profile.name[0]) {
      const name = profile.name[0];
      return name.text || `${name.given?.[0] || ''} ${name.family || ''}`.trim() || 'User';
    }
    return 'User';
  };

  return (
    <AppShell
      header={{ height: 60 }}
      navbar={{ width: 250, breakpoint: 'sm', collapsed: { mobile: !opened, desktop: false } }}
      padding="md"
    >
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between">
          <Group>
            <Burger opened={opened} onClick={toggle} hiddenFrom="sm" size="sm" />
            <Title order={3}>Provider Registry</Title>
          </Group>

          <Group>
            <Text size="sm">{getProfileName()}</Text>
            <Button
              variant="subtle"
              leftSection={<IconLogout size={16} />}
              onClick={handleLogout}
            >
              Logout
            </Button>
          </Group>
        </Group>
      </AppShell.Header>

      <AppShell.Navbar p="md">
        <NavLink
          component={Link}
          to="/"
          label="Dashboard"
          leftSection={<IconHome size={20} />}
        />

        <NavLink
          component={Link}
          to="/organizations"
          label="Organizations"
          leftSection={<IconBuilding size={20} />}
        />

        <NavLink
          component={Link}
          to="/practitioners"
          label="Practitioners"
          leftSection={<IconStethoscope size={20} />}
        />

        <NavLink
          component={Link}
          to="/roles"
          label="Roles"
          leftSection={<IconClipboardList size={20} />}
          description="Assign practitioners to organizations"
        />

        <NavLink
          component={Link}
          to="/patients"
          label="Patients"
          leftSection={<IconUsers size={20} />}
        />
      </AppShell.Navbar>

      <AppShell.Main>
        <Outlet />
      </AppShell.Main>
    </AppShell>
  );
}

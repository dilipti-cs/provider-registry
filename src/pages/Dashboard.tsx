import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Container, Title, SimpleGrid, Paper, Text, Button, Group, Stack } from '@mantine/core';
import { IconBuilding, IconStethoscope, IconUsers, IconPlus } from '@tabler/icons-react';
import { useMedplum } from '@medplum/react';
import { notifications } from '@mantine/notifications';

export default function Dashboard() {
  const medplum = useMedplum();
  const [stats, setStats] = useState({
    organizations: 0,
    practitioners: 0,
    patients: 0,
    roles: 0,
  });
  const [loading, setLoading] = useState(true);

  const fetchStats = async () => {
    setLoading(true);
    try {
      console.log('=== FETCHING STATS ===');

      // Use searchResources which returns the array directly
      const [orgs, practitioners, patients, roles] = await Promise.all([
        medplum.searchResources('Organization'),
        medplum.searchResources('Practitioner'),
        medplum.searchResources('Patient'),
        medplum.searchResources('PractitionerRole'),
      ]);

      const newStats = {
        organizations: orgs.length,
        practitioners: practitioners.length,
        patients: patients.length,
        roles: roles.length,
      };

      console.log('=== STATS FETCHED ===', newStats);
      console.log('Organizations found:', orgs);

      setStats(newStats);
    } catch (error) {
      console.error('=== ERROR FETCHING STATS ===', error);
      notifications.show({
        title: 'Error',
        message: 'Failed to fetch stats: ' + (error as Error).message,
        color: 'red',
      });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();

    // Refresh stats every 30 seconds while on dashboard
    const interval = setInterval(fetchStats, 30000);

    return () => clearInterval(interval);
  }, []);

  return (
    <Container size="xl">
      <Group justify="space-between" mb="xl">
        <Title order={2}>Dashboard</Title>
        <Button onClick={fetchStats} loading={loading} variant="light">
          Refresh Stats
        </Button>
      </Group>

      <SimpleGrid cols={{ base: 1, sm: 2, md: 4 }} spacing="lg" mb="xl">
        <Paper shadow="sm" p="md" withBorder>
          <Group>
            <IconBuilding size={40} color="blue" />
            <Stack gap={0}>
              <Text size="xl" fw={700}>
                {stats.organizations}
              </Text>
              <Text size="sm" c="dimmed">
                Organizations
              </Text>
            </Stack>
          </Group>
        </Paper>

        <Paper shadow="sm" p="md" withBorder>
          <Group>
            <IconStethoscope size={40} color="green" />
            <Stack gap={0}>
              <Text size="xl" fw={700}>
                {stats.practitioners}
              </Text>
              <Text size="sm" c="dimmed">
                Practitioners
              </Text>
            </Stack>
          </Group>
        </Paper>

        <Paper shadow="sm" p="md" withBorder>
          <Group>
            <IconUsers size={40} color="orange" />
            <Stack gap={0}>
              <Text size="xl" fw={700}>
                {stats.patients}
              </Text>
              <Text size="sm" c="dimmed">
                Patients
              </Text>
            </Stack>
          </Group>
        </Paper>

        <Paper shadow="sm" p="md" withBorder>
          <Group>
            <IconStethoscope size={40} color="violet" />
            <Stack gap={0}>
              <Text size="xl" fw={700}>
                {stats.roles}
              </Text>
              <Text size="sm" c="dimmed">
                Active Roles
              </Text>
            </Stack>
          </Group>
        </Paper>
      </SimpleGrid>

      <Paper shadow="sm" p="md" withBorder>
        <Title order={3} mb="md">
          Quick Actions
        </Title>

        <Group>
          <Button
            component={Link}
            to="/organizations/new"
            leftSection={<IconPlus size={16} />}
            variant="light"
          >
            New Organization
          </Button>

          <Button
            component={Link}
            to="/practitioners/new"
            leftSection={<IconPlus size={16} />}
            variant="light"
          >
            New Practitioner
          </Button>

          <Button
            component={Link}
            to="/patients/new"
            leftSection={<IconPlus size={16} />}
            variant="light"
          >
            New Patient
          </Button>

          <Button
            component={Link}
            to="/roles/new"
            leftSection={<IconPlus size={16} />}
            variant="light"
          >
            Assign Role
          </Button>
        </Group>
      </Paper>
    </Container>
  );
}

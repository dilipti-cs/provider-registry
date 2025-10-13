import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Container,
  Title,
  Button,
  Table,
  Group,
  Paper,
  Badge,
  Text,
} from '@mantine/core';
import { IconPlus } from '@tabler/icons-react';
import { useMedplum } from '@medplum/react';
import { PractitionerRole, Practitioner, Organization } from '@medplum/fhirtypes';

interface RoleWithDetails extends PractitionerRole {
  practitionerName?: string;
  organizationName?: string;
}

export default function RoleList() {
  const medplum = useMedplum();
  const [roles, setRoles] = useState<RoleWithDetails[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchRoles();
  }, []);

  const fetchRoles = async () => {
    setLoading(true);
    try {
      const results = await medplum.searchResources('PractitionerRole', {
        _count: '50',
        _sort: '-_lastUpdated',
      });

      // Fetch practitioner and organization details for each role
      const rolesWithDetails = await Promise.all(
        results.map(async (role) => {
          const roleWithDetails: RoleWithDetails = { ...role };

          if (role.practitioner?.reference) {
            try {
              const prac = await medplum.readReference(role.practitioner as any);
              const pracResource = prac as Practitioner;
              if (pracResource.name?.[0]) {
                const name = pracResource.name[0];
                roleWithDetails.practitionerName = `${name.prefix?.join(' ') || ''} ${name.given?.join(' ') || ''} ${name.family || ''}`.trim();
              }
            } catch (e) {
              roleWithDetails.practitionerName = 'Unknown';
            }
          }

          if (role.organization?.reference) {
            try {
              const org = await medplum.readReference(role.organization as any);
              const orgResource = org as Organization;
              roleWithDetails.organizationName = orgResource.name || 'Unknown';
            } catch (e) {
              roleWithDetails.organizationName = 'Unknown';
            }
          }

          return roleWithDetails;
        })
      );

      setRoles(rolesWithDetails);
    } catch (error) {
      console.error('Failed to fetch roles:', error);
    } finally {
      setLoading(false);
    }
  };

  const getRoleCode = (role: PractitionerRole) => {
    return role.code?.[0]?.coding?.[0]?.display || role.code?.[0]?.coding?.[0]?.code || 'N/A';
  };

  const getSpecialty = (role: PractitionerRole) => {
    if (!role.specialty || role.specialty.length === 0) return 'N/A';
    return role.specialty
      .map((s) => s.coding?.[0]?.display || s.coding?.[0]?.code)
      .filter(Boolean)
      .join(', ');
  };

  return (
    <Container size="xl">
      <Group justify="space-between" mb="md">
        <Title order={2}>Practitioner Roles</Title>
        <Button component={Link} to="/roles/new" leftSection={<IconPlus size={16} />}>
          Assign New Role
        </Button>
      </Group>

      <Paper shadow="sm" p="md" mb="md">
        <Text size="sm" c="dimmed">
          PractitionerRoles link practitioners to organizations. Each practitioner can have
          multiple roles across different organizations.
        </Text>
      </Paper>

      <Paper shadow="sm" p="md">
        {loading ? (
          <div>Loading...</div>
        ) : roles.length === 0 ? (
          <div>No roles found. Start by assigning a practitioner to an organization.</div>
        ) : (
          <Table>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Practitioner</Table.Th>
                <Table.Th>Organization</Table.Th>
                <Table.Th>Role</Table.Th>
                <Table.Th>Specialty</Table.Th>
                <Table.Th>Status</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {roles.map((role) => (
                <Table.Tr key={role.id}>
                  <Table.Td>{role.practitionerName || 'N/A'}</Table.Td>
                  <Table.Td>{role.organizationName || 'N/A'}</Table.Td>
                  <Table.Td>{getRoleCode(role)}</Table.Td>
                  <Table.Td>{getSpecialty(role)}</Table.Td>
                  <Table.Td>
                    <Badge color={role.active !== false ? 'green' : 'red'}>
                      {role.active !== false ? 'Active' : 'Inactive'}
                    </Badge>
                  </Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        )}
      </Paper>
    </Container>
  );
}

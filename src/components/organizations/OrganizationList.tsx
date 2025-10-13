import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Container,
  Title,
  Button,
  Table,
  TextInput,
  Select,
  Group,
  Paper,
  Badge,
  ActionIcon,
} from '@mantine/core';
import { IconPlus, IconSearch, IconEdit, IconEye } from '@tabler/icons-react';
import { useMedplum } from '@medplum/react';
import { Organization } from '@medplum/fhirtypes';

export default function OrganizationList() {
  const medplum = useMedplum();
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchOrganizations();
  }, [searchTerm, typeFilter]);

  const fetchOrganizations = async () => {
    setLoading(true);
    try {
      const params: Record<string, string> = { _count: '20', _sort: '-_lastUpdated' };
      if (searchTerm) params.name = searchTerm;
      if (typeFilter) params.type = typeFilter;

      const results = await medplum.searchResources('Organization', params);
      setOrganizations(results);
    } catch (error) {
      console.error('Failed to fetch organizations:', error);
    } finally {
      setLoading(false);
    }
  };

  const getAddress = (org: Organization) => {
    if (!org.address || org.address.length === 0) return 'N/A';
    const addr = org.address[0];
    return `${addr.city || ''}, ${addr.state || ''}`.trim() || 'N/A';
  };

  const getPhone = (org: Organization) => {
    const phone = org.telecom?.find((t) => t.system === 'phone');
    return phone?.value || 'N/A';
  };

  return (
    <Container size="xl">
      <Group justify="space-between" mb="md">
        <Title order={2}>Organizations</Title>
        <Button component={Link} to="/organizations/new" leftSection={<IconPlus size={16} />}>
          New Organization
        </Button>
      </Group>

      <Paper shadow="sm" p="md" mb="md">
        <Group>
          <TextInput
            placeholder="Search by name..."
            leftSection={<IconSearch size={16} />}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.currentTarget.value)}
            style={{ flex: 1 }}
          />

          <Select
            placeholder="Filter by type"
            clearable
            value={typeFilter}
            onChange={setTypeFilter}
            data={[
              { value: 'prov', label: 'Healthcare Provider' },
              { value: 'dept', label: 'Department' },
              { value: 'team', label: 'Team' },
              { value: 'govt', label: 'Government' },
              { value: 'ins', label: 'Insurance' },
              { value: 'pay', label: 'Payer' },
              { value: 'edu', label: 'Educational' },
            ]}
            style={{ minWidth: 200 }}
          />
        </Group>
      </Paper>

      <Paper shadow="sm" p="md">
        {loading ? (
          <div>Loading...</div>
        ) : organizations.length === 0 ? (
          <div>No organizations found</div>
        ) : (
          <Table>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Name</Table.Th>
                <Table.Th>Type</Table.Th>
                <Table.Th>Location</Table.Th>
                <Table.Th>Phone</Table.Th>
                <Table.Th>Status</Table.Th>
                <Table.Th>Actions</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {organizations.map((org) => (
                <Table.Tr key={org.id}>
                  <Table.Td>{org.name}</Table.Td>
                  <Table.Td>
                    {org.type?.[0]?.coding?.[0]?.display || org.type?.[0]?.coding?.[0]?.code || 'N/A'}
                  </Table.Td>
                  <Table.Td>{getAddress(org)}</Table.Td>
                  <Table.Td>{getPhone(org)}</Table.Td>
                  <Table.Td>
                    <Badge color={org.active !== false ? 'green' : 'red'}>
                      {org.active !== false ? 'Active' : 'Inactive'}
                    </Badge>
                  </Table.Td>
                  <Table.Td>
                    <Group gap="xs">
                      <ActionIcon
                        component={Link}
                        to={`/organizations/${org.id}/edit`}
                        variant="subtle"
                        color="blue"
                      >
                        <IconEdit size={16} />
                      </ActionIcon>
                    </Group>
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

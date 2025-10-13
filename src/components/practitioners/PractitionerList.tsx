import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Container,
  Title,
  Button,
  Table,
  TextInput,
  Group,
  Paper,
  Badge,
  ActionIcon,
} from '@mantine/core';
import { IconPlus, IconSearch, IconEdit } from '@tabler/icons-react';
import { useMedplum } from '@medplum/react';
import { Practitioner } from '@medplum/fhirtypes';

export default function PractitionerList() {
  const medplum = useMedplum();
  const [practitioners, setPractitioners] = useState<Practitioner[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchPractitioners();
  }, [searchTerm]);

  const fetchPractitioners = async () => {
    setLoading(true);
    try {
      const params: Record<string, string> = { _count: '20', _sort: '-_lastUpdated' };
      if (searchTerm) params.name = searchTerm;

      const results = await medplum.searchResources('Practitioner', params);
      setPractitioners(results);
    } catch (error) {
      console.error('Failed to fetch practitioners:', error);
    } finally {
      setLoading(false);
    }
  };

  const getName = (prac: Practitioner) => {
    if (!prac.name || prac.name.length === 0) return 'N/A';
    const name = prac.name[0];
    const prefix = name.prefix?.join(' ') || '';
    const given = name.given?.join(' ') || '';
    const family = name.family || '';
    return `${prefix} ${given} ${family}`.trim();
  };

  const getEmail = (prac: Practitioner) => {
    const email = prac.telecom?.find((t) => t.system === 'email');
    return email?.value || 'N/A';
  };

  const getPhone = (prac: Practitioner) => {
    const phone = prac.telecom?.find((t) => t.system === 'phone');
    return phone?.value || 'N/A';
  };

  const getQualifications = (prac: Practitioner) => {
    if (!prac.qualification || prac.qualification.length === 0) return 'N/A';
    return prac.qualification
      .map((q) => q.code.coding?.[0]?.display || q.code.coding?.[0]?.code)
      .filter(Boolean)
      .join(', ');
  };

  return (
    <Container size="xl">
      <Group justify="space-between" mb="md">
        <Title order={2}>Practitioners</Title>
        <Button component={Link} to="/practitioners/new" leftSection={<IconPlus size={16} />}>
          New Practitioner
        </Button>
      </Group>

      <Paper shadow="sm" p="md" mb="md">
        <TextInput
          placeholder="Search by name..."
          leftSection={<IconSearch size={16} />}
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.currentTarget.value)}
        />
      </Paper>

      <Paper shadow="sm" p="md">
        {loading ? (
          <div>Loading...</div>
        ) : practitioners.length === 0 ? (
          <div>No practitioners found</div>
        ) : (
          <Table>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Name</Table.Th>
                <Table.Th>Email</Table.Th>
                <Table.Th>Phone</Table.Th>
                <Table.Th>Qualifications</Table.Th>
                <Table.Th>Status</Table.Th>
                <Table.Th>Actions</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {practitioners.map((prac) => (
                <Table.Tr key={prac.id}>
                  <Table.Td>{getName(prac)}</Table.Td>
                  <Table.Td>{getEmail(prac)}</Table.Td>
                  <Table.Td>{getPhone(prac)}</Table.Td>
                  <Table.Td>{getQualifications(prac)}</Table.Td>
                  <Table.Td>
                    <Badge color={prac.active !== false ? 'green' : 'red'}>
                      {prac.active !== false ? 'Active' : 'Inactive'}
                    </Badge>
                  </Table.Td>
                  <Table.Td>
                    <Group gap="xs">
                      <ActionIcon
                        component={Link}
                        to={`/practitioners/${prac.id}/edit`}
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

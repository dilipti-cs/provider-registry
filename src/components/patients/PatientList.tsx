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
import { Patient } from '@medplum/fhirtypes';

export default function PatientList() {
  const medplum = useMedplum();
  const [patients, setPatients] = useState<Patient[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchPatients();
  }, [searchTerm]);

  const fetchPatients = async () => {
    setLoading(true);
    try {
      const params: Record<string, string> = { _count: '20', _sort: '-_lastUpdated' };
      if (searchTerm) params.name = searchTerm;

      const results = await medplum.searchResources('Patient', params);
      setPatients(results);
    } catch (error) {
      console.error('Failed to fetch patients:', error);
    } finally {
      setLoading(false);
    }
  };

  const getName = (patient: Patient) => {
    if (!patient.name || patient.name.length === 0) return 'N/A';
    const name = patient.name[0];
    const given = name.given?.join(' ') || '';
    const family = name.family || '';
    return `${given} ${family}`.trim();
  };

  const getEmail = (patient: Patient) => {
    const email = patient.telecom?.find((t) => t.system === 'email');
    return email?.value || 'N/A';
  };

  const getPhone = (patient: Patient) => {
    const phone = patient.telecom?.find((t) => t.system === 'phone');
    return phone?.value || 'N/A';
  };

  const formatDate = (date?: string) => {
    if (!date) return 'N/A';
    return new Date(date).toLocaleDateString();
  };

  return (
    <Container size="xl">
      <Group justify="space-between" mb="md">
        <Title order={2}>Patients</Title>
        <Button component={Link} to="/patients/new" leftSection={<IconPlus size={16} />}>
          New Patient
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
        ) : patients.length === 0 ? (
          <div>No patients found</div>
        ) : (
          <Table>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>Name</Table.Th>
                <Table.Th>DOB</Table.Th>
                <Table.Th>Gender</Table.Th>
                <Table.Th>Phone</Table.Th>
                <Table.Th>Email</Table.Th>
                <Table.Th>Status</Table.Th>
                <Table.Th>Actions</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {patients.map((patient) => (
                <Table.Tr key={patient.id}>
                  <Table.Td>{getName(patient)}</Table.Td>
                  <Table.Td>{formatDate(patient.birthDate)}</Table.Td>
                  <Table.Td>{patient.gender || 'N/A'}</Table.Td>
                  <Table.Td>{getPhone(patient)}</Table.Td>
                  <Table.Td>{getEmail(patient)}</Table.Td>
                  <Table.Td>
                    <Badge color={patient.active !== false ? 'green' : 'red'}>
                      {patient.active !== false ? 'Active' : 'Inactive'}
                    </Badge>
                  </Table.Td>
                  <Table.Td>
                    <Group gap="xs">
                      <ActionIcon
                        component={Link}
                        to={`/patients/${patient.id}/edit`}
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

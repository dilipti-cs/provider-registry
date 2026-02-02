import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container,
  Title,
  Paper,
  Button,
  Group,
  Select,
  Stack,
  Text,
} from '@mantine/core';
import { notifications } from '@mantine/notifications';
import { useMedplum } from '@medplum/react';
import { ReferenceInput } from '@medplum/react';
import { Reference, Practitioner, Organization, PractitionerRole } from '@medplum/fhirtypes';

export default function RoleAssignment() {
  const medplum = useMedplum();
  const navigate = useNavigate();
  const [practitioner, setPractitioner] = useState<Reference<Practitioner>>();
  const [organization, setOrganization] = useState<Reference<Organization>>();
  const [roleCode, setRoleCode] = useState<string>('');
  const [loading, setLoading] = useState(false);

  const roleOptions = [
    { value: '309343006', label: 'Physician' },
    { value: '224571005', label: 'Nurse' },
    { value: '224529009', label: 'Clinical Nurse Specialist' },
    { value: '36682004', label: 'Physiotherapist' },
    { value: '59944000', label: 'Psychologist' },
    { value: '46255001', label: 'Pharmacist' },
    { value: '304292004', label: 'Surgeon' },
    { value: '28229004', label: 'Optometrist' },
    { value: '159033005', label: 'Dietitian' },
  ];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!practitioner || !organization || !roleCode) {
      notifications.show({
        title: 'Error',
        message: 'Please fill in all required fields',
        color: 'red',
      });
      return;
    }

    setLoading(true);

    try {
      const role: PractitionerRole = {
        resourceType: 'PractitionerRole',
        active: true,
        practitioner,
        organization,
        code: [
          {
            coding: [
              {
                system: 'http://snomed.info/sct',
                code: roleCode,
                display: roleOptions.find((opt) => opt.value === roleCode)?.label,
              },
            ],
          },
        ],
      };

      await medplum.createResource(role);

      notifications.show({
        title: 'Success',
        message: 'Role assigned successfully',
        color: 'green',
      });

      navigate('/roles');
    } catch (error) {
      notifications.show({
        title: 'Error',
        message: 'Failed to assign role',
        color: 'red',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container size="md">
      <Title order={2} mb="md">
        Assign Practitioner to Organization
      </Title>

      <Paper shadow="sm" p="md">
        <Text size="sm" c="dimmed" mb="md">
          Create a PractitionerRole to link a practitioner to an organization. Each practitioner can
          have multiple roles across different organizations.
        </Text>

        <form onSubmit={handleSubmit}>
          <Stack>
            <div>
              <Text size="sm" fw={500} mb={4}>
                Practitioner *
              </Text>
              <ReferenceInput
                name="practitioner"
                targetTypes={['Practitioner']}
                placeholder="Select a practitioner"
                onChange={(value) => setPractitioner(value as Reference<Practitioner>)}
              />
            </div>

            <div>
              <Text size="sm" fw={500} mb={4}>
                Organization *
              </Text>
              <ReferenceInput
                name="organization"
                targetTypes={['Organization']}
                placeholder="Select an organization"
                onChange={(value) => setOrganization(value as Reference<Organization>)}
              />
            </div>

            <Select
              label="Role *"
              placeholder="Select role type"
              data={roleOptions}
              value={roleCode}
              onChange={(value) => setRoleCode(value || '')}
              searchable
            />

            <Group mt="md">
              <Button type="submit" loading={loading}>
                Assign Role
              </Button>
              <Button variant="default" onClick={() => navigate('/roles')}>
                Cancel
              </Button>
            </Group>
          </Stack>
        </form>
      </Paper>
    </Container>
  );
}

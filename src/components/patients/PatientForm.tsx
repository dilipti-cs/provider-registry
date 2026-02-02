import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Container, Title, Paper, Button, Group, Stack, Text, Divider } from '@mantine/core';
import { notifications } from '@mantine/notifications';
import { useMedplum } from '@medplum/react';
import { ResourceForm, ReferenceInput } from '@medplum/react';
import { Patient, Reference, Organization, PractitionerRole } from '@medplum/fhirtypes';

export default function PatientForm() {
  const { id } = useParams();
  const medplum = useMedplum();
  const navigate = useNavigate();
  const [patient, setPatient] = useState<Patient | undefined>();
  const [loading, setLoading] = useState(!!id);
  const [managingOrganization, setManagingOrganization] = useState<Reference<Organization>>();
  const [generalPractitioners, setGeneralPractitioners] = useState<Reference<PractitionerRole>[]>(
    []
  );

  useEffect(() => {
    if (id) {
      loadPatient();
    }
  }, [id]);

  const loadPatient = async () => {
    if (!id) return;

    setLoading(true);
    try {
      const pat = await medplum.readResource('Patient', id);
      setPatient(pat);
      setManagingOrganization(pat.managingOrganization);
      setGeneralPractitioners((pat.generalPractitioner || []) as Reference<PractitionerRole>[]);
    } catch (error) {
      notifications.show({
        title: 'Error',
        message: 'Failed to load patient',
        color: 'red',
      });
      navigate('/patients');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (resource: Patient) => {
    try {
      // Add managing organization and general practitioners
      const updatedResource: Patient = {
        ...resource,
        managingOrganization,
        generalPractitioner: generalPractitioners,
      };

      if (id) {
        // Update existing patient
        await medplum.updateResource({ ...updatedResource, id });
        notifications.show({
          title: 'Success',
          message: 'Patient updated successfully',
          color: 'green',
        });
      } else {
        // Create new patient
        await medplum.createResource(updatedResource);
        notifications.show({
          title: 'Success',
          message: 'Patient created successfully',
          color: 'green',
        });
      }
      navigate('/patients');
    } catch (error) {
      notifications.show({
        title: 'Error',
        message: 'Failed to save patient',
        color: 'red',
      });
    }
  };

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <Container size="lg">
      <Title order={2} mb="md">
        {id ? 'Edit Patient' : 'New Patient'}
      </Title>

      <Paper shadow="sm" p="md" mb="md">
        <Stack>
          <Title order={4}>Patient Demographics</Title>
          <ResourceForm
            defaultValue={
              patient || {
                resourceType: 'Patient',
                active: true,
                name: [
                  {
                    family: '',
                    given: [''],
                  },
                ],
              }
            }
            onSubmit={(resource) => handleSubmit(resource as Patient)}
          />
        </Stack>
      </Paper>

      <Paper shadow="sm" p="md" mb="md">
        <Stack>
          <Title order={4}>Provider Connections</Title>
          <Text size="sm" c="dimmed">
            Link this patient to their managing organization and primary care providers
          </Text>

          <Divider />

          <div>
            <Text size="sm" fw={500} mb={4}>
              Managing Organization
            </Text>
            <ReferenceInput
              name="managingOrganization"
              targetTypes={['Organization']}
              placeholder="Select managing organization"
              defaultValue={managingOrganization}
              onChange={(value) => setManagingOrganization(value as Reference<Organization>)}
            />
            <Text size="xs" c="dimmed" mt={4}>
              The organization that manages this patient's care
            </Text>
          </div>

          <div>
            <Text size="sm" fw={500} mb={4}>
              General Practitioners (Primary Providers)
            </Text>
            <ReferenceInput
              name="generalPractitioner"
              targetTypes={['PractitionerRole']}
              placeholder="Select primary provider (PractitionerRole)"
              defaultValue={generalPractitioners[0]}
              onChange={(value) => {
                if (value) {
                  setGeneralPractitioners([value as Reference<PractitionerRole>]);
                } else {
                  setGeneralPractitioners([]);
                }
              }}
            />
            <Text size="xs" c="dimmed" mt={4}>
              Important: Link to PractitionerRole (not Practitioner directly) to include both the
              provider and their organization context
            </Text>
          </div>
        </Stack>
      </Paper>

      <Group>
        <Button variant="default" onClick={() => navigate('/patients')}>
          Cancel
        </Button>
      </Group>
    </Container>
  );
}

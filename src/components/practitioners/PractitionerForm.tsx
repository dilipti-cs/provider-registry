import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Container, Title, Paper, Button, Group } from '@mantine/core';
import { notifications } from '@mantine/notifications';
import { useMedplum } from '@medplum/react';
import { ResourceForm } from '@medplum/react';
import { Practitioner } from '@medplum/fhirtypes';

export default function PractitionerForm() {
  const { id } = useParams();
  const medplum = useMedplum();
  const navigate = useNavigate();
  const [practitioner, setPractitioner] = useState<Practitioner | undefined>();
  const [loading, setLoading] = useState(!!id);

  useEffect(() => {
    if (id) {
      loadPractitioner();
    }
  }, [id]);

  const loadPractitioner = async () => {
    if (!id) return;

    setLoading(true);
    try {
      const prac = await medplum.readResource('Practitioner', id);
      setPractitioner(prac);
    } catch (error) {
      notifications.show({
        title: 'Error',
        message: 'Failed to load practitioner',
        color: 'red',
      });
      navigate('/practitioners');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (resource: Practitioner) => {
    try {
      if (id) {
        // Update existing practitioner
        await medplum.updateResource({ ...resource, id });
        notifications.show({
          title: 'Success',
          message: 'Practitioner updated successfully',
          color: 'green',
        });
      } else {
        // Create new practitioner
        await medplum.createResource(resource);
        notifications.show({
          title: 'Success',
          message: 'Practitioner created successfully',
          color: 'green',
        });
      }
      navigate('/practitioners');
    } catch (error) {
      notifications.show({
        title: 'Error',
        message: 'Failed to save practitioner',
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
        {id ? 'Edit Practitioner' : 'New Practitioner'}
      </Title>

      <Paper shadow="sm" p="md">
        <ResourceForm
          defaultValue={
            practitioner || {
              resourceType: 'Practitioner',
              active: true,
              name: [
                {
                  family: '',
                  given: [''],
                },
              ],
            }
          }
          onSubmit={handleSubmit}
        />

        <Group mt="md">
          <Button variant="default" onClick={() => navigate('/practitioners')}>
            Cancel
          </Button>
        </Group>
      </Paper>
    </Container>
  );
}

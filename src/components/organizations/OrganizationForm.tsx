import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Container, Title, Paper, Button, Group } from '@mantine/core';
import { notifications } from '@mantine/notifications';
import { useMedplum } from '@medplum/react';
import { ResourceForm } from '@medplum/react';
import { Organization } from '@medplum/fhirtypes';

export default function OrganizationForm() {
  const { id } = useParams();
  const medplum = useMedplum();
  const navigate = useNavigate();
  const [organization, setOrganization] = useState<Organization | undefined>();
  const [loading, setLoading] = useState(!!id);

  useEffect(() => {
    if (id) {
      loadOrganization();
    }
  }, [id]);

  const loadOrganization = async () => {
    if (!id) return;

    setLoading(true);
    try {
      const org = await medplum.readResource('Organization', id);
      setOrganization(org);
    } catch (error) {
      notifications.show({
        title: 'Error',
        message: 'Failed to load organization',
        color: 'red',
      });
      navigate('/organizations');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (resource: Organization) => {
    try {
      if (id) {
        // Update existing organization
        await medplum.updateResource({ ...resource, id });
        notifications.show({
          title: 'Success',
          message: 'Organization updated successfully',
          color: 'green',
        });
      } else {
        // Create new organization
        await medplum.createResource(resource);
        notifications.show({
          title: 'Success',
          message: 'Organization created successfully',
          color: 'green',
        });
      }
      navigate('/organizations');
    } catch (error) {
      notifications.show({
        title: 'Error',
        message: 'Failed to save organization',
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
        {id ? 'Edit Organization' : 'New Organization'}
      </Title>

      <Paper shadow="sm" p="md">
        <ResourceForm
          defaultValue={
            organization || {
              resourceType: 'Organization',
              active: true,
              name: '',
              type: [
                {
                  coding: [
                    {
                      system: 'http://terminology.hl7.org/CodeSystem/organization-type',
                      code: 'prov',
                      display: 'Healthcare Provider',
                    },
                  ],
                },
              ],
            }
          }
          onSubmit={handleSubmit}
        />

        <Group mt="md">
          <Button variant="default" onClick={() => navigate('/organizations')}>
            Cancel
          </Button>
        </Group>
      </Paper>
    </Container>
  );
}

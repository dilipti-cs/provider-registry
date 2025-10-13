import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Container, Paper, Title, TextInput, PasswordInput, Button, Stack } from '@mantine/core';
import { notifications } from '@mantine/notifications';
import { useMedplum } from '@medplum/react';

export default function LoginPage() {
  const medplum = useMedplum();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      // Start the login process
      const loginResponse = await medplum.startLogin({ email, password });

      // Complete the login with the code
      if (loginResponse.code) {
        await medplum.processCode(loginResponse.code);
      }

      // Verify we have a profile
      const profile = await medplum.getProfile();
      if (profile) {
        notifications.show({
          title: 'Success',
          message: 'Logged in successfully',
          color: 'green',
        });
        navigate('/');
      }
    } catch (error) {
      console.error('Login error:', error);
      notifications.show({
        title: 'Error',
        message: 'Invalid credentials or login failed',
        color: 'red',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container size={420} my={40}>
      <Title ta="center" mb={20}>
        Provider Registry
      </Title>

      <Paper withBorder shadow="md" p={30} mt={30} radius="md">
        <form onSubmit={handleLogin}>
          <Stack>
            <TextInput
              label="Email"
              placeholder="your@email.com"
              required
              value={email}
              onChange={(e) => setEmail(e.currentTarget.value)}
            />

            <PasswordInput
              label="Password"
              placeholder="Your password"
              required
              value={password}
              onChange={(e) => setPassword(e.currentTarget.value)}
            />

            <Button type="submit" fullWidth loading={loading}>
              Sign in
            </Button>
          </Stack>
        </form>
      </Paper>
    </Container>
  );
}

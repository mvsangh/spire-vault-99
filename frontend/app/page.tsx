'use client';

import { Box, Container, Typography, Button } from '@mui/material';
import { useRouter } from 'next/navigation';

export default function HomePage() {
  const router = useRouter();

  return (
    <Container maxWidth="md">
      <Box
        sx={{
          minHeight: '100vh',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'center',
          textAlign: 'center',
          gap: 3,
        }}
      >
        <Typography variant="h2" component="h1" gutterBottom>
          SPIRE-Vault-99
        </Typography>
        <Typography variant="h5" color="text.secondary" gutterBottom>
          Zero-Trust Security Platform
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Brooklyn Nine-Nine themed demo showcasing SPIRE/SPIFFE, OpenBao, and Cilium integration
        </Typography>
        <Box sx={{ display: 'flex', gap: 2, mt: 2 }}>
          <Button
            variant="contained"
            size="large"
            onClick={() => router.push('/auth/login')}
          >
            Login
          </Button>
          <Button
            variant="outlined"
            size="large"
            onClick={() => router.push('/auth/register')}
          >
            Register
          </Button>
        </Box>
      </Box>
    </Container>
  );
}

'use client';

import { useEffect, useState } from 'react';
import {
  Container,
  Box,
  Typography,
  Paper,
  Card,
  CardContent,
  Chip,
  Alert,
} from '@mui/material';
import { CheckCircle, Error, Pending } from '@mui/icons-material';
import NavBar from '@/components/NavBar';
import ProtectedRoute from '@/components/ProtectedRoute';
import { useAuth } from '@/contexts/AuthContext';
import { healthAPI } from '@/lib/api/client';
import type { HealthResponse } from '@/types';

export default function DashboardPage() {
  const { user } = useAuth();
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [healthError, setHealthError] = useState<string | null>(null);

  useEffect(() => {
    const fetchHealth = async () => {
      try {
        const data = await healthAPI.check();
        setHealth(data);
      } catch (error) {
        setHealthError('Failed to fetch backend health status');
      }
    };

    fetchHealth();
    const interval = setInterval(fetchHealth, 10000); // Poll every 10 seconds

    return () => clearInterval(interval);
  }, []);

  const getStatusIcon = (status: string) => {
    if (status === 'ready') return <CheckCircle color="success" />;
    if (status === 'not_ready') return <Error color="error" />;
    return <Pending color="warning" />;
  };

  const getStatusColor = (status: string): 'success' | 'error' | 'warning' => {
    if (status === 'ready') return 'success';
    if (status === 'not_ready') return 'error';
    return 'warning';
  };

  return (
    <ProtectedRoute>
      <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
        <NavBar />

        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Typography variant="h3" component="h1" gutterBottom>
            Dashboard
          </Typography>

          {user && (
            <Paper sx={{ p: 3, mb: 3 }}>
              <Typography variant="h5" gutterBottom>
                Welcome, {user.username}!
              </Typography>
              <Typography variant="body1" color="text.secondary">
                Email: {user.email || 'Not provided'}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                Account created: {user.created_at ? new Date(user.created_at).toLocaleDateString() : 'Unknown'}
              </Typography>
            </Paper>
          )}

          <Typography variant="h5" gutterBottom sx={{ mt: 4 }}>
            Backend System Status
          </Typography>

          {healthError && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {healthError}
            </Alert>
          )}

          {health && (
            <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: 2 }}>
              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                    {getStatusIcon(health.spire)}
                    <Typography variant="h6">SPIRE</Typography>
                  </Box>
                  <Chip
                    label={health.spire}
                    color={getStatusColor(health.spire)}
                    size="small"
                  />
                </CardContent>
              </Card>

              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                    {getStatusIcon(health.vault)}
                    <Typography variant="h6">Vault</Typography>
                  </Box>
                  <Chip
                    label={health.vault}
                    color={getStatusColor(health.vault)}
                    size="small"
                  />
                </CardContent>
              </Card>

              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                    {getStatusIcon(health.database)}
                    <Typography variant="h6">Database</Typography>
                  </Box>
                  <Chip
                    label={health.database}
                    color={getStatusColor(health.database)}
                    size="small"
                  />
                </CardContent>
              </Card>

              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                    {getStatusIcon(health.status)}
                    <Typography variant="h6">Overall</Typography>
                  </Box>
                  <Chip
                    label={health.status}
                    color={getStatusColor(health.status)}
                    size="small"
                  />
                </CardContent>
              </Card>
            </Box>
          )}

          <Paper sx={{ p: 3, mt: 4 }}>
            <Typography variant="h6" gutterBottom>
              About This Platform
            </Typography>
            <Typography variant="body2" paragraph>
              <strong>SPIRE-Vault-99</strong> is a zero-trust security demonstration platform showcasing:
            </Typography>
            <Box component="ul" sx={{ pl: 2 }}>
              <Typography component="li" variant="body2">
                <strong>SPIRE/SPIFFE:</strong> Workload identity with X.509 and JWT-SVID
              </Typography>
              <Typography component="li" variant="body2">
                <strong>OpenBao:</strong> Secrets management with dynamic database credentials
              </Typography>
              <Typography component="li" variant="body2">
                <strong>Cilium:</strong> Service mesh with SPIFFE-based network policies
              </Typography>
              <Typography component="li" variant="body2">
                <strong>PostgreSQL:</strong> Database with Brooklyn Nine-Nine demo data
              </Typography>
            </Box>
            <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 2 }}>
              Version: {health?.version || '1.0.0'}
            </Typography>
          </Paper>
        </Container>
      </Box>
    </ProtectedRoute>
  );
}

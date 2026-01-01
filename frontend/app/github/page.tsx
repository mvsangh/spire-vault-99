'use client';

import { useState } from 'react';
import {
  Container,
  Box,
  Typography,
  Paper,
  Tabs,
  Tab,
  TextField,
  Button,
  Alert,
  Card,
  CardContent,
  Chip,
  Avatar,
  CircularProgress,
  Link as MuiLink,
} from '@mui/material';
import { GitHub, Star, Code } from '@mui/icons-material';
import NavBar from '@/components/NavBar';
import ProtectedRoute from '@/components/ProtectedRoute';
import { githubAPI } from '@/lib/api/client';
import { useSnackbar } from 'notistack';
import type { GitHubRepo, GitHubUser, APIError } from '@/types';

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`github-tabpanel-${index}`}
      {...other}
    >
      {value === index && <Box sx={{ py: 3 }}>{children}</Box>}
    </div>
  );
}

export default function GitHubPage() {
  const [tabValue, setTabValue] = useState(0);
  const { enqueueSnackbar } = useSnackbar();

  // Configure tab state
  const [token, setToken] = useState('');
  const [configuring, setConfiguring] = useState(false);
  const [configSuccess, setConfigSuccess] = useState(false);

  // Repos tab state
  const [repos, setRepos] = useState<GitHubRepo[]>([]);
  const [loadingRepos, setLoadingRepos] = useState(false);

  // User tab state
  const [user, setUser] = useState<GitHubUser | null>(null);
  const [loadingUser, setLoadingUser] = useState(false);

  const handleTabChange = (event: React.SyntheticEvent, newValue: number) => {
    setTabValue(newValue);
  };

  const handleConfigureToken = async () => {
    if (!token.trim()) {
      enqueueSnackbar('Please enter a GitHub token', { variant: 'warning' });
      return;
    }

    setConfiguring(true);
    try {
      await githubAPI.configure(token);
      setConfigSuccess(true);
      setToken('');
      enqueueSnackbar('GitHub token configured successfully!', { variant: 'success' });
    } catch (err) {
      const error = err as APIError;
      enqueueSnackbar(error.detail, { variant: 'error' });
    } finally {
      setConfiguring(false);
    }
  };

  const handleFetchRepos = async () => {
    setLoadingRepos(true);
    try {
      const data = await githubAPI.getRepositories();
      setRepos(data);
      enqueueSnackbar(`Loaded ${data.length} repositories`, { variant: 'success' });
    } catch (err) {
      const error = err as APIError;
      enqueueSnackbar(error.detail, { variant: 'error' });
      setRepos([]);
    } finally {
      setLoadingRepos(false);
    }
  };

  const handleFetchUser = async () => {
    setLoadingUser(true);
    try {
      const data = await githubAPI.getUser();
      setUser(data);
      enqueueSnackbar('GitHub profile loaded', { variant: 'success' });
    } catch (err) {
      const error = err as APIError;
      enqueueSnackbar(error.detail, { variant: 'error' });
      setUser(null);
    } finally {
      setLoadingUser(false);
    }
  };

  return (
    <ProtectedRoute>
      <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
        <NavBar />

        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 3 }}>
            <GitHub fontSize="large" />
            <Typography variant="h3" component="h1">
              GitHub Integration
            </Typography>
          </Box>

          <Paper sx={{ width: '100%' }}>
            <Tabs
              value={tabValue}
              onChange={handleTabChange}
              aria-label="GitHub integration tabs"
            >
              <Tab label="Configure Token" />
              <Tab label="Repositories" />
              <Tab label="Profile" />
            </Tabs>

            {/* Configure Token Tab */}
            <TabPanel value={tabValue} index={0}>
              <Box sx={{ maxWidth: 600 }}>
                <Typography variant="h6" gutterBottom>
                  Configure GitHub Personal Access Token
                </Typography>
                <Typography variant="body2" color="text.secondary" paragraph>
                  Your GitHub token is securely stored in OpenBao (Vault) and never exposed in the database.
                </Typography>

                {configSuccess && (
                  <Alert severity="success" sx={{ mb: 2 }}>
                    Token configured successfully! You can now view your repositories and profile.
                  </Alert>
                )}

                <TextField
                  fullWidth
                  label="GitHub Personal Access Token"
                  type="password"
                  value={token}
                  onChange={(e) => setToken(e.target.value)}
                  placeholder="ghp_xxxxxxxxxxxx"
                  helperText="Get your token from https://github.com/settings/tokens"
                  sx={{ mb: 2 }}
                />

                <Button
                  variant="contained"
                  onClick={handleConfigureToken}
                  disabled={configuring || !token.trim()}
                >
                  {configuring ? <CircularProgress size={24} /> : 'Save Token'}
                </Button>

                <Alert severity="info" sx={{ mt: 3 }}>
                  <Typography variant="body2" gutterBottom>
                    <strong>How to get a GitHub token:</strong>
                  </Typography>
                  <Typography variant="body2" component="ol" sx={{ pl: 2, mb: 0 }}>
                    <li>Go to GitHub Settings → Developer Settings → Personal Access Tokens</li>
                    <li>Generate new token (classic)</li>
                    <li>Select scopes: <code>repo</code>, <code>read:user</code></li>
                    <li>Copy the token and paste it above</li>
                  </Typography>
                </Alert>
              </Box>
            </TabPanel>

            {/* Repositories Tab */}
            <TabPanel value={tabValue} index={1}>
              <Box>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                  <Typography variant="h6">
                    Your Repositories
                  </Typography>
                  <Button
                    variant="contained"
                    onClick={handleFetchRepos}
                    disabled={loadingRepos}
                  >
                    {loadingRepos ? <CircularProgress size={24} /> : 'Load Repositories'}
                  </Button>
                </Box>

                {repos.length === 0 && !loadingRepos && (
                  <Alert severity="info">
                    Click "Load Repositories" to fetch your GitHub repos using the token stored in Vault.
                  </Alert>
                )}

                <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: 2 }}>
                  {repos.map((repo) => (
                    <Card key={repo.id}>
                      <CardContent>
                        <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1, mb: 1 }}>
                          <Code fontSize="small" />
                          <Typography variant="h6" component="div" sx={{ fontSize: '1rem' }}>
                            <MuiLink
                              href={repo.html_url}
                              target="_blank"
                              rel="noopener"
                              underline="hover"
                            >
                              {repo.name}
                            </MuiLink>
                          </Typography>
                        </Box>

                        <Typography variant="body2" color="text.secondary" sx={{ mb: 2, minHeight: 40 }}>
                          {repo.description || 'No description'}
                        </Typography>

                        <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                          {repo.language && (
                            <Chip label={repo.language} size="small" />
                          )}
                          <Chip
                            icon={<Star fontSize="small" />}
                            label={repo.stargazers_count}
                            size="small"
                            variant="outlined"
                          />
                        </Box>
                      </CardContent>
                    </Card>
                  ))}
                </Box>
              </Box>
            </TabPanel>

            {/* Profile Tab */}
            <TabPanel value={tabValue} index={2}>
              <Box>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                  <Typography variant="h6">
                    GitHub Profile
                  </Typography>
                  <Button
                    variant="contained"
                    onClick={handleFetchUser}
                    disabled={loadingUser}
                  >
                    {loadingUser ? <CircularProgress size={24} /> : 'Load Profile'}
                  </Button>
                </Box>

                {!user && !loadingUser && (
                  <Alert severity="info">
                    Click "Load Profile" to fetch your GitHub profile using the token stored in Vault.
                  </Alert>
                )}

                {user && (
                  <Card sx={{ maxWidth: 600 }}>
                    <CardContent>
                      <Box sx={{ display: 'flex', gap: 3, alignItems: 'flex-start' }}>
                        <Avatar
                          src={user.avatar_url}
                          alt={user.login}
                          sx={{ width: 100, height: 100 }}
                        />
                        <Box sx={{ flex: 1 }}>
                          <Typography variant="h5" gutterBottom>
                            {user.name || user.login}
                          </Typography>
                          <Typography variant="body2" color="text.secondary" gutterBottom>
                            @{user.login}
                          </Typography>
                          {user.bio && (
                            <Typography variant="body1" paragraph>
                              {user.bio}
                            </Typography>
                          )}
                          <Box sx={{ display: 'flex', gap: 2, mt: 2 }}>
                            <Chip label={`${user.public_repos} repos`} />
                            <Chip label={`${user.followers} followers`} />
                            <Chip label={`${user.following} following`} />
                          </Box>
                        </Box>
                      </Box>
                    </CardContent>
                  </Card>
                )}
              </Box>
            </TabPanel>
          </Paper>
        </Container>
      </Box>
    </ProtectedRoute>
  );
}

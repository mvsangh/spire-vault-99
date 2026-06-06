'use client';

import { useEffect, useState } from 'react';
import {
  Box,
  Container,
  Typography,
  Card,
  CardContent,
  CardActions,
  Button,
  Chip,
  Alert,
  CircularProgress,
  Divider,
  Paper,
  Tooltip,
  LinearProgress,
} from '@mui/material';
import {
  CheckCircle,
  Block,
  PlayArrow,
  Shield,
  Storage,
  VpnKey,
  Fingerprint,
  OpenInNew,
  ErrorOutline,
  Autorenew,
  Lock,
  Warning,
} from '@mui/icons-material';
import NavBar from '@/components/NavBar';
import ProtectedRoute from '@/components/ProtectedRoute';
import { demoAPI } from '@/lib/api/client';
import type { DemoScenarioMeta, ScenarioResult, RotationResult } from '@/types';

// ── icons per scenario ──────────────────────────────────────────────────────
const SCENARIO_ICONS: Record<string, React.ReactNode> = {
  'backend-to-postgres':       <Storage fontSize="large" />,
  'backend-to-openbao':        <VpnKey fontSize="large" />,
  'backend-spiffe-identity':   <Fingerprint fontSize="large" />,
  'dynamic-db-credentials':    <Shield fontSize="large" />,
  'blocked-spire-direct':      <Lock fontSize="large" />,
  'blocked-postgres-wrong-ns': <Warning fontSize="large" />,
};

// ── small helpers ────────────────────────────────────────────────────────────
function StatusChip({ status }: { status: string }) {
  const icon =
    status === 'allowed' ? <CheckCircle fontSize="small" /> :
    status === 'blocked' ? <Block fontSize="small" /> :
    <ErrorOutline fontSize="small" />;
  const color =
    status === 'allowed' ? 'success' :
    status === 'blocked' ? 'error' : 'warning';
  return (
    <Chip icon={icon} label={status.toUpperCase()}
      color={color as 'success' | 'error' | 'warning'}
      size="small" sx={{ fontWeight: 700, letterSpacing: 1 }} />
  );
}

function ExtraDetails({ extra }: { extra: Record<string, unknown> }) {
  return (
    <Box sx={{ mt: 1.5, p: 1.5, bgcolor: 'action.hover', borderRadius: 1 }}>
      {Object.entries(extra).map(([k, v]) => (
        <Box key={k} sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
          <Typography component="span" sx={{ color: 'text.secondary', fontFamily: 'monospace', fontSize: '0.75rem', minWidth: 200 }}>
            {k}:
          </Typography>
          <Typography component="span" sx={{ fontFamily: 'monospace', fontSize: '0.75rem', wordBreak: 'break-all' }}>
            {String(v)}
          </Typography>
        </Box>
      ))}
    </Box>
  );
}

// ── scenario card ────────────────────────────────────────────────────────────
function ScenarioCard({ scenario, result, running, onRun }: {
  scenario: DemoScenarioMeta;
  result: ScenarioResult | null;
  running: boolean;
  onRun: () => void;
}) {
  const hasResult = result !== null;
  const policyCorrect = hasResult && result.status === result.expected;
  const borderColor = !hasResult ? 'transparent'
    : policyCorrect
      ? (result.status === 'allowed' ? '#16a34a' : '#dc2626')
      : '#d97706';

  return (
    <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column',
      border: `2px solid ${borderColor}`, transition: 'border-color 0.3s' }}>
      {running && <LinearProgress />}
      <CardContent sx={{ flexGrow: 1 }}>
        <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2, mb: 2 }}>
          <Box sx={{ color: scenario.category === 'blocked' ? 'error.main' : 'primary.main', mt: 0.5 }}>
            {SCENARIO_ICONS[scenario.id] ?? <Shield fontSize="large" />}
          </Box>
          <Box sx={{ flexGrow: 1 }}>
            <Typography variant="h6" gutterBottom sx={{ lineHeight: 1.3 }}>
              {scenario.title}
            </Typography>
            <Chip
              label={`Expected: ${scenario.expected.toUpperCase()}`}
              color={scenario.expected === 'allowed' ? 'success' : 'error'}
              size="small" variant="outlined" sx={{ mb: 1 }} />
          </Box>
        </Box>

        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          {scenario.description}
        </Typography>

        {hasResult && (
          <Box>
            <Divider sx={{ mb: 1.5 }} />
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
              <StatusChip status={result.status} />
              {!policyCorrect && <Chip label="UNEXPECTED" color="warning" size="small" />}
              {policyCorrect && result.policy_enforced && <Chip label="Policy enforced" color="default" size="small" variant="outlined" />}
            </Box>
            <Typography variant="body2" sx={{ mb: 1 }}>{result.detail}</Typography>
            {result.extra && <ExtraDetails extra={result.extra} />}
          </Box>
        )}
      </CardContent>

      <CardActions sx={{ px: 2, pb: 2 }}>
        <Button
          variant={hasResult ? 'outlined' : 'contained'}
          color={scenario.category === 'blocked' ? 'error' : 'primary'}
          startIcon={running ? <CircularProgress size={16} color="inherit" /> : <PlayArrow />}
          onClick={onRun} disabled={running} size="small"
        >
          {running ? 'Running…' : hasResult ? 'Re-run' : 'Run Scenario'}
        </Button>
      </CardActions>
    </Card>
  );
}

// ── attack simulation panel ──────────────────────────────────────────────────
interface AttackProbeResult {
  source: string;
  target: string;
  host: string;
  port: number;
  label: string;
  reachable: boolean;
  status: 'allowed' | 'blocked';
  duration_ms: number;
  note: string;
}

const ATTACK_TARGETS = [
  { id: 'postgres', label: 'PostgreSQL (5432)', icon: <Storage />, description: 'Frontend pod attempts direct DB connection' },
  { id: 'openbao',  label: 'OpenBao (8200)',    icon: <VpnKey />,   description: 'Frontend pod attempts to read secrets directly' },
  { id: 'spire',   label: 'SPIRE Server (8081)', icon: <Lock />,    description: 'Frontend pod attempts direct SPIRE gRPC connection' },
];

function AttackPanel() {
  const [results, setResults] = useState<Record<string, AttackProbeResult>>({});
  const [running, setRunning] = useState<Record<string, boolean>>({});

  const probe = async (target: string) => {
    setRunning(prev => ({ ...prev, [target]: true }));
    try {
      const res = await fetch(`/api/demo/attack-probe?target=${target}`);
      const data: AttackProbeResult = await res.json();
      setResults(prev => ({ ...prev, [target]: data }));
    } catch {
      setResults(prev => ({
        ...prev,
        [target]: {
          source: 'frontend-pod', target, host: '', port: 0, label: target,
          reachable: false, status: 'blocked', duration_ms: 0,
          note: 'Request failed — frontend API route unavailable.',
        },
      }));
    } finally {
      setRunning(prev => ({ ...prev, [target]: false }));
    }
  };

  const probeAll = async () => {
    for (const t of ATTACK_TARGETS) await probe(t.id);
  };

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1 }}>
        <Warning color="error" />
        <Typography variant="h6">Attack Simulation — Frontend Trying to Reach Restricted Services</Typography>
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
        These probes run <strong>from the frontend pod itself</strong> (Next.js server-side), not from the backend.
        Cilium drops the packets — you will see the dropped flows appear in Hubble UI originating from the frontend pod IP.
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }}>
        Open <strong>Hubble UI → Namespace: 99-apps</strong> then click a probe below.
        Watch for red dropped flows from the frontend pod.
      </Alert>

      <Button variant="outlined" color="error" size="small"
        startIcon={<PlayArrow />} onClick={probeAll} sx={{ mb: 3 }}>
        Run All Attack Probes
      </Button>

      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: 'repeat(3, 1fr)' }, gap: 2 }}>
        {ATTACK_TARGETS.map(t => {
          const r = results[t.id];
          const isRunning = !!running[t.id];
          return (
            <Paper key={t.id} variant="outlined" sx={{
              p: 2,
              borderColor: r ? (r.reachable ? 'error.main' : 'success.main') : 'divider',
              transition: 'border-color 0.3s',
            }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1, color: 'error.main' }}>
                {t.icon}
                <Typography variant="subtitle2" fontWeight={700}>{t.label}</Typography>
              </Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2, fontSize: '0.78rem' }}>
                {t.description}
              </Typography>

              {r && (
                <Box sx={{ mb: 1.5 }}>
                  <Chip
                    icon={r.reachable ? <ErrorOutline fontSize="small" /> : <Block fontSize="small" />}
                    label={r.reachable ? 'NOT BLOCKED (!)' : `BLOCKED (${r.duration_ms}ms)`}
                    color={r.reachable ? 'warning' : 'success'}
                    size="small" sx={{ mb: 1, fontWeight: 700 }} />
                  <Typography variant="body2" sx={{ fontSize: '0.75rem', color: 'text.secondary' }}>
                    {r.note}
                  </Typography>
                </Box>
              )}

              <Button size="small" variant={r ? 'outlined' : 'contained'} color="error"
                startIcon={isRunning ? <CircularProgress size={14} color="inherit" /> : <PlayArrow />}
                onClick={() => probe(t.id)} disabled={isRunning}>
                {isRunning ? 'Probing…' : r ? 'Re-probe' : 'Attack'}
              </Button>
            </Paper>
          );
        })}
      </Box>
    </Paper>
  );
}

// ── credential rotation panel ────────────────────────────────────────────────
function RotationPanel() {
  const [rotating, setRotating] = useState(false);
  const [result, setResult] = useState<RotationResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const rotate = async () => {
    setRotating(true);
    setError(null);
    try {
      const r = await demoAPI.rotateCredentials();
      setResult(r);
    } catch {
      setError('Rotation failed — check backend logs.');
    } finally {
      setRotating(false);
    }
  };

  return (
    <Paper sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1 }}>
        <Autorenew color="secondary" />
        <Typography variant="h6">Force Credential Rotation</Typography>
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        OpenBao issues ephemeral PostgreSQL users that rotate every 50 minutes automatically.
        Click below to trigger an immediate rotation and watch the username change live.
        The old user is revoked from PostgreSQL the moment the new pool is ready.
      </Typography>

      <Button
        variant="contained"
        color="secondary"
        startIcon={rotating ? <CircularProgress size={18} color="inherit" /> : <Autorenew />}
        onClick={rotate}
        disabled={rotating}
        sx={{ mb: 2 }}
      >
        {rotating ? 'Rotating…' : 'Rotate DB Credentials Now'}
      </Button>

      {error && <Alert severity="error">{error}</Alert>}

      {result && (
        <Box sx={{ mt: 1 }}>
          <Alert severity="success" sx={{ mb: 2 }}>
            Rotated in <strong>{result.rotation_duration_ms}ms</strong> — old user revoked, new pool active.
          </Alert>
          <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
            <Paper variant="outlined" sx={{ p: 2 }}>
              <Typography variant="caption" color="text.secondary">OLD USERNAME (revoked)</Typography>
              <Typography sx={{ fontFamily: 'monospace', fontSize: '0.8rem', wordBreak: 'break-all', mt: 0.5, color: 'error.main' }}>
                {result.old_username}
              </Typography>
              <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 1 }}>Lease</Typography>
              <Typography sx={{ fontFamily: 'monospace', fontSize: '0.7rem', color: 'text.secondary', wordBreak: 'break-all' }}>
                {result.old_lease_id}
              </Typography>
            </Paper>
            <Paper variant="outlined" sx={{ p: 2 }}>
              <Typography variant="caption" color="text.secondary">NEW USERNAME (active)</Typography>
              <Typography sx={{ fontFamily: 'monospace', fontSize: '0.8rem', wordBreak: 'break-all', mt: 0.5, color: 'success.main' }}>
                {result.new_username}
              </Typography>
              <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 1 }}>Lease</Typography>
              <Typography sx={{ fontFamily: 'monospace', fontSize: '0.7rem', color: 'text.secondary', wordBreak: 'break-all' }}>
                {result.new_lease_id}
              </Typography>
            </Paper>
          </Box>
        </Box>
      )}
    </Paper>
  );
}

// ── main page ────────────────────────────────────────────────────────────────
export default function DemoPage() {
  const [scenarios, setScenarios] = useState<DemoScenarioMeta[]>([]);
  const [results, setResults] = useState<Record<string, ScenarioResult>>({});
  const [running, setRunning] = useState<Record<string, boolean>>({});
  const [loadError, setLoadError] = useState<string | null>(null);
  const [runningAll, setRunningAll] = useState(false);

  useEffect(() => {
    demoAPI.listScenarios()
      .then(data => setScenarios(data.scenarios))
      .catch(() => setLoadError('Failed to load scenarios — is the backend running?'));
  }, []);

  const runScenario = async (id: string) => {
    setRunning(prev => ({ ...prev, [id]: true }));
    try {
      const result = await demoAPI.runScenario(id);
      setResults(prev => ({ ...prev, [id]: result }));
    } catch {
      setResults(prev => ({
        ...prev,
        [id]: { scenario: id, title: '', description: '', status: 'error',
          detail: 'Request failed — backend unreachable.', expected: 'allowed', policy_enforced: false },
      }));
    } finally {
      setRunning(prev => ({ ...prev, [id]: false }));
    }
  };

  const runAll = async () => {
    setRunningAll(true);
    for (const s of scenarios) await runScenario(s.id);
    setRunningAll(false);
  };

  const allowed = scenarios.filter(s => s.category === 'allowed');
  const blocked = scenarios.filter(s => s.category === 'blocked');

  const allRan = scenarios.length > 0 && scenarios.every(s => results[s.id]);
  const allPassed = allRan && scenarios.every(s => results[s.id].status === results[s.id].expected);

  return (
    <ProtectedRoute>
      <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
        <NavBar />
        <Container maxWidth="lg" sx={{ py: 4 }}>

          {/* Header */}
          <Box sx={{ mb: 3 }}>
            <Typography variant="h3" fontWeight={700} gutterBottom>Security Demo</Typography>
            <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 700 }}>
              Live Cilium network policy enforcement. Each scenario runs a real TCP probe
              from the backend pod. Open <strong>Hubble UI</strong> alongside to watch
              allowed and dropped flows in real time.
            </Typography>
          </Box>

          {/* Hubble callout */}
          <Paper sx={{ p: 2, mb: 4, display: 'flex', alignItems: 'center', gap: 2,
            bgcolor: 'primary.main', color: 'primary.contrastText' }}>
            <Shield />
            <Box sx={{ flexGrow: 1 }}>
              <Typography variant="subtitle2" fontWeight={700}>Hubble UI — watch traffic in real time</Typography>
              <Typography variant="body2" sx={{ opacity: 0.9 }}>
                Filter by namespace <code>99-apps</code> then run scenarios below to see green (allowed) and red (dropped) flows.
              </Typography>
            </Box>
            <Tooltip title="Open Hubble UI (kubectl port-forward -n kube-system svc/hubble-ui 12000:80)">
              <Button variant="outlined" size="small" endIcon={<OpenInNew />}
                href="http://localhost:12000" target="_blank"
                sx={{ color: 'inherit', borderColor: 'rgba(255,255,255,0.5)', whiteSpace: 'nowrap' }}>
                Open Hubble
              </Button>
            </Tooltip>
          </Paper>

          {loadError && <Alert severity="error" sx={{ mb: 3 }}>{loadError}</Alert>}

          {/* Run all */}
          {scenarios.length > 0 && (
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 4 }}>
              <Button variant="contained" size="large"
                startIcon={runningAll ? <CircularProgress size={18} color="inherit" /> : <PlayArrow />}
                onClick={runAll} disabled={runningAll}>
                {runningAll ? 'Running all…' : 'Run All Scenarios'}
              </Button>
              {allPassed && (
                <Alert severity="success" sx={{ py: 0.5 }}>
                  All {scenarios.length} scenarios match expected Cilium enforcement.
                </Alert>
              )}
            </Box>
          )}

          {/* ALLOWED section */}
          {allowed.length > 0 && (
            <Box sx={{ mb: 4 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                <CheckCircle color="success" />
                <Typography variant="h5" fontWeight={600}>Allowed — Identified Workloads</Typography>
              </Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                These connections are permitted because the backend pod carries the correct label (<code>app=backend</code>)
                and namespace (<code>99-apps</code>) that Cilium policies allow.
              </Typography>
              <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: 'repeat(2, 1fr)' }, gap: 3 }}>
                {allowed.map(s => (
                  <ScenarioCard key={s.id} scenario={s} result={results[s.id] ?? null}
                    running={!!running[s.id]} onRun={() => runScenario(s.id)} />
                ))}
              </Box>
            </Box>
          )}

          {/* BLOCKED section */}
          {blocked.length > 0 && (
            <Box sx={{ mb: 4 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                <Block color="error" />
                <Typography variant="h5" fontWeight={600}>Blocked — Unauthorised Access Attempts</Typography>
              </Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                These connections are dropped by Cilium at the kernel level — the destination never even receives the packet.
                No application-level firewall involved.
              </Typography>
              <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: 'repeat(2, 1fr)' }, gap: 3 }}>
                {blocked.map(s => (
                  <ScenarioCard key={s.id} scenario={s} result={results[s.id] ?? null}
                    running={!!running[s.id]} onRun={() => runScenario(s.id)} />
                ))}
              </Box>
            </Box>
          )}

          {/* Attack simulation */}
          <Box sx={{ mb: 4 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
              <Warning color="error" />
              <Typography variant="h5" fontWeight={600}>Attack Simulation — From Frontend Pod</Typography>
            </Box>
            <AttackPanel />
          </Box>

          {/* Credential rotation */}
          <Box sx={{ mb: 4 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
              <Autorenew color="secondary" />
              <Typography variant="h5" fontWeight={600}>Dynamic Secrets — OpenBao Credential Rotation</Typography>
            </Box>
            <RotationPanel />
          </Box>

          {/* Legend */}
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>How Cilium enforces this</Typography>
            <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' }, gap: 2 }}>
              <Box>
                <Typography variant="subtitle2" color="success.main" gutterBottom>ALLOWED</Typography>
                <Typography variant="body2" color="text.secondary">
                  The source pod's labels match the <code>fromEndpoints</code> selector in the CiliumNetworkPolicy. eBPF passes the packet.
                </Typography>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="error.main" gutterBottom>BLOCKED</Typography>
                <Typography variant="body2" color="text.secondary">
                  No matching policy for this source. eBPF drops the packet in the kernel — the destination pod never receives it.
                  The connection times out from the sender's perspective.
                </Typography>
              </Box>
              <Box>
                <Typography variant="subtitle2" color="text.secondary" gutterBottom>Zero Trust principle</Typography>
                <Typography variant="body2" color="text.secondary">
                  Even if the frontend container is fully compromised, it cannot reach the database or OpenBao.
                  Policy is enforced at the kernel, not the application layer.
                </Typography>
              </Box>
            </Box>
          </Paper>

        </Container>
      </Box>
    </ProtectedRoute>
  );
}

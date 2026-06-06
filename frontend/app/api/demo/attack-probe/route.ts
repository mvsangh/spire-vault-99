import { NextRequest, NextResponse } from 'next/server';
import * as net from 'net';

// This route intentionally attempts direct TCP connections from the frontend
// pod to restricted services. Cilium will drop these — visible in Hubble as
// red dropped flows originating from the frontend pod.

function tcpProbe(host: string, port: number, timeoutMs = 4000): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    let settled = false;

    const done = (result: boolean) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(result);
    };

    socket.setTimeout(timeoutMs);
    socket.connect(port, host, () => done(true));
    socket.on('timeout', () => done(false));
    socket.on('error', () => done(false));
  });
}

export async function GET(request: NextRequest) {
  const target = request.nextUrl.searchParams.get('target') ?? 'postgres';

  const probes: Record<string, { host: string; port: number; label: string }> = {
    postgres: {
      host: 'postgresql.99-apps.svc.cluster.local',
      port: 5432,
      label: 'PostgreSQL',
    },
    openbao: {
      host: 'openbao.openbao.svc.cluster.local',
      port: 8200,
      label: 'OpenBao',
    },
    spire: {
      host: 'spire-server.spire-system.svc.cluster.local',
      port: 8081,
      label: 'SPIRE Server',
    },
  };

  const probe = probes[target];
  if (!probe) {
    return NextResponse.json({ error: 'Unknown target' }, { status: 400 });
  }

  const start = Date.now();
  const reachable = await tcpProbe(probe.host, probe.port);
  const duration = Date.now() - start;

  return NextResponse.json({
    source: 'frontend-pod',
    target,
    host: probe.host,
    port: probe.port,
    label: probe.label,
    reachable,
    status: reachable ? 'allowed' : 'blocked',
    duration_ms: duration,
    note: reachable
      ? 'WARNING: Frontend reached a restricted service — policy gap!'
      : `Cilium dropped the packet. Connection timed out after ${duration}ms. Check Hubble for the dropped flow.`,
  });
}

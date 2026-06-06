import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://backend.99-apps.svc.cluster.local:8000';

export async function GET() {
  try {
    const response = await fetch(`${BACKEND_URL}/api/v1/demo/scenarios`);
    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    return NextResponse.json({ detail: 'Backend unavailable' }, { status: 503 });
  }
}

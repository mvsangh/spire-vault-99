import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://backend.99-apps.svc.cluster.local:8000';

export async function GET(request: NextRequest) {
  try {
    const response = await fetch(`${BACKEND_URL}/api/v1/health/ready`, {
      method: 'GET',
    });

    const data = await response.json();

    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Health check API route error:', error);
    return NextResponse.json(
      { detail: 'Backend unavailable' },
      { status: 503 }
    );
  }
}

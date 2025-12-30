'use client';

import { ThemeProvider } from '@/contexts/ThemeContext';
import { SnackbarProvider } from 'notistack';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider>
      <SnackbarProvider
        maxSnack={3}
        anchorOrigin={{
          vertical: 'top',
          horizontal: 'right',
        }}
        autoHideDuration={3000}
      >
        {children}
      </SnackbarProvider>
    </ThemeProvider>
  );
}

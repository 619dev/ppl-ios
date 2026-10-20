import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.fm619tech.paperphonelite',
  appName: 'PaperPhoneLite',
  webDir: 'dist',
  server: {
    // Serve bundled assets through Capacitor's trusted local URL scheme.
    iosScheme: 'capacitor',
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: true,
      launchShowDuration: 2000,
      splashFullScreen: true,
      splashImmersive: true,
      backgroundColor: '#ffffff',
    },
  },
  ios: {
    // HTML applies native safe areas once; the container handles the keyboard.
    contentInset: 'never',
    allowsLinkPreview: false,
    scrollEnabled: false,
  },
}

export default config

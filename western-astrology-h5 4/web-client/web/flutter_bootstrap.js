{{flutter_js}}
{{flutter_build_config}}

// Keep the original Flutter loader, including its JavaScript compatibility build.
const fateFlutterConfig = {
  hostElement: document.getElementById('fate-flutter'),
  canvasKitBaseUrl: 'engine/' + _flutter.buildConfig.engineRevision + '/'
};
const fateBasePath = new URL('.', document.baseURI).pathname;
const fateLandingPath = location.pathname === fateBasePath || location.pathname === fateBasePath + 'index.html';
// The official loader selects the shipped JavaScript build for this one recovery document.
if(window.fateBoot.compatibility||window.fateBoot.embedded)fateFlutterConfig.renderer='canvaskit';
// Instagram's Android WebView is sensitive to the number of GPU/platform-view
// surfaces. Keep the Chromium-compatible CanvasKit build and cap overlays, but
// retain GPU rendering: forcing the whole report onto the CPU makes long pages
// and their scrolling unusably slow. The generation view separately avoids its
// video platform view on this browser.
if(document.documentElement.dataset.metaBrowser==='instagram'&&
   document.documentElement.dataset.metaPlatform==='android'){
  fateFlutterConfig.canvasKitMaximumSurfaces=2;
  fateFlutterConfig.canvasKitVariant='chromium';
}
if (!window.fateBoot.upgrading && fateLandingPath) {
  // The native form is the complete landing experience. Do not make it compete
  // with Flutter's engine, Wasm and fonts before the visitor can enter details.
  window.fateBoot.landingReady();
} else if (!window.fateBoot.upgrading) {
  preloadEngineAssets();
  _flutter.loader.load({
    config: fateFlutterConfig,
    onEntrypointLoaded: async (initializer) => {
      try {
        window.fateBoot.stage('engine');
        const app = await initializer.initializeEngine(fateFlutterConfig);
        window.fateBoot.stage('app');
        await app.runApp();
      } catch (error) {
        window.fateBoot.fail();
        console.error('FATE startup failed', error);
      }
    }
  }).catch(() => {
    window.fateBoot.fail();
    console.error('FATE loader failed');
  });
}

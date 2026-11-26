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
if(window.fateBoot.compatibility)fateFlutterConfig.renderer='canvaskit';
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

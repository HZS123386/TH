{{flutter_js}}
{{flutter_build_config}}

// Keep the original Flutter loader, including its JavaScript compatibility build.
const fateFlutterConfig = { canvasKitBaseUrl: 'engine/' + _flutter.buildConfig.engineRevision + '/' };
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
}).catch((error) => {
  window.fateBoot.fail();
  console.error('FATE loader failed', error);
});

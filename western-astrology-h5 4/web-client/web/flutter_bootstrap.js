{{flutter_js}}
{{flutter_build_config}}

// Keep the original Flutter loader, including its JavaScript compatibility build.
const fateFlutterConfig = { canvasKitBaseUrl: 'engine/' + _flutter.buildConfig.engineRevision + '/' };
// The official loader selects the shipped JavaScript build for this one recovery document.
if(window.fateBoot.compatibility)fateFlutterConfig.renderer='canvaskit';
if(!window.fateBoot.upgrading)_flutter.loader.load({
  config: fateFlutterConfig,
  onEntrypointLoaded: async (initializer) => {
    try {
      window.fateBoot.stage('engine');
      const app = await initializer.initializeEngine(fateFlutterConfig);
      window.fateBoot.stage('app');
      await app.runApp();
    } catch (error) {
      window.fateBoot.fail(error);
      console.error('FATE startup failed');
    }
  }
}).catch(error => {
  window.fateBoot.fail(error);
  console.error('FATE loader failed');
});

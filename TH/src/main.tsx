import ReactDOM from 'react-dom/client';
import '@fontsource/noto-sans-thai/400.css';
import '@fontsource/noto-sans-thai/500.css';
import '@fontsource/noto-sans-thai/600.css';
import App from './App';
import './styles.css';
import { i18nReady } from './lib/i18n';

void i18nReady.then(() => ReactDOM.createRoot(document.getElementById('root')!).render(<App />));

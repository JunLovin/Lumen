import { AppRegistry } from 'react-native';
import { name as appName } from './app.json';
import { createRoot } from './src/composition/create-root';

AppRegistry.registerComponent(appName, createRoot);

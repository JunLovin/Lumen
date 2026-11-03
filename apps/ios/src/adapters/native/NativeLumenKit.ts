import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  protocolVersion(): number;
}

export default TurboModuleRegistry.getEnforcing<Spec>('LumenKit');

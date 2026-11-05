import { en, type TranslationKey } from './en';
import { es } from './es';

const deviceLanguage = new Intl.DateTimeFormat()
  .resolvedOptions()
  .locale.split('-')[0];
const translations = deviceLanguage === 'es' ? es : en;

export const translate = (key: TranslationKey): string => translations[key];

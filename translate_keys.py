#!/usr/bin/env python3
"""
Translation script: Translates EN keys to 40 languages using Google Translate
"""
import json
import time
from google.cloud import translate_v2
from google.auth import default
import os

# Language codes (40 languages)
LANGUAGES = {
    'pt': 'Portuguese',
    'it': 'Italian',
    'pl': 'Polish',
    'ru': 'Russian',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'ko': 'Korean',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'pa': 'Punjabi',
    'te': 'Telugu',
    'mr': 'Marathi',
    'ta': 'Tamil',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'ms': 'Malay',
    'fil': 'Filipino',
    'uk': 'Ukrainian',
    'ro': 'Romanian',
    'el': 'Greek',
    'hu': 'Hungarian',
    'cs': 'Czech',
    'sv': 'Swedish',
    'da': 'Danish',
    'no': 'Norwegian',
    'fi': 'Finnish',
    'nl': 'Dutch',
    'be': 'Belarusian',
    'sr': 'Serbian',
    'hr': 'Croatian',
}

# EN translations (core set - extracted from app_texts.dart)
EN_TEXTS = {
    'appName': 'NO SMOKE',
    'selectLanguage': 'Select language',
    'splashTagline': '',
    'initialSurvey': 'Initial Survey',
    'name': 'Name',
    'age': 'Age',
    'gender': 'Gender',
    'male': 'Male',
    'female': 'Female',
    'selectOption': 'Select',
    'professionLabel': 'Profession',
    'yes': 'Yes',
    'no': 'No',
    'continue': 'Continue',
    'home': 'Home',
    'weeklySurvey': 'Weekly Survey',
    'riskAnalysis': 'Risk Analysis',
    'save': 'Save',
    'retry': 'Retry',
    'start': 'Start',
    'test': 'Test',
    'good': 'Good',
    'bad': 'Bad',
    'risk': 'Risk',
}

def translate_text(client, text, target_lang):
    """Translate text to target language"""
    if not text or text == '':
        return ''
    
    try:
        result = client.translate_text(
            source_language_code='en',
            target_language_code=target_lang,
            contents=[text]
        )
        return result['translations'][0]['translated_text']
    except Exception as e:
        print(f"Error translating to {target_lang}: {e}")
        return text

def main():
    # Initialize Google Translate client
    try:
        client = translate_v2.Client()
        print("✅ Google Translate API client initialized")
    except Exception as e:
        print(f"❌ Failed to initialize Google Translate: {e}")
        print("Make sure you have:")
        print("  1. Installed: pip install google-cloud-translate")
        print("  2. Set GOOGLE_APPLICATION_CREDENTIALS env var")
        print("  3. GCP credentials JSON file")
        return

    # Translate
    translations = {}
    for lang_code, lang_name in LANGUAGES.items():
        print(f"\n🌍 Translating to {lang_name} ({lang_code})...")
        translations[lang_code] = {}
        
        for key, en_text in EN_TEXTS.items():
            if en_text:
                translated = translate_text(client, en_text, lang_code)
                translations[lang_code][key] = translated
                print(f"  ✓ {key}")
            else:
                translations[lang_code][key] = ''
            
            time.sleep(0.05)  # Rate limiting

    # Save as JSON for reference
    with open('translations_output.json', 'w', encoding='utf-8') as f:
        json.dump(translations, f, ensure_ascii=False, indent=2)
    
    print("\n✅ Translations saved to translations_output.json")
    print("\nGenerated Dart code snippet:")
    print_dart_code(translations)

def print_dart_code(translations):
    """Print Dart map format"""
    for lang_code, texts in sorted(translations.items()):
        print(f"\n// {lang_code}")
        print(f"'{lang_code}': {{")
        for key, text in sorted(texts.items()):
            escaped = text.replace("'", "\\'")
            print(f"  '{key}': '{escaped}',")
        print("},")

if __name__ == '__main__':
    main()

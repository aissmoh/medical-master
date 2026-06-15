import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return PopupMenuButton<String>(
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LanguageProvider.supportedLanguages[languageProvider.currentLanguageCode]!['flag']!,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
          onSelected: (String languageCode) {
            languageProvider.changeLanguage(languageCode);
          },
          itemBuilder: (BuildContext context) {
            return LanguageProvider.supportedLanguages.entries.map((entry) {
              final code = entry.key;
              final data = entry.value;
              final isSelected = code == languageProvider.currentLanguageCode;
              
              return PopupMenuItem<String>(
                value: code,
                child: Row(
                  children: [
                    Text(
                      data['flag']!,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      data['nativeName']!,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : null,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check,
                        color: Theme.of(context).primaryColor,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Changer de Langue'),
      ),
      body: ListView.builder(
        itemCount: LanguageProvider.supportedLanguages.length,
        itemBuilder: (context, index) {
          final entry = LanguageProvider.supportedLanguages.entries.elementAt(index);
          final code = entry.key;
          final data = entry.value;
          final isSelected = code == languageProvider.currentLanguageCode;
          
          return ListTile(
            leading: Text(
              data['flag']!,
              style: const TextStyle(fontSize: 30),
            ),
            title: Text(
              data['nativeName']!,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
            subtitle: Text(data['name']!),
            trailing: isSelected 
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                )
              : null,
            selected: isSelected,
            onTap: () {
              languageProvider.changeLanguage(code);
              Navigator.pop(context);
              
              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Langue changée en ${data['nativeName']}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

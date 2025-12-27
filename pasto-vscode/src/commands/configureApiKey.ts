import * as vscode from 'vscode';

export function registerConfigureApiKeyCommand(
  context: vscode.ExtensionContext
): void {
  const disposable = vscode.commands.registerCommand('pasto.configureApiKey', async () => {
    const apiKey = await vscode.window.showInputBox({
      prompt: 'Enter your Pasto API Key',
      placeHolder: 'pasto_ak_...',
      password: true,
      ignoreFocusOut: true,
      validateInput: (value) => {
        if (!value) {
          return 'API key cannot be empty';
        }
        if (!value.startsWith('pasto_ak_')) {
          return 'API key should start with "pasto_ak_"';
        }
        return undefined;
      }
    });

    if (apiKey) {
      await context.secrets.store('pasto.apiKey', apiKey);
      vscode.window.showInformationMessage('API key saved successfully!');

      // Refresh paste tree
      vscode.commands.executeCommand('pasto.refreshPastes');
    }
  });

  context.subscriptions.push(disposable);
}

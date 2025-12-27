import * as vscode from 'vscode';
import { PastoTreeProvider } from './views/pasteTree';
import { PastoClient } from './api/pastoClient';
import { registerCreatePasteCommand } from './commands/createPaste';
import { registerFetchPasteCommand } from './commands/fetchPaste';
import { registerConfigureApiKeyCommand } from './commands/configureApiKey';
import { registerDeletePasteCommand } from './commands/deletePaste';
import { registerCopyPasteURLCommand } from './commands/copyPasteURL';
import { registerOpenPasteCommand } from './commands/openPaste';
import { registerRefreshPastesCommand } from './commands/refreshPastes';

export async function activate(context: vscode.ExtensionContext) {
  console.log('Pasto extension activated');

  // Initialize API client
  const apiClient = new PastoClient(context);

  // Register TreeView provider
  const treeProvider = new PastoTreeProvider(apiClient);
  vscode.window.registerTreeDataProvider('pastoView', treeProvider);

  // Register all commands
  registerCreatePasteCommand(context, apiClient);
  registerFetchPasteCommand(context, apiClient);
  registerConfigureApiKeyCommand(context);
  registerDeletePasteCommand(context, apiClient);
  registerCopyPasteURLCommand(context);
  registerOpenPasteCommand(context);
  registerRefreshPastesCommand(context, treeProvider);

  // Setup status bar
  const statusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100
  );
  statusBarItem.text = '$(file-code) Pasto';
  statusBarItem.tooltip = 'Create Pasto Paste';
  statusBarItem.command = 'pasto.createPaste';
  statusBarItem.show();
  context.subscriptions.push(statusBarItem);

  // Check if API key is configured
  const apiKey = await context.secrets.get('pasto.apiKey');
  if (!apiKey) {
    const result = await vscode.window.showInformationMessage(
      'Pasto extension requires an API key. Would you like to configure it now?',
      'Configure',
      'Later'
    );
    if (result === 'Configure') {
      await vscode.commands.executeCommand('pasto.configureApiKey');
    }
  }
}

export function deactivate() {
  console.log('Pasto extension deactivated');
}

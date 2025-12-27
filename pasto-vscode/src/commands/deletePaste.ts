import * as vscode from 'vscode';
import { PastoClient } from '../api/pastoClient';
import { Paste } from '../api/pastoClient';

export function registerDeletePasteCommand(
  context: vscode.ExtensionContext,
  apiClient: PastoClient
): void {
  const disposable = vscode.commands.registerCommand('pasto.deletePaste', async (paste: Paste) => {
    if (!paste) {
      return;
    }

    const confirm = await vscode.window.showWarningMessage(
      `Are you sure you want to delete "${paste.title || paste.id}"?`,
      { modal: true },
      'Delete'
    );

    if (confirm !== 'Delete') {
      return;
    }

    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Deleting paste...',
        cancellable: false
      },
      async () => {
        try {
          await apiClient.deletePaste(paste.id);
          vscode.window.showInformationMessage('Paste deleted successfully');

          // Refresh paste tree
          vscode.commands.executeCommand('pasto.refreshPastes');
        } catch (error) {
          vscode.window.showErrorMessage(`Failed to delete paste: ${error}`);
        }
      }
    );
  });

  context.subscriptions.push(disposable);
}

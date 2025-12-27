import * as vscode from 'vscode';
import { PastoClient } from '../api/pastoClient';

export function registerFetchPasteCommand(
  context: vscode.ExtensionContext,
  apiClient: PastoClient
): void {
  const disposable = vscode.commands.registerCommand('pasto.fetchPaste', async () => {
    const pasteId = await vscode.window.showInputBox({
      prompt: 'Enter Paste ID or URL',
      placeHolder: 'abc123 or https://pasto.example.com/abc123'
    });

    if (!pasteId) {
      return;
    }

    // Extract ID from URL if needed
    const id = pasteId.includes('/')
      ? pasteId.split('/').pop() || pasteId
      : pasteId;

    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Fetching paste...',
        cancellable: false
      },
      async () => {
        try {
          const paste = await apiClient.fetchPaste(id);

          // Create new untitled document with paste content
          const doc = await vscode.workspace.openTextDocument({
            content: paste.content,
            language: paste.language
          });

          await vscode.window.showTextDocument(doc);
          vscode.window.showInformationMessage(`Fetched paste: ${paste.title || paste.id}`);
        } catch (error) {
          vscode.window.showErrorMessage(`Failed to fetch paste: ${error}`);
        }
      }
    );
  });

  context.subscriptions.push(disposable);
}

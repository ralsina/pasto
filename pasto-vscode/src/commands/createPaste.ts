import * as vscode from 'vscode';
import { PastoClient } from '../api/pastoClient';

export function registerCreatePasteCommand(
  context: vscode.ExtensionContext,
  apiClient: PastoClient
): void {
  const disposable = vscode.commands.registerCommand('pasto.createPaste', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showErrorMessage('No active editor found');
      return;
    }

    // Get selected text or entire document
    const selection = editor.selection;
    const text = selection.isEmpty
      ? editor.document.getText()
      : editor.document.getText(selection);

    if (!text) {
      vscode.window.showWarningMessage('No text to paste');
      return;
    }

    // Get configuration
    const config = vscode.workspace.getConfiguration('pasto');
    const autoDetect = config.get<boolean>('autoDetectLanguage', true);

    // Detect language from file extension
    let language = 'text';
    if (autoDetect) {
      const languageId = editor.document.languageId;
      language = languageId !== 'plaintext' ? languageId : 'text';
    }

    // Get title from user
    const title = await vscode.window.showInputBox({
      prompt: 'Enter paste title (optional)',
      placeHolder: 'My Paste'
    });

    // Show progress
    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Creating paste...',
        cancellable: false
      },
      async (progress) => {
        try {
          const paste = await apiClient.createPaste({
            content: text,
            language,
            title,
            private: config.get<boolean>('defaultPrivate', false)
          });

          // Copy URL to clipboard if enabled
          if (config.get<boolean>('copyUrlAfterCreate', true)) {
            await vscode.env.clipboard.writeText(paste.url);
          }

          // Show success message with action buttons
          const result = await vscode.window.showInformationMessage(
            `Paste created! ${config.get<boolean>('copyUrlAfterCreate') ? '(URL copied)' : ''}`,
            'Open in Browser',
            'Copy URL'
          );

          if (result === 'Open in Browser') {
            vscode.env.openExternal(vscode.Uri.parse(paste.url));
          } else if (result === 'Copy URL') {
            await vscode.env.clipboard.writeText(paste.url);
            vscode.window.showInformationMessage('URL copied to clipboard');
          }

          // Refresh paste tree
          vscode.commands.executeCommand('pasto.refreshPastes');
        } catch (error) {
          vscode.window.showErrorMessage(`Failed to create paste: ${error}`);
        }
      }
    );
  });

  context.subscriptions.push(disposable);
}

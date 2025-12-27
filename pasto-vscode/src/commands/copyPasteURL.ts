import * as vscode from 'vscode';
import { Paste } from '../api/pastoClient';

export function registerCopyPasteURLCommand(
  context: vscode.ExtensionContext
): void {
  const disposable = vscode.commands.registerCommand('pasto.copyPasteURL', async (paste: Paste) => {
    if (!paste) {
      return;
    }

    await vscode.env.clipboard.writeText(paste.url);
    vscode.window.showInformationMessage('URL copied to clipboard');
  });

  context.subscriptions.push(disposable);
}

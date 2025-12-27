import * as vscode from 'vscode';
import { Paste } from '../api/pastoClient';

export function registerOpenPasteCommand(
  context: vscode.ExtensionContext
): void {
  const disposable = vscode.commands.registerCommand('pasto.openPaste', async (paste: Paste) => {
    if (!paste) {
      return;
    }

    // Create new untitled document with paste content
    const doc = await vscode.workspace.openTextDocument({
      content: paste.content,
      language: paste.language
    });

    await vscode.window.showTextDocument(doc);
  });

  context.subscriptions.push(disposable);
}

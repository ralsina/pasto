import * as vscode from 'vscode';
import { PastoTreeProvider } from '../views/pasteTree';

export function registerRefreshPastesCommand(
  context: vscode.ExtensionContext,
  treeProvider: PastoTreeProvider
): void {
  const disposable = vscode.commands.registerCommand('pasto.refreshPastes', async () => {
    treeProvider.refresh();
  });

  context.subscriptions.push(disposable);
}

import * as vscode from 'vscode';
import { PastoClient, Paste } from '../api/pastoClient';

export class PastoTreeProvider implements vscode.TreeDataProvider<PasteTreeItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<PasteTreeItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  constructor(private apiClient: PastoClient) {}

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: PasteTreeItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: PasteTreeItem): Promise<PasteTreeItem[]> {
    if (element) {
      return [];
    }

    try {
      const pastes = await this.apiClient.listPastes();
      return pastes.map(p => new PasteTreeItem(p));
    } catch (error) {
      vscode.window.showErrorMessage(`Failed to load pastes: ${error}`);
      return [];
    }
  }
}

export class PasteTreeItem extends vscode.TreeItem {
  constructor(public readonly paste: Paste) {
    super(paste.title || paste.id, vscode.TreeItemCollapsibleState.None);

    this.tooltip = `${paste.language} - Created ${new Date(paste.created_at).toLocaleString()}`;
    this.description = paste.language;
    this.contextValue = 'paste';

    // Set icon based on paste type
    if (paste.encrypted) {
      this.iconPath = new vscode.ThemeIcon('lock');
    } else if (paste.private) {
      this.iconPath = new vscode.ThemeIcon('eye-closed');
    } else {
      this.iconPath = new vscode.ThemeIcon('file-code');
    }

    // Click to open paste
    this.command = {
      command: 'pasto.openPaste',
      title: 'Open Paste',
      arguments: [paste]
    };
  }
}

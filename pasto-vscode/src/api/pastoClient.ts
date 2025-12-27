import * as vscode from 'vscode';
import * as https from 'https';
import * as http from 'http';
import * as url from 'url';

export interface Paste {
  id: string;
  content: string;
  language: string;
  title?: string;
  created_at: string;
  expires_at?: string;
  private: boolean;
  encrypted: boolean;
  url: string;
}

export interface CreatePasteOptions {
  content: string;
  language?: string;
  title?: string;
  private?: boolean;
  expires_at?: string;
}

export class PastoClient {
  private context: vscode.ExtensionContext;
  private baseUrl: string;

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
    const config = vscode.workspace.getConfiguration('pasto');
    this.baseUrl = config.get<string>('instanceUrl') || 'https://pasto1.ralsina.me';
  }

  private async getApiKey(): Promise<string | undefined> {
    return await this.context.secrets.get('pasto.apiKey');
  }

  private async request(method: string, path: string, body?: string): Promise<any> {
    const apiKey = await this.getApiKey();
    if (!apiKey) {
      throw new Error('API key not configured');
    }

    const parsedUrl = url.parse(this.baseUrl + path);
    const isHttps = parsedUrl.protocol === 'https:';
    const client = isHttps ? https : http;

    const options: http.RequestOptions | https.RequestOptions = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port,
      path: parsedUrl.path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      }
    };

    return new Promise((resolve, reject) => {
      const req = client.request(options, (res) => {
        let data = '';

        res.on('data', (chunk) => {
          data += chunk;
        });

        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve(JSON.parse(data));
            } catch (e) {
              resolve(data);
            }
          } else {
            reject(new Error(`Request failed with status ${res.statusCode}: ${data}`));
          }
        });
      });

      req.on('error', (error) => {
        reject(error);
      });

      if (body) {
        req.write(body);
      }

      req.end();
    });
  }

  async createPaste(options: CreatePasteOptions): Promise<Paste> {
    const data = await this.request('POST', '/api/v1/pastes', JSON.stringify({
      content: options.content,
      language: options.language || 'text',
      title: options.title,
      private: options.private,
      expires_at: options.expires_at
    }));

    return {
      id: data.id,
      content: data.content,
      language: data.language,
      title: data.title,
      created_at: data.created_at,
      expires_at: data.expires_at,
      private: data.private,
      encrypted: data.encrypted || false,
      url: `${this.baseUrl}/${data.id}`
    };
  }

  async fetchPaste(id: string): Promise<Paste> {
    const data = await this.request('GET', `/api/v1/pastes/${id}`);

    return {
      id: data.id,
      content: data.content,
      language: data.language,
      title: data.title,
      created_at: data.created_at,
      expires_at: data.expires_at,
      private: data.private,
      encrypted: data.encrypted || false,
      url: `${this.baseUrl}/${data.id}`
    };
  }

  async listPastes(): Promise<Paste[]> {
    const data = await this.request('GET', '/api/v1/pastes');

    return data.map((p: any) => ({
      id: p.id,
      content: p.content || '',
      language: p.language,
      title: p.title,
      created_at: p.created_at,
      expires_at: p.expires_at,
      private: p.private,
      encrypted: p.encrypted || false,
      url: `${this.baseUrl}/${p.id}`
    }));
  }

  async deletePaste(id: string): Promise<void> {
    await this.request('DELETE', `/api/v1/pastes/${id}`);
  }
}

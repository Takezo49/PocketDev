import { execSync } from 'child_process';
import { readdirSync, statSync, existsSync } from 'fs';
import { join, basename } from 'path';
import { homedir } from 'os';

export interface ProjectInfo {
  path: string;
  name: string;
  branch?: string;
  dirty: boolean;
  changedFiles: number;
  lastCommitMsg?: string;
  framework?: string;
  lastUsed?: number;
  tier: 'active' | 'recent' | 'discovered';
}

interface DirEntry {
  name: string;
  hasGit: boolean;
  isFile: boolean;
}

const PROJECT_MARKERS = ['.git', 'package.json', 'Cargo.toml', 'pubspec.yaml', 'go.mod', 'pyproject.toml'];
const SKIP_DIRS = new Set(['node_modules', '.git', 'target', 'build', 'dist', '.cache', 'venv', '.local', '.npm', '.cargo', '.rustup', '__pycache__', '.gradle', '.pub-cache']);

const FRAMEWORK_MAP: Record<string, string> = {
  'package.json': 'node',
  'pubspec.yaml': 'flutter',
  'Cargo.toml': 'rust',
  'go.mod': 'go',
  'pyproject.toml': 'python',
};

const CACHE_TTL = 60_000; // 60s

export class ProjectScanner {
  private cache: ProjectInfo[] | null = null;
  private cacheTime = 0;

  async getProjects(recentCwds?: Map<string, number>): Promise<ProjectInfo[]> {
    const now = Date.now();
    if (this.cache && (now - this.cacheTime) < CACHE_TTL) {
      return this.mergeRecents(this.cache, recentCwds);
    }

    const projects = await this.scan();
    this.cache = projects;
    this.cacheTime = now;
    return this.mergeRecents(projects, recentCwds);
  }

  invalidate(): void {
    this.cache = null;
  }

  searchDirectories(query: string): { path: string; name: string; hasGit: boolean; isFile: boolean }[] {
    const results: { path: string; name: string; hasGit: boolean; isFile: boolean }[] = [];
    const q = query.toLowerCase();
    const home = homedir();

    const search = (dir: string, depth: number) => {
      if (depth > 4 || results.length >= 50) return;
      try {
        const entries = readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
          if (entry.name.startsWith('.') && depth < 2) continue;
          const fullPath = join(dir, entry.name);

          if (entry.isDirectory()) {
            if (SKIP_DIRS.has(entry.name)) continue;
            if (entry.name.toLowerCase().includes(q)) {
              const hasGit = existsSync(join(fullPath, '.git'));
              results.push({ path: fullPath, name: entry.name, hasGit, isFile: false });
            }
            if (results.length < 50) {
              search(fullPath, depth + 1);
            }
          } else if (entry.isFile()) {
            if (entry.name.toLowerCase().includes(q)) {
              results.push({ path: fullPath, name: entry.name, hasGit: false, isFile: true });
            }
          }
        }
      } catch {}
    };

    search(home, 0);
    // Sort: dirs first (git repos on top), then files
    results.sort((a, b) => {
      if (a.isFile !== b.isFile) return a.isFile ? 1 : -1;
      if (!a.isFile && !b.isFile && a.hasGit !== b.hasGit) return a.hasGit ? -1 : 1;
      return a.name.localeCompare(b.name);
    });
    return results;
  }

  listDirectories(dirPath: string): DirEntry[] {
    try {
      const entries = readdirSync(dirPath, { withFileTypes: true });
      const dirs: DirEntry[] = [];
      const files: DirEntry[] = [];
      for (const entry of entries) {
        if (entry.isDirectory()) {
          if (SKIP_DIRS.has(entry.name)) continue;
          const fullPath = join(dirPath, entry.name);
          let hasGit = existsSync(join(fullPath, '.git'));
          // Also check if any immediate child has .git (parent of projects)
          if (!hasGit) {
            try {
              const children = readdirSync(fullPath, { withFileTypes: true });
              hasGit = children.some(c => c.isDirectory() && existsSync(join(fullPath, c.name, '.git')));
            } catch {}
          }
          dirs.push({ name: entry.name, hasGit, isFile: false });
        } else if (entry.isFile()) {
          files.push({ name: entry.name, hasGit: false, isFile: true });
        }
      }
      // Split dirs into regular and dotdirs
      const regularDirs = dirs.filter(d => !d.name.startsWith('.'));
      const dotDirs = dirs.filter(d => d.name.startsWith('.'));
      // Split files into regular and dotfiles
      const regularFiles = files.filter(f => !f.name.startsWith('.'));
      const dotFiles = files.filter(f => f.name.startsWith('.'));

      // Sort each group: git repos first, then alphabetical
      const sortDirs = (arr: DirEntry[]) => arr.sort((a, b) => {
        if (a.hasGit !== b.hasGit) return a.hasGit ? -1 : 1;
        return a.name.localeCompare(b.name);
      });
      const sortByName = (arr: DirEntry[]) => arr.sort((a, b) => a.name.localeCompare(b.name));

      sortDirs(regularDirs);
      sortDirs(dotDirs);
      sortByName(regularFiles);
      sortByName(dotFiles);

      // Order: regular dirs → regular files → dotdirs → dotfiles
      return [...regularDirs, ...regularFiles, ...dotDirs, ...dotFiles];
    } catch {
      return [];
    }
  }

  private async scan(): Promise<ProjectInfo[]> {
    return new Promise((resolve) => {
      const timeout = setTimeout(() => resolve(found), 5000);
      const found: ProjectInfo[] = [];
      const home = homedir();

      try {
        this.walkBFS(home, 3, found);
      } catch {}

      clearTimeout(timeout);
      resolve(found);
    });
  }

  private walkBFS(root: string, maxDepth: number, found: ProjectInfo[]): void {
    const queue: { path: string; depth: number }[] = [{ path: root, depth: 0 }];

    while (queue.length > 0) {
      const { path: dirPath, depth } = queue.shift()!;
      if (depth > maxDepth) continue;

      try {
        const entries = readdirSync(dirPath, { withFileTypes: true });

        // Check if this directory is a project
        const isProject = PROJECT_MARKERS.some(m => {
          try { return existsSync(join(dirPath, m)); } catch { return false; }
        });

        if (isProject && depth > 0) {
          const info = this.getProjectInfo(dirPath);
          if (info) found.push(info);
          // Don't recurse into project directories
          continue;
        }

        // Queue subdirectories
        for (const entry of entries) {
          if (!entry.isDirectory()) continue;
          if (entry.name.startsWith('.')) continue;
          if (SKIP_DIRS.has(entry.name)) continue;
          queue.push({ path: join(dirPath, entry.name), depth: depth + 1 });
        }
      } catch {
        // Permission denied or other error, skip
      }
    }
  }

  private getProjectInfo(dirPath: string): ProjectInfo | null {
    try {
      const name = this.getProjectName(dirPath);
      const framework = this.detectFramework(dirPath);
      const gitInfo = this.getGitInfo(dirPath);

      return {
        path: dirPath,
        name,
        branch: gitInfo.branch,
        dirty: gitInfo.dirty,
        changedFiles: gitInfo.changedFiles,
        lastCommitMsg: gitInfo.lastCommitMsg,
        framework,
        tier: 'discovered',
      };
    } catch {
      return null;
    }
  }

  private getProjectName(dirPath: string): string {
    // Try reading name from manifest files
    try {
      if (existsSync(join(dirPath, 'package.json'))) {
        const pkg = JSON.parse(require('fs').readFileSync(join(dirPath, 'package.json'), 'utf-8'));
        if (pkg.name) return pkg.name;
      }
    } catch {}

    return basename(dirPath);
  }

  private detectFramework(dirPath: string): string | undefined {
    for (const [file, framework] of Object.entries(FRAMEWORK_MAP)) {
      if (existsSync(join(dirPath, file))) return framework;
    }
    return undefined;
  }

  private getGitInfo(dirPath: string): { branch?: string; dirty: boolean; changedFiles: number; lastCommitMsg?: string } {
    if (!existsSync(join(dirPath, '.git'))) {
      return { dirty: false, changedFiles: 0 };
    }

    const opts = { cwd: dirPath, timeout: 2000, encoding: 'utf-8' as const, stdio: 'pipe' as const };

    let branch: string | undefined;
    try {
      branch = execSync('git rev-parse --abbrev-ref HEAD', opts).toString().trim();
    } catch {}

    let dirty = false;
    let changedFiles = 0;
    try {
      const status = execSync('git status --porcelain', opts).toString().trim();
      if (status) {
        dirty = true;
        changedFiles = status.split('\n').filter(l => l.trim()).length;
      }
    } catch {}

    let lastCommitMsg: string | undefined;
    try {
      lastCommitMsg = execSync('git log -1 --format=%s', opts).toString().trim();
    } catch {}

    return { branch, dirty, changedFiles, lastCommitMsg };
  }

  private mergeRecents(projects: ProjectInfo[], recentCwds?: Map<string, number>): ProjectInfo[] {
    if (!recentCwds || recentCwds.size === 0) return projects;

    const merged = projects.map(p => {
      const lastUsed = recentCwds.get(p.path);
      if (lastUsed) {
        return { ...p, lastUsed, tier: 'recent' as const };
      }
      return p;
    });

    // Add recent cwds that weren't found by scanner
    for (const [path, lastUsed] of recentCwds) {
      if (!merged.some(p => p.path === path)) {
        const info = this.getProjectInfo(path);
        if (info) {
          merged.push({ ...info, lastUsed, tier: 'recent' });
        }
      }
    }

    // Sort: recent by lastUsed desc, then discovered alphabetically
    merged.sort((a, b) => {
      if (a.tier === 'recent' && b.tier !== 'recent') return -1;
      if (a.tier !== 'recent' && b.tier === 'recent') return 1;
      if (a.tier === 'recent' && b.tier === 'recent') {
        return (b.lastUsed ?? 0) - (a.lastUsed ?? 0);
      }
      return a.name.localeCompare(b.name);
    });

    return merged;
  }
}

// =============================================================================
// LANGUAGE MAPPING MODULE
// =============================================================================
// This module handles language-to-extension and extension-to-language mappings
// for syntax highlighting in Pasto.

// Map languages to typical file extensions
// Generated from all lexers - picking the most canonical extension for each
const LanguageExtensions = {
  'abap': '.abap',
  'abnf': '.abnf',
  'actionscript': '.as',
  'actionscript_3': '.as',
  'ada': '.ada',
  'agda': '.agda',
  'al': '.al',
  'alloy': '.als',
  'apl': '.apl',
  'applescript': '.applescript',
  'arangodb_aql': '.aql',
  'arduino': '.ino',
  'armasm': '.s',
  'autohotkey': '.ahk',
  'autoit': '.au3',
  'awk': '.awk',
  'ballerina': '.bal',
  'bash': '.sh',
  'batchfile': '.bat',
  'bibtex': '.bib',
  'bicep': '.bicep',
  'blitzbasic': '.bb',
  'bnf': '.bnf',
  'bqn': '.bqn',
  'brainfuck': '.bf',
  'c': '.c',
  'c#': '.cs',
  'c++': '.cpp',
  'cap_n_proto': '.capnp',
  'cassandra_cql': '.cql',
  'ceylon': '.ceylon',
  'cfengine3': '.cf',
  'chaiscript': '.chai',
  'chapel': '.chpl',
  'cheetah': '.tmpl',
  'clojure': '.clj',
  'cmake': '.cmake',
  'cobol': '.cob',
  'coffeescript': '.coffee',
  'common_lisp': '.lisp',
  'coq': '.v',
  'crystal': '.cr',
  'csharp': '.cs',
  'css': '.css',
  'cue': '.cue',
  'cython': '.pyx',
  'd': '.d',
  'dart': '.dart',
  'dax': '.dax',
  'desktop_entry': '.desktop',
  'diff': '.diff',
  'dns': '.zone',
  'docker': '.dockerfile',
  'dtd': '.dtd',
  'dylan': '.dylan',
  'ebnf': '.ebnf',
  'elixir': '.ex',
  'elm': '.elm',
  'emacslisp': '.el',
  'erlang': '.erl',
  'factor': '.factor',
  'fennel': '.fennel',
  'fish': '.fish',
  'forth': '.fth',
  'fortran': '.f90',
  'fortranfixed': '.f',
  'fsharp': '.fs',
  'gas': '.s',
  'gdscript': '.gd',
  'gdscript3': '.gd',
  'gherkin': '.feature',
  'gleam': '.gleam',
  'glsl': '.glsl',
  'gnuplot': '.plt',
  'go': '.go',
  'go_template': '.gotmpl',
  'graphql': '.graphql',
  'groff': '.man',
  'groovy': '.groovy',
  'handlebars': '.hbs',
  'hare': '.ha',
  'haskell': '.hs',
  'hcl': '.hcl',
  'hlb': '.hlb',
  'hlsl': '.hlsl',
  'holyc': '.hc',
  'html': '.html',
  'hy': '.hy',
  'idris': '.idr',
  'igor': '.ipf',
  'ini': '.ini',
  'io': '.io',
  'j': '.ijs',
  'java': '.java',
  'javascript': '.js',
  'json': '.json',
  'jsonata': '.jsonata',
  'julia': '.jl',
  'jungle': '.jungle',
  'kotlin': '.kt',
  'llvm': '.ll',
  'lua': '.lua',
  'makefile': '.mak',
  'mako': '.mao',
  'markdown': '.md',
  'mason': '.mhtml',
  'mathematica': '.nb',
  'matlab': '.m',
  'mcfunction': '.mcfunction',
  'metal': '.metal',
  'minizinc': '.mzn',
  'mlir': '.mlir',
  'modula-2': '.mod',
  'monkeyc': '.mc',
  'myghty': '.myt',
  'nasm': '.nasm',
  'natural': '.nsp',
  'newspeak': '.ns2',
  'nim': '.nim',
  'nix': '.nix',
  'objective-c': '.m',
  'objectpascal': '.pas',
  'ocaml': '.ml',
  'octave': '.m',
  'odin': '.odin',
  'onesenterprise': '.epf',
  'openedge_abl': '.p',
  'openscad': '.scad',
  'org_mode': '.org',
  'perl': '.pl',
  'php': '.php',
  'pig': '.pig',
  'pkgconfig': '.pc',
  'plaintext': '.txt',
  'plutus_core': '.plc',
  'pony': '.pony',
  'postscript': '.ps',
  'povray': '.pov',
  'powerquery': '.pq',
  'powershell': '.ps1',
  'prolog': '.pro',
  'promela': '.pml',
  'promql': '.promql',
  'properties': '.properties',
  'protocol_buffer': '.proto',
  'prql': '.prql',
  'psl': '.psl',
  'puppet': '.pp',
  'python': '.py',
  'python_2': '.py',
  'qbasic': '.bas',
  'qml': '.qml',
  'r': '.r',
  'racket': '.rkt',
  'react': '.jsx',
  'reasonml': '.re',
  'reg': '.reg',
  'rego': '.rego',
  'rexx': '.rexx',
  'rpm_spec': '.spec',
  'rst': '.rst',
  'ruby': '.rb',
  'rust': '.rs',
  'sas': '.sas',
  'sass': '.sass',
  'scala': '.scala',
  'scheme': '.scm',
  'scilab': '.sci',
  'scss': '.scss',
  'sed': '.sed',
  'shell': '.sh',
  'sieve': '.sieve',
  'smali': '.smali',
  'smalltalk': '.st',
  'smarty': '.tpl',
  'snobol': '.snobol',
  'solidity': '.sol',
  'sourcepawn': '.sp',
  'sparql': '.sparql',
  'sql': '.sql',
  'mysql': '.sql',
  'standard_ml': '.sml',
  'stas': '.stas',
  'stylus': '.styl',
  'svelte': '.svelte',
  'swift': '.swift',
  'systemd': '.service',
  'systemverilog': '.sv',
  'tablegen': '.td',
  'tal': '.tal',
  'tasm': '.tasm',
  'tcl': '.tcl',
  'tcsh': '.tcsh',
  'terraform': '.tf',
  'tex': '.tex',
  'text': '.txt',
  'thrift': '.thrift',
  'toml': '.toml',
  'tradingview': '.tv',
  'tradingview': '.tv',
  'turing': '.tu',
  'turtle': '.ttl',
  'twig': '.twig',
  'typescript': '.ts',
  'typoscript': '.ts',
  'ucode': '.uc',
  'v': '.v',
  'v_shell': '.vsh',
  'vala': '.vala',
  'vb_net': '.vb',
  'VelocityLexer': '.vm',
  'verilog': '.v',
  'vhdl': '.vhdl',
  'vhs': '.tape',
  'viml': '.vim',
  'vue': '.vue',
  'wdte': '.wdte',
  'webgpu_shading_language': '.wgsl',
  'whiley': '.whiley',
  'xml': '.xml',
  'yaml': '.yaml',
  'yang': '.yang',
  'z80_assembly': '.z80',
  'zed': '.zed',
  'zig': '.zig',
  // Aliases
  'cpp': '.cpp',
  'jsx': '.jsx',
  'tsx': '.tsx',
  'sh': '.sh',
  'zsh': '.sh'
};

// Create reverse mapping (extension to language) for efficient lookup
// This is generated programmatically to avoid maintaining duplicate mappings
const ExtensionToLanguage = (() => {
  const mapping = {};

  for (const [language, extension] of Object.entries(LanguageExtensions)) {
    mapping[extension] = language;
  }

  return mapping;
})();

/**
 * Get the language name for a given file extension
 * @param {string} extension - File extension (with or without leading dot)
 * @returns {string} Language name or 'text' as fallback
 */
function languageForExtension(extension) {
  if (!extension || typeof extension !== 'string') {
    return 'text';
  }

  // Normalize extension: ensure it starts with dot and is lowercase
  let normalizedExt = extension.toLowerCase();
  if (!normalizedExt.startsWith('.')) {
    normalizedExt = '.' + normalizedExt;
  }

  // Look up in the extension-to-language mapping
  const language = ExtensionToLanguage[normalizedExt];

  // Return the found language or 'text' as fallback
  return language || 'text';
}

/**
 * Get the file extension for a given language name
 * @param {string} language - Language name
 * @returns {string} File extension or '.txt' as fallback
 */
function extensionForLanguage(language) {
  if (!language || typeof language !== 'string') {
    return '.txt';
  }

  const extension = LanguageExtensions[language];
  return extension || '.txt';
}

// Export functions for global access via window object
if (typeof window !== 'undefined') {
  window.languageForExtension = languageForExtension;
  window.extensionForLanguage = extensionForLanguage;
  window.LanguageExtensions = LanguageExtensions;
  window.ExtensionToLanguage = ExtensionToLanguage;
}
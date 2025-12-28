module Pasto
  TARTRAZINE_TO_HLJS_MAPPING = {
    # Comments
    ".c"   => ".hljs-comment", # Comment
    ".ch"  => ".hljs-comment", # CommentHashbang
    ".cm"  => ".hljs-comment", # CommentMultiline
    ".cp"  => ".hljs-comment", # CommentPreproc
    ".cpf" => ".hljs-comment", # CommentPreprocFile
    ".cs"  => ".hljs-comment", # CommentSingle / CommentSpecial

    # Keywords
    ".k"  => ".hljs-keyword", # Keyword
    ".kc" => ".hljs-keyword", # KeywordConstant
    ".kd" => ".hljs-keyword", # KeywordDeclaration
    ".kn" => ".hljs-keyword", # KeywordNamespace
    ".kp" => ".hljs-keyword", # KeywordPseudo
    ".kr" => ".hljs-keyword", # KeywordReserved
    ".kt" => ".hljs-type",    # KeywordType

    # Literals / Strings
    ".l"   => ".hljs-literal",       # Literal
    ".ld"  => ".hljs-string",        # LiteralDate
    ".ls"  => ".hljs-string",        # LiteralString
    ".lsa" => ".hljs-string",        # LiteralStringAffix / LiteralStringAtom
    ".lsb" => ".hljs-string",        # LiteralStringBacktick / LiteralStringBoolean
    ".lsc" => ".hljs-char",          # LiteralStringChar
    ".lsd" => ".hljs-string",        # LiteralStringDelimiter / LiteralStringDoc / LiteralStringDouble
    ".lse" => ".hljs-string.escape", # LiteralStringEscape
    ".lsh" => ".hljs-string",        # LiteralStringHeredoc
    ".lsi" => ".hljs-subst",         # LiteralStringInterpol
    ".lsn" => ".hljs-variable",      # LiteralStringName
    ".lso" => ".hljs-string",        # LiteralStringOther
    ".lsr" => ".hljs-regexp",        # LiteralStringRegex
    ".lss" => ".hljs-string",        # LiteralStringSingle / LiteralStringSymbol

    # Numbers
    ".ln"   => ".hljs-number", # LiteralNumber
    ".lnb"  => ".hljs-number", # LiteralNumberBin
    ".lnf"  => ".hljs-number", # LiteralNumberFloat
    ".lnh"  => ".hljs-number", # LiteralNumberHex
    ".lni"  => ".hljs-number", # LiteralNumberInteger
    ".lnil" => ".hljs-number", # LiteralNumberIntegerLong
    ".lno"  => ".hljs-number", # LiteralNumberOct

    # Names / Variables
    ".n"   => ".hljs-variable",        # Name / None
    ".na"  => ".hljs-variable",        # NameAttribute
    ".nb"  => ".hljs-built_in",        # NameBuiltin
    ".nbp" => ".hljs-built_in",        # NameBuiltinPseudo
    ".nc"  => ".hljs-title.class_",    # NameClass / NameConstant
    ".nd"  => ".hljs-variable",        # NameDecorator
    ".ne"  => ".hljs-variable",        # NameEntity / NameException
    ".nf"  => ".hljs-title.function_", # NameFunction
    ".nfm" => ".hljs-title.function_", # NameFunctionMagic
    ".nk"  => ".hljs-keyword",         # NameKeyword
    ".nl"  => ".hljs-variable",        # NameLabel
    ".nn"  => ".hljs-variable",        # NameNamespace
    ".no"  => ".hljs-operator",        # NameOperator / NameOther
    ".np"  => ".hljs-property",        # NameProperty / NamePseudo
    ".nt"  => ".hljs-selector-tag",    # NameTag
    ".nv"  => ".hljs-variable",        # NameVariable
    ".nva" => ".hljs-variable",        # NameVariableAnonymous
    ".nvc" => ".hljs-variable",        # NameVariableClass
    ".nvg" => ".hljs-variable",        # NameVariableGlobal
    ".nvi" => ".hljs-variable",        # NameVariableInstance
    ".nvm" => ".hljs-variable",        # NameVariableMagic

    # Operators
    ".o"  => ".hljs-operator", # Operator / Other
    ".ow" => ".hljs-operator", # OperatorWord

    # Punctuation
    ".p" => ".hljs-punctuation", # Punctuation

    # Text
    ".t"  => ".hljs-variable",    # Text
    ".tp" => ".hljs-punctuation", # TextPunctuation
    ".ts" => ".hljs-symbol",      # TextSymbol
    ".tw" => ".hljs-variable",    # TextWhitespace

    # Generic (these map to various categories)
    ".g"  => ".hljs-variable", # Generic
    ".gd" => ".hljs-deletion", # GenericDeleted
    ".ge" => ".hljs-variable", # GenericEmph / GenericError
    ".gh" => ".hljs-title",    # GenericHeading
    ".gi" => ".hljs-addition", # GenericInserted
    ".go" => ".hljs-variable", # GenericOutput
    ".gp" => ".hljs-variable", # GenericPrompt
    ".gs" => ".hljs-strong",   # GenericStrong / GenericSubheading
    ".gt" => ".hljs-variable", # GenericTraceback
    ".gu" => ".hljs-variable", # GenericUnderline

    # Error
    ".e" => ".hljs-variable", # Error

    # Highlighting (special cases)
    ".hl"   => ".hljs-variable", # Highlight
    ".lh"   => ".hljs-variable", # LineHighlight
    ".lnl"  => ".hljs-variable", # LineNumbers (context dependent, use .lnl to avoid conflict)
    ".lnt"  => ".hljs-variable", # LineNumbersTable
    ".lt"   => ".hljs-variable", # LineTable
    ".lttd" => ".hljs-variable", # LineTableTD
    ".cl"   => ".hljs-variable", # CodeLine
    ".b"    => ".hljs-variable", # Background

    # Additional highlight.js classes that don't have direct Tartrazine equivalents
    # These will be used for more specific styling when needed
    ".hljs-meta"              => ".hljs-meta",              # Meta information
    ".hljs-params"            => ".hljs-params",            # Function parameters
    ".hljs-doctag"            => ".hljs-doctag",            # Documentation tags
    ".hljs-selector-id"       => ".hljs-selector-id",       # CSS ID selectors
    ".hljs-selector-class"    => ".hljs-selector-class",    # CSS class selectors
    ".hljs-selector-attr"     => ".hljs-selector-attr",     # CSS attribute selectors
    ".hljs-selector-pseudo"   => ".hljs-selector-pseudo",   # CSS pseudo-selectors
    ".hljs-template-tag"      => ".hljs-template-tag",      # Template tags
    ".hljs-template-variable" => ".hljs-template-variable", # Template variables
    ".hljs-bullet"            => ".hljs-bullet",            # List bullets
    ".hljs-code"              => ".hljs-code",              # Inline code
    ".hljs-emphasis"          => ".hljs-emphasis",          # Emphasized text
    ".hljs-formula"           => ".hljs-formula",           # Mathematical formulas
    ".hljs-link"              => ".hljs-link",              # Links
    ".hljs-quote"             => ".hljs-quote",             # Quotes
  }
end

module lsp;

enum ScopeKind
{
	IMPORT,
    GLOBAL,
    CONTAINER,       // Inside struct, union, bitstruct fields
    EXECUTION,       // Inside a function body or macro body
    TYPE_ASSIGNMENT  // Explicit right-hand side matching (e.g., Var = )
}

enum LspAccessKind
{
    NONE,
    INSTANCE,   // Triggered by '.'
    STATIC    // Triggered by '::'
}
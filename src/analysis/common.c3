module lsp;

enum ScopeKind
{
	NONE,
	IMPORT,
	GLOBAL,
	PARAMETER,
	CONTAINER,       // Inside struct, union, bitstruct fields
	ENUM,
	EXECUTION,       // Inside a function body or macro body
	TYPE_ASSIGNMENT,  // Explicit right-hand side matching (e.g., Var = )
	ATTRIBUTE
}

enum LspAccessKind
{
	NONE,
	INSTANCE,   // Triggered by '.'
	STATIC    // Triggered by '::'
}